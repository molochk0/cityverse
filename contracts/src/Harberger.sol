// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Escrow} from "./Escrow.sol";
import {Place} from "./Place.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Harberger — принудительный выкуп мест по самооценке (Harberger Tax)
/// @notice Владелец регистрирует место: NFT уходит в escrow, владелец сам назначает цену (price)
///         и кладёт депозит $CITY на налог. Налог (доля от price в год) непрерывно списывается
///         из депозита в казну. Пока депозит цел — любой может выкупить место за price. Если депозит
///         исчерпан, место в дефолте и выкупается за 0 — это и есть «плати налог или потеряешь».
contract Harberger is Escrow {
    using SafeERC20 for IERC20;

    struct Parcel {
        address owner; // бенефициарный владелец (NFT лежит в escrow на этом контракте)
        uint256 price; // самооценка
        uint256 deposit; // запас $CITY на уплату налога
        uint256 lastSettled; // момент последнего расчёта налога
    }

    uint256 internal constant BPS = 10_000;
    uint256 internal constant YEAR = 365 days;

    address public immutable treasury; // получатель собранного налога
    uint256 public immutable taxRateBps; // годовая ставка налога в basis points (1000 = 10%/год)

    mapping(uint256 tokenId => Parcel) public parcels;

    event Registered(uint256 indexed tokenId, address indexed owner, uint256 price, uint256 deposit);
    event PriceSet(uint256 indexed tokenId, address indexed owner, uint256 newPrice);
    event DepositAdded(uint256 indexed tokenId, uint256 amount, uint256 newDeposit);
    event TaxSettled(uint256 indexed tokenId, uint256 paid, uint256 remainingDeposit);
    event ForceBought(uint256 indexed tokenId, address indexed from, address indexed to, uint256 pricePaid, uint256 newPrice);
    event Withdrawn(uint256 indexed tokenId, address indexed owner);

    error ZeroPrice();
    error ZeroDeposit();
    error AlreadyRegistered(uint256 tokenId);
    error NotRegistered(uint256 tokenId);
    error NotParcelOwner(uint256 tokenId, address caller);
    error InDefault(uint256 tokenId);

    constructor(Place place_, IERC20 city_, address treasury_, uint256 taxRateBps_) Escrow(place_, city_) {
        treasury = treasury_;
        taxRateBps = taxRateBps_;
    }

    /// @notice Накопленный, но ещё не списанный налог.
    function taxOwed(uint256 tokenId) public view returns (uint256) {
        Parcel memory p = parcels[tokenId];
        if (p.owner == address(0)) return 0;
        uint256 elapsed = block.timestamp - p.lastSettled;
        return p.price * taxRateBps * elapsed / (BPS * YEAR);
    }

    /// @notice Депозит исчерпан налогом — место можно выкупить за 0.
    function inDefault(uint256 tokenId) public view returns (bool) {
        if (parcels[tokenId].owner == address(0)) return false;
        return taxOwed(tokenId) >= parcels[tokenId].deposit;
    }

    /// @notice Цена принудительного выкупа прямо сейчас (0, если место в дефолте).
    function effectivePrice(uint256 tokenId) public view returns (uint256) {
        return inDefault(tokenId) ? 0 : parcels[tokenId].price;
    }

    /// @notice Зарегистрировать место под Harberger. Требует approve NFT и $CITY (depositа).
    function register(uint256 tokenId, uint256 price, uint256 deposit) external nonReentrant {
        if (price == 0) revert ZeroPrice();
        if (deposit == 0) revert ZeroDeposit();
        if (parcels[tokenId].owner != address(0)) revert AlreadyRegistered(tokenId);

        parcels[tokenId] = Parcel(msg.sender, price, deposit, block.timestamp);

        city.safeTransferFrom(msg.sender, address(this), deposit);
        place.safeTransferFrom(msg.sender, address(this), tokenId);

        emit Registered(tokenId, msg.sender, price, deposit);
    }

    /// @notice Списать накопленный налог из депозита в казну. Может звать кто угодно.
    function settleTax(uint256 tokenId) external {
        if (parcels[tokenId].owner == address(0)) revert NotRegistered(tokenId);
        _settle(tokenId);
    }

    /// @notice Изменить самооценку. Налог за прошедший период списывается по старой цене.
    function setPrice(uint256 tokenId, uint256 newPrice) external {
        Parcel storage p = parcels[tokenId];
        if (p.owner != msg.sender) revert NotParcelOwner(tokenId, msg.sender);
        if (newPrice == 0) revert ZeroPrice();

        _settle(tokenId);
        p.price = newPrice;

        emit PriceSet(tokenId, msg.sender, newPrice);
    }

    /// @notice Пополнить депозит (продлить «горючее» для налога).
    function addDeposit(uint256 tokenId, uint256 amount) external nonReentrant {
        Parcel storage p = parcels[tokenId];
        if (p.owner != msg.sender) revert NotParcelOwner(tokenId, msg.sender);
        if (amount == 0) revert ZeroDeposit();

        _settle(tokenId);
        p.deposit += amount;

        city.safeTransferFrom(msg.sender, address(this), amount);

        emit DepositAdded(tokenId, amount, p.deposit);
    }

    /// @notice Принудительно выкупить место. Покупатель платит текущую цену владельцу и сразу
    ///         задаёт свою самооценку (newPrice) и депозит (newDeposit).
    function forceBuy(uint256 tokenId, uint256 newPrice, uint256 newDeposit) external nonReentrant {
        Parcel storage p = parcels[tokenId];
        if (p.owner == address(0)) revert NotRegistered(tokenId);
        if (newPrice == 0) revert ZeroPrice();
        if (newDeposit == 0) revert ZeroDeposit();

        uint256 buyPrice = effectivePrice(tokenId); // фиксируем до списания налога
        address oldOwner = p.owner;

        _settle(tokenId); // добираем налог из депозита старого владельца
        uint256 refund = p.deposit; // остаток депозита вернём старому владельцу

        // эффекты до внешних вызовов (CEI)
        p.owner = msg.sender;
        p.price = newPrice;
        p.deposit = newDeposit;
        p.lastSettled = block.timestamp;

        if (refund > 0) city.safeTransfer(oldOwner, refund);
        if (buyPrice > 0) city.safeTransferFrom(msg.sender, oldOwner, buyPrice);
        city.safeTransferFrom(msg.sender, address(this), newDeposit);

        emit ForceBought(tokenId, oldOwner, msg.sender, buyPrice, newPrice);
    }

    /// @notice Забрать место из-под Harberger (вернуть NFT). Нельзя, пока в дефолте — сперва пополни депозит.
    function withdraw(uint256 tokenId) external nonReentrant {
        Parcel storage p = parcels[tokenId];
        if (p.owner != msg.sender) revert NotParcelOwner(tokenId, msg.sender);
        if (inDefault(tokenId)) revert InDefault(tokenId);

        _settle(tokenId);
        uint256 refund = p.deposit;
        delete parcels[tokenId];

        place.safeTransferFrom(address(this), msg.sender, tokenId);
        if (refund > 0) city.safeTransfer(msg.sender, refund);

        emit Withdrawn(tokenId, msg.sender);
    }

    function _settle(uint256 tokenId) internal {
        Parcel storage p = parcels[tokenId];
        uint256 owed = taxOwed(tokenId);
        p.lastSettled = block.timestamp;
        if (owed == 0 || p.deposit == 0) return;

        uint256 pay = owed < p.deposit ? owed : p.deposit; // больше депозита не собрать (остаток прощается)
        p.deposit -= pay;

        city.safeTransfer(treasury, pay);
        emit TaxSettled(tokenId, pay, p.deposit);
    }
}
