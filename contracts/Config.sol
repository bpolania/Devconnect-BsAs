// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title Config
 * @notice Contains public on-chain constants for the LayerZero + Stargate bridge
 * @dev These are public values that are the same for all users
 *      Private/sensitive data like private keys and API keys go in .env file
 */
library Config {
    // LayerZero Endpoint IDs (v2)
    // Mainnet
    uint32 constant ETHEREUM_EID = 30101; // Ethereum mainnet
    uint32 constant ARBITRUM_EID = 30110; // Arbitrum One
    // Testnet (Sepolia)
    uint32 constant ETHEREUM_SEPOLIA_EID = 40161; // Ethereum Sepolia
    uint32 constant ARBITRUM_SEPOLIA_EID = 40231; // Arbitrum Sepolia

    // LayerZero Endpoints V2
    // Mainnet endpoints (same address on all chains)
    address constant ETHEREUM_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    address constant ARBITRUM_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    // Testnet endpoints (Sepolia - same address on all chains)
    address constant SEPOLIA_ENDPOINT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

    // Stargate addresses (v2)
    // NOTE: These are example addresses - verify with official Stargate v2 docs before mainnet deployment
    // Mainnet
    address constant ETHEREUM_STARGATE = 0x0000000000000000000000000000000000000000; // TODO: Update with actual address
    address constant ARBITRUM_STARGATE = 0x0000000000000000000000000000000000000000; // TODO: Update with actual address
    // Testnet (Sepolia)
    address constant ETHEREUM_SEPOLIA_STARGATE = 0x0000000000000000000000000000000000000000; // TODO: Update when available
    address constant ARBITRUM_SEPOLIA_STARGATE = 0x0000000000000000000000000000000000000000; // TODO: Update when available

    // USDC Token addresses
    // Mainnet
    address constant ETHEREUM_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // Mainnet USDC
    address constant ARBITRUM_USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831; // Arbitrum USDC
    // Testnet USDC (these are example test tokens - use actual testnet USDC when available)
    address constant ETHEREUM_SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC on Sepolia
    address constant ARBITRUM_SEPOLIA_USDC = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d; // USDC on Arbitrum Sepolia

    // Stargate Pool IDs for USDC
    uint16 constant USDC_POOL_ID = 1; // Usually pool ID 1 for USDC

    // Gas limits for composed calls
    uint128 constant COMPOSE_GAS_LIMIT = 500000;
    uint128 constant LZ_RECEIVE_GAS_LIMIT = 200000;

    function getEndpointId(uint256 chainId) internal pure returns (uint32) {
        if (chainId == 1) return ETHEREUM_EID;
        if (chainId == 42161) return ARBITRUM_EID;
        revert("Config: unsupported chain");
    }

    function getEndpoint(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return ETHEREUM_ENDPOINT;
        if (chainId == 42161) return ARBITRUM_ENDPOINT;
        revert("Config: unsupported chain");
    }

    function getStargate(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return ETHEREUM_STARGATE;
        if (chainId == 42161) return ARBITRUM_STARGATE;
        revert("Config: unsupported chain");
    }

    function getUsdc(uint256 chainId) internal pure returns (address) {
        if (chainId == 1) return ETHEREUM_USDC;
        if (chainId == 42161) return ARBITRUM_USDC;
        revert("Config: unsupported chain");
    }
}