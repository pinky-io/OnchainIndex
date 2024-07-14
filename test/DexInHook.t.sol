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
import {DexInHook} from "../src/DexInHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FixedWeightStrategy} from "../src/Strategy/Strategy.sol";
import {ISwapRouter} from "../src/utils/SwapHelper.sol";

address constant ADDRESS_ZERO = address(0);

contract DexInHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    DexInHook hook;
    PoolId poolId;
    FixedWeightStrategy vault;
    Currency underlyingCurrency;
    address addressUnderlyingCurrency;
    PoolKey key0;
    PoolKey key1;

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        underlyingCurrency = Deployers.deployMintAndApproveCurrency();
        addressUnderlyingCurrency = Currency.unwrap(underlyingCurrency);

        key0 = PoolKey(currency0, underlyingCurrency, 3000, 1, IHooks(ADDRESS_ZERO));
        key1 = PoolKey(currency1, underlyingCurrency, 3000, 1, IHooks(ADDRESS_ZERO));
        poolId = key.toId();
        manager.initialize(key0, SQRT_PRICE_1_1, ZERO_BYTES);
        manager.initialize(key1, SQRT_PRICE_1_1, ZERO_BYTES);

        modifyLiquidityRouter.modifyLiquidity(
            key0,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10_000 ether, 0),
            ZERO_BYTES
        );
        modifyLiquidityRouter.modifyLiquidity(
            key1,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 10_000 ether, 0),
            ZERO_BYTES
        );

        vault = new FixedWeightStrategy(
            IERC20(Currency.unwrap(underlyingCurrency)),
            IERC20(Currency.unwrap(currency0)),
            IERC20(Currency.unwrap(currency1)),
            address(manager),
            ISwapRouter(address(swapRouter)),
            key0,
            key1
        );

        address flags =
            address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG) ^ (0x4444 << 144));
        deployCodeTo("DexInHook.sol", abi.encode(manager, address(vault)), flags);
        hook = DexInHook(flags);

        key = PoolKey(Currency.wrap(address(vault)), underlyingCurrency, 3000, 60, IHooks(hook));

        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        uint256 amountSpecified = 10;
        deal(addressUnderlyingCurrency, address(this), 1e18);
        IERC20(addressUnderlyingCurrency).approve(address(vault), type(uint256).max);
        uint256 amountOut = vault.mint(amountSpecified, address(manager));
    }

    function testSetup() public {
        assertEq(hook.vaultAddress(), address(vault));
    }

    function testSwap() public {
        bool zeroForOne = false;
        int256 amountSpecified = -1e5;
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }
}
