// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ILayerZeroComposer} from "../../contracts/interfaces/ILayerZero.sol";

contract MockEndpoint {
    address public composer;
    address public stargate;

    function setComposer(address _composer) external {
        composer = _composer;
    }

    function setStargate(address _stargate) external {
        stargate = _stargate;
    }

    function simulateCompose(
        bytes32 _guid,
        bytes calldata _message
    ) external payable {
        ILayerZeroComposer(composer).lzCompose(
            stargate,
            _guid,
            _message,
            address(this),
            bytes("")
        );
    }
}