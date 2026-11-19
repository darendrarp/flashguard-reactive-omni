// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { MockToken } from "../src/MockToken.sol";
import { ProtectedVault } from "../src/ProtectedVault.sol";

/// @notice Deploy MockToken (mETH + mUSDC) and ProtectedVault on Base Sepolia.
/// @dev Requires REACTIVE (FlashGuardReactive address on Lasna) in env.
///      Mints 10 mETH to the deployer (demo user funds) and funds the vault
///      with 100,000 mUSDC reserve so exits can pay out.
///      forge script script/DeployVault.s.sol --rpc-url base-sepolia --broadcast
contract DeployVault is Script {
    /// @notice Base Sepolia callback proxy (Reactive docs, Origins & Destinations).
    address public constant BASE_SEPOLIA_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;

    function run() external returns (ProtectedVault vault, MockToken meth, MockToken musdc) {
        uint256 key = vm.envUint("PRIVATE_KEY");
        address reactive = vm.envAddress("REACTIVE");
        address deployer = vm.addr(key);

        vm.startBroadcast(key);
        meth = new MockToken("Mock ETH", "mETH", 18);
        musdc = new MockToken("Mock USD Coin", "mUSDC", 6);
        vault = new ProtectedVault{ value: 0.05 ether }(
            IPayable(payable(BASE_SEPOLIA_PROXY)),
            reactive,
            address(meth),
            address(musdc)
        );
        meth.mint(deployer, 10 ether);
        musdc.mint(deployer, 200_000e6);
        musdc.transfer(address(vault), 100_000e6);
        vm.stopBroadcast();

        console.log("mETH:", address(meth));
        console.log("mUSDC:", address(musdc));
        console.log("ProtectedVault:", address(vault));
        console.log("Callback sender (reactive):", reactive);
    }
}
