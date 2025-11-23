// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStargate {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    function token() external view returns (address);

    function assetIds(address token) external view returns (uint16);
}

interface IStargatePool {
    function token() external view returns (address);
}

interface ITokenMessaging {
    function quoteTaxi(
        IStargate.SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (IStargate.MessagingFee memory fee);
}