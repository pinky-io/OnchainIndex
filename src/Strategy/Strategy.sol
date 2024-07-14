// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SwapHelper, ISwapRouter} from "../utils/SwapHelper.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import "forge-std/StdMath.sol";

abstract contract Vault is ERC4626 {
    IERC20 assetA;
    IERC20 assetB;
    address pool;

    constructor(
        IERC20 _underlyingAsset,
        IERC20 _assetA,
        IERC20 _assetB,
        address _pool,
        string memory _name,
        string memory _symbol
    ) ERC4626(_underlyingAsset) ERC20(_name, _symbol) {
        assetA = _assetA;
        assetB = _assetB;
        pool = _pool;
    }

    function maxDeposit(address addr) public view override returns (uint256) {
        if (addr == pool) {
            return type(uint256).max;
        } else {
            return 0;
        }
    }

    function maxMint(address addr) public view override returns (uint256) {
        if (addr == pool) {
            return type(uint256).max;
        } else {
            return 0;
        }
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // after transfering underlying token from caller to this, convert underlying token to token A & B, then mint

        SafeERC20.safeTransferFrom(IERC20(asset()), caller, address(this), assets);
        _swapForAsset(assets);
        _mint(receiver, shares);

        emit Deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // after burning shares, convert token A & B to underlying token, then send
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }
        _burn(owner, shares);

        (uint256 assetAPerShare, uint256 assetBPerShare) = _assetsBalance();
        _swapForUnderlyingToken(assetAPerShare * shares, assetBPerShare * shares);

        SafeERC20.safeTransfer(IERC20(asset()), receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// Asset conversion functions ///

    // compute the amount of token A & token B that will be received from underlyingTokenAmount
    function _previewSwapForAsset(uint256 underlyingTokenAmount) internal view virtual;

    // compute the amount of underlying token that will be received from assetAAmount & assetBAmount
    function _previewSwapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) internal view virtual;

    function _swapForAsset(uint256 underlyingTokenAmount) internal virtual;

    function _swapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount)
        internal
        virtual
        returns (uint256, uint256);

    /// Helpers ///

    function _assetsBalance() internal view returns (uint256 assetAPerShare, uint256 assetBPerShare) {
        uint256 assetABalance = assetA.balanceOf(address(this));
        uint256 assetBBalance = assetB.balanceOf(address(this));

        if (totalSupply() == 0) {
            return (assetABalance, assetBBalance);
        } else {
            return (assetABalance / totalSupply(), assetBBalance / totalSupply());
        }
    }
}

