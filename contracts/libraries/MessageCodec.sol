// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library MessageCodec {
    function encode(
        uint256 _amountLD,
        bytes memory _composeMsg
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            uint8(1), // MSG_TYPE_COMPOSE
            uint64(0), // nonce (placeholder)
            uint32(0), // srcEid (filled by Stargate)
            _amountLD,
            _composeMsg
        );
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