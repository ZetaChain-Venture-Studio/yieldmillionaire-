// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IGatewayEVM} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

/**
 * @title IVault
 * @author https://github.com/nzmpi
 * @notice An interface for a basic vault
 */
interface IVault {
    /**
     * A struct to store the context of the reinitialization call.
     * @param version - The version of the reinitialization call.
     * @param guardians - The guardians of the contract.
     */
    struct ReInitContext {
        uint64 version;
        address[] guardians;
    }

    /**
     * Emitted when a deposit is made.
     * @param depositor - The address of the depositor.
     * @param onBehalfOf - The address on behalf of which the deposit is made.
     * @param sender - The address of the token sender - Gateway or EVMEntry.
     * @param assets - The amount of assets deposited.
     * @param shares - The amount of shares minted.
     * @param chainId - The original chain ID.
     */
    event Deposit(
        address indexed depositor,
        address indexed onBehalfOf,
        address indexed sender,
        uint256 assets,
        uint256 shares,
        uint256 chainId
    );
    /**
     * Emitted when the deposit is paused.
     * @param guardian - The address of the guardian who paused the deposit.
     * @param time - The timestamp when the deposit was paused.
     */
    event DepositPaused(address indexed guardian, uint256 time);
    /**
     * Emitted when the deposit is unpaused.
     * @param time - The timestamp when the deposit was unpaused.
     */
    event DepositUnpaused(uint256 time);
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
     * Emitted when a guardian is updated.
     * @param guardian - The address of the guardian.
     * @param status - The status of the guardian.
     */
    event GuardianUpdated(address indexed guardian, bool status);
    /**
     * Emitted when the owner is updated.
     * @param newOwner - The new owner.
     */
    event OwnerUpdated(address indexed newOwner);
    /**
     * Emitted when tokens are withdrawn.
     * @param sender - The address of the sender.
     * @param receiver - The address to withdraw to on ZetaChain.
     * @param assets - The amount of assets withdrawn.
     * @param shares - The amount of shares withdrawn.
     * @param destinationChain - The destination chain ID.
     */
    event Withdraw(
        address indexed sender, address indexed receiver, uint256 assets, uint256 shares, uint256 destinationChain
    );
    /**
     * Emitted when the withdraw is paused.
     * @param guardian - The address of the guardian who paused the withdraw.
     * @param time - The timestamp when the withdraw was paused.
     */
    event WithdrawPaused(address indexed guardian, uint256 time);
    /**
     * Emitted when the withdraw is unpaused.
     * @param time - The timestamp when the withdraw was unpaused.
     */
    event WithdrawUnpaused(uint256 time);

    error DepositIsForbidden();
    error InvalidFee();
    error InvalidMessage(bytes);
    error InvalidSignature();
    error NonceIsUsed(address sender, uint256 nonce);
    error NotEVMEntry();
    error NotGateway();
    error NotGuardian();
    error NotOwner();
    error NotYieldMil();
    error SignatureExpired();
    error TransferFailed();
    error VaultIsNotPaused();
    error WithdrawIsForbidden();
    error ZeroAddress();
    error ZeroAssets();
    error ZeroShares();
    error ZeroTokens();

    /**
     * Returns the current version of the contract.
     */
    function VERSION() external view returns (string memory);
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
     * Returns the EVMENTRY contract address.
     */
    function EVMENTRY() external view returns (address);

    /**
     * Deposits tokens into the vault.
     * @param message - The deposit message.
     * @return shares - The amount of minted shares.
     */
    function deposit(bytes calldata message) external returns (uint256 shares);
    /**
     * Withdraws tokens from the vault.
     * @param message - The withdraw message.
     */
    function withdraw(bytes calldata message) external;
    /**
     * Pauses the deposit.
     * @dev Only the guardian can pause the deposit.
     */
    function pauseDeposit() external;
    /**
     * Pauses the withdraw.
     * @dev Only the guardian can pause the withdraw.
     */
    function pauseWithdraw() external;
    /**
     * Unpauses the deposit.
     * @dev Only the owner can unpause the deposit.
     */
    function unpauseDeposit() external payable;
    /**
     * Unpauses the withdraw.
     * @dev Only the owner can unpause the withdraw.
     */
    function unpauseWithdraw() external payable;
    /**
     * Updates guardian's status.
     * @dev Only the owner can update the guardian's status.
     * @param guardian - The address of the guardian.
     * @param status - The status of the guardian.
     */
    function updateGuardian(address guardian, bool status) external payable;
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
     * Returns the POOL contract address.
     */
    function getPool() external view returns (address);
    /**
     * Returns the fee.
     */
    function getFee() external view returns (uint256);
    /**
     * Returns the owner.
     */
    function getOwner() external view returns (address);
    /**
     * Returns the guardian status.
     * @param guardian - The address of the guardian.
     */
    function isGuardian(address guardian) external view returns (bool);
    /**
     * Returns the last vault balance.
     */
    function getLastVaultBalance() external view returns (uint256);
    /**
     * Returns current free nonce.
     * @param sender - The address of the sender.
     */
    function getNonce(address sender) external view returns (uint256);
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
    /**
     * Returns the assets and shares.
     * @param owner - The address of the owner of assets and shares.
     * @return assets - The amount of assets.
     * @return shares - The amount of shares.
     */
    function getAssetsAndShares(address owner) external view returns (uint256 assets, uint256 shares);
}
