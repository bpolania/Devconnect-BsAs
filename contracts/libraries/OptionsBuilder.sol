// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library OptionsBuilder {
    uint16 internal constant TYPE_3 = 3;

    function newOptions() internal pure returns (bytes memory) {
        return abi.encodePacked(TYPE_3);
    }

    function addExecutorLzReceiveOption(
        bytes memory _options,
        uint128 _gas,
        uint128 _value
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _options,
            uint8(1), // EXECUTOR_LZ_RECEIVE_OPTION
            uint16(16 + 16), // gas + value size
            _gas,
            _value
        );
    }

    function addExecutorLzComposeOption(
        bytes memory _options,
        uint16 _index,
        uint128 _gas,
        uint128 _value
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _options,
            uint8(2), // EXECUTOR_LZ_COMPOSE_OPTION
            uint16(2 + 16 + 16), // index + gas + value size
            _index,
            _gas,
            _value
        );
    }

    function addExecutorOrderedExecutionOption(
        bytes memory _options
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            _options,
            uint8(5), // EXECUTOR_ORDERED_EXECUTION_OPTION
            uint16(0) // no additional data
        );
    }
}