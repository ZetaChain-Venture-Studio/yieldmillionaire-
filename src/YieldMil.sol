// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IYieldMil.sol";
import {SwapHelperLib} from "./utils/SwapHelperLib.sol";
import "./utils/YieldMilStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Abortable, CallOptions, RevertOptions, Revertable
} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";
import "@zetachain/contracts/zevm/interfaces/IZRC20.sol";
import {MessageContext, UniversalContract} from "@zetachain/contracts/zevm/interfaces/UniversalContract.sol";

/**
 * @title YieldMil
 * @author https://github.com/nzmpi
 * @notice An entry point for the YieldMil to deposit and withdraw tokens on supported chains
 */
contract YieldMil is IYieldMil, YieldMilStorage, UniversalContract, Abortable, Revertable, Initializable {
    using SafeERC20 for IERC20;
    using SwapHelperLib for address;

    /// @inheritdoc IYieldMil
    string public constant VERSION = "1.1.0";
    /// @inheritdoc IYieldMil
    IWETH9 public constant WZETA = IWETH9(0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf);
    /// @inheritdoc IYieldMil
    uint256 public constant BASE_CHAIN_ID = 8453;
    /// @inheritdoc IYieldMil
    uint256 public constant POLYGON_CHAIN_ID = 137;
    /// @inheritdoc IYieldMil
    IGatewayZEVM public immutable GATEWAY;
    /// @inheritdoc IYieldMil
    address public immutable USDC_BASE;
    /// @inheritdoc IYieldMil
    address public immutable ETH_BASE;
    /// @inheritdoc IYieldMil
    address public immutable USDC_POLYGON;
    /// @inheritdoc IYieldMil
    address public immutable POL_POLYGON;

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _getStorage().owner) revert NotOwner();
        _;
    }

    modifier notZero(address input) {
        if (input == address(0)) revert ZeroAddress();
        _;
    }

    constructor(IGatewayZEVM _gateway, address _usdcBase, address _ethBase, address _usdcPolygon, address _polPolygon)
        payable
    {
        _disableInitializers();
        if (
            address(_gateway) == address(0) || _usdcBase == address(0) || _ethBase == address(0)
                || _usdcPolygon == address(0) || _polPolygon == address(0)
        ) revert ZeroAddress();
        GATEWAY = _gateway;
        USDC_BASE = _usdcBase;
        ETH_BASE = _ethBase;
        USDC_POLYGON = _usdcPolygon;
        POL_POLYGON = _polPolygon;
    }

    /**
     * Initializes the YieldMil.
     * @param initContext - The initialization context.
     */
    function initialize(InitContext calldata initContext) external payable initializer notZero(initContext.owner) {
        Storage storage s = _getStorage();
        s.owner = initContext.owner;
        emit OwnerUpdated(initContext.owner);

        uint256 len = initContext.chains.length;
        if (len != initContext.protocols.length || len != initContext.vaults.length || len != initContext.tokens.length)
        {
            revert InvalidInitialization();
        }
        for (uint256 i; i < len; ++i) {
            if (initContext.tokens[i] != _getUSDC(initContext.chains[i])) revert NotUSDC();
            if (initContext.vaults[i] == address(0)) revert ZeroAddress();
            s.vaults[_getKey(initContext.chains[i], initContext.protocols[i], initContext.tokens[i])] =
                initContext.vaults[i];
            emit VaultUpdated(
                initContext.chains[i], initContext.protocols[i], initContext.tokens[i], initContext.vaults[i]
            );
        }

        len = initContext.EVMEntryChains.length;
        if (len != initContext.EVMEntries.length) revert InvalidInitialization();
        for (uint256 i; i < len; ++i) {
            if (initContext.EVMEntries[i] == address(0)) revert ZeroAddress();
            s.EVMEntries[initContext.EVMEntryChains[i]] = initContext.EVMEntries[i];
            emit EVMEntryUpdated(initContext.EVMEntryChains[i], initContext.EVMEntries[i]);
        }

        // Approve tokens for the gateway
        IZRC20(USDC_BASE).approve(address(GATEWAY), type(uint256).max);
        IZRC20(ETH_BASE).approve(address(GATEWAY), type(uint256).max);
        IZRC20(USDC_POLYGON).approve(address(GATEWAY), type(uint256).max);
        IZRC20(POL_POLYGON).approve(address(GATEWAY), type(uint256).max);
    }

    /// @inheritdoc UniversalContract
    function onCall(MessageContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        onlyGateway
    {
        if (_getStorage().EVMEntries[context.chainID] != context.senderEVM) revert InvalidEVMEntry();
        if (message[0] == hex"01") {
            (address sender, CallContext memory callContext) =
                abi.decode(message[1:message.length], (address, CallContext));
            callContext.token = _getUSDC(callContext.targetChain);
            // TODO: this slippage only works for USDCs
            callContext.amount = zrc20.swapExactTokensForTokens(amount, callContext.token, amount * 95 / 100);
            _deposit(sender, callContext, context.chainID);
        } else if (message[0] == hex"02") {
            (address sender, CallContext memory callContext) =
                abi.decode(message[1:message.length], (address, CallContext));
            callContext.token = _getUSDC(callContext.targetChain);
            amount = _withdraw(sender, callContext, zrc20, amount, context.chainID);
            if (amount != 0) {
                _getStorage().refunds[sender][zrc20] += amount;
                emit RefundAdded(sender, zrc20, amount);
            }
        } else if (message[0] == hex"03") {
            (address sender, address receiver, uint256 destinationChain) =
                abi.decode(message[1:message.length], (address, address, uint256));
            CallContext memory callContext;
            callContext.targetChain = context.chainID;
            callContext.to = receiver;
            callContext.destinationChain = destinationChain;
            if (destinationChain == block.chainid) {
                IERC20(zrc20).safeTransfer(receiver, amount);
                callContext.token = zrc20;
                callContext.amount = amount;
            } else {
                address targetToken = _getUSDC(destinationChain);
                callContext.token = targetToken;
                amount = zrc20.swapExactTokensForTokens(amount, targetToken, amount * 95 / 100);
                (address gasZRC20, uint256 gasFee) = IZRC20(targetToken).withdrawGasFeeWithGasLimit(70_000);
                callContext.gasLimit = 70_000;
                amount -= targetToken.swapTokensForExactTokens(amount, gasZRC20, gasFee);
                callContext.amount = amount;
                RevertOptions memory revertOptions = RevertOptions({
                    revertAddress: address(this),
                    callOnRevert: true,
                    abortAddress: address(this),
                    revertMessage: message,
                    onRevertGasLimit: 250_000
                });
                GATEWAY.withdraw(bytes.concat(bytes20(receiver)), amount, targetToken, revertOptions);
            }
            emit Withdraw(sender, callContext, context.chainID);
        } else {
            revert InvalidMessage(message);
        }
    }

    /// @inheritdoc IYieldMil
    function deposit(CallContext calldata context) external {
        if (context.token != _getUSDC(context.targetChain)) revert NotUSDC();
        uint256 amount = context.amount;
        if (amount == 0) revert ZeroAmount();
        IERC20(context.token).safeTransferFrom(msg.sender, address(this), amount);
        _deposit(msg.sender, context, block.chainid);
    }

    /// @inheritdoc IYieldMil
    function withdraw(CallContext calldata context) external payable {
        if (context.token != _getUSDC(context.targetChain)) revert NotUSDC();

        uint256 amount = msg.value;
        if (amount == 0) revert ZeroAmount();

        WZETA.deposit{value: amount}();
        amount = _withdraw(msg.sender, context, address(WZETA), amount, block.chainid);

        // Return excess funds
        if (amount != 0) {
            WZETA.withdraw(amount);
            (bool s,) = msg.sender.call{value: amount}("");
            if (!s) revert TransferFailed();
        }
    }

    /// @inheritdoc IYieldMil
    function withdrawRefunds(address to, address token) external {
        uint256 amount = _getStorage().refunds[msg.sender][token];
        if (amount == 0) revert ZeroAmount();
        delete _getStorage().refunds[msg.sender][token];
        IERC20(token).safeTransfer(to, amount);
        emit RefundSent(msg.sender, to, token, amount);
    }

    /// @inheritdoc Revertable
    function onRevert(RevertContext calldata revertContext) external onlyGateway {
        if (revertContext.sender != address(this)) revert InvalidRevert();

        if (revertContext.amount != 0) {
            (address sender,,, uint256 chainId) = abi.decode(
                revertContext.revertMessage[1:revertContext.revertMessage.length], (address, address, uint256, uint256)
            );
            if (chainId == block.chainid) {
                // return tokens to the original sender
                IERC20(revertContext.asset).safeTransfer(sender, revertContext.amount);
            } else {
                _getStorage().refunds[sender][revertContext.asset] += revertContext.amount;
                emit RefundAdded(sender, revertContext.asset, revertContext.amount);
            }
        }

        bytes1 flag = revertContext.revertMessage[0];
        if (flag == hex"01") {
            emit DepositReverted(revertContext);
        } else if (flag == hex"02" || flag == hex"03") {
            emit WithdrawReverted(revertContext);
        } else {
            revert InvalidRevert();
        }
    }

    /// @inheritdoc Abortable
    function onAbort(AbortContext calldata abortContext) external onlyGateway {
        uint256 amount = abortContext.amount;
        if (amount != 0) {
            address sender = address(bytes20(abortContext.sender));
            address receiver;
            if (sender == address(this)) {
                (receiver,,,) = abi.decode(
                    abortContext.revertMessage[1:abortContext.revertMessage.length],
                    (address, address, uint256, uint256)
                );
            } else if (sender == _getStorage().EVMEntries[abortContext.chainID]) {
                receiver = abi.decode(abortContext.revertMessage[1:abortContext.revertMessage.length], (address));
            } else {
                revert InvalidAbort();
            }
            _getStorage().refunds[receiver][abortContext.asset] += amount;
            emit RefundAdded(receiver, abortContext.asset, amount);
        }

        bytes1 flag = abortContext.revertMessage[0];
        if (flag == hex"01") {
            emit DepositAborted(abortContext);
        } else if (flag == hex"02" || flag == hex"03") {
            emit WithdrawAborted(abortContext);
        }
    }

    /// @inheritdoc IYieldMil
    function updateVault(uint256 chain, Protocol protocol, address token, address vault) external payable onlyOwner {
        if (token != _getUSDC(chain)) revert NotUSDC();
        _getStorage().vaults[_getKey(chain, protocol, token)] = vault;
        emit VaultUpdated(chain, protocol, token, vault);
    }

    /// @inheritdoc IYieldMil
    function updateEVMEntry(uint256 chainId, address EVMEntry) external payable onlyOwner {
        _getStorage().EVMEntries[chainId] = EVMEntry;
        emit EVMEntryUpdated(chainId, EVMEntry);
    }

    /// @inheritdoc IYieldMil
    function transferOwnership(address newOwner) external payable onlyOwner notZero(newOwner) {
        _getStorage().owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    /// @inheritdoc IYieldMil
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (address(token) == address(0)) {
            (bool s,) = to.call{value: amount}("");
            if (!s) revert TransferFailed();
        } else {
            token.safeTransfer(to, amount);
        }
        emit FundsRescued(to, token, amount);
    }

    /// @inheritdoc IYieldMil
    function sendRefund(address from, address to, address token) external payable onlyOwner {
        uint256 amount = _getStorage().refunds[from][token];
        if (amount == 0) revert ZeroAmount();
        delete _getStorage().refunds[from][token];
        IERC20(token).safeTransfer(to, amount);
        emit RefundSent(from, to, token, amount);
    }

    /// @inheritdoc IYieldMil
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IYieldMil
    function getVault(uint256 chain, Protocol protocol, address token) external view returns (address) {
        return _getStorage().vaults[_getKey(chain, protocol, token)];
    }

    /// @inheritdoc IYieldMil
    function getEVMEntry(uint256 chainId) external view returns (address) {
        return _getStorage().EVMEntries[chainId];
    }

    /// @inheritdoc IYieldMil
    function getRefunds(address from, address token) external view returns (uint256) {
        return _getStorage().refunds[from][token];
    }

    /**
     * Deposits the tokens to the vault on an EVM.
     * @dev Reverts if the vault does not exist
     * @param sender - The address of the original sender
     * @param context - The deposit call context
     * @param chainId - The original chain id
     */
    function _deposit(address sender, CallContext memory context, uint256 chainId) internal {
        address token = context.token;
        address vault = _getStorage().vaults[_getKey(context.targetChain, context.protocol, token)];
        if (vault == address(0)) revert InvalidVault();

        // Get the gas fee for the transfer
        (address gasZRC20, uint256 gasFee) = IZRC20(token).withdrawGasFeeWithGasLimit(context.gasLimit);
        uint256 amount = context.amount;
        amount -= token.swapTokensForExactTokens(amount, gasZRC20, gasFee);

        bytes memory message = bytes.concat(hex"01", abi.encode(sender, context.to, amount, chainId));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: message,
            onRevertGasLimit: 250_000
        });

        emit Deposit(sender, context.targetChain, context.protocol, context.to, token, amount, chainId);

        GATEWAY.withdrawAndCall(bytes.concat(bytes20(vault)), amount, token, message, callOptions, revertOptions);
    }

    /**
     * Withdraws the tokens from the vault on an EVM.
     * @dev Reverts if the vault does not exist
     * @param sender - The address of the original sender
     * @param context - The withdrawal call context
     * @param tokenForFee - The token for the gas fee
     * @param amount - The amount
     * @param chainId - The original chain id
     */
    function _withdraw(address sender, CallContext memory context, address tokenForFee, uint256 amount, uint256 chainId)
        internal
        returns (uint256)
    {
        address vault = _getStorage().vaults[_getKey(context.targetChain, context.protocol, context.token)];
        if (vault == address(0)) revert InvalidVault();
        // Get the gas fee for the call
        address gasZRC20 = _getNative(context.targetChain);
        (, uint256 gasFee) = IZRC20(gasZRC20).withdrawGasFeeWithGasLimit(context.gasLimit);
        amount -= tokenForFee.swapTokensForExactTokens(amount, gasZRC20, gasFee);

        bytes memory message =
            bytes.concat(hex"02", abi.encode(sender, context.to, context.amount, context.destinationChain));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: abi.encode(message, chainId),
            onRevertGasLimit: 250_000
        });

        emit Withdraw(sender, context, chainId);

        GATEWAY.call(bytes.concat(bytes20(vault)), gasZRC20, message, callOptions, revertOptions);

        return amount;
    }

    /**
     * Returns the key for the given chain, protocol and token.
     * @param chain - The chain.
     * @param protocol - The protocol.
     * @param token - The token.
     * @return The key.
     */
    function _getKey(uint256 chain, Protocol protocol, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(chain, protocol, token));
    }

    /**
     * Returns the USDC address for the given chain.
     * @param _chain - The chain.
     * @return The USDC address.
     */
    function _getUSDC(uint256 _chain) internal view returns (address) {
        if (_chain == BASE_CHAIN_ID) {
            return USDC_BASE;
        } else if (_chain == POLYGON_CHAIN_ID) {
            return USDC_POLYGON;
        } else {
            revert InvalidChain();
        }
    }

    /**
     * Returns the native token address for the given chain.
     * @param _chain - The chain.
     * @return The native token address.
     */
    function _getNative(uint256 _chain) internal view returns (address) {
        if (_chain == BASE_CHAIN_ID) {
            return ETH_BASE;
        }
        if (_chain == POLYGON_CHAIN_ID) {
            return POL_POLYGON;
        } else {
            revert InvalidChain();
        }
    }
}
