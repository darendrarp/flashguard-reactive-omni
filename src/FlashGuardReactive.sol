// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractReactive } from "@reactive/src/base/AbstractReactive.sol";

/// @title FlashGuardReactive — cross-chain stop-loss engine on Reactive Lasna
/// @notice Watches `PriceUpdated` events from the PriceFeed on Unichain Sepolia.
///         The moment a price prints at or below a registered stop-loss threshold,
///         it requests a callback to the ProtectedVault on Base Sepolia, which exits
///         the user's position. No bot, no keeper — the reaction is on-chain.
/// @dev Deployed on Reactive Lasna (chain ID 5318007). Funded in lREACT: the
///      contract pays for its own reactive transactions. Keep it topped up or it
///      stops receiving events (see `coverDebt`).
contract FlashGuardReactive is AbstractReactive {
    /// @notice Unichain Sepolia chain ID (origin chain).
    uint256 public constant ORIGIN_CHAIN_ID = 1301;
    /// @notice Base Sepolia chain ID (destination chain).
    uint256 public constant DESTINATION_CHAIN_ID = 84532;
    /// @notice Gas forwarded to the vault callback. The proxy withholds overhead
    ///         on top of this; 500k comfortably covers the vault's exit logic.
    uint64 public constant CALLBACK_GAS_LIMIT = 500_000;
    /// @notice Max orders scanned per price event, bounding react() gas.
    uint256 public constant MAX_ORDERS_PER_EVENT = 50;

    /// @notice keccak256("PriceUpdated(uint256,uint256,uint256)")
    uint256 public constant PRICE_UPDATED_TOPIC_0 =
        0x15819dd2fd9f6418b142e798d08a18d0bf06ea368f4480b7b0d3f75bd966bc48;

    struct Order {
        address user;
        uint256 assetId;
        uint256 threshold; // stop-loss trigger price, 8 decimals
        bool active;
        bool triggered;
        uint256 triggeredPrice;
        uint256 triggeredAt; // Lasna block timestamp of the trigger
    }

    address public owner;
    address public immutable priceFeed;
    address public vault; // ProtectedVault on Base Sepolia (set after deployment)

    Order[] public orders;
    mapping(uint256 assetId => uint256[] orderIds) public ordersByAsset;
    uint256 public triggersCount;

    event OrderRegistered(uint256 indexed orderId, address indexed user, uint256 indexed assetId, uint256 threshold);
    event OrderCancelled(uint256 indexed orderId, address indexed user);
    event StopLossTriggered(
        uint256 indexed orderId,
        address indexed user,
        uint256 indexed assetId,
        uint256 price,
        uint256 originTimestamp
    );
    event VaultSet(address indexed vault);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error VaultNotSet();
    error InvalidOrder();
    error NotOrderOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param priceFeed_ PriceFeed contract on Unichain Sepolia to subscribe to.
    constructor(address priceFeed_) payable {
        owner = msg.sender;
        priceFeed = priceFeed_;
        SYSTEM.subscribe(
            ORIGIN_CHAIN_ID,
            priceFeed_,
            PRICE_UPDATED_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }

    // ------------------------------------------------------------------------
    // Orders
    // ------------------------------------------------------------------------

    /// @notice Register a stop-loss order. Anyone may register for themselves;
    ///         the owner (demo operator) may register on behalf of any user.
    /// @return orderId The new order's id.
    function registerOrder(address user, uint256 assetId, uint256 threshold) external returns (uint256 orderId) {
        if (user == address(0) || threshold == 0) revert InvalidOrder();
        if (msg.sender != owner && msg.sender != user) revert NotOrderOwner();
        orderId = orders.length;
        orders.push(
            Order({
                user: user,
                assetId: assetId,
                threshold: threshold,
                active: true,
                triggered: false,
                triggeredPrice: 0,
                triggeredAt: 0
            })
        );
        ordersByAsset[assetId].push(orderId);
        emit OrderRegistered(orderId, user, assetId, threshold);
    }

    /// @notice Cancel an active order (owner of the order, or contract owner).
    function cancelOrder(uint256 orderId) external {
        if (orderId >= orders.length) revert InvalidOrder();
        Order storage order = orders[orderId];
        if (msg.sender != owner && msg.sender != order.user) revert NotOrderOwner();
        order.active = false;
        emit OrderCancelled(orderId, order.user);
    }

    /// @notice Point the reactive contract at the deployed vault (Base Sepolia).
    ///         Must be called after the vault is deployed; the vault itself needs
    ///         this contract's address at construction, so the link closes here.
    function setVault(address vault_) external onlyOwner {
        vault = vault_;
        emit VaultSet(vault_);
    }

    /// @notice Settles outstanding debt from this contract's own balance.
    ///         A contract in debt receives no reactive transactions.
    function coverDebt() external {
        _coverDebt();
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function orderCount() external view returns (uint256) {
        return orders.length;
    }

    function ordersForAsset(uint256 assetId) external view returns (uint256[] memory) {
        return ordersByAsset[assetId];
    }

    // ------------------------------------------------------------------------
    // Reactive entry point
    // ------------------------------------------------------------------------

    /// @inheritdoc IReactive
    /// @notice Called by the system contract for every matching PriceUpdated log.
    ///         Non-matching logs fall through silently (never revert as a filter:
    ///         the system still bills the gas).
    function react(LogRecord memory log_) external onlySystem {
        if (log_.topic0 != PRICE_UPDATED_TOPIC_0) return;
        if (log_.contractAddress != priceFeed) return;
        if (log_.opCode != 2) return; // PriceUpdated has 1 indexed arg (assetId)
        if (vault == address(0)) return;

        uint256 assetId = log_.topic1;
        (uint256 price, uint256 originTimestamp) = abi.decode(log_.data, (uint256, uint256));

        uint256[] storage ids = ordersByAsset[assetId];
        uint256 scanned = 0;
        for (uint256 i = 0; i < ids.length && scanned < MAX_ORDERS_PER_EVENT; i++) {
            uint256 orderId = ids[i];
            Order storage order = orders[orderId];
            if (!order.active || order.triggered) continue;
            scanned++;
            if (price > order.threshold) continue;

            // Threshold breached: mark first (re-entrancy / duplicate safety),
            // then request the exit callback on Base Sepolia.
            order.triggered = true;
            order.active = false;
            order.triggeredPrice = price;
            order.triggeredAt = block.timestamp;
            triggersCount++;

            emit StopLossTriggered(orderId, order.user, assetId, price, originTimestamp);

            bytes memory payload = abi.encodeWithSignature(
                "executeStopLoss(address,address,uint256,uint256,uint256,uint256)",
                address(0), // placeholder: proxy injects this contract's address
                order.user,
                assetId,
                price,
                orderId,
                originTimestamp
            );
            SYSTEM.requestCallbackV_1_0(
                ISystemContract.CallbackConfiguration_V_1_0({
                    chainId: DESTINATION_CHAIN_ID,
                    recipient: vault,
                    gasLimit: CALLBACK_GAS_LIMIT,
                    payload: payload
                })
            );
        }
    }
}
