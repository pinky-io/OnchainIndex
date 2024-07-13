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
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import "forge-std/StdMath.sol";

abstract contract ISwapRouter {
    IPoolManager public manager;

    function swap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        PoolSwapTest.TestSettings memory testSettings,
        bytes memory hookData
    ) external payable virtual returns (BalanceDelta delta);
}
// Helper function to swap using a Uniswap V4 pool.
// It is declared in a library to be injected in the IPoolManager type, using 'using' operator.

// Abstract contract wrapper to be inherited to include relevant data
abstract contract SwapHelper {
    mapping(address token => PoolKey key) internal keys;
    ISwapRouter immutable swapRouter;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;

    constructor(
        ISwapRouter _swapRouter,
        address tokenA,
        PoolKey memory keyA,
        address tokenB,
        PoolKey memory keyB
    ) {
        swapRouter = _swapRouter;
        keys[tokenA] = keyA;
        keys[tokenB] = keyB;
    }

    using StateLibrary for IPoolManager;

    uint24 public constant poolFee = 3000; // 0.3%

    event SwapInitiated(
        address indexed tokenIn,
        uint256 amountIn,
        address poolManager
    );
    event SwapParameters(bool zeroForOne, int256 amountIn);
    event SwapResult(uint256 amountOut);

    function swapExactInputSingle(
        int256 amountIn,
        address tokenIn,
        PoolKey memory key
    ) external returns (uint256 amountOut) {
        emit SwapInitiated(tokenIn, stdMath.abs(amountIn), swapRouter.manager.address);

        bool zeroForOne = tokenIn == Currency.unwrap(key.currency0);
        IERC20(tokenIn).approve(swapRouter.manager.address, stdMath.abs(amountIn));

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams(
            zeroForOne,
            int256(amountIn),
            zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        );

        emit SwapParameters(zeroForOne, int256(amountIn));

        BalanceDelta res = swapRouter.swap(
            key,
            params,
            PoolSwapTest.TestSettings(false, false),
            ""
        );

        amountOut = uint256(int256(zeroForOne ? res.amount1() : res.amount0()));

        emit SwapResult(amountOut);
    }

    function getPoolPrice(
        IPoolManager poolManager,
        PoolKey memory key
    ) external view returns (uint256) {
        (uint160 sqrtPriceX96, , , ) = poolManager.getSlot0(
            PoolIdLibrary.toId(key)
        );

        uint256 price = sqrtPriceX96; // TODO: uint256 is not large enough to hold (type(uint160).max)^2
        return price * price; // it's a square root, so computing its square gives us the real price
    }
}
