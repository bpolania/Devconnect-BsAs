// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenizedTreasury} from "../contracts/TokenizedTreasury.sol";
import {TreasuryMarketplace} from "../contracts/TreasuryMarketplace.sol";
import {TreasuryBridgeOrchestrator} from "../contracts/TreasuryBridgeOrchestrator.sol";
import {UsdcBridgeSender} from "../contracts/UsdcBridgeSender.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockStargate} from "./mocks/MockStargate.sol";
import {Config} from "../contracts/Config.sol";

contract TokenizedTreasuryTest is Test {
    TokenizedTreasury public treasury;
    TreasuryMarketplace public marketplace;
    TreasuryBridgeOrchestrator public orchestrator;
    UsdcBridgeSender public bridgeSender;
    MockERC20 public usdc;
    MockStargate public stargate;

    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public owner = address(this);

    uint256 constant INITIAL_TREASURY_SUPPLY = 1000000 * 10**18; // 1M tokens
    uint256 constant INITIAL_USDC_LIQUIDITY = 1000000 * 10**6; // 1M USDC
    uint256 constant BASE_PRICE = 1 * 10**6; // 1 USDC per treasury token

    function setUp() public {
        // Deploy mock USDC
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy mock Stargate
        stargate = new MockStargate(address(usdc));

        // Deploy treasury token
        uint256 maturityDate = block.timestamp + 365 days;
        treasury = new TokenizedTreasury(
            "US Treasury 2-Year Token",
            "UST2Y",
            maturityDate,
            500, // 5% coupon
            "912828ZW8"
        );

        // Deploy marketplace
        marketplace = new TreasuryMarketplace(
            address(usdc),
            address(treasury),
            BASE_PRICE,
            owner
        );

        // Set higher transaction limits for testing
        marketplace.updateTradingLimits(
            1000000 * 10**18, // 1M treasury tokens max
            10000000 * 10**6  // 10M USDC daily limit
        );

        // Deploy bridge sender (payable)
        bridgeSender = new UsdcBridgeSender(
            address(stargate),
            address(usdc),
            42161 // Arbitrum chain ID
        );

        // Set composer address for Ethereum
        bridgeSender.setComposer(Config.ETHEREUM_EID, address(0x9999));

        // Deploy orchestrator
        orchestrator = new TreasuryBridgeOrchestrator(
            address(marketplace),
            address(bridgeSender),
            address(usdc),
            address(treasury)
        );

        // Setup initial liquidity
        treasury.mint(owner, INITIAL_TREASURY_SUPPLY);
        usdc.mint(owner, INITIAL_USDC_LIQUIDITY * 2);

        // Add liquidity to marketplace
        treasury.approve(address(marketplace), INITIAL_TREASURY_SUPPLY / 2);
        usdc.approve(address(marketplace), INITIAL_USDC_LIQUIDITY);
        marketplace.addLiquidity(INITIAL_TREASURY_SUPPLY / 2, INITIAL_USDC_LIQUIDITY);

        // Fund test accounts
        treasury.mint(alice, 10000 * 10**18);
        usdc.mint(alice, 100000 * 10**6);
        vm.deal(alice, 10 ether);

        treasury.mint(bob, 10000 * 10**18);
        usdc.mint(bob, 100000 * 10**6);
        vm.deal(bob, 10 ether);
    }

    function testTreasuryTokenCreation() public {
        assertEq(treasury.name(), "US Treasury 2-Year Token");
        assertEq(treasury.symbol(), "UST2Y");
        assertEq(treasury.couponRate(), 500);
        assertEq(treasury.cusip(), "912828ZW8");
        assertFalse(treasury.hasMatured());
    }

    function testMinting() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 balanceBefore = treasury.balanceOf(alice);

        treasury.mint(alice, mintAmount);

        assertEq(treasury.balanceOf(alice) - balanceBefore, mintAmount);
    }

    function testBlacklist() public {
        treasury.addToBlacklist(alice);
        assertTrue(treasury.blacklisted(alice));

        vm.expectRevert("TokenizedTreasury: recipient blacklisted");
        treasury.mint(alice, 100);

        treasury.removeFromBlacklist(alice);
        assertFalse(treasury.blacklisted(alice));
    }

    function testMarketplaceSellTreasury() public {
        uint256 sellAmount = 100 * 10**18;
        uint256 minUsdcOut = 90 * 10**6; // Accept 10% slippage

        vm.startPrank(alice);
        treasury.approve(address(marketplace), sellAmount);

        uint256 usdcBefore = usdc.balanceOf(alice);
        uint256 usdcOut = marketplace.sellTreasury(sellAmount, minUsdcOut);
        uint256 usdcAfter = usdc.balanceOf(alice);

        assertGt(usdcOut, minUsdcOut);
        assertEq(usdcAfter - usdcBefore, usdcOut);
        vm.stopPrank();
    }

    function testMarketplacePricing() public {
        // Test constant product AMM pricing
        uint256 treasuryAmount = 1000 * 10**18;
        uint256 expectedOutput = marketplace.calculateUsdcOutput(treasuryAmount);

        assertGt(expectedOutput, 0);
        assertLt(expectedOutput, INITIAL_USDC_LIQUIDITY);
    }

    function testOrchestratorSellAndBridge() public {
        uint256 treasuryToSell = 100 * 10**18;
        uint256 minUsdcOut = 90 * 10**6;
        address ethereumRecipient = address(0x3333);

        vm.startPrank(alice);

        // Approve orchestrator
        treasury.approve(address(orchestrator), treasuryToSell);

        // Quote the operation
        (uint256 expectedUsdc, uint256 bridgeFee) = orchestrator.quoteSellAndBridge(
            treasuryToSell,
            true, // Bridge all proceeds
            0
        );

        // Execute sell and bridge
        (uint256 usdcReceived, uint256 usdcBridged, bytes32 guid) = orchestrator.sellAndBridge{value: bridgeFee}(
            treasuryToSell,
            minUsdcOut,
            ethereumRecipient,
            true, // Bridge all proceeds
            0
        );

        assertEq(usdcReceived, usdcBridged);
        assertGt(usdcReceived, minUsdcOut);
        assertEq(guid, keccak256(abi.encodePacked(block.timestamp, uint256(1))));

        vm.stopPrank();
    }

    function testOrchestratorPartialBridge() public {
        uint256 treasuryToSell = 100 * 10**18;
        uint256 minUsdcOut = 90 * 10**6;
        uint256 bridgeAmount = 50 * 10**6; // Bridge only half
        address ethereumRecipient = address(0x3333);

        vm.startPrank(alice);

        treasury.approve(address(orchestrator), treasuryToSell);

        // Quote
        (uint256 expectedUsdc, uint256 bridgeFee) = orchestrator.quoteSellAndBridge(
            treasuryToSell,
            false, // Don't bridge all
            bridgeAmount
        );

        uint256 usdcBefore = usdc.balanceOf(alice);

        // Execute
        (uint256 usdcReceived, uint256 usdcBridged, ) = orchestrator.sellAndBridge{value: bridgeFee}(
            treasuryToSell,
            minUsdcOut,
            ethereumRecipient,
            false, // Don't bridge all
            bridgeAmount
        );

        uint256 usdcAfter = usdc.balanceOf(alice);

        assertEq(usdcBridged, bridgeAmount);
        assertGt(usdcReceived, usdcBridged);
        assertEq(usdcAfter - usdcBefore, usdcReceived - usdcBridged); // Remainder returned

        vm.stopPrank();
    }

    function testDirectBridge() public {
        uint256 bridgeAmount = 100 * 10**6;
        address ethereumRecipient = address(0x3333);

        vm.startPrank(alice);

        usdc.approve(address(orchestrator), bridgeAmount);

        // Get bridge fee
        (uint256 nativeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            bridgeAmount,
            ethereumRecipient
        );

        // Execute direct bridge
        bytes32 guid = orchestrator.bridgeUsdc{value: nativeFee}(
            bridgeAmount,
            ethereumRecipient
        );

        assertEq(guid, keccak256(abi.encodePacked(block.timestamp, uint256(1))));

        vm.stopPrank();
    }

    function testUserStatistics() public {
        uint256 treasuryToSell = 100 * 10**18;
        address ethereumRecipient = address(0x3333);

        vm.startPrank(alice);
        treasury.approve(address(orchestrator), treasuryToSell);

        (uint256 expectedUsdc, uint256 bridgeFee) = orchestrator.quoteSellAndBridge(
            treasuryToSell,
            true,
            0
        );

        orchestrator.sellAndBridge{value: bridgeFee}(
            treasuryToSell,
            90 * 10**6,
            ethereumRecipient,
            true,
            0
        );

        vm.stopPrank();

        // Check statistics
        (uint256 treasurySold, uint256 usdcBridged, uint256 txCount) = orchestrator.getUserStats(alice);

        assertEq(treasurySold, treasuryToSell);
        assertGt(usdcBridged, 0);
        assertEq(txCount, 1);
        assertEq(orchestrator.totalTransactions(), 1);
    }

    function testAccruedInterest() public {
        uint256 principal = 1000 * 10**18;

        // Fast forward 180 days to accumulate interest
        vm.warp(block.timestamp + 180 days);

        uint256 interest = treasury.calculateAccruedInterest(principal);

        // With 5% annual rate for 180 days, interest should be positive
        assertGt(interest, 0);

        // Should be approximately 2.5% for half year
        uint256 expectedInterest = (principal * 500 * 180) / (10000 * 365);
        assertApproxEqRel(interest, expectedInterest, 0.01e18); // 1% tolerance
    }

    function testPauseUnpause() public {
        treasury.pause();

        vm.prank(alice);
        vm.expectRevert(); // Should revert when paused
        treasury.transfer(bob, 100);

        treasury.unpause();

        vm.prank(alice);
        treasury.transfer(bob, 100); // Should work now
        assertEq(treasury.balanceOf(bob), 10000 * 10**18 + 100);
    }

    function testMarketplaceFees() public {
        uint256 initialFees = marketplace.accumulatedFees();

        vm.startPrank(alice);
        treasury.approve(address(marketplace), 100 * 10**18);
        marketplace.sellTreasury(100 * 10**18, 0);
        vm.stopPrank();

        assertGt(marketplace.accumulatedFees(), initialFees);

        // Collect fees
        uint256 feeRecipientBefore = usdc.balanceOf(owner);
        marketplace.collectFees();
        assertGt(usdc.balanceOf(owner), feeRecipientBefore);
        assertEq(marketplace.accumulatedFees(), 0);
    }
}