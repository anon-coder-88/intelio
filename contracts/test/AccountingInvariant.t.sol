// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ResourceAccounts} from "../src/ResourceAccounts.sol";

/// @dev Handler owns two isolated apps and submits valid arbitrary operation sequences.
contract AccountHandler is Test {
    ResourceAccounts public immutable accounts;
    address payable public constant PROVIDER = payable(address(0xCAFE));
    bytes32 public constant SERVICE = keccak256("service");
    uint256 public deposits;
    uint256 public withdrawals;
    uint256 public charges;
    uint256 public sequence;

    constructor(ResourceAccounts accounts_) {
        accounts = accounts_;
        for (uint256 i; i < 2; ++i) {
            uint256 id = accounts.createApplication(
                "invariant-app", ResourceAccounts.Policy(1 ether, 3 ether, 20 ether)
            );
            accounts.configureService(id, SERVICE, address(this), PROVIDER, true);
        }
    }

    function fund(uint256 rawId, uint96 rawAmount) external {
        uint256 id = 1 + rawId % 2;
        uint256 amount = bound(uint256(rawAmount), 1, 5 ether);
        vm.deal(address(this), amount);
        accounts.fund{value: amount}(id);
        deposits += amount;
    }

    function withdraw(uint256 rawId, uint96 rawAmount) external {
        uint256 id = 1 + rawId % 2;
        uint256 balance = accounts.application(id).balance;
        if (balance == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, balance);
        accounts.withdraw(id, payable(address(this)), amount);
        withdrawals += amount;
    }

    function charge(uint256 rawId, uint96 rawAmount) external {
        uint256 id = 1 + rawId % 2;
        ResourceAccounts.Application memory app = accounts.application(id);
        if (app.paused) return;
        uint256 spent = app.day == block.timestamp / 1 days ? app.dailySpent : 0;
        uint256 capacity = app.policy.dailyLimit - spent;
        capacity = min(capacity, app.policy.lifetimeLimit - app.lifetimeSpent);
        capacity = min(capacity, app.policy.requestLimit);
        capacity = min(capacity, app.balance);
        if (capacity == 0) return;
        uint256 amount = bound(uint256(rawAmount), 1, capacity);
        accounts.payUsage(id, SERVICE, bytes32(++sequence), amount);
        charges += amount;
    }

    function advanceTime(uint32 seconds_) external {
        vm.warp(block.timestamp + bound(uint256(seconds_), 0, 3 days));
    }

    function pause(uint256 rawId, bool paused) external {
        accounts.setPaused(1 + rawId % 2, paused);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    receive() external payable {}
}

contract AccountingInvariantTest is StdInvariant, Test {
    ResourceAccounts internal accounts;
    AccountHandler internal handler;

    function setUp() public {
        vm.warp(1 days);
        accounts = new ResourceAccounts();
        handler = new AccountHandler(accounts);
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = AccountHandler.fund.selector;
        selectors[1] = AccountHandler.withdraw.selector;
        selectors[2] = AccountHandler.charge.selector;
        selectors[3] = AccountHandler.advanceTime.selector;
        selectors[4] = AccountHandler.pause.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }

    function invariantLiabilitiesEqualSumOfApplicationBalances() public view {
        assertEq(
            accounts.totalLiabilities(), accounts.application(1).balance + accounts.application(2).balance
        );
        assertEq(address(accounts).balance, accounts.totalLiabilities());
    }

    function invariantDepositsConservedAcrossPaymentsAndWithdrawals() public view {
        assertEq(handler.deposits(), accounts.totalLiabilities() + handler.withdrawals() + handler.charges());
        assertEq(handler.PROVIDER().balance, handler.charges());
    }

    function invariantSpendingNeverExceedsPolicy() public view {
        for (uint256 id = 1; id <= 2; ++id) {
            ResourceAccounts.Application memory app = accounts.application(id);
            assertLe(app.dailySpent, app.policy.dailyLimit);
            assertLe(app.lifetimeSpent, app.policy.lifetimeLimit);
        }
    }
}
