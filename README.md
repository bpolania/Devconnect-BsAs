# Cross-Chain DeFi Suite: Treasury, Flatcoin, and USDC Bridge

A comprehensive DeFi platform featuring tokenized treasury notes, an inflation-pegged stablecoin (Flatcoin), and cross-chain USDC bridging using LayerZero v2 and Stargate v2.

## Overview

This project provides three integrated DeFi systems:

### 1. Treasury System
- **Trade tokenized US Treasury notes** on Arbitrum through an automated market maker
- **Sell treasury tokens for USDC** with instant liquidity
- **Bridge proceeds cross-chain** between Arbitrum and Ethereum

### 2. Flatcoin System ($FLAT)
- **Inflation-pegged stablecoin** that maintains purchasing power
- **Position-based ownership** with interest accrual
- **Order book trading** with spot and future positions
- **Tax mechanism** that funds interest payments to holders

### 3. Cross-Chain Infrastructure
- **USDC bridging** between Ethereum and Arbitrum via Stargate v2
- **Composed operations** using LayerZero's Composer pattern
- **Unified deployment** across multiple chains

## Architecture

### Core Components

#### Treasury System
- **TokenizedTreasury**: ERC20 representation of US Treasury notes with compliance features
- **TreasuryMarketplace**: Constant product AMM for trading treasury tokens against USDC
- **TreasuryBridgeInitiator**: Orchestrates treasury sales and cross-chain bridging

#### Flatcoin System
- **SimpleFlatcoinOFT**: Omnichain fungible token with cross-chain capabilities
- **FlatcoinCore**: Position management, order book, and economic mechanics
  - 2% annual interest rate matching inflation
  - Tax formula: `(principal - earned_interest) * interest_rate`
  - 0.3% spot trading fees, 0.1% position transfer fees

#### Bridge Infrastructure
- **CrossChainComposer**: Receives and processes composed messages on destination chains
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
├── flatcoin/
│   ├── SimpleFlatcoinOFT.sol    # Flatcoin token with OFT capabilities
│   └── FlatcoinCore.sol         # Position management and economics
├── interfaces/                   # External protocol interfaces
│   ├── ILayerZero.sol
│   └── IStargate.sol
└── libraries/                    # Utility libraries
    ├── MessageCodec.sol          # Message encoding/decoding
    └── OptionsBuilder.sol        # LayerZero options construction

script/
├── DeployAll.s.sol               # Deploys all systems
├── DeployFlatcoin.s.sol          # Flatcoin-specific deployment
├── DeployTreasury.s.sol          # Treasury-specific deployment
├── Deploy.s.sol                  # Bridge infrastructure deployment
└── BridgeExample.s.sol           # Example usage scripts

test/
├── TokenizedTreasury.t.sol       # Treasury and marketplace tests
├── CrossChainComposer.t.sol      # Composer pattern tests
├── FlatcoinCore.t.sol            # Flatcoin system tests
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

### Local Development

```bash
# Start local Anvil node
anvil

# Deploy all contracts locally (treasury, flatcoin, and bridge)
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

Local deployment includes:
- Mock tokens (USDC, USDT)
- Mock LayerZero endpoint and Stargate
- All treasury contracts with 1M token / 100k USDC liquidity
- Flatcoin system with 100k USDT reserves
- Cross-chain infrastructure fully configured

### Testnet Deployment (Sepolia)

#### Prerequisites
1. **Get Testnet ETH**:
   - Ethereum Sepolia: https://sepoliafaucet.com/
   - Arbitrum Sepolia: https://faucets.chain.link/arbitrum-sepolia

2. **Get Testnet USDC**:
   - Ethereum Sepolia USDC: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
   - Arbitrum Sepolia USDC: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
   - Use Circle's testnet faucet: https://faucet.circle.com/

3. **Configure RPC URLs** in `.env`:
   ```bash
   ETH_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
   ARBITRUM_RPC_URL=https://arbitrum-sepolia.infura.io/v3/YOUR_INFURA_KEY
   ```

#### Step 1: Deploy to Arbitrum Sepolia
```bash
# Deploy all contracts (treasury, flatcoin, bridge)
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY \
  -vvvv

# Deployed contracts:
# Treasury System:
#   - TokenizedTreasury: 0x...
#   - TreasuryMarketplace: 0x...
#   - TreasuryBridgeInitiator: 0x...
# Flatcoin System:
#   - SimpleFlatcoinOFT: 0x...
#   - FlatcoinCore: 0x...
# Bridge Infrastructure:
#   - CrossChainComposer: 0x...
#   - UsdcBridgeSender: 0x...
```

#### Step 2: Deploy to Ethereum Sepolia
```bash
# Deploy bridge and flatcoin contracts (no treasury)
forge script script/DeployAll.s.sol:DeployAll \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  -vvvv

# Deployed contracts:
# - CrossChainComposer: 0x...
# - UsdcBridgeSender: 0x...
# - SimpleFlatcoinOFT: 0x...
# - FlatcoinCore: 0x...
```

#### Step 3: Configure Cross-Chain Connection
```bash
# Set composer addresses on both chains
# On Arbitrum Sepolia - point to Ethereum composer
cast send <ARBITRUM_SENDER_ADDRESS> \
  "setComposer(uint32,address)" \
  40161 <ETHEREUM_COMPOSER_ADDRESS> \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY

# On Ethereum Sepolia - point to Arbitrum composer
cast send <ETHEREUM_SENDER_ADDRESS> \
  "setComposer(uint32,address)" \
  40231 <ARBITRUM_COMPOSER_ADDRESS> \
  --rpc-url $ETH_RPC_URL \
  --private-key $PRIVATE_KEY
