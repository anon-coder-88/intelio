// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";
import {ResourceReceiver} from "./ResourceReceiver.sol";
import {ResourceActor} from "./ResourceActor.sol";

/// @dev Executable Solidity scenarios; every test uses a fresh resource account.
contract ResourceScenarios2 {
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

    function testSelfRecipient() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.setRecipient,(id,address(c),true)),IntelioResources.InvalidInput.selector);
        require(!c.approvedRecipient(id,address(c)), "recursive recipient");
    }

    function testOperatorReplacement() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(actor),1 ether);
        c.setOperator(id,address(actor),2);
        require(c.operatorAllowance(id,address(actor)) == 2, "allowance should replace");
        require(_balance(c,id) == 1 ether, "allowance moved funds");
    }

    function testOperatorRevocation() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(actor),1 ether);
        c.setRecipient(id,address(this),true);
        c.setOperator(id,address(actor),0);
        _actorFails(actor,c,abi.encodeCall(c.payUsage,(id,payable(address(this)),1,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(_balance(c,id) == 1 ether, "revoked payment moved funds");
    }

    function testRecipientRevocation() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),1 ether);
        c.setRecipient(id,address(actor),true);
        c.setRecipient(id,address(actor),false);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(c.operatorAllowance(id,address(this)) == 1 ether, "revocation spent allowance");
    }

    function testUnapprovedRecipient() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),1 ether);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(_balance(c,id) == 1 ether && address(actor).balance == 0, "unapproved payout");
    }

    function testOwnerNeedsAllowance() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1,RECEIPT)),IntelioResources.Unauthorized.selector);
        require(_balance(c,id) == 1 ether, "owner bypassed budget");
    }

    function testZeroPayment() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),1 ether);
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),0,RECEIPT)),IntelioResources.InvalidInput.selector);
        require(c.operatorAllowance(id,address(this)) == 1 ether, "zero payout changed budget");
    }

    function testEmptyReceipt() external payable {
        (IntelioResources c,ResourceActor actor,uint256 id) = _funded();
        c.setOperator(id,address(this),1 ether);
        c.setRecipient(id,address(actor),true);
        _mustFail(address(c),abi.encodeCall(c.payUsage,(id,payable(address(actor)),1,bytes32(0))),IntelioResources.InvalidInput.selector);
        require(_balance(c,id) == 1 ether && address(actor).balance == 0, "invalid receipt payout");
    }
}
