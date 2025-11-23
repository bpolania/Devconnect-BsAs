// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILayerZeroComposer} from "./interfaces/ILayerZero.sol";
import {MessageCodec} from "./libraries/MessageCodec.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdcComposer is ILayerZeroComposer, Ownable {
    address public immutable endpoint;
    address public immutable stargate;
    address public immutable usdc;

    mapping(uint32 => address) public trustedRemotes;

    event ComposedTransfer(
        address indexed receiver,
        uint256 amountLD,
        uint32 srcEid,
        bytes32 guid
    );

    event TrustedRemoteSet(uint32 eid, address remote);

    error InvalidCaller();
    error InvalidSourceAddress();
    error TransferFailed();
    error InsufficientBalance();

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
    ) external payable override {
        // Verify the call is from the LayerZero endpoint
        if (msg.sender != endpoint) revert InvalidCaller();

        // Verify the source is the Stargate contract
        if (_from != stargate) revert InvalidSourceAddress();

        _handleCompose(_guid, _message);
    }

    function _handleCompose(bytes32 _guid, bytes memory _message) private {
        // Decode the message to extract amount and inner compose message
        uint256 amountLD = MessageCodec.decodeAmountLD(_message);
        bytes memory composeMsg = MessageCodec.decodeComposeMsg(_message);
        uint32 srcEid = MessageCodec.decodeSrcEid(_message);

        // Decode the compose message to get the receiver
        (address receiver, ) = abi.decode(composeMsg, (address, bytes));

        // Check that this contract has enough USDC balance
        uint256 balance = IERC20(usdc).balanceOf(address(this));
        if (balance < amountLD) revert InsufficientBalance();

        // Transfer USDC to the receiver
        bool success = IERC20(usdc).transfer(receiver, amountLD);
        if (!success) revert TransferFailed();

        emit ComposedTransfer(receiver, amountLD, srcEid, _guid);

        // Future extension point: process additionalData for more complex logic
        // For example, could auto-deposit into a vault, swap, or other DeFi action
    }

    function setTrustedRemote(uint32 _eid, address _remote) external onlyOwner {
        trustedRemotes[_eid] = _remote;
        emit TrustedRemoteSet(_eid, _remote);
    }

    // Emergency function to recover stuck tokens
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    // View function to check composer's USDC balance
    function getUsdcBalance() external view returns (uint256) {
        return IERC20(usdc).balanceOf(address(this));
    }

    receive() external payable {}
}