// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ProxyBase} from "../src/ProxyBase.sol";
import {RefundVault} from "../src/RefundVault.sol";
import {IGatewayZEVM, IYieldMil, YieldMil} from "../src/YieldMil.sol";
import "../src/utils/Types.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployYieldMilScript is Script {
    uint256 immutable chainId = block.chainid;
    address immutable admin =
        chainId == 7001 ? 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827 : 0xABD10F0A61270D6977c5bFD9d4ec74d6D3bc96ab;
    address constant implTestnet = 0x62B98289A77F4Fee03d5F77a0060863D74e58DCC;
    address constant implMainnet = 0x759638f208d26F3FaC6C10DA4F237C65B721d7a7;
    address constant proxyTestnet = 0x3a1E99a396607B822a68B194eE856d05fc38d848;
    address constant proxyMainnet = 0xE65eEe518A897618cBEe25898f80200E7988c81e;

    struct YieldMilConstructorArgs {
        IGatewayZEVM gateway;
        RefundVault refundVault;
        address usdcBase;
        address ethBase;
        address usdcPolygon;
        address polPolygon;
        address usdcBnb;
        address bnbBnb;
    }

    YieldMilConstructorArgs testnetArgs = YieldMilConstructorArgs({
        gateway: IGatewayZEVM(0x6c533f7fE93fAE114d0954697069Df33C9B74fD7),
        refundVault: RefundVault(0xa4d973a5eE54ac5aAB74465900947D2208011E14),
        usdcBase: 0x4bC32034caCcc9B7e02536945eDbC286bACbA073, // arbitrum
        ethBase: 0x1de70f3e971B62A0707dA18100392af14f7fB677, // arbitrum
        usdcPolygon: 0x4bC32034caCcc9B7e02536945eDbC286bACbA073,
        polPolygon: 0x1de70f3e971B62A0707dA18100392af14f7fB677,
        usdcBnb: 0x4bC32034caCcc9B7e02536945eDbC286bACbA073,
        bnbBnb: 0x1de70f3e971B62A0707dA18100392af14f7fB677
    });

    YieldMilConstructorArgs mainnetArgs = YieldMilConstructorArgs({
        gateway: IGatewayZEVM(0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E),
        refundVault: RefundVault(0xC724D3E76B501B97B93DA8cb964EA380621586F0),
        usdcBase: 0x96152E6180E085FA57c7708e18AF8F05e37B479D,
        ethBase: 0x1de70f3e971B62A0707dA18100392af14f7fB677,
        usdcPolygon: 0xfC9201f4116aE6b054722E10b98D904829b469c3,
        polPolygon: 0xADF73ebA3Ebaa7254E859549A44c74eF7cff7501,
        usdcBnb: 0x05BA149A7bd6dC1F937fA9046A9e05C05f3b18b0,
        bnbBnb: 0x48f80608B672DC30DC7e3dbBd0343c5F02C738Eb
    });

    function run() public {
        // deploy yieldMil implementation
        /* vm.startBroadcast();
        YieldMilConstructorArgs memory args;
        if (chainId == 7000) {
            args = mainnetArgs;
        } else if (chainId == 7001) {
            args = testnetArgs;
        } else {
            revert("Unsupported network");
        }
        new YieldMil(args.gateway, args.refundVault, args.usdcBase, args.ethBase, args.usdcPolygon, args.polPolygon, args.usdcBnb, args.bnbBnb);
        vm.stopBroadcast(); */

        // change implementation
        /* vm.startBroadcast();
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), "");
        vm.stopBroadcast(); */

        // change implementation and reinitialize
        vm.startBroadcast();
        IYieldMil.ReInitContext memory reInitContext = _getReInitContext();
        reInitContext.version = 3;
        bytes memory data = abi.encodeCall(YieldMil.reinitialize, reInitContext);
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), data);
        vm.stopBroadcast();
    }

    // deploy proxy without initializing
    /* function run() public {
        vm.startBroadcast();
        new ProxyBase(_getImpl(), admin, "");
        vm.stopBroadcast();
    } */

    // initialize
    /* function run() public {
        vm.startBroadcast();
        (
            uint256[] memory chains,
            Protocol[] memory protocols,
            address[] memory tokens,
            address[] memory vaults,
            uint256[] memory EVMEntryChains,
            address[] memory EVMEntries
        ) = _getInitContext();
        IYieldMil.InitContext memory initContext = IYieldMil.InitContext({
            owner: admin,
            chains: chains,
            protocols: protocols,
            tokens: tokens,
            vaults: vaults,
            EVMEntryChains: EVMEntryChains,
            EVMEntries: EVMEntries
        });
        bytes memory data = abi.encodeCall(YieldMil.initialize, initContext);
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), data);
        vm.stopBroadcast();
    } */

    function _getImpl() internal view returns (address) {
        if (chainId == 7000) {
            return implMainnet;
        } else if (chainId == 7001) {
            return implTestnet;
        } else {
            revert("Unsupported network");
        }
    }

    function _getProxy() internal view returns (address) {
        if (chainId == 7000) {
            return proxyMainnet;
        } else if (chainId == 7001) {
            return proxyTestnet;
        } else {
            revert("Unsupported network");
        }
    }

    function _getInitContext()
        internal
        view
        returns (
            uint256[] memory chains,
            Protocol[] memory protocols,
            address[] memory tokens,
            address[] memory vaults,
            uint256[] memory EVMEntryChains,
            address[] memory EVMEntries
        )
    {
        if (chainId == 7000) {
            chains = new uint256[](2);
            chains[0] = 8453;
            chains[1] = 137;
            protocols = new Protocol[](2);
            protocols[0] = Protocol.Aave;
            protocols[1] = Protocol.Aave;
            tokens = new address[](2);
            tokens[0] = mainnetArgs.usdcBase;
            tokens[1] = mainnetArgs.usdcPolygon;
            vaults = new address[](2);
            vaults[0] = 0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029;
            vaults[1] = 0x1c60d7075b19C8107dEe803272c9d085A0eDf775;
            EVMEntryChains = chains;
            EVMEntries = new address[](2);
            EVMEntries[0] = 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD;
            EVMEntries[1] = 0x1547e8603048137deFf6Fc029C1778E2889A0F83;
        } else if (chainId == 7001) {
            chains = new uint256[](1);
            chains[0] = 421614;
            protocols = new Protocol[](1);
            protocols[0] = Protocol.Aave;
            tokens = new address[](1);
            tokens[0] = testnetArgs.usdcBase;
            vaults = new address[](1);
            vaults[0] = 0x2DEEdcE96f1B40301B7CA1F8877286f73dE87CF3;
            EVMEntryChains = chains;
            EVMEntries = new address[](1);
            EVMEntries[0] = address(0);
        } else {
            revert("Unsupported network");
        }
    }

    function _getReInitContext() internal view returns (IYieldMil.ReInitContext memory reInitContext) {
        if (chainId == 7000) {
            reInitContext.chains = new uint256[](3);
            reInitContext.chains[0] = 8453;
            reInitContext.chains[1] = 137;
            reInitContext.chains[2] = 56;
        } else if (chainId == 7001) {
            reInitContext.chains = new uint256[](1);
            reInitContext.chains[0] = 421614;
        } else {
            revert("Unsupported network");
        }
    }
}
