// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

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

    function totalAssets() public view override returns (uint256) {
        // must compute the value of token A & B amounts in underlying token
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view override returns (uint256) {
        // compute how many assets A & B can be get from assets amount, then compute shares amount
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view override returns (uint256) {
        // compute how many assets A & B can be get from shares amount, then compute both assets value in underlying asset
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // after transfering underlying token from caller to this, convert underlying token to token A & B, then mint
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // after burning shares, convert token A & B to underlying token, then send
    }

    /// Asset conversion functions ///

    // compute the amount of token A & token B that will be received from underlyingTokenAmount
    function previewSwapForAsset(uint256 underlyingTokenAmount) public view virtual;

    // compute the amount of underlying token that will be received from assetAAmount & assetBAmount
    function previewSwapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) public view virtual;

    function swapForAsset(uint256 underlyingTokenAmount) public virtual;

    function swapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) public virtual;
}

contract Strategy1 is Vault {
    uint256 immutable tokenAPercentage;
    uint256 immutable tokenBPercentage;

    constructor(IERC20 _underlyingAsset, IERC20 _assetA, IERC20 _assetB, address _pool)
        Vault(_underlyingAsset, _assetA, _assetB, _pool, "Strategy1", "STRAT1")
    {
        tokenAPercentage = 80;
        tokenBPercentage = 20;
    }

    function previewSwapForAsset(uint256 underlyingTokenAmount) public view override {}

    // compute the amount of underlying token that will be received from assetAAmount & assetBAmount
    function previewSwapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) public view override {}

    function swapForAsset(uint256 underlyingTokenAmount) public override {}

    function swapForUnderlyingToken(uint256 assetAAmount, uint256 assetBAmount) public override {}
}
