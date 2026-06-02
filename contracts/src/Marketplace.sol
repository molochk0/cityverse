// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Place} from "./Place.sol";
import {CityToken} from "./CityToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Marketplace — купля-продажа мест за $CITY
/// @notice Продавец выставляет место (NFT уходит в escrow на этот контракт). Покупатель платит
///         $CITY → получает NFT, продавец получает $CITY. Продавец может снять листинг и забрать NFT.
contract Marketplace is IERC721Receiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        uint256 price;
    }

    Place public immutable place;
    IERC20 public immutable city;

    mapping(uint256 tokenId => Listing) public listings;

    event Listed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event Sold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event Cancelled(uint256 indexed tokenId, address indexed seller);

    error ZeroPrice();
    error AlreadyListed(uint256 tokenId);
    error NotListed(uint256 tokenId);
    error NotSeller(uint256 tokenId, address caller);

    constructor(Place place_, CityToken city_) {
        place = place_;
        city = city_;
    }

    /// @notice Выставить место на продажу. Требует предварительного approve этого контракта на NFT.
    function list(uint256 tokenId, uint256 price) external {
        if (price == 0) revert ZeroPrice();
        if (listings[tokenId].seller != address(0)) revert AlreadyListed(tokenId);

        listings[tokenId] = Listing(msg.sender, price);
        place.safeTransferFrom(msg.sender, address(this), tokenId); // в escrow

        emit Listed(tokenId, msg.sender, price);
    }

    /// @notice Купить место. Требует предварительного approve этого контракта на $CITY (>= price).
    function buy(uint256 tokenId) external nonReentrant {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed(tokenId);

        delete listings[tokenId]; // эффект до внешних вызовов (CEI)

        city.safeTransferFrom(msg.sender, item.seller, item.price); // оплата $CITY
        place.safeTransferFrom(address(this), msg.sender, tokenId); // выдаём NFT

        emit Sold(tokenId, item.seller, msg.sender, item.price);
    }

    /// @notice Снять листинг и вернуть NFT продавцу.
    function cancel(uint256 tokenId) external nonReentrant {
        Listing memory item = listings[tokenId];
        if (item.seller == address(0)) revert NotListed(tokenId);
        if (item.seller != msg.sender) revert NotSeller(tokenId, msg.sender);

        delete listings[tokenId];
        place.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Cancelled(tokenId, msg.sender);
    }

    /// @dev Нужно, чтобы контракт мог принимать NFT через safeTransferFrom.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
