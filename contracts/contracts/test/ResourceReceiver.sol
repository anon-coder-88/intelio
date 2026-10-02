// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {IntelioResources} from "../IntelioResources.sol";

/// @dev Test fixture for failed payments and reentrancy attempts.
contract ResourceReceiver {
    IntelioResources public resources;
    bool public rejectPayment;
    bool public reentered;
    constructor(IntelioResources target) { resources = target; }
    function setReject(bool value) external { rejectPayment = value; }
    receive() external payable {
        require(!rejectPayment, "Payment rejected");
        (reentered,) = address(resources).call(abi.encodeCall(resources.payUsage, (1, payable(address(this)), 1, keccak256("nested"))));
    }
}
