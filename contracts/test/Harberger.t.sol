// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Harberger} from "../src/Harberger.sol";
import {Place} from "../src/Place.sol";
import {CityToken} from "../src/CityToken.sol";

contract HarbergerTest is Test {
    Harberger internal harb;
    Place internal place;
    CityToken internal city;

    address internal admin = address(this);
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice"); // первый владелец места 0
    address internal bob = makeAddr("bob"); // выкупщик

    uint256 internal constant TOKEN = 0;
    uint256 internal constant PRICE = 100e18;
    uint256 internal constant TAX_BPS = 1000; // 10%/год → 10e18 в год при price 100e18

    function setUp() public {
        city = new CityToken(admin);
        city.grantRole(city.MINTER_ROLE(), admin);
        city.mint(alice, 1000e18);
        city.mint(bob, 1000e18);

        place = new Place(10, admin);
        place.grantRole(place.MINTER_ROLE(), admin);
        place.mint(alice, Place.Category.Landmark, "ipfs://0");

        harb = new Harberger(place, city, treasury, TAX_BPS);
    }

    function _registerAsAlice(uint256 price, uint256 deposit) internal {
        vm.startPrank(alice);
        place.approve(address(harb), TOKEN);
        city.approve(address(harb), deposit);
        harb.register(TOKEN, price, deposit);
        vm.stopPrank();
    }

    function test_RegisterEscrowsNFTAndDeposit() public {
        _registerAsAlice(PRICE, 20e18);

        assertEq(place.ownerOf(TOKEN), address(harb));
        assertEq(city.balanceOf(address(harb)), 20e18);
        assertEq(city.balanceOf(alice), 980e18);

        (address owner, uint256 price, uint256 deposit,) = harb.parcels(TOKEN);
        assertEq(owner, alice);
        assertEq(price, PRICE);
        assertEq(deposit, 20e18);
    }

    function test_RegisterZeroPriceReverts() public {
        vm.startPrank(alice);
        place.approve(address(harb), TOKEN);
        city.approve(address(harb), 20e18);
        vm.expectRevert(Harberger.ZeroPrice.selector);
        harb.register(TOKEN, 0, 20e18);
        vm.stopPrank();
    }

    function test_TaxAccruesButNotDefaultWhenFunded() public {
        _registerAsAlice(PRICE, 20e18);
        vm.warp(block.timestamp + 365 days);

        assertEq(harb.taxOwed(TOKEN), 10e18); // 10% от 100e18 за год
        assertFalse(harb.inDefault(TOKEN)); // 10e18 < 20e18
        assertEq(harb.effectivePrice(TOKEN), PRICE);
    }

    function test_SettleTaxMovesToTreasury() public {
        _registerAsAlice(PRICE, 20e18);
        vm.warp(block.timestamp + 365 days);

        harb.settleTax(TOKEN);

        assertEq(city.balanceOf(treasury), 10e18);
        (,, uint256 deposit,) = harb.parcels(TOKEN);
        assertEq(deposit, 10e18);
        assertEq(harb.taxOwed(TOKEN), 0);
    }

    function test_DefaultWhenDepositExhausted() public {
        _registerAsAlice(PRICE, 10e18);
        vm.warp(block.timestamp + 365 days); // налог 10e18 == депозит

        assertTrue(harb.inDefault(TOKEN));
        assertEq(harb.effectivePrice(TOKEN), 0);
    }

    function test_ForceBuyFunded() public {
        _registerAsAlice(PRICE, 20e18); // alice: 1000 - 20 = 980

        vm.startPrank(bob);
        city.approve(address(harb), PRICE + 30e18);
        harb.forceBuy(TOKEN, 150e18, 30e18);
        vm.stopPrank();

        // alice получила цену (100) и возврат депозита (20): 980 + 120 = 1100
        assertEq(city.balanceOf(alice), 1100e18);
        // bob отдал цену (100) и новый депозит (30): 1000 - 130 = 870
        assertEq(city.balanceOf(bob), 870e18);
        assertEq(city.balanceOf(treasury), 0); // налога не было (warp 0)

        (address owner, uint256 price, uint256 deposit,) = harb.parcels(TOKEN);
        assertEq(owner, bob);
        assertEq(price, 150e18);
        assertEq(deposit, 30e18);
        assertEq(place.ownerOf(TOKEN), address(harb)); // NFT остаётся в escrow
    }

    function test_ForceBuyInDefaultPaysZeroToOwner() public {
        _registerAsAlice(PRICE, 10e18); // alice: 990
        vm.warp(block.timestamp + 365 days); // дефолт: налог 10e18 == депозит

        vm.startPrank(bob);
        city.approve(address(harb), 10e18);
        harb.forceBuy(TOKEN, 50e18, 10e18);
        vm.stopPrank();

        // alice потеряла место бесплатно: цена 0, депозит ушёл в налог → остаётся 990
        assertEq(city.balanceOf(alice), 990e18);
        assertEq(city.balanceOf(treasury), 10e18); // весь депозит как налог
        // bob заплатил 0 цены + 10 депозита
        assertEq(city.balanceOf(bob), 990e18);

        (address owner,,,) = harb.parcels(TOKEN);
        assertEq(owner, bob);
    }

    function test_SetPriceSettlesFirst() public {
        _registerAsAlice(PRICE, 20e18);
        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        harb.setPrice(TOKEN, 200e18);

        (, uint256 price, uint256 deposit,) = harb.parcels(TOKEN);
        assertEq(price, 200e18);
        assertEq(deposit, 10e18); // 20 - 10 налога
        assertEq(city.balanceOf(treasury), 10e18);
    }

    function test_AddDepositRecoversFromDefault() public {
        _registerAsAlice(PRICE, 10e18);
        vm.warp(block.timestamp + 365 days); // дефолт

        vm.startPrank(alice);
        city.approve(address(harb), 15e18);
        harb.addDeposit(TOKEN, 15e18);
        vm.stopPrank();

        (,, uint256 deposit,) = harb.parcels(TOKEN);
        assertEq(deposit, 15e18); // старый депозит ушёл в налог, добавили 15
        assertFalse(harb.inDefault(TOKEN));
        assertEq(city.balanceOf(treasury), 10e18);
    }

    function test_Withdraw() public {
        _registerAsAlice(PRICE, 20e18); // alice: 980
        vm.warp(block.timestamp + 365 days);

        vm.prank(alice);
        harb.withdraw(TOKEN);

        assertEq(place.ownerOf(TOKEN), alice); // NFT вернулся
        assertEq(city.balanceOf(treasury), 10e18); // налог собран
        assertEq(city.balanceOf(alice), 990e18); // 980 + возврат 10
        (address owner,,,) = harb.parcels(TOKEN);
        assertEq(owner, address(0)); // запись удалена
    }

    function test_WithdrawInDefaultReverts() public {
        _registerAsAlice(PRICE, 10e18);
        vm.warp(block.timestamp + 365 days); // дефолт

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Harberger.InDefault.selector, TOKEN));
        harb.withdraw(TOKEN);
    }

    function test_ForceBuyUnregisteredReverts() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Harberger.NotRegistered.selector, TOKEN));
        harb.forceBuy(TOKEN, 100e18, 10e18);
    }

    function test_SetPriceByNonOwnerReverts() public {
        _registerAsAlice(PRICE, 20e18);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Harberger.NotParcelOwner.selector, TOKEN, bob));
        harb.setPrice(TOKEN, 200e18);
    }
}
