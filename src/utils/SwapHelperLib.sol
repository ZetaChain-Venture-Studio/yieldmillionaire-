// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../interfaces/IUniswapV2Router.sol";
import "@zetachain/contracts/zevm/interfaces/IZRC20.sol";

library SwapHelperLib {
    uint256 internal constant MAX_DEADLINE = 200;
    address internal constant WZETA = 0x5F0b1a82749cb4E2278EC87F8BF6B618dC71a8bf;
    bytes20 internal constant UNISWAPV2_FACTORY = bytes20(0x9fd96203f7b22bCF72d9DCb40ff98302376cE09c);
    address internal constant UNISWAPV2_ROUTER_02 = 0x2ca7d64A7EFE2D62A725E2B35Cf7230D6677FfEe;

    error BadTokenPair();

    function swapTokensForExactTokens(address inputZRC20, uint256 amountInMax, address outputZRC20, uint256 amountOut)
        internal
        returns (uint256)
    {
        address[] memory path = _getPath(inputZRC20, outputZRC20);

        IZRC20(inputZRC20).approve(UNISWAPV2_ROUTER_02, amountInMax);
        uint256[] memory amounts = IUniswapV2Router(UNISWAPV2_ROUTER_02).swapTokensForExactTokens(
            amountOut, amountInMax, path, address(this), block.timestamp + MAX_DEADLINE
        );
        return amounts[0];
    }

    function swapExactTokensForTokens(address inputZRC20, uint256 amount, address outputZRC20, uint256 minAmountOut)
        internal
        returns (uint256)
    {
        address[] memory path = _getPath(inputZRC20, outputZRC20);

        IZRC20(inputZRC20).approve(UNISWAPV2_ROUTER_02, amount);
        uint256[] memory amounts = IUniswapV2Router(UNISWAPV2_ROUTER_02).swapExactTokensForTokens(
            amount, minAmountOut, path, address(this), block.timestamp + MAX_DEADLINE
        );
        return amounts[path.length - 1];
    }

    function _getPath(address tokenA, address tokenB) internal view returns (address[] memory path) {
        if (_doesPairPoolExist(tokenA, tokenB)) {
            path = new address[](2);
            path[0] = tokenA;
            path[1] = tokenB;
        } else {
            path = new address[](3);
            path[0] = tokenA;
            path[1] = WZETA;
            path[2] = tokenB;
        }
    }

    function _doesPairPoolExist(address tokenA, address tokenB) private view returns (bool) {
        address uniswapPool = _uniswapv2PairFor(tokenA, tokenB);
        return IZRC20(tokenA).balanceOf(uniswapPool) > 0 && IZRC20(tokenB).balanceOf(uniswapPool) > 0;
    }

    function _uniswapv2PairFor(address tokenA, address tokenB) private pure returns (address pair) {
        if (tokenA == tokenB || tokenA == address(0) || tokenB == address(0)) revert BadTokenPair();
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        bytes.concat(
                            hex"ff",
                            UNISWAPV2_FACTORY,
                            keccak256(bytes.concat(bytes20(tokenA), bytes20(tokenB))),
                            hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
                        )
                    )
                )
            )
        );
    }
}
