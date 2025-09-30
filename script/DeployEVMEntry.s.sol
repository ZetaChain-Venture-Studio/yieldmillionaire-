// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EVMEntry, IEVMEntry} from "../src/EVMEntry.sol";
import {ProxyBase} from "../src/ProxyBase.sol";
import "../src/utils/Types.sol";
import "./Constants.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployEVMEntryScript is Script {
    uint256 immutable chainId = block.chainid;
    address immutable admin =
        chainId == 421614 ? 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827 : 0xABD10F0A61270D6977c5bFD9d4ec74d6D3bc96ab;
    address constant implTestnet = 0xE879848fF873eF67CC6Bdfb21D275236548B2a09;
    address constant implBase = 0x932F1B9623C5C55B84C11379e2D59Bdabc386B1c;
    address constant implPolygon = 0x7E31763BCB704DaF1B54B55D84DF3E3eAd6dB2aF;
    address constant implBnb = 0x47C03cbAf42ddee10F997E50c64EBC54248aA498;
    address constant proxyTestnet = 0x5789500c258fB5cd222fF83f07576E4DF3B5401e;
    address constant proxyBase = 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD;
    address constant proxyPolygon = 0x1547e8603048137deFf6Fc029C1778E2889A0F83;
    address constant proxyBnb = 0x33CB07CA2D83298dc4ee9Efa5b0c421632b15B11;

    struct EVMEntryConstructorArgs {
        IGatewayEVM gateway;
        IPermit2 permit2;
        address yieldMil;
        address usdc;
    }

    // arbitrum
    EVMEntryConstructorArgs testnetArgs = EVMEntryConstructorArgs({
        gateway: IGatewayEVM(0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f),
        permit2: permit2,
        yieldMil: 0x3a1E99a396607B822a68B194eE856d05fc38d848, // proxy
        usdc: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
    });

    EVMEntryConstructorArgs baseArgs = EVMEntryConstructorArgs({
        gateway: gateway,
        permit2: permit2,
        yieldMil: yieldMil, // proxy
        usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
    });

    EVMEntryConstructorArgs polygonArgs = EVMEntryConstructorArgs({
        gateway: gateway,
        permit2: permit2,
        yieldMil: yieldMil, // proxy
        usdc: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
    });

    EVMEntryConstructorArgs bnbArgs = EVMEntryConstructorArgs({
        gateway: gateway,
        permit2: permit2,
        yieldMil: yieldMil, // proxy
        usdc: 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
    });

    function run() public {
        // deploy EVMEntry implementation
        /* vm.startBroadcast();
        EVMEntryConstructorArgs memory args;
        if (chainId == 8453) {
            args = baseArgs;
        } else if (chainId == 137) {
            args = polygonArgs;
        } else if (chainId == 421614) {
            args = testnetArgs;
        } else if (chainId == 56) {
            args = bnbArgs;
        } else {
            revert("Unsupported network");
        }
        new EVMEntry(args.gateway, args.permit2, args.yieldMil, args.usdc);
        vm.stopBroadcast(); */

        // change implementation
        /* vm.startBroadcast();
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), "");
        vm.stopBroadcast(); */

        // change implementation and reinitialize
        vm.startBroadcast();
        IEVMEntry.ReInitContext memory reInitContext = _getReInitContext();
        reInitContext.version = 2;
        bytes memory data = abi.encodeCall(EVMEntry.reinitialize, reInitContext);
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), data);
        vm.stopBroadcast();
    }

    // deploy proxy without initialization
    /* function run() public {
        vm.startBroadcast();
        new ProxyBase(_getImpl(), admin, "");
        vm.stopBroadcast();
    } */

    // initialize proxy
    /* function run() public {
        vm.startBroadcast();
        (Protocol[] memory protocols, address[] memory tokens, address[] memory vaults) = _getInitArgs();
        bytes memory data = abi.encodeCall(EVMEntry.initialize, (admin, protocols, tokens, vaults));
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), data);
        vm.stopBroadcast();
    } */

    function _getImpl() internal view returns (address) {
        if (chainId == 8453) {
            return implBase;
        } else if (chainId == 137) {
            return implPolygon;
        } else if (chainId == 421614) {
            return implTestnet;
        } else if (chainId == 56) {
            return implBnb;
        } else {
            revert("Unsupported network");
        }
    }

    function _getProxy() internal view returns (address) {
        if (chainId == 8453) {
            return proxyBase;
        } else if (chainId == 137) {
            return proxyPolygon;
        } else if (chainId == 421614) {
            return proxyTestnet;
        } else if (chainId == 56) {
            return proxyBnb;
        } else {
            revert("Unsupported network");
        }
    }

    function _getInitArgs()
        internal
        view
        returns (Protocol[] memory protocols, address[] memory tokens, address[] memory vaults)
    {
        protocols = new Protocol[](1);
        protocols[0] = Protocol.Aave;
        tokens = new address[](1);
        vaults = new address[](1);

        if (chainId == 8453) {
            tokens[0] = baseArgs.usdc;
            vaults[0] = 0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029;
        } else if (chainId == 137) {
            tokens[0] = polygonArgs.usdc;
            vaults[0] = 0x1c60d7075b19C8107dEe803272c9d085A0eDf775;
        } else if (chainId == 421614) {
            tokens[0] = testnetArgs.usdc;
            vaults[0] = 0x2DEEdcE96f1B40301B7CA1F8877286f73dE87CF3;
        } else if (chainId == 56) {
            tokens[0] = bnbArgs.usdc;
            vaults[0] = 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD;
        } else {
            revert("Unsupported network");
        }
    }

    function _getReInitContext() internal view returns (IEVMEntry.ReInitContext memory reInitContext) {
        if (chainId == 8453) {
            reInitContext.vaults = new address[](1);
            reInitContext.vaults[0] = 0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029;
        } else if (chainId == 137) {
            reInitContext.vaults = new address[](1);
            reInitContext.vaults[0] = 0x1c60d7075b19C8107dEe803272c9d085A0eDf775;
        } else if (chainId == 421614) {
            reInitContext.vaults = new address[](1);
            reInitContext.vaults[0] = 0x2DEEdcE96f1B40301B7CA1F8877286f73dE87CF3;
        } else if (chainId == 56) {
            reInitContext.vaults = new address[](1);
            reInitContext.vaults[0] = 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD;
        } else {
            revert("Unsupported network");
        }
    }
}
