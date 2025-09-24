// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RefundVault} from "../RefundVault.sol";
import "../utils/Types.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGatewayZEVM} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {AbortContext, RevertContext} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";
import {IWETH9} from "@zetachain/contracts/zevm/interfaces/IWZETA.sol";

/**
 * @title IYieldMil
 * @author https://github.com/nzmpi
 * @notice Defines the interface of the YieldMil
 */
interface IYieldMil {
    /**
     * A struct to store the context of the reinitialization call.
     * @param version - The version of the reinitialization call.
     * @param chains - The supported chains.
     */
    struct ReInitContext {
        uint64 version;
        uint256[] chains;
    }

    /**
     * Emitted when tokens are deposited.
     * @param depositor - The address of the depositor.
     * @param targetChain - The chain to which the deposit is made.
     * @param protocol - The protocol to which the deposit is made.
     * @param onBehalfOf - The address on behalf of which the deposit is made.
     * @param token - The token to deposit.
     * @param amount - The amount of the token to deposit.
     * @param originalChain - The chain from which the deposit is made.
     */
    event Deposit(
        address indexed depositor,
        uint256 targetChain,
        Protocol protocol,
        address indexed onBehalfOf,
        address token,
        uint256 amount,
        uint256 originalChain
    );
    /**
     * Emitted when a deposit is aborted.
     * @param abortContext - The abort context.
     */
    event DepositAborted(AbortContext abortContext);
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
     * Emitted when a deposit is reverted.
     * @param revertContext - The revert context.
     */
    event DepositReverted(RevertContext revertContext);
    /**
     * Emitted when an EVMEntry is updated.
     * @param chainId - The chain id.
     * @param EVMEntry - The EVMEntry address.
     */
    event EVMEntryUpdated(uint256 indexed chainId, address indexed EVMEntry);
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
     * Emitted when a refund is added.
     * @param to - The address of the owner of the refund.
     * @param token - The token of the refund.
     * @param amount - The amount of the refund.
     */
    event RefundAdded(address indexed to, address indexed token, uint256 amount);
    /**
     * Emitted when refunds are sent.
     * @param from - The address of the owner of the refund.
     * @param to - The address to send the refund to.
     * @param token - The token to refund.
     * @param amount - The amount of the token to refund.
     */
    event RefundSent(address indexed from, address indexed to, address indexed token, uint256 amount);
    /**
     * Emitted when a vault is updated.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @param vault - The address of the vault.
     */
    event VaultUpdated(uint256 chain, Protocol protocol, address token, address indexed vault);
    /**
     * Emitted when tokens are withdrawn.
     * @param sender - The address of the sender.
     * @param context - The withdrawal call context.
     * @param originalChain - The chain on which the withdrawal is made.
     */
    event Withdraw(address indexed sender, CallContext context, uint256 originalChain);
    /**
     * Emitted when a withdrawal is aborted.
     * @param abortContext - The abort context.
     */
    event WithdrawAborted(AbortContext abortContext);
    /**
     * Emitted when a withdrawal is reverted.
     * @param revertContext - The revert context.
     */
    event WithdrawReverted(RevertContext revertContext);
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
    error InvalidAbort();
    error InvalidChain();
    error InvalidEVMEntry();
    error InvalidMessage(bytes);
    error InvalidSender();
    error InvalidSignature();
    error InvalidVault();
    error InvalidRevert();
    error NotGateway();
    error NotGuardian();
    error NotOwner();
    error NotUSDC();
    error SignatureExpired();
    error TransferFailed();
    error WithdrawIsForbidden();
    error ZeroAddress();
    error ZeroAmount();

    /**
     * Returns the current version of the contract
     */
    function VERSION() external view returns (string memory);
    /**
     * Returns the WZETA contract address
     */
    function WZETA() external view returns (IWETH9);
    /**
     * Returns Base chain id
     */
    function BASE_CHAIN_ID() external view returns (uint256);
    /**
     * Returns Polygon chain id
     */
    function POLYGON_CHAIN_ID() external view returns (uint256);
    /**
     * Returns BNB chain id
     */
    function BNB_CHAIN_ID() external view returns (uint256);
    /**
     * Returns the GATEWAY contract address
     */
    function GATEWAY() external view returns (IGatewayZEVM);
    /**
     * Returns the REFUND_VAULT contract address
     */
    function REFUND_VAULT() external view returns (RefundVault);
    /**
     * Returns the USDC_BASE contract address
     */
    function USDC_BASE() external view returns (address);
    /**
     * Returns the ETH_BASE contract address
     */
    function ETH_BASE() external view returns (address);
    /**
     * Returns the USDC_POLYGON contract address
     */
    function USDC_POLYGON() external view returns (address);
    /**
     * Returns the POL_POLYGON contract address
     */
    function POL_POLYGON() external view returns (address);
    /**
     * Returns the USDC_BNB contract address
     */
    function USDC_BNB() external view returns (address);
    /**
     * Returns the BNB_BNB contract address
     */
    function BNB_BNB() external view returns (address);

    /**
     * Deposits tokens into the contract.
     * @notice The token to deposit must be approved.
     * @notice The gas on an EVM chain is paid from the token amount.
     * @notice The tokens are taken from the caller, but deposit is made for context.to.
     * @dev Reverts if the vault does not exist.
     * @param context - The deposit call context.
     */
    function deposit(CallContext calldata context) external;
    /**
     * Withdraws tokens from the contract on an EVM.
     * @notice The gas on an EVM chain is paid from Zeta sent with the call.
     * @notice The amount in context is the amount of **shares** to withdraw.
     * @notice The tokens are sent to context.to on Zetachain.
     * @dev Does not revert on Zetachain, only on an EVM.
     * @param context - The withdrawal call context.
     */
    function withdraw(CallContext calldata context) external payable;
    /**
     * Updates a vault in the contract.
     * @dev Only callable by the owner.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @param vault - The address of the vault.
     */
    function updateVault(uint256 chain, Protocol protocol, address token, address vault) external payable;
    /**
     * Updates an EVMEntry address in the contract.
     * @dev Only callable by the owner.
     * @param chainId - The chain id.
     * @param EVMEntry - The EVMEntry address.
     */
    function updateEVMEntry(uint256 chainId, address EVMEntry) external payable;
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
     * Returns the owner of the contract.
     */
    function getOwner() external view returns (address);
    /**
     * Returns the guardian status.
     * @param guardian - The address of the guardian.
     */
    function isGuardian(address guardian) external view returns (bool);
    /**
     * Gets the vault address for the given parameters.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @return The address of the vault.
     */
    function getVault(uint256 chain, Protocol protocol, address token) external view returns (address);
    /**
     * Gets the EVMEntry address for the given chain id.
     * @param chainId - The chain id.
     */
    function getEVMEntry(uint256 chainId) external view returns (address);
}
