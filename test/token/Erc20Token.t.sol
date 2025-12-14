// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Erc20Token} from "src/token/Erc20Token.sol";

contract TestMyToken is Test {
    Erc20Token myToken;

    uint256 private PRIVATE_KEY;

    address public defaultAdmin;

    function setUp() public {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");
        defaultAdmin = vm.addr(PRIVATE_KEY);

        address proxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (defaultAdmin, defaultAdmin, defaultAdmin)
            )
        );

        myToken = Erc20Token(proxy);
    }

    function testMint() public {
        uint256 amount = 100;
        vm.prank(defaultAdmin);
        myToken.mint(defaultAdmin, amount);
        assertEq(myToken.balanceOf(defaultAdmin), amount);
    }

    function testBurn() public {
        uint256 amount = 100;
        vm.prank(defaultAdmin);
        myToken.mint(defaultAdmin, amount);
        assertEq(myToken.balanceOf(defaultAdmin), amount);

        vm.prank(defaultAdmin);
        myToken.approve(address(this), amount);

        myToken.burnFrom(defaultAdmin, amount);
        assertEq(myToken.balanceOf(defaultAdmin), 0);
    }
}
