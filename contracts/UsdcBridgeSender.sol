// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStargate} from "./interfaces/IStargate.sol";
import {Config} from "./Config.sol";
import {OptionsBuilder} from "./libraries/OptionsBuilder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdcBridgeSender is Ownable {
    using OptionsBuilder for bytes;

    address public immutable stargate;
    address public immutable usdc;
    uint32 public immutable currentChainEid;

    mapping(uint32 => address) public composers;

    event BridgeInitiated(
        address indexed sender,
        address indexed receiver,
        uint32 dstEid,
        uint256 amountLD,
        bytes32 guid
    );

    event ComposerSet(uint32 eid, address composer);

    error InsufficientFee();
    error InvalidDestination();
    error InvalidAmount();
    error ComposerNotSet();

    constructor(
        address _stargate,
        address _usdc,
        uint256 _chainId
    ) Ownable(msg.sender) {
        require(_stargate != address(0), "UsdcBridgeSender: invalid stargate");
        require(_usdc != address(0), "UsdcBridgeSender: invalid usdc");

        stargate = _stargate;
        usdc = _usdc;
        currentChainEid = Config.getEndpointId(_chainId);
    }

    function bridgeToEthereum(
        uint256 amountLD,
        address receiver
    ) external payable returns (bytes32) {
        return _bridge(Config.ETHEREUM_EID, amountLD, receiver);
    }

    function bridgeToArbitrum(
        uint256 amountLD,
        address receiver
    ) external payable returns (bytes32) {
        return _bridge(Config.ARBITRUM_EID, amountLD, receiver);
    }

    function bridge(
        uint32 dstEid,
        uint256 amountLD,
        address receiver
    ) external payable returns (bytes32) {
        return _bridge(dstEid, amountLD, receiver);
    }

    function _bridge(
        uint32 dstEid,
        uint256 amountLD,
        address receiver
    ) internal returns (bytes32) {
        if (dstEid == currentChainEid) revert InvalidDestination();
        if (amountLD == 0) revert InvalidAmount();

        address composer = composers[dstEid];
        if (composer == address(0)) revert ComposerNotSet();

        // Transfer USDC from sender to this contract
        IERC20(usdc).transferFrom(msg.sender, address(this), amountLD);

        // Approve Stargate to spend USDC
        IERC20(usdc).approve(stargate, amountLD);

        // Encode the compose message
        bytes memory composeMsg = abi.encode(receiver, bytes(""));

        // Build options with gas for compose execution
        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(Config.LZ_RECEIVE_GAS_LIMIT, 0)
            .addExecutorLzComposeOption(0, Config.COMPOSE_GAS_LIMIT, 0);

        // Build send parameters
        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: addressToBytes32(composer),
            amountLD: amountLD,
            minAmountLD: amountLD * 99 / 100, // 1% slippage tolerance
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        // Quote the send to get the fee
        IStargate.MessagingFee memory fee = IStargate(stargate).quoteSend(sendParam, false);

        if (msg.value < fee.nativeFee) revert InsufficientFee();

        // Send the tokens through Stargate
        IStargate.MessagingReceipt memory receipt = IStargate(stargate).sendToken{value: fee.nativeFee}(
            sendParam,
            fee,
            msg.sender // refund address
        );

        emit BridgeInitiated(msg.sender, receiver, dstEid, amountLD, receipt.guid);

        // Refund excess ETH if any
        if (msg.value > fee.nativeFee) {
            payable(msg.sender).transfer(msg.value - fee.nativeFee);
        }

        return receipt.guid;
    }

    function quoteBridge(
        uint32 dstEid,
        uint256 amountLD,
        address receiver
    ) external view returns (uint256 nativeFee, uint256 lzTokenFee) {
        address composer = composers[dstEid];
        require(composer != address(0), "UsdcBridgeSender: composer not set");

        bytes memory composeMsg = abi.encode(receiver, bytes(""));

        bytes memory options = OptionsBuilder
            .newOptions()
            .addExecutorLzReceiveOption(Config.LZ_RECEIVE_GAS_LIMIT, 0)
            .addExecutorLzComposeOption(0, Config.COMPOSE_GAS_LIMIT, 0);

        IStargate.SendParam memory sendParam = IStargate.SendParam({
            dstEid: dstEid,
            to: addressToBytes32(composer),
            amountLD: amountLD,
            minAmountLD: amountLD * 99 / 100,
            extraOptions: options,
            composeMsg: composeMsg,
            oftCmd: bytes("")
        });

        IStargate.MessagingFee memory fee = IStargate(stargate).quoteSend(sendParam, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    function setComposer(uint32 _eid, address _composer) external onlyOwner {
        composers[_eid] = _composer;
        emit ComposerSet(_eid, _composer);
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    // Emergency function to recover stuck tokens
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }

    // Emergency function to recover stuck ETH
    function recoverETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}