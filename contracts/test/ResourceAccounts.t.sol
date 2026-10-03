// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {ResourceAccounts} from "../src/ResourceAccounts.sol";

contract RejectETH {
    receive() external payable {
        revert("Recipient unavailable");
    }
}

contract ReentrantRecipient {
    ResourceAccounts public immutable accounts;
    uint256 public appId;
    bytes32 public serviceId;
    bool public attempted;
    bool public succeeded;

    constructor(ResourceAccounts accounts_) {
        accounts = accounts_;
    }

    function setup(uint256 appId_, bytes32 serviceId_) external {
        appId = appId_;
        serviceId = serviceId_;
    }

    function charge() external {
        accounts.payUsage(appId, serviceId, keccak256("outer"), 1);
    }

    receive() external payable {
        attempted = true;
        (succeeded,) = address(accounts)
            .call(abi.encodeCall(accounts.payUsage, (appId, serviceId, keccak256("inner"), 1)));
    }
}

contract ResourceAccountsTest is Test {
    ResourceAccounts internal accounts;
    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");
    address payable internal provider = payable(makeAddr("provider"));
    address internal stranger = makeAddr("stranger");
    bytes32 internal service = keccak256("classification");
    bytes32 internal request = keccak256("request-1");
    uint256 internal appId;

    function setUp() public {
        vm.warp(10 days + 1);
        accounts = new ResourceAccounts();
        vm.deal(owner, 100 ether);
        vm.deal(stranger, 100 ether);
        vm.startPrank(owner);
        appId = accounts.createApplication(
            "ipfs://public-app", ResourceAccounts.Policy(1 ether, 2 ether, 4 ether)
        );
        accounts.configureService(appId, service, operator, provider, true);
        accounts.fund{value: 5 ether}(appId);
        vm.stopPrank();
    }

    function _pay(bytes32 id, uint256 amount) internal {
        vm.prank(operator);
        accounts.payUsage(appId, service, id, amount);
    }

    function _expectChargeError(bytes4 error, uint256 amount) internal {
        vm.expectRevert(error);
        _pay(request, amount);
    }

    function testCreateIdentityAndPolicy() public view {
        ResourceAccounts.Application memory app = accounts.application(appId);
        assertEq(app.owner, owner);
        assertEq(app.metadataURI, "ipfs://public-app");
        assertEq(app.policy.requestLimit, 1 ether);
        assertEq(app.day, 10);
        assertEq(accounts.nextAppId(), 2);
    }

    function testPaymentEmitsReceiptAndConservesFunds() public {
        vm.expectEmit(true, true, true, true, address(accounts));
        emit ResourceAccounts.UsagePaid(appId, service, request, operator, provider, 1 ether);
        _pay(request, 1 ether);
        ResourceAccounts.Application memory app = accounts.application(appId);
        assertEq(app.balance, 4 ether);
        assertEq(app.dailySpent, 1 ether);
        assertEq(app.lifetimeSpent, 1 ether);
        assertEq(provider.balance, 1 ether);
        assertEq(accounts.totalLiabilities(), 4 ether);
        assertEq(address(accounts).balance, 4 ether);
        assertTrue(accounts.paidRequests(appId, request));
    }

    function testSponsorCannotAcquireAuthority() public {
        vm.prank(stranger);
        accounts.fund{value: 1 ether}(appId);
        assertEq(accounts.application(appId).balance, 6 ether);
        vm.prank(stranger);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.withdraw(appId, payable(stranger), 1);
    }

    function testUnauthorizedCharge() public {
        vm.prank(stranger);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.payUsage(appId, service, request, 1);
    }

    function testDisabledService() public {
        vm.prank(owner);
        accounts.configureService(appId, service, operator, provider, false);
        _expectChargeError(ResourceAccounts.ServiceDisabled.selector, 1);
    }

    function testUnknownService() public {
        vm.prank(operator);
        vm.expectRevert(ResourceAccounts.ServiceDisabled.selector);
        accounts.payUsage(appId, keccak256("unknown"), request, 1);
    }

    function testOperatorRotationRevokesPreviousCaller() public {
        vm.prank(owner);
        accounts.configureService(appId, service, stranger, provider, true);
        _expectChargeError(ResourceAccounts.Unauthorized.selector, 1);
        vm.prank(stranger);
        accounts.payUsage(appId, service, request, 1);
        assertEq(provider.balance, 1);
    }

    function testZeroAmountRejected() public {
        _expectChargeError(ResourceAccounts.InvalidInput.selector, 0);
    }

    function testZeroRequestRejected() public {
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        _pay(bytes32(0), 1);
    }

    function testRequestLimitPlusOneRejected() public {
        _expectChargeError(ResourceAccounts.RequestLimitExceeded.selector, 1 ether + 1);
    }

    function testDailyLimitInclusiveAndOneWeiExcessRejected() public {
        _pay(request, 1 ether);
        _pay(keccak256("second"), 1 ether);
        vm.expectRevert(ResourceAccounts.DailyLimitExceeded.selector);
        _pay(keccak256("third"), 1);
        assertEq(accounts.application(appId).dailySpent, 2 ether);
    }

    function testUtcDayBoundaryResetsOnlyDailyCounter() public {
        vm.warp(11 days - 1);
        _pay(request, 1 ether);
        _pay(keccak256("second"), 1 ether);
        vm.warp(11 days);
        _pay(keccak256("next-day"), 1);
        ResourceAccounts.Application memory app = accounts.application(appId);
        assertEq(app.dailySpent, 1);
        assertEq(app.lifetimeSpent, 2 ether + 1);
        assertEq(app.day, 11);
    }

    function testLifetimeLimitPersistsAcrossDays() public {
        for (uint256 i; i < 4; ++i) {
            vm.warp((11 + i) * 1 days);
            _pay(bytes32(i + 1), 1 ether);
        }
        vm.warp(20 days);
        vm.expectRevert(ResourceAccounts.LifetimeLimitExceeded.selector);
        _pay(keccak256("excess"), 1);
        assertEq(accounts.application(appId).lifetimeSpent, 4 ether);
    }

    function testPolicyUpdatesCannotResetCounters() public {
        _pay(request, 1 ether);
        vm.prank(owner);
        accounts.setPolicy(appId, ResourceAccounts.Policy(1 ether, 1 ether, 4 ether));
        vm.expectRevert(ResourceAccounts.DailyLimitExceeded.selector);
        _pay(keccak256("again"), 1);
        assertEq(accounts.application(appId).dailySpent, 1 ether);
    }

    function testLowerDailyLimitBelowSpendBlocksUntilNextDay() public {
        _pay(request, 1 ether);
        vm.prank(owner);
        accounts.setPolicy(appId, ResourceAccounts.Policy(1, 1, 4 ether));
        vm.expectRevert(ResourceAccounts.DailyLimitExceeded.selector);
        _pay(keccak256("blocked"), 1);
        vm.warp(11 days);
        _pay(keccak256("allowed"), 1);
    }

    function testLifetimeLimitCannotBeLoweredBelowSpent() public {
        _pay(request, 1 ether);
        vm.prank(owner);
        vm.expectRevert(ResourceAccounts.InvalidPolicy.selector);
        accounts.setPolicy(appId, ResourceAccounts.Policy(1, 2, 3));
    }

    function testIncreaseLimitsDoesNotResetUsage() public {
        _pay(request, 1 ether);
        vm.prank(owner);
        accounts.setPolicy(appId, ResourceAccounts.Policy(2 ether, 3 ether, 6 ether));
        _pay(keccak256("larger"), 2 ether);
        assertEq(accounts.application(appId).lifetimeSpent, 3 ether);
    }

    function testReplayAcrossServicesRejected() public {
        _pay(request, 1);
        bytes32 other = keccak256("other-service");
        vm.prank(owner);
        accounts.configureService(appId, other, operator, provider, true);
        vm.prank(operator);
        vm.expectRevert(ResourceAccounts.RequestAlreadyPaid.selector);
        accounts.payUsage(appId, other, request, 1);
    }

    function testReplayAcrossDaysRejected() public {
        _pay(request, 1);
        vm.warp(11 days);
        _expectChargeError(ResourceAccounts.RequestAlreadyPaid.selector, 1);
    }

    function testSameReferenceIndependentAcrossApplications() public {
        vm.startPrank(owner);
        uint256 second = accounts.createApplication("second", ResourceAccounts.Policy(1, 2, 3));
        accounts.configureService(second, service, operator, provider, true);
        accounts.fund{value: 1}(second);
        vm.stopPrank();
        _pay(request, 1);
        vm.prank(operator);
        accounts.payUsage(second, service, request, 1);
        assertEq(provider.balance, 2);
        assertTrue(accounts.paidRequests(second, request));
    }

    function testInsufficientFundsDoesNotConsumeRequest() public {
        vm.prank(owner);
        accounts.withdraw(appId, payable(owner), 5 ether);
        _expectChargeError(ResourceAccounts.InsufficientBalance.selector, 1);
        assertFalse(accounts.paidRequests(appId, request));
        vm.prank(owner);
        accounts.fund{value: 1}(appId);
        _pay(request, 1);
    }

    function testRecipientFailureRevertsAllAccountingAndCanRetry() public {
        RejectETH reject = new RejectETH();
        vm.prank(owner);
        accounts.configureService(appId, service, operator, payable(address(reject)), true);
        _expectChargeError(ResourceAccounts.TransferFailed.selector, 1 ether);
        assertEq(accounts.application(appId).balance, 5 ether);
        assertEq(accounts.application(appId).lifetimeSpent, 0);
        assertEq(accounts.totalLiabilities(), 5 ether);
        assertFalse(accounts.paidRequests(appId, request));
        vm.prank(owner);
        accounts.configureService(appId, service, operator, provider, true);
        _pay(request, 1 ether);
    }

    function testReentrancyCannotChargeTwice() public {
        ReentrantRecipient receiver = new ReentrantRecipient(accounts);
        receiver.setup(appId, service);
        vm.prank(owner);
        accounts.configureService(appId, service, address(receiver), payable(address(receiver)), true);
        receiver.charge();
        assertTrue(receiver.attempted());
        assertFalse(receiver.succeeded());
        assertEq(accounts.application(appId).balance, 5 ether - 1);
        assertFalse(accounts.paidRequests(appId, keccak256("inner")));
    }

    function testPauseBlocksChargesButAllowsOwnerRecovery() public {
        vm.prank(owner);
        accounts.setPaused(appId, true);
        _expectChargeError(ResourceAccounts.AccountPaused.selector, 1);
        vm.prank(owner);
        accounts.withdraw(appId, payable(owner), 5 ether);
        assertEq(owner.balance, 100 ether);
        assertEq(accounts.totalLiabilities(), 0);
    }

    function testUnpauseResumesWithinRemainingBudget() public {
        _pay(request, 1);
        vm.startPrank(owner);
        accounts.setPaused(appId, true);
        accounts.setPaused(appId, false);
        vm.stopPrank();
        _pay(keccak256("resume"), 1);
        assertEq(accounts.application(appId).lifetimeSpent, 2);
    }

    function testWithdrawalDoesNotResetUsageOrOperatorAuthority() public {
        _pay(request, 1);
        vm.prank(owner);
        accounts.withdraw(appId, payable(owner), 1 ether);
        assertEq(accounts.application(appId).lifetimeSpent, 1);
        _pay(keccak256("continued"), 1);
        assertEq(provider.balance, 2);
    }

    function testWithdrawalFailureRetainsBalance() public {
        RejectETH reject = new RejectETH();
        vm.prank(owner);
        vm.expectRevert(ResourceAccounts.TransferFailed.selector);
        accounts.withdraw(appId, payable(address(reject)), 1 ether);
        assertEq(accounts.application(appId).balance, 5 ether);
        assertEq(accounts.totalLiabilities(), 5 ether);
    }

    function testWithdrawalToZeroOrContractRejected() public {
        vm.startPrank(owner);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.withdraw(appId, payable(address(0)), 1);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.withdraw(appId, payable(address(accounts)), 1);
        vm.stopPrank();
    }

    function testZeroOrExcessWithdrawalRejected() public {
        vm.startPrank(owner);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.withdraw(appId, payable(owner), 0);
        vm.expectRevert(ResourceAccounts.InsufficientBalance.selector);
        accounts.withdraw(appId, payable(owner), 5 ether + 1);
        vm.stopPrank();
    }

    function testCloseRequiresEmptyBalance() public {
        vm.prank(owner);
        vm.expectRevert(ResourceAccounts.BalanceNotEmpty.selector);
        accounts.closeApplication(appId);
    }

    function testCloseIsTerminal() public {
        vm.startPrank(owner);
        accounts.withdraw(appId, payable(owner), 5 ether);
        accounts.closeApplication(appId);
        vm.expectRevert(ResourceAccounts.AccountClosed.selector);
        accounts.fund{value: 1}(appId);
        vm.expectRevert(ResourceAccounts.AccountClosed.selector);
        accounts.setPaused(appId, false);
        vm.stopPrank();
        _expectChargeError(ResourceAccounts.AccountClosed.selector, 1);
        assertTrue(accounts.application(appId).closed);
    }

    function testUnknownApplicationRejectedForReadFundAndPay() public {
        vm.expectRevert(ResourceAccounts.UnknownApplication.selector);
        accounts.application(999);
        vm.expectRevert(ResourceAccounts.UnknownApplication.selector);
        accounts.fund{value: 1}(999);
        vm.expectRevert(ResourceAccounts.UnknownApplication.selector);
        accounts.payUsage(999, service, request, 1);
    }

    function testZeroFundingRejected() public {
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.fund(appId);
    }

    function testApplicationIsolation() public {
        vm.prank(stranger);
        uint256 other = accounts.createApplication("other", ResourceAccounts.Policy(1, 2, 3));
        vm.prank(stranger);
        accounts.fund{value: 3}(other);
        _pay(request, 1 ether);
        assertEq(accounts.application(other).balance, 3);
        assertEq(accounts.application(other).lifetimeSpent, 0);
        vm.prank(owner);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.withdraw(other, payable(owner), 1);
    }

    function testAllAdministrationRequiresOwner() public {
        vm.startPrank(stranger);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.setPolicy(appId, ResourceAccounts.Policy(1, 2, 3));
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.configureService(appId, service, stranger, provider, true);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.setPaused(appId, true);
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.setMetadata(appId, "changed");
        vm.expectRevert(ResourceAccounts.Unauthorized.selector);
        accounts.closeApplication(appId);
        vm.stopPrank();
    }

    function testInvalidServiceConfiguration() public {
        vm.startPrank(owner);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.configureService(appId, bytes32(0), operator, provider, true);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.configureService(appId, service, address(0), provider, true);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.configureService(appId, service, operator, payable(address(0)), true);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.configureService(appId, service, operator, payable(address(accounts)), true);
        vm.stopPrank();
    }

    function testMetadataBoundsAndUpdates() public {
        vm.startPrank(owner);
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.setMetadata(appId, "");
        vm.expectRevert(ResourceAccounts.InvalidInput.selector);
        accounts.setMetadata(appId, string(new bytes(513)));
        accounts.setMetadata(appId, string(new bytes(512)));
        assertEq(bytes(accounts.application(appId).metadataURI).length, 512);
        vm.stopPrank();
    }

    function testInvalidPolicyOrderingAndZero() public {
        vm.startPrank(owner);
        vm.expectRevert(ResourceAccounts.InvalidPolicy.selector);
        accounts.createApplication("app", ResourceAccounts.Policy(0, 0, 0));
        vm.expectRevert(ResourceAccounts.InvalidPolicy.selector);
        accounts.setPolicy(appId, ResourceAccounts.Policy(3, 2, 4));
        vm.expectRevert(ResourceAccounts.InvalidPolicy.selector);
        accounts.setPolicy(appId, ResourceAccounts.Policy(1, 3, 2));
        vm.stopPrank();
    }

    function testDirectTransferRejected() public {
        vm.deal(address(this), 1);
        (bool success,) = address(accounts).call{value: 1}("");
        assertFalse(success);
        assertEq(accounts.totalLiabilities(), 5 ether);
    }

    function testForcedSurplusNotCredited() public {
        vm.deal(address(accounts), 6 ether);
        assertEq(accounts.application(appId).balance, 5 ether);
        vm.prank(owner);
        accounts.withdraw(appId, payable(owner), 5 ether);
        assertEq(address(accounts).balance, 1 ether);
        assertEq(accounts.totalLiabilities(), 0);
    }

    function testOneWeiPrecisionNoRounding() public {
        _pay(request, 1);
        assertEq(provider.balance, 1);
        assertEq(accounts.application(appId).balance, 5 ether - 1);
    }

    function testFuzzAllowedPaymentsConserveAssets(uint96 raw) public {
        uint256 amount = bound(uint256(raw), 1, 1 ether);
        _pay(request, amount);
        assertEq(provider.balance + accounts.application(appId).balance, 5 ether);
        assertEq(accounts.totalLiabilities(), address(accounts).balance);
        assertEq(accounts.application(appId).dailySpent, amount);
    }

    function testFuzzRejectedRequestAmountsDoNotMutate(uint96 raw) public {
        uint256 amount = bound(uint256(raw), 1 ether + 1, type(uint96).max);
        _expectChargeError(ResourceAccounts.RequestLimitExceeded.selector, amount);
        assertEq(accounts.application(appId).balance, 5 ether);
        assertFalse(accounts.paidRequests(appId, request));
    }

    function testFuzzWithdrawAllOrPartial(uint96 raw) public {
        uint256 amount = bound(uint256(raw), 1, 5 ether);
        vm.prank(owner);
        accounts.withdraw(appId, payable(owner), amount);
        assertEq(owner.balance, 95 ether + amount);
        assertEq(accounts.totalLiabilities(), 5 ether - amount);
    }

    function testFuzzLargeValidLimitsDoNotOverflow(uint256 limit) public {
        limit = bound(limit, 1, type(uint256).max);
        vm.prank(owner);
        accounts.setPolicy(appId, ResourceAccounts.Policy(limit, limit, limit));
        _pay(request, 1);
        assertEq(accounts.application(appId).lifetimeSpent, 1);
    }
}
