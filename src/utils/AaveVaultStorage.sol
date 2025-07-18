// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title AaveVaultStorage
 * @author https://github.com/nzmpi
 * @notice A storage contract for the AaveVault
 */
contract AaveVaultStorage {
    // EIP-7201: keccak256(abi.encode(uint256(keccak256("yieldmil.storage.aavevault")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AAVEVAULT_STORAGE_SLOT = 0xe86928725d42611a4d97f5379bd85d7fa4997f3070cc0d523b2643f8c6d82d00;

    /**
     * A storage struct for the AaveVault.
     * @dev All new fields must be added at the end of the struct.
     * @param fee - The fee.
     * @param accumulatedFees - The accumulated fees.
     * @param lastVaultBalance - The last vault balance of assets.
     * @param totalShares - The total shares.
     * @param owner - The owner of the contract.
     * @param shareBalanceOf - The share balance of each address.
     */
    struct Storage {
        uint16 fee;
        uint240 accumulatedFees;
        uint256 lastVaultBalance;
        uint256 totalShares;
        address owner;
        mapping(address => uint256) shareBalanceOf;
    }

    /**
     * Returns the storage of the AaveVault.
     */
    function _getStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := AAVEVAULT_STORAGE_SLOT
        }
    }
}
