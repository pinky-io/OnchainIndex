// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IFixedWeightStrategy {
    type Currency is address;

    struct PoolKey {
        Currency currency0;
        Currency currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    error AddressEmptyCode(address target);
    error AddressInsufficientBalance(address account);
    error ERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error ERC4626ExceededMaxDeposit(address receiver, uint256 assets, uint256 max);
    error ERC4626ExceededMaxMint(address receiver, uint256 shares, uint256 max);
    error ERC4626ExceededMaxRedeem(address owner, uint256 shares, uint256 max);
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error FailedInnerCall();
    error MathOverflowedMulDiv();
    error SafeERC20FailedOperation(address token);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event Rebalance(int256 amountAssetA, int256 amountAssetB);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Withdraw(
        address indexed sender, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function MAX_PRICE_LIMIT() external view returns (uint160);
    function MIN_PRICE_LIMIT() external view returns (uint160);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function asset() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 requestedDecrease) external returns (bool);
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function getPoolPrice(address poolManager, PoolKey memory key) external view returns (uint256);
    function getRatioA() external view returns (uint256);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function maxDeposit(address addr) external view returns (uint256);
    function maxMint(address addr) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256);
    function name() external view returns (string memory);
    function poolFee() external view returns (uint24);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewMint(uint256 shares) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function previewWithdraw(uint256 assets) external view returns (uint256);
    function rebalance() external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function swapExactInputSingle(int256 amountIn, PoolKey memory key, bool zeroForOne)
        external
        returns (uint256 amountOut);
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
}
