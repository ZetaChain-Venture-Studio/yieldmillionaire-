//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC1967Proxy, ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title ProxyBase
 * @author https://github.com/nzmpi
 * @notice A simple proxy contract
 * @dev Make sure the implementation doesn't have one of the 4 function selectors.
 */
contract ProxyBase is ERC1967Proxy {
    error NotProxyAdmin(address);

    modifier onlyProxyAdmin() {
        if (ERC1967Utils.getAdmin() != msg.sender) revert NotProxyAdmin(msg.sender);
        _;
    }

    constructor(address _impl, address _admin, bytes memory _initData) payable ERC1967Proxy(_impl, _initData) {
        ERC1967Utils.changeAdmin(_admin);
    }

    receive() external payable {}

    /**
     * Change the proxy admin
     * @dev Only callable by the proxy admin
     * @dev Selector - 0x9f712f2f
     * @param _newAdmin - The new proxy admin.
     */
    function changeProxyAdmin(address _newAdmin) external onlyProxyAdmin {
        ERC1967Utils.changeAdmin(_newAdmin);
    }

    /**
     * Change the proxy implementation
     * @dev Only callable by the proxy admin
     * @dev Selector - 0x31124171
     * @param _newImpl - The new implementation.
     * @param _data - The initialization data.
     */
    function changeImplementation(address _newImpl, bytes calldata _data) external onlyProxyAdmin {
        ERC1967Utils.upgradeToAndCall(_newImpl, _data);
    }

    /**
     * Returns the proxy admin address
     * @dev Selector - 0x8b3240a0
     */
    function getProxyAdmin() external view returns (address) {
        return ERC1967Utils.getAdmin();
    }

    /**
     * Returns the proxy implementation address
     * @dev Selector - 0xaaf10f42
     */
    function getImplementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }
}
