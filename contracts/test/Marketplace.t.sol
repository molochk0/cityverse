// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {Place} from "../src/Place.sol";
import {CityToken} from "../src/CityToken.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract MarketplaceTest is Test {
    Marketplace internal market;
    Place internal place;
    CityToken internal city;

    address internal admin = address(this);
    address internal alice = makeAddr("alice"); // продавец, владелец места 0
    address internal bob = makeAddr("bob"); // покупатель

    uint256 internal constant TOKEN = 0;
    uint256 internal constant PRICE = 100e18;

    function setUp() public {
        city = new CityToken(admin);
        city.grantRole(city.MINTER_ROLE(), admin);

        place = new Place(10, admin);
        place.grantRole(place.MINTER_ROLE(), admin);
        place.mint(alice, Place.Category.Park, "ipfs://0");

        market = new Marketplace(place, city);

        city.mint(bob, 1000e18); // у bob есть чем платить
    }

    function _listAsAlice(uint256 price) internal {
        vm.startPrank(alice);
        place.approve(address(market), TOKEN);
        market.list(TOKEN, price);
        vm.stopPrank();
    }

    function test_ListEscrowsNFT() public {
        _listAsAlice(PRICE);

        assertEq(place.ownerOf(TOKEN), address(market));
        (address seller, uint256 price) = market.listings(TOKEN);
        assertEq(seller, alice);
        assertEq(price, PRICE);
    }

    function test_ListZeroPriceReverts() public {
        vm.startPrank(alice);
        place.approve(address(market), TOKEN);
        vm.expectRevert(Marketplace.ZeroPrice.selector);
        market.list(TOKEN, 0);
        vm.stopPrank();
    }

    function test_ListAlreadyListedReverts() public {
        _listAsAlice(PRICE);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.AlreadyListed.selector, TOKEN));
        market.list(TOKEN, PRICE);
    }

    function test_Buy() public {
        _listAsAlice(PRICE);

        vm.startPrank(bob);
        city.approve(address(market), PRICE);
        market.buy(TOKEN);
        vm.stopPrank();

        assertEq(place.ownerOf(TOKEN), bob);
        assertEq(city.balanceOf(alice), PRICE);
        assertEq(city.balanceOf(bob), 1000e18 - PRICE);

        (address seller,) = market.listings(TOKEN);
        assertEq(seller, address(0)); // листинг удалён
    }

    function test_BuyNotListedReverts() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.NotListed.selector, TOKEN));
        market.buy(TOKEN);
    }

    function test_BuyWithoutApprovalReverts() public {
        _listAsAlice(PRICE);
        vm.prank(bob); // bob не делал approve на $CITY
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(market), 0, PRICE)
        );
        market.buy(TOKEN);
    }

    function test_Cancel() public {
        _listAsAlice(PRICE);

        vm.prank(alice);
        market.cancel(TOKEN);

        assertEq(place.ownerOf(TOKEN), alice);
        (address seller,) = market.listings(TOKEN);
        assertEq(seller, address(0));
    }

    function test_CancelByNonSellerReverts() public {
        _listAsAlice(PRICE);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.NotSeller.selector, TOKEN, bob));
        market.cancel(TOKEN);
    }

    function test_ReentrantBuyIsBlocked() public {
        _listAsAlice(PRICE);

        ReentrantBuyer attacker = new ReentrantBuyer(market, city);
        city.mint(address(attacker), 1000e18);

        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        attacker.attack(TOKEN);
    }
}

/// @dev Вредоносный покупатель: при получении NFT пытается повторно зайти в buy().
contract ReentrantBuyer is IERC721Receiver {
    Marketplace internal market;
    CityToken internal city;
    uint256 internal target;

    constructor(Marketplace market_, CityToken city_) {
        market = market_;
        city = city_;
    }

    function attack(uint256 tokenId) external {
        target = tokenId;
        city.approve(address(market), type(uint256).max);
        market.buy(tokenId);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        market.buy(target); // повторный вход — должен быть отбит nonReentrant
        return IERC721Receiver.onERC721Received.selector;
    }
}
