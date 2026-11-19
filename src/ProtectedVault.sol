// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractCallback } from "@reactive/src/base/AbstractCallback.sol";

interface IERC20Minimal {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// @title ProtectedVault — destination-chain vault on Base Sepolia
/// @notice Users deposit a test asset (mETH). When the FlashGuard reactive contract
///         on Lasna sees the price breach a stop-loss threshold, it triggers a
///         callback here and the vault exits the user's full position into the
///         stablecoin (mUSDC) at the trigger price. The exit is fully on-chain:
///         no keeper, no bot, no off-chain signer.
/// @dev Deployed on Base Sepolia (chain ID 84532). The callback proxy bills this
///      contract in ETH for each callback, so it must stay funded. The vault must
///      also hold enough mUSDC reserve to pay out exits (see `fundReserve`).
///      All time-based logic uses timestamps, never block counts (Base Sepolia
///      produces 200ms blocks since the Denim upgrade).
contract ProtectedVault is AbstractCallback {
    /// @notice Asset id for the protected asset (mETH). Single-asset vault;
    ///         multi-asset support is a matter of one mapping per asset.
    uint256 public constant ASSET_ID = 1;

    IERC20Minimal public immutable asset; // mETH (18 decimals)
    IERC20Minimal public immutable stable; // mUSDC (6 decimals)
    address public owner;

    mapping(address user => uint256 balance) public deposits;
    uint256 public totalDeposited;
    uint256 public totalExited;
    uint256 public exitCount;
    uint256 public lastLoopLatencySeconds;
    uint256 public totalLoopLatencySeconds;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event ReserveFunded(address indexed funder, uint256 amount);
    /// @notice Emitted on every reactive exit. `loopLatencySeconds` is measured
    ///         on-chain: callback execution time minus the origin event's
    ///         timestamp — the full Unichain → Lasna → Base loop, in seconds.
    event StopLossExecuted(
        address indexed user,
        uint256 indexed assetId,
        uint256 indexed orderId,
        uint256 amountIn,
        uint256 amountOut,
        uint256 triggerPrice,
        uint256 originTimestamp,
        uint256 loopLatencySeconds
    );
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error ZeroAmount();
    error InsufficientBalance();
    error InsufficientReserve();
    error UnsupportedAsset();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param callbackProxy_ Base Sepolia callback proxy
    ///        (0x476F44b11F5C942c58f4c8E3d0300E5710743585).
    /// @param callbackSender_ The FlashGuardReactive contract on Lasna.
    /// @param asset_ mETH token (18 decimals).
    /// @param stable_ mUSDC token (6 decimals).
    constructor(IPayable callbackProxy_, address callbackSender_, address asset_, address stable_)
        payable
        AbstractCallback(callbackProxy_, callbackSender_)
    {
        owner = msg.sender;
        asset = IERC20Minimal(asset_);
        stable = IERC20Minimal(stable_);
    }

    // ------------------------------------------------------------------------
    // User funds
    // ------------------------------------------------------------------------

    /// @notice Deposit mETH to protect it with a stop-loss.
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        asset.transferFrom(msg.sender, address(this), amount);
        deposits[msg.sender] += amount;
        totalDeposited += amount;
        emit Deposited(msg.sender, amount);
    }

    /// @notice Withdraw un-exited mETH at any time.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (deposits[msg.sender] < amount) revert InsufficientBalance();
        deposits[msg.sender] -= amount;
        totalDeposited -= amount;
        asset.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Fund the mUSDC reserve that pays out stop-loss exits.
    function fundReserve(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        stable.transferFrom(msg.sender, address(this), amount);
        emit ReserveFunded(msg.sender, amount);
    }

    /// @notice Average full-loop latency across all exits, in seconds.
    function averageLoopLatencySeconds() external view returns (uint256) {
        if (exitCount == 0) return 0;
        return totalLoopLatencySeconds / exitCount;
    }

    /// @notice Settles outstanding debt from this contract's own balance.
    ///         A contract in debt receives no callbacks.
    function coverDebt() external {
        _coverDebt();
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ------------------------------------------------------------------------
    // Reactive callback
    // ------------------------------------------------------------------------

    /// @notice Exits a user's full position at the trigger price. Called only via
    ///         the Reactive callback proxy, and only when the injected sender is
    ///         the authorized FlashGuard reactive contract.
    /// @param reactive_ Injected by the proxy: the reactive contract that
    ///        requested the callback (must be the authorized sender).
    /// @param user_ The stop-loss order owner.
    /// @param assetId_ Must be ASSET_ID.
    /// @param price_ Trigger price, 8 decimals (Chainlink style).
    /// @param orderId_ The triggered order's id on the reactive contract.
    /// @param originTimestamp_ Block timestamp of the origin PriceUpdated event
    ///        on Unichain Sepolia — the start of the latency clock.
    function executeStopLoss(
        address reactive_,
        address user_,
        uint256 assetId_,
        uint256 price_,
        uint256 orderId_,
        uint256 originTimestamp_
    ) external onlyServiceProvider onlyCallbackSender(reactive_) {
        if (assetId_ != ASSET_ID) revert UnsupportedAsset();
        uint256 amountIn = deposits[user_];
        if (amountIn == 0) revert InsufficientBalance();

        // amountOut (mUSDC, 6 dec) = amountIn (mETH, 18 dec) * price (8 dec) / 1e20
        uint256 amountOut = (amountIn * price_) / 1e20;
        if (stable.balanceOf(address(this)) < amountOut) revert InsufficientReserve();

        deposits[user_] = 0;
        totalDeposited -= amountIn;
        totalExited += amountIn;
        exitCount++;

        // Full-loop latency, measured on-chain from the origin event's timestamp.
        uint256 latency = block.timestamp >= originTimestamp_ ? block.timestamp - originTimestamp_ : 0;
        lastLoopLatencySeconds = latency;
        totalLoopLatencySeconds += latency;

        stable.transfer(user_, amountOut);
        emit StopLossExecuted(user_, assetId_, orderId_, amountIn, amountOut, price_, originTimestamp_, latency);
    }
}
