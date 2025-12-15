// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TokenTransferorPool} from "../src/TokenTransferorPool.sol";

import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {ITokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/interfaces/ITokenAdminRegistry.sol";
import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {Register} from "@chainlink-local/contracts/ccip/CCIPLocalSimulatorFork.sol";

contract DeployTokenTransferorPool is Script {
    uint256 private PRIVATE_KEY;

    TokenTransferorPool constant tokenTransferorPool1 =
        TokenTransferorPool(
            payable(0x25100992Bb97c2DE169cd9d3Db12EaFe72074f38)
        );
    address constant token1 = 0x4013361546efe989Efd4a1242aDD5Ea88915e980;

    Register.NetworkDetails public networkDetails1 =
        Register.NetworkDetails({
            chainSelector: 13264668187771770619,
            routerAddress: 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f,
            linkAddress: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06,
            wrappedNativeAddress: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd,
            ccipBnMAddress: 0x0000000000000000000000000000000000000000,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
            registryModuleOwnerCustomAddress: 0x763685240370758c5ac6C5F7c22AB36684c0570E,
            tokenAdminRegistryAddress: 0xF8f2A4466039Ac8adf9944fD67DBb3bb13888f2B
        });

    TokenTransferorPool constant tokenTransferorPool2 =
        TokenTransferorPool(
            payable(0x5E4A22cA86b7Cd2D04CBb659F6B8C2f4E65E8B93)
        );
    address constant token2 = 0x734bb43B503Ea50EBE58EB371e34263551cc3d28;

    Register.NetworkDetails public networkDetails2 =
        Register.NetworkDetails({
            chainSelector: 16015286601757825753,
            routerAddress: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            wrappedNativeAddress: 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534,
            ccipBnMAddress: 0x0000000000000000000000000000000000000000,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991,
            registryModuleOwnerCustomAddress: 0x62e731218d0D47305aba2BE3751E7EE9E5520790,
            tokenAdminRegistryAddress: 0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82
        });

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        // token注册
        RegistryModuleOwnerCustom(
            networkDetails1.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(token1));
        ITokenAdminRegistry(networkDetails1.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token1));
        ITokenAdminRegistry(networkDetails1.tokenAdminRegistryAddress).setPool(
            address(token1),
            address(tokenTransferorPool1)
        );
    
        TokenPool.ChainUpdate[]
            memory chainsToAdd1 = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses1 = new bytes[](1);
        poolAddresses1[0] = abi.encode(address(tokenTransferorPool2));
        chainsToAdd1[0] = TokenPool.ChainUpdate({
            remoteChainSelector: networkDetails2.chainSelector,
            remotePoolAddresses: poolAddresses1,
            remoteTokenAddress: abi.encode(address(token2)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        tokenTransferorPool1.applyChainUpdates(new uint64[](0), chainsToAdd1);

        vm.stopBroadcast();

        vm.createSelectFork("eth-sepolia");
        vm.startBroadcast(PRIVATE_KEY);

        // token注册
        RegistryModuleOwnerCustom(
            networkDetails2.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(token2));
        ITokenAdminRegistry(networkDetails2.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token2));
        ITokenAdminRegistry(networkDetails2.tokenAdminRegistryAddress).setPool(
            address(token2),
            address(tokenTransferorPool2)
        );

        TokenPool.ChainUpdate[]
            memory chainsToAdd2 = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses2 = new bytes[](1);
        poolAddresses2[0] = abi.encode(address(tokenTransferorPool1));
        chainsToAdd2[0] = TokenPool.ChainUpdate({
            remoteChainSelector: networkDetails1.chainSelector,
            remotePoolAddresses: poolAddresses2,
            remoteTokenAddress: abi.encode(address(token1)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        tokenTransferorPool2.applyChainUpdates(new uint64[](0), chainsToAdd2);
        vm.stopBroadcast();
    }
}
