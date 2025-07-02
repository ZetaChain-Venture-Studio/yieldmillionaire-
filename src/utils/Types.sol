// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum Protocol {
    Aave
}

/**
 * A struct to store the context of a cross-chain call.
 * @param targetChain - The target chain to which the call is made.
 * @param protocol - The protocol to which the call is made.
 * @param to - The address on behalf of which the deposit is made on an EVM or to which to receive the withdrawal.
 * @param token - The token to transfer.
 * @param amount - The amount to transfer.
 * @param gasLimit - The gas limit for the call.
 * @param destinationChain - The chain to which the withdrawal is made.
 */
struct CallContext {
    uint256 targetChain;
    Protocol protocol;
    address to;
    address token;
    uint256 amount;
    uint256 gasLimit;
    uint256 destinationChain;
}
