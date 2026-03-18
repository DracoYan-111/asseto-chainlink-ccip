// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20, TokenPool, Pool} from "@chainlink/contracts-ccip/contracts/pools/TokenPool.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {SafeERC20} from "@openzeppelin/contracts@4.8.3/token/ERC20/utils/SafeERC20.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";

import {ICashPlus} from "./interfaces/ICashPlus.sol";

/// @title CashPlusTransferorPool
/// @notice CCIP Token Pool for CashPlus cross-chain transfers using burn-and-mint mechanism.
/// @dev Extends Chainlink TokenPool to handle CashPlus-specific TokenData encoding/decoding.
contract CashPlusTransferorPool is TokenPool {
    using SafeERC20 for IERC20;

    /// @notice Gas limit for destination chain execution.
    /// @dev UUPS proxy + abi.decode(TokenData[], uint256[]) + mint + event requires ~200k gas.
    uint256 public destGasLimit = 200_000;

    /// @dev Tracks addresses allowed to call privileged transfer methods.
    mapping(address account => bool allowed) private s_whitelist;

    /// @notice If true, enforce whitelist checks for privileged transfer methods.
    bool public whitelistEnabled;

    /// @notice Thrown when msg.value is insufficient to cover CCIP fees.
    error NotEnoughBalance(uint256 currentBalance, uint256 requiredBalance);
    /// @notice Thrown when the destination chain is not allowlisted.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector);
    /// @notice Thrown when caller is not whitelisted.
    error CallerNotWhitelisted(address caller);
    /// @notice Thrown when attempting to whitelist the zero address.
    error InvalidWhitelistAddress();
    /// @notice Thrown when the receiver address is zero.
    error InvalidReceiverAddress();
    /// @notice Thrown when the token data is too long.
    error TokenDataTooLong();
    /// @notice Thrown when the refund failed.
    error RefundFailed();
    /// @notice Thrown when TokenData and amounts array lengths mismatch.
    error LengthMismatch();
    /// @notice Thrown when too many elements are provided.
    error TooManyElements();
    /// @notice Thrown when encoded pool data is too short.
    error DataTooShort();
    /// @notice Thrown when encoded pool data length is invalid.
    error InvalidDataLength();

    /// @notice Emitted when tokens are transferred to another chain via CCIP.
    /// @param messageId The unique ID of the CCIP message.
    /// @param destinationChainSelector The chain selector of the destination chain.
    /// @param receiver The address of the receiver on the destination chain.
    /// @param token The token address that was transferred.
    /// @param tokenAmount The token amount that was transferred.
    /// @param feeToken The token address used to pay CCIP fees (address(0) for native).
    /// @param fees The fees paid for sending the message.
    event TokensTransferred(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address receiver,
        address token,
        uint256 tokenAmount,
        address feeToken,
        uint256 fees
    );

    /// @notice Emitted when whitelist status changes.
    event WhitelistUpdated(address indexed account, bool allowed);

    /// @notice Emitted when whitelist enforcement toggles.
    event WhitelistEnabledUpdated(bool enabled);

    /// @dev Reverts if the receiver address is zero.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    /// @dev Reverts if msg.sender is not in the whitelist.
    modifier onlyWhitelisted() {
        if (whitelistEnabled && !s_whitelist[msg.sender]) {
            revert CallerNotWhitelisted(msg.sender);
        }
        _;
    }

    /// @notice Initializes the CashPlus token pool for cross-chain transfers.
    /// @param token The CashPlus token address.
    /// @param localTokenDecimals The decimals of the token on this chain.
    /// @param allowlist List of addresses allowed to interact with the pool.
    /// @param rmnProxy The RMN proxy address for security verification.
    /// @param router The CCIP router address.
    constructor(
        address token,
        uint8 localTokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    )
        TokenPool(
            IERC20(token),
            localTokenDecimals,
            allowlist,
            rmnProxy,
            router
        )
    {
        whitelistEnabled = true;
        _setWhitelist(owner(), true);
        for (uint256 i = 0; i < allowlist.length; ++i) {
            _setWhitelist(allowlist[i], true);
        }
    }

    /// @notice Returns whether an address is whitelisted.
    function isWhitelisted(address account) external view returns (bool) {
        return s_whitelist[account];
    }

    /// @notice Batch updates whitelist status.
    /// @dev Only callable by the owner.
    function setWhitelistBatch(
        address[] calldata accounts,
        bool allowed
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; ++i) {
            _setWhitelist(accounts[i], allowed);
        }
    }

    /// @notice Enables or disables whitelist enforcement.
    /// @dev Only callable by the owner.
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
        emit WhitelistEnabledUpdated(enabled);
    }

    function _setWhitelist(address account, bool allowed) internal {
        if (account == address(0)) revert InvalidWhitelistAddress();
        s_whitelist[account] = allowed;
        emit WhitelistUpdated(account, allowed);
    }

    /// @notice Sets the gas limit for destination chain execution.
    /// @dev Only callable by the owner.
    /// @param _gasLimit The new gas limit value.
    function setDestGasLimit(uint256 _gasLimit) external onlyOwner {
        destGasLimit = _gasLimit;
    }

    /// @notice Transfers tokens to a receiver on the destination chain, paying fees in native gas.
    /// @dev Only callable by the owner. Excess msg.value is refunded to the sender.
    /// @param _destinationChainSelector The CCIP chain selector for the destination blockchain.
    /// @param _receiver The recipient address on the destination blockchain.
    /// @param _token The token address to transfer.
    /// @param _amount The amount of tokens to transfer.
    /// @return messageId The unique ID of the CCIP message.
    function transferTokensPayNative(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    )
        external
        payable
        onlyWhitelisted
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        if (!isSupportedChain(_destinationChainSelector))
            revert DestinationChainNotAllowlisted(_destinationChainSelector);

        uint256 fees = getRouterFee(
            _destinationChainSelector,
            _receiver,
            _token,
            _amount
        );

        if (fees != msg.value) {
            if (fees > msg.value) {
                revert NotEnoughBalance(msg.value, fees);
            } else if (msg.value > fees) {
                (bool success, ) = msg.sender.call{value: msg.value - fees}("");
                if (!success) revert RefundFailed();
            }
        }

        address router = getRouter();
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_token).safeApprove(router, 0);
        IERC20(_token).safeApprove(router, _amount);

        messageId = IRouterClient(router).ccipSend{value: fees}(
            _destinationChainSelector,
            _buildCCIPMessage(_receiver, _token, _amount, address(0))
        );

        emit TokensTransferred(
            messageId,
            _destinationChainSelector,
            _receiver,
            _token,
            _amount,
            address(0),
            fees
        );
    }

    /// @notice Calculates the CCIP fee required to send a cross-chain message.
    /// @param _destinationChainSelector The CCIP chain selector for the destination blockchain.
    /// @param _receiver The recipient address on the destination blockchain.
    /// @param _token The token address to transfer.
    /// @param _amount The amount of tokens to transfer.
    /// @return The fee amount in native gas (ETH/POL).
    function getRouterFee(
        uint64 _destinationChainSelector,
        address _receiver,
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        return
            IRouterClient(getRouter()).getFee(
                _destinationChainSelector,
                _buildCCIPMessage(_receiver, _token, _amount, address(0))
            );
    }

    /// @dev Constructs a CCIP message for cross-chain token transfer.
    /// @param _receiver The recipient address on the destination chain.
    /// @param _token The token address to transfer.
    /// @param _amount The amount of tokens to transfer.
    /// @param _feeTokenAddress The fee token address (address(0) for native gas).
    /// @return The constructed EVM2AnyMessage struct.
    function _buildCCIPMessage(
        address _receiver,
        address _token,
        uint256 _amount,
        address _feeTokenAddress
    ) private view returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: "",
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.GenericExtraArgsV2({
                        gasLimit: destGasLimit,
                        allowOutOfOrderExecution: true
                    })
                ),
                feeToken: _feeTokenAddress
            });
    }

    /// @notice Allows the contract to receive native gas for CCIP fee payments.
    receive() external payable {}

    /// @notice Burns tokens on the source chain during a cross-chain transfer.
    /// @dev Encodes TokenData and amounts into compact destPoolData for the destination chain.
    /// @param lockOrBurnIn The lock/burn input parameters from CCIP.
    /// @return The output containing destination token address and encoded pool data.
    function lockOrBurn(
        Pool.LockOrBurnInV1 calldata lockOrBurnIn
    ) public virtual override returns (Pool.LockOrBurnOutV1 memory) {
        _validateLockOrBurn(lockOrBurnIn);

        (
            ICashPlus.TokenData[] memory tokenDatas,
            uint256[] memory amounts
        ) = ICashPlus(address(i_token)).burnFrom(
                lockOrBurnIn.originalSender,
                lockOrBurnIn.amount
            );
        if (tokenDatas.length > 100) revert TokenDataTooLong();

        bytes memory destPoolData = _encodePoolData(tokenDatas, amounts);

        emit LockedOrBurned({
            remoteChainSelector: lockOrBurnIn.remoteChainSelector,
            token: address(i_token),
            sender: msg.sender,
            amount: lockOrBurnIn.amount
        });

        return
            Pool.LockOrBurnOutV1({
                destTokenAddress: getRemoteToken(
                    lockOrBurnIn.remoteChainSelector
                ),
                destPoolData: destPoolData
            });
    }

    /// @notice Mints tokens on the destination chain during a cross-chain transfer.
    /// @dev Decodes TokenData and amounts from compact sourcePoolData and mints to the receiver.
    /// @param releaseOrMintIn The release/mint input parameters from CCIP.
    /// @return The output containing the minted amount.
    function releaseOrMint(
        Pool.ReleaseOrMintInV1 calldata releaseOrMintIn
    ) public virtual override returns (Pool.ReleaseOrMintOutV1 memory) {
        (
            ICashPlus.TokenData[] memory tokenDatas,
            uint256[] memory amounts,
            uint256 localAmount
        ) = _decodePoolData(releaseOrMintIn.sourcePoolData);

        _validateReleaseOrMint(releaseOrMintIn, localAmount);

        ICashPlus(address(i_token)).mint(
            releaseOrMintIn.receiver,
            localAmount,
            tokenDatas,
            amounts
        );
        emit ReleasedOrMinted({
            remoteChainSelector: releaseOrMintIn.remoteChainSelector,
            token: address(i_token),
            sender: msg.sender,
            recipient: releaseOrMintIn.receiver,
            amount: localAmount
        });

        return Pool.ReleaseOrMintOutV1({destinationAmount: localAmount});
    }

    /// @dev Encodes TokenData[] and amounts[] into compact bytes.
    /// Format: [length: 2 bytes][element1][element2]...
    /// Each element: [id: 32 bytes][amount: 16 bytes][tokenOwner: 20 bytes][chainId: 8 bytes] = 76 bytes
    /// @param tokenDatas Array of TokenData structs.
    /// @param amounts Array of corresponding amounts.
    /// @return Compact encoded bytes.
    function _encodePoolData(
        ICashPlus.TokenData[] memory tokenDatas,
        uint256[] memory amounts
    ) internal pure returns (bytes memory) {
        uint256 length = tokenDatas.length;
        if (length != amounts.length) revert LengthMismatch();
        if (length > type(uint16).max) revert TooManyElements();

        // Calculate total size: 2 bytes length + 76 bytes per element
        bytes memory data = new bytes(2 + length * 76);

        assembly {
            let ptr := add(data, 32) // skip length prefix of bytes

            // Store length as uint16 (2 bytes)
            mstore8(ptr, shr(8, length))
            mstore8(add(ptr, 1), and(length, 0xff))
            ptr := add(ptr, 2)

            // Get pointers to arrays (skip length prefix)
            let tokenDatasPtr := add(tokenDatas, 32)
            let amountsPtr := add(amounts, 32)

            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                // Get pointer to current TokenData struct
                let structPtr := mload(add(tokenDatasPtr, mul(i, 32)))

                // id (32 bytes) - full uint256
                mstore(ptr, mload(structPtr))
                ptr := add(ptr, 32)

                // amount as uint128 (16 bytes) - take lower 128 bits, shift left to align
                let amt := mload(add(amountsPtr, mul(i, 32)))
                mstore(ptr, shl(128, amt))
                ptr := add(ptr, 16)

                // tokenOwner (20 bytes)
                let tOwner := mload(add(structPtr, 32))
                mstore(ptr, shl(96, tOwner))
                ptr := add(ptr, 20)

                // chainId as uint64 (8 bytes)
                let chainId := mload(add(structPtr, 64))
                mstore(ptr, shl(192, chainId))
                ptr := add(ptr, 8)
            }
        }

        return data;
    }

    /// @dev Decodes compact bytes back to TokenData[] and amounts[].
    /// @param data Compact encoded bytes from source chain.
    /// @return tokenDatas Decoded array of TokenData structs.
    /// @return amounts Decoded array of amounts.
    /// @return totalAmount Sum of all amounts.
    function _decodePoolData(
        bytes memory data
    )
        internal
        pure
        returns (
            ICashPlus.TokenData[] memory tokenDatas,
            uint256[] memory amounts,
            uint256 totalAmount
        )
    {
        if (data.length < 2) revert DataTooShort();

        // Read length from first 2 bytes
        uint256 length = (uint256(uint8(data[0])) << 8) |
            uint256(uint8(data[1]));

        if (data.length != 2 + length * 76) revert InvalidDataLength();

        tokenDatas = new ICashPlus.TokenData[](length);
        amounts = new uint256[](length);
        totalAmount = 0;

        assembly {
            let ptr := add(add(data, 32), 2) // skip bytes length + uint16 length
            let tokenDatasPtr := add(tokenDatas, 32)
            let amountsPtr := add(amounts, 32)

            for {
                let i := 0
            } lt(i, length) {
                i := add(i, 1)
            } {
                // Allocate new TokenData struct
                let structPtr := mload(0x40)
                mstore(0x40, add(structPtr, 96)) // 3 * 32 bytes
                mstore(add(tokenDatasPtr, mul(i, 32)), structPtr)

                // id (32 bytes) - full uint256
                mstore(structPtr, mload(ptr))
                ptr := add(ptr, 32)

                // amount from uint128 (16 bytes) - read 32 bytes and shift right by 128 bits
                let amt := shr(128, mload(ptr))
                mstore(add(amountsPtr, mul(i, 32)), amt)
                totalAmount := add(totalAmount, amt)
                ptr := add(ptr, 16)

                // tokenOwner (20 bytes) - read 32 bytes and shift right by 96 bits
                let tokenOwner := shr(96, mload(ptr))
                mstore(add(structPtr, 32), tokenOwner)
                ptr := add(ptr, 20)

                // chainId from uint64 (8 bytes) - read 32 bytes and shift right by 192 bits
                let cId := shr(192, mload(ptr))
                mstore(add(structPtr, 64), cId)
                ptr := add(ptr, 8)
            }
        }
    }
}
