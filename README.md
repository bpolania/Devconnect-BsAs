# Cross-Chain Treasury and USDC Bridge

A production-ready implementation of tokenized treasury notes on Arbitrum with cross-chain USDC bridging to Ethereum using LayerZero v2 and Stargate v2's Composer pattern.

## Overview

This project enables users to:
1. **Trade tokenized US Treasury notes** on Arbitrum through an automated market maker
2. **Sell treasury tokens for USDC** with instant liquidity
3. **Bridge USDC cross-chain** between Arbitrum and Ethereum seamlessly
4. **Compose complex operations** like selling treasuries and bridging in one transaction

## Architecture

### Core Components

- **TokenizedTreasury**: ERC20 representation of US Treasury notes with compliance features (blacklisting, pausing, authorized minting)
- **TreasuryMarketplace**: Constant product AMM for trading treasury tokens against USDC
- **TreasuryBridgeInitiator**: Orchestrates treasury sales and initiates cross-chain USDC bridging on Arbitrum
- **CrossChainComposer**: Receives and processes composed messages on the destination chain
- **UsdcBridgeSender**: Initiates USDC bridging operations via Stargate v2

### Message Types

The system supports three types of composed operations:
- `SIMPLE_TRANSFER`: Direct USDC bridging between chains
- `TREASURY_SALE`: Sell treasury tokens and bridge proceeds
- `VAULT_DEPOSIT`: Bridge USDC for vault operations (extensible)

## Project Structure

```
contracts/
├── Config.sol                    # Network configurations and constants
├── TokenizedTreasury.sol         # ERC20 treasury token with compliance
├── TreasuryMarketplace.sol       # AMM for treasury/USDC trading
├── TreasuryBridgeInitiator.sol   # Orchestrates sales and bridging
├── CrossChainComposer.sol        # Processes composed messages
├── UsdcBridgeSender.sol          # Initiates cross-chain bridging
├── interfaces/                   # External protocol interfaces
│   ├── ILayerZero.sol
│   └── IStargate.sol
└── libraries/                    # Utility libraries
    ├── MessageCodec.sol          # Message encoding/decoding
    └── OptionsBuilder.sol        # LayerZero options construction

script/
├── DeployAll.s.sol               # Comprehensive deployment script
├── DeployTreasury.s.sol          # Treasury-specific deployment
├── Deploy.s.sol                  # Bridge infrastructure deployment
└── BridgeExample.s.sol           # Example usage scripts

test/
├── TokenizedTreasury.t.sol       # Treasury and marketplace tests
├── CrossChainComposer.t.sol      # Composer pattern tests
└── mocks/                        # Mock contracts for testing
```

## Installation

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and setup
git clone <repository>
cd <repository>
forge install
```

## Configuration

### Environment Variables (.env)

```bash
cp .env.example .env
```

Required variables:
- `PRIVATE_KEY`: Deployer wallet private key
- `ARBITRUM_RPC_URL`: Arbitrum RPC endpoint
- `ETH_RPC_URL`: Ethereum RPC endpoint

Optional for treasury deployment:
- `BRIDGE_SENDER_ADDRESS`: Existing bridge sender (if already deployed)
- `TREASURY_ADDRESS`: Existing treasury token address
- `MARKETPLACE_ADDRESS`: Existing marketplace address

### Network Configuration

Update `contracts/Config.sol` with the latest addresses from:
- [LayerZero v2 Endpoints](https://docs.layerzero.network/v2)
- [Stargate v2 Contracts](https://stargateprotocol.gitbook.io/stargate)

## Deployment

### Deploy Everything (Recommended)

```bash
# Deploy all contracts to local testnet
forge script script/DeployAll.s.sol --rpc-url localhost --broadcast

# Deploy to Arbitrum (treasury + bridge infrastructure)
forge script script/DeployAll.s.sol --rpc-url arbitrum --broadcast --verify

