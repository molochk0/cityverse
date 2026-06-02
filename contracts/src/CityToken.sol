// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title $CITY — внутриигровая валюта (ERC-20)
/// @notice Минтится не сразу, а по ходу игры теми, у кого есть роль MINTER
///         (в Фазе 3 ею наделим YieldVault — он раздаёт награды за владение местами).
contract CityToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // admin получает DEFAULT_ADMIN_ROLE и дальше сам выдаёт/отзывает MINTER нужным контрактам.
    constructor(address admin) ERC20("Cityverse Token", "CITY") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
