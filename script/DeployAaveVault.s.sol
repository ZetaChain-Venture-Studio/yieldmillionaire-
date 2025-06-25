// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AaveVault} from "../src/AaveVault.sol";
import {ProxyBase} from "../src/ProxyBase.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGatewayEVM} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";
import {Script, console} from "forge-std/Script.sol";

contract DeployAaveVaultScript is Script {
    address constant admin = 0xFaB1e0F009A77a60dc551c2e768DFb3fadc40827;

    struct AaveVaultConstructorArgs {
        IPool pool;
        IERC20 token;
        IERC20 asset;
        IGatewayEVM gateway;
        address yieldMil;
    }

    // arbitrum
    AaveVaultConstructorArgs testnetArgs = AaveVaultConstructorArgs({
        pool: IPool(0xBfC91D59fdAA134A4ED45f7B584cAf96D7792Eff),
        token: IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d),
        asset: IERC20(0x460b97BD498E1157530AEb3086301d5225b91216),
        gateway: IGatewayEVM(0x0dA86Dc3F9B71F84a0E97B0e2291e50B7a5df10f),
        yieldMil: 0x76768c94b898CC09e163BDB58B8742162F9FdF6a // proxy
    });

    AaveVaultConstructorArgs baseArgs = AaveVaultConstructorArgs({
        pool: IPool(0xA238Dd80C259a72e81d7e4664a9801593F98d1c5),
        token: IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913),
        asset: IERC20(0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB),
        gateway: IGatewayEVM(0x48B9AACC350b20147001f88821d31731Ba4C30ed),
        yieldMil: address(0) // proxy
    });

    AaveVaultConstructorArgs polygonArgs = AaveVaultConstructorArgs({
        pool: IPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD),
        token: IERC20(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359),
        asset: IERC20(0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD),
        gateway: IGatewayEVM(0x48B9AACC350b20147001f88821d31731Ba4C30ed),
        yieldMil: address(0) // proxy
    });

    // deploy AaveVault implementation
    function run() public {
        vm.startBroadcast();
        AaveVaultConstructorArgs memory args;
        if (block.chainid == 8453) {
            args = baseArgs;
        } else if (block.chainid == 137) {
            args = polygonArgs;
        } else if (block.chainid == 421614) {
            args = testnetArgs;
        } else {
            revert("Unsupported network");
        }
        new AaveVault(args.pool, args.token, args.asset, args.gateway, args.yieldMil);
        vm.stopBroadcast();
    }

    // deploy proxy
    /* function run() public {
        vm.startBroadcast();
        address aaveVault = 0x52C1978545f68fbD9BF26905F38e0316d39c2e4F;
        bytes memory data = abi.encodeCall(AaveVault.initialize, (admin, 1000, 1000000));
        new ProxyBase(aaveVault, admin, data);
        vm.stopBroadcast();
    } */

    // get an address at nonce + 1
    /* function run() public {
        vm.startBroadcast();
        console.log(vm.computeCreateAddress(admin, vm.getNonce(admin) + 1));
        vm.stopBroadcast();
    } */
}
