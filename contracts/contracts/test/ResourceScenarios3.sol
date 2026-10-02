// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";
import {ResourceReceiver} from "./ResourceReceiver.sol";
import {ResourceActor} from "./ResourceActor.sol";

/// @dev Executable Solidity scenarios; every test uses a fresh resource account.
contract ResourceScenarios3 {
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

    function testBudgetBoundary() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),7);
        c.setRecipient(id,address(actor),true);
        c.payUsage(id,payable(address(actor)),7,RECEIPT);
        require(c.operatorAllowance(id,address(this)) == 0, "budget not exhausted");
        require(_balance(c,id) == 1 ether-7 && address(actor).balance == 7, "exact budget payout");
    }

    function testOverBudget() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),7);
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),8,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(c.operatorAllowance(id,address(this)) == 7 && _balance(c,id) == 1 ether, "over budget rollback");
    }

    function testOverBalance() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),2 ether);
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1 ether+1,RECEIPT)),IntelioResources.InsufficientResources.selector);
        require(c.operatorAllowance(id,address(this)) == 2 ether && _balance(c,id) == 1 ether, "overdraw rollback");
    }

    function testFullPayment() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),1 ether);
        c.setRecipient(id,address(actor),true);
        c.payUsage(id,payable(address(actor)),1 ether,RECEIPT);
        require(_balance(c,id) == 0 && address(c).balance == 0, "full payout accounting");
        require(address(actor).balance == 1 ether && c.operatorAllowance(id,address(this)) == 0, "full payout delivery");
    }

    function testRepeatedPayments() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),10);
        c.setRecipient(id,address(actor),true);
        c.payUsage(id,payable(address(actor)),3,RECEIPT);
        c.payUsage(id,payable(address(actor)),2,keccak256("second"));
        require(_balance(c,id) == 1 ether-5 && address(actor).balance == 5, "cumulative charges");
        require(c.operatorAllowance(id,address(this)) == 5, "remaining budget");
    }

    function testDistinctOperators() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),10);
        c.setOperator(id,address(actor),8);
        c.setRecipient(id,address(this),true);
        (bool ok,) = actor.execute(address(c),abi.encodeCall(c.payUsage,(id,payable(address(this)),3,RECEIPT)));
        require(ok, "authorized actor payment");
        require(c.operatorAllowance(id,address(actor)) == 5 && c.operatorAllowance(id,address(this)) == 10, "operator isolation");
    }

    function testApplicationPermissions() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        uint256 second = c.createApplication("ipfs://second");
        c.setOperator(id,address(actor),100);
        c.setRecipient(id,address(this),true);
        require(c.operatorAllowance(second,address(actor)) == 0, "allowance leaked");
        require(!c.approvedRecipient(second,address(this)), "recipient leaked");
    }

    function testRejectingRecipient() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        actor.setReject(true);
        c.setOperator(id,address(this),10);
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),3,RECEIPT)),IntelioResources.TransferFailed.selector);
        require(c.operatorAllowance(id,address(this)) == 10 && _balance(c,id) == 1 ether, "failed transfer rollback");
    }
}
