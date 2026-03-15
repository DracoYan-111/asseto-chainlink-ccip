// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity 0.8.24;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {ICashPlus} from "../interfaces/ICashPlus.sol";

contract Erc20Token is
    ICashPlus,
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address private _ccipAdmin;

    event CCIPAdminTransferred(
        address indexed previousAdmin,
        address indexed newAdmin
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address minter,
        address upgrader
    ) public initializer {
        __ERC20_init("MyToken", "MTK");
        __AccessControl_init();
        _setCCIPAdmin(defaultAdmin);

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function mint(
        address to,
        uint256 amount,
        TokenData[] calldata tokenDatas,
        uint256[] calldata amounts
    ) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
        // 暂时不用染色直接从事件打印
        emit UseMockTokenData(to, amount, tokenDatas, amounts);
    }

    function burnFrom(
        address from,
        uint256 amount
    )
        external
        returns (TokenData[] memory tokenDatas, uint256[] memory amounts)
    {
        _burn(from, amount);

        // 生成固定的测试染色数据（3 笔，按 50%/30%/20% 拆分）
        tokenDatas = new TokenData[](3);
        amounts = new uint256[](3);

        tokenDatas[0] = TokenData({
            id: 1001,
            tokenOwner: from,
            chainId: block.chainid
        });
        amounts[0] = (amount * 50) / 100;

        tokenDatas[1] = TokenData({
            id: 1002,
            tokenOwner: from,
            chainId: block.chainid
        });
        amounts[1] = (amount * 30) / 100;

        tokenDatas[2] = TokenData({
            id: 1003,
            tokenOwner: from,
            chainId: block.chainid
        });
        amounts[2] = amount - amounts[0] - amounts[1];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // ---- CCT 自助注册需要的接口 ----
    function getCCIPAdmin() external view returns (address) {
        return _ccipAdmin;
    }

    function setCCIPAdmin(
        address newAdmin
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newAdmin != address(0), "CCIP admin is zero");
        _setCCIPAdmin(newAdmin);
    }

    function _setCCIPAdmin(address newAdmin) internal {
        address previous = _ccipAdmin;
        _ccipAdmin = newAdmin;
        emit CCIPAdminTransferred(previous, newAdmin);
    }
}
