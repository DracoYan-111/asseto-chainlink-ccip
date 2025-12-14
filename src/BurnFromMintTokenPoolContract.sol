// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import {BurnFromMintTokenPool} from "@chainlink/contracts-ccip/contracts/pools/BurnFromMintTokenPool.sol";

contract BurnFromMintTokenPoolContract is BurnFromMintTokenPool { 
    constructor(
        IBurnMintERC20 token,
        uint8 localTokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) BurnFromMintTokenPool(token, localTokenDecimals, allowlist, rmnProxy, router) {}

    
}
