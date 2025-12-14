// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";
import {Erc20Token} from "../../src/token/Erc20Token.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {ITokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/interfaces/ITokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";

contract UseErc20Token is Script {

    uint256 private PRIVATE_KEY;

    TokenPool constant tokenTransferorPool = TokenPool(0x4509a5E04b8B53cBE636b8bcEaAfDFb1D3936EEC);
    Erc20Token constant erc20Token = Erc20Token(0xCb36aBbc170B4A2cEe4e38Daf112096abcd52A0B);
    RegistryModuleOwnerCustom constant registryModuleOwnerCustom = RegistryModuleOwnerCustom(0x62e731218d0D47305aba2BE3751E7EE9E5520790);
    ITokenAdminRegistry constant tokenAdminRegistry = ITokenAdminRegistry(0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82);
    

    address constant otherTokenTransferorPool = address(0x88885cC572f2c0DD980e98D5D36cDF372EcaADD1);
    address constant otherErc20Token = address(0xe2CE4Ba73a987Fe13Aad9E21344C1E471654739F);
    uint64 constant otherRemoteChainSelector = 13264668187771770619;
    function run() external {

        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(PRIVATE_KEY);
        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(PRIVATE_KEY);


        erc20Token.approve(address(tokenTransferorPool), 1000000 ether);
        erc20Token.mint(deployer, 1000000 ether);
        erc20Token.grantRole(erc20Token.MINTER_ROLE(),address(tokenTransferorPool));

        // token注册
        registryModuleOwnerCustom.registerAdminViaGetCCIPAdmin(address(erc20Token));
        tokenAdminRegistry.acceptAdminRole(address(erc20Token));
        tokenAdminRegistry.setPool(address(erc20Token), address(tokenTransferorPool));
       

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses = new bytes[](1);
        poolAddresses[0] = abi.encode(otherTokenTransferorPool);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: otherRemoteChainSelector,
            remotePoolAddresses: poolAddresses,
            remoteTokenAddress: abi.encode(otherErc20Token),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        tokenTransferorPool.applyChainUpdates(new uint64[](0), chainsToAdd);

        vm.stopBroadcast();

    }
}