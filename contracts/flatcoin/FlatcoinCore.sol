// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SimpleFlatcoinOFT} from "./SimpleFlatcoinOFT.sol";

/**
 * @title FlatcoinCore
 * @notice Core contract managing FLAT positions, orders, and inflation mechanics
 * @dev Users buy FLAT with USDT at 1:1 and earn inflation-adjusted interest when selling
 */
contract FlatcoinCore is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    SimpleFlatcoinOFT public immutable flatcoin;
    IERC20 public immutable usdt;

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SPOT_FEE = 30; // 0.3% spot order fee
    uint256 public constant TRANSFER_FEE = 10; // 0.1% position transfer fee

    // Interest rate (annual, in basis points) - starts at 2% (200 bp)
    uint256 public interestRate = 200;

    // Total reserves held by the protocol
    uint256 public totalReserves;

    // Position counter
    uint256 public nextPositionId = 1;

    // ============ Structs ============

    struct Position {
        address owner;
        uint256 principal;
        uint256 openTime;
        bool isFuture;
        uint256 futurePrice; // Price for future positions (0 for spot)
    }

    struct Order {
        address maker;
        uint256 amount;
        uint256 price;
        bool isBuyOrder;
        bool isActive;
    }

    // ============ Mappings ============

    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositions;
    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId = 1;

    // ============ Events ============

    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        uint256 principal,
        bool isFuture,
        uint256 futurePrice
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 principal,
        uint256 interest,
        uint256 tax
    );

    event PositionTransferred(
        uint256 indexed positionId,
        address indexed from,
        address indexed to,
        uint256 fee
    );

    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        uint256 amount,
        uint256 price,
        bool isBuyOrder
    );

    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        uint256 amount
    );

    event OrderCancelled(uint256 indexed orderId);

    event InterestRateUpdated(uint256 oldRate, uint256 newRate);

    // ============ Errors ============

    error InvalidAmount();
    error InvalidPrice();
    error PositionNotFound();
    error NotPositionOwner();
    error OrderNotFound();
    error OrderNotActive();
    error InsufficientReserves();
    error InsufficientBalance();

    // ============ Constructor ============

    constructor(
        address _flatcoin,
        address _usdt
    ) Ownable(msg.sender) {
        flatcoin = SimpleFlatcoinOFT(_flatcoin);
        usdt = IERC20(_usdt);
    }

    // ============ Buy Functions ============

    /**
     * @notice Buy FLAT tokens spot (immediate execution)
     * @param amount Amount of USDT to spend (and FLAT to receive)
     * @return positionId The ID of the created position
     */
    function buySpot(uint256 amount) external nonReentrant returns (uint256 positionId) {
        if (amount == 0) revert InvalidAmount();

        // Calculate fee
        uint256 fee = (amount * SPOT_FEE) / BASIS_POINTS;
        uint256 netAmount = amount - fee;

        // Transfer USDT from user
        usdt.safeTransferFrom(msg.sender, address(this), amount);

        // Add fee to reserves
        totalReserves += fee;

        // Mint FLAT tokens
        flatcoin.mint(msg.sender, netAmount);

        // Create position
        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            principal: netAmount,
            openTime: block.timestamp,
            isFuture: false,
            futurePrice: 0
        });

        userPositions[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, netAmount, false, 0);
    }

    /**
     * @notice Place a buy order at a specific price
     * @param amount Amount of FLAT tokens to buy
     * @param price Price per FLAT in USDT (with PRECISION decimals)
     * @return orderId The ID of the created order
     */
    function placeBuyOrder(uint256 amount, uint256 price) external returns (uint256 orderId) {
        if (amount == 0) revert InvalidAmount();
        if (price == 0) revert InvalidPrice();

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            amount: amount,
            price: price,
            isBuyOrder: true,
            isActive: true
        });

        emit OrderPlaced(orderId, msg.sender, amount, price, true);
    }

    /**
     * @notice Buy a future position at a specific price
     * @param amount Amount of FLAT tokens
     * @param futurePrice Price for the future position
     * @return positionId The ID of the created future position
     */
    function buyFuture(uint256 amount, uint256 futurePrice) external returns (uint256 positionId) {
        if (amount == 0) revert InvalidAmount();
        if (futurePrice <= PRECISION) revert InvalidPrice(); // Must be > 1 USDT

        uint256 cost = (amount * futurePrice) / PRECISION;

        // Transfer USDT from user
        usdt.safeTransferFrom(msg.sender, address(this), cost);

        // Create future position (no tokens minted yet)
        positionId = nextPositionId++;
        positions[positionId] = Position({
            owner: msg.sender,
            principal: amount,
            openTime: block.timestamp,
            isFuture: true,
            futurePrice: futurePrice
        });

        userPositions[msg.sender].push(positionId);

        emit PositionOpened(positionId, msg.sender, amount, true, futurePrice);
    }

    // ============ Sell Functions ============

    /**
     * @notice Sell FLAT tokens spot (close position)
     * @param positionId ID of the position to close
     */
    function sellSpot(uint256 positionId) external nonReentrant {
        Position memory position = positions[positionId];

        if (position.owner == address(0)) revert PositionNotFound();
        if (position.owner != msg.sender) revert NotPositionOwner();
        if (position.isFuture) revert("Cannot spot sell future position");

        // Calculate interest earned
        uint256 interest = calculateInterest(position.principal, position.openTime);
        uint256 totalPayout = position.principal + interest;

        // Calculate tax
        uint256 tax = calculateTax(position.principal, interest);
        uint256 netPayout = totalPayout - tax;

        // Check reserves
        if (totalReserves + tax < netPayout) revert InsufficientReserves();

        // Burn FLAT tokens
        flatcoin.burn(msg.sender, position.principal);

        // Transfer USDT to user
        usdt.safeTransfer(msg.sender, netPayout);

        // Update reserves
        totalReserves = totalReserves + tax - interest;

        // Delete position
        delete positions[positionId];
        _removePositionFromUser(msg.sender, positionId);

        emit PositionClosed(positionId, msg.sender, position.principal, interest, tax);
    }

    /**
     * @notice Place a sell order at a specific price
     * @param amount Amount of FLAT tokens to sell
     * @param price Price per FLAT in USDT
     * @return orderId The ID of the created order
     */
    function placeSellOrder(uint256 amount, uint256 price) external returns (uint256 orderId) {
        if (amount == 0) revert InvalidAmount();
        if (price == 0) revert InvalidPrice();
        if (flatcoin.balanceOf(msg.sender) < amount) revert InsufficientBalance();

        orderId = nextOrderId++;
        orders[orderId] = Order({
            maker: msg.sender,
            amount: amount,
            price: price,
            isBuyOrder: false,
            isActive: true
        });

        emit OrderPlaced(orderId, msg.sender, amount, price, false);
    }

    // ============ Order Matching ============

    /**
     * @notice Fill an existing order
     * @param orderId ID of the order to fill
     * @param amount Amount to fill (can be partial)
     */
    function fillOrder(uint256 orderId, uint256 amount) external nonReentrant {
        Order storage order = orders[orderId];

        if (!order.isActive) revert OrderNotActive();
        if (amount == 0 || amount > order.amount) revert InvalidAmount();

        uint256 cost = (amount * order.price) / PRECISION;

        if (order.isBuyOrder) {
            // Maker wants to buy, taker is selling
            if (flatcoin.balanceOf(msg.sender) < amount) revert InsufficientBalance();

            // Transfer FLAT from taker to maker
            flatcoin.burn(msg.sender, amount);
            flatcoin.mint(order.maker, amount);

            // Transfer USDT from this contract to taker
            usdt.safeTransfer(msg.sender, cost);
        } else {
            // Maker wants to sell, taker is buying
            // Transfer USDT from taker
            usdt.safeTransferFrom(msg.sender, address(this), cost);

            // Transfer FLAT from maker to taker
            flatcoin.burn(order.maker, amount);
            flatcoin.mint(msg.sender, amount);
        }

        // Update order
        order.amount -= amount;
        if (order.amount == 0) {
            order.isActive = false;
        }

        emit OrderFilled(orderId, msg.sender, amount);
    }

    /**
     * @notice Cancel an order
     * @param orderId ID of the order to cancel
     */
    function cancelOrder(uint256 orderId) external {
        Order storage order = orders[orderId];

        if (order.maker != msg.sender) revert("Not order maker");
        if (!order.isActive) revert OrderNotActive();

        order.isActive = false;

        emit OrderCancelled(orderId);
    }

    // ============ Position Management ============

    /**
     * @notice Transfer a position to another address
     * @param positionId ID of the position to transfer
     * @param to Address to transfer to
     */
    function transferPosition(uint256 positionId, address to) external {
        Position storage position = positions[positionId];

        if (position.owner == address(0)) revert PositionNotFound();
        if (position.owner != msg.sender) revert NotPositionOwner();

        // Calculate transfer fee
        uint256 fee = (position.principal * TRANSFER_FEE) / BASIS_POINTS;

        // Transfer fee in USDT
        usdt.safeTransferFrom(msg.sender, address(this), fee);
        totalReserves += fee;

        // Update position owner
        address oldOwner = position.owner;
        position.owner = to;

        // Update user positions mapping
        _removePositionFromUser(oldOwner, positionId);
        userPositions[to].push(positionId);

        emit PositionTransferred(positionId, oldOwner, to, fee);
    }

    // ============ Interest & Tax Calculations ============

    /**
     * @notice Calculate interest earned on a position
     * @param principal Principal amount
     * @param openTime Time when position was opened
     * @return interest Interest earned
     */
    function calculateInterest(uint256 principal, uint256 openTime) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - openTime;
        uint256 annualInterest = (principal * interestRate) / BASIS_POINTS;
        return (annualInterest * timeElapsed) / 365 days;
    }

    /**
     * @notice Calculate tax on position closure
     * @param principal Principal amount
     * @param earnedInterest Interest earned
     * @return tax Tax amount
     */
    function calculateTax(uint256 principal, uint256 earnedInterest) public view returns (uint256) {
        // Tax formula: (principal - earned_interest) * interest_rate
        // This creates incentive dynamics for holding
        if (earnedInterest >= principal) return 0;

        uint256 taxableAmount = principal - earnedInterest;
        return (taxableAmount * interestRate) / BASIS_POINTS;
    }

    // ============ Admin Functions ============

    /**
     * @notice Update the interest rate (affects inflation index)
     * @param newRate New interest rate in basis points
     */
    function updateInterestRate(uint256 newRate) external onlyOwner {
        if (newRate == 0 || newRate > 2000) revert("Invalid rate"); // Max 20%

        uint256 oldRate = interestRate;
        interestRate = newRate;

        emit InterestRateUpdated(oldRate, newRate);
    }

    /**
     * @notice Add reserves to the system
     * @param amount Amount of USDT to add
     */
    function addReserves(uint256 amount) external onlyOwner {
        usdt.safeTransferFrom(msg.sender, address(this), amount);
        totalReserves += amount;
    }

    // ============ View Functions ============

    /**
     * @notice Get user's position IDs
     * @param user Address of the user
     * @return Position IDs
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }

    /**
     * @notice Get current inflation index (interest rate)
     * @return Inflation index in basis points
     */
    function getInflationIndex() external view returns (uint256) {
        return interestRate;
    }

    // ============ Internal Functions ============

    function _removePositionFromUser(address user, uint256 positionId) internal {
        uint256[] storage positions = userPositions[user];
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i] == positionId) {
                positions[i] = positions[positions.length - 1];
                positions.pop();
                break;
            }
        }
    }
}