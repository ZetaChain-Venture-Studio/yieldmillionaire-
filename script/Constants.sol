// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPermit2} from "@permit2/interfaces/IPermit2.sol";
import {IGatewayEVM} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

IGatewayEVM constant gateway = IGatewayEVM(0x48B9AACC350b20147001f88821d31731Ba4C30ed);
address constant yieldMil = 0xE65eEe518A897618cBEe25898f80200E7988c81e;
IPermit2 constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
