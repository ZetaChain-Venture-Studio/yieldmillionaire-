// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RefundVault} from "../src/RefundVault.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployRefundVaultScript is Script {
    // deploy RefundVault
    function run() public {
        vm.startBroadcast();
        new RefundVault();
        vm.stopBroadcast();
    }
}
