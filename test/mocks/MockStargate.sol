// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStargate} from "../../contracts/interfaces/IStargate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStargate is IStargate {
    address public token;
    uint256 public nextNonce = 1;

    constructor(address _token) {
        token = _token;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable override returns (MessagingReceipt memory) {
        // Transfer tokens from sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), _sendParam.amountLD);

        // Create receipt
        MessagingReceipt memory receipt = MessagingReceipt({
            guid: keccak256(abi.encodePacked(block.timestamp, nextNonce++)),
            nonce: uint64(nextNonce - 1),
            fee: _fee
        });

        // Refund excess ETH
        if (msg.value > _fee.nativeFee) {
            payable(_refundAddress).transfer(msg.value - _fee.nativeFee);
        }

        return receipt;
    }

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external pure override returns (MessagingFee memory) {
        // Mock fee calculation
        return MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });
    }

    function assetIds(address _token) external pure override returns (uint16) {
        return 1; // Mock USDC pool ID
    }
}