// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./AaveVaultStorage.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Callable, MessageContext, RevertOptions} from "@zetachain/contracts/evm/interfaces/IGatewayEVM.sol";

/**
 * @title AaveVault
 * @author https://github.com/nzmpi
 * @notice A vault for the Aave protocol.
 * @dev Can only be called from ZetaChain.
 */
contract AaveVault is AaveVaultStorage, Callable, Initializable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /// denominator for fee, 10000 == 100%
    uint256 constant SCALE = 10000;
    /// @inheritdoc IAaveVault
    string public constant VERSION = "1.0.0";
    /// @inheritdoc IAaveVault
    IPool public immutable POOL;
    /// @inheritdoc IAaveVault
    IERC20 public immutable ASSET;
    /// @inheritdoc IAaveVault
    IERC20 public immutable ATOKEN;
    /// @inheritdoc IAaveVault
    IGatewayEVM public immutable GATEWAY;
    /// @inheritdoc IAaveVault
    address public immutable YIELDMIL;

    modifier onlyGateway() {
        if (msg.sender != address(GATEWAY)) revert NotGateway();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _getStorage().owner) revert NotOwner();
        _;
    }

    constructor(IPool _pool, IERC20 _asset, IERC20 _atoken, IGatewayEVM _gateway, address _yieldMil) payable {
        _disableInitializers();
        POOL = _pool;
        ASSET = _asset;
        ATOKEN = _atoken;
        GATEWAY = _gateway;
        YIELDMIL = _yieldMil;
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
            _deposit(message[1:message.length]);
        } else if (message[0] == hex"02") {
            _withdraw(message[1:message.length]);
        } else {
            revert InvalidMessage(message);
        }
        return "";
    }

    /**
     * Initializes the contract.
     * @param owner The address of the owner.
     * @param fee The fee.
     * @param amount The amount of tokens to deposit.
     */
    function initialize(address owner, uint16 fee, uint256 amount) external payable initializer {
        if (owner == address(0)) revert ZeroAddress();
        // cannot be more than 50%
        if (fee > SCALE / 2) revert InvalidFee();
        if (amount == 0) revert ZeroAssets();

        Storage storage s = _getStorage();
        s.owner = owner;
        s.fee = fee;
        emit OwnerUpdated(owner);
        emit FeeUpdated(fee);

        uint256 shares = _convertToShares(amount);
        if (shares == 0) revert ZeroShares();

        // Approve the pool and gateway
        IERC20(ASSET).approve(address(POOL), type(uint256).max);
        IERC20(ASSET).approve(address(GATEWAY), type(uint256).max);

        ASSET.safeTransferFrom(msg.sender, address(this), amount);
        POOL.supply(address(ASSET), amount, address(this), 0);
        _getStorage().lastVaultBalance = ATOKEN.balanceOf(address(this));
        _mint(owner, shares);

        emit Deposit(owner, amount, shares);
    }

    /// @inheritdoc IAaveVault
    function setFee(uint256 newFee) external payable onlyOwner {
        _accrueYield();
        // cannot be more than 50%
        if (newFee > SCALE / 2) revert InvalidFee();
        _getStorage().fee = uint16(newFee);

        emit FeeUpdated(newFee);
    }

    /// @inheritdoc IAaveVault
    function withdrawFees(address to) external payable onlyOwner {
        _accrueYield();
        Storage storage s = _getStorage();
        uint256 amount = s.accumulatedFees;
        delete s.accumulatedFees;
        ATOKEN.safeTransfer(to, amount);
        s.lastVaultBalance = ATOKEN.balanceOf(address(this));

        emit FeesWithdrawn(to, amount);
    }

    /// @inheritdoc IAaveVault
    function transferOwnership(address newOwner) external payable onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        _getStorage().owner = newOwner;

        emit OwnerUpdated(newOwner);
    }

    /// @inheritdoc IAaveVault
    function rescueFunds(address to, IERC20 token, uint256 amount) external payable onlyOwner {
        if (address(token) == address(0)) {
            (bool s,) = to.call{value: amount}("");
            if (!s) revert TransferFailed();
        } else {
            token.safeTransfer(to, amount);
        }
        emit FundsRescued(to, token, amount);
    }

    /// @inheritdoc IAaveVault
    function getFee() external view returns (uint256) {
        return _getStorage().fee;
    }

    /// @inheritdoc IAaveVault
    function getOwner() external view returns (address) {
        return _getStorage().owner;
    }

    /// @inheritdoc IAaveVault
    function getAssetsAndShares(address owner) external view returns (uint256 assets, uint256 shares) {
        shares = _getStorage().shareBalanceOf[owner];
        assets = _convertToAssets(shares);
    }

    /// @inheritdoc IAaveVault
    function getLastVaultBalance() external view returns (uint256) {
        return _getStorage().lastVaultBalance;
    }

    /// @inheritdoc IAaveVault
    function totalSupply() public view returns (uint256) {
        return _getStorage().totalShares;
    }

    /// @inheritdoc IAaveVault
    function totalAssets() public view returns (uint256) {
        return ATOKEN.balanceOf(address(this)) - getAccumulatedFees();
    }

    /// @inheritdoc IAaveVault
    function getAccumulatedFees() public view returns (uint256) {
        Storage storage s = _getStorage();
        uint256 newVaultBalance = ATOKEN.balanceOf(address(this));
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
        uint256 newVaultBalance = ATOKEN.balanceOf(address(this));
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
     * @param message - Message containing sender and amount.
     */
    function _deposit(bytes calldata message) internal {
        (address sender, uint256 amount) = abi.decode(message, (address, uint256));
        _accrueYield();
        uint256 shares = _convertToShares(amount);
        if (shares == 0) revert ZeroShares();

        ASSET.safeTransferFrom(address(GATEWAY), address(this), amount);
        POOL.supply(address(ASSET), amount, address(this), 0);
        _getStorage().lastVaultBalance = ATOKEN.balanceOf(address(this));
        _mint(sender, shares);

        emit Deposit(sender, amount, shares);
    }

    /**
     * Withdraws assets from the pool, burns shares and sends tokens to Zetachain.
     * @dev If user tries to withdraw more than they have, it will underflow.
     * @param message - Message containing sender and shares.
     */
    function _withdraw(bytes calldata message) internal {
        (address sender, uint256 shares) = abi.decode(message, (address, uint256));
        _accrueYield();
        uint256 amount = _convertToAssets(shares);
        if (amount == 0) revert ZeroAssets();

        _burn(sender, shares);
        amount = POOL.withdraw(address(ASSET), amount, address(this));
        _getStorage().lastVaultBalance = ATOKEN.balanceOf(address(this));
        _sendToZetachain(sender, amount);

        emit Withdraw(sender, amount, shares);
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
        return (supply == 0) ? shares : shares.mulDiv(totalAssets(), supply, Math.Rounding.Ceil);
    }

    /**
     * Sends tokens to Zetachain.
     */
    function _sendToZetachain(address receiver, uint256 amount) internal {
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(0),
            callOnRevert: false,
            abortAddress: YIELDMIL,
            revertMessage: abi.encode(receiver),
            onRevertGasLimit: 0
        });
        GATEWAY.deposit(receiver, amount, address(ASSET), revertOptions);
    }
}
