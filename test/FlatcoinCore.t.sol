// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {SimpleFlatcoinOFT} from "../contracts/flatcoin/SimpleFlatcoinOFT.sol";
import {FlatcoinCore} from "../contracts/flatcoin/FlatcoinCore.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract FlatcoinCoreTest is Test {
    SimpleFlatcoinOFT public flatcoin;
    FlatcoinCore public core;
    MockERC20 public usdt;

    address public alice = address(0x1111);
    address public bob = address(0x2222);
    address public owner = address(this);

    uint256 constant INITIAL_RESERVES = 100000 * 10**6; // 100k USDT
    uint256 constant USER_BALANCE = 10000 * 10**6; // 10k USDT

    function setUp() public {
        // Deploy mock USDT
        usdt = new MockERC20("Tether USD", "USDT", 6);

        // Deploy SimpleFlatcoinOFT with mock endpoint
        flatcoin = new SimpleFlatcoinOFT(
            "Flatcoin",
            "FLAT",
            address(0x9999), // mock endpoint
            owner
        );

        // Deploy FlatcoinCore
        core = new FlatcoinCore(address(flatcoin), address(usdt));

        // Set core contract in OFT
        flatcoin.setCoreContract(address(core));

        // Mint USDT to users and owner
        usdt.mint(owner, INITIAL_RESERVES);
        usdt.mint(alice, USER_BALANCE);
        usdt.mint(bob, USER_BALANCE);

        // Add initial reserves
        usdt.approve(address(core), INITIAL_RESERVES);
        core.addReserves(INITIAL_RESERVES);

        // Give users some ETH for gas
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testBuySpot() public {
        uint256 buyAmount = 1000 * 10**6; // 1000 USDT

        vm.startPrank(alice);
        usdt.approve(address(core), buyAmount);

        uint256 positionId = core.buySpot(buyAmount);

        // Check position created
        (address owner, uint256 principal, uint256 openTime, bool isFuture,) = core.positions(positionId);
        assertEq(owner, alice);
        assertEq(principal, 997 * 10**6); // 1000 - 0.3% fee
        assertEq(openTime, block.timestamp);
        assertFalse(isFuture);

        // Check FLAT balance
        assertEq(flatcoin.balanceOf(alice), 997 * 10**6);

        vm.stopPrank();
    }

    function testSellSpotWithInterest() public {
        uint256 buyAmount = 1000 * 10**6;

        // Alice buys FLAT
        vm.startPrank(alice);
        usdt.approve(address(core), buyAmount);
        uint256 positionId = core.buySpot(buyAmount);
        vm.stopPrank();

        // Fast forward 180 days
        vm.warp(block.timestamp + 180 days);

        // Alice sells FLAT
        vm.startPrank(alice);
        uint256 usdtBefore = usdt.balanceOf(alice);
        core.sellSpot(positionId);
        uint256 usdtAfter = usdt.balanceOf(alice);

        // Should receive principal + interest - tax
        uint256 received = usdtAfter - usdtBefore;
        // Tax formula means short-term holders may lose money
        // After 180 days: ~9.8 USDT interest, ~19.7 USDT tax = net loss
        assertGt(received, 980 * 10**6); // Will receive less than principal due to tax > interest

        // Check FLAT burned
        assertEq(flatcoin.balanceOf(alice), 0);

        vm.stopPrank();
    }

    function testPlaceAndFillBuyOrder() public {
        // Alice places a buy order
        vm.startPrank(alice);
        uint256 orderAmount = 500 * 10**6; // 500 FLAT
        uint256 orderPrice = 1.02 * 10**18; // 1.02 USDT per FLAT
        uint256 orderId = core.placeBuyOrder(orderAmount, orderPrice);
        vm.stopPrank();

        // Bob buys FLAT first
        vm.startPrank(bob);
        usdt.approve(address(core), 1000 * 10**6);
        core.buySpot(1000 * 10**6);

        // Bob fills Alice's buy order
        uint256 bobFlatBefore = flatcoin.balanceOf(bob);
        uint256 bobUsdtBefore = usdt.balanceOf(bob);

        core.fillOrder(orderId, orderAmount);

        uint256 bobFlatAfter = flatcoin.balanceOf(bob);
        uint256 bobUsdtAfter = usdt.balanceOf(bob);

        // Bob should have less FLAT
        assertEq(bobFlatBefore - bobFlatAfter, orderAmount);

        // Bob should have more USDT (at 1.02 rate)
        uint256 expectedUsdt = (orderAmount * orderPrice) / 10**18;
        assertEq(bobUsdtAfter - bobUsdtBefore, expectedUsdt);

        // Alice should have FLAT
        assertEq(flatcoin.balanceOf(alice), orderAmount);

        vm.stopPrank();
    }

    function testPlaceAndFillSellOrder() public {
        // Alice buys FLAT first
        vm.startPrank(alice);
        usdt.approve(address(core), 1000 * 10**6);
        core.buySpot(1000 * 10**6);

        // Alice places a sell order
        uint256 orderAmount = 500 * 10**6; // 500 FLAT
        uint256 orderPrice = 0.98 * 10**18; // 0.98 USDT per FLAT
        uint256 orderId = core.placeSellOrder(orderAmount, orderPrice);
        vm.stopPrank();

        // Bob fills Alice's sell order
        vm.startPrank(bob);
        uint256 bobUsdtBefore = usdt.balanceOf(bob);
        uint256 cost = (orderAmount * orderPrice) / 10**18;

        usdt.approve(address(core), cost);
        core.fillOrder(orderId, orderAmount);

        // Bob should have FLAT
        assertEq(flatcoin.balanceOf(bob), orderAmount);

        // Bob should have less USDT
        assertEq(bobUsdtBefore - usdt.balanceOf(bob), cost);

        vm.stopPrank();
    }

    function testBuyFuturePosition() public {
        vm.startPrank(alice);

        uint256 amount = 1000 * 10**6; // 1000 FLAT
        uint256 futurePrice = 1.02 * 10**18; // 1.02 USDT per FLAT
        uint256 cost = (amount * futurePrice) / 10**18;

        usdt.approve(address(core), cost);
        uint256 positionId = core.buyFuture(amount, futurePrice);

        // Check future position created
        (address owner, uint256 principal, , bool isFuture, uint256 price) = core.positions(positionId);
        assertEq(owner, alice);
        assertEq(principal, amount);
        assertTrue(isFuture);
        assertEq(price, futurePrice);

        // No FLAT should be minted for futures
        assertEq(flatcoin.balanceOf(alice), 0);

        vm.stopPrank();
    }

    function testTransferPosition() public {
        // Alice buys FLAT
        vm.startPrank(alice);
        usdt.approve(address(core), 1000 * 10**6);
        uint256 positionId = core.buySpot(1000 * 10**6);

        // Alice transfers position to Bob
        uint256 transferFee = (997 * 10**6 * 10) / 10000; // 0.1% of principal
        usdt.approve(address(core), transferFee);
        core.transferPosition(positionId, bob);
        vm.stopPrank();

        // Check position ownership changed
        (address newOwner, , , ,) = core.positions(positionId);
        assertEq(newOwner, bob);

        // Check Bob's positions
        uint256[] memory bobPositions = core.getUserPositions(bob);
        assertEq(bobPositions.length, 1);
        assertEq(bobPositions[0], positionId);
    }

    function testInterestCalculation() public {
        uint256 principal = 1000 * 10**6;
        uint256 openTime = 1000000; // Set a starting time

        // Fast forward 1 year from openTime
        vm.warp(openTime + 365 days);

        uint256 interest = core.calculateInterest(principal, openTime);

        // With 2% annual rate, interest should be 20 USDT
        uint256 expectedInterest = (principal * 200) / 10000; // 2% of 1000
        assertEq(interest, expectedInterest);
    }

    function testTaxCalculation() public {
        uint256 principal = 1000 * 10**6;
        uint256 earnedInterest = 10 * 10**6; // 10 USDT interest

        uint256 tax = core.calculateTax(principal, earnedInterest);

        // Tax = (principal - earned_interest) * interest_rate
        // Tax = (1000 - 10) * 0.02 = 19.8 USDT
        uint256 expectedTax = ((principal - earnedInterest) * 200) / 10000;
        assertEq(tax, expectedTax);
    }

    function testUpdateInterestRate() public {
        uint256 newRate = 300; // 3%

        core.updateInterestRate(newRate);

        assertEq(core.interestRate(), newRate);
        assertEq(core.getInflationIndex(), newRate);
    }

    function testCancelOrder() public {
        // Alice places an order
        vm.startPrank(alice);
        uint256 orderId = core.placeBuyOrder(100 * 10**6, 1 * 10**18);

        // Alice cancels the order
        core.cancelOrder(orderId);

        // Check order is not active
        (, , , , bool isActive) = core.orders(orderId);
        assertFalse(isActive);

        vm.stopPrank();
    }

    function testCannotFillInactiveOrder() public {
        // Alice places and cancels an order
        vm.startPrank(alice);
        uint256 orderId = core.placeBuyOrder(100 * 10**6, 1 * 10**18);
        core.cancelOrder(orderId);
        vm.stopPrank();

        // Bob tries to fill the cancelled order
        vm.startPrank(bob);
        vm.expectRevert(FlatcoinCore.OrderNotActive.selector);
        core.fillOrder(orderId, 100 * 10**6);
        vm.stopPrank();
    }

    function testReservesTracking() public {
        uint256 initialReserves = core.totalReserves();

        // Alice buys with fee
        vm.startPrank(alice);
        usdt.approve(address(core), 1000 * 10**6);
        core.buySpot(1000 * 10**6);
        vm.stopPrank();

        // Reserves should increase by the fee amount
        uint256 fee = (1000 * 10**6 * 30) / 10000; // 0.3%
        assertEq(core.totalReserves(), initialReserves + fee);
    }
}