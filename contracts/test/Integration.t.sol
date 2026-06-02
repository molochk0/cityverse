// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CityToken} from "../src/CityToken.sol";
import {Place} from "../src/Place.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {Harberger} from "../src/Harberger.sol";

/// @notice Сквозной тест: вся игровая петля на связке контрактов в одном прогоне.
contract IntegrationTest is Test {
    CityToken internal city;
    Place internal place;
    YieldVault internal vault;
    Marketplace internal market;
    Harberger internal harb;

    address internal admin = address(this);
    address internal treasury = makeAddr("treasury");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant TOKEN = 0;

    function setUp() public {
        city = new CityToken(admin);
        place = new Place(50, admin);
        vault = new YieldVault(place, city);
        market = new Marketplace(place, city);
        harb = new Harberger(place, city, treasury, 1000);

        city.grantRole(city.MINTER_ROLE(), address(vault)); // как в Deploy
        place.grantRole(place.MINTER_ROLE(), admin);
        place.setYieldHook(vault); // как в Deploy: доход настилается при трансфере
        city.grantRole(city.MINTER_ROLE(), admin); // только для теста: фондируем покупателей

        place.mint(alice, Place.Category.Food, "ipfs://0"); // кальянная у alice
    }

    function test_FullLoop() public {
        // 1. Владение → доход. Alice держит место сутки и клеймит (Food = 10/сут).
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        vault.claim(TOKEN);
        assertEq(city.balanceOf(alice), 10e18);

        // 2. Продажа на маркетплейсе: alice → bob за 6 $CITY.
        city.mint(bob, 100e18);
        vm.startPrank(alice);
        place.approve(address(market), TOKEN);
        market.list(TOKEN, 6e18);
        vm.stopPrank();

        vm.startPrank(bob);
        city.approve(address(market), 6e18);
        market.buy(TOKEN);
        vm.stopPrank();

        assertEq(place.ownerOf(TOKEN), bob);
        assertEq(city.balanceOf(alice), 16e18); // 10 надоено + 6 с продажи

        // 3. Bob ставит место под Harberger: самооценка 20, депозит 10.
        vm.startPrank(bob);
        place.approve(address(harb), TOKEN);
        city.approve(address(harb), 10e18);
        harb.register(TOKEN, 20e18, 10e18);
        vm.stopPrank();
        assertEq(place.ownerOf(TOKEN), address(harb));

        // 4. Carol принудительно выкупает за самооценку 20 и ставит свою (25 / депозит 5).
        city.mint(carol, 100e18);
        vm.startPrank(carol);
        city.approve(address(harb), 25e18);
        harb.forceBuy(TOKEN, 25e18, 5e18);
        vm.stopPrank();

        (address owner, uint256 price,,) = harb.parcels(TOKEN);
        assertEq(owner, carol);
        assertEq(price, 25e18);

        // bob: 100 (минт) - 6 (купил место) - 10 (депозит) + 20 (цена выкупа) + 10 (возврат депозита) = 114
        assertEq(city.balanceOf(bob), 114e18);
        // carol: 100 - 20 (цена) - 5 (депозит) = 75
        assertEq(city.balanceOf(carol), 75e18);
    }
}
