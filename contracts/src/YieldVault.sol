// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Place} from "./Place.sol";
import {CityToken} from "./CityToken.sol";
import {IYieldHook} from "./IYieldHook.sol";

/// @title YieldVault — пассивная доходность мест в $CITY
/// @notice Каждое место копит $CITY со временем по ставке своей категории. Владелец места
///         в любой момент клеймит накопленное — vault минтит ему $CITY (для этого ему нужна
///         роль MINTER на CityToken). Дополнительно Place дёргает settle() при каждом трансфере,
///         чтобы доход настилался уходящему владельцу, а не утекал покупателю/выкупщику.
contract YieldVault is IYieldHook {
    Place public immutable place;
    CityToken public immutable city;

    // Точка отсчёта доходности для мест, по которым ещё не клеймили.
    uint256 public immutable startTime;

    mapping(uint256 tokenId => uint256 timestamp) public lastClaimAt;

    event Claimed(uint256 indexed tokenId, address indexed owner, uint256 amount);

    error NotPlaceOwner(uint256 tokenId, address caller);
    error OnlyPlace();

    constructor(Place place_, CityToken city_) {
        place = place_;
        city = city_;
        startTime = block.timestamp;
    }

    /// @notice Базовая ставка доходности категории, в $CITY за сутки (18 знаков).
    function ratePerDay(Place.Category category) public pure returns (uint256) {
        if (category == Place.Category.Landmark) return 15e18;
        if (category == Place.Category.Food) return 10e18;
        if (category == Place.Category.Transit) return 8e18;
        return 5e18; // Park
    }

    /// @notice Сколько $CITY накопило место с момента последнего клейма.
    function pendingYield(uint256 tokenId) public view returns (uint256) {
        if (tokenId >= place.totalMinted()) return 0; // место не сминчено

        uint256 last = lastClaimAt[tokenId];
        if (last == 0) last = startTime; // подстраховка для мест без зафиксированного клока

        uint256 elapsed = block.timestamp - last;
        return ratePerDay(place.categoryOf(tokenId)) * elapsed / 1 days;
    }

    /// @notice Забрать накопленный $CITY. Доступно только текущему владельцу места.
    function claim(uint256 tokenId) external returns (uint256) {
        address owner = place.ownerOf(tokenId); // реверт, если места не существует
        if (msg.sender != owner) revert NotPlaceOwner(tokenId, msg.sender);
        return _accrue(tokenId, owner);
    }

    /// @notice Вызывается только из Place при трансфере: настилаем доход уходящему владельцу.
    ///         На минте (from == 0) дохода нет — просто запускаем клок места.
    function settle(uint256 tokenId, address from) external {
        if (msg.sender != address(place)) revert OnlyPlace();
        if (from == address(0)) {
            lastClaimAt[tokenId] = block.timestamp;
            return;
        }
        _accrue(tokenId, from);
    }

    function _accrue(uint256 tokenId, address to) private returns (uint256 amount) {
        amount = pendingYield(tokenId);
        lastClaimAt[tokenId] = block.timestamp; // эффект до внешнего вызова (CEI)
        if (amount > 0) city.mint(to, amount);

        emit Claimed(tokenId, to, amount);
    }
}
