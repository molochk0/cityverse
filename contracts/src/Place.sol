// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Place — уникальное место города как NFT (ERC-721)
/// @notice Каждый токен = одно реальное место (кальянная, парк и т.п.).
///         Категория задаёт базовый yield rate в будущих фазах (Phase 3 — YieldVault).
///         Метаданные (название, координаты, картинка) хранятся off-chain по uri (обычно ipfs://CID).
contract Place is ERC721URIStorage, Ownable {
    /// @dev Категории мест. Порядок важен — он часть on-chain состояния (categoryOf).
    ///      Кальянные/еда → Food, парки → Park.
    enum Category {
        Landmark, // достопримечательность
        Transit, // транспорт (станции и т.п.)
        Food, // еда / кальянные
        Park // парки и скверы
    }

    /// @notice Жёсткий потолок предложения. Фиксируется в конструкторе и неизменен —
    ///         именно дефицит мест создаёт ценность и конфликт в игре.
    uint256 public immutable maxSupply;

    /// @notice Сколько мест уже сминчено. Одновременно служит следующим tokenId (0-индексация).
    uint256 public totalMinted;

    /// @notice tokenId => категория места.
    mapping(uint256 tokenId => Category category) public categoryOf;

    /// @param tokenId Идентификатор сминченного места.
    /// @param to Кому ушёл NFT.
    /// @param category Категория места.
    /// @param uri Ссылка на метаданные (ipfs://...).
    event PlaceMinted(uint256 indexed tokenId, address indexed to, Category category, string uri);

    /// @dev Реверт при попытке сминтить сверх потолка.
    error MaxSupplyReached(uint256 maxSupply);

    /// @param maxSupply_ Максимальное число мест в игре (на старте 50–100).
    constructor(uint256 maxSupply_) ERC721("Cityverse Place", "PLACE") Ownable(msg.sender) {
        maxSupply = maxSupply_;
    }

    /// @notice Сминтить новое место. Пока доступно только владельцу контракта.
    ///         В Phase 2 onlyOwner заменится на роль MINTER (AccessControl).
    /// @param to Адрес-получатель NFT.
    /// @param category Категория места.
    /// @param uri Ссылка на метаданные места.
    /// @return tokenId Идентификатор созданного места.
    function mint(address to, Category category, string calldata uri)
        external
        onlyOwner
        returns (uint256 tokenId)
    {
        if (totalMinted >= maxSupply) revert MaxSupplyReached(maxSupply);

        tokenId = totalMinted;
        unchecked {
            totalMinted += 1; // не переполнится: ограничено maxSupply
        }

        categoryOf[tokenId] = category;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        emit PlaceMinted(tokenId, to, category, uri);
    }
}
