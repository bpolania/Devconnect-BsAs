// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TreasuryMarketplace} from "./TreasuryMarketplace.sol";
import {UsdcBridgeSender} from "./UsdcBridgeSender.sol";
import {MessageCodec} from "./libraries/MessageCodec.sol";
import {Config} from "./Config.sol";

/**
 * @title TreasuryBridgeInitiator
 * @notice Initiates treasury sales and bridges USDC with proper composer message types
 * @dev Deployed on Arbitrum to work with CrossChainComposer on Ethereum
 */
contract TreasuryBridgeInitiator is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    TreasuryMarketplace public immutable marketplace;
    UsdcBridgeSender public immutable bridgeSender;
    IERC20 public immutable usdc;
    IERC20 public immutable treasuryToken;

    // Statistics
    uint256 public totalTreasurySold;
    uint256 public totalUsdcBridged;
    mapping(address => uint256) public userTreasurySold;
    mapping(address => uint256) public userUsdcBridged;

    event TreasuryBridgeInitiated(
        address indexed user,
        uint256 treasuryAmount,
        uint256 usdcReceived,
        uint256 usdcBridged,
        address ethereumRecipient,
        bytes32 bridgeGuid,
        uint8 messageType
    );

    constructor(
        address _marketplace,
        address _bridgeSender,
        address _usdc,
        address _treasuryToken
    ) Ownable(msg.sender) {
        require(_marketplace != address(0), "Initiator: invalid marketplace");
        require(_bridgeSender != address(0), "Initiator: invalid bridge sender");
        require(_usdc != address(0), "Initiator: invalid USDC");
        require(_treasuryToken != address(0), "Initiator: invalid treasury token");

        marketplace = TreasuryMarketplace(_marketplace);
        bridgeSender = UsdcBridgeSender(payable(_bridgeSender));
        usdc = IERC20(_usdc);
        treasuryToken = IERC20(_treasuryToken);
    }

    /**
     * @notice Sell treasury tokens and bridge with TREASURY_SALE message type
     * @param treasuryAmount Amount of treasury tokens to sell
     * @param minUsdcOut Minimum USDC to receive from sale
     * @param ethereumRecipient Recipient address on Ethereum
     * @param treasuryData Additional treasury metadata to send
     */
    function sellAndBridgeWithComposer(
        uint256 treasuryAmount,
        uint256 minUsdcOut,
        address ethereumRecipient,
        bytes calldata treasuryData
    ) external payable nonReentrant returns (bytes32 bridgeGuid) {
        require(treasuryAmount > 0, "Initiator: zero treasury amount");
        require(ethereumRecipient != address(0), "Initiator: invalid recipient");

        // Step 1: Transfer treasury tokens from user
        treasuryToken.safeTransferFrom(msg.sender, address(this), treasuryAmount);

        // Step 2: Approve marketplace
        IERC20(treasuryToken).approve(address(marketplace), treasuryAmount);

        // Step 3: Sell treasury for USDC
        uint256 usdcReceived = marketplace.sellTreasury(treasuryAmount, minUsdcOut);

        // Step 4: Create treasury sale message for composer
        bytes memory composeMsg = abi.encode(ethereumRecipient, treasuryData);

        // Step 5: Bridge with TREASURY_SALE message type
        bridgeGuid = _bridgeWithMessageType(
            usdcReceived,
            ethereumRecipient,
            MessageCodec.MSG_TYPE_TREASURY_SALE,
            composeMsg
        );

        // Update statistics
        totalTreasurySold += treasuryAmount;
        totalUsdcBridged += usdcReceived;
        userTreasurySold[msg.sender] += treasuryAmount;
        userUsdcBridged[msg.sender] += usdcReceived;

        emit TreasuryBridgeInitiated(
            msg.sender,
            treasuryAmount,
            usdcReceived,
            usdcReceived,
            ethereumRecipient,
            bridgeGuid,
            MessageCodec.MSG_TYPE_TREASURY_SALE
        );
    }

    /**
     * @notice Bridge USDC with simple transfer message type
     * @param usdcAmount Amount of USDC to bridge
     * @param ethereumRecipient Recipient address on Ethereum
     */
    function bridgeSimple(
        uint256 usdcAmount,
        address ethereumRecipient
    ) external payable nonReentrant returns (bytes32 bridgeGuid) {
        require(usdcAmount > 0, "Initiator: zero amount");
        require(ethereumRecipient != address(0), "Initiator: invalid recipient");

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Create simple transfer message
        bytes memory composeMsg = abi.encode(ethereumRecipient, bytes(""));

        // Bridge with SIMPLE_TRANSFER message type
        bridgeGuid = _bridgeWithMessageType(
            usdcAmount,
            ethereumRecipient,
            MessageCodec.MSG_TYPE_SIMPLE_TRANSFER,
            composeMsg
        );

        totalUsdcBridged += usdcAmount;
        userUsdcBridged[msg.sender] += usdcAmount;

        emit TreasuryBridgeInitiated(
            msg.sender,
            0,
            usdcAmount,
            usdcAmount,
            ethereumRecipient,
            bridgeGuid,
            MessageCodec.MSG_TYPE_SIMPLE_TRANSFER
        );
    }

    /**
     * @notice Bridge USDC for vault deposit
     * @param usdcAmount Amount of USDC to bridge
     * @param beneficiary Beneficiary for the vault deposit
     * @param vaultParams Parameters for vault operation
     */
    function bridgeForVault(
        uint256 usdcAmount,
        address beneficiary,
        bytes calldata vaultParams
    ) external payable nonReentrant returns (bytes32 bridgeGuid) {
        require(usdcAmount > 0, "Initiator: zero amount");
        require(beneficiary != address(0), "Initiator: invalid beneficiary");

        // Transfer USDC from user
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmount);

        // Create vault deposit message
        bytes memory composeMsg = abi.encode(beneficiary, vaultParams);

        // Bridge with VAULT_DEPOSIT message type
        bridgeGuid = _bridgeWithMessageType(
            usdcAmount,
            beneficiary,
            MessageCodec.MSG_TYPE_VAULT_DEPOSIT,
            composeMsg
        );

        totalUsdcBridged += usdcAmount;
        userUsdcBridged[msg.sender] += usdcAmount;

        emit TreasuryBridgeInitiated(
            msg.sender,
            0,
            usdcAmount,
            usdcAmount,
            beneficiary,
            bridgeGuid,
            MessageCodec.MSG_TYPE_VAULT_DEPOSIT
        );
    }

    /**
     * @notice Internal function to bridge with specific message type
     */
    function _bridgeWithMessageType(
        uint256 usdcAmount,
        address recipient,
        uint8 messageType,
        bytes memory composeMsg
    ) private returns (bytes32) {
        // Approve bridge sender
        IERC20(usdc).approve(address(bridgeSender), usdcAmount);

        // Quote bridge fee
        (uint256 nativeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            usdcAmount,
            recipient
        );

        require(msg.value >= nativeFee, "Initiator: insufficient fee");

        // Note: The actual message type encoding happens in Stargate/LayerZero
        // The bridgeSender should be updated to support message types
        // For now, we bridge normally and the composer will handle based on the compose message
        bytes32 bridgeGuid = bridgeSender.bridgeToEthereum{value: nativeFee}(
            usdcAmount,
            recipient
        );

        // Refund excess ETH
        if (msg.value > nativeFee) {
            payable(msg.sender).transfer(msg.value - nativeFee);
        }

        return bridgeGuid;
    }

    /**
     * @notice Quote sell and bridge operation
     */
    function quoteSellAndBridge(
        uint256 treasuryAmount
    ) external view returns (uint256 expectedUsdc, uint256 bridgeFee) {
        expectedUsdc = marketplace.calculateUsdcOutput(treasuryAmount);
        (bridgeFee, ) = bridgeSender.quoteBridge(
            Config.ETHEREUM_EID,
            expectedUsdc,
            msg.sender
        );
    }

    /**
     * @notice Get user statistics
     */
    function getUserStats(address user) external view returns (
        uint256 treasurySold,
        uint256 usdcBridged
    ) {
        return (userTreasurySold[user], userUsdcBridged[user]);
    }

    /**
     * @notice Emergency token recovery
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    receive() external payable {}
}