// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

contract DexInHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;

    enum LiquidityState {
        EnoughLiquidity,
        NotEnoughToken0,
        NotEnoughToken1
    }

    address vault;

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
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
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
        LiquidityState result = checkSwapLiquidity(key, params);
        uint256 amountToken0 = 0;
        uint256 amountToken1 = 0;

        if (result == LiquidityState.NotEnoughToken0) {
            // Do associated logic
        } else if (result == LiquidityState.NotEnoughToken1) {
            // Do associated logic
        }

        if (checkRebalancing()) {
            // Do associated logic
        }
        return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountToken0.toInt128(), amountToken1.toInt128()), 0);
    }

    function checkRebalancing() internal returns (bool) {
        // Check the vault needs rebalancing or not
        // To be implemented
        return false;
    }

    function checkSwapLiquidity(PoolKey calldata key, IPoolManager.SwapParams calldata params)
        internal
        returns (LiquidityState)
    {
        // Check if the swap requires the minting of new shares in the vault
        // To be implemented
        bool zeroForOne = params.zeroForOne;
        return LiquidityState.EnoughLiquidity;
    }
}