# Deploy to Ethereum (bridge infrastructure only)
forge script script/DeployAll.s.sol --rpc-url ethereum --broadcast --verify
```

### Post-Deployment Setup

1. **Configure Cross-Chain Connection**:
```bash
ARBITRUM_SENDER=0x... ETHEREUM_SENDER=0x... \
ARBITRUM_COMPOSER=0x... ETHEREUM_COMPOSER=0x... \
forge script script/DeployAll.s.sol:SetupCrossChain --rpc-url arbitrum --broadcast
```

2. **Add Marketplace Liquidity**:
```bash
TREASURY_ADDRESS=0x... MARKETPLACE_ADDRESS=0x... \
USDC_ADDRESS=0x... TREASURY_LIQUIDITY_AMOUNT=1000000000000000000000 \
USDC_LIQUIDITY_AMOUNT=1000000000000 \
forge script script/DeployTreasury.s.sol:SetupTreasuryLiquidity --rpc-url arbitrum --broadcast
```

## Usage

### Trading Treasury Tokens

```solidity
// Sell treasury tokens for USDC
uint256 usdcReceived = marketplace.sellTreasury(treasuryAmount, minUsdcOut);

// Buy treasury tokens with USDC
uint256 treasuryReceived = marketplace.buyTreasury(usdcAmount, minTreasuryOut);

// Add liquidity to the pool
marketplace.addLiquidity(treasuryAmount, usdcAmount);
```

### Sell Treasury and Bridge to Ethereum

```solidity
// Quote the operation
(uint256 expectedUsdc, uint256 bridgeFee) = initiator.quoteSellAndBridge(treasuryAmount);

// Execute: Sell treasury tokens and bridge USDC to Ethereum
bytes32 guid = initiator.sellAndBridgeWithComposer{value: bridgeFee}(
    treasuryAmount,           // Amount of treasury tokens to sell
    minUsdcOut,               // Minimum USDC to receive
    ethereumRecipient,        // Recipient address on Ethereum
    treasuryMetadata          // Additional data for composer
);
```

### Simple USDC Bridging

```bash
# Bridge USDC from Arbitrum to Ethereum
SENDER_CONTRACT=0x... RECEIVER_ADDRESS=0x... \
BRIDGE_AMOUNT=1000000 DESTINATION=ethereum \
forge script script/BridgeExample.s.sol --rpc-url arbitrum --broadcast
```

## Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test suite
forge test --match-contract TokenizedTreasury -vvv
```

## Treasury Token Features

### Compliance
- **Blacklist Management**: Block specific addresses from transfers
- **Pause Mechanism**: Emergency pause for all transfers
- **Authorized Minting**: Only designated addresses can mint new tokens

### Financial Features
- **Coupon Rate**: Fixed interest rate (e.g., 4.5% annually)
- **Maturity Date**: Token expiration for redemption
- **CUSIP Identifier**: Standard securities identification
- **Interest Calculation**: Accrued interest based on holding period

## Marketplace Mechanics

The TreasuryMarketplace uses a constant product AMM (x * y = k):
- **No Slippage Protection**: Built-in minimum output requirements
- **Fee Collection**: 0.3% trading fee to liquidity providers
- **Price Discovery**: Automatic price adjustment based on supply/demand
- **Liquidity Management**: Add/remove liquidity with proportional shares

## Security Features

- **Composer Validation**: Only LayerZero endpoint can call lzCompose
- **Source Verification**: Validates messages come from trusted Stargate
- **Emergency Recovery**: Owner can recover stuck tokens
- **Trading Limits**: Configurable maximum transaction and daily limits
- **Reentrancy Protection**: All external calls protected

## Gas Optimization

- Compiled with Solidity 0.8.20, optimizer at 200 runs
- Efficient message encoding with MessageCodec library
- Optimized LayerZero options construction
- Via-IR compilation for complex contracts

## Troubleshooting

Common issues and solutions:

1. **Bridge Failure**: Verify composer addresses are set correctly on both chains
2. **Insufficient Gas**: Adjust COMPOSE_GAS_LIMIT in Config.sol
3. **Trading Reverts**: Check marketplace has sufficient liquidity
4. **Minting Fails**: Ensure caller is authorized minter
5. **High Slippage**: Increase minOutput parameters or reduce trade size

Track transfers on [LayerZero Scan](https://layerzeroscan.com) using the returned GUID.

## License

MIT