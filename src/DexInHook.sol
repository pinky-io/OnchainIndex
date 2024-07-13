// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/src/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {Pool} from "v4-core/src/libraries/Pool.sol";
import {Slot0} from "v4-core/src/types/Slot0.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

contract DexInHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;
    using StateLibrary for IPoolManager;
    using Pool for Pool.State;

    enum LiquidityState {
        EnoughLiquidity,
        NotEnoughToken0,
        NotEnoughToken1
    }

    event NeedToMintShares();
    event NeedToBurnShares();

    address vault;
    Pool.State FakeState;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function set_vault(address _vault) external {
        vault = _vault;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (checkRebalancing()) {
            // Do associated logic
        }
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function checkRebalancing() internal returns (bool) {
        // Check the vault needs rebalancing or not
        // To be implemented
        return false;
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta balanceDelta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        int256 amountSpecified = params.amountSpecified;
        if (amountSpecified < 0) {
            amountSpecified = int256(-amountSpecified);
        }
        bool zeroForOne = params.zeroForOne;
        int256 amountExecuted;
        if (zeroForOne) {
            int256 amountDifference = amountSpecified - int256(-BalanceDeltaLibrary.amount0(balanceDelta));
            if (amountDifference > 0) {
                // Mint Shares
                Currency input = params.zeroForOne ? key.currency0 : key.currency1;
                manager.take(input, vault, uint256(amountDifference));
                emit NeedToMintShares();
            }
        } else {
            int256 amountDifference = amountSpecified - BalanceDeltaLibrary.amount1(balanceDelta);
            if (amountDifference > 0) {
                // Burn Shares
                Currency input = params.zeroForOne ? key.currency0 : key.currency1;
                manager.take(input, vault, uint256(amountDifference));
                emit NeedToBurnShares();
            }
        }
        return (BaseHook.afterSwap.selector, 0);
    }

    // function checkSwapLiquidity(PoolKey calldata key, IPoolManager.SwapParams calldata params)
    //     internal
    //     returns (LiquidityState)
    // {
    //     // Check if the swap requires the minting of new shares in the vault
    //     // To be implemented
    //     PoolId poolId = key.toId();
    //     (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee) = manager.getSlot0(poolId);
    //     int24 my_tick = FakeState.initialize(sqrtPriceX96, protocolFee, lpFee);
    //     Pool.SwapParams memory swap_params =
    //         Pool.SwapParams(key.tickSpacing, params.zeroForOne, params.amountSpecified, params.sqrtPriceLimitX96, 0);
    //     (BalanceDelta result, uint256 feeForProtocol, uint24 swapFee, Pool.SwapState memory post_swap_state) =
    //         FakeState.swap(swap_params);
    //     return LiquidityState.EnoughLiquidity;
    // }
}
