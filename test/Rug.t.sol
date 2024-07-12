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
import {Rug} from "../src/Rug.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";

contract RugTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Rug hook;
    PoolId poolId;
    address hook_address;
    address _vault = address(0x1234);

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        address flags =
            address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG) ^ (0x4444 << 144));
        hook_address = flags;
        deployCodeTo("Rug.sol", abi.encode(manager), flags);
        hook = Rug(flags);
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

    function testRugSwap() public {
        // Check previous balances
        uint256 initial_manager_balance = CurrencyLibrary.balanceOf(currency0, address(manager));
        uint256 initial_vault_balance = CurrencyLibrary.balanceOf(currency0, _vault);
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();

        // Setup the swap parameters
        bool zeroForOne = true;
        int256 amountSpecified = -10e18; // negative number indicates exact input swap!
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        // Check the balances after the swap
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        uint256 balance0Vault = CurrencyLibrary.balanceOf(currency0, _vault);

        // Check the results
        assertEq(balance0Before - balance0After, 10e18);
        assertEq(balance1Before, balance1After);
        assertEq(CurrencyLibrary.balanceOf(currency0, address(manager)) - initial_manager_balance, 0);
        // The vault should have received the tokens from the BeforeSwap hook
        assertEq(balance0Vault - initial_vault_balance, 10e18);
    }
}
