// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";
import {ResourceReceiver} from "./ResourceReceiver.sol";
import {ResourceActor} from "./ResourceActor.sol";

/// @dev Executable Solidity scenarios; every test uses a fresh resource account.
contract ResourceScenarios4 {
    bytes32 private constant RECEIPT = keccak256("usage-001");
    receive() external payable {}
    function _funded() private returns (IntelioResources c, ResourceActor actor, uint256 id) {
        require(msg.value == 1 ether, "test funding");
        c = new IntelioResources();
        actor = new ResourceActor();
        id = c.createApplication("ipfs://application");
        c.deposit{value: 1 ether}(id);
    }
    function _balance(IntelioResources c, uint256 id) private view returns (uint256 balance) {
        (,, balance) = c.applications(id);
    }
    function _mustFail(address target, bytes memory data, bytes4 expected) private {
        (bool ok, bytes memory result) = target.call(data);
        require(!ok, "unexpected success");
        require(result.length >= 4 && bytes4(result) == expected, "wrong error");
    }
    function _actorFails(ResourceActor actor, IntelioResources c, bytes memory data, bytes4 expected) private {
        (bool ok, bytes memory result) = actor.execute(address(c), data);
        require(!ok && result.length >= 4 && bytes4(result) == expected, "wrong actor error");
    }

    function testReentrancy() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        ResourceReceiver receiver = new ResourceReceiver(c);
        c.setOperator(id,address(this),100);
        c.setOperator(id,address(receiver),100);
        c.setRecipient(id,address(receiver),true);
        c.payUsage(id,payable(address(receiver)),10,RECEIPT);
        require(!receiver.reentered(), "reentrancy succeeded");
        require(_balance(c,id) == 1 ether-10 && c.operatorAllowance(id,address(receiver)) == 100, "nested accounting changed");
    }

    function testZeroWithdraw() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.withdraw,(id,0)),IntelioResources.InvalidInput.selector);
        require(_balance(c,id) == 1 ether && address(c).balance == 1 ether, "zero withdrawal accounting");
    }

    function testOverWithdraw() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.withdraw,(id,1 ether+1)),IntelioResources.InsufficientResources.selector);
        require(_balance(c,id) == 1 ether && address(c).balance == 1 ether, "overwithdraw rollback");
    }

    function testFullWithdraw() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        uint256 beforeBalance = address(this).balance;
        c.withdraw(id,1 ether);
        require(_balance(c,id) == 0 && address(c).balance == 0, "withdraw accounting");
        require(address(this).balance == beforeBalance+1 ether, "owner delivery");
    }

    function testWithdrawKeepsAllowance() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(actor),1 ether);
        c.withdraw(id,1 ether);
        require(c.operatorAllowance(id,address(actor)) == 1 ether, "withdraw unexpectedly revoked allowance");
        require(_balance(c,id) == 0, "withdraw balance");
    }

    function testSponsoredApplication() external payable {
        IntelioResources c = new IntelioResources();
        ResourceActor owner = new ResourceActor();
        (bool ok,bytes memory result) = owner.execute(address(c),abi.encodeCall(c.createApplication,("ipfs://sponsored")));
        require(ok, "actor create");
        uint256 id = abi.decode(result,(uint256));
        c.deposit{value: 1 ether}(id);
        (address appOwner,,uint256 balance) = c.applications(id);
        require(appOwner == address(owner) && balance == 1 ether, "sponsorship changed ownership");
    }

    function testRejectingOwner() external payable {
        IntelioResources c = new IntelioResources();
        ResourceActor owner = new ResourceActor();
        (bool ok,bytes memory result) = owner.execute(address(c),abi.encodeCall(c.createApplication,("ipfs://rejecting-owner")));
        require(ok, "actor create");
        uint256 id = abi.decode(result,(uint256));
        c.deposit{value: 1 ether}(id);
        owner.setReject(true);
        _actorFails(owner,c,abi.encodeCall(c.withdraw,(id,10)),IntelioResources.TransferFailed.selector);
        require(_balance(c,id) == 1 ether && address(c).balance == 1 ether, "failed withdrawal rollback");
    }

    function testFreshFundingAfterExhaustion() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setRecipient(id,address(actor),true);
        c.setOperator(id,address(this),1 ether);
        c.payUsage(id,payable(address(actor)),1 ether,RECEIPT);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(_balance(c,id) == 0 && c.operatorAllowance(id,address(this)) == 0, "exhaustion boundary");
    }
}
