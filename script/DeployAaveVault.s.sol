// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AaveVault} from "../src/AaveVault.sol";
import {ProxyBase} from "../src/ProxyBase.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGatewayEVM} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployAaveVaultScript is Script {
    uint256 immutable chainId = block.chainid;
    address immutable admin =
        chainId == 421614 ? 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827 : 0xABD10F0A61270D6977c5bFD9d4ec74d6D3bc96ab;
    address constant implTestnet = 0x3695E1C3e362D86CCA3520Abc335eFfe58F33423;
    address constant implBase = 0x862f46d57B3aa0FD3592D2DbA8Ea1cA4A11e846E;
    address constant implPolygon = 0x8bcd92E87B3f67457C80F085379Ef7fC65d3bCcD;
    address constant proxyTestnet = 0x2DEEdcE96f1B40301B7CA1F8877286f73dE87CF3;
    address constant proxyBase = 0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029;
    address constant proxyPolygon = 0x1c60d7075b19C8107dEe803272c9d085A0eDf775;

    struct AaveVaultConstructorArgs {
        IPool pool;
        IERC20 token;
        IERC20 asset;
        IGatewayEVM gateway;
        address yieldMil;
        address evmEntry;
    }

    // arbitrum
    AaveVaultConstructorArgs testnetArgs = AaveVaultConstructorArgs({
        pool: IPool(0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff),
        token: IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d),
        asset: IERC20(0x460b97BD498E1157530AEb3086301d5225b91216),
        gateway: IGatewayEVM(0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f),
        yieldMil: 0x3a1E99a396607B822a68B194eE856d05fc38d848, // proxy
        evmEntry: 0x5789500c258fB5cd222fF83f07576E4DF3B5401e // proxy
    });

    AaveVaultConstructorArgs baseArgs = AaveVaultConstructorArgs({
        pool: IPool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5),
        token: IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
        asset: IERC20(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
        gateway: IGatewayEVM(0x48B9AACC350b20147001f88821d31731Ba4C30ed),
        yieldMil: 0xE65eEe518A897618cBEe25898f80200E7988c81e, // proxy
        evmEntry: 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD // proxy
    });

    AaveVaultConstructorArgs polygonArgs = AaveVaultConstructorArgs({
        pool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        token: IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359),
        asset: IERC20(0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD),
        gateway: IGatewayEVM(0x48B9AACC350b20147001f88821d31731Ba4C30ed),
        yieldMil: 0xE65eEe518A897618cBEe25898f80200E7988c81e, // proxy
        evmEntry: 0x1547e8603048137deFf6Fc029C1778E2889A0F83 // proxy
    });

    // deploy AaveVault implementation
    /* function run() public {
        vm.startBroadcast();
        AaveVaultConstructorArgs memory args;
        if (chainId == 8453) {
            args = baseArgs;
        } else if (chainId == 137) {
            args = polygonArgs;
        } else if (chainId == 421614) {
            args = testnetArgs;
        } else {
            revert("Unsupported network");
        }
        new AaveVault(args.pool, args.token, args.asset, args.gateway, args.yieldMil, args.evmEntry);
        vm.stopBroadcast();
    } */

    // change implementation
    function run() public {
        vm.startBroadcast();
        ProxyBase(payable(_getProxy())).changeImplementation(_getImpl(), "");
        vm.stopBroadcast();
    }

    // deploy proxy
    /* function run() public {
        vm.startBroadcast();
        bytes memory data = abi.encodeCall(AaveVault.initialize, (admin, 200, 5234567));
        new ProxyBase(_getImpl(), admin, data);
        vm.stopBroadcast();
    } */

    // get an address at nonce + 1
    /* function run() public {
        vm.startBroadcast();
        console.log(vm.computeCreateAddress(admin, vm.getNonce(admin) + 1));
        vm.stopBroadcast();
    } */

    function _getImpl() internal view returns (address) {
        if (chainId == 8453) {
            return implBase;
        } else if (chainId == 137) {
            return implPolygon;
        } else if (chainId == 421614) {
            return implTestnet;
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
        } else {
            revert("Unsupported network");
        }
    }
}
