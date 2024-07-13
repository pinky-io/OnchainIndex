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
import {HookFee} from "../src/HookFee.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

contract HookFeeTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using FixedPointMathLib for uint256;

    HookFee hook;
    PoolId poolId;

    function setUp() public {
        Deployers.deployFreshManagerAndRouters();
        Deployers.deployMintAndApprove2Currencies();
        address flags = address(uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG) ^ (0x4444 << 144));
        deployCodeTo("HookFee.sol", abi.encode(manager), flags);
        hook = HookFee(flags);

        // Create the pool a pool with a 0% swap fee
        key = PoolKey(currency0, currency1, 0, 60, IHooks(address(hook)));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        // Provide full-range liquidity to the pool
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams(TickMath.minUsableTick(60), TickMath.maxUsableTick(60), 0.1 ether, 0),
            ZERO_BYTES
        );
    }

    function testHookFee() public {
        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        // ------------------- //

        // hook is holding the fee as a balance
        assertApproxEqAbs(
            manager.balanceOf(address(hook), currency1.toId()),
            uint256(-amountSpecified).mulWadDown(hook.HOOK_FEE()),
            0.000001e18
        );
    }
}
