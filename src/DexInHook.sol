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
import {stdMath} from "forge-std/StdMath.sol";
import "forge-std/console.sol";

contract DexInHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;
    using SafeCast for int256;
    using StateLibrary for IPoolManager;
    using Pool for Pool.State;
    using CurrencyLibrary for Currency;

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
            afterSwapReturnDelta: true,
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
            return (BaseHook.afterSwap.selector, 0);
        }
        bool zeroForOne = params.zeroForOne;
        if (zeroForOne) {
            // AMOUNT0 OUT : i.e i want to get usdc and give shares
            int128 realisedAmount0 = balanceDelta.amount0();
            int128 realisedAmount1 = balanceDelta.amount1();
            uint256 shares = stdMath.abs(int256(realisedAmount1));
            if (realisedAmount0 < 0) {
                realisedAmount0 = -realisedAmount0;
            }
            int256 diffAmount = amountSpecified - realisedAmount0;
            if (diffAmount > 0) {
                // burn shares
                emit NeedToBurnShares();
                manager.take(key.currency1, vault, shares);
                return (BaseHook.afterSwap.selector, shares.toInt128());
            } else {
                return (BaseHook.afterSwap.selector, 0);
            }
        } else {
            // AMOUNT1 OUT : i.e i want to get shares
            int128 realisedAmount1 = balanceDelta.amount1();
            console.log("realisedAmount1: ", realisedAmount1);
            // amount specified is in token 1
            int256 diffAmount = amountSpecified - realisedAmount1;
            if (diffAmount > 0) {
                // mint shares
                emit NeedToBurnShares();
                manager.take(key.currency1, vault, uint256(diffAmount));
                return (BaseHook.afterSwap.selector, diffAmount.toInt128());
            } else {
                return (BaseHook.afterSwap.selector, 0);
            }
        }
    }
}
