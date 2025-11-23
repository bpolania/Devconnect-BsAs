// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UsdcComposer} from "../contracts/UsdcComposer.sol";
import {UsdcBridgeSender} from "../contracts/UsdcBridgeSender.sol";
import {Config} from "../contracts/Config.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockEndpoint} from "../test/mocks/MockEndpoint.sol";
import {MockStargate} from "../test/mocks/MockStargate.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get chain ID
        uint256 chainId = block.chainid;
        console2.log("Deploying on chain ID:", chainId);

        // Deploy based on network
        if (chainId == 31337) {
            // Local deployment with mocks
            deployLocal();
        } else if (chainId == 1) {
            // Ethereum mainnet
            deployEthereum();
        } else if (chainId == 42161) {
            // Arbitrum One
            deployArbitrum();
        } else {
            revert("Unsupported chain");
        }

        vm.stopBroadcast();
    }

    function deployLocal() internal {
        console2.log("Deploying local test environment...");

        // Deploy mock USDC
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console2.log("Mock USDC deployed at:", address(usdc));

        // Deploy mock endpoint
        MockEndpoint endpoint = new MockEndpoint();
        console2.log("Mock Endpoint deployed at:", address(endpoint));

        // Deploy mock Stargate
        MockStargate stargate = new MockStargate(address(usdc));
        console2.log("Mock Stargate deployed at:", address(stargate));

        // Deploy Composer
        UsdcComposer composer = new UsdcComposer(
            address(endpoint),
            address(stargate),
            address(usdc)
        );
        console2.log("UsdcComposer deployed at:", address(composer));

        // Deploy Sender
        UsdcBridgeSender sender = new UsdcBridgeSender(
            address(stargate),
            address(usdc),
            31337 // local chain ID
        );
        console2.log("UsdcBridgeSender deployed at:", address(sender));

        // Configure
        endpoint.setComposer(address(composer));
        endpoint.setStargate(address(stargate));

        // Set composers for both directions (mock)
        sender.setComposer(Config.ETHEREUM_EID, address(composer));
        sender.setComposer(Config.ARBITRUM_EID, address(composer));

        console2.log("\nLocal deployment complete!");
        console2.log("Next steps:");
        console2.log("1. Mint USDC:");
        console2.log("   cast send", address(usdc));
        console2.log("   \"mint(address,uint256)\" <your_address> 1000000000000");
        console2.log("2. Approve sender:");
        console2.log("   cast send", address(usdc));
        console2.log("   \"approve(address,uint256)\"", address(sender));
        console2.log("   1000000000000");
    }

    function deployEthereum() internal {
        console2.log("Deploying on Ethereum mainnet...");

        address endpoint = Config.ETHEREUM_ENDPOINT;
        address stargate = Config.ETHEREUM_STARGATE;
        address usdc = Config.ETHEREUM_USDC;

        require(stargate != address(0), "Deploy: Update Stargate address in Config.sol");

        // Deploy Composer
        UsdcComposer composer = new UsdcComposer(endpoint, stargate, usdc);
        console2.log("UsdcComposer deployed at:", address(composer));

        // Deploy Sender
        UsdcBridgeSender sender = new UsdcBridgeSender(stargate, usdc, 1);
        console2.log("UsdcBridgeSender deployed at:", address(sender));

        console2.log("\nEthereum deployment complete!");
        console2.log("Next steps:");
        console2.log("1. Set Arbitrum composer address on sender");
        console2.log("2. Verify contracts on Etherscan");
    }

    function deployArbitrum() internal {
        console2.log("Deploying on Arbitrum One...");

        address endpoint = Config.ARBITRUM_ENDPOINT;
        address stargate = Config.ARBITRUM_STARGATE;
        address usdc = Config.ARBITRUM_USDC;

        require(stargate != address(0), "Deploy: Update Stargate address in Config.sol");

        // Deploy Composer
        UsdcComposer composer = new UsdcComposer(endpoint, stargate, usdc);
        console2.log("UsdcComposer deployed at:", address(composer));

        // Deploy Sender
        UsdcBridgeSender sender = new UsdcBridgeSender(stargate, usdc, 42161);
        console2.log("UsdcBridgeSender deployed at:", address(sender));

        console2.log("\nArbitrum deployment complete!");
        console2.log("Next steps:");
        console2.log("1. Set Ethereum composer address on sender");
        console2.log("2. Verify contracts on Arbiscan");
    }
}