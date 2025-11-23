// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TreasuryMarketplace} from "./TreasuryMarketplace.sol";
import {UsdcBridgeSender} from "./UsdcBridgeSender.sol";
import {Config} from "./Config.sol";

/**
 * @title TreasuryBridgeOrchestrator
 * @notice Orchestrates the sale of treasury tokens and bridging USDC to Ethereum in one transaction
 * @dev Combines TreasuryMarketplace and UsdcBridgeSender functionality
 */
contract TreasuryBridgeOrchestrator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Core contracts
    TreasuryMarketplace public immutable marketplace;
    UsdcBridgeSender public immutable bridgeSender;
    IERC20 public immutable usdc;
    IERC20 public immutable treasuryToken;

    // Statistics
    uint256 public totalTreasurySold;
    uint256 public totalUsdcBridged;
    uint256 public totalTransactions;

    // User statistics
    mapping(address => uint256) public userTreasurySold;
    mapping(address => uint256) public userUsdcBridged;
    mapping(address => uint256) public userTransactionCount;

    // Events
    event TreasurySoldAndBridged(
        address indexed user,
        uint256 treasuryAmount,
        uint256 usdcReceived,
        uint256 usdcBridged,
        address ethereumRecipient,
        bytes32 bridgeGuid
    );

    event DirectBridge(
        address indexed user,
        uint256 usdcAmount,
        address ethereumRecipient,
        bytes32 bridgeGuid
    );

    /**
     * @param _marketplace TreasuryMarketplace contract address
     * @param _bridgeSender UsdcBridgeSender contract address
     * @param _usdc USDC token address
     * @param _treasuryToken Treasury token address
     */
    constructor(
        address _marketplace,
        address _bridgeSender,
        address _usdc,
        address _treasuryToken
    ) Ownable(msg.sender) {
        require(_marketplace != address(0), "Orchestrator: invalid marketplace");
        require(_bridgeSender != address(0), "Orchestrator: invalid bridge sender");
        require(_usdc != address(0), "Orchestrator: invalid USDC");
        require(_treasuryToken != address(0), "Orchestrator: invalid treasury token");

        marketplace = TreasuryMarketplace(_marketplace);
        bridgeSender = UsdcBridgeSender(payable(_bridgeSender));
        usdc = IERC20(_usdc);
        treasuryToken = IERC20(_treasuryToken);
    }

    /**
     * @notice Sell treasury tokens for USDC and bridge to Ethereum in one transaction
     * @param treasuryAmount Amount of treasury tokens to sell
     * @param minUsdcOut Minimum USDC to receive from sale
     * @param ethereumRecipient Recipient address on Ethereum
     * @param bridgeAllProceeds If true, bridge all USDC received; if false, bridge only specified amount
     * @param bridgeAmount Amount to bridge (only used if bridgeAllProceeds is false)
     * @return usdcReceived Amount of USDC received from sale
     * @return usdcBridged Amount of USDC bridged to Ethereum
     * @return bridgeGuid LayerZero message GUID
     */
    function sellAndBridge(
        uint256 treasuryAmount,
        uint256 minUsdcOut,
        address ethereumRecipient,
        bool bridgeAllProceeds,
        uint256 bridgeAmount
    ) external payable nonReentrant returns (
        uint256 usdcReceived,
        uint256 usdcBridged,
        bytes32 bridgeGuid
    ) {
        require(treasuryAmount > 0, "Orchestrator: zero treasury amount");
        require(ethereumRecipient != address(0), "Orchestrator: invalid recipient");

        // Step 1: Transfer treasury tokens from user to this contract
        treasuryToken.safeTransferFrom(msg.sender, address(this), treasuryAmount);

        // Step 2: Approve marketplace to spend treasury tokens
        treasuryToken.approve(address(marketplace), treasuryAmount);

        // Step 3: Sell treasury tokens for USDC
        usdcReceived = marketplace.sellTreasury(treasuryAmount, minUsdcOut);

        // Step 4: Determine amount to bridge
        if (bridgeAllProceeds) {
            usdcBridged = usdcReceived;
        } else {
            require(bridgeAmount <= usdcReceived, "Orchestrator: bridge amount exceeds received");
            usdcBridged = bridgeAmount;
        }

        // Step 5: Approve bridge sender to spend USDC
        usdc.approve(address(bridgeSender), usdcBridged);

        // Step 6: Quote bridge fee
        (uint256 nativeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            usdcBridged,
            ethereumRecipient
        );

        require(msg.value >= nativeFee, "Orchestrator: insufficient fee");

        // Step 7: Bridge USDC to Ethereum
        bridgeGuid = bridgeSender.bridgeToEthereum{value: nativeFee}(
            usdcBridged,
            ethereumRecipient
        );

        // Step 8: Return any remaining USDC to user
        uint256 remainingUsdc = usdcReceived - usdcBridged;
        if (remainingUsdc > 0) {
            usdc.safeTransfer(msg.sender, remainingUsdc);
        }

        // Step 9: Refund excess ETH
        if (msg.value > nativeFee) {
            payable(msg.sender).transfer(msg.value - nativeFee);
        }

        // Update statistics
        totalTreasurySold += treasuryAmount;
        totalUsdcBridged += usdcBridged;
        totalTransactions++;

        userTreasurySold[msg.sender] += treasuryAmount;
        userUsdcBridged[msg.sender] += usdcBridged;
        userTransactionCount[msg.sender]++;

        emit TreasurySoldAndBridged(
            msg.sender,
            treasuryAmount,
            usdcReceived,
            usdcBridged,
            ethereumRecipient,
            bridgeGuid
        );

        return (usdcReceived, usdcBridged, bridgeGuid);
    }

    /**
     * @notice Bridge existing USDC to Ethereum (without selling treasury)
     * @param usdcAmount Amount of USDC to bridge
     * @param ethereumRecipient Recipient address on Ethereum
     * @return bridgeGuid LayerZero message GUID
     */
    function bridgeUsdc(
        uint256 usdcAmount,
        address ethereumRecipient
    ) external payable nonReentrant returns (bytes32 bridgeGuid) {
        require(usdcAmount > 0, "Orchestrator: zero amount");
        require(ethereumRecipient != address(0), "Orchestrator: invalid recipient");

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Approve bridge sender
        usdc.approve(address(bridgeSender), usdcAmount);

        // Quote and execute bridge
        (uint256 nativeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            usdcAmount,
            ethereumRecipient
        );

        require(msg.value >= nativeFee, "Orchestrator: insufficient fee");

        bridgeGuid = bridgeSender.bridgeToEthereum{value: nativeFee}(
            usdcAmount,
            ethereumRecipient
        );

        // Refund excess ETH
        if (msg.value > nativeFee) {
            payable(msg.sender).transfer(msg.value - nativeFee);
        }

        // Update statistics
        totalUsdcBridged += usdcAmount;
        userUsdcBridged[msg.sender] += usdcAmount;

        emit DirectBridge(msg.sender, usdcAmount, ethereumRecipient, bridgeGuid);

        return bridgeGuid;
    }

    /**
     * @notice Quote the total cost for sell and bridge operation
     * @param treasuryAmount Amount of treasury tokens to sell
     * @param bridgeAllProceeds Whether to bridge all proceeds
     * @param bridgeAmount Amount to bridge if not all proceeds
     * @return expectedUsdc Expected USDC from sale
     * @return bridgeFee Required ETH for bridge fee
     */
    function quoteSellAndBridge(
        uint256 treasuryAmount,
        bool bridgeAllProceeds,
        uint256 bridgeAmount
    ) external view returns (uint256 expectedUsdc, uint256 bridgeFee) {
        expectedUsdc = marketplace.calculateUsdcOutput(treasuryAmount);

        uint256 amountToBridge = bridgeAllProceeds ? expectedUsdc : bridgeAmount;

        (bridgeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            amountToBridge,
            msg.sender
        );

        return (expectedUsdc, bridgeFee);
    }

    /**
     * @notice Get user statistics
     * @param user User address
     * @return treasurySold Total treasury tokens sold
     * @return usdcBridged Total USDC bridged
     * @return transactionCount Total transactions
     */
    function getUserStats(address user) external view returns (
        uint256 treasurySold,
        uint256 usdcBridged,
        uint256 transactionCount
    ) {
        return (
            userTreasurySold[user],
            userUsdcBridged[user],
            userTransactionCount[user]
        );
    }

    /**
     * @notice Emergency function to recover stuck tokens
     * @param token Token address
     * @param amount Amount to recover
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Emergency function to recover stuck ETH
     */
    function emergencyWithdrawETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}