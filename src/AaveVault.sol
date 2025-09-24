// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IEVMEntry.sol";
import {IVault} from "./interfaces/IVault.sol";
import "./utils/AaveVaultStorage.sol";
import {Protocol} from "./utils/Types.sol";
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Callable, MessageContext} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

/**
 * @title AaveVault
 * @author https://github.com/nzmpi
 * @notice A vault for the Aave protocol.
 * @dev Can only be called from ZetaChain or EVMEntry.
 */
contract AaveVault is IVault, AaveVaultStorage, Callable, Initializable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    /// denominator for fee, 10000 == 100%
    uint256 internal constant SCALE = 10000;
    /// gas savings
    uint256 internal immutable CHAIN_ID = block.chainid;
    IPool internal immutable POOL;
    /// @inheritdoc IVault
    string public constant VERSION = "1.2.0";
    /// @inheritdoc IVault
    IERC20 public immutable TOKEN;
    /// @inheritdoc IVault
    IERC20 public immutable ASSET;
    /// @inheritdoc IVault
    IGatewayEVM public immutable GATEWAY;
    /// @inheritdoc IVault
    address public immutable YIELDMIL;
    /// @inheritdoc IVault
    address public immutable EVMENTRY;

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _getStorage().owner) revert NotOwner();
        _;
    }

    modifier onlyEVMEntry() {
        if (msg.sender != EVMENTRY) revert NotEVMEntry();
        _;
    }

    modifier onlyGuardian() {
        if (!_getStorage().guardians[msg.sender]) revert NotGuardian();
        _;
    }

    constructor(IPool _pool, IERC20 _token, IERC20 _asset, IGatewayEVM _gateway, address _yieldMil, address _evmentry)
        payable
    {
        _disableInitializers();
        if (
            address(_pool) == address(0) || address(_token) == address(0) || address(_asset) == address(0)
                || address(_gateway) == address(0) || _yieldMil == address(0) || _evmentry == address(0)
        ) revert ZeroAddress();
        POOL = _pool;
        TOKEN = _token;
        ASSET = _asset;
        GATEWAY = _gateway;
        YIELDMIL = _yieldMil;
        EVMENTRY = _evmentry;
    }

    /// @inheritdoc Callable
    function onCall(MessageContext calldata context, bytes calldata message)
        external
        payable
        onlyGateway
        returns (bytes memory)
    {
        if (context.sender != YIELDMIL) revert NotYieldMil();
        if (message[0] == hex"01") {
            _deposit(address(GATEWAY), message[1:message.length]);
        } else if (message[0] == hex"02") {
            _withdraw(message[1:message.length]);
        } else {
            revert InvalidMessage(message);
        }
        return "";
    }

    /// @inheritdoc IVault
    function deposit(bytes calldata message) external onlyEVMEntry returns (uint256 shares) {
        shares = _deposit(EVMENTRY, message);
    }

    /// @inheritdoc IVault
    function withdraw(bytes calldata message) external onlyEVMEntry {
        _withdraw(message);
    }

    /**
     * Reinitializes the vault for new versions.
     * @param reInitContext - The reinitialization context.
     */
    function reinitialize(ReInitContext calldata reInitContext)
        external
        payable
        onlyOwner
        reinitializer(reInitContext.version)
    {
        // remove approvals
        IERC20(TOKEN).approve(address(POOL), 0);
        IERC20(TOKEN).approve(address(GATEWAY), 0);

        uint256 len = reInitContext.guardians.length;
        address guardian;
        for (uint256 i; i < len; ++i) {
            guardian = reInitContext.guardians[i];
            if (guardian == address(0)) revert ZeroAddress();
            _getStorage().guardians[guardian] = true;
            emit GuardianUpdated(guardian, true);
        }
    }

    /// @inheritdoc IVault
    function pauseDeposit() external onlyGuardian {
        _getStorage().isDepositPaused = true;
        emit DepositPaused(msg.sender, block.timestamp);
    }

    /// @inheritdoc IVault
    function pauseWithdraw() external onlyGuardian {
        _getStorage().isWithdrawPaused = true;
        emit WithdrawPaused(msg.sender, block.timestamp);
    }

    /// @inheritdoc IVault
    function unpauseDeposit() external payable onlyOwner {
        delete _getStorage().isDepositPaused;
        emit DepositUnpaused(block.timestamp);
    }

    /// @inheritdoc IVault
    function unpauseWithdraw() external payable onlyOwner {
        delete _getStorage().isWithdrawPaused;
        emit WithdrawUnpaused(block.timestamp);
    }

    /// @inheritdoc IVault
    function updateGuardian(address guardian, bool status) external payable onlyOwner {
        _getStorage().guardians[guardian] = status;
        emit GuardianUpdated(guardian, status);
    }

    /// @inheritdoc IVault
    function setFee(uint256 newFee) external payable onlyOwner {
        _accrueYield();
        // cannot be more than 50%
        if (newFee > SCALE / 2) revert InvalidFee();
        _getStorage().fee = uint16(newFee);

        emit FeeUpdated(newFee);
    }

    /// @inheritdoc IVault
    function withdrawFees(address to) external payable onlyOwner {
        _accrueYield();
        Storage storage s = _getStorage();
        uint256 amount = s.accumulatedFees;
        delete s.accumulatedFees;
        ASSET.safeTransfer(to, amount);
        s.lastVaultBalance = ASSET.balanceOf(address(this));

        emit FeesWithdrawn(to, amount);
    }

    /// @inheritdoc IVault
    function transferOwnership(address newOwner) external payable onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _getStorage().owner = newOwner;

        emit OwnerUpdated(newOwner);
    }

    /// @inheritdoc IVault
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if ((token == ASSET || token == TOKEN) && !(_getStorage().isDepositPaused && _getStorage().isWithdrawPaused)) {
            revert VaultIsNotPaused();
        }
        emit FundsRescued(to, token, amount);

        if (address(token) == address(0)) {
            (bool s,) = to.call{value: amount}("");
            if (!s) revert TransferFailed();
        } else {
            token.safeTransfer(to, amount);
        }
    }

    /// @inheritdoc IVault
    function getPool() external view returns (address) {
        return address(POOL);
    }

    /// @inheritdoc IVault
    function getFee() external view returns (uint256) {
        return _getStorage().fee;
    }

    /// @inheritdoc IVault
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IVault
    function getAssetsAndShares(address owner) external view returns (uint256 assets, uint256 shares) {
        shares = _getStorage().shareBalanceOf[owner];
        assets = _convertToAssets(shares);
    }

    /// @inheritdoc IVault
    function getLastVaultBalance() external view returns (uint256) {
        return _getStorage().lastVaultBalance;
    }

    /// @inheritdoc IVault
    function getNonce(address sender) external view returns (uint256) {
        return _getStorage().nonces[sender];
    }

    /// @inheritdoc IVault
    function totalSupply() public view returns (uint256) {
        return _getStorage().totalShares;
    }

    /// @inheritdoc IVault
    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this)) - getAccumulatedFees();
    }

    /// @inheritdoc IVault
    function getAccumulatedFees() public view returns (uint256) {
        Storage storage s = _getStorage();
        uint256 newVaultBalance = ASSET.balanceOf(address(this));
        uint256 lastVaultBalance = s.lastVaultBalance;
        uint256 fee = s.fee;
        if (newVaultBalance <= lastVaultBalance || fee == 0) {
            return s.accumulatedFees;
        }

        uint256 newYield = newVaultBalance - lastVaultBalance;
        uint256 newFees = newYield.mulDiv(fee, SCALE, Math.Rounding.Floor);

        return s.accumulatedFees + newFees;
    }

    /**
     * Accrues yield.
     */
    function _accrueYield() internal {
        Storage storage s = _getStorage();
        uint256 newVaultBalance = ASSET.balanceOf(address(this));
        uint256 lastVaultBalance = s.lastVaultBalance;

        if (newVaultBalance <= lastVaultBalance) {
            return;
        }

        uint256 fee = s.fee;
        if (fee != 0) {
            uint256 newYield = newVaultBalance - lastVaultBalance;
            uint256 newFeesEarned = newYield.mulDiv(fee, SCALE, Math.Rounding.Floor);
            s.accumulatedFees += uint240(newFeesEarned);
        }

        s.lastVaultBalance = newVaultBalance;
    }

    /**
     * Deposits assets and mints shares.
     * @notice Reverts when deposit is paused.
     * @param sender - Sender - Gateway or EVMEntry.
     * @param message - Message containing depositor, onBehalfOf, amount and originChainId.
     */
    function _deposit(address sender, bytes calldata message) internal returns (uint256 shares) {
        if (_getStorage().isDepositPaused) revert DepositIsForbidden();
        (address depositor, address onBehalfOf, uint256 amount, uint256 originChainId) =
            abi.decode(message, (address, address, uint256, uint256));
        _accrueYield();
        shares = _convertToShares(amount);
        if (shares == 0) revert ZeroShares();

        TOKEN.safeTransferFrom(sender, address(this), amount);
        TOKEN.safeIncreaseAllowance(address(POOL), amount);
        POOL.supply(address(TOKEN), amount, address(this), 0);
        _getStorage().lastVaultBalance = ASSET.balanceOf(address(this));
        _mint(onBehalfOf, shares);

        emit Deposit(depositor, onBehalfOf, sender, amount, shares, originChainId);
    }

    /**
     * Withdraws assets from the pool, burns shares and sends tokens to a receiver or to EVMEntry.
     * @dev If user tries to withdraw more than they have, it will underflow.
     * @notice Reverts when withdraw is paused.
     * @param message - Message containing sender, receiver, shares, destinationChain,
     * deadline and signature.
     */
    function _withdraw(bytes calldata message) internal {
        if (_getStorage().isWithdrawPaused) revert WithdrawIsForbidden();
        (address sender, address receiver, uint256 shares, uint256 destinationChain) = _verifySignature(message);
        _accrueYield();
        uint256 amount = _convertToAssets(shares);
        if (amount == 0) revert ZeroAssets();

        _burn(sender, shares);
        amount = POOL.withdraw(address(TOKEN), amount, address(this));
        _getStorage().lastVaultBalance = ASSET.balanceOf(address(this));
        emit Withdraw(sender, receiver, amount, shares, destinationChain);

        if (destinationChain == CHAIN_ID) {
            TOKEN.safeTransfer(receiver, amount);
        } else {
            TOKEN.safeIncreaseAllowance(EVMENTRY, amount);
            bytes memory vaultMessage = abi.encode(sender, receiver, destinationChain);
            IEVMEntry(EVMENTRY).onCallback(sender, Protocol.Aave, address(TOKEN), amount, vaultMessage);
        }
    }

    /**
     * Mints shares for the receiver.
     */
    function _mint(address receiver, uint256 amount) internal {
        Storage storage s = _getStorage();
        s.totalShares += amount;
        s.shareBalanceOf[receiver] += amount;
    }

    /**
     * Burns shares for the receiver.
     */
    function _burn(address receiver, uint256 amount) internal {
        Storage storage s = _getStorage();
        s.totalShares -= amount;
        s.shareBalanceOf[receiver] -= amount;
    }

    /**
     * Verifies signature.
     * @param message - Message containing sender, receiver, shares, destinationChain, nonce,
     * deadline and signature.
     * @return sender, receiver, shares, destinationChain
     */
    function _verifySignature(bytes calldata message) internal returns (address, address, uint256, uint256) {
        (
            address sender,
            address receiver,
            uint256 shares,
            uint256 destinationChain,
            uint256 deadline,
            bytes memory signature
        ) = abi.decode(message, (address, address, uint256, uint256, uint256, bytes));
        if (deadline < block.timestamp) revert SignatureExpired();

        uint256 nonce = _getStorage().nonces[sender];
        bytes32 digest = keccak256(
            abi.encode(
                sender, receiver, shares, destinationChain, nonce, CHAIN_ID, address(this)
            )
        ).toEthSignedMessageHash();
        if (!sender.isValidSignatureNow(digest, signature)) revert InvalidSignature();

        _getStorage().nonces[sender] = nonce + 1;
        return (sender, receiver, shares, destinationChain);
    }

    /**
     * Converts assets to shares.
     */
    function _convertToShares(uint256 assets) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (assets == 0 || supply == 0) ? assets : assets.mulDiv(supply, totalAssets(), Math.Rounding.Floor);
    }

    /**
     * Converts shares to assets.
     */
    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        uint256 supply = totalSupply();
        return (supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, Math.Rounding.Floor);
    }
}
