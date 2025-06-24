// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ProxyBase} from "../src/ProxyBase.sol";
import {YieldMil} from "../src/YieldMil.sol";

import "../src/interfaces/ISystemContract.sol";
import {MockERC20} from "./helpers/MockERC20.sol";
import {MockGateway} from "./helpers/MockGateway.sol";
import {MockSystemContract} from "./helpers/MockSystemContract.sol";

import {IGatewayZEVM} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {Test, console} from "forge-std/Test.sol";

contract YieldMilTest is Test {
    YieldMil yieldMil;
    MockGateway gateway;
    MockSystemContract systemContract;
    MockERC20 usdcBase;
    MockERC20 ethBase;
    MockERC20 usdcPolygon;
    MockERC20 polPolygon;

    function setUp() public {
        gateway = new MockGateway();
        systemContract = new MockSystemContract();
        usdcBase = new MockERC20();
        ethBase = new MockERC20();
        usdcPolygon = new MockERC20();
        polPolygon = new MockERC20();
        yieldMil = new YieldMil(
            IGatewayZEVM(address(gateway)),
            ISystemContract(address(systemContract)),
            address(usdcBase),
            address(ethBase),
            address(usdcPolygon),
            address(polPolygon)
        );
    }

    function test() public {}
}
