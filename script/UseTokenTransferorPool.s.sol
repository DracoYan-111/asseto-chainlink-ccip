// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TokenTransferorPool} from "../src/TokenTransferorPool.sol";

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract DeployTokenTransferorPool is Script {

    uint256 private PRIVATE_KEY;
    TokenTransferorPool constant tokenTransferorPool = TokenTransferorPool(payable(0x88885cC572f2c0DD980e98D5D36cDF372EcaADD1));

    function run() external {

        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(PRIVATE_KEY);

        uint256 fees = tokenTransferorPool.getRouterFee(
            16015286601757825753,
            vm.addr(PRIVATE_KEY),
            address(0xe2CE4Ba73a987Fe13Aad9E21344C1E471654739F),
            1 ether
        );

        tokenTransferorPool.transferTokensPayNative{value :fees }(
            16015286601757825753,
            vm.addr(PRIVATE_KEY),
            address(0xe2CE4Ba73a987Fe13Aad9E21344C1E471654739F),
            1 ether
        );

        vm.stopBroadcast();
    }
}