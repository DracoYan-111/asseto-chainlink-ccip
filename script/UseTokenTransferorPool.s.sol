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
            payable(0xEB322952C9Ba0E204a1ab341Fc18832A9700D54a)
        );
    address constant token1 = 0x1775504c5873e179Ea2f8ABFcE3861EC74D159bc;

    Register.NetworkDetails public networkDetails1 =
        Register.NetworkDetails({
            chainSelector: 11344663589394136015,
            routerAddress: 0x34B03Cb9086d7D758AC55af71584F81A598759FE,
            linkAddress: 0x404460C6A5EdE2D891e8297795264fDe62ADBB75,
            wrappedNativeAddress: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c,
            ccipBnMAddress: 0x0000000000000000000000000000000000000000,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0x9e09697842194f77d315E0907F1Bda77922e8f84,
            registryModuleOwnerCustomAddress: 0x47Db76c9c97F4bcFd54D8872FDb848Cab696092d,
            tokenAdminRegistryAddress: 0x736Fd8660c443547a85e4Eaf70A49C1b7Bb008fc
        });

    TokenTransferorPool constant tokenTransferorPool2 =
        TokenTransferorPool(
            payable(0xEB322952C9Ba0E204a1ab341Fc18832A9700D54a)
        );
    address constant token2 = 0x498D9329555471bF6073A5f2D047F746d522A373;

    Register.NetworkDetails public networkDetails2 =
        Register.NetworkDetails({
            chainSelector: 5009297550715157269,
            routerAddress: 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D,
            linkAddress: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            wrappedNativeAddress: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            ccipBnMAddress: 0x0000000000000000000000000000000000000000,
            ccipLnMAddress: 0x0000000000000000000000000000000000000000,
            rmnProxyAddress: 0x411dE17f12D1A34ecC7F45f49844626267c75e81,
            registryModuleOwnerCustomAddress: 0x4855174E9479E211337832E109E7721d43A4CA64,
            tokenAdminRegistryAddress: 0xb22764f98dD05c789929716D677382Df22C05Cb6
        });

    function run() external {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork("bsc-mainnet");
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

        vm.createSelectFork("eth-mainnet");
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

        // 转移所有权
        // uint256 privateKey2 = vm.envUint("PRIVATE_KEY2");
        // address owner = vm.addr(privateKey2);

        // tokenTransferorPool1.transferOwnership(owner);
        // console2.log("owner", tokenTransferorPool1.owner());

        // vm.stopBroadcast();

        // vm.startBroadcast(privateKey2);

        // tokenTransferorPool2.acceptOwnership();
        // console2.log("owner", tokenTransferorPool2.owner());

        // vm.stopBroadcast();


        // uint256 privateKey2 = vm.envUint("PRIVATE_KEY2");
        // vm.startBroadcast(privateKey2);

        // // 批准 tokenTransferorPool1 花费 token1
        // IERC20(token1).approve(address(tokenTransferorPool1), 0.02 ether);

        // // 获取手续费
        // uint256 fees = tokenTransferorPool1.getRouterFee(
        //     networkDetails2.chainSelector,
        //     vm.addr(privateKey2),
        //     address(token1),
        //     0.02 ether
        // );
        // console2.log("fees", fees);

        // bytes32 messageId = tokenTransferorPool1.transferTokensPayNative{
        //     value: fees
        // }(
        //     networkDetails2.chainSelector,
        //     vm.addr(privateKey2),
        //     address(token1),
        //     0.02 ether
        // );
        // console2.logBytes32(messageId);

        // vm.stopBroadcast();
    }
}
