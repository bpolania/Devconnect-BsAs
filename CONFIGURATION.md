# Configuration Guide

## Overview

This project separates configuration into two distinct categories:

### 1. Config.sol - Public On-Chain Constants
**Location:** `contracts/Config.sol`

Contains public, immutable values that are the same for all users:
- **Network Constants:**
  - LayerZero Endpoint IDs (e.g., Ethereum: 30101, Arbitrum: 30110)
  - LayerZero Endpoint contract addresses
  - Stargate contract addresses
  - USDC token addresses on each chain

- **Protocol Parameters:**
  - Gas limits for composed calls
  - Stargate pool IDs
  - Slippage tolerances

These values are compiled into the smart contracts and deployed on-chain.

### 2. .env File - Private User Secrets
**Location:** `.env` (create from `.env.example`)

Contains sensitive, user-specific data that must NEVER be committed to version control:
- **Private Keys:** Your wallet's private key for signing transactions
- **RPC URLs:** Your personal RPC endpoints (can be public or private)
- **API Keys:** Etherscan/Arbiscan keys for contract verification
- **User Parameters:** Personal addresses and amounts for scripts

## Why This Separation?

**Config.sol** is for:
- Contract addresses that everyone needs
- Network IDs and protocol constants
- Values that are safe to share publicly
- Configuration that gets deployed on-chain

**.env file** is for:
- Private keys (NEVER share these!)
- API keys for services
- Personal RPC endpoints with rate limits
- User-specific test parameters

## Setup Instructions

1. **For Development/Testing:**
   ```bash
   # Copy the example environment file
   cp .env.example .env

   # Edit .env and replace placeholders:
   # - PRIVATE_KEY: Your wallet's private key (without 0x prefix)
   # - RPC URLs: Can use the provided public endpoints or your own
   ```

2. **For Mainnet Deployment:**
   - Update `contracts/Config.sol` with actual Stargate V2 addresses when available
   - Use secure RPC endpoints in your `.env` file
   - Consider using hardware wallets or secure key management

## Security Best Practices

1. **NEVER commit .env to git** - It's already in .gitignore
2. **NEVER share your private key** - Not even in screenshots
3. **Use different keys for testnet and mainnet**
4. **Consider using environment-specific .env files:**
   - `.env.local` for local development
   - `.env.testnet` for testnet deployment
   - `.env.mainnet` for mainnet (store securely!)

## Example Usage

```bash
# Local testing
forge test

# Deploy to Sepolia testnet
forge script script/Deploy.s.sol --rpc-url $ETH_RPC_URL --broadcast

# Bridge USDC (after setting SENDER_CONTRACT in .env)
forge script script/BridgeExample.s.sol --rpc-url $ARBITRUM_RPC_URL --broadcast
```