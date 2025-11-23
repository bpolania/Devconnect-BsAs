// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {UsdcBridgeSender} from "../contracts/UsdcBridgeSender.sol";
import {Config} from "../contracts/Config.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BridgeExample is Script {
    function run() external {
        // Configuration
        address payable sender = payable(vm.envAddress("SENDER_CONTRACT"));
        address receiver = vm.envAddress("RECEIVER_ADDRESS");
        uint256 amount = vm.envUint("BRIDGE_AMOUNT"); // in USDC units (6 decimals)
        string memory destination = vm.envString("DESTINATION"); // "ethereum" or "arbitrum"

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get chain ID and USDC address
        uint256 chainId = block.chainid;
        address usdc = getUsdc(chainId);

        console2.log("=== Bridge Configuration ===");
        console2.log("Sender contract:", sender);
        console2.log("Receiver address:", receiver);
        console2.log("Amount:", amount / 1e6, "USDC");
        console2.log("Destination:", destination);
        console2.log("Chain ID:", chainId);

        // Get destination EID
        uint32 dstEid = getDestinationEid(destination);

        // Step 1: Check USDC balance
        uint256 balance = IERC20(usdc).balanceOf(msg.sender);
        console2.log("\n=== Balance Check ===");
        console2.log("Your USDC balance:", balance / 1e6, "USDC");
        require(balance >= amount, "Insufficient USDC balance");

        // Step 2: Check allowance
        uint256 allowance = IERC20(usdc).allowance(msg.sender, sender);
        console2.log("Current allowance:", allowance / 1e6, "USDC");

        // Step 3: Approve if needed
        if (allowance < amount) {
            console2.log("Approving sender to spend USDC...");
            IERC20(usdc).approve(sender, amount);
            console2.log("Approved!");
        }

        // Step 4: Quote bridge fee
        console2.log("\n=== Fee Quote ===");
        UsdcBridgeSender bridgeSender = UsdcBridgeSender(sender);
        (uint256 nativeFee, uint256 lzTokenFee) = bridgeSender.quoteBridge(
            dstEid,
            amount,
            receiver
        );
        console2.log("Native fee required:", nativeFee);
        console2.log("LZ token fee:", lzTokenFee);

        // Step 5: Check ETH balance for fees
        uint256 ethBalance = address(msg.sender).balance;
        console2.log("\n=== ETH Balance Check ===");
        console2.log("Your ETH balance:", ethBalance);
        require(ethBalance >= nativeFee, "Insufficient ETH for fees");

        // Step 6: Execute bridge
        console2.log("\n=== Executing Bridge ===");
        console2.log("Sending", amount / 1e6, "USDC to", receiver);
        console2.log("Destination:", destination);

        bytes32 guid = bridgeSender.bridge{value: nativeFee}(
            dstEid,
            amount,
            receiver
        );

        console2.log("\n=== Bridge Initiated Successfully! ===");
        console2.log("Transaction GUID:", uint256(guid));
        console2.log("Track your transfer on LayerZero Scan:");
        console2.log("https://layerzeroscan.com/tx/", uint256(guid));

        vm.stopBroadcast();
    }

    function getUsdc(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return Config.ETHEREUM_USDC;
        if (chainId == 42161) return Config.ARBITRUM_USDC;
        if (chainId == 31337) return address(0); // Update with mock address
        revert("Unsupported chain");
    }

    function getDestinationEid(string memory destination) internal pure returns (uint32) {
        if (keccak256(bytes(destination)) == keccak256(bytes("ethereum"))) {
            return Config.ETHEREUM_EID;
        }
        if (keccak256(bytes(destination)) == keccak256(bytes("arbitrum"))) {
            return Config.ARBITRUM_EID;
        }
        revert("Invalid destination. Use 'ethereum' or 'arbitrum'");
    }
}

contract BridgeQuote is Script {
    function run() external view {
        // Quick script to just get a quote without executing
        address payable sender = payable(vm.envAddress("SENDER_CONTRACT"));
        address receiver = vm.envAddress("RECEIVER_ADDRESS");
        uint256 amount = vm.envUint("BRIDGE_AMOUNT");
        string memory destination = vm.envString("DESTINATION");

        uint32 dstEid = getDestinationEid(destination);

        UsdcBridgeSender bridgeSender = UsdcBridgeSender(sender);
        (uint256 nativeFee, uint256 lzTokenFee) = bridgeSender.quoteBridge(
            dstEid,
            amount,
            receiver
        );

        console2.log("=== Bridge Quote ===");
        console2.log("Amount:", amount / 1e6, "USDC");
        console2.log("Destination:", destination);
        console2.log("Native fee:", nativeFee, "wei");
        console2.log("Native fee:", nativeFee / 1e18, "ETH");
        console2.log("LZ token fee:", lzTokenFee);
    }

    function getDestinationEid(string memory destination) internal pure returns (uint32) {
        if (keccak256(bytes(destination)) == keccak256(bytes("ethereum"))) {
            return Config.ETHEREUM_EID;
        }
        if (keccak256(bytes(destination)) == keccak256(bytes("arbitrum"))) {
            return Config.ARBITRUM_EID;
        }
        revert("Invalid destination");
    }
}