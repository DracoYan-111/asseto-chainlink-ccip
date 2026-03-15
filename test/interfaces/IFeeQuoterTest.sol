// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Minimal FeeQuoter interface for fork testing
/// Based on ccip-develop branch FeeQuoter.sol
interface IFeeQuoterTest {
    /// @dev Transfer fee configuration for a single token
    struct TokenTransferFeeConfig {
        uint32 minFeeUSDCents; // Minimum fee to charge per token transfer, multiples of 0.01 USD
        uint32 maxFeeUSDCents; // Maximum fee to charge per token transfer, multiples of 0.01 USD
        uint16 deciBps; // Basis points charged on token transfers, multiples of 0.1bps, or 1e-5
        uint32 destGasOverhead; // Gas charged to execute the token transfer on the destination chain
        uint32 destBytesOverhead; // Extra data availability bytes returned from source pool
        bool isEnabled; // Whether this token has custom transfer fees
    }

    /// @dev Token transfer fee config with token address
    struct TokenTransferFeeConfigSingleTokenArgs {
        address token;
        TokenTransferFeeConfig tokenTransferFeeConfig;
    }

    /// @dev Token transfer fee configs for a destination chain
    struct TokenTransferFeeConfigArgs {
        uint64 destChainSelector;
        TokenTransferFeeConfigSingleTokenArgs[] tokenTransferFeeConfigs;
    }

    /// @dev Args for removing token transfer fee config
    struct TokenTransferFeeConfigRemoveArgs {
        uint64 destChainSelector;
        address token;
    }

    /// @notice Applies token transfer fee config updates
    function applyTokenTransferFeeConfigUpdates(
        TokenTransferFeeConfigArgs[] memory tokenTransferFeeConfigArgs,
        TokenTransferFeeConfigRemoveArgs[] memory tokensToUseDefaultFeeConfigs
    ) external;

    /// @notice Returns the owner of the contract
    function owner() external view returns (address);
}
