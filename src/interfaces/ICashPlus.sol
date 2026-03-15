// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface ICashPlus {
    // TokenData structure to hold token ID and amount
    struct TokenData {
        uint256 id; // Token ID
        address tokenOwner; // Token owner address
        uint256 chainId; // Chain ID where the token was minted
    }

    event UseMockTokenData(
        address to,
        uint256 amount,
        ICashPlus.TokenData[] tokenDatas,
        uint256[] amounts
    );

    function burnFrom(
        address from,
        uint256 amount
    )
        external
        returns (TokenData[] memory tokenDatas, uint256[] memory amounts);

    function mint(
        address to,
        uint256 amount,
        TokenData[] calldata tokenDatas,
        uint256[] calldata amounts
    ) external;
}
