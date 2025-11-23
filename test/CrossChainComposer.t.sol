// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrossChainComposer} from "../contracts/CrossChainComposer.sol";
import {MessageCodec} from "../contracts/libraries/MessageCodec.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockEndpoint} from "./mocks/MockEndpoint.sol";

contract CrossChainComposerTest is Test {
    CrossChainComposer public composer;
    MockERC20 public usdc;
    MockEndpoint public endpoint;
    address public stargate;

    address public alice = address(0x1111);
    address public bob = address(0x2222);

    uint32 constant ARBITRUM_EID = 30110;
    bytes32 constant TEST_GUID = bytes32("test_guid");

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USDC", "USDC", 6);
        endpoint = new MockEndpoint();
        stargate = address(0x3333);

        // Deploy composer
        composer = new CrossChainComposer(
            address(endpoint),
            stargate,
            address(usdc)
        );

        // Setup endpoint
        endpoint.setComposer(address(composer));
        endpoint.setStargate(stargate);

        // Fund composer with USDC
        usdc.mint(address(composer), 1000000 * 10**6); // 1M USDC

        // Fund alice
        vm.deal(alice, 10 ether);
    }

    function testLzComposeSuccess() public {
        uint256 amountLD = 100 * 10**6; // 100 USDC
        address receiver = bob;

        // Encode the compose message
        bytes memory composeMsg = abi.encode(receiver, bytes(""));

        // Create the full message as Stargate would send it
        bytes memory message = abi.encodePacked(
            uint8(1), // MSG_TYPE_COMPOSE
            uint64(1), // nonce
            ARBITRUM_EID, // srcEid
            amountLD,
            composeMsg
        );

        uint256 bobBalanceBefore = usdc.balanceOf(bob);

        // Simulate compose call from endpoint
        vm.prank(address(endpoint));
        composer.lzCompose(
            stargate,
            TEST_GUID,
            message,
            address(endpoint),
            bytes("")
        );

        uint256 bobBalanceAfter = usdc.balanceOf(bob);
        assertEq(bobBalanceAfter - bobBalanceBefore, amountLD, "Bob should receive USDC");
    }

    function testLzComposeFailsFromWrongCaller() public {
        uint256 amountLD = 100 * 10**6;
        bytes memory composeMsg = abi.encode(bob, bytes(""));
        bytes memory message = abi.encodePacked(
            uint8(1),
            uint64(1),
            ARBITRUM_EID,
            amountLD,
            composeMsg
        );

        // Try to call from non-endpoint address
        vm.prank(alice);
        vm.expectRevert(CrossChainComposer.InvalidCaller.selector);
        composer.lzCompose(
            stargate,
            TEST_GUID,
            message,
            alice,
            bytes("")
        );
    }

    function testLzComposeFailsFromWrongSource() public {
        uint256 amountLD = 100 * 10**6;
        bytes memory composeMsg = abi.encode(bob, bytes(""));
        bytes memory message = abi.encodePacked(
            uint8(1),
            uint64(1),
            ARBITRUM_EID,
            amountLD,
            composeMsg
        );

        // Call from endpoint but with wrong source
        vm.prank(address(endpoint));
        vm.expectRevert(CrossChainComposer.InvalidSourceAddress.selector);
        composer.lzCompose(
            alice, // wrong source
            TEST_GUID,
            message,
            address(endpoint),
            bytes("")
        );
    }

    function testMessageDecoding() public {
        uint256 amountLD = 123456789;
        address receiver = bob;
        bytes memory additionalData = bytes("extra");
        bytes memory composeMsg = abi.encode(receiver, additionalData);

        bytes memory message = abi.encodePacked(
            uint8(1),
            uint64(42),
            ARBITRUM_EID,
            amountLD,
            composeMsg
        );

        // Test decoding functions
        uint256 decodedAmount = MessageCodec.decodeAmountLD(message);
        assertEq(decodedAmount, amountLD, "Amount should decode correctly");

        uint32 decodedSrcEid = MessageCodec.decodeSrcEid(message);
        assertEq(decodedSrcEid, ARBITRUM_EID, "Source EID should decode correctly");

        bytes memory decodedComposeMsg = MessageCodec.decodeComposeMsg(message);
        (address decodedReceiver, bytes memory decodedAdditionalData) = abi.decode(
            decodedComposeMsg,
            (address, bytes)
        );
        assertEq(decodedReceiver, receiver, "Receiver should decode correctly");
        assertEq(decodedAdditionalData, additionalData, "Additional data should decode correctly");
    }

    function testSetTrustedRemote() public {
        address remoteComposer = address(0x9999);

        composer.setTrustedRemote(ARBITRUM_EID, remoteComposer);
        assertEq(composer.trustedRemotes(ARBITRUM_EID), remoteComposer);
    }

    function testRecoverToken() public {
        uint256 amount = 50 * 10**6;
        uint256 ownerBalanceBefore = usdc.balanceOf(address(this));

        composer.recoverToken(address(usdc), amount);

        uint256 ownerBalanceAfter = usdc.balanceOf(address(this));
        assertEq(ownerBalanceAfter - ownerBalanceBefore, amount);
    }

    function testInsufficientBalance() public {
        // Drain composer USDC
        uint256 balance = usdc.balanceOf(address(composer));
        vm.prank(address(composer));
        usdc.transfer(address(this), balance);

        uint256 amountLD = 100 * 10**6;
        bytes memory composeMsg = abi.encode(bob, bytes(""));
        bytes memory message = abi.encodePacked(
            uint8(1),
            uint64(1),
            ARBITRUM_EID,
            amountLD,
            composeMsg
        );

        vm.prank(address(endpoint));
        vm.expectRevert(CrossChainComposer.InsufficientBalance.selector);
        composer.lzCompose(
            stargate,
            TEST_GUID,
            message,
            address(endpoint),
            bytes("")
        );
    }
}