// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";
import {ResourceAccounts} from "../src/ResourceAccounts.sol";

/// @notice Chain guard prevents this local development script from deploying to a public chain.
contract DeployLocal is Script {
    function run() external returns (ResourceAccounts accounts) {
        require(block.chainid == 31337, "Local chain only");
        vm.startBroadcast();
        accounts = new ResourceAccounts();
        vm.stopBroadcast();
    }
}
