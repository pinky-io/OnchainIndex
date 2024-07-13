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
    address hook_address;
    address _vault = address(0x1234);
    address user = address(0x5678);

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        address flags =
            address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG) ^ (0x4444 << 144));
        hook_address = flags;
        deployCodeTo("DexInHook.sol", abi.encode(manager), flags);
        hook = DexInHook(flags);
        hook.set_vault(_vault);

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide full-range liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10_000 ether, 0),
            ZERO_BYTES
        );
    }

    function testDexInSwapWithoutConditions() public {
        // Check previous balances
        uint256 balance0Before = 1e18;
        uint256 balance1Before = 0;

        // Setup the swap parameters
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        address address_currency0 = Currency.unwrap(currency0);

        // Deal 1e18 currency0 to user
        deal(address_currency0, user, 1e18);

        // Approve the swapRouter to spend 2e18 currency0 from user
        vm.prank(user);
        IERC20Minimal(address_currency0).approve(address(swapRouter), 2e18);

        // Users swaps 1e18 currency0 in the pool
        vm.prank(user);
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        // Check the balances after the swap
        uint256 balance0After = currency0.balanceOf(user);
        uint256 balance1After = currency1.balanceOf(user);

        // As the conditions are not met, the swap should be executed as usual
        assertEq(balance0Before - balance0After, 1e18);
        require(balance1Before < balance1After, "balance1Before < balance1After");
        assertEq(balance1After, 996900609009281774);
    }
}
