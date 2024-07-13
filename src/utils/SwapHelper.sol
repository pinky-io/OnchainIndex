// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

// Helper function to swap using a Uniswap V4 pool.
// It is declared in a library to be injected in the IPoolManager type, using 'using' operator.
library SwapHelperLibrary {
    using StateLibrary for IPoolManager;

    uint24 public constant poolFee = 3000; // 0.3%

    function swapExactInputSingle(IPoolManager poolManager, uint256 amountIn, address tokenIn, PoolKey memory key)
        external
        returns (uint256 amountOut)
    {
        bool zeroForOne = tokenIn == Currency.unwrap(key.currency0);
        // Approve the router to spend 'tokenIn'.
        IERC20(tokenIn).approve(address(poolManager), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(zeroForOne, int256(amountIn), 0);

        // Proceed to swap, cast operations are unsecured as of now.
        BalanceDelta res = poolManager.swap(key, params, "");
        amountOut = uint256(int256(zeroForOne ? res.amount1() : res.amount0()));
    }

    function getPoolPrice(IPoolManager poolManager, PoolKey memory key) external view returns (uint256) {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(PoolIdLibrary.toId(key));

        uint256 price = sqrtPriceX96; // TODO: uint256 is not large enough to hold (type(uint160).max)^2
        return price * price; // it's a square root, so computing its square gives us the real price
    }
}

// Abstract contract wrapper to be inherited to include relevant data
abstract contract SwapHelper {
    mapping(address token => PoolKey key) internal keys;
    IPoolManager immutable poolManager;

    constructor(IPoolManager _poolManager, address tokenA, PoolKey memory keyA, address tokenB, PoolKey memory keyB) {
        poolManager = _poolManager;
        keys[tokenA] = keyA;
        keys[tokenB] = keyB;
    }
}
