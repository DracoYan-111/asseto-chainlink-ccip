// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {TokenTransferorPool} from "../src/TokenTransferorPool.sol";

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract DeployTokenTransferorPool is Script {
    uint256 private PRIVATE_KEY;

    // https://docs.chain.link/ccip/directory/testnet/chain/bsc-testnet
    address constant token1 = 0x4013361546efe989Efd4a1242aDD5Ea88915e980;
    address constant rmnProxy1 = 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D;
    address constant router1 = 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f;

    // https://docs.chain.link/ccip/directory/testnet/chain/ethereum-testnet-sepolia
    address constant token2 = 0x734bb43B503Ea50EBE58EB371e34263551cc3d28;
    address constant rmnProxy2 = 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991;
    address constant router2 = 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59;

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        TokenTransferorPool tokenTransferorPoolOne = new TokenTransferorPool{salt: salt}(
            IBurnMintERC20(token1),
            18,
            new address[](0),
            rmnProxy1,
            router1
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(tokenTransferorPoolOne));

        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(PRIVATE_KEY);

        TokenTransferorPool tokenTransferorPoolTwo = new TokenTransferorPool(
            IBurnMintERC20(token2),
            18,
            new address[](0),
            rmnProxy2,
            router2
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(tokenTransferorPoolTwo));
    }
}
