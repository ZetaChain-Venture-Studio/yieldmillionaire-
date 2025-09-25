//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

/**
 * @title RefundVault
 * @author https://github.com/nzmpi
 * @notice A simple refund vault for ERC20 tokens
 */
contract RefundVault {
    using SafeERC20 for IERC20;
    using MessageHashUtils for bytes32;
    using SignatureChecker for address;

    uint256 internal immutable CHAIN_ID = block.chainid;

    mapping(address owner => mapping(IERC20 token => uint256 amount)) public refunds;
    mapping(address => uint256) public nonces;

    event RefundAdded(address indexed caller, address indexed owner, IERC20 token, uint256 amount);
    event RefundSent(address indexed caller, address indexed owner, address indexed to, IERC20 token, uint256 amount);

    error InvalidSignature();
    error SignatureExpired();
    error ZeroAddress();
    error ZeroAmount();

    /**
     * Caller can add a refund.
     * @param owner - The address of the owner of the refund.
     * @param token - The token of the refund.
     * @param amount - The amount of the refund.
     */
    function addRefunds(address owner, IERC20 token, uint256 amount) external {
        if (owner == address(0) || address(token) == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        token.safeTransferFrom(msg.sender, address(this), amount);
        refunds[owner][token] += amount;
        emit RefundAdded(msg.sender, owner, token, amount);
    }

    /**
     * Owner of the refund can withdraw their refund.
     * @param to - The address to send the refund to.
     * @param token - The token of the refund.
     * @param amount - The amount of the refund.
     */
    function withdrawRefunds(address to, IERC20 token, uint256 amount) external {
        if (to == address(0) || address(token) == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        refunds[msg.sender][token] -= amount;
        token.safeTransfer(to, amount);
        emit RefundSent(msg.sender, msg.sender, to, token, amount);
    }

    /**
     * Anyone can withdraw someone else's refund with a valid signature.
     * @param owner - The address of the owner of the refund.
     * @param to - The address to send the refund to.
     * @param token - The token of the refund.
     * @param amount - The amount of the refund.
     * @param deadline - The deadline of the signature.
     * @param signature - The signature.
     */
    function withdrawRefunds(
        address owner,
        address to,
        IERC20 token,
        uint256 amount,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (owner == address(0) || to == address(0) || address(token) == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (deadline < block.timestamp) revert SignatureExpired();

        uint256 nonce = nonces[owner];
        bytes32 digest = keccak256(abi.encode(owner, to, token, amount, nonce, CHAIN_ID, deadline, address(this)))
            .toEthSignedMessageHash();
        if (!owner.isValidSignatureNow(digest, signature)) revert InvalidSignature();

        nonces[owner] = nonce + 1;
        refunds[owner][token] -= amount;
        token.safeTransfer(to, amount);
        emit RefundSent(msg.sender, owner, to, token, amount);
    }
}