```

#### Step 4: Initialize Markets
```bash
# Mint initial treasury supply
cast send <TREASURY_ADDRESS> \
  "mint(address,uint256)" \
  $YOUR_ADDRESS 1000000000000000000000000 \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY

# Approve marketplace for treasury tokens
cast send <TREASURY_ADDRESS> \
  "approve(address,uint256)" \
  <MARKETPLACE_ADDRESS> 500000000000000000000000 \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY

# Approve marketplace for USDC
cast send <USDC_ADDRESS> \
  "approve(address,uint256)" \
  <MARKETPLACE_ADDRESS> 500000000000 \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY

# Add liquidity to marketplace
cast send <MARKETPLACE_ADDRESS> \
  "addLiquidity(uint256,uint256)" \
  100000000000000000000000 100000000000 \
  --rpc-url $ARBITRUM_RPC_URL \
  --private-key $PRIVATE_KEY
```

##### Initialize Flatcoin (All chains)
```bash
# Add USDT reserves to FlatcoinCore
cast send <USDT_ADDRESS> \
  "approve(address,uint256)" \
  <FLATCOIN_CORE_ADDRESS> 100000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

cast send <FLATCOIN_CORE_ADDRESS> \
  "addReserves(uint256)" \
  100000000000 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Configure cross-chain peers for Flatcoin
cast send <FLATCOIN_OFT_ADDRESS> \
  "setPeer(uint32,address)" \
  <DESTINATION_CHAIN_ID> <PEER_FLATCOIN_ADDRESS> \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Mainnet Deployment

For mainnet deployment, follow the same steps but:
1. Use mainnet RPC URLs and chain IDs (Ethereum: 1, Arbitrum: 42161)
2. Ensure sufficient ETH for gas fees
3. Use real USDC addresses from Config.sol
4. Consider using a hardware wallet or multisig for deployment
5. Test thoroughly on testnet first
6. Audit contracts before mainnet deployment

### Verification & Monitoring

#### Verify Contracts on Block Explorers
```bash
# Verify on Arbiscan (Arbitrum Sepolia)
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id 421614 \
  --etherscan-api-key $ARBISCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(...)" ...)

# Verify on Etherscan (Ethereum Sepolia)
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(...)" ...)
```

#### Monitor Your Deployment
1. **Track Bridge Transactions**:
   - LayerZero Scan: https://testnet.layerzeroscan.com/
   - Search by transaction GUID returned from bridge operations

2. **Check Contract State**:
   ```bash
   # Check treasury token supply
   cast call <TREASURY_ADDRESS> "totalSupply()" --rpc-url $ARBITRUM_RPC_URL | cast --to-dec

   # Check marketplace liquidity
   cast call <MARKETPLACE_ADDRESS> "treasuryReserve()" --rpc-url $ARBITRUM_RPC_URL | cast --to-dec
   cast call <MARKETPLACE_ADDRESS> "usdcReserve()" --rpc-url $ARBITRUM_RPC_URL | cast --to-dec

   # Check bridge sender composer settings
   cast call <SENDER_ADDRESS> "composers(uint32)" 40161 --rpc-url $ARBITRUM_RPC_URL
   ```

3. **Test Bridge Operations**:
   ```bash
   # Quote bridge fee
   cast call <SENDER_ADDRESS> \
     "quoteBridge(uint32,uint256,address)" \
     40161 1000000 <RECIPIENT_ADDRESS> \
     --rpc-url $ARBITRUM_RPC_URL
   ```

## Usage

### Flatcoin Operations

```solidity
// Buy FLAT tokens spot (1:1 with USDT)
uint256 positionId = flatcoinCore.buySpot(usdtAmount);

// Sell FLAT tokens (receive USDT + interest - tax)
flatcoinCore.sellSpot(positionId);

// Place buy/sell orders
uint256 orderId = flatcoinCore.placeBuyOrder(amount, price);
flatcoinCore.placeSellOrder(amount, price);

// Fill orders
flatcoinCore.fillOrder(orderId, amount);

// Buy future position
flatcoinCore.buyFuture(amount, futurePrice);

// Transfer position (0.1% fee)
flatcoinCore.transferPosition(positionId, newOwner);

// Cross-chain transfer
flatcoin.sendToChain{value: bridgeFee}(dstChainId, recipient, amount);
```

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
# Run all tests (30 tests across all systems)
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test suites
forge test --match-contract TokenizedTreasury -vvv  # 11 tests
forge test --match-contract CrossChainComposer -vvv # 7 tests
forge test --match-contract FlatcoinCore -vvv       # 12 tests
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

## Flatcoin Mechanics

### Economic Model
- **Interest Rate**: 2% annual (configurable by owner)
- **Tax Formula**: `(principal - earned_interest) * interest_rate`
- **Break-even**: ~1 year holding period (interest overcomes tax)
- **Fees**: 0.3% on spot trades, 0.1% on position transfers

### Position System
- Each buy creates a unique position NFT
- Positions track principal, open time, and type (spot/future)
- Interest accrues based on holding duration
- Positions are transferable with fees

## Security Features

- **Composer Validation**: Only LayerZero endpoint can call lzCompose
- **Source Verification**: Validates messages come from trusted Stargate
- **Emergency Recovery**: Owner can recover stuck tokens
- **Trading Limits**: Configurable maximum transaction and daily limits
- **Reentrancy Protection**: All external calls protected
- **Position Ownership**: Only position owners can sell or transfer

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