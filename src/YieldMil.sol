// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IGatewayZEVM} from "@zetachain/protocol-contracts/contracts/zevm/interfaces/IGatewayZEVM.sol";
import "@zetachain/protocol-contracts/contracts/zevm/interfaces/UniversalContract.sol";

contract YeildMil is UniversalContract {
    IGatewayZEVM public constant GATEWAY = IGatewayZEVM(0xfEDD7A6e3Ef1cC470fbfbF955a22D793dDC0F44E);
    address public constant USDCBASE = 0x96152E6180E085FA57c7708e18AF8F05e37B479D;

    error NotGateway();

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    function onCall(MessageContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        onlyGateway
    {}

    function deposit() external {

    }

    function withdraw() external {
        
    }
}
