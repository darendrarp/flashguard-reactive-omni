// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { FlashGuardReactive } from "../src/FlashGuardReactive.sol";

/// @notice Deploy FlashGuardReactive on Reactive Lasna (chain ID 5318007).
/// @dev Requires PRICE_FEED (Unichain Sepolia PriceFeed address) in env.
///      Funds the reactive contract with 0.5 lREACT so it can pay for its own
///      reactive transactions. Get lREACT from the faucet (see README).
///      forge script script/DeployReactive.s.sol --rpc-url lasna --broadcast
contract DeployReactive is Script {
    function run() external returns (FlashGuardReactive reactive) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address priceFeed = vm.envAddress("PRICE_FEED");
        vm.startBroadcast(key);
        reactive = new FlashGuardReactive{ value: 0.5 ether }(priceFeed);
        vm.stopBroadcast();
        console.log("FlashGuardReactive:", address(reactive));
        console.log("Subscribed to PriceFeed:", priceFeed);
    }
}
