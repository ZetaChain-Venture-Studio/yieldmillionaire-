// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IEVMEntry.sol";
import {IVault} from "./interfaces/IVault.sol";
import "./utils/EVMEntryStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISignatureTransfer} from "@permit2/interfaces/ISignatureTransfer.sol";
import {RevertOptions, Revertable} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

/**
 * @title EVMEntry
 * @notice Entry point for the EVM to deposit and withdraw tokens.
 * @author https://github.com/nzmpi
 */
contract EVMEntry is IEVMEntry, EVMEntryStorage, Revertable, Initializable {
    using SafeERC20 for IERC20;

    /// gas savings
    uint256 internal immutable CHAIN_ID = block.chainid;
    /// @inheritdoc IEVMEntry
    string public constant VERSION = "1.3.0";
    /// @inheritdoc IEVMEntry
    IGatewayEVM public immutable GATEWAY;
    /// @inheritdoc IEVMEntry
    IPermit2 public immutable PERMIT2;
    /// @inheritdoc IEVMEntry
    address public immutable YIELDMIL;
    /// @inheritdoc IEVMEntry
    address public immutable USDC;

    modifier onlyOwner() {
        if (msg.sender != _getStorage().owner) revert NotOwner();
        _;
    }

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    constructor(IGatewayEVM _gateway, IPermit2 _permit2, address _yieldMil, address _usdc) payable {
        _disableInitializers();
        if (
            address(_gateway) == address(0) || address(_permit2) == address(0) || _yieldMil == address(0)
                || _usdc == address(0)
        ) revert ZeroAddress();
        GATEWAY = _gateway;
        PERMIT2 = _permit2;
        YIELDMIL = _yieldMil;
        USDC = _usdc;
    }

    receive() external payable {}

    /**
     * Reinitializes the contract for new versions.
     * @param reInitContext - The reinitialization context.
     */
    function reinitialize(ReInitContext calldata reInitContext)
        external
        payable
        onlyOwner
        reinitializer(reInitContext.version)
    {
        // remove approvals
        IERC20(USDC).approve(address(GATEWAY), 0);
        uint256 len = reInitContext.vaults.length;
        for (uint256 i; i < len; ++i) {
            IERC20(USDC).approve(reInitContext.vaults[i], 0);
        }
    }

    /// @inheritdoc IEVMEntry
    function deposit(CallContext calldata context) external returns (uint256 shares) {
        address sender = context.sender;
        uint256 amount = context.amount;
        address token = context.token;
        if (
            context.targetChain == 0 || sender == address(0) || context.to == address(0) || token == address(0)
                || amount == 0
        ) {
            revert InvalidContext();
        }

        if (context.signature.length == 0) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
                nonce: context.nonce,
                deadline: context.deadline
            });
            ISignatureTransfer.SignatureTransferDetails memory transferDetails =
                ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount});
            PERMIT2.permitTransferFrom(permit, transferDetails, sender, context.signature);
        }
        emit Deposit(msg.sender, context);

        if (context.targetChain == CHAIN_ID) {
            address vault = _getStorage().vaults[_getKey(context.protocol, token)];
            if (vault == address(0)) revert InvalidVault();

            bytes memory message = abi.encode(sender, context.to, amount, CHAIN_ID);
            IERC20(token).safeIncreaseAllowance(vault, amount);
            shares = IVault(vault).deposit(message);
        } else {
            if (token != USDC) revert NotUSDC();
            bytes memory message = bytes.concat(hex"01", abi.encode(context));
            RevertOptions memory revertOptions = RevertOptions({
                revertAddress: address(this),
                callOnRevert: true,
                abortAddress: YIELDMIL,
                revertMessage: bytes.concat(hex"01", abi.encode(sender)),
                onRevertGasLimit: 250_000
            });
            IERC20(USDC).safeIncreaseAllowance(address(GATEWAY), amount);
            GATEWAY.depositAndCall(YIELDMIL, amount, token, message, revertOptions);
        }
    }

    /// @inheritdoc IEVMEntry
    function withdraw(CallContext calldata context) external payable {
        if (
            context.targetChain == 0 || context.to == address(0) || context.sender == address(0)
                || context.token == address(0) || context.amount == 0 || context.destinationChain == 0
                || context.signature.length == 0
        ) revert InvalidContext();

        emit Withdraw(msg.sender, context);

        if (context.targetChain == CHAIN_ID) {
            if (msg.value != 0) revert NotZeroValue();
            address vault = _getStorage().vaults[_getKey(context.protocol, context.token)];
            if (vault == address(0)) revert InvalidVault();

            bytes memory message = abi.encode(context);
            IVault(vault).withdraw(message);
        } else {
            bytes memory message = bytes.concat(hex"02", abi.encode(context));
            RevertOptions memory revertOptions;
            if (msg.value == 0) {
                GATEWAY.call(YIELDMIL, message, revertOptions);
            } else {
                revertOptions = RevertOptions({
                    revertAddress: address(this),
                    callOnRevert: true,
                    abortAddress: YIELDMIL,
                    revertMessage: bytes.concat(hex"02", abi.encode(context.sender)),
                    onRevertGasLimit: 250_000
                });
                GATEWAY.depositAndCall{value: msg.value}(YIELDMIL, message, revertOptions);
            }
        }
    }

    /// @inheritdoc IEVMEntry
    function onCallback(address sender, Protocol protocol, address token, uint256 amount, bytes calldata vaultMessage)
        external
    {
        address vault = _getStorage().vaults[_getKey(protocol, token)];
        if (msg.sender != vault) revert NotVault();

        IERC20(token).safeTransferFrom(vault, address(this), amount);
        bytes memory message = bytes.concat(hex"03", vaultMessage);
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: true,
            abortAddress: YIELDMIL,
            revertMessage: bytes.concat(hex"03", abi.encode(sender)),
            onRevertGasLimit: 250_000
        });
        IERC20(token).safeIncreaseAllowance(address(GATEWAY), amount);
        GATEWAY.depositAndCall(YIELDMIL, amount, token, message, revertOptions);
    }

    /// @inheritdoc Revertable
    function onRevert(RevertContext calldata revertContext) external onlyGateway {
        if (revertContext.sender != address(this)) revert NotEVMEntry();

        bytes1 flag = revertContext.revertMessage[0];
        if (flag == hex"01") {
            emit DepositReverted(revertContext);
        } else if (flag == hex"02" || flag == hex"03") {
            emit WithdrawReverted(revertContext);
        } else {
            revert InvalidRevertMessage(revertContext.revertMessage);
        }

        if (revertContext.amount != 0) {
            address sender = abi.decode(revertContext.revertMessage[1:revertContext.revertMessage.length], (address));
            if (revertContext.asset == address(0)) {
                (bool s,) = sender.call{value: revertContext.amount}("");
                if (!s) revert TransferFailed();
            } else {
                IERC20(revertContext.asset).safeTransfer(sender, revertContext.amount);
            }
        }
    }

    /// @inheritdoc IEVMEntry
    function updateVault(Protocol protocol, address token, address vault) external payable onlyOwner {
        _getStorage().vaults[_getKey(protocol, token)] = vault;
        emit VaultUpdated(protocol, token, vault);
    }

    /// @inheritdoc IEVMEntry
    function transferOwnership(address newOwner) external payable onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _getStorage().owner = newOwner;
        emit OwnerUpdated(newOwner);
    }

    /// @inheritdoc IEVMEntry
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        emit FundsRescued(to, token, amount);

        if (address(token) == address(0)) {
            (bool s,) = to.call{value: amount}("");
            if (!s) revert TransferFailed();
        } else {
            token.safeTransfer(to, amount);
        }
    }

    /// @inheritdoc IEVMEntry
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IEVMEntry
    function getVault(Protocol protocol, address token) external view returns (address) {
        return _getStorage().vaults[_getKey(protocol, token)];
    }

    /// @inheritdoc IEVMEntry
    function getAssetsAndShares(address owner, address token)
        external
        view
        returns (uint256[] memory assets, uint256[] memory shares)
    {
        uint256 len = uint256(type(Protocol).max) + 1;
        assets = new uint256[](len);
        shares = new uint256[](len);
        address vault;
        for (uint256 i; i < len; ++i) {
            vault = _getStorage().vaults[_getKey(Protocol(i), token)];
            if (vault == address(0)) {
                (assets[i], shares[i]) = (0, 0);
            } else {
                (assets[i], shares[i]) = IVault(vault).getAssetsAndShares(owner);
            }
        }
    }

    /**
     * Returns the key for the given protocol and token
     * @param protocol - The protocol
     * @param token - The token address
     */
    function _getKey(Protocol protocol, address token) internal pure returns (bytes32) {
        return keccak256(abi.encode(protocol, token));
    }
}
