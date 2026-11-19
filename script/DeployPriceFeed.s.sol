// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { PriceFeed } from "../src/PriceFeed.sol";

/// @notice Deploy PriceFeed on Unichain Sepolia (chain ID 1301).
/// @dev forge script script/DeployPriceFeed.s.sol --rpc-url unichain-sepolia --broadcast
contract DeployPriceFeed is Script {
    function run() external returns (PriceFeed feed) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(key);
        feed = new PriceFeed();
        vm.stopBroadcast();
        console.log("PriceFeed:", address(feed));
    }
}
