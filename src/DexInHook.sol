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
import {IFixedWeightStrategy} from "./Strategy/IFixedWeightStrategy.sol";
import {Lock} from "v4-core/src/libraries/Lock.sol";

contract DexInHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Lock for IPoolManager;

    address public immutable vaultAddress;

    constructor(IPoolManager _poolManager, address _vaultAddress) BaseHook(_poolManager) {
        vaultAddress = _vaultAddress;
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
        int256 amountSpecified = params.amountSpecified;
        if (amountSpecified >= 0) {
            revert("Cannot swap using exact output amount");
        }

        amountSpecified = -amountSpecified;
        bool zeroForOne = params.zeroForOne;
        Currency input = zeroForOne ? key.currency0 : key.currency1;
        Currency output = zeroForOne ? key.currency1 : key.currency0;
        manager.take(input, address(this), uint256(amountSpecified));

        if (!params.zeroForOne) {
            // mint shares into the hook, here amountSpecified is an amount of USDC
            address inputCurrency = Currency.unwrap(input);
            IERC20Minimal(inputCurrency).approve(vaultAddress, uint256(amountSpecified));
            uint256 shares = IFixedWeightStrategy(vaultAddress).deposit(uint256(amountSpecified), address(this));
            // settle the shares to the pool manager
            output.transfer(address(manager), shares);
            manager.settle(output);
            return (BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountSpecified.toInt128(), -shares.toInt128()), 0);
        } else {
            // redeem shares from the pool manager
            manager.take(output, address(this), uint256(amountSpecified));
            // redeem shares from the vault
            uint256 assetAmount =
                IFixedWeightStrategy(vaultAddress).withdraw(uint256(amountSpecified), address(this), address(this));
            // settle the asset to the pool manager
            input.transfer(address(manager), assetAmount);
            manager.settle(input);
            return (
                BaseHook.beforeSwap.selector, toBeforeSwapDelta(amountSpecified.toInt128(), -assetAmount.toInt128()), 0
            );
        }
    }
}
