# Testnet Deployment Summary

## Deployment Date
November 23, 2025

## Deployer Address
0x541dED3778741d4A991141672d73aaeb7495b2a1

## Arbitrum Sepolia (Chain ID: 421614)

### Cross-Chain Infrastructure
- **CrossChainComposer**: `0xBfDd5129f519c2AE700dC071a65725766856F6E6`
- **UsdcBridgeSender**: `0xb358B625F069A5221D5357C8069c1b24BC79b5e5`

### Treasury System
- **TokenizedTreasury**: `0x087482d238870B874F93f68cF56C1EF1F1C486AB`
- **TreasuryMarketplace**: `0x9a41c6fed3e4E6E19BBEe0aF1D7358cf2b2A7331`
- **TreasuryBridgeInitiator**: `0x576F2c228917e5fe519b8edF470b995c3D3adcCf`

### Flatcoin System
- **SimpleFlatcoinOFT**: `0xc40f4A59E448ee477fe116a4f601A5002118EA39`
- **FlatcoinCore**: `0x533c735fb733Bb11EC43F680fECEa5dae31094C6`

### Tokens
- **USDC (Official Testnet)**: `0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d`
- **USDT (Mock)**: `0xD3910EA06835ebCcffBf6Be8DbDC52dB4dd8CF37`

## Ethereum Sepolia (Chain ID: 11155111)

### Cross-Chain Infrastructure
- **CrossChainComposer**: `0xb358B625F069A5221D5357C8069c1b24BC79b5e5`
- **UsdcBridgeSender**: `0x087482d238870B874F93f68cF56C1EF1F1C486AB`

### Flatcoin System
- **SimpleFlatcoinOFT**: `0x576F2c228917e5fe519b8edF470b995c3D3adcCf`
- **FlatcoinCore**: `0x6efc4e0075f25bBCE9441064254C23A9F1df0c90`

### Tokens
- **USDC (Official Testnet)**: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`
- **USDT (Mock)**: `0x9a41c6fed3e4E6E19BBEe0aF1D7358cf2b2A7331`

## Configuration Status

All configuration steps have been completed successfully!

## Completed Steps

### 1. Configure Cross-Chain Connections

- **Arbitrum Sender → Ethereum Composer**: Transaction `0xfeb503699aae3ef90f13990722b40e25fc01ee75619b7ac802181717ec4359a8`
- **Ethereum Sender → Arbitrum Composer**: Transaction `0x516d6591e9f2c53997d9678873c26b3a78a2a0c4e40886688563752218d5623f`

### 2. Configure Flatcoin Peers

- **Arbitrum Flatcoin → Ethereum Peer**: Transaction `0x9d15789d4b2a90d5abe5923c9d130bbf3b8f1e856820664ddf31258a4ab5da06`
- **Ethereum Flatcoin → Arbitrum Peer**: Transaction `0xd525de71b0c27f37ac291d10bc027a54e799c2fea87e3686c808fb7e7938cbe0`

### 3. Initialize Treasury Marketplace (Arbitrum)

- **Authorized Minter**: Transaction `0xb3d7ccf634f87ef547f124d20ac97f27895cdbdc7636c6e9f8bd0703cfaf0fee`
- **Minted 1M Treasury Tokens**: Transaction `0xd5adb00bfc9288717038bedaf8f5117218c410c7c1442a3c68ec583ae00ca1d4`
- **Approved Marketplace**: Transaction `0xb6d6b5d17225675a2561989b56a2e9e8d56021887ed360f7b2337aa0fe22b7ea`
- **Note**: Liquidity will be added after obtaining testnet USDC from [Circle Faucet](https://faucet.circle.com/)

### 4. Initialize Flatcoin System

#### Arbitrum Sepolia
- **Minted 100k USDT**: Transaction `0x1f15ab12aefd649425d028225dc3799a40887aa7734277a89d77617c7fedb1cc`
- **Approved FlatcoinCore**: Transaction `0xee98a0b7c599d3cb70568f704da914a62bdaadccc975dced3c8b1e515888484b`
- **Added 100k USDT Reserves**: Transaction `0xd87bbd75a23d68ba561c3a5bd3c4a985196cee29f1f30ba6c91a97f8fd5bbfbc`

#### Ethereum Sepolia
- **Minted 100k USDT**: Transaction `0xdd6d61bd99dddc582f88976211b7ea87d3c6b0bd06441f501afacd0081f9ab78`
- **Approved FlatcoinCore**: Transaction `0x620a13df00676c13a7de0522233e290b7c23542d23d3665984a6d90dd703d9db`
- **Added 100k USDT Reserves**: Transaction `0x289bf860ee7921ce1eb87cfa66a0b772e83a580da1fc0a0e07c41bff1bb06562`

## Block Explorer Links

### Arbitrum Sepolia
- View contracts: https://sepolia.arbiscan.io/address/[CONTRACT_ADDRESS]
- Example: https://sepolia.arbiscan.io/address/0xBfDd5129f519c2AE700dC071a65725766856F6E6

### Ethereum Sepolia
- View contracts: https://sepolia.etherscan.io/address/[CONTRACT_ADDRESS]
- Example: https://sepolia.etherscan.io/address/0xb358B625F069A5221D5357C8069c1b24BC79b5e5

## Important Notes

1. **Get Testnet Tokens**:
   - ETH Sepolia: https://sepoliafaucet.com/
   - Arbitrum Sepolia: https://faucets.chain.link/arbitrum-sepolia
   - USDC Testnet: https://faucet.circle.com/

2. **LayerZero Endpoints**:
   - Ethereum Sepolia EID: 40161
   - Arbitrum Sepolia EID: 40231

3. **Contract Verification**:
   - Contracts can be verified on block explorers using the deployment artifacts in `broadcast/` directory
   - Use `forge verify-contract` with appropriate constructor arguments

4. **Security**:
   - These are testnet deployments for testing purposes only
   - Never use testnet private keys on mainnet
   - Always audit contracts before mainnet deployment