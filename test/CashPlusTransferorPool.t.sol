// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import "forge-std/Test.sol";

import {Erc20Token, ICashPlus} from "src/token/Erc20Token.sol";
import {CashPlusTransferorPool} from "src/CashPlusTransferorPool.sol";

import {Upgrades} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/contracts/ccip/CCIPLocalSimulatorFork.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {IRouter} from "@chainlink/contracts-ccip/contracts/interfaces/IRouter.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {RegistryModuleOwnerCustom} from "@chainlink/contracts-ccip/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {ITokenAdminRegistry} from "@chainlink/contracts-ccip/contracts/interfaces/ITokenAdminRegistry.sol";
import {TokenPool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {RateLimiter} from "@chainlink/contracts-ccip/contracts/libraries/RateLimiter.sol";
import {EVM2EVMOnRamp} from "@chainlink/ccip-develop/onRamp/EVM2EVMOnRamp.sol";

// // Local minimal interface for FeeQuoter (avoids Solidity version conflicts)
// import {IFeeQuoterTest} from "./interfaces/IFeeQuoterTest.sol";

contract TestTokenTransferorPool is Test {
    uint256 private PRIVATE_KEY;
    address public deployer;

    // FeeQuoter addresses (will be fetched from OnRamp)
    address public bscEVM2EVMOnRamp =
        0x35C724666ba31632A56Bad4390eb69f206ab60C7;
    address public ethEVM2EVMOnRamp =
        0x948306C220Ac325fa9392A6E601042A3CD0b480d;

    CashPlusTransferorPool bsc_c;
    Erc20Token bsc_myToken;

    CashPlusTransferorPool eth_c;
    Erc20Token eth_myToken;

    uint256 bscFork;
    uint256 ethFork;
    CCIPLocalSimulatorFork public bscCcipLocalSimulatorFork;
    Register.NetworkDetails public bscNetworkDetails;
    CCIPLocalSimulatorFork public ethCcipLocalSimulatorFork;
    Register.NetworkDetails public ethNetworkDetails;

    function setUp() public {
        PRIVATE_KEY = vm.envUint("PRIVATE_KEY");

        ethFork = vm.createFork(vm.rpcUrl("eth-mainnet"));
        bscFork = vm.createFork(vm.rpcUrl("bsc-mainnet"));

        deployer = vm.addr(PRIVATE_KEY);

        vm.selectFork(bscFork);

        // Initialize CCIP Local Simulator for fork testing
        bscCcipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(bscCcipLocalSimulatorFork));

        // BSC Network Details
        bscNetworkDetails = Register.NetworkDetails({
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
        // Register BSC network details with simulator
        bscCcipLocalSimulatorFork.setNetworkDetails(56, bscNetworkDetails);

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
        bsc_c = new CashPlusTransferorPool(
            address(bsc_myToken),
            bsc_myToken.decimals(),
            new address[](0),
            bscNetworkDetails.rmnProxyAddress,
            bscNetworkDetails.routerAddress
        );

        assertEq(bsc_c.owner(), deployer);

        uint256 amount = 1000000 ether;
        bsc_myToken.approve(address(bsc_c), amount);
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);

        tokenDatas[0] = ICashPlus.TokenData({
            id: 1001,
            tokenOwner: deployer,
            chainId: block.chainid
        });
        amounts[0] = amount;

        //bsc_myToken.approve(address(bscNetworkDetails.routerAddress), amount);
        bsc_myToken.mint(deployer, amount, tokenDatas, amounts);
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

        // 切换网络
        vm.selectFork(ethFork);

        // ETH Network Details
        ethNetworkDetails = Register.NetworkDetails({
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
        // Register ETH network details with simulator (simulator is persistent)
        bscCcipLocalSimulatorFork.setNetworkDetails(1, ethNetworkDetails);

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
        eth_c = new CashPlusTransferorPool(
            address(eth_myToken),
            eth_myToken.decimals(),
            new address[](0),
            ethNetworkDetails.rmnProxyAddress,
            ethNetworkDetails.routerAddress
        );

        eth_myToken.approve(address(eth_c), amount);

        //eth_myToken.approve(address(ethNetworkDetails.routerAddress), 1000000 ether);
        eth_myToken.mint(deployer, amount, tokenDatas, amounts);
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

        // Configure BSC Pool
        vm.selectFork(bscFork);
        address EVM2EVMOnRampOwner = EVM2EVMOnRamp(bscEVM2EVMOnRamp).owner();
        vm.startPrank(EVM2EVMOnRampOwner);

        EVM2EVMOnRamp.TokenTransferFeeConfigArgs[]
            memory args = new EVM2EVMOnRamp.TokenTransferFeeConfigArgs[](1);

        args[0].token = address(bsc_myToken); // ──────────────────╮ Token address
        args[0].minFeeUSDCents = 150; //           │ Minimum fee to charge per token transfer, multiples of 0.01 USD
        args[0].maxFeeUSDCents = 4294967295; //           │ Maximum fee to charge per token transfer, multiples of 0.01 USD
        args[0].deciBps = 0; // ─────────────────╯ Basis points charged on token transfers, multiples of 0.1bps, or 1e-5
        args[0].destGasOverhead = 140000; // ─────────╮ Gas charged to execute the token transfer on the destination chain
        //                                  │ Extra data availability bytes that are returned from the source pool and sent
        args[0].destBytesOverhead = 8000; //        │ to the destination pool. Must be >= Pool.CCIP_LOCK_OR_BURN_V1_RET_BYTES
        args[0].aggregateRateLimitEnabled = false; // ─╯ Whether this transfer token is to be included in Aggregate Rate Limiting
        EVM2EVMOnRamp(bscEVM2EVMOnRamp).setTokenTransferFeeConfig(
            args,
            new address[](0)
        );
        vm.stopPrank();

        // Configure BSC Pool chain updates (as deployer/pool owner)
        vm.startPrank(deployer);
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
        vm.stopPrank();

        // Configure ETH Pool chain updates
        vm.selectFork(ethFork);
        vm.startPrank(deployer);
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

        // Make all contracts persistent AFTER all configurations are done
        vm.makePersistent(address(bsc_c));
        vm.makePersistent(address(bsc_myToken));
        vm.makePersistent(address(eth_c));
        vm.makePersistent(address(eth_myToken));
    }

    /// @notice Full cross-chain transfer test (requires CCIPLocalSimulatorFork)
    /// @dev Uncomment CCIPLocalSimulatorFork initialization to run this test
    function testCrossChainTransfer() public {
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

        // Route message to destination chain
        bscCcipLocalSimulatorFork.switchChainAndRouteMessage(ethFork);
    }
}
