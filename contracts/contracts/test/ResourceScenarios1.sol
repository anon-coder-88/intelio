// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";
import {ResourceReceiver} from "./ResourceReceiver.sol";
import {ResourceActor} from "./ResourceActor.sol";

/// @dev Executable Solidity scenarios; every test uses a fresh resource account.
contract ResourceScenarios1 {
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

    function testUnknownRecipient() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.setRecipient,(99,address(this),true)),IntelioResources.UnknownApplication.selector);
        require(!c.approvedRecipient(99,address(this)), "unknown approval");
    }

    function testUnknownPay() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.payUsage,(99,payable(address(this)),1,RECEIPT)),IntelioResources.UnknownApplication.selector);
        require(address(c).balance == 0, "unknown payment");
    }

    function testUnknownWithdraw() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.withdraw,(99,1)),IntelioResources.UnknownApplication.selector);
        require(address(c).balance == 0, "unknown withdrawal");
    }

    function testOperatorOwnership() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        _actorFails(actor,c,abi.encodeCall(c.setOperator,(id,address(actor),1 ether)),IntelioResources.Unauthorized.selector);
        require(c.operatorAllowance(id,address(actor)) == 0, "operator self authorization");
    }

    function testRecipientOwnership() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        _actorFails(actor,c,abi.encodeCall(c.setRecipient,(id,address(actor),true)),IntelioResources.Unauthorized.selector);
        require(!c.approvedRecipient(id,address(actor)), "recipient self authorization");
    }

    function testWithdrawOwnership() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        _actorFails(actor,c,abi.encodeCall(c.withdraw,(id,1)),IntelioResources.Unauthorized.selector);
        require(_balance(c,id) == 1 ether && address(actor).balance == 0, "unauthorized withdrawal");
    }

    function testZeroOperator() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.setOperator,(id,address(0),1)),IntelioResources.InvalidInput.selector);
        require(c.operatorAllowance(id,address(0)) == 0, "zero operator");
    }

    function testZeroRecipient() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.setRecipient,(id,address(0),true)),IntelioResources.InvalidInput.selector);
        require(!c.approvedRecipient(id,address(0)), "zero recipient");
    }
}
