// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IYieldHook} from "./IYieldHook.sol";

/// @title Place — место города как NFT (ERC-721)
/// @notice Один токен = одно реальное место. Категория задаёт будущий yield; название,
///         координаты и картинка хранятся off-chain и доступны по tokenURI.
contract Place is ERC721URIStorage, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Уведомляется при каждом трансфере, чтобы доход настилался уходящему владельцу.
    // Задаётся после деплоя (vault создаётся уже зная Place — иначе циклическая зависимость).
    IYieldHook public yieldHook;

    // Кальянные → Food, парки → Park. Порядок фиксирован: это часть on-chain состояния.
    enum Category {
        Landmark,
        Transit,
        Food,
        Park
    }

    // Потолок предложения неизменен — дефицит мест и есть основа ценности в игре.
    uint256 public immutable maxSupply;

    // Сминчено всего; одновременно — id следующего токена (нумерация с 0).
    uint256 public totalMinted;

    mapping(uint256 tokenId => Category) public categoryOf;

    event PlaceMinted(uint256 indexed tokenId, address indexed to, Category category, string uri);

    error MaxSupplyReached(uint256 maxSupply);

    // admin получает DEFAULT_ADMIN_ROLE и дальше сам выдаёт MINTER (сидеру, в будущем — sale-контракту).
    constructor(uint256 maxSupply_, address admin) ERC721("Cityverse Place", "PLACE") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        maxSupply = maxSupply_;
    }

    function setYieldHook(IYieldHook hook) external onlyRole(DEFAULT_ADMIN_ROLE) {
        yieldHook = hook;
    }

    function mint(address to, Category category, string calldata uri)
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 tokenId)
    {
        if (totalMinted >= maxSupply) revert MaxSupplyReached(maxSupply);

        tokenId = totalMinted;
        totalMinted += 1;

        categoryOf[tokenId] = category;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit PlaceMinted(tokenId, to, category, uri);
    }

    // Хук на любую смену владельца (включая минт: from == address(0)). Доход уходящему владельцу.
    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = super._update(to, tokenId, auth);
        if (address(yieldHook) != address(0)) {
            yieldHook.settle(tokenId, from);
        }
    }

    // ERC721URIStorage и AccessControl оба объявляют supportsInterface — объединяем их реализации.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
