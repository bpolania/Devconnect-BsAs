// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library MessageCodec {
    // Message types
    uint8 constant MSG_TYPE_SIMPLE_TRANSFER = 1;
    uint8 constant MSG_TYPE_TREASURY_SALE = 2;
    uint8 constant MSG_TYPE_VAULT_DEPOSIT = 3;

    function encode(
        uint256 _amountLD,
        bytes memory _composeMsg
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(MSG_TYPE_SIMPLE_TRANSFER),
            uint64(0), // nonce (placeholder)
            uint32(0), // srcEid (filled by Stargate)
            _amountLD,
            _composeMsg
        );
    }

    function encodeTreasurySale(
        uint256 _amountLD,
        address _receiver,
        bytes memory _treasuryData
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(MSG_TYPE_TREASURY_SALE),
            uint64(0), // nonce
            uint32(0), // srcEid
            _amountLD,
            abi.encode(_receiver, _treasuryData)
        );
    }

    function decodeMessageType(bytes memory _message) internal pure returns (uint8) {
        require(_message.length >= 1, "MessageCodec: invalid message length");
        return uint8(_message[0]);
    }

    function decodeAmountLD(bytes memory _message) internal pure returns (uint256) {
        require(_message.length >= 45, "MessageCodec: invalid message length");
        return uint256(bytes32(slice(_message, 13, 32)));
    }

    function decodeComposeMsg(bytes memory _message) internal pure returns (bytes memory) {
        require(_message.length > 45, "MessageCodec: invalid message length");
        return slice(_message, 45, _message.length - 45);
    }

    function decodeSrcEid(bytes memory _message) internal pure returns (uint32) {
        require(_message.length >= 13, "MessageCodec: invalid message length");
        return uint32(bytes4(slice(_message, 9, 4)));
    }

    function slice(bytes memory data, uint256 start, uint256 length) private pure returns (bytes memory) {
        bytes memory result = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}