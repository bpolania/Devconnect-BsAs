# LayerZero v2 + Stargate v2 USDC Bridge

A production-oriented implementation of USDC bridging between Ethereum and Arbitrum using LayerZero v2 and Stargate v2 with the Composer pattern.

## Architecture Overview

This project implements a composable cross-chain USDC bridge using three main components. The UsdcBridgeSender contract initiates bridge operations on the source chain, Stargate v2 handles the actual token bridging between chains, and the UsdcComposer contract on the destination chain receives composed messages and delivers the bridged USDC to the final recipient.

The system uses LayerZero v2's compose functionality, which allows for programmable actions after bridging. When a user initiates a bridge, the sender contract packages both the USDC amount and the recipient's address into a composed message. Stargate bridges the tokens and triggers a composed call on the destination chain. The composer contract then decodes the message and transfers the USDC to the intended recipient.

## Core Flows

### Arbitrum to Ethereum Bridge Flow

The process begins when a user calls bridgeToEthereum on the UsdcBridgeSender contract deployed on Arbitrum, specifying the amount of USDC and the recipient address on Ethereum. The sender contract transfers USDC from the user, approves Stargate to spend it, and constructs a composed message containing the recipient's address. It then calls Stargate's sendToken function with the Ethereum endpoint ID, the Ethereum composer's address, and the composed message.

Stargate bridges the USDC to Ethereum and credits it to the Ethereum Composer contract. The LayerZero endpoint on Ethereum then triggers the lzCompose function on the composer. The composer validates that the call came from the trusted endpoint and Stargate, decodes the message to extract the amount and recipient, and transfers the USDC from itself to the final recipient.

### Ethereum to Arbitrum Bridge Flow

This flow mirrors the Arbitrum to Ethereum process but in reverse. The user initiates the bridge from Ethereum, Stargate handles the cross-chain transfer to Arbitrum, and the Arbitrum composer delivers the USDC to the recipient. The same security checks and message encoding patterns apply.

## Project Structure

```
contracts/
├── Config.sol                 # Network configurations and constants
├── UsdcComposer.sol          # Composer contract for receiving bridged USDC
├── UsdcBridgeSender.sol      # Sender contract for initiating bridges
├── interfaces/               # LayerZero and Stargate interfaces
│   ├── ILayerZero.sol
│   └── IStargate.sol
└── libraries/                # Utility libraries
    ├── MessageCodec.sol      # Message encoding/decoding
    └── OptionsBuilder.sol    # LayerZero options construction

script/
├── Deploy.s.sol              # Deployment script for all networks
└── BridgeExample.s.sol       # Example bridge execution script

test/
├── UsdcComposer.t.sol        # Unit tests for composer
└── mocks/                    # Mock contracts for testing
```

## Setup and Installation

First, install Foundry if you haven't already by following the instructions at https://book.getfoundry.sh/getting-started/installation. Clone this repository and install dependencies:

```bash
git clone <repository>
cd <repository>
forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std
```

## Configuration

The project uses two types of configuration:

### Config.sol (Public Constants)
Contains public on-chain constants that are the same for all users:
- LayerZero endpoint addresses and IDs
- Stargate contract addresses
- USDC token addresses
- Gas limits and pool IDs

Update these in `contracts/Config.sol` with actual deployed addresses from the official LayerZero v2 documentation at https://docs.layerzero.network/v2 and Stargate v2 documentation at https://stargateprotocol.gitbook.io/stargate.

### .env File (Private Secrets)
Contains user-specific private data that should never be committed to version control. Create it from the example:

```bash
cp .env.example .env
# Then edit .env and replace placeholders with your actual values
```

Required variables:
- `PRIVATE_KEY` - Your wallet private key (without 0x prefix)
- `ETH_RPC_URL` - Ethereum RPC endpoint
- `ARBITRUM_RPC_URL` - Arbitrum RPC endpoint

## Testing

Run the test suite to verify the composer logic and message decoding:

```bash
forge test -vvv
```

For gas reporting:

```bash
forge test --gas-report
```

## Deployment

Deploy to a local test environment:

```bash
forge script script/Deploy.s.sol --rpc-url local --broadcast
```

Deploy to Ethereum mainnet:

```bash
forge script script/Deploy.s.sol --rpc-url ethereum --broadcast --verify
```

Deploy to Arbitrum:

```bash
forge script script/Deploy.s.sol --rpc-url arbitrum --broadcast --verify
```

After deployment, you need to set the composer addresses on each sender contract. On Ethereum, set the Arbitrum composer address, and on Arbitrum, set the Ethereum composer address.

## Usage Example

To bridge USDC from Arbitrum to Ethereum:

```bash
# First, quote the bridge fee
SENDER_CONTRACT=0x... RECEIVER_ADDRESS=0x... BRIDGE_AMOUNT=1000000 DESTINATION=ethereum forge script script/BridgeExample.s.sol:BridgeQuote --rpc-url arbitrum

# Then execute the bridge
SENDER_CONTRACT=0x... RECEIVER_ADDRESS=0x... BRIDGE_AMOUNT=1000000 DESTINATION=ethereum forge script script/BridgeExample.s.sol --rpc-url arbitrum --broadcast
```

## Security Considerations

The composer contracts validate that lzCompose calls only come from the LayerZero endpoint and that the source is the trusted Stargate contract. This prevents unauthorized contracts from triggering USDC transfers. The system includes emergency recovery functions for stuck tokens, accessible only by the contract owner. Always verify the source chain and endpoint IDs match expected values when setting up trusted remotes.

## Extensibility

The current implementation performs a simple transfer to the recipient, but the composer pattern allows for much more complex logic. Future enhancements could include automatic deposit into DeFi vaults, token swaps before delivery, batched transfers to multiple recipients, or conditional logic based on on-chain state. The composeMsg field in the sender can be expanded to include additional parameters for these advanced use cases.

To add new functionality, modify the lzCompose function in UsdcComposer.sol after the basic transfer logic. The additionalData field decoded from the compose message can carry instructions for these extended operations.

## Gas Optimization

The contracts are compiled with Solidity 0.8.20 and optimizer enabled at 200 runs. The OptionsBuilder efficiently constructs LayerZero options to minimize calldata size. Consider adjusting COMPOSE_GAS_LIMIT and LZ_RECEIVE_GAS_LIMIT in Config.sol based on your specific use case and gas price conditions.

## Troubleshooting

If bridges fail, check that the composer addresses are correctly set on both sender contracts, verify sufficient gas limits in Config.sol for the compose execution, ensure USDC allowances are properly set before bridging, and confirm the Stargate pool has sufficient liquidity for your transfer amount.

Monitor your transfers on LayerZero Scan using the transaction GUID returned from the bridge function.

## License

MIT