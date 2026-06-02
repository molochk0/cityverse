// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title Place — место города как NFT (ERC-721)
/// @notice Один токен = одно реальное место. Категория задаёт будущий yield; название,
///         координаты и картинка хранятся off-chain и доступны по tokenURI.
contract Place is ERC721URIStorage, Ownable {
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

    constructor(uint256 maxSupply_) ERC721("Cityverse Place", "PLACE") Ownable(msg.sender) {
        maxSupply = maxSupply_;
    }

    // onlyOwner — временно на Фазу 1; в Фазе 2 заменим на роль MINTER (AccessControl).
    function mint(address to, Category category, string calldata uri)
        external
        onlyOwner
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
}
