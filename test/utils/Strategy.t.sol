// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FixedWeightStrategy} from "../../src/Strategy/Strategy.sol";
import {ISwapRouter} from "../../src/utils/SwapHelper.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "forge-std/Test.sol";

address constant ADDRESS_ZERO = address(0);

contract SwapHelperTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    PoolId poolId;
    FixedWeightStrategy vault;
    Currency underlyingCurrency;
    PoolKey key0;
    PoolKey key1;
    address user = address(0x5678);

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        underlyingCurrency = Deployers.deployMintAndApproveCurrency();

        key0 = PoolKey(currency0, underlyingCurrency, 3000, 1, IHooks(ADDRESS_ZERO));
        key1 = PoolKey(currency1, underlyingCurrency, 3000, 1, IHooks(ADDRESS_ZERO));
        poolId = key.toId();
        manager.initialize(key0, SQRT_PRICE_1_1, ZERO_BYTES);
        manager.initialize(key1, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide full-range liquidity to the pool
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
    }

    function testSwapExactInputSingle() public {
        int256 amountSpecified = -1e18;
        address addressUnderlyingCurrency = Currency.unwrap(underlyingCurrency);

        deal(addressUnderlyingCurrency, address(vault), 1e18);

        uint256 amountOut = vault.swapExactInputSingle(amountSpecified, key1, false);

        assert(amountOut > 0);
    }

    function testMintShares() public {
        uint256 amountSpecified = 10;
        address addressUnderlyingCurrency = Currency.unwrap(underlyingCurrency);

        deal(addressUnderlyingCurrency, address(this), 1e18);
        IERC20(addressUnderlyingCurrency).approve(address(vault), vault.convertToAssets(amountSpecified));
        uint256 amountOut = vault.mint(amountSpecified, address(manager));

        assert(amountOut > 0);
    }
}
