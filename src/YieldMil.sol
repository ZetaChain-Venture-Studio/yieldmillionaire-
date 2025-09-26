// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IYieldMil.sol";
import {SwapHelperLib} from "./utils/SwapHelperLib.sol";
import "./utils/YieldMilStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
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
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    /// gas savings
    uint256 internal immutable CHAIN_ID = block.chainid;
    bytes internal constant FEE_DATA = abi.encode(0, 0);
    address internal constant CURVE_ADAPTER = 0x03f876327F4dd491cA6BD9c4E33d60CA41EAEeF6;
    uint256 internal constant DECIMAL_DIFF = 1e12;
    /// @inheritdoc IYieldMil
    string public constant VERSION = "1.4.1";
    /// @inheritdoc IYieldMil
    IWETH9 public constant WZETA = IWETH9(0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf);
    /// @inheritdoc IYieldMil
    uint256 public constant BASE_CHAIN_ID = 8453;
    /// @inheritdoc IYieldMil
    uint256 public constant POLYGON_CHAIN_ID = 137;
    /// @inheritdoc IYieldMil
    uint256 public constant BNB_CHAIN_ID = 56;
    /// @inheritdoc IYieldMil
    IDODORouter public constant DODO_ROUTER = IDODORouter(0xDf25db6c8735E4238a86423D0380572505422BfD);
    /// @inheritdoc IYieldMil
    IGatewayZEVM public immutable GATEWAY;
    /// @inheritdoc IYieldMil
    RefundVault public immutable REFUND_VAULT;
    /// @inheritdoc IYieldMil
    address public immutable USDC_BASE;
    /// @inheritdoc IYieldMil
    address public immutable ETH_BASE;
    /// @inheritdoc IYieldMil
    address public immutable USDC_POLYGON;
    /// @inheritdoc IYieldMil
    address public immutable POL_POLYGON;
    /// @inheritdoc IYieldMil
    address public immutable USDC_BNB;
    /// @inheritdoc IYieldMil
    address public immutable BNB_BNB;

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _getStorage().owner) revert NotOwner();
        _;
    }

    modifier onlyGuardian() {
        if (!_getStorage().guardians[msg.sender]) revert NotGuardian();
        _;
    }

    modifier notZero(address input) {
        if (input == address(0)) revert ZeroAddress();
        _;
    }

    constructor(
        IGatewayZEVM _gateway,
        RefundVault _refundVault,
        address _usdcBase,
        address _ethBase,
        address _usdcPolygon,
        address _polPolygon,
        address _usdcBnb,
        address _bnbBnb
    ) payable {
        _disableInitializers();
        if (
            address(_gateway) == address(0) || address(_refundVault) == address(0) || _usdcBase == address(0)
                || _ethBase == address(0) || _usdcPolygon == address(0) || _polPolygon == address(0)
                || _usdcBnb == address(0) || _bnbBnb == address(0)
        ) revert ZeroAddress();
        GATEWAY = _gateway;
        REFUND_VAULT = _refundVault;
        USDC_BASE = _usdcBase;
        ETH_BASE = _ethBase;
        USDC_POLYGON = _usdcPolygon;
        POL_POLYGON = _polPolygon;
        USDC_BNB = _usdcBnb;
        BNB_BNB = _bnbBnb;
    }

    /**
     * Reinitializes the YieldMil for new versions.
     * @param reInitContext - The reinitialization context.
     */
    function reinitialize(ReInitContext calldata reInitContext)
        external
        payable
        onlyOwner
        reinitializer(reInitContext.version)
    {
        // remove approvals
        uint256 len = reInitContext.chains.length;
        uint256 chain;
        for (uint256 i; i < len; ++i) {
            chain = reInitContext.chains[i];
            IZRC20(_getUSDC(chain)).approve(address(GATEWAY), 0);
            IZRC20(_getNative(chain)).approve(address(GATEWAY), 0);
        }
    }

    /// @inheritdoc UniversalContract
    /// @dev Can only be called by an EVMEntry
    /// @dev 01 - deposit, 02 - withdraw, 03 - onCallback from EVMEntry
    function onCall(MessageContext calldata context, address zrc20, uint256 amount, bytes calldata message)
        external
        onlyGateway
    {
        if (_getStorage().EVMEntries[context.chainID] != context.senderEVM) revert InvalidEVMEntry();
        if (message[0] == hex"01") {
            CallContext memory callContext = abi.decode(message[1:message.length], (CallContext));
            callContext.token = _getUSDC(callContext.targetChain);
            callContext.amount = _swapUsdcs(zrc20, callContext.token, amount);
            _deposit(callContext, context.chainID);
        } else if (message[0] == hex"02") {
            CallContext memory callContext = abi.decode(message[1:message.length], (CallContext));
            callContext.token = _getUSDC(callContext.targetChain);
            amount = _withdraw(callContext, zrc20, amount, context.chainID);
            if (amount != 0) {
                IERC20(zrc20).safeIncreaseAllowance(address(REFUND_VAULT), amount);
                REFUND_VAULT.addRefunds(callContext.sender, IERC20(zrc20), amount);
                emit RefundAdded(callContext.sender, zrc20, amount);
            }
        } else if (message[0] == hex"03") {
            if (_getStorage().isWithdrawPaused) revert WithdrawIsForbidden();
            (address sender, address receiver, uint256 destinationChain) =
                abi.decode(message[1:message.length], (address, address, uint256));
            CallContext memory callContext;
            callContext.targetChain = context.chainID;
            callContext.to = receiver;
            callContext.destinationChain = destinationChain;
            if (destinationChain == CHAIN_ID) {
                IERC20(zrc20).safeTransfer(receiver, amount);
                callContext.token = zrc20;
                callContext.amount = amount;
            } else {
                address targetToken = _getUSDC(destinationChain);
                callContext.token = targetToken;
                amount = _swapUsdcs(zrc20, targetToken, amount);
                (address gasZRC20, uint256 gasFee) = IZRC20(targetToken).withdrawGasFeeWithGasLimit(100_000);
                callContext.gasLimit = 100_000;
                // If the contract doesn't have enough tokens, swap for it
                if (IZRC20(gasZRC20).balanceOf(address(this)) < gasFee) {
                    amount -= targetToken.swapTokensForExactTokens(amount, gasZRC20, gasFee);
                }
                callContext.amount = amount;
                RevertOptions memory revertOptions = RevertOptions({
                    revertAddress: address(this),
                    callOnRevert: true,
                    abortAddress: address(this),
                    revertMessage: message,
                    onRevertGasLimit: 250_000
                });

                IERC20(targetToken).safeIncreaseAllowance(address(GATEWAY), amount);
                IERC20(gasZRC20).safeIncreaseAllowance(address(GATEWAY), gasFee);
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
        if (msg.sender != context.sender) revert InvalidSender();

        if (context.amount == 0) revert ZeroAmount();
        IERC20(context.token).safeTransferFrom(msg.sender, address(this), context.amount);
        _deposit(context, CHAIN_ID);
    }

    /// @inheritdoc IYieldMil
    function withdraw(CallContext calldata context) external payable {
        if (context.token != _getUSDC(context.targetChain)) revert NotUSDC();
        if (msg.sender != context.sender) revert InvalidSender();

        uint256 amount = msg.value;
        // if amount is zero, sponsor the withdrawal
        if (amount != 0) {
            WZETA.deposit{value: amount}();
        }

        amount = _withdraw(context, address(WZETA), amount, CHAIN_ID);

        // Return excess funds
        if (amount != 0) {
            WZETA.withdraw(amount);
            (bool s,) = msg.sender.call{value: amount}("");
            if (!s) revert TransferFailed();
        }
    }

    /// @inheritdoc Revertable
    function onRevert(RevertContext calldata revertContext) external onlyGateway {
        address sender = revertContext.sender;
        if (sender != address(this)) revert InvalidRevert();

        bytes1 flag = revertContext.revertMessage[0];
        uint256 amount = revertContext.amount;
        if (amount != 0) {
            uint256 chainId;
            if (flag == hex"01") {
                (sender,,, chainId) = abi.decode(
                    revertContext.revertMessage[1:revertContext.revertMessage.length],
                    (address, address, uint256, uint256)
                );
            } else if (flag == hex"03") {
                (sender,, chainId) = abi.decode(
                    revertContext.revertMessage[1:revertContext.revertMessage.length], (address, address, uint256)
                );
            } else {
                revert InvalidRevert();
            }

            if (chainId == CHAIN_ID) {
                // return tokens to the original sender
                IERC20(revertContext.asset).safeTransfer(sender, amount);
            } else {
                address asset = revertContext.asset;
                IERC20(asset).safeIncreaseAllowance(address(REFUND_VAULT), amount);
                REFUND_VAULT.addRefunds(sender, IERC20(asset), amount);
                emit RefundAdded(sender, asset, amount);
            }
        }

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
        bytes1 flag = abortContext.revertMessage[0];
        uint256 amount = abortContext.amount;
        if (amount != 0) {
            address sender = address(bytes20(abortContext.sender));
            address receiver;
            if (sender == address(this)) {
                if (flag == hex"01") {
                    (receiver,,,) = abi.decode(
                        abortContext.revertMessage[1:abortContext.revertMessage.length],
                        (address, address, uint256, uint256)
                    );
                } else if (flag == hex"03") {
                    (receiver,,) = abi.decode(
                        abortContext.revertMessage[1:abortContext.revertMessage.length], (address, address, uint256)
                    );
                } else {
                    revert InvalidAbort();
                }
            } else if (sender == _getStorage().EVMEntries[abortContext.chainID]) {
                receiver = abi.decode(abortContext.revertMessage[1:abortContext.revertMessage.length], (address));
            } else {
                revert InvalidAbort();
            }

            address asset = abortContext.asset;
            IERC20(asset).safeIncreaseAllowance(address(REFUND_VAULT), amount);
            REFUND_VAULT.addRefunds(receiver, IERC20(asset), amount);
            emit RefundAdded(receiver, asset, amount);
        }

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
    function pauseDeposit() external onlyGuardian {
        _getStorage().isDepositPaused = true;
        emit DepositPaused(msg.sender, block.timestamp);
    }

    /// @inheritdoc IYieldMil
    function pauseWithdraw() external onlyGuardian {
        _getStorage().isWithdrawPaused = true;
        emit WithdrawPaused(msg.sender, block.timestamp);
    }

    /// @inheritdoc IYieldMil
    function unpauseDeposit() external payable onlyOwner {
        delete _getStorage().isDepositPaused;
        emit DepositUnpaused(block.timestamp);
    }

    /// @inheritdoc IYieldMil
    function unpauseWithdraw() external payable onlyOwner {
        delete _getStorage().isWithdrawPaused;
        emit WithdrawUnpaused(block.timestamp);
    }

    /// @inheritdoc IYieldMil
    function updateGuardian(address guardian, bool status) external payable onlyOwner {
        _getStorage().guardians[guardian] = status;
        emit GuardianUpdated(guardian, status);
    }

    /// @inheritdoc IYieldMil
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IYieldMil
    function isGuardian(address guardian) external view returns (bool) {
        return _getStorage().guardians[guardian];
    }

    /// @inheritdoc IYieldMil
    function getVault(uint256 chain, Protocol protocol, address token) external view returns (address) {
        return _getStorage().vaults[_getKey(chain, protocol, token)];
    }

    /// @inheritdoc IYieldMil
    function getEVMEntry(uint256 chainId) external view returns (address) {
        return _getStorage().EVMEntries[chainId];
    }

    /**
     * Deposits the tokens to the vault on an EVM.
     * @dev Reverts if the vault does not exist.
     * @param context - The deposit call context.
     * @param chainId - The original chain id.
     */
    function _deposit(CallContext memory context, uint256 chainId) internal {
        if (_getStorage().isDepositPaused) revert DepositIsForbidden();

        address token = context.token;
        address vault = _getStorage().vaults[_getKey(context.targetChain, context.protocol, token)];
        if (vault == address(0)) revert InvalidVault();

        // Get the gas fee for the transfer
        (address gasZRC20, uint256 gasFee) = IZRC20(token).withdrawGasFeeWithGasLimit(context.gasLimit);
        uint256 amount = context.amount;
        // If the contract doesn't have enough tokens, swap for it
        if (IZRC20(gasZRC20).balanceOf(address(this)) < gasFee) {
            amount -= token.swapTokensForExactTokens(amount, gasZRC20, gasFee);
        }

        bytes memory message = bytes.concat(hex"01", abi.encode(context.sender, context.to, amount, chainId));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: message,
            onRevertGasLimit: 250_000
        });

        emit Deposit(context.sender, context.targetChain, context.protocol, context.to, token, amount, chainId);

        IERC20(token).safeIncreaseAllowance(address(GATEWAY), amount);
        IERC20(gasZRC20).safeIncreaseAllowance(address(GATEWAY), gasFee);
        GATEWAY.withdrawAndCall(bytes.concat(bytes20(vault)), amount, token, message, callOptions, revertOptions);
    }

    /**
     * Withdraws the tokens from the vault on an EVM.
     * @dev Reverts if the vault does not exist.
     * @param context - The withdrawal call context.
     * @param tokenForFee - The token for the gas fee.
     * @param amount - The amount.
     * @param chainId - The original chain id.
     */
    function _withdraw(CallContext memory context, address tokenForFee, uint256 amount, uint256 chainId)
        internal
        returns (uint256)
    {
        if (_getStorage().isWithdrawPaused) revert WithdrawIsForbidden();
        address vault = _getStorage().vaults[_getKey(context.targetChain, context.protocol, context.token)];
        if (vault == address(0)) revert InvalidVault();
        _verifySignature(context, vault);

        // Get the gas fee for the call
        address gasZRC20 = _getNative(context.targetChain);
        (, uint256 gasFee) = IZRC20(gasZRC20).withdrawGasFeeWithGasLimit(context.gasLimit);
        // If the contract doesn't have enough tokens, swap for it
        if (IZRC20(gasZRC20).balanceOf(address(this)) < gasFee) {
            amount -= tokenForFee.swapTokensForExactTokens(amount, gasZRC20, gasFee);
        }

        bytes memory message = bytes.concat(hex"02", abi.encode(context));
        CallOptions memory callOptions = CallOptions({gasLimit: context.gasLimit, isArbitraryCall: false});
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: address(this),
            revertMessage: abi.encode(message, chainId),
            onRevertGasLimit: 250_000
        });

        emit Withdraw(context.sender, context, chainId);

        IERC20(gasZRC20).safeIncreaseAllowance(address(GATEWAY), gasFee);
        GATEWAY.call(bytes.concat(bytes20(vault)), gasZRC20, message, callOptions, revertOptions);

        return amount;
    }

    /**
     * Verifies signature.
     * @param _context - The call context.
     * @param _vault - The vault address.
     */
    function _verifySignature(CallContext memory _context, address _vault) internal view {
        if (_context.deadline < block.timestamp) revert SignatureExpired();

        bytes32 digest = keccak256(
            abi.encode(
                _context.sender,
                _context.to,
                _context.amount,
                _context.destinationChain,
                _context.nonce,
                _context.targetChain,
                _context.deadline,
                _vault
            )
        ).toEthSignedMessageHash();
        if (!_context.sender.isValidSignatureNow(digest, _context.signature)) revert InvalidSignature();
    }

    /**
     * Swaps USDCs via DODO.
     * @dev will revert with non USDC tokens.
     * @param fromToken - The token to swap from.
     * @param toToken - The token to swap to.
     * @param amount - The amount to swap.
     * @return The amount of tokens received.
     */
    function _swapUsdcs(address fromToken, address toToken, uint256 amount) internal returns (uint256) {
        address[] memory mixAdapters = new address[](1);
        mixAdapters[0] = CURVE_ADAPTER;
        address[] memory mixPairs = new address[](1);
        // usdc7 pool
        mixPairs[0] = 0x0a914379955E56fc7732E5d6Fc0A6f94B44fD590;
        address[] memory assetTo = new address[](2);
        assetTo[0] = CURVE_ADAPTER;
        assetTo[1] = address(DODO_ROUTER);
        bytes[] memory moreInfos = new bytes[](1);
        moreInfos[0] = abi.encode(true, fromToken, toToken, _getIndex(fromToken), _getIndex(toToken));
        // 0.5% slippage
        uint256 minReturnAmount;
        uint256 expReturnAmount;
        if (fromToken == USDC_BNB) {
            minReturnAmount = amount * 995 / 1000 / DECIMAL_DIFF;
            expReturnAmount = amount / DECIMAL_DIFF;
        } else if (toToken == USDC_BNB) {
            minReturnAmount = amount * 995 * DECIMAL_DIFF / 1000;
            expReturnAmount = amount * DECIMAL_DIFF;
        } else {
            minReturnAmount = amount * 995 / 1000;
            expReturnAmount = amount;
        }

        IERC20(fromToken).safeIncreaseAllowance(0x3a5980966a8774b357A807231F87F7FD792Ff6F9, amount);
        uint256 balanceBefore = IERC20(toToken).balanceOf(address(this));
        DODO_ROUTER.mixSwap({
            fromToken: fromToken,
            toToken: toToken,
            fromTokenAmount: amount,
            expReturnAmount: expReturnAmount,
            minReturnAmount: minReturnAmount,
            mixAdapters: mixAdapters,
            mixPairs: mixPairs,
            assetTo: assetTo,
            directions: 1,
            moreInfos: moreInfos,
            feeData: FEE_DATA,
            deadLine: block.timestamp + 200
        });
        uint256 amountReceived = IERC20(toToken).balanceOf(address(this)) - balanceBefore;
        if (amountReceived < minReturnAmount) revert BadSwap(amountReceived);

        return amountReceived;
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
        } else if (_chain == BNB_CHAIN_ID) {
            return USDC_BNB;
        } else {
            revert InvalidChain();
        }
    }

    /**
     * Returns the index for the given token for the CURVE pool.
     * @param token - The token.
     * @return The index.
     */
    function _getIndex(address token) internal view returns (uint256) {
        if (token == USDC_BASE) {
            return 3;
        } else if (token == USDC_POLYGON) {
            return 6;
        } else if (token == USDC_BNB) {
            return 4;
        } else {
            revert NotUSDC();
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
        } else if (_chain == POLYGON_CHAIN_ID) {
            return POL_POLYGON;
        } else if (_chain == BNB_CHAIN_ID) {
            return BNB_BNB;
        } else {
            revert InvalidChain();
        }
    }
}
