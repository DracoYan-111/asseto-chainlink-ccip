// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Erc20Token} from "../../src/token/Erc20Token.sol";

contract DeployErc20Token is Script {
    uint256 private PRIVATE_KEY;

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(PRIVATE_KEY);

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        address proxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (deployer, deployer, deployer)
            )
        );

        vm.stopBroadcast();

        console2.log("Implementation:", address(proxy));
        console2.log("decimals:", Erc20Token(proxy).decimals());
    }
}
