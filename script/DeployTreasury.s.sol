// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {TokenizedTreasury} from "../contracts/TokenizedTreasury.sol";
import {TreasuryMarketplace} from "../contracts/TreasuryMarketplace.sol";
import {TreasuryBridgeInitiator} from "../contracts/TreasuryBridgeInitiator.sol";
import {UsdcBridgeSender} from "../contracts/UsdcBridgeSender.sol";
import {Config} from "../contracts/Config.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployTreasury is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get chain ID
        uint256 chainId = block.chainid;
        console2.log("Deploying Treasury contracts on chain ID:", chainId);

        // Only deploy on Arbitrum (mainnet or testnet)
        require(
            chainId == 42161 || // Arbitrum One
            chainId == 421614 || // Arbitrum Sepolia
            chainId == 31337, // Local
            "DeployTreasury: Only deploy on Arbitrum"
        );

        address usdcAddress;
        address stargateAddress;
        address bridgeSenderAddress;

        // Get addresses based on network
        if (chainId == 42161) {
            // Arbitrum One mainnet
            usdcAddress = Config.ARBITRUM_USDC;
            stargateAddress = Config.ARBITRUM_STARGATE;
            console2.log("Using Arbitrum mainnet addresses");
        } else if (chainId == 421614) {
            // Arbitrum Sepolia testnet
            usdcAddress = Config.ARBITRUM_SEPOLIA_USDC;
            stargateAddress = Config.ARBITRUM_SEPOLIA_STARGATE;
            console2.log("Using Arbitrum Sepolia testnet addresses");
        } else {
            // Local deployment - deploy mocks
            console2.log("Deploying mock USDC for local testing");
            MockERC20 mockUsdc = new MockERC20("USD Coin", "USDC", 6);
            usdcAddress = address(mockUsdc);
            stargateAddress = address(0); // Will be set later
        }

        // Check if we need to deploy or use existing bridge sender
        bridgeSenderAddress = vm.envOr("BRIDGE_SENDER_ADDRESS", address(0));

        if (bridgeSenderAddress == address(0)) {
            console2.log("Bridge sender not provided, checking for existing deployment...");
            // In production, you would check if it's already deployed
            // For now, we'll error out
            require(chainId == 31337, "DeployTreasury: Bridge sender required for non-local deployment");
        }

        // Deploy TokenizedTreasury
        console2.log("Deploying TokenizedTreasury...");

        uint256 maturityDate = block.timestamp + 730 days; // 2 years
        uint256 couponRate = 450; // 4.5% annual
        string memory cusip = "912828ZW8"; // Example CUSIP for US Treasury

        TokenizedTreasury treasury = new TokenizedTreasury(
            "US Treasury 2-Year Token",
            "UST2Y",
            maturityDate,
            couponRate,
            cusip
        );
        console2.log("TokenizedTreasury deployed at:", address(treasury));

        // Deploy TreasuryMarketplace
        console2.log("Deploying TreasuryMarketplace...");

        uint256 basePrice = 1 * 10**6; // 1 USDC per treasury token initial price
        address feeRecipient = msg.sender; // Set deployer as fee recipient

        TreasuryMarketplace marketplace = new TreasuryMarketplace(
            usdcAddress,
            address(treasury),
            basePrice,
            feeRecipient
        );
        console2.log("TreasuryMarketplace deployed at:", address(marketplace));

        // Deploy TreasuryBridgeInitiator if bridge sender exists
        if (bridgeSenderAddress != address(0)) {
            console2.log("Deploying TreasuryBridgeInitiator...");

            TreasuryBridgeInitiator initiator = new TreasuryBridgeInitiator(
                address(marketplace),
                bridgeSenderAddress,
                usdcAddress,
                address(treasury)
            );
            console2.log("TreasuryBridgeInitiator deployed at:", address(initiator));

            // Initial configuration
            console2.log("\n=== Configuration Complete ===");
            console2.log("Treasury Token:", address(treasury));
            console2.log("Marketplace:", address(marketplace));
            console2.log("Initiator:", address(initiator));
            console2.log("USDC:", usdcAddress);
            console2.log("Bridge Sender:", bridgeSenderAddress);
        } else {
            console2.log("\n=== Configuration Complete (No Bridge) ===");
            console2.log("Treasury Token:", address(treasury));
            console2.log("Marketplace:", address(marketplace));
            console2.log("USDC:", usdcAddress);
        }

        console2.log("\n=== Next Steps ===");
        console2.log("1. Mint initial treasury token supply");
        console2.log("2. Add liquidity to marketplace");
        console2.log("3. Configure authorized minters on treasury token");
        console2.log("4. Set trading limits on marketplace");

        vm.stopBroadcast();
    }
}

contract SetupTreasuryLiquidity is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address treasuryAddress = vm.envAddress("TREASURY_ADDRESS");
        address marketplaceAddress = vm.envAddress("MARKETPLACE_ADDRESS");
        address usdcAddress = vm.envAddress("USDC_ADDRESS");

        uint256 treasuryAmount = vm.envUint("TREASURY_LIQUIDITY_AMOUNT");
        uint256 usdcAmount = vm.envUint("USDC_LIQUIDITY_AMOUNT");

        vm.startBroadcast(deployerPrivateKey);

        TokenizedTreasury treasury = TokenizedTreasury(treasuryAddress);
        TreasuryMarketplace marketplace = TreasuryMarketplace(marketplaceAddress);

        console2.log("Setting up liquidity...");
        console2.log("Treasury amount:", treasuryAmount);
        console2.log("USDC amount:", usdcAmount);

        // Mint treasury tokens if needed
        if (treasury.balanceOf(msg.sender) < treasuryAmount) {
            console2.log("Minting treasury tokens...");
            treasury.mint(msg.sender, treasuryAmount);
        }

        // Approve marketplace
        console2.log("Approving marketplace...");
        treasury.approve(marketplaceAddress, treasuryAmount);
        IERC20(usdcAddress).approve(marketplaceAddress, usdcAmount);

        // Add liquidity
        console2.log("Adding liquidity to marketplace...");
        marketplace.addLiquidity(treasuryAmount, usdcAmount);

        console2.log("Liquidity setup complete!");

        vm.stopBroadcast();
    }
}