// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ProxyBase} from "../src/ProxyBase.sol";
import {IGatewayZEVM, ISystemContract, YieldMil} from "../src/YieldMil.sol";
import {IYieldMil} from "../src/interfaces/IYieldMil.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployYieldMilScript is Script {
    address constant admin = 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827;

    struct YieldMilConstructorArgs {
        IGatewayZEVM gateway;
        ISystemContract systemContract;
        address usdcBase;
        address ethBase;
        address usdcPolygon;
        address polPolygon;
    }

    YieldMilConstructorArgs testnetArgs = YieldMilConstructorArgs({
        gateway: IGatewayZEVM(0x6c533f7fE93fAE114d0954697069Df33C9B74fD7),
        systemContract: ISystemContract(0xEdf1c3275d13489aCdC6cD6eD246E72458B8795B),
        usdcBase: 0x4bC32034caCcc9B7e02536945eDbC286bACbA073, // arbitrum
        ethBase: 0x1de70f3e971B62A0707dA18100392af14f7fB677, // arbitrum
        usdcPolygon: 0x4bC32034caCcc9B7e02536945eDbC286bACbA073,
        polPolygon: 0x1de70f3e971B62A0707dA18100392af14f7fB677
    });

    YieldMilConstructorArgs mainnetArgs = YieldMilConstructorArgs({
        gateway: IGatewayZEVM(0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E),
        systemContract: ISystemContract(0x91d18e54DAf4F677cB28167158d6dd21F6aB3921),
        usdcBase: 0x96152E6180E085FA57c7708e18AF8F05e37B479D,
        ethBase: 0x1de70f3e971B62A0707dA18100392af14f7fB677,
        usdcPolygon: 0xfC9201f4116aE6b054722E10b98D904829b469c3,
        polPolygon: 0xADF73ebA3Ebaa7254E859549A44c74eF7cff7501
    });

    // deploy yieldMil implementation
    /* function run() public {
        vm.startBroadcast();
        YieldMilConstructorArgs memory args;
        if (block.chainid == 7000) {
            args = mainnetArgs;
        } else if (block.chainid == 7001) {
            args = testnetArgs;
        } else {
            revert("Unsupported network");
        }
        new YieldMil(args.gateway, args.systemContract, args.usdcBase, args.ethBase, args.usdcPolygon, args.polPolygon);
        vm.stopBroadcast();
    } */

    // deploy proxy without initializing
    /* function run() public {
        vm.startBroadcast();
        address yieldMil = 0xeebC3D7bf1e4b57a08135E9C4E2fE6834e9c1dD0;
        new ProxyBase(yieldMil, admin, "");
        vm.stopBroadcast();
    } */

    // initialize
    /* function run() public {
        vm.startBroadcast();
        address yieldMil = 0xeebC3D7bf1e4b57a08135E9C4E2fE6834e9c1dD0;
        ProxyBase proxy = ProxyBase(payable(0x76768c94b898CC09e163BDB58B8742162F9FdF6a));
        (IYieldMil.Chain[] memory chains, IYieldMil.Protocol[] memory protocols, address[] memory tokens, address[] memory vaults) = _getInitContext();
        IYieldMil.InitContext memory initContext = IYieldMil.InitContext({
            owner: admin,
            chains: chains,
            protocols: protocols,
            tokens: tokens,
            vaults: vaults
        });
        bytes memory data = abi.encodeCall(YieldMil.initialize, initContext);
        proxy.changeImplementation(yieldMil, data);
        vm.stopBroadcast();
    } */

    // change implementation
    function run() public {
        vm.startBroadcast();
        address yieldMil = 0xeebC3D7bf1e4b57a08135E9C4E2fE6834e9c1dD0;
        ProxyBase proxy = ProxyBase(payable(0x76768c94b898CC09e163BDB58B8742162F9FdF6a));
        proxy.changeImplementation(yieldMil, "");
        vm.stopBroadcast();
    }

    function _getInitContext()
        internal
        view
        returns (
            IYieldMil.Chain[] memory chains,
            IYieldMil.Protocol[] memory protocols,
            address[] memory tokens,
            address[] memory vaults
        )
    {
        if (block.chainid == 7000) {
            chains = new IYieldMil.Chain[](2);
            chains[0] = IYieldMil.Chain.Base;
            chains[1] = IYieldMil.Chain.Polygon;
            protocols = new IYieldMil.Protocol[](2);
            protocols[0] = IYieldMil.Protocol.Aave;
            protocols[1] = IYieldMil.Protocol.Aave;
            tokens = new address[](2);
            tokens[0] = testnetArgs.usdcBase;
            tokens[1] = testnetArgs.usdcPolygon;
            vaults = new address[](1);
            vaults[0] = 0x4fDf139518f0a6DaA2073934DcC67c49fA50aA55;
            vaults[1] = 0x4fDf139518f0a6DaA2073934DcC67c49fA50aA55;
        } else if (block.chainid == 7001) {
            chains = new IYieldMil.Chain[](1);
            chains[0] = IYieldMil.Chain.Base;
            protocols = new IYieldMil.Protocol[](1);
            protocols[0] = IYieldMil.Protocol.Aave;
            tokens = new address[](1);
            tokens[0] = testnetArgs.usdcBase;
            vaults = new address[](1);
            vaults[0] = 0x4fDf139518f0a6DaA2073934DcC67c49fA50aA55;
        } else {
            revert("Unsupported network");
        }
    }
}
