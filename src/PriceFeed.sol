// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title PriceFeed — origin-chain price oracle for FlashGuard
/// @notice Deployed on Unichain Sepolia (chain ID 1301). A designated updater posts
///         asset prices; every post emits `PriceUpdated`, the event the FlashGuard
///         reactive contract on Reactive Lasna subscribes to.
/// @dev Prices use 8 decimals, Chainlink style (e.g. $3,000.00 == 3000e8).
///      This is a demo oracle for the hackathon: in production the updater would be
///      a Chainlink feed, a Uniswap TWAP reader, or a decentralized oracle network.
///      The reactive stop-loss logic is fully independent of how the price gets here.
contract PriceFeed {
    address public owner;
    mapping(address => bool) public updaters;
    mapping(uint256 assetId => uint256 price) public latestPrice;
    mapping(uint256 assetId => uint256 timestamp) public latestTimestamp;

    /// @notice Emitted on every price post. topic0 = signature, topic1 = assetId,
    ///         data = abi.encode(price, timestamp). opCode == 2.
    event PriceUpdated(uint256 indexed assetId, uint256 price, uint256 timestamp);
    event UpdaterSet(address indexed updater, bool allowed);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error NotUpdater();
    error InvalidPrice();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyUpdater() {
        if (!updaters[msg.sender]) revert NotUpdater();
        _;
    }

    constructor() {
        owner = msg.sender;
        updaters[msg.sender] = true;
    }

    /// @notice Post a new price for an asset. Emits the event Reactive watches.
    function postPrice(uint256 assetId, uint256 price) external onlyUpdater {
        if (price == 0) revert InvalidPrice();
        latestPrice[assetId] = price;
        latestTimestamp[assetId] = block.timestamp;
        emit PriceUpdated(assetId, price, block.timestamp);
    }

    function setUpdater(address updater, bool allowed) external onlyOwner {
        updaters[updater] = allowed;
        emit UpdaterSet(updater, allowed);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function getPrice(uint256 assetId) external view returns (uint256 price, uint256 timestamp) {
        return (latestPrice[assetId], latestTimestamp[assetId]);
    }
}
