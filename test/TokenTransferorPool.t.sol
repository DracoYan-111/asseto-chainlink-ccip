// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {Erc20Token} from "src/token/Erc20Token.sol";
import {TokenTransferorPool} from "src/TokenTransferorPool.sol";

import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {IBurnMintERC20} from "@chainlink/contracts/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/contracts/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {ITokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/interfaces/ITokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";

contract TestTokenTransferorPool is Test {
    uint256 private PRIVATE_KEY;
    address public deployer;

    TokenTransferorPool bsc_c;
    Erc20Token bsc_myToken;

    TokenTransferorPool eth_c;
    Erc20Token eth_myToken;

    uint256 bscFork;
    uint256 ethFork;
    CCIPLocalSimulatorFork public bscCcipLocalSimulatorFork;
    Register.NetworkDetails public bscNetworkDetails;
    CCIPLocalSimulatorFork public ethCcipLocalSimulatorFork;
    Register.NetworkDetails public ethNetworkDetails;

    function setUp() public {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        ethFork = vm.createFork(vm.rpcUrl("eth-sepolia"));
        bscFork = vm.createFork(vm.rpcUrl("bsc-testnet"));

        deployer = vm.addr(PRIVATE_KEY);

        vm.selectFork(bscFork);
        // ccip属性
        bscCcipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        bscCcipLocalSimulatorFork.setNetworkDetails(
            bscFork,
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
            })
        );
        vm.makePersistent(address(bscCcipLocalSimulatorFork));

        bscNetworkDetails = bscCcipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        assertEq(block.chainid, 56);

        // token设置
        address bscProxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (deployer, deployer, deployer)
            )
        );

        bsc_myToken = Erc20Token(bscProxy);

        vm.startPrank(deployer);
        // pool设置
        bsc_c = new TokenTransferorPool(
            IBurnMintERC20(address(bsc_myToken)),
            bsc_myToken.decimals(),
            new address[](0),
            bscNetworkDetails.rmnProxyAddress,
            bscNetworkDetails.routerAddress
        );

        assertEq(bsc_c.owner(), deployer);

        bsc_myToken.approve(address(bsc_c), 1000000 ether);
        //bsc_myToken.approve(address(bscNetworkDetails.routerAddress), 1000000 ether);
        bsc_myToken.mint(deployer, 1000000 ether);
        bsc_myToken.grantRole(bsc_myToken.MINTER_ROLE(), address(bsc_c));

        // token注册
        RegistryModuleOwnerCustom(
            bscNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(bsc_myToken));
        ITokenAdminRegistry(bscNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(bsc_myToken));
        ITokenAdminRegistry(bscNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(bsc_myToken), address(bsc_c));

        vm.stopPrank();
        assertEq(bsc_myToken.balanceOf(deployer), 1000000 ether);

        vm.makePersistent(address(bsc_c));
        vm.makePersistent(address(bsc_myToken));

        // 切换网络
        vm.selectFork(ethFork);

        ethCcipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        ethCcipLocalSimulatorFork.setNetworkDetails(
            ethFork,
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
            })
        );
        vm.makePersistent(address(ethCcipLocalSimulatorFork));

        ethNetworkDetails = ethCcipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        assertEq(block.chainid, 1);

        // token设置
        address ethProxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (deployer, deployer, deployer)
            )
        );
        eth_myToken = Erc20Token(ethProxy);

        vm.startPrank(deployer);
        // pool设置
        eth_c = new TokenTransferorPool(
            IBurnMintERC20(address(eth_myToken)),
            eth_myToken.decimals(),
            new address[](0),
            ethNetworkDetails.rmnProxyAddress,
            ethNetworkDetails.routerAddress
        );

        eth_myToken.approve(address(eth_c), 1000000 ether);
        //eth_myToken.approve(address(ethNetworkDetails.routerAddress), 1000000 ether);
        eth_myToken.mint(deployer, 1000000 ether);
        eth_myToken.grantRole(eth_myToken.MINTER_ROLE(), address(eth_c));

        // token注册
        RegistryModuleOwnerCustom(
            ethNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(eth_myToken));
        ITokenAdminRegistry(ethNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(eth_myToken));
        ITokenAdminRegistry(ethNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(eth_myToken), address(eth_c));

        vm.stopPrank();
        assertEq(eth_myToken.balanceOf(deployer), 1000000 ether);

        vm.makePersistent(address(eth_c));
        vm.makePersistent(address(eth_myToken));

        // Configure BSC Pool
        vm.startPrank(deployer);
        vm.selectFork(bscFork);
        TokenPool.ChainUpdate[]
            memory bscChainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory ethPoolAddresses = new bytes[](1);
        ethPoolAddresses[0] = abi.encode(address(eth_c));
        bscChainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: ethNetworkDetails.chainSelector,
            remotePoolAddresses: ethPoolAddresses,
            remoteTokenAddress: abi.encode(address(eth_myToken)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        bsc_c.applyChainUpdates(new uint64[](0), bscChainsToAdd);

        // Configure ETH Pool
        vm.selectFork(ethFork);
        TokenPool.ChainUpdate[]
            memory ethChainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory bscPoolAddresses = new bytes[](1);
        bscPoolAddresses[0] = abi.encode(address(bsc_c));
        ethChainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: bscNetworkDetails.chainSelector,
            remotePoolAddresses: bscPoolAddresses,
            remoteTokenAddress: abi.encode(address(bsc_myToken)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0),
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0)
        });
        eth_c.applyChainUpdates(new uint64[](0), ethChainsToAdd);
        vm.stopPrank();
    }

    function testDeploy() public {
        vm.selectFork(bscFork);

        vm.deal(deployer, 10 ether);

        vm.startPrank(deployer);

        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            100 ether
        );
        console.log("fee", fee);

        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            100 ether
        );

        console.log("================>", msg.sender);

        // 将消息路由到目标链
        bscCcipLocalSimulatorFork.switchChainAndRouteMessage(ethFork);
    }
}
