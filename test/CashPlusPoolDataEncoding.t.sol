// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {ICashPlus} from "src/interfaces/ICashPlus.sol";

/// @dev Test harness to expose internal encoding/decoding functions
contract PoolDataEncodingHarness {
    /// @dev Encodes TokenData[] and amounts[] into compact bytes.
    function encodePoolData(
        ICashPlus.TokenData[] memory tokenDatas,
        uint256[] memory amounts
    ) external pure returns (bytes memory) {
        return _encodePoolData(tokenDatas, amounts);
    }

    /// @dev Decodes compact bytes back to TokenData[] and amounts[].
    function decodePoolData(
        bytes memory data
    )
        external
        pure
        returns (
            ICashPlus.TokenData[] memory tokenDatas,
            uint256[] memory amounts,
            uint256 totalAmount
        )
    {
        return _decodePoolData(data);
    }

    function _encodePoolData(
        ICashPlus.TokenData[] memory tokenDatas,
        uint256[] memory amounts
    ) internal pure returns (bytes memory) {
        uint256 length = tokenDatas.length;
        require(length == amounts.length, "Length mismatch");
        require(length <= type(uint16).max, "Too many elements");

        // Calculate total size: 2 bytes length + 76 bytes per element
        bytes memory data = new bytes(2 + length * 76);

        assembly {
            let ptr := add(data, 32) // skip length prefix of bytes

            // Store length as uint16 (2 bytes)
            mstore8(ptr, shr(8, length))
            mstore8(add(ptr, 1), and(length, 0xff))
            ptr := add(ptr, 2)

            // Get pointers to arrays (skip length prefix)
            let tokenDatasPtr := add(tokenDatas, 32)
            let amountsPtr := add(amounts, 32)

            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                // Get pointer to current TokenData struct
                let structPtr := mload(add(tokenDatasPtr, mul(i, 32)))

                // id (32 bytes) - full uint256
                mstore(ptr, mload(structPtr))
                ptr := add(ptr, 32)

                // amount as uint128 (16 bytes) - take lower 128 bits, shift left to align
                let amt := mload(add(amountsPtr, mul(i, 32)))
                mstore(ptr, shl(128, amt))
                ptr := add(ptr, 16)

                // tokenOwner (20 bytes)
                let tOwner := mload(add(structPtr, 32))
                mstore(ptr, shl(96, tOwner))
                ptr := add(ptr, 20)

                // chainId as uint64 (8 bytes)
                let chainId := mload(add(structPtr, 64))
                mstore(ptr, shl(192, chainId))
                ptr := add(ptr, 8)
            }
        }

        return data;
    }

    function _decodePoolData(
        bytes memory data
    )
        internal
        pure
        returns (
            ICashPlus.TokenData[] memory tokenDatas,
            uint256[] memory amounts,
            uint256 totalAmount
        )
    {
        require(data.length >= 2, "Data too short");

        // Read length from first 2 bytes
        uint256 length = (uint256(uint8(data[0])) << 8) |
            uint256(uint8(data[1]));

        require(data.length == 2 + length * 76, "Invalid data length");

        tokenDatas = new ICashPlus.TokenData[](length);
        amounts = new uint256[](length);
        totalAmount = 0;

        assembly {
            let ptr := add(add(data, 32), 2) // skip bytes length + uint16 length
            let tokenDatasPtr := add(tokenDatas, 32)
            let amountsPtr := add(amounts, 32)

            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                // Allocate new TokenData struct
                let structPtr := mload(0x40)
                mstore(0x40, add(structPtr, 96)) // 3 * 32 bytes
                mstore(add(tokenDatasPtr, mul(i, 32)), structPtr)

                // id (32 bytes) - full uint256
                mstore(structPtr, mload(ptr))
                ptr := add(ptr, 32)

                // amount from uint128 (16 bytes) - read 32 bytes and shift right by 128 bits
                let amt := shr(128, mload(ptr))
                mstore(add(amountsPtr, mul(i, 32)), amt)
                totalAmount := add(totalAmount, amt)
                ptr := add(ptr, 16)

                // tokenOwner (20 bytes) - read 32 bytes and shift right by 96 bits
                let tokenOwner := shr(96, mload(ptr))
                mstore(add(structPtr, 32), tokenOwner)
                ptr := add(ptr, 20)

                // chainId from uint64 (8 bytes) - read 32 bytes and shift right by 192 bits
                let cId := shr(192, mload(ptr))
                mstore(add(structPtr, 64), cId)
                ptr := add(ptr, 8)
            }
        }
    }
}