contract FixedWeightStrategy is Vault, SwapHelper {
    using CurrencyLibrary for Currency;
    using Math for uint256;

    // todo uint256 is unecessary large for a bps
    uint256 immutable tokenABps;
    uint256 immutable tokenBBps;
    uint256 constant BPS_LIMIT = 10_000;
    uint256 constant MAX_TRESHOLD = 2_000;

    event Rebalance(int256 amountAssetA, int256 amountAssetB);

    constructor(
        IERC20 _underlyingAsset,
        IERC20 _assetA,
        IERC20 _assetB,
        address _pool,
        ISwapRouter _swapRouter,
        PoolKey memory keyA,
        PoolKey memory keyB
    )
        Vault(_underlyingAsset, _assetA, _assetB, _pool, "FixedWeightStrategy", "STRAT1")
        SwapHelper(_swapRouter, address(_assetA), keyA, address(_assetB), keyB)
    {
        tokenABps = 8000;
        tokenBBps = 2000;
    }

    function rebalance() public {
        uint256 ratio = getRatioA();

        if (stdMath.abs((int256(tokenABps) - int256(ratio))) > MAX_TRESHOLD) {
            _rebalance(ratio);
        }
    }

    function _rebalance(uint256 ratioA) private {
        // stdMath.abs((int256(tokenABps) - int256(ratioA)) - MAX_TRESHOLD
        int256 buyOrSell = (int256(tokenABps) - int256(ratioA));
        uint256 balanceAssetA = assetA.balanceOf(address(this));
        uint256 balanceAssetB = assetB.balanceOf(address(this));
        uint256 receivedUnderlying = 0;

        if (buyOrSell > 0) {
            PoolKey memory keyA = keys[address(assetA)];
            uint256 amountB = stdMath.abs(buyOrSell) * balanceAssetB / BPS_LIMIT;
            (, receivedUnderlying) = _swapForUnderlyingToken(0, amountB);
            uint256 receivedAmountA =
                swapExactInputSingle(-int256(receivedUnderlying), keyA, Currency.unwrap(keyA.currency0) == asset());

            emit Rebalance(int256(receivedAmountA), -int256(amountB));
        } else {
            PoolKey memory keyB = keys[address(assetB)];
            uint256 amountA = stdMath.abs(buyOrSell) * balanceAssetA / BPS_LIMIT;
            (, receivedUnderlying) = _swapForUnderlyingToken(0, amountA);
            uint256 receivedAmountB = swapExactInputSingle(
                -int256(receivedUnderlying), keys[address(assetB)], Currency.unwrap(keyB.currency0) == asset()
            );

            emit Rebalance(-int256(amountA), int256(receivedAmountB));
        }
    }

    function getRatioA() public view returns (uint256) {
        uint256 balanceAssetA = assetA.balanceOf(address(this));
        uint256 balanceAssetB = assetB.balanceOf(address(this));
        uint256 priceAssetA = getPoolPrice(swapRouter.manager(), keys[address(assetA)]);
        uint256 priceAssetB = getPoolPrice(swapRouter.manager(), keys[address(assetB)]);

        uint256 totalValue = balanceAssetA * priceAssetA + balanceAssetB * priceAssetB;
        uint256 ratioAssetA = uint256(balanceAssetA * priceAssetA * 10000).mulDiv(1, totalValue);
        return ratioAssetA;
    }

    function totalAssets() public view override returns (uint256) {
        // must compute the value of token A & B amounts in underlying token
        return (
            getPoolPrice(swapRouter.manager(), keys[address(assetA)]) * assetA.balanceOf(address(this))
                + getPoolPrice(swapRouter.manager(), keys[address(assetB)]) * assetB.balanceOf(address(this))
        );
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        // compute how many assets A & B can be get from assets amount, then compute shares amount
        return super._convertToShares(assets, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        // compute how many assets A & B can be get from shares amount, then compute both assets value in underlying asset
        return super._convertToAssets(shares, rounding);
    }

    // compute the amount of token A & token B that will be received from underlyingTokenAmount
    function _previewSwapForAsset(uint256 underlyingTokenAmount) internal view override {}

    // compute the amount of underlying token that will be received from assetAAmount & assetBAmount
    function _previewSwapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) internal view override {}

    function _swapForAsset(uint256 underlyingTokenAmount) internal override {
        PoolKey memory keyA = keys[address(assetA)];
        PoolKey memory keyB = keys[address(assetB)];

        // swap for token A
        uint256 amountForSwapA = underlyingTokenAmount * tokenABps / BPS_LIMIT;
        swapExactInputSingle(-int256(amountForSwapA), keyA, Currency.unwrap(keyA.currency0) == asset());

        // swap for token B
        uint256 amountForSwapB = underlyingTokenAmount * tokenBBps / BPS_LIMIT;
        swapExactInputSingle(-int256(amountForSwapB), keyB, Currency.unwrap(keyB.currency0) == asset());
    }

    function _swapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount)
        internal
        override
        returns (uint256, uint256)
    {
        address underlyingToken = asset();
        PoolKey memory keyA = keys[address(assetA)];
        PoolKey memory keyB = keys[address(assetB)];
        uint256 resAssetA = 0;
        uint256 resAssetB = 0;

        // swap token A for underlying
        if (assetAAmount > 0) {
            resAssetA =
                swapExactInputSingle(-int256(assetAAmount), keyA, Currency.unwrap(keyA.currency1) == underlyingToken);
        }

        // swap token B for underlying
        if (assetBAmount > 0) {
            resAssetB =
                swapExactInputSingle(-int256(assetBAmount), keyB, Currency.unwrap(keyB.currency1) == underlyingToken);
        }

        return (resAssetA, resAssetB);
    }
}
