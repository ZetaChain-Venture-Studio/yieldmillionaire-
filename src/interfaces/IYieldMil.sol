// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ISystemContract.sol";
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
    enum Chain {
        Base,
        Polygon
    }

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
     */
    struct CallContext {
        Chain targetChain;
        Protocol protocol;
        address to;
        address token;
        uint256 amount;
        uint256 gasLimit;
    }

    /**
     * A struct to store the context of the initialization call.
     * @param owner - The owner of the contract.
     * @param chains - The supported chains.
     * @param protocols - The supported protocols.
     * @param tokens - The supported tokens.
     * @param vaults - The deployed vaults on each chain.
     */
    struct InitContext {
        address owner;
        Chain[] chains;
        Protocol[] protocols;
        address[] tokens;
        address[] vaults;
    }

    /**
     * Emitted when tokens are deposited.
     * @param depositor - The address of the depositor.
     * @param chain - The chain to which the deposit is made.
     * @param protocol - The protocol to which the deposit is made.
     * @param onBehalfOf - The address on behalf of which the deposit is made.
     * @param token - The token to deposit.
     * @param amount - The amount of the token to deposit.
     */
    event Deposit(
        address indexed depositor,
        Chain chain,
        Protocol protocol,
        address indexed onBehalfOf,
        address token,
        uint256 amount
    );
    /**
     * Emitted when a deposit is aborted.
     * @param abortContext - The abort context.
     */
    event DepositAborted(AbortContext abortContext);
    /**
     * Emitted when a deposit is reverted.
     * @param revertContext - The revert context.
     */
    event DepositReverted(RevertContext revertContext);
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
     * Emitted when refunds are sent.
     * @param to - The address to send the refund to.
     * @param token - The token to refund.
     * @param amount - The amount of the token to refund.
     */
    event RefundSent(address indexed to, IERC20 indexed token, uint256 amount);
    /**
     * Emitted when a vault is updated.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @param vault - The address of the vault.
     */
    event VaultUpdated(Chain chain, Protocol protocol, address token, address indexed vault);
    /**
     * Emitted when tokens are withdrawn.
     * @param sender - The address of the sender.
     * @param chain - The chain from which the withdrawal is made.
     * @param protocol - The protocol from which the withdrawal is made.
     * @param to - The address to which the withdrawal is sent.
     * @param token - The token to withdraw.
     * @param amount - The amount of **shares** to withdraw.
     */
    event Withdraw(
        address indexed sender, Chain chain, Protocol protocol, address indexed to, address token, uint256 amount
    );
    /**
     * Emitted when a withdrawal is aborted.
     * @param abortContext - The abort context.
     */
    event WithdrawAborted(AbortContext abortContext);
    /**
     * Emitted when a withdrawal is aborted on an EVM.
     * @param abortContext - The abort context.
     */
    event WithdrawEVMAborted(AbortContext abortContext);
    /**
     * Emitted when a withdrawal is reverted.
     * @param revertContext - The revert context.
     */
    event WithdrawReverted(RevertContext revertContext);

    error InvalidAbort();
    error InvalidChain();
    error InvalidVault();
    error InvalidRevert();
    error NotGateway();
    error NotOwner();
    error NotUSDC();
    error TransferFailed();
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
     * Returns the GATEWAY contract address
     */
    function GATEWAY() external view returns (IGatewayZEVM);
    /**
     * Returns the SYSTEM_CONTRACT contract address
     */
    function SYSTEM_CONTRACT() external view returns (ISystemContract);
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
     * Adds a vault to the contract.
     * @dev Only callable by the owner.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @param vault - The address of the vault.
     */
    function addVault(Chain chain, Protocol protocol, address token, address vault) external payable;
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
     * Sends a refund.
     * @dev Only callable by the owner.
     * @param to - The address to send the refund to.
     * @param token - The token to refund.
     */
    function sendRefund(address to, IERC20 token) external payable;
    /**
     * Returns the owner of the contract.
     */
    function getOwner() external view returns (address);
    /**
     * Gets the vault address for the given parameters.
     * @param chain - The chain of the vault.
     * @param protocol - The protocol of the vault.
     * @param token - The token of the vault.
     * @return The address of the vault.
     */
    function getVault(Chain chain, Protocol protocol, address token) external view returns (address);
    /**
     * Gets the refunds for the given parameters.
     * @param to - The address of the recipient of the refunds.
     * @param token - The token of the refunds.
     */
    function getRefunds(address to, address token) external view returns (uint256);
}