contract CashPlusPoolDataEncodingTest is Test {
    PoolDataEncodingHarness harness;

    function setUp() public {
        harness = new PoolDataEncodingHarness();
    }

    function testEncodeDecode_SingleElement() public view {
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenDatas[0] = ICashPlus.TokenData({
            id: 1001,
            tokenOwner: address(0x1234567890AbcdEF1234567890aBcdef12345678),
            chainId: 56
        });
        amounts[0] = 100 ether;

        // Encode
        bytes memory encoded = harness.encodePoolData(tokenDatas, amounts);

        // Check size: 2 + 76 = 78 bytes
        assertEq(encoded.length, 78, "Single element should be 78 bytes");

        // Decode
        (
            ICashPlus.TokenData[] memory decodedTokenDatas,
            uint256[] memory decodedAmounts,
            uint256 totalAmount
        ) = harness.decodePoolData(encoded);

        // Verify
        assertEq(decodedTokenDatas.length, 1);
        assertEq(decodedAmounts.length, 1);
        assertEq(decodedTokenDatas[0].id, 1001);
        assertEq(
            decodedTokenDatas[0].tokenOwner,
            address(0x1234567890AbcdEF1234567890aBcdef12345678)
        );
        assertEq(decodedTokenDatas[0].chainId, 56);
        assertEq(decodedAmounts[0], 100 ether);
        assertEq(totalAmount, 100 ether);
    }

    function testEncodeDecode_MultipleElements() public view {
        // ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](3);
        // uint256[] memory amounts = new uint256[](3);
        // tokenDatas[0] = ICashPlus.TokenData({
        //     id: 1001,
        //     tokenOwner: address(0x1111111111111111111111111111111111111111),
        //     chainId: 1
        // });
        // tokenDatas[1] = ICashPlus.TokenData({
        //     id: 2002,
        //     tokenOwner: address(0x2222222222222222222222222222222222222222),
        //     chainId: 56
        // });
        // tokenDatas[2] = ICashPlus.TokenData({
        //     id: 3003,
        //     tokenOwner: address(0x3333333333333333333333333333333333333333),
        //     chainId: 137
        // });
        // amounts[0] = 10 ether;
        // amounts[1] = 20 ether;
        // amounts[2] = 30 ether;
        // // Encode
        // bytes memory encoded = harness.encodePoolData(tokenDatas, amounts);
        // // Check size: 2 + 76*3 = 230 bytes
        // assertEq(encoded.length, 230, "3 elements should be 230 bytes");
        // // Decode
        // (
        //     ICashPlus.TokenData[] memory decodedTokenDatas,
        //     uint256[] memory decodedAmounts,
        //     uint256 totalAmount
        // ) = harness.decodePoolData(encoded);
        // // Verify
        // assertEq(decodedTokenDatas.length, 3);
        // assertEq(decodedAmounts.length, 3);
        // assertEq(decodedTokenDatas[0].id, 1001);
        // assertEq(decodedTokenDatas[0].tokenOwner, address(0x1111111111111111111111111111111111111111));
        // assertEq(decodedTokenDatas[0].chainId, 1);
        // assertEq(decodedTokenDatas[1].id, 2002);
        // assertEq(decodedTokenDatas[1].tokenOwner, address(0x2222222222222222222222222222222222222222));
        // assertEq(decodedTokenDatas[1].chainId, 56);
        // assertEq(decodedTokenDatas[2].id, 3003);
        // assertEq(decodedTokenDatas[2].tokenOwner, address(0x3333333333333333333333333333333333333333));
        // assertEq(decodedTokenDatas[2].chainId, 137);
        // assertEq(decodedAmounts[0], 10 ether);
        // assertEq(decodedAmounts[1], 20 ether);
        // assertEq(decodedAmounts[2], 30 ether);
        // assertEq(totalAmount, 60 ether);

        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](
            100
        );
        uint256[] memory amounts = new uint256[](100);

        for (uint256 i = 0; i < 100; ) {
            tokenDatas[i] = ICashPlus.TokenData({
                id: type(uint256).max - i,
                tokenOwner: address(uint160(i)),
                chainId: uint64(i)
            });
            amounts[i] = i * 10 ether;
            ++i;
        }

        // Encode
        bytes memory encoded = harness.encodePoolData(tokenDatas, amounts);

        // Decode
        (
            ICashPlus.TokenData[] memory decodedTokenDatas,
            uint256[] memory decodedAmounts,
            uint256 totalAmount
        ) = harness.decodePoolData(encoded);

        // Verify
        assertEq(decodedTokenDatas.length, 100);
        assertEq(decodedAmounts.length, 100);
        for (uint256 i = 0; i < 100; ) {
            assertEq(decodedTokenDatas[i].id, tokenDatas[i].id);
            assertEq(decodedTokenDatas[i].tokenOwner, tokenDatas[i].tokenOwner);
            assertEq(decodedTokenDatas[i].chainId, tokenDatas[i].chainId);
            assertEq(decodedAmounts[i], amounts[i]);
            ++i;
        }
    }

    function testEncodeDecode_LargeValues() public view {
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);

        // Test with max values (id is uint256, amount is uint128, chainId is uint64)
        tokenDatas[0] = ICashPlus.TokenData({
            id: type(uint256).max,
            tokenOwner: address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
            chainId: type(uint64).max // Max uint64
        });
        amounts[0] = type(uint128).max; // Amount is truncated to uint128

        bytes memory encoded = harness.encodePoolData(tokenDatas, amounts);

        (
            ICashPlus.TokenData[] memory decodedTokenDatas,
            uint256[] memory decodedAmounts,
            uint256 totalAmount
        ) = harness.decodePoolData(encoded);

        assertEq(decodedTokenDatas[0].id, type(uint256).max);
        assertEq(
            decodedTokenDatas[0].tokenOwner,
            address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
        );
        assertEq(decodedTokenDatas[0].chainId, type(uint64).max);
        assertEq(decodedAmounts[0], type(uint128).max);
        assertEq(totalAmount, type(uint128).max);
    }

    function testCompareWithAbiEncode() public view {
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenDatas[0] = ICashPlus.TokenData({
            id: 1001,
            tokenOwner: address(0x1234567890AbcdEF1234567890aBcdef12345678),
            chainId: 56
        });
        amounts[0] = 100 ether;

        // Compact encoding
        bytes memory compactEncoded = harness.encodePoolData(
            tokenDatas,
            amounts
        );

        // abi.encode for comparison
        bytes memory abiEncoded = abi.encode(tokenDatas, amounts);

        console.log("Compact encoding size:", compactEncoded.length);
        console.log("abi.encode size:", abiEncoded.length);
        console.log(
            "Savings:",
            abiEncoded.length - compactEncoded.length,
            "bytes"
        );
        console.log(
            "Savings percentage:",
            ((abiEncoded.length - compactEncoded.length) * 100) /
                abiEncoded.length,
            "%"
        );

        // Compact should be smaller
        assertLt(
            compactEncoded.length,
            abiEncoded.length,
            "Compact encoding should be smaller"
        );
    }

    function testCompareWithAbiEncode_FiveElements() public view {
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](5);
        uint256[] memory amounts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            tokenDatas[i] = ICashPlus.TokenData({
                id: 1000 + i,
                tokenOwner: address(
                    uint160(0x1111111111111111111111111111111111111111) +
                        uint160(i)
                ),
                chainId: 56
            });
            amounts[i] = (i + 1) * 10 ether;
        }

        bytes memory compactEncoded = harness.encodePoolData(
            tokenDatas,
            amounts
        );
        bytes memory abiEncoded = abi.encode(tokenDatas, amounts);

        console.log("=== 5 Elements ===");
        console.log("Compact encoding size:", compactEncoded.length);
        console.log("abi.encode size:", abiEncoded.length);
        console.log(
            "Savings:",
            abiEncoded.length - compactEncoded.length,
            "bytes"
        );
    }
}
