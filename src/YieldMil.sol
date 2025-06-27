// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./YieldMilStorage.sol";
import "./interfaces/IYieldMil.sol";
import {SwapHelperLib} from "./utils/SwapHelperLib.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    Abortable, CallOptions, RevertOptions, Revertable
} from "@zetachain/contracts/zevm/interfaces/IGatewayZEVM.sol";
import "@zetachain/contracts/zevm/interfaces/IZRC20.sol";

/**
 * @title YieldMil
 * @author https://github.com/nzmpi
 * @notice An entry point for the YieldMil to deposit and withdraw tokens on supported chains
 */
contract YieldMil is IYieldMil, YieldMilStorage, Abortable, Revertable, Initializable {
    using SafeERC20 for IERC20;
    using SwapHelperLib for ISystemContract;

    /// @inheritdoc IYieldMil
    string public constant VERSION = "1.0.1";
    /// @inheritdoc IYieldMil
    IWETH9 public constant WZETA = IWETH9(0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf);
    /// @inheritdoc IYieldMil
    IGatewayZEVM public immutable GATEWAY;
    /// @inheritdoc IYieldMil
    ISystemContract public immutable SYSTEM_CONTRACT;
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

    constructor(
        IGatewayZEVM _gateway,
        ISystemContract _systemContract,
        address _usdcBase,
        address _ethBase,
        address _usdcPolygon,
        address _polPolygon
    ) payable {
        _disableInitializers();
        if (
            address(_gateway) == address(0) || address(_systemContract) == address(0) || _usdcBase == address(0)
                || _ethBase == address(0) || _usdcPolygon == address(0) || _polPolygon == address(0)
        ) revert ZeroAddress();
        GATEWAY = _gateway;
        SYSTEM_CONTRACT = _systemContract;
        USDC_BASE = _usdcBase;
        ETH_BASE = _ethBase;
        USDC_POLYGON = _usdcPolygon;
        POL_POLYGON = _polPolygon;
    }

    /// @inheritdoc IYieldMil
    function deposit(CallContext calldata context) external {
        if (context.token != _getUSDC(context.targetChain)) revert NotUSDC();
        bytes32 key = keccak256(abi.encode(context.targetChain, context.protocol, context.token));
        address vault = _getStorage().vaults[key];
        if (vault == address(0)) revert InvalidVault();
        uint256 amount = context.amount;
        if (amount == 0) revert ZeroAmount();

        IERC20(context.token).safeTransferFrom(msg.sender, address(this), amount);
        // Get the gas fee for the transfer
        (address gasZRC20, uint256 gasFee) = IZRC20(context.token).withdrawGasFeeWithGasLimit(context.gasLimit);
        amount -= SYSTEM_CONTRACT.swapTokensForExactTokens(context.token, amount, gasZRC20, gasFee);

        bytes memory message = bytes.concat(hex"01", abi.encode(msg.sender, context.to, amount));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: message,
            onRevertGasLimit: 100_000
        });

        GATEWAY.withdrawAndCall(
            bytes.concat(bytes20(vault)), amount, context.token, message, callOptions, revertOptions
        );

        emit Deposit(msg.sender, context.targetChain, context.protocol, context.to, context.token, amount);
    }

    /// @inheritdoc IYieldMil
    function withdraw(CallContext calldata context) external payable {
        if (context.token != _getUSDC(context.targetChain)) revert NotUSDC();
        bytes32 key = keccak256(abi.encode(context.targetChain, context.protocol, context.token));
        address vault = _getStorage().vaults[key];
        if (vault == address(0)) revert InvalidVault();
        uint256 amount = msg.value;
        if (amount == 0) revert ZeroAmount();

        WZETA.deposit{value: amount}();
        // Get the gas fee for the call
        address gasZRC20 = _getNative(context.targetChain);
        (, uint256 gasFee) = IZRC20(gasZRC20).withdrawGasFeeWithGasLimit(context.gasLimit);
        amount -= SYSTEM_CONTRACT.swapTokensForExactTokens(address(WZETA), amount, gasZRC20, gasFee);

        bytes memory message = bytes.concat(hex"02", abi.encode(msg.sender, context.to, context.amount));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: message,
            onRevertGasLimit: 100_000
        });

        GATEWAY.call(bytes.concat(bytes20(vault)), gasZRC20, message, callOptions, revertOptions);

        emit Withdraw(msg.sender, context.targetChain, context.protocol, context.to, context.token, context.amount);

        // Return excess funds
        if (amount != 0) {
            WZETA.withdraw(amount);
            (bool s,) = msg.sender.call{value: amount}("");
            if (!s) revert TransferFailed();
        }
    }

    /// @inheritdoc Revertable
    function onRevert(RevertContext calldata revertContext) external onlyGateway {
        if (revertContext.sender != address(this)) revert InvalidRevert();
        if (revertContext.revertMessage[0] == hex"01") {
            (address sender,,) = abi.decode(
                revertContext.revertMessage[1:revertContext.revertMessage.length], (address, address, uint256)
            );
            // return tokens to the original sender
            IERC20(revertContext.asset).safeTransfer(sender, revertContext.amount);
            emit DepositReverted(revertContext);
        } else if (revertContext.revertMessage[0] == hex"02") {
            emit WithdrawReverted(revertContext);
        } else {
            revert InvalidRevert();
        }
    }

    /// @inheritdoc Abortable
    function onAbort(AbortContext calldata abortContext) external onlyGateway {
        if (abortContext.outgoing) {
            if (address(bytes20(abortContext.sender)) != address(this)) revert InvalidAbort();
            if (abortContext.revertMessage[0] == hex"01") {
                (address sender,,) = abi.decode(
                    abortContext.revertMessage[1:abortContext.revertMessage.length], (address, address, uint256)
                );
                // return tokens to the original sender
                IERC20(abortContext.asset).safeTransfer(sender, abortContext.amount);
                emit DepositAborted(abortContext);
            } else if (abortContext.revertMessage[0] == hex"02") {
                emit WithdrawAborted(abortContext);
            } else {
                revert InvalidAbort();
            }
        } else {
            _getStorage().refunds[abi.decode(abortContext.revertMessage, (address))][abortContext.asset] +=
                abortContext.amount;
            emit WithdrawEVMAborted(abortContext);
        }
    }

    /// @inheritdoc IYieldMil
    function addVault(Chain chain, Protocol protocol, address token, address vault)
        external
        payable
        onlyOwner
        notZero(vault)
    {
        if (token != _getUSDC(chain)) revert NotUSDC();
        bytes32 key = keccak256(abi.encode(chain, protocol, token));
        _getStorage().vaults[key] = vault;
        emit VaultUpdated(chain, protocol, token, vault);
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
    function sendRefund(address to, IERC20 token) external payable onlyOwner {
        uint256 amount = _getStorage().refunds[to][address(token)];
        if (amount == 0) revert ZeroAmount();
        delete _getStorage().refunds[to][address(token)];
        token.safeTransfer(to, amount);
        emit RefundSent(to, token, amount);
    }

    /// @inheritdoc IYieldMil
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IYieldMil
    function getVault(Chain chain, Protocol protocol, address token) external view returns (address) {
        bytes32 key = keccak256(abi.encode(chain, protocol, token));
        return _getStorage().vaults[key];
    }

    /// @inheritdoc IYieldMil
    function getRefunds(address to, address token) external view returns (uint256) {
        return _getStorage().refunds[to][token];
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
        bytes32 key;
        for (uint256 i; i < len; ++i) {
            if (initContext.tokens[i] != _getUSDC(initContext.chains[i])) revert NotUSDC();
            if (initContext.vaults[i] == address(0)) revert ZeroAddress();
            key = keccak256(abi.encode(initContext.chains[i], initContext.protocols[i], initContext.tokens[i]));
            s.vaults[key] = initContext.vaults[i];
            emit VaultUpdated(
                initContext.chains[i], initContext.protocols[i], initContext.tokens[i], initContext.vaults[i]
            );
        }

        // Approve tokens for the gateway
        IZRC20(USDC_BASE).approve(address(GATEWAY), type(uint256).max);
        IZRC20(ETH_BASE).approve(address(GATEWAY), type(uint256).max);
        IZRC20(USDC_POLYGON).approve(address(GATEWAY), type(uint256).max);
        IZRC20(POL_POLYGON).approve(address(GATEWAY), type(uint256).max);
    }

    /**
     * Returns the USDC address for the given chain.
     * @param _chain - The chain.
     * @return The USDC address.
     */
    function _getUSDC(Chain _chain) internal view returns (address) {
        if (_chain == Chain.Base) {
            return USDC_BASE;
        } else if (_chain == Chain.Polygon) {
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
    function _getNative(Chain _chain) internal view returns (address) {
        if (_chain == Chain.Base) {
            return ETH_BASE;
        }
        if (_chain == Chain.Polygon) {
            return POL_POLYGON;
        } else {
            revert InvalidChain();
        }
    }
}
