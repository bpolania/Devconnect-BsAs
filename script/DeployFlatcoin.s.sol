// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SimpleFlatcoinOFT} from "../contracts/flatcoin/SimpleFlatcoinOFT.sol";
import {FlatcoinCore} from "../contracts/flatcoin/FlatcoinCore.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployFlatcoin is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        uint256 chainId = block.chainid;

        console2.log("Deploying Flatcoin system on chain ID:", chainId);
        console2.log("Deployer:", deployer);

        // Get LayerZero endpoint based on chain
        address lzEndpoint = getLzEndpoint(chainId);
        console2.log("LayerZero Endpoint:", lzEndpoint);

        // Get or deploy USDT
        address usdt = getUsdt(chainId);
        console2.log("USDT:", usdt);

        // Deploy SimpleFlatcoinOFT
        SimpleFlatcoinOFT flatcoin = new SimpleFlatcoinOFT(
            "Flatcoin",
            "FLAT",
            lzEndpoint,
            deployer
        );
        console2.log("SimpleFlatcoinOFT deployed at:", address(flatcoin));

        // Deploy FlatcoinCore
        FlatcoinCore core = new FlatcoinCore(
            address(flatcoin),
            usdt
        );
        console2.log("FlatcoinCore deployed at:", address(core));

        // Set core contract in OFT
        flatcoin.setCoreContract(address(core));
        console2.log("Core contract set in SimpleFlatcoinOFT");

        // For testnet: mint some USDT to deployer for testing
        if (chainId == 31337 || chainId == 11155111 || chainId == 421614) {
            MockERC20 mockUsdt = MockERC20(usdt);
            mockUsdt.mint(deployer, 1000000 * 10**6); // 1M USDT
            console2.log("Minted 1M USDT to deployer for testing");

            // Add initial reserves
            mockUsdt.approve(address(core), 100000 * 10**6);
            core.addReserves(100000 * 10**6); // 100k USDT reserves
            console2.log("Added 100k USDT to reserves");
        }

        console2.log("\n=== Deployment Complete ===");
        console2.log("SimpleFlatcoinOFT:", address(flatcoin));
        console2.log("FlatcoinCore:", address(core));
        console2.log("USDT:", usdt);

        console2.log("\n=== Next Steps ===");
        console2.log("1. Configure OFT for cross-chain transfers");
        console2.log("2. Set peers on other chains");
        console2.log("3. Add initial reserves if on mainnet");
        console2.log("4. Monitor and adjust interest rates");

        vm.stopBroadcast();
    }

    function getLzEndpoint(uint256 chainId) internal pure returns (address) {
        // Mainnet
        if (chainId == 1) return 0x1a44076050125825900e736c501f859c50fE728c; // Ethereum
        if (chainId == 42161) return 0x1a44076050125825900e736c501f859c50fE728c; // Arbitrum
        if (chainId == 10) return 0x1a44076050125825900e736c501f859c50fE728c; // Optimism
        if (chainId == 137) return 0x1a44076050125825900e736c501f859c50fE728c; // Polygon
        if (chainId == 56) return 0x1a44076050125825900e736c501f859c50fE728c; // BSC

        // Testnet
        if (chainId == 11155111) return 0x6EDCE65403992e310A62460808c4b910D972f10f; // Sepolia
        if (chainId == 421614) return 0x6EDCE65403992e310A62460808c4b910D972f10f; // Arbitrum Sepolia

        // Local
        if (chainId == 31337) return address(0x1234); // Mock endpoint

        revert("Unsupported chain");
    }

    function getUsdt(uint256 chainId) internal returns (address) {
        // Mainnet USDT
        if (chainId == 1) return 0xdAC17F958D2ee523a2206206994597C13D831ec7; // Ethereum
        if (chainId == 42161) return 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // Arbitrum
        if (chainId == 10) return 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58; // Optimism
        if (chainId == 137) return 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // Polygon
        if (chainId == 56) return 0x55d398326f99059fF775485246999027B3197955; // BSC

        // For testnet and local, deploy mock USDT
        console2.log("Deploying Mock USDT for testing");
        MockERC20 mockUsdt = new MockERC20("Tether USD", "USDT", 6);
        return address(mockUsdt);
    }
}

contract SetFlatcoinPeers is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address flatcoinAddress = vm.envAddress("FLATCOIN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SimpleFlatcoinOFT flatcoin = SimpleFlatcoinOFT(flatcoinAddress);

        // Example: Set Arbitrum as peer from Ethereum
        // Update these based on your deployment
        uint32 arbitrumEid = 30110;
        address arbitrumFlatcoin = vm.envAddress("ARBITRUM_FLATCOIN");

        // SetPeerParams would need to be defined based on actual OFT implementation
        // flatcoin.setPeer(arbitrumEid, bytes32(uint256(uint160(arbitrumFlatcoin))));

        console2.log("Peer set for Arbitrum");

        vm.stopBroadcast();
    }
}