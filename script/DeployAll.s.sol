// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrossChainComposer} from "../contracts/CrossChainComposer.sol";
import {UsdcBridgeSender} from "../contracts/UsdcBridgeSender.sol";
import {TokenizedTreasury} from "../contracts/TokenizedTreasury.sol";
import {TreasuryMarketplace} from "../contracts/TreasuryMarketplace.sol";
import {TreasuryBridgeInitiator} from "../contracts/TreasuryBridgeInitiator.sol";
import {Config} from "../contracts/Config.sol";
import {SimpleFlatcoinOFT} from "../contracts/flatcoin/SimpleFlatcoinOFT.sol";
import {FlatcoinCore} from "../contracts/flatcoin/FlatcoinCore.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockEndpoint} from "../test/mocks/MockEndpoint.sol";
import {MockStargate} from "../test/mocks/MockStargate.sol";

contract DeployAll is Script {
    struct DeploymentResult {
        address crossChainComposer;
        address usdcBridgeSender;
        address tokenizedTreasury;
        address treasuryMarketplace;
        address treasuryBridgeInitiator;
        address simpleFlatcoinOFT;
        address flatcoinCore;
        address usdc;
        address usdt;
    }

    function run() external returns (DeploymentResult memory) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        uint256 chainId = block.chainid;
        console2.log("Deploying all contracts on chain ID:", chainId);

        DeploymentResult memory result;

        if (chainId == 31337) {
            // Local deployment with mocks
            result = deployLocal(deployerAddress);
        } else if (chainId == 1 || chainId == 11155111) {
            // Ethereum mainnet or Sepolia
            result = deployEthereum();
        } else if (chainId == 42161 || chainId == 421614) {
            // Arbitrum One or Arbitrum Sepolia
            result = deployArbitrum();
        } else {
            revert("Unsupported chain");
        }

        printDeploymentSummary(result);

        vm.stopBroadcast();
        return result;
    }

    function deployLocal(address deployerAddress) internal returns (DeploymentResult memory) {
        console2.log("\n=== Deploying Local Test Environment ===");

        // Deploy mocks
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console2.log("Mock USDC:", address(usdc));

        MockEndpoint endpoint = new MockEndpoint();
        console2.log("Mock Endpoint:", address(endpoint));

        MockStargate stargate = new MockStargate(address(usdc));
        console2.log("Mock Stargate:", address(stargate));

        // Deploy CrossChainComposer (for receiving bridged funds)
        CrossChainComposer composer = new CrossChainComposer(
            address(endpoint),
            address(stargate),
            address(usdc)
        );
        console2.log("CrossChainComposer:", address(composer));

        // Deploy UsdcBridgeSender
        UsdcBridgeSender sender = new UsdcBridgeSender(
            address(stargate),
            address(usdc),
            31337
        );
        console2.log("UsdcBridgeSender:", address(sender));

        // Deploy Treasury contracts
        TokenizedTreasury treasury = new TokenizedTreasury(
            "US Treasury 2-Year Token",
            "UST2Y",
            block.timestamp + 730 days,
            450, // 4.5% coupon
            "912828ZW8"
        );
        console2.log("TokenizedTreasury:", address(treasury));

        TreasuryMarketplace marketplace = new TreasuryMarketplace(
            address(usdc),
            address(treasury),
            1 * 10**6, // 1 USDC per treasury token
            msg.sender // fee recipient
        );
        console2.log("TreasuryMarketplace:", address(marketplace));

        TreasuryBridgeInitiator initiator = new TreasuryBridgeInitiator(
            address(marketplace),
            address(sender),
            address(usdc),
            address(treasury)
        );
        console2.log("TreasuryBridgeInitiator:", address(initiator));

        // Configure
        endpoint.setComposer(address(composer));
        endpoint.setStargate(address(stargate));
        sender.setComposer(Config.ETHEREUM_EID, address(composer));

        // Deploy mock USDT for flatcoin
        MockERC20 usdt = new MockERC20("Tether USD", "USDT", 6);
        console2.log("Mock USDT:", address(usdt));

        // Deploy Flatcoin contracts
        SimpleFlatcoinOFT flatcoin = new SimpleFlatcoinOFT(
            "Flatcoin",
            "FLAT",
            address(endpoint),
            deployerAddress
        );
        console2.log("SimpleFlatcoinOFT:", address(flatcoin));

        FlatcoinCore flatcoinCore = new FlatcoinCore(
            address(flatcoin),
            address(usdt)
        );
        console2.log("FlatcoinCore:", address(flatcoinCore));

        // Configure flatcoin
        flatcoin.setCoreContract(address(flatcoinCore));

        // Setup initial liquidity for testing
        usdc.mint(deployerAddress, 10000000 * 10**6); // 10M USDC
        usdt.mint(deployerAddress, 10000000 * 10**6); // 10M USDT
        treasury.mint(deployerAddress, 1000000 * 10**18); // 1M treasury tokens

        // Add initial reserves to flatcoin
        usdt.approve(address(flatcoinCore), 100000 * 10**6);
        flatcoinCore.addReserves(100000 * 10**6); // 100k USDT reserves

        return DeploymentResult({
            crossChainComposer: address(composer),
            usdcBridgeSender: address(sender),
            tokenizedTreasury: address(treasury),
            treasuryMarketplace: address(marketplace),
            treasuryBridgeInitiator: address(initiator),
            simpleFlatcoinOFT: address(flatcoin),
            flatcoinCore: address(flatcoinCore),
            usdc: address(usdc),
            usdt: address(usdt)
        });
    }

    function deployEthereum() internal returns (DeploymentResult memory) {
        console2.log("\n=== Deploying on Ethereum ===");

        uint256 chainId = block.chainid;
        address endpoint = chainId == 1 ? Config.ETHEREUM_ENDPOINT : Config.SEPOLIA_ENDPOINT;
        address stargate = chainId == 1 ? Config.ETHEREUM_STARGATE : Config.ETHEREUM_SEPOLIA_STARGATE;
        address usdc = chainId == 1 ? Config.ETHEREUM_USDC : Config.ETHEREUM_SEPOLIA_USDC;

        require(endpoint != address(0), "Invalid endpoint address");
        require(stargate != address(0), "Invalid stargate address");

        // Deploy CrossChainComposer
        CrossChainComposer composer = new CrossChainComposer(
            endpoint,
            stargate,
            usdc
        );
        console2.log("CrossChainComposer:", address(composer));

        // Deploy UsdcBridgeSender
        UsdcBridgeSender sender = new UsdcBridgeSender(
            stargate,
            usdc,
            chainId == 1 ? 1 : 11155111
        );
        console2.log("UsdcBridgeSender:", address(sender));

        // Deploy USDT for flatcoin (testnet only)
        address usdt = usdc; // On mainnet, would use actual USDT address
        if (chainId == 11155111) {
            // Deploy mock USDT on testnet
            MockERC20 mockUsdt = new MockERC20("Tether USD", "USDT", 6);
            usdt = address(mockUsdt);
            console2.log("Mock USDT:", usdt);
        }

        // Deploy Flatcoin contracts
        address deployer = msg.sender;
        SimpleFlatcoinOFT flatcoin = new SimpleFlatcoinOFT(
            "Flatcoin",
            "FLAT",
            endpoint,
            deployer
        );
        console2.log("SimpleFlatcoinOFT:", address(flatcoin));

        FlatcoinCore flatcoinCore = new FlatcoinCore(
            address(flatcoin),
            usdt
        );
        console2.log("FlatcoinCore:", address(flatcoinCore));

        // Configure flatcoin
        flatcoin.setCoreContract(address(flatcoinCore));

        // Note: Treasury contracts are only deployed on Arbitrum
        console2.log("\nNote: Treasury contracts should be deployed on Arbitrum");

        return DeploymentResult({
            crossChainComposer: address(composer),
            usdcBridgeSender: address(sender),
            tokenizedTreasury: address(0),
            treasuryMarketplace: address(0),
            treasuryBridgeInitiator: address(0),
            simpleFlatcoinOFT: address(flatcoin),
            flatcoinCore: address(flatcoinCore),
            usdc: usdc,
            usdt: usdt
        });
    }

    function deployArbitrum() internal returns (DeploymentResult memory) {
        console2.log("\n=== Deploying on Arbitrum ===");

        uint256 chainId = block.chainid;
        address endpoint = chainId == 42161 ? Config.ARBITRUM_ENDPOINT : Config.SEPOLIA_ENDPOINT;
        address stargate = chainId == 42161 ? Config.ARBITRUM_STARGATE : Config.ARBITRUM_SEPOLIA_STARGATE;
        address usdc = chainId == 42161 ? Config.ARBITRUM_USDC : Config.ARBITRUM_SEPOLIA_USDC;

        require(endpoint != address(0), "Invalid endpoint address");
        require(stargate != address(0), "Invalid stargate address");

        // Deploy CrossChainComposer
        CrossChainComposer composer = new CrossChainComposer(
            endpoint,
            stargate,
            usdc
        );
        console2.log("CrossChainComposer:", address(composer));

        // Deploy UsdcBridgeSender
        UsdcBridgeSender sender = new UsdcBridgeSender(
            stargate,
            usdc,
            chainId == 42161 ? 42161 : 421614
        );
        console2.log("UsdcBridgeSender:", address(sender));

        // Deploy Treasury contracts
        TokenizedTreasury treasury = new TokenizedTreasury(
            "US Treasury 2-Year Token",
            "UST2Y",
            block.timestamp + 730 days,
            450, // 4.5% coupon
            "912828ZW8"
        );
        console2.log("TokenizedTreasury:", address(treasury));

        TreasuryMarketplace marketplace = new TreasuryMarketplace(
            address(usdc),
            address(treasury),
            1 * 10**6, // 1 USDC per treasury token
            msg.sender // fee recipient
        );
        console2.log("TreasuryMarketplace:", address(marketplace));

        TreasuryBridgeInitiator initiator = new TreasuryBridgeInitiator(
            address(marketplace),
            address(sender),
            address(usdc),
            address(treasury)
        );
        console2.log("TreasuryBridgeInitiator:", address(initiator));

        // Set transaction limits
        marketplace.updateTradingLimits(
            1000000 * 10**18, // 1M treasury tokens max
            10000000 * 10**6  // 10M USDC daily limit
        );

        // Deploy USDT for flatcoin (testnet only)
        address usdt = usdc; // On mainnet, would use actual USDT address
        if (chainId == 421614) {
            // Deploy mock USDT on testnet
            MockERC20 mockUsdt = new MockERC20("Tether USD", "USDT", 6);
            usdt = address(mockUsdt);
            console2.log("Mock USDT:", usdt);
        }

        // Deploy Flatcoin contracts
        address deployer = msg.sender;
        SimpleFlatcoinOFT flatcoin = new SimpleFlatcoinOFT(
            "Flatcoin",
            "FLAT",
            endpoint,
            deployer
        );
        console2.log("SimpleFlatcoinOFT:", address(flatcoin));

        FlatcoinCore flatcoinCore = new FlatcoinCore(
            address(flatcoin),
            usdt
        );
        console2.log("FlatcoinCore:", address(flatcoinCore));

        // Configure flatcoin
        flatcoin.setCoreContract(address(flatcoinCore));

        return DeploymentResult({
            crossChainComposer: address(composer),
            usdcBridgeSender: address(sender),
            tokenizedTreasury: address(treasury),
            treasuryMarketplace: address(marketplace),
            treasuryBridgeInitiator: address(initiator),
            simpleFlatcoinOFT: address(flatcoin),
            flatcoinCore: address(flatcoinCore),
            usdc: usdc,
            usdt: usdt
        });
    }

    function printDeploymentSummary(DeploymentResult memory result) internal view {
        console2.log("\n=== Deployment Summary ===");
        console2.log("CrossChainComposer:", result.crossChainComposer);
        console2.log("UsdcBridgeSender:", result.usdcBridgeSender);
        console2.log("USDC:", result.usdc);

        if (result.tokenizedTreasury != address(0)) {
            console2.log("TokenizedTreasury:", result.tokenizedTreasury);
            console2.log("TreasuryMarketplace:", result.treasuryMarketplace);
            console2.log("TreasuryBridgeInitiator:", result.treasuryBridgeInitiator);
        }

        if (result.simpleFlatcoinOFT != address(0)) {
            console2.log("SimpleFlatcoinOFT:", result.simpleFlatcoinOFT);
            console2.log("FlatcoinCore:", result.flatcoinCore);
            console2.log("USDT:", result.usdt);
        }

        console2.log("\n=== Next Steps ===");
        console2.log("1. Set composer addresses on both chains");
        console2.log("2. Add liquidity to marketplace (if on Arbitrum)");
        console2.log("3. Configure authorized minters for treasury tokens");
        console2.log("4. Add reserves to flatcoin core contract");
        console2.log("5. Configure flatcoin peers for cross-chain transfers");
        console2.log("6. Verify contracts on block explorer");
    }
}

contract SetupCrossChain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get addresses from environment
        address arbitrumSender = vm.envAddress("ARBITRUM_SENDER");
        address ethereumSender = vm.envAddress("ETHEREUM_SENDER");
        address arbitrumComposer = vm.envAddress("ARBITRUM_COMPOSER");
        address ethereumComposer = vm.envAddress("ETHEREUM_COMPOSER");

        vm.startBroadcast(deployerPrivateKey);

        console2.log("Setting up cross-chain configuration...");

        // Setup Arbitrum sender to point to Ethereum composer
        UsdcBridgeSender(payable(arbitrumSender)).setComposer(
            Config.ETHEREUM_EID,
            ethereumComposer
        );
        console2.log("Arbitrum sender configured to use Ethereum composer");

        // Setup Ethereum sender to point to Arbitrum composer
        UsdcBridgeSender(payable(ethereumSender)).setComposer(
            Config.ARBITRUM_EID,
            arbitrumComposer
        );
        console2.log("Ethereum sender configured to use Arbitrum composer");

        vm.stopBroadcast();

        console2.log("\nCross-chain setup complete!");
    }
}