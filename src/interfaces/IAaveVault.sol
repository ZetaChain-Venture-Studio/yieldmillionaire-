// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGatewayEVM, RevertContext} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

/**
 * @title IAaveVault
 * @author https://github.com/nzmpi
 * @notice An interface for the AaveVault
 */
interface IAaveVault {
    /**
     * Emitted when a deposit is made.
     * @param depositor - The address of the depositor.
     * @param assets - The amount of assets deposited.
     * @param shares - The amount of shares minted.
     */
    event Deposit(address indexed depositor, uint256 assets, uint256 shares);
    /**
     * Emitted when the fee is updated.
     * @param newFee - The new fee.
     */
    event FeeUpdated(uint256 newFee);
    /**
     * Emitted when fees are withdrawn.
     * @param to - The address to withdraw to.
     * @param amount - The amount of fees withdrawn.
     */
    event FeesWithdrawn(address indexed to, uint256 amount);
    /**
     * Emitted when funds are rescued.
     * @param to - The address to rescue to.
     * @param token - The token rescued.
     * @param amount - The amount of funds rescued.
     */
    event FundsRescued(address indexed to, IERC20 indexed token, uint256 amount);
    /**
     * Emitted when the owner is updated.
     * @param newOwner - The new owner.
     */
    event OwnerUpdated(address indexed newOwner);
    /**
     * Emitted when tokens are withdrawn.
     * @param receiver - The address to withdraw to on ZetaChain.
     * @param assets - The amount of assets withdrawn.
     * @param shares - The amount of shares withdrawn.
     */
    event Withdraw(address indexed receiver, uint256 assets, uint256 shares);

    error InvalidFee();
    error InvalidMessage(bytes);
    error NotGateway();
    error NotOwner();
    error NotYieldMil();
    error TransferFailed();
    error ZeroAddress();
    error ZeroAssets();
    error ZeroShares();
    error ZeroTokens();

    /**
     * Returns the current version of the contract.
     */
    function VERSION() external view returns (string memory);
    /**
     * Returns the POOL contract address.
     */
    function POOL() external view returns (IPool);
    /**
     * Returns the TOKEN contract address.
     */
    function TOKEN() external view returns (IERC20);
    /**
     * Returns the ASSET (AToken) contract address.
     */
    function ASSET() external view returns (IERC20);
    /**
     * Returns the GATEWAY contract address.
     */
    function GATEWAY() external view returns (IGatewayEVM);
    /**
     * Returns the YIELDMIL contract address.
     */
    function YIELDMIL() external view returns (address);

    /**
     * Sets the fee.
     * @dev Only callable by the owner.
     * @param newFee - The new fee.
     */
    function setFee(uint256 newFee) external payable;
    /**
     * Withdraws the accumulated fees.
     * @dev Only callable by the owner.
     * @notice Withdraws in ATokens.
     * @param to - The address to withdraw to.
     */
    function withdrawFees(address to) external payable;
    /**
     * Transfers ownership of the contract.
     * @dev Only callable by the owner.
     * @param newOwner - The new owner.
     */
    function transferOwnership(address newOwner) external payable;
    /**
     * Rescues funds from the contract.
     * @notice For native tokens use address(0).
     * @dev Only callable by the owner.
     * @param to - The address to rescue to.
     * @param token - The token to rescue.
     * @param amount - The amount of funds to rescue.
     */
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable;

    /**
     * Returns the fee.
     */
    function getFee() external view returns (uint256);
    /**
     * Returns the owner.
     */
    function getOwner() external view returns (address);
    /**
     * Returns the assets and shares.
     * @param owner - The address of the owner of assets and shares.
     * @return assets - The amount of assets.
     * @return shares - The amount of shares.
     */
    function getAssetsAndShares(address owner) external view returns (uint256 assets, uint256 shares);
    /**
     * Returns the last vault balance.
     */
    function getLastVaultBalance() external view returns (uint256);
    /**
     * Returns the total supply of shares.
     */
    function totalSupply() external view returns (uint256);
    /**
     * Returns the total amount of assets minus the accumulated fees.
     */
    function totalAssets() external view returns (uint256);
    /**
     * Returns the accumulated fees.
     */
    function getAccumulatedFees() external view returns (uint256);
}
