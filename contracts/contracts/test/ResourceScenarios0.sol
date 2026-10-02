// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";
import {ResourceReceiver} from "./ResourceReceiver.sol";
import {ResourceActor} from "./ResourceActor.sol";

/// @dev Executable Solidity scenarios; every test uses a fresh resource account.
contract ResourceScenarios0 {
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

    function testIdentity() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        (address owner,string memory uri,uint256 balance) = c.applications(id);
        require(owner == address(this), "owner");
        require(keccak256(bytes(uri)) == keccak256("ipfs://application"), "metadata");
        require(balance == 1 ether && c.nextAppId() == 2, "identity sequence");
    }

    function testIsolatedAccounts() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        uint256 second = c.createApplication("ipfs://second");
        require(second != id && c.nextAppId() == 3, "unique identity");
        require(_balance(c,second) == 0 && _balance(c,id) == 1 ether, "isolated balances");
    }

    function testEmptyMetadata() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.createApplication,("")),IntelioResources.InvalidInput.selector);
        require(c.nextAppId() == 1, "failed creation changed sequence");
    }

    function testLongMetadata() external payable {
        IntelioResources c = new IntelioResources();
        string memory uri = string(new bytes(513));
        _mustFail(address(c),abi.encodeCall(c.createApplication,(uri)),IntelioResources.InvalidInput.selector);
        require(c.nextAppId() == 1, "failed creation changed sequence");
    }

    function testMaxMetadata() external payable {
        IntelioResources c = new IntelioResources();
        uint256 id = c.createApplication(string(new bytes(512)));
        (,string memory uri,) = c.applications(id);
        require(bytes(uri).length == 512 && id == 1, "metadata boundary");
    }

    function testEmptyDeposit() external payable {
        (IntelioResources c,,uint256 id) = _funded();
        _mustFail(address(c),abi.encodeCall(c.deposit,(id)),IntelioResources.InvalidInput.selector);
        require(_balance(c,id) == 1 ether, "deposit rollback");
    }

    function testUnknownDeposit() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.deposit,(99)),IntelioResources.UnknownApplication.selector);
        require(address(c).balance == 0, "unknown account received funds");
    }

    function testUnknownOperator() external payable {
        IntelioResources c = new IntelioResources();
        _mustFail(address(c),abi.encodeCall(c.setOperator,(99,address(this),1)),IntelioResources.UnknownApplication.selector);
        require(c.operatorAllowance(99,address(this)) == 0, "unknown allowance");
    }
}
