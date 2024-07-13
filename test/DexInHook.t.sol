// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {DexInHook} from "../src/DexInHook.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";

contract DexInHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    DexInHook hook;
    PoolId poolId;
    address _vault = address(0x1234);
    address user = address(0x5678);

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG)
                ^ (0x4444 << 144)
        );
        deployCodeTo("DexInHook.sol", abi.encode(manager), flags);
        hook = DexInHook(flags);
        hook.set_vault(_vault);

        key = PoolKey(currency0, currency1, 3000, 1, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide full-range liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(
            key, IPoolManager.ModifyLiquidityParams(-10, 10, 0.1 ether, 0), ZERO_BYTES
        );
    }

    function testDexInSwapWithoutConditions() public {
        // Setup the swap parameters
        bool zeroForOne = true;
        int256 amountSpecified = 1e18;
        address address_currency0 = Currency.unwrap(currency0);
        address address_currency1 = Currency.unwrap(currency1);

        // // Deal 1e18 currency1 to user
        // deal(address_currency1, user, 1e18);
        // // Approve the swapRouter to spend 1e18 currency0 from user as we are doing an amount0Out swap
        // vm.prank(user);
        IERC20Minimal(address_currency0).approve(address(swapRouter), 1e18);
        IERC20Minimal(address_currency1).approve(address(swapRouter), 1e18);
        IERC20Minimal(address_currency0).approve(address(manager), 1e18);
        IERC20Minimal(address_currency1).approve(address(manager), 1e18);
        // vm.prank(user);
        // // Users swaps 1e18 currency0 in the pool
        // vm.prank(user);

        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        assertGt(currency1.balanceOf(_vault), 0);
    }
}
