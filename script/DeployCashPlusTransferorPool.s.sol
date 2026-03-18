// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {CashPlusTransferorPool} from "../src/CashPlusTransferorPool.sol";

contract DeployCashPlusTransferorPool is Script {
    uint256 private PRIVATE_KEY;

    // https://docs.chain.link/ccip/directory/mainnet/chain/bsc-mainnet
    address constant token1 = 0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2; // TODO: Replace with actual CashPlus token address on BSC
    address constant rmnProxy1 = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D;
    address constant router1 = 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f;

    // https://docs.chain.link/ccip/directory/mainnet/chain/mainnet
    address constant token2 = 0xbc0E5Af03b41FEB5ec5968Ddd324f3eC48017138; // TODO: Replace with actual CashPlus token address on ETH
    address constant rmnProxy2 = 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991;
    address constant router2 = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        CashPlusTransferorPool cashPlusTransferorPool1 = new CashPlusTransferorPool(
                token1,
                18,
                new address[](0),
                rmnProxy1,
                router1
            );

        vm.stopBroadcast();

        console2.log(
            "BSC CashPlusTransferorPool:",
            address(cashPlusTransferorPool1)
        );

        vm.createSelectFork("eth-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        CashPlusTransferorPool cashPlusTransferorPool2 = new CashPlusTransferorPool(
                token2,
                18,
                new address[](0),
                rmnProxy2,
                router2
            );

        vm.stopBroadcast();

        console2.log(
            "ETH CashPlusTransferorPool:",
            address(cashPlusTransferorPool2)
        );
    }
}
