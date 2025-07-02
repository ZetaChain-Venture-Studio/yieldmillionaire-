// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IVault
 * @author https://github.com/nzmpi
 * @notice An interface for a basic vault
 */
interface IVault {
    /**
     * Deposits tokens into the vault
     * @param message - The deposit message
     */
    function deposit(bytes calldata message) external;
    /**
     * Withdraws tokens from the vault
     * @param message - The withdraw message
     */
    function withdraw(bytes calldata message) external;
}
