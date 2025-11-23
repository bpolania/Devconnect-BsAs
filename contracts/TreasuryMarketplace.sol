// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title TreasuryMarketplace
 * @notice Marketplace for selling tokenized treasury notes for USDC on Arbitrum
 * @dev Implements an automated market maker (AMM) style pricing with admin controls
 */
contract TreasuryMarketplace is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Core token addresses
    IERC20 public immutable usdc;
    IERC20 public immutable treasuryToken;

    // Pricing parameters (all in basis points for precision)
    uint256 public basePrice; // Base price in USDC per treasury token (6 decimals for USDC)
    uint256 public spreadBps = 50; // 0.5% spread
    uint256 public slippageBps = 100; // 1% max slippage

    // Liquidity management
    uint256 public treasuryReserve; // Treasury tokens available for sale
    uint256 public usdcReserve; // USDC in the pool
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    // Fee structure
    uint256 public feeBps = 30; // 0.3% fee
    address public feeRecipient;
    uint256 public accumulatedFees;

    // Trading limits
    uint256 public maxTransactionSize;
    uint256 public dailyVolumeLimit;
    uint256 public currentDayVolume;
    uint256 public lastResetTimestamp;

    // Oracle price feed (simplified - in production use Chainlink)
    address public priceOracle;
    uint256 public lastOraclePrice;
    uint256 public lastOracleUpdate;

    event TreasurySold(
        address indexed seller,
        uint256 treasuryAmount,
        uint256 usdcReceived,
        uint256 fee
    );

    event LiquidityAdded(
        uint256 treasuryAmount,
        uint256 usdcAmount
    );

    event LiquidityRemoved(
        uint256 treasuryAmount,
        uint256 usdcAmount
    );

    event PriceUpdated(uint256 newPrice);
    event FeesCollected(uint256 amount);

    constructor(
        address _usdc,
        address _treasuryToken,
        uint256 _basePrice,
        address _feeRecipient
    ) Ownable(msg.sender) {
        require(_usdc != address(0), "TreasuryMarketplace: invalid USDC");
        require(_treasuryToken != address(0), "TreasuryMarketplace: invalid treasury token");
        require(_basePrice > 0, "TreasuryMarketplace: invalid base price");

        usdc = IERC20(_usdc);
        treasuryToken = IERC20(_treasuryToken);
        basePrice = _basePrice;
        feeRecipient = _feeRecipient;

        lastResetTimestamp = block.timestamp;
        maxTransactionSize = 1000000 * 10**6; // 1M USDC default
        dailyVolumeLimit = 10000000 * 10**6; // 10M USDC daily limit
    }

    /**
     * @notice Sell treasury tokens for USDC
     * @param treasuryAmount Amount of treasury tokens to sell
     * @param minUsdcOut Minimum USDC to receive (slippage protection)
     * @return usdcOut Amount of USDC received
     */
    function sellTreasury(
        uint256 treasuryAmount,
        uint256 minUsdcOut
    ) external nonReentrant whenNotPaused returns (uint256 usdcOut) {
        require(treasuryAmount > 0, "TreasuryMarketplace: zero amount");
        require(treasuryAmount <= maxTransactionSize, "TreasuryMarketplace: exceeds max transaction");

        _resetDailyVolumeIfNeeded();

        // Calculate USDC output amount
        usdcOut = calculateUsdcOutput(treasuryAmount);
        uint256 fee = (usdcOut * feeBps) / 10000;
        uint256 netUsdcOut = usdcOut - fee;

        require(netUsdcOut >= minUsdcOut, "TreasuryMarketplace: insufficient output");
        require(netUsdcOut <= usdcReserve, "TreasuryMarketplace: insufficient liquidity");

        // Check daily volume limit
        currentDayVolume += netUsdcOut;
        require(currentDayVolume <= dailyVolumeLimit, "TreasuryMarketplace: daily limit exceeded");

        // Transfer treasury tokens from seller
        treasuryToken.safeTransferFrom(msg.sender, address(this), treasuryAmount);

        // Update reserves
        treasuryReserve += treasuryAmount;
        usdcReserve -= usdcOut;
        accumulatedFees += fee;

        // Transfer USDC to seller
        usdc.safeTransfer(msg.sender, netUsdcOut);

        emit TreasurySold(msg.sender, treasuryAmount, netUsdcOut, fee);

        return netUsdcOut;
    }

    /**
     * @notice Calculate USDC output for a given treasury input
     * @param treasuryAmount Amount of treasury tokens
     * @return USDC output amount
     */
    function calculateUsdcOutput(uint256 treasuryAmount) public view returns (uint256) {
        if (treasuryReserve == 0 || usdcReserve == 0) {
            // Use base price if no liquidity
            return (treasuryAmount * basePrice) / 10**18;
        }

        // Simple constant product formula (x * y = k)
        uint256 k = treasuryReserve * usdcReserve;
        uint256 newTreasuryReserve = treasuryReserve + treasuryAmount;
        uint256 newUsdcReserve = k / newTreasuryReserve;

        uint256 usdcOut = usdcReserve - newUsdcReserve;

        // Apply spread
        usdcOut = (usdcOut * (10000 - spreadBps)) / 10000;

        return usdcOut;
    }

    /**
     * @notice Add liquidity to the marketplace
     * @param treasuryAmount Amount of treasury tokens to add
     * @param usdcAmount Amount of USDC to add
     */
    function addLiquidity(
        uint256 treasuryAmount,
        uint256 usdcAmount
    ) external onlyOwner {
        require(treasuryAmount > 0 && usdcAmount > 0, "TreasuryMarketplace: zero amounts");

        treasuryToken.safeTransferFrom(msg.sender, address(this), treasuryAmount);
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        treasuryReserve += treasuryAmount;
        usdcReserve += usdcAmount;

        emit LiquidityAdded(treasuryAmount, usdcAmount);
    }

    /**
     * @notice Remove liquidity from the marketplace
     * @param treasuryAmount Amount of treasury tokens to remove
     * @param usdcAmount Amount of USDC to remove
     */
    function removeLiquidity(
        uint256 treasuryAmount,
        uint256 usdcAmount
    ) external onlyOwner {
        require(treasuryAmount <= treasuryReserve, "TreasuryMarketplace: insufficient treasury");
        require(usdcAmount <= usdcReserve, "TreasuryMarketplace: insufficient USDC");

        treasuryReserve -= treasuryAmount;
        usdcReserve -= usdcAmount;

        if (treasuryAmount > 0) {
            treasuryToken.safeTransfer(msg.sender, treasuryAmount);
        }
        if (usdcAmount > 0) {
            usdc.safeTransfer(msg.sender, usdcAmount);
        }

        emit LiquidityRemoved(treasuryAmount, usdcAmount);
    }

    /**
     * @notice Collect accumulated fees
     */
    function collectFees() external {
        require(msg.sender == feeRecipient || msg.sender == owner(), "TreasuryMarketplace: unauthorized");

        uint256 fees = accumulatedFees;
        require(fees > 0, "TreasuryMarketplace: no fees");

        accumulatedFees = 0;
        usdc.safeTransfer(feeRecipient, fees);

        emit FeesCollected(fees);
    }

    /**
     * @notice Update base price (owner only)
     * @param newPrice New base price
     */
    function updateBasePrice(uint256 newPrice) external onlyOwner {
        require(newPrice > 0, "TreasuryMarketplace: invalid price");
        basePrice = newPrice;
        emit PriceUpdated(newPrice);
    }

    /**
     * @notice Update fee parameters
     */
    function updateFeeParams(uint256 _feeBps, address _feeRecipient) external onlyOwner {
        require(_feeBps <= 1000, "TreasuryMarketplace: fee too high"); // Max 10%
        require(_feeRecipient != address(0), "TreasuryMarketplace: invalid recipient");

        feeBps = _feeBps;
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Update trading limits
     */
    function updateTradingLimits(
        uint256 _maxTransactionSize,
        uint256 _dailyVolumeLimit
    ) external onlyOwner {
        maxTransactionSize = _maxTransactionSize;
        dailyVolumeLimit = _dailyVolumeLimit;
    }

    /**
     * @notice Reset daily volume counter if needed
     */
    function _resetDailyVolumeIfNeeded() private {
        if (block.timestamp >= lastResetTimestamp + 1 days) {
            currentDayVolume = 0;
            lastResetTimestamp = block.timestamp;
        }
    }

    /**
     * @notice Get current market price
     */
    function getCurrentPrice() external view returns (uint256) {
        if (treasuryReserve == 0 || usdcReserve == 0) {
            return basePrice;
        }
        return (usdcReserve * 10**18) / treasuryReserve;
    }

    /**
     * @notice Pause trading
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause trading
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency token recovery
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}