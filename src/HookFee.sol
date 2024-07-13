// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

contract HookFee is BaseHook {
    using PoolIdLibrary for PoolKey;
    using FixedPointMathLib for uint256;
    using CurrencyLibrary for Currency;
    using SafeCast for uint256;
    using SafeCast for int256;

    uint256 public constant HOOK_FEE = 1;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        // fee will be in the unspecified token of the swap
        bool isCurrency0Specified = (params.amountSpecified < 0 == params.zeroForOne);

        (Currency currencyUnspecified, int128 amountUnspecified) =
            (isCurrency0Specified) ? (key.currency1, delta.amount1()) : (key.currency0, delta.amount0());

        // if exactOutput swap, get the absolute output amount
        if (amountUnspecified < 0) amountUnspecified = -amountUnspecified;

        uint256 feeAmount = uint256(int256(amountUnspecified)).mulWadDown(HOOK_FEE);

        // mint ERC6909 as its cheaper than ERC20 transfer
        //manager.mint(address(this), CurrencyLibrary.toId(currencyUnspecified), feeAmount);
        manager.take(currencyUnspecified, address(1), feeAmount);

        return (BaseHook.afterSwap.selector, feeAmount.toInt128());
    }
}
