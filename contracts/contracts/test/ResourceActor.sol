// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/// @dev A distinct caller lets tests exercise ownership and operator boundaries.
contract ResourceActor {
    bool public reject;
    function setReject(bool value) external { reject = value; }
    function execute(address target, bytes calldata data) external payable returns (bool ok, bytes memory result) {
        (ok, result) = target.call{value: msg.value}(data);
    }
    receive() external payable { require(!reject, "reject"); }
}

