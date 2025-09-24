// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../utils/Types.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "@permit2/interfaces/IPermit2.sol";
import {IGatewayEVM} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";
import {RevertContext} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

interface IEVMEntry {
    /**
     * A struct to store the context of the reinitialization call.
     * @param version - The version of the reinitialization call.
     * @param guardians - The guardians of the contract.
     */
    struct ReInitContext {
        uint64 version;
        address[] vaults;
    }

    /**
     * Emitted when a deposit is made
     * @param sender - The address of the sender
     * @param context - The deposit call context
     */
    event Deposit(address indexed sender, CallContext context);
    /**
     * Emitted when the deposit is reverted
     * @param revertContext - The revert context
     */
    event DepositReverted(RevertContext revertContext);
    /**
     * Emitted when funds are rescued
     * @param to - The address to send the funds to
     * @param token - The token to rescue
     * @param amount - The amount of funds to rescue
     */
    event FundsRescued(address to, IERC20 token, uint256 amount);
    /**
     * Emitted when the owner is updated
     * @param newOwner - The new owner address
     */
    event OwnerUpdated(address newOwner);
    /**
     * Emitted when the vault is updated
     * @param protocol - The protocol
     * @param token - The token address
     * @param vault - The vault address
     */
    event VaultUpdated(Protocol protocol, address token, address vault);
    /**
     * Emitted when a withdrawal is made
     * @param sender - The address of the sender
     * @param context - The withdrawal call context
     */
    event Withdraw(address indexed sender, CallContext context);
    /**
     * Emitted when the withdrawal is reverted
     * @param revertContext - The revert context
     */
    event WithdrawReverted(RevertContext revertContext);

    error InvalidContext();
    error InvalidRevertMessage(bytes);
    error InvalidVault();
    error NotGateway();
    error NotOwner();
    error NotUSDC();
    error NotVault();
    error NotEVMEntry();
    error NotZeroValue();
    error TransferFailed();
    error ZeroAddress();

    /**
     * Returns the current version of the contract
     */
    function VERSION() external view returns (string memory);
    /**
     * Returns the GATEWAY contract address
     */
    function GATEWAY() external view returns (IGatewayEVM);
    /**
     * Returns the PERMIT2 contract
     */
    function PERMIT2() external view returns (IPermit2);
    /**
     * Returns the YIELDMIL contract address
     */
    function YIELDMIL() external view returns (address);
    /**
     * Returns the USDC contract address
     */
    function USDC() external view returns (address);

    /**
     * Deposits funds into the vault or sends them to Zetachain.
     * @param context - The deposit call context.
     * @return shares - The amount of minted shares.
     */
    function deposit(CallContext calldata context) external returns (uint256 shares);
    /**
     * Withdraws funds from the vault or calls Zetachain to withdraw
     * @param context - The withdrawal call context
     */
    function withdraw(CallContext calldata context) external payable;
    /**
     * Called by a vault to send tokens to Zetachain
     * @param sender - The address of the sender
     * @param protocol - The protocol
     * @param token - The token
     * @param amount - The amount
     * @param vaultMessage - The vault message
     */
    function onCallback(address sender, Protocol protocol, address token, uint256 amount, bytes calldata vaultMessage)
        external;
    /**
     * Updates the vault address
     * @param protocol - The protocol
     * @param token - The token address
     * @param vault - The vault address
     */
    function updateVault(Protocol protocol, address token, address vault) external payable;
    /**
     * Transfers ownership
     * @param newOwner - The new owner address
     */
    function transferOwnership(address newOwner) external payable;
    /**
     * Rescues funds
     * @param to - The address to rescue to
     * @param token - The token to rescue
     * @param amount - The amount of funds to rescue
     */
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable;

    /**
     * Returns the current owner address
     */
    function getOwner() external view returns (address);
    /**
     * Returns the vault address
     * @param protocol - The protocol
     * @param token - The token address
     */
    function getVault(Protocol protocol, address token) external view returns (address);
    /**
     * Gets the assets and shares from all protocols that supports token deposits
     * @notice Returns an array of values for each protocol in the same order as listed in Protocol
     * @notice If a vault is not found, the assets and shares are set to 0
     * @param owner - The address of the owner
     * @param token - The token address
     * @return assets - The amount of assets, e.g. USDC
     * @return shares - The amount of shares in a vault
     */
    function getAssetsAndShares(address owner, address token)
        external
        view
        returns (uint256[] memory assets, uint256[] memory shares);
}
