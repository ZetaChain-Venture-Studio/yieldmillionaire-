// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {
    Abortable, CallOptions, RevertOptions, Revertable
} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";

contract MockGateway {
    function withdrawAndCall(
        bytes calldata receiver,
        uint256 amount,
        address token,
        bytes calldata message,
        CallOptions calldata callOptions,
        RevertOptions calldata revertOptions
    ) external {}
}
