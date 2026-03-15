// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {TokenTransferorPool} from "../src/TokenTransferorPool.sol";

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract DeployTokenTransferorPool is Script {
    uint256 private PRIVATE_KEY;

    // https://docs.chain.link/ccip/directory/mainnet/chain/bsc-mainnet
    address constant token1 = 0x1775504c5873e179Ea2f8ABFcE3861EC74D159bc;
    address constant rmnProxy1 = 0x9e09697842194f77d315E0907F1Bda77922e8f84;
    address constant router1 = 0x34B03Cb9086d7D758AC55af71584F81A598759FE;

    // https://docs.chain.link/ccip/directory/mainnet/chain/mainnet
    address constant token2 = 0x498D9329555471bF6073A5f2D047F746d522A373;
    address constant rmnProxy2 = 0x411dE17f12D1A34ecC7F45f49844626267c75e81;
    address constant router2 = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D;

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-mainnet");
        vm.startBroadcast(PRIVATE_KEY);

        TokenTransferorPool tokenTransferorPoolOne = new TokenTransferorPool(
            IBurnMintERC20(token1),
            18,
            new address[](0),
            rmnProxy1,
            router1
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(tokenTransferorPoolOne));

        vm.createSelectFork("eth-mainnet");
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
