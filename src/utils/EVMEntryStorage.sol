// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title EVMEntryStorage
 * @author https://github.com/nzmpi
 * @notice A storage contract for the EVMEntry
 */
contract EVMEntryStorage {
    // EIP-7201: keccak256(abi.encode(uint256(keccak256("yieldmil.storage.evmentry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant EVMENTRY_STORAGE_SLOT = 0x83567f97536c31f81aa4b0994d8f9dfc230af889153a57098bae9fd5c2da1c00;

    /**
     * A storage struct for the YieldMil.
     * @dev Key is the keccak256(abi.encode(protocol, token))
     * @dev All new fields must be added at the end of the struct.
     * @param owner - The owner of the contract.
     * @param vaults - The vaults of the contract.
     */
    struct Storage {
        address owner;
        mapping(bytes32 key => address) vaults;
    }

    /**
     * Returns the storage of the YieldMil.
     */
    function _getStorage() internal pure returns (Storage storage $) {
        assembly ("memory-safe") {
            $.slot := EVMENTRY_STORAGE_SLOT
        }
    }
}
