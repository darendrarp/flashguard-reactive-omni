// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { PriceFeed } from "../src/PriceFeed.sol";
import { MockToken } from "../src/MockToken.sol";
import { FlashGuardReactive } from "../src/FlashGuardReactive.sol";
import { ProtectedVault } from "../src/ProtectedVault.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";

/// @notice Minimal stand-in for the Reactive system contract (Lasna).
///         Etched at 0x8888... in tests; records subscriptions + callbacks.
contract MockSystem {
    struct CallbackReq {
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    CallbackReq[] public callbacks;
    uint256 public subscribeCalls;
    uint256 public unsubscribeCalls;

    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }

    function subscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        subscribeCalls++;
    }

    function unsubscribe(uint256, address, uint256, uint256, uint256, uint256) external {
        unsubscribeCalls++;
    }

    function requestCallback(ISystemContract.CallbackVersion, bytes memory) external {}

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config_) external {
        callbacks.push(
            CallbackReq({
                chainId: config_.chainId,
                recipient: config_.recipient,
                gasLimit: config_.gasLimit,
                payload: config_.payload
            })
        );
    }

    function callbackCount() external view returns (uint256) {
        return callbacks.length;
    }
}

/// @notice Minimal stand-in for the Base Sepolia callback proxy.
contract MockProxy {
    receive() external payable {}

    function debt(address) external pure returns (uint256) {
        return 0;
    }
}

