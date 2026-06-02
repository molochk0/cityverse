// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Place} from "./Place.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Escrow — общая обвязка для контрактов, держащих места (Place) в эскроу.
/// @notice Хранит ссылки на Place и $CITY, принимает NFT (onERC721Received), даёт nonReentrant.
///         Наследуется Marketplace и Harberger.
abstract contract Escrow is IERC721Receiver, ReentrancyGuard {
    Place public immutable place;
    IERC20 public immutable city;

    constructor(Place place_, IERC20 city_) {
        place = place_;
        city = city_;
    }

    /// @dev Нужно, чтобы контракт мог принимать NFT через safeTransferFrom.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
