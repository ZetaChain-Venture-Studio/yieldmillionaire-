// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title YieldMilStorage
 * @author https://github.com/nzmpi
 * @notice A storage contract for the YieldMil
 */
contract YieldMilStorage {
    // EIP-7201: keccak256(abi.encode(uint256(keccak256("yieldmil.storage.yieldmil")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant YIELDMIL_STORAGE_SLOT = 0xe964e1827ef0fbd29bea35034bc8c822443e26fbb8e8cf4e8c253caeee6fd700;

    /**
     * A storage struct for the YieldMil.
     * @dev Key is the keccak256(abi.encode(chain, protocol, token))
     * @dev All new fields must be added at the end of the struct.
     * @param owner - The owner of the contract.
     * @param vaults - The vaults of the contract.
     * @param refunds - The refunds got from aborts.
     * @param EVMEntries - The EVMEntries of the contract.
     * @param isDepositPaused - Whether the deposit is paused.
     * @param isWithdrawPaused - Whether the withdraw is paused.
     * @param guardians - The guardians of the contract, that can pause the deposit and/or withdraw.
     */
    struct Storage {
        address owner;
        mapping(bytes32 key => address) vaults;
        // refunds are deprecated in version 1.4.0
        mapping(address owner => mapping(address token => uint256 amount)) refunds;
        mapping(uint256 chainId => address EVMEntry) EVMEntries;
        bool isDepositPaused;
        bool isWithdrawPaused;
        mapping(address => bool status) guardians;
    }

    /**
     * Returns the storage of the YieldMil.
     */
    function _getStorage() internal pure returns (Storage storage $) {
        assembly {
            $.slot := YIELDMIL_STORAGE_SLOT
        }
    }
}
