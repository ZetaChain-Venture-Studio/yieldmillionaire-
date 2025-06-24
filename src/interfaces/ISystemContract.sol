// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISystemContract {
    function uniswapv2FactoryAddress() external view returns (address);
    function uniswapv2Router02Address() external view returns (address);
    function uniswapv2PairFor(address, address, address) external pure returns (address);
    function wZetaContractAddress() external view returns (address);
}
