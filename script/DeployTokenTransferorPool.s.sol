// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TokenTransferorPool} from "../src/TokenTransferorPool.sol";

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract DeployTokenTransferorPool is Script {

    uint256 private PRIVATE_KEY ;

    function run() external {

        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        TokenTransferorPool tokenTransferorPoolOne = new TokenTransferorPool(
            IBurnMintERC20(0xe2CE4Ba73a987Fe13Aad9E21344C1E471654739F),
            18,
            new address[](0),
            0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
            0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(tokenTransferorPoolOne));

        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(PRIVATE_KEY);

        TokenTransferorPool tokenTransferorPoolTwo = new TokenTransferorPool(
            IBurnMintERC20(0xCb36aBbc170B4A2cEe4e38Daf112096abcd52A0B),
            18,
            new address[](0),
            0xba3f6251de62dED61Ff98590cB2fDf6871FbB991,
            0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(tokenTransferorPoolTwo));
    }
}