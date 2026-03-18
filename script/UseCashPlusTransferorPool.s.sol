// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CashPlusTransferorPool} from "../src/CashPlusTransferorPool.sol";

import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {ITokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/interfaces/ITokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {Register} from "@chainlink-local/contracts/ccip/CCIPLocalSimulatorFork.sol";

contract UseCashPlusTransferorPool is Script {
    uint256 private PRIVATE_KEY;

    // TODO: Replace with actual deployed CashPlusTransferorPool addresses
    CashPlusTransferorPool constant cashPlusTransferorPool1 =
        CashPlusTransferorPool(
            payable(0xBAA5FF65B0b8b0517d775a1c96DfC57661AFF1f9)
        );
    address constant token1 = 0x9EA9cd205783F08700d2A12C325FC4e1BF8e99a2; // TODO: Replace with actual CashPlus token address on BSC

    // BSC Network Details
    Register.NetworkDetails public networkDetails1 =
        Register.NetworkDetails({
            chainSelector: 13264668187771770619,
            routerAddress: 0xE1053aE1857476f36A3C62580FF9b016E8EE8F6f,
            linkAddress: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06,
            wrappedNativeAddress: 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd,
            ccipBnMAddress: 0x0000000000000000000000000000000000000000,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0xA8C0c11bf64AF62CDCA6f93D3769B88BdD7cb93D,
            registryModuleOwnerCustomAddress: 0x8Cd87FeAC14D69D770E67Bedf029e6fd3F33D0C7,
            tokenAdminRegistryAddress: 0xF8f2A4466039Ac8adf9944fD67DBb3bb13888f2B
        });

    // TODO: Replace with actual deployed CashPlusTransferorPool addresses
    CashPlusTransferorPool constant cashPlusTransferorPool2 =
        CashPlusTransferorPool(
            payable(0xF5794060D7756eBC046B0b2e1c3771E477909818)
        );
    address constant token2 = 0xbc0E5Af03b41FEB5ec5968Ddd324f3eC48017138; // TODO: Replace with actual CashPlus token address on ETH

    // ETH Network Details
    Register.NetworkDetails public networkDetails2 =
        Register.NetworkDetails({
            chainSelector: 16015286601757825753,
            routerAddress: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            wrappedNativeAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            ccipBnMAddress: 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0xba3f6251de62dED61Ff98590cB2fDf6871FbB991,
            registryModuleOwnerCustomAddress: 0xa3c796d480638d7476792230da1E2ADa86e031b0,
            tokenAdminRegistryAddress: 0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82
        });

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");
        // ========== BSC Configuration ==========

        vm.createSelectFork("bsc-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        // Register token with CCIP
        RegistryModuleOwnerCustom(
            networkDetails1.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(token1));
        ITokenAdminRegistry(networkDetails1.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token1));
        ITokenAdminRegistry(networkDetails1.tokenAdminRegistryAddress).setPool(
            address(token1),
            address(cashPlusTransferorPool1)
        );

        // Configure chain updates for BSC pool
        TokenPool.ChainUpdate[]
            memory chainsToAdd1 = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses1 = new bytes[](1);
        poolAddresses1[0] = abi.encode(address(cashPlusTransferorPool2));
        chainsToAdd1[0] = TokenPool.ChainUpdate({
            remoteChainSelector: networkDetails2.chainSelector,
            remotePoolAddresses: poolAddresses1,
            remoteTokenAddress: abi.encode(address(token2)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        cashPlusTransferorPool1.applyChainUpdates(
            new uint64[](0),
            chainsToAdd1
        );

        vm.stopBroadcast();

        // ========== ETH Configuration ==========
        vm.createSelectFork("eth-testnet");
        vm.startBroadcast(PRIVATE_KEY);

        // Register token with CCIP
        RegistryModuleOwnerCustom(
            networkDetails2.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(token2));
        ITokenAdminRegistry(networkDetails2.tokenAdminRegistryAddress)
            .acceptAdminRole(address(token2));
        ITokenAdminRegistry(networkDetails2.tokenAdminRegistryAddress).setPool(
            address(token2),
            address(cashPlusTransferorPool2)
        );

        // Configure chain updates for ETH pool
        TokenPool.ChainUpdate[]
            memory chainsToAdd2 = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses2 = new bytes[](1);
        poolAddresses2[0] = abi.encode(address(cashPlusTransferorPool1));
        chainsToAdd2[0] = TokenPool.ChainUpdate({
            remoteChainSelector: networkDetails1.chainSelector,
            remotePoolAddresses: poolAddresses2,
            remoteTokenAddress: abi.encode(address(token1)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        cashPlusTransferorPool2.applyChainUpdates(
            new uint64[](0),
            chainsToAdd2
        );

        vm.stopBroadcast();
    }

    /// @notice Example function to transfer tokens cross-chain
    /// @dev Uncomment and update addresses to use
    function transferTokens() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-mainnet");
        vm.startBroadcast(PRIVATE_KEY);

        uint256 amount = 100 ether;

        // Approve pool to spend tokens
        IERC20(token1).approve(address(cashPlusTransferorPool1), amount);

        // Get fee estimate
        uint256 fees = cashPlusTransferorPool1.getRouterFee(
            networkDetails2.chainSelector,
            vm.addr(PRIVATE_KEY),
            address(token1),
            amount
        );
        console2.log("CCIP fees:", fees);

        // Transfer tokens to ETH
        bytes32 messageId = cashPlusTransferorPool1.transferTokensPayNative{
            value: fees
        }(
            networkDetails2.chainSelector,
            vm.addr(PRIVATE_KEY),
            address(token1),
            amount
        );
        console2.log("Message ID:");
        console2.logBytes32(messageId);

        vm.stopBroadcast();
    }
}
