// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILayerZeroComposer} from "./interfaces/ILayerZero.sol";
import {MessageCodec} from "./libraries/MessageCodec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract UsdcComposer is ILayerZeroComposer, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable endpoint;
    address public immutable stargate;
    address public immutable usdc;

    // Optional integrations
    address public treasuryVault;
    address public defiProtocol;

    // Statistics
    mapping(uint8 => uint256) public operationCounts;
    mapping(uint32 => address) public trustedRemotes;

    event ComposedTransfer(
        address indexed receiver,
        uint256 amountLD,
        uint32 srcEid,
        bytes32 guid,
        uint8 operationType
    );

    event TreasuryOperation(
        address indexed receiver,
        uint256 amountLD,
        bytes treasuryData,
        bytes32 guid
    );

    event TrustedRemoteSet(uint32 eid, address remote);

    error InvalidCaller();
    error InvalidSourceAddress();
    error TransferFailed();
    error InsufficientBalance();
    error UnsupportedOperation();

    constructor(
        address _endpoint,
        address _stargate,
        address _usdc
    ) Ownable(msg.sender) {
        require(_endpoint != address(0), "UsdcComposer: invalid endpoint");
        require(_stargate != address(0), "UsdcComposer: invalid stargate");
        require(_usdc != address(0), "UsdcComposer: invalid usdc");

        endpoint = _endpoint;
        stargate = _stargate;
        usdc = _usdc;
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable override nonReentrant {
        // Verify the call is from the LayerZero endpoint
        if (msg.sender != endpoint) revert InvalidCaller();

        // Verify the source is the Stargate contract
        if (_from != stargate) revert InvalidSourceAddress();

        // Convert to memory and decode message type
        bytes memory message = _message;
        uint8 messageType = MessageCodec.decodeMessageType(message);

        // Route to appropriate handler
        if (messageType == MessageCodec.MSG_TYPE_SIMPLE_TRANSFER) {
            _handleSimpleTransfer(_guid, message);
        } else if (messageType == MessageCodec.MSG_TYPE_TREASURY_SALE) {
            _handleTreasuryOperation(_guid, message);
        } else if (messageType == MessageCodec.MSG_TYPE_VAULT_DEPOSIT) {
            _handleVaultDeposit(_guid, message);
        } else {
            revert UnsupportedOperation();
        }

        // Update statistics
        operationCounts[messageType]++;
    }

    function _handleSimpleTransfer(bytes32 _guid, bytes memory _message) private {
        uint256 amountLD = MessageCodec.decodeAmountLD(_message);
        bytes memory composeMsg = MessageCodec.decodeComposeMsg(_message);
        uint32 srcEid = MessageCodec.decodeSrcEid(_message);

        // Decode the compose message to get the receiver
        (address receiver, ) = abi.decode(composeMsg, (address, bytes));

        // Transfer USDC to receiver
        _transferUsdc(receiver, amountLD);

        emit ComposedTransfer(receiver, amountLD, srcEid, _guid, MessageCodec.MSG_TYPE_SIMPLE_TRANSFER);
    }

    function _handleTreasuryOperation(bytes32 _guid, bytes memory _message) private {
        uint256 amountLD = MessageCodec.decodeAmountLD(_message);
        bytes memory composeMsg = MessageCodec.decodeComposeMsg(_message);
        uint32 srcEid = MessageCodec.decodeSrcEid(_message);

        // Decode treasury-specific data
        (address receiver, bytes memory treasuryData) = abi.decode(composeMsg, (address, bytes));

        // If treasury vault is configured, send there; otherwise to receiver
        address finalRecipient = treasuryVault != address(0) ? treasuryVault : receiver;
        _transferUsdc(finalRecipient, amountLD);

        emit TreasuryOperation(receiver, amountLD, treasuryData, _guid);
        emit ComposedTransfer(finalRecipient, amountLD, srcEid, _guid, MessageCodec.MSG_TYPE_TREASURY_SALE);
    }

    function _handleVaultDeposit(bytes32 _guid, bytes memory _message) private {
        uint256 amountLD = MessageCodec.decodeAmountLD(_message);
        bytes memory composeMsg = MessageCodec.decodeComposeMsg(_message);
        uint32 srcEid = MessageCodec.decodeSrcEid(_message);

        // Decode vault parameters
        (address beneficiary, ) = abi.decode(composeMsg, (address, bytes));

        // If DeFi protocol is configured, approve it; otherwise just transfer
        if (defiProtocol != address(0)) {
            IERC20(usdc).approve(defiProtocol, amountLD);
            // Protocol integration would go here
        }

        _transferUsdc(beneficiary, amountLD);

        emit ComposedTransfer(beneficiary, amountLD, srcEid, _guid, MessageCodec.MSG_TYPE_VAULT_DEPOSIT);
    }

    function _transferUsdc(address recipient, uint256 amount) private {
        uint256 balance = IERC20(usdc).balanceOf(address(this));
        if (balance < amount) revert InsufficientBalance();

        IERC20(usdc).safeTransfer(recipient, amount);
    }

    function setTrustedRemote(uint32 _eid, address _remote) external onlyOwner {
        trustedRemotes[_eid] = _remote;
        emit TrustedRemoteSet(_eid, _remote);
    }

    // Configure optional integrations
    function setIntegrations(address _treasuryVault, address _defiProtocol) external onlyOwner {
        treasuryVault = _treasuryVault;
        defiProtocol = _defiProtocol;
    }

    // Emergency function to recover stuck tokens
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(msg.sender, _amount);
    }

    // View function to check composer's USDC balance
    function getUsdcBalance() external view returns (uint256) {
        return IERC20(usdc).balanceOf(address(this));
    }

    // Get operation statistics
    function getOperationCount(uint8 operationType) external view returns (uint256) {
        return operationCounts[operationType];
    }

    receive() external payable {}
}