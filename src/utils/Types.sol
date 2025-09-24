// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

enum Protocol {
    Aave
}

/**
 * A struct to store the context of a cross-chain call.
 * @param targetChain - The target chain to which the call is made.
 * @param protocol - The protocol to which the call is made.
 * @param sender - The address of the sender.
 * @param to - The address on behalf of which the deposit is made on an EVM or to which to receive the withdrawal.
 * @param token - The token to transfer.
 * @param amount - The amount to transfer.
 * @param gasLimit - The gas limit for the call.
 * @param nonce - For deposits - the permit2 nonce, for withdrawals - the nonce from the vault.
 * @param destinationChain - The destination chain for withdrawals.
 * @param deadline - The deadline of the signature.
 * @param signature - The signature.
 */
struct CallContext {
    uint256 targetChain;
    Protocol protocol;
    address sender;
    address to;
    address token;
    uint256 amount;
    uint256 gasLimit;
    uint256 nonce;
    uint256 destinationChain;
    uint256 deadline;
    bytes signature;
}
