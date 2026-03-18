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

contract TestTokenTransferorPool is Test {
    uint256 private PRIVATE_KEY;
    address public deployer;

    // EVM2EVMOnRamp address (used to configure token transfer fees)
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

        // Create forks
        ethFork = vm.createFork(vm.rpcUrl("eth-mainnet"));
        bscFork = vm.createFork(vm.rpcUrl("bsc-mainnet"));

        deployer = vm.addr(PRIVATE_KEY);

        vm.selectFork(bscFork);

        // Initialize CCIP local simulator for fork testing
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
        // Register BSC network details to the simulator
        bscCcipLocalSimulatorFork.setNetworkDetails(56, bscNetworkDetails);

        // ========== BSC Token Setup ==========
        address bscProxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (deployer, deployer, deployer)
            )
        );

        bsc_myToken = Erc20Token(bscProxy);

        vm.startPrank(deployer);

        // BSC Pool Setup
        bsc_c = new CashPlusTransferorPool(
            address(bsc_myToken),
            bsc_myToken.decimals(),
            new address[](0),
            bscNetworkDetails.rmnProxyAddress,
            bscNetworkDetails.routerAddress
        );

        assertEq(bsc_c.owner(), deployer);

        // Prepare 100 TokenData, each representing 1 ether of \"colored\" token
        uint256 amount = 100 ether;
        bsc_myToken.approve(address(bsc_c), amount);

        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](
            amount / 1 ether
        );
        uint256[] memory amounts = new uint256[](amount / 1 ether);
        for (uint256 i = 0; i < (amount / 1 ether); ++i) {
            tokenDatas[i] = ICashPlus.TokenData({
                id: type(uint256).max - i, // Unique ID
                tokenOwner: deployer,
                chainId: block.chainid
            });
            amounts[i] = 1 ether;
        }

        // Mint tokens and grant minter role to the pool
        bsc_myToken.mint(deployer, amount, tokenDatas, amounts);
        bsc_myToken.grantRole(bsc_myToken.MINTER_ROLE(), address(bsc_c));

        // Register Token to CCIP (via TokenAdminRegistry)
        RegistryModuleOwnerCustom(
            bscNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(bsc_myToken));
        ITokenAdminRegistry(bscNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(bsc_myToken));
        ITokenAdminRegistry(bscNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(bsc_myToken), address(bsc_c));

        vm.stopPrank();
        assertEq(bsc_myToken.balanceOf(deployer), 100 ether);

        // ========== Switch to ETH Network ==========
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
        // Register ETH network details to the simulator (simulator is persistent)
        bscCcipLocalSimulatorFork.setNetworkDetails(1, ethNetworkDetails);

        // ========== ETH Token Setup ==========
        address ethProxy = Upgrades.deployUUPSProxy(
            "Erc20Token.sol:Erc20Token",
            abi.encodeCall(
                Erc20Token.initialize,
                (deployer, deployer, deployer)
            )
        );
        eth_myToken = Erc20Token(ethProxy);

        vm.startPrank(deployer);

        // ETH Pool Setup
        eth_c = new CashPlusTransferorPool(
            address(eth_myToken),
            eth_myToken.decimals(),
            new address[](0),
            ethNetworkDetails.rmnProxyAddress,
            ethNetworkDetails.routerAddress
        );

        eth_myToken.approve(address(eth_c), amount);

        // Do not mint initial tokens on ETH chain, waiting for cross-chain transfer
        eth_myToken.grantRole(eth_myToken.MINTER_ROLE(), address(eth_c));

        // Register Token to CCIP
        RegistryModuleOwnerCustom(
            ethNetworkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaGetCCIPAdmin(address(eth_myToken));
        ITokenAdminRegistry(ethNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(eth_myToken));
        ITokenAdminRegistry(ethNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(eth_myToken), address(eth_c));

        vm.stopPrank();
        assertEq(eth_myToken.balanceOf(deployer), 0);

        // ========== Configure BSC Pool Token Transfer Fees ==========
        vm.selectFork(bscFork);
        address EVM2EVMOnRampOwner = EVM2EVMOnRamp(bscEVM2EVMOnRamp).owner();
        vm.startPrank(EVM2EVMOnRampOwner);

        EVM2EVMOnRamp.TokenTransferFeeConfigArgs[]
            memory args = new EVM2EVMOnRamp.TokenTransferFeeConfigArgs[](1);

        args[0].token = address(bsc_myToken); // Token address
        args[0].minFeeUSDCents = 150; // Minimum fee (multiples of 0.01 USD)
        args[0].maxFeeUSDCents = 4294967295; // Maximum fee
        args[0].deciBps = 0; // Basis point rate (multiples of 0.1bps)
        args[0].destGasOverhead = 140000; // Destination chain execution gas overhead
        args[0].destBytesOverhead = 8000; // Destination chain data availability byte overhead (must be >= Pool.CCIP_LOCK_OR_BURN_V1_RET_BYTES)
        args[0].aggregateRateLimitEnabled = false; // Whether to enable aggregate rate limit

        EVM2EVMOnRamp(bscEVM2EVMOnRamp).setTokenTransferFeeConfig(
            args,
            new address[](0)
        );
        vm.stopPrank();

        // ========== Configure BSC Pool Chain Updates (set remote chain info) ==========
        vm.startPrank(deployer);
        TokenPool.ChainUpdate[]
            memory bscChainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory ethPoolAddresses = new bytes[](1);
        ethPoolAddresses[0] = abi.encode(address(eth_c));
        bscChainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: ethNetworkDetails.chainSelector,
            remotePoolAddresses: ethPoolAddresses,
            remoteTokenAddress: abi.encode(address(eth_myToken)),
            outboundRateLimiterConfig: RateLimiter.Config(false, 0, 0), // Disable outbound rate limiting
            inboundRateLimiterConfig: RateLimiter.Config(false, 0, 0) // Disable inbound rate limiting
        });
        bsc_c.applyChainUpdates(new uint64[](0), bscChainsToAdd);
        vm.stopPrank();

        // ========== Configure ETH Pool Chain Updates ==========
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

        // ========== IMPORTANT: Make contracts persistent only after all configurations are done ==========
        // vm.makePersistent saves the state snapshot at the time of calling
        // If called before configuration is complete, the pool on the destination chain will not have source chain config
        vm.makePersistent(address(bsc_c));
        vm.makePersistent(address(bsc_myToken));
        vm.makePersistent(address(eth_c));
        vm.makePersistent(address(eth_myToken));
    }

    /// @notice Complete cross-chain transfer test
    function testCrossChainTransfer() public {
        vm.selectFork(bscFork);
        vm.deal(deployer, 10 ether);
        vm.startPrank(deployer);

        // Get CCIP fee
        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            100 ether
        );
        console.log("CCIP fee:", fee);

        // Execute cross-chain transfer (BSC -> ETH)
        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            100 ether
        );

        console.log("================> Transfer initiator:", msg.sender);

        // Route message to destination chain (simulate CCIP message delivery)
        bscCcipLocalSimulatorFork.switchChainAndRouteMessage(ethFork);
    }

    function testTransferTokensPayNativeRevertsForNonWhitelistedCaller() public {
        vm.selectFork(bscFork);

        address user = makeAddr("nonWhitelistedUser");

        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            1 ether
        );

        vm.deal(user, fee);
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                CashPlusTransferorPool.CallerNotWhitelisted.selector,
                user
            )
        );
        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            1 ether
        );
    }

    function testTransferTokensPayNativeAllowsWhitelistedCaller() public {
        vm.selectFork(bscFork);

        address user = makeAddr("whitelistedUser");

        // Owner whitelists user
        vm.prank(deployer);
        address[] memory users = new address[](1);
        users[0] = user;
        bsc_c.setWhitelistBatch(users, true);

        // Mint tokens to user so they can transfer
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenDatas[0] = ICashPlus.TokenData({
            id: 12345,
            tokenOwner: user,
            chainId: block.chainid
        });
        amounts[0] = 1 ether;

        vm.startPrank(deployer);
        bsc_myToken.mint(user, 1 ether, tokenDatas, amounts);
        vm.stopPrank();

        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            user,
            address(bsc_myToken),
            1 ether
        );

        vm.deal(user, fee);
        vm.startPrank(user);
        bsc_myToken.approve(address(bsc_c), 1 ether);
        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            user,
            address(bsc_myToken),
            1 ether
        );
        vm.stopPrank();
    }

    function testTransferTokensPayNativeAllowsNonWhitelistedCallerWhenDisabled()
        public
    {
        vm.selectFork(bscFork);

        address user = makeAddr("nonWhitelistedButDisabled");

        // Owner disables whitelist enforcement
        vm.prank(deployer);
        bsc_c.setWhitelistEnabled(false);

        // Mint tokens to user so they can transfer
        ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenDatas[0] = ICashPlus.TokenData({
            id: 54321,
            tokenOwner: user,
            chainId: block.chainid
        });
        amounts[0] = 1 ether;

        vm.startPrank(deployer);
        bsc_myToken.mint(user, 1 ether, tokenDatas, amounts);
        vm.stopPrank();

        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            user,
            address(bsc_myToken),
            1 ether
        );

        vm.deal(user, fee);
        vm.startPrank(user);
        bsc_myToken.approve(address(bsc_c), 1 ether);
        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            user,
            address(bsc_myToken),
            1 ether
        );
        vm.stopPrank();
    }

    /// @notice Test gas usage of cross-chain transfer
    function testCrossChainTransferGasUsage() public {
        vm.selectFork(bscFork);
        vm.deal(deployer, 100 ether);
        vm.startPrank(deployer);

        uint256 transferAmount = 100 ether;
        // BSC typical gas price: 3-5 gwei, using 3 gwei here
        uint256 gasPrice = 3 gwei;
        vm.txGasPrice(gasPrice);

        // Get fee
        uint256 fee = bsc_c.getRouterFee(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            transferAmount
        );

        console.log("=== Cross-chain Gas Usage Analysis ===");
        console.log("Transfer amount:", transferAmount / 1 ether, "tokens");
        console.log("TokenData elements count:", transferAmount / 1 ether);
        console.log("Gas price (gwei):", gasPrice / 1 gwei);

        // Measure gas of source chain operation (including lockOrBurn)
        uint256 gasBefore = gasleft();
        bsc_c.transferTokensPayNative{value: fee}(
            ethNetworkDetails.chainSelector,
            deployer,
            address(bsc_myToken),
            transferAmount
        );
        uint256 gasUsedSource = gasBefore - gasleft();

        vm.stopPrank();

        // Route message and measure destination chain gas
        uint256 gasBeforeDest = gasleft();
        bscCcipLocalSimulatorFork.switchChainAndRouteMessage(ethFork);
        uint256 gasUsedDest = gasBeforeDest - gasleft();

        // Calculate cost (in ETH unit)
        uint256 sourceGasCostWei = gasUsedSource * gasPrice;
        uint256 destGasCostWei = gasUsedDest * gasPrice;
        uint256 totalGasCostWei = sourceGasCostWei + destGasCostWei;
        uint256 totalCostWei = totalGasCostWei + fee;

        console.log("=== Gas Consumption ===");
        console.log("Source chain gas consumption (gas units):", gasUsedSource);
        console.log(
            "Destination chain gas consumption (gas units):",
            gasUsedDest
        );

        console.log("=== Fee Statistics ===");
        _logEthValue("Source chain gas fee", sourceGasCostWei);
        _logEthValue("Destination chain gas fee", destGasCostWei);
        _logEthValue("CCIP fee", fee);
        console.log(unicode"---");
        _logEthValue("Total gas fee", totalGasCostWei);
        _logEthValue("Total consumption (gas + CCIP)", totalCostWei);

        // Verify balance after transfer
        vm.selectFork(ethFork);
        uint256 ethBalance = eth_myToken.balanceOf(deployer);
        console.log(
            "Balance after transfer on ETH chain:",
            ethBalance / 1 ether,
            "tokens"
        );

        // Calculate encoded size comparison
        uint256 encodedDataSize = 2 + (transferAmount / 1 ether) * 76;
        uint256 abiEncodedSize = 32 +
            32 +
            (transferAmount / 1 ether) *
            96 +
            (transferAmount / 1 ether) *
            32;
        console.log("=== Encoded Size Comparison ===");
        console.log("Compact encoded size (bytes):", encodedDataSize);
        console.log("abi.encode size (bytes):", abiEncodedSize);
        console.log("Savings (bytes):", abiEncodedSize - encodedDataSize);
        console.log(
            "Savings percentage (%):",
            ((abiEncodedSize - encodedDataSize) * 100) / abiEncodedSize
        );
    }

    /// @notice Test gas usage of different TokenData amounts
    function testGasUsageByTokenDataCount() public {
        console.log("=== Gas usage of different TokenData amounts ===");

        // BSC typical gas price: 3 gwei
        uint256 gasPrice = 3 gwei;
        vm.txGasPrice(gasPrice);
        console.log("Gas price (gwei):", gasPrice / 1 gwei);

        uint256[] memory testCounts = new uint256[](4);
        testCounts[0] = 1;
        testCounts[1] = 10;
        testCounts[2] = 50;
        testCounts[3] = 100;

        for (uint256 t = 0; t < testCounts.length; t++) {
            uint256 count = testCounts[t];

            // Create specific amounts of tokens for this test
            vm.selectFork(bscFork);
            vm.startPrank(deployer);

            ICashPlus.TokenData[] memory tokenDatas = new ICashPlus.TokenData[](
                count
            );
            uint256[] memory amounts = new uint256[](count);
            uint256 totalAmount = count * 1 ether;

            for (uint256 i = 0; i < count; ++i) {
                tokenDatas[i] = ICashPlus.TokenData({
                    id: 1000000 + t * 1000 + i,
                    tokenOwner: deployer,
                    chainId: block.chainid
                });
                amounts[i] = 1 ether;
            }

            // Mint additional tokens for this test
            bsc_myToken.mint(deployer, totalAmount, tokenDatas, amounts);
            bsc_myToken.approve(address(bsc_c), totalAmount);

            vm.deal(deployer, 10 ether);

            uint256 fee = bsc_c.getRouterFee(
                ethNetworkDetails.chainSelector,
                deployer,
                address(bsc_myToken),
                totalAmount
            );

            uint256 gasBefore = gasleft();
            bsc_c.transferTokensPayNative{value: fee}(
                ethNetworkDetails.chainSelector,
                deployer,
                address(bsc_myToken),
                totalAmount
            );
            uint256 gasUsed = gasBefore - gasleft();

            // Calculate cost (in ETH unit)
            uint256 gasCostWei = gasUsed * gasPrice;
            uint256 totalCostWei = gasCostWei + fee;

            console.log("---");
            console.log("TokenData amount:", count);
            console.log("Source chain gas consumption (gas units):", gasUsed);
            _logEthValue("Source chain gas fee", gasCostWei);
            _logEthValue("CCIP fee", fee);
            _logEthValue("Total consumption", totalCostWei);
            console.log("Encoded data size:", 2 + count * 76, "bytes");

            vm.stopPrank();

            // Route to destination chain
            bscCcipLocalSimulatorFork.switchChainAndRouteMessage(ethFork);
        }
    }

    /// @notice Helper function: output value in ETH (showing integer and fractional parts)
    function _logEthValue(string memory label, uint256 weiValue) internal pure {
        uint256 intPart = weiValue / 1 ether;
        uint256 decPart = (weiValue % 1 ether) / 1e12; // Keep 6 decimal places (unit: 1e-6 ETH)
        // Format: label (ETH): integer part . fractional part (6 places)
        console.log(
            string.concat(
                label,
                " (ETH): ",
                vm.toString(intPart),
                ".",
                _padZeros(decPart, 6)
            )
        );
    }

    /// @notice Helper function: pad zeros before number
    function _padZeros(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory) {
        string memory str = vm.toString(value);
        bytes memory strBytes = bytes(str);
        if (strBytes.length >= length) {
            return str;
        }
        bytes memory result = new bytes(length);
        uint256 padding = length - strBytes.length;
        for (uint256 i = 0; i < padding; i++) {
            result[i] = "0";
        }
        for (uint256 i = 0; i < strBytes.length; i++) {
            result[padding + i] = strBytes[i];
        }
        return string(result);
    }
}
