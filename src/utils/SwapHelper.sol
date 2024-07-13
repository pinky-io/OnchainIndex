// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISwapRouter} from "../interfaces/ISwapRouter.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

// Helper function to swap using a Uniswap V4 pool.
// It is declared in a library to be injected in the ISwapRouter type, using 'using' operator.
library _SwapHelper {
    uint24 public constant poolFee = 3000; // 0.3%

    function swapExactInputSingle(ISwapRouter swapRouter, uint256 amountIn, address tokenIn, PoolKey memory key)
        internal
        returns (uint256 amountOut)
    {
        // Approve the router to spend 'tokenIn'.
        IERC20(tokenIn).approve(address(swapRouter), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IPoolManager.SwapParams memory params =
            IPoolManager.SwapParams(tokenIn == Currency.unwrap(key.currency0), int256(amountIn), 0);

        // Proceed to swap, cast operations are unsecured as of now.
        amountOut = uint256(int256(swapRouter.swap(key, params, ISwapRouter.TestSettings(false, false), "").amount1()));
    }
}

// Abstract contract wrapper to be inherited
abstract contract SwapHelper {
    using _SwapHelper for ISwapRouter;

    mapping(address token => PoolKey key) internal keys;

    ISwapRouter immutable swapRouterTokenA;
    ISwapRouter immutable swapRouterTokenB;

    constructor(
        ISwapRouter _swapRouterTokenA,
        ISwapRouter _swapRouterTokenB,
        address tokenA,
        PoolKey memory keyA,
        address tokenB,
        PoolKey memory keyB
    ) {
        swapRouterTokenA = _swapRouterTokenA;
        swapRouterTokenB = _swapRouterTokenB;
        keys[tokenA] = keyA;
        keys[tokenB] = keyB;
    }
}
