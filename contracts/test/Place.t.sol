// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Place} from "../src/Place.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract PlaceTest is Test {
    Place internal place;

    address internal owner = address(this); // деплоер = owner
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    // Локальная копия события для vm.expectEmit.
    event PlaceMinted(uint256 indexed tokenId, address indexed to, Place.Category category, string uri);

    function setUp() public {
        place = new Place(3); // маленький потолок, чтобы проверить лимит
    }

    function test_Metadata() public view {
        assertEq(place.name(), "Cityverse Place");
        assertEq(place.symbol(), "PLACE");
        assertEq(place.maxSupply(), 3);
        assertEq(place.totalMinted(), 0);
        assertEq(place.owner(), owner);
    }

    function test_OwnerCanMint() public {
        vm.expectEmit(true, true, false, true);
        emit PlaceMinted(0, alice, Place.Category.Park, "ipfs://park0");

        uint256 id = place.mint(alice, Place.Category.Park, "ipfs://park0");

        assertEq(id, 0);
        assertEq(place.ownerOf(0), alice);
        assertEq(uint8(place.categoryOf(0)), uint8(Place.Category.Park));
        assertEq(place.tokenURI(0), "ipfs://park0");
        assertEq(place.totalMinted(), 1);
        assertEq(place.balanceOf(alice), 1);
    }

    function test_TokenIdsIncrementSequentially() public {
        place.mint(alice, Place.Category.Food, "ipfs://a");
        place.mint(bob, Place.Category.Park, "ipfs://b");

        assertEq(place.ownerOf(0), alice);
        assertEq(place.ownerOf(1), bob);
        assertEq(uint8(place.categoryOf(0)), uint8(Place.Category.Food));
        assertEq(uint8(place.categoryOf(1)), uint8(Place.Category.Park));
        assertEq(place.totalMinted(), 2);
    }

    function test_NonOwnerCannotMint() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        place.mint(alice, Place.Category.Food, "ipfs://x");
    }

    function test_RevertsWhenMaxSupplyReached() public {
        place.mint(alice, Place.Category.Park, "a");
        place.mint(alice, Place.Category.Park, "b");
        place.mint(alice, Place.Category.Park, "c"); // 3/3 — потолок

        vm.expectRevert(abi.encodeWithSelector(Place.MaxSupplyReached.selector, 3));
        place.mint(alice, Place.Category.Park, "d");
    }

    function test_TokenURIRevertsForNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 99));
        place.tokenURI(99);
    }

    /// @dev Любая валидная категория корректно сохраняется в categoryOf.
    function testFuzz_MintAssignsCategory(uint8 catRaw) public {
        Place.Category cat = Place.Category(bound(catRaw, 0, 3));
        place.mint(alice, cat, "ipfs://fuzz");
        assertEq(uint8(place.categoryOf(0)), uint8(cat));
    }
}
