// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleFlatcoinOFT
 * @notice Simplified OFT implementation for FLAT - an inflation-pegged stablecoin
 * @dev This is a simplified version that can be extended with LayerZero OFT later
 */
contract SimpleFlatcoinOFT is ERC20, Ownable {
    // Core contract that manages positions and minting/burning
    address public coreContract;

    // LayerZero endpoint for future integration
    address public lzEndpoint;

    // Peer addresses on other chains (chainId => peer address)
    mapping(uint32 => address) public peers;

    // Events
    event CoreContractSet(address indexed oldCore, address indexed newCore);
    event PeerSet(uint32 indexed chainId, address indexed peer);
    event CrossChainTransfer(
        address indexed from,
        address indexed to,
        uint32 indexed dstChainId,
        uint256 amount
    );

    // Errors
    error OnlyCore();
    error InvalidAddress();
    error InsufficientBalance();
    error PeerNotSet();

    modifier onlyCore() {
        if (msg.sender != coreContract) revert OnlyCore();
        _;
    }

    /**
     * @notice Constructor for SimpleFlatcoinOFT
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _lzEndpoint LayerZero endpoint address (can be 0 for testing)
     * @param _owner Owner address
     */
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _owner
    ) ERC20(_name, _symbol) Ownable(_owner) {
        lzEndpoint = _lzEndpoint;
    }

    /**
     * @notice Set the core contract address
     * @param _coreContract Address of the FlatcoinCore contract
     */
    function setCoreContract(address _coreContract) external onlyOwner {
        if (_coreContract == address(0)) revert InvalidAddress();
        address oldCore = coreContract;
        coreContract = _coreContract;
        emit CoreContractSet(oldCore, _coreContract);
    }

    /**
     * @notice Mint tokens (only callable by core contract)
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyCore {
        _mint(_to, _amount);
    }

    /**
     * @notice Burn tokens (only callable by core contract)
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external onlyCore {
        _burn(_from, _amount);
    }

    /**
     * @notice Set peer address on another chain
     * @param _chainId Chain ID of the peer
     * @param _peer Address of the peer contract
     */
    function setPeer(uint32 _chainId, address _peer) external onlyOwner {
        if (_peer == address(0)) revert InvalidAddress();
        peers[_chainId] = _peer;
        emit PeerSet(_chainId, _peer);
    }

    /**
     * @notice Send tokens to another chain (simplified version)
     * @param _dstChainId Destination chain ID
     * @param _to Recipient address on destination chain
     * @param _amount Amount to send
     * @dev In production, this would integrate with LayerZero
     */
    function sendToChain(
        uint32 _dstChainId,
        address _to,
        uint256 _amount
    ) external payable {
        if (balanceOf(msg.sender) < _amount) revert InsufficientBalance();
        if (peers[_dstChainId] == address(0)) revert PeerNotSet();

        // Burn tokens on source chain
        _burn(msg.sender, _amount);

        // In production: Call LayerZero endpoint to send message
        // For now, just emit event
        emit CrossChainTransfer(msg.sender, _to, _dstChainId, _amount);
    }

    /**
     * @notice Receive tokens from another chain (simplified version)
     * @param _from Sender address on source chain
     * @param _to Recipient address on this chain
     * @param _amount Amount received
     * @dev In production, this would be called by LayerZero endpoint
     */
    function receiveFromChain(
        address _from,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        // In production: Verify the message came from LayerZero endpoint
        // and from a trusted peer
        _mint(_to, _amount);
        emit CrossChainTransfer(_from, _to, uint32(block.chainid), _amount);
    }

    /**
     * @notice Get token decimals (USDT-compatible 6 decimals)
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}