contract FlashGuardTest is Test {
    address payable constant SYSTEM_ADDR = payable(0x8888888888888888888888888888888888888888);

    PriceFeed feed;
    MockToken meth;
    MockToken musdc;
    FlashGuardReactive reactive;
    ProtectedVault vault;
    MockProxy proxy;
    MockSystem system;

    address owner = address(this);
    address user = address(0xBEEF);
    address stranger = address(0xDEAD);

    // keccak256("PriceUpdated(uint256,uint256,uint256)") — cached so _priceLog
    // makes no external call (an external call would consume a pending prank).
    uint256 constant TOPIC0 = 0x15819dd2fd9f6418b142e798d08a18d0bf06ea368f4480b7b0d3f75bd966bc48;
    uint256 constant ASSET_ID = 1;
    uint256 constant PRICE_HIGH = 3000e8; // $3,000
    uint256 constant PRICE_LOW = 2400e8; // $2,400
    uint256 constant THRESHOLD = 2500e8; // $2,500 stop-loss

    function setUp() public {
        vm.deal(address(this), 100 ether);
        // Etch the mock system contract at the real SYSTEM address.
        system = new MockSystem();
        vm.etch(SYSTEM_ADDR, address(system).code);

        feed = new PriceFeed();
        meth = new MockToken("Mock ETH", "mETH", 18);
        musdc = new MockToken("Mock USD Coin", "mUSDC", 6);
        proxy = new MockProxy();

        reactive = new FlashGuardReactive{ value: 1 ether }(address(feed));
        vault = new ProtectedVault{ value: 1 ether }(
            IPayable(payable(address(proxy))), address(reactive), address(meth), address(musdc)
        );
        reactive.setVault(address(vault));

        // Fund the user + the vault reserve.
        meth.mint(user, 10 ether);
        musdc.mint(address(this), 1_000_000e6);
        musdc.transfer(address(vault), 100_000e6);
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _priceLog(uint256 price, uint256 originTs) internal view returns (IReactive.LogRecord memory) {
        return
            IReactive.LogRecord({
                chainId: 1301,
                contractAddress: address(feed),
                topic0: TOPIC0,
                topic1: ASSET_ID,
                topic2: 0,
                topic3: 0,
                data: abi.encode(price, originTs),
                blockNumber: 1,
                opCode: 2,
                blockHash: 0,
                txHash: 0,
                logIndex: 0
            });
    }

    function _depositAndOrder(uint256 depositAmount) internal returns (uint256 orderId) {
        vm.startPrank(user);
        meth.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        orderId = reactive.registerOrder(user, ASSET_ID, THRESHOLD);
    }

    function _deliverCallback(uint256 index) internal {
        // Simulate the proxy delivering a recorded callback to the vault,
        // injecting the reactive contract's address as the first argument.
        (uint256 chainId, address recipient, uint64 gasLimit, bytes memory payload) = MockSystem(SYSTEM_ADDR)
            .callbacks(index);
        assertEq(chainId, 84532);
        assertEq(recipient, address(vault));
        assertEq(gasLimit, 500_000);
        // Decode the payload, then re-encode with the injected sender.
        (, address cbUser, uint256 cbAsset, uint256 cbPrice, uint256 cbOrder, uint256 cbTs) = abi.decode(
            _stripSelector(payload),
            (address, address, uint256, uint256, uint256, uint256)
        );
        vm.prank(address(proxy));
        vault.executeStopLoss(address(reactive), cbUser, cbAsset, cbPrice, cbOrder, cbTs);
    }

    function _stripSelector(bytes memory payload) internal pure returns (bytes memory) {
        bytes memory body = new bytes(payload.length - 4);
        for (uint256 i = 0; i < body.length; i++) {
            body[i] = payload[i + 4];
        }
        return body;
    }

    // ------------------------------------------------------------------
    // PriceFeed
    // ------------------------------------------------------------------

    function testFeedPostsPriceAndEmits() public {
        feed.postPrice(ASSET_ID, PRICE_HIGH);
        (uint256 price, uint256 ts) = feed.getPrice(ASSET_ID);
        assertEq(price, PRICE_HIGH);
        assertEq(ts, block.timestamp);
    }

    function testFeedRejectsNonUpdater() public {
        vm.prank(stranger);
        vm.expectRevert(PriceFeed.NotUpdater.selector);
        feed.postPrice(ASSET_ID, PRICE_HIGH);
    }

    // ------------------------------------------------------------------
    // Reactive: subscription + orders
    // ------------------------------------------------------------------

    function testReactiveSubscribesOnDeploy() public view {
        assertEq(MockSystem(SYSTEM_ADDR).subscribeCalls(), 1);
    }

    function testRegisterOrder() public {
        uint256 id = reactive.registerOrder(user, ASSET_ID, THRESHOLD);
        (address u, uint256 a, uint256 t, bool active, bool trig, , ) = reactive.orders(id);
        assertEq(u, user);
        assertEq(a, ASSET_ID);
        assertEq(t, THRESHOLD);
        assertTrue(active);
        assertFalse(trig);
    }

    function testCancelOrder() public {
        uint256 id = reactive.registerOrder(user, ASSET_ID, THRESHOLD);
        vm.prank(user);
        reactive.cancelOrder(id);
        (, , , bool active, , , ) = reactive.orders(id);
        assertFalse(active);
    }

    // ------------------------------------------------------------------
    // Reactive: react()
    // ------------------------------------------------------------------

    function testReactIgnoresPriceAboveThreshold() public {
        _depositAndOrder(1 ether);
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(PRICE_HIGH, block.timestamp));
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 0);
        assertEq(reactive.triggersCount(), 0);
    }

    function testReactTriggersAtThreshold() public {
        uint256 id = _depositAndOrder(1 ether);
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(THRESHOLD, block.timestamp)); // exactly at threshold triggers
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 1);
        assertEq(reactive.triggersCount(), 1);
        (, , , bool active, bool trig, uint256 tp, ) = reactive.orders(id);
        assertFalse(active);
        assertTrue(trig);
        assertEq(tp, THRESHOLD);
    }

    function testReactTriggersBelowThresholdOnce() public {
        _depositAndOrder(1 ether);
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(PRICE_LOW, block.timestamp));
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(PRICE_LOW - 100e8, block.timestamp));
        // Second event must not re-trigger the same order.
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 1);
        assertEq(reactive.triggersCount(), 1);
    }

    function testReactRejectsNonSystemCaller() public {
        vm.prank(stranger);
        vm.expectRevert();
        reactive.react(_priceLog(PRICE_LOW, block.timestamp));
    }

    function testReactIgnoresWrongTopicAndContract() public {
        _depositAndOrder(1 ether);
        IReactive.LogRecord memory log = _priceLog(PRICE_LOW, block.timestamp);
        log.topic0 = 0x1234;
        vm.prank(SYSTEM_ADDR);
        reactive.react(log);
        log = _priceLog(PRICE_LOW, block.timestamp);
        log.contractAddress = stranger;
        vm.prank(SYSTEM_ADDR);
        reactive.react(log);
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 0);
    }

    function testReactDoesNothingWithoutVault() public {
        FlashGuardReactive noVault = new FlashGuardReactive(address(feed));
        noVault.registerOrder(user, ASSET_ID, THRESHOLD);
        IReactive.LogRecord memory log = _priceLog(PRICE_LOW, block.timestamp);
        vm.prank(SYSTEM_ADDR);
        noVault.react(log); // must not revert, must not request a callback
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 0);
    }

    // ------------------------------------------------------------------
    // Vault
    // ------------------------------------------------------------------

    function testVaultDepositWithdraw() public {
        vm.startPrank(user);
        meth.approve(address(vault), 2 ether);
        vault.deposit(2 ether);
        assertEq(vault.deposits(user), 2 ether);
        vault.withdraw(1 ether);
        assertEq(vault.deposits(user), 1 ether);
        vm.stopPrank();
    }

    function testVaultRejectsDirectCallbackCall() public {
        _depositAndOrder(1 ether);
        vm.prank(stranger);
        vm.expectRevert();
        vault.executeStopLoss(address(reactive), user, ASSET_ID, PRICE_LOW, 0, block.timestamp);
    }

    function testVaultRejectsWrongSender() public {
        _depositAndOrder(1 ether);
        vm.prank(address(proxy));
        vm.expectRevert();
        vault.executeStopLoss(stranger, user, ASSET_ID, PRICE_LOW, 0, block.timestamp);
    }

    // ------------------------------------------------------------------
    // Full loop: feed event -> react -> callback -> exit + latency
    // ------------------------------------------------------------------

    function testFullLoopExitsPositionAndMeasuresLatency() public {
        uint256 depositAmount = 2 ether;
        uint256 orderId = _depositAndOrder(depositAmount);

        uint256 originTs = block.timestamp;
        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(PRICE_LOW, originTs));

        // Simulate the ~seconds the real loop takes: origin -> Lasna -> Base.
        vm.warp(block.timestamp + 4);

        uint256 musdcBefore = musdc.balanceOf(user);
        _deliverCallback(0);

        // 2 mETH * $2,400 = $4,800 -> 4,800e6 mUSDC.
        assertEq(musdc.balanceOf(user) - musdcBefore, 4800e6);
        assertEq(vault.deposits(user), 0);
        assertEq(vault.exitCount(), 1);
        assertEq(vault.lastLoopLatencySeconds(), 4);
        assertEq(vault.averageLoopLatencySeconds(), 4);
        assertEq(vault.totalExited(), depositAmount);
        assertEq(orderId, 0);
    }

    function testFullLoopSecondUserIndependent() public {
        address user2 = address(0xCAFE);
        meth.mint(user2, 5 ether);
        vm.startPrank(user2);
        meth.approve(address(vault), 5 ether);
        vault.deposit(5 ether);
        vm.stopPrank();
        _depositAndOrder(1 ether); // user 1, threshold 2500e8
        reactive.registerOrder(user2, ASSET_ID, 2000e8); // user 2, lower threshold

        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(PRICE_LOW, block.timestamp)); // $2,400: only user 1 triggers
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 1);

        vm.prank(SYSTEM_ADDR);
        reactive.react(_priceLog(1900e8, block.timestamp)); // $1,900: user 2 triggers
        assertEq(MockSystem(SYSTEM_ADDR).callbackCount(), 2);
    }
}
