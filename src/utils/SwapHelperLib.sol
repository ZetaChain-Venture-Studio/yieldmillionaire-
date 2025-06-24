// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/ISystemContract.sol";
import "../interfaces/IUniswapV2Router.sol";
import "@zetachain/contracts/zevm/interfaces/IZRC20.sol";

library SwapHelperLib {
    uint256 internal constant MAX_DEADLINE = 200;

    function _existsPairPool(ISystemContract systemContract, address zrc20A, address zrc20B)
        internal
        view
        returns (bool)
    {
        address uniswapPool = systemContract.uniswapv2PairFor(systemContract.uniswapv2FactoryAddress(), zrc20A, zrc20B);
        return IZRC20(zrc20A).balanceOf(uniswapPool) > 0 && IZRC20(zrc20B).balanceOf(uniswapPool) > 0;
    }

    function swapTokensForExactTokens(
        ISystemContract systemContract,
        address zrc20,
        uint256 amountInMax,
        address targetZRC20,
        uint256 amountOut
    ) internal returns (uint256) {
        bool existsPairPool = _existsPairPool(systemContract, zrc20, targetZRC20);

        address[] memory path;
        if (existsPairPool) {
            path = new address[](2);
            path[0] = zrc20;
            path[1] = targetZRC20;
        } else {
            path = new address[](3);
            path[0] = zrc20;
            path[1] = systemContract.wZetaContractAddress();
            path[2] = targetZRC20;
        }

        IZRC20(zrc20).approve(address(systemContract.uniswapv2Router02Address()), amountInMax);
        uint256[] memory amounts = IUniswapV2Router(systemContract.uniswapv2Router02Address()).swapTokensForExactTokens(
            amountOut, amountInMax, path, address(this), block.timestamp + MAX_DEADLINE
        );
        return amounts[0];
    }
}
