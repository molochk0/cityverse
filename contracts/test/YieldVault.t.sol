// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {Place} from "../src/Place.sol";
import {CityToken} from "../src/CityToken.sol";

contract YieldVaultTest is Test {
    YieldVault internal vault;
    Place internal place;
    CityToken internal city;

    address internal admin = address(this);
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    uint256 internal constant PARK = 0; // tokenId 0 — парк у alice
    uint256 internal constant LANDMARK = 1; // tokenId 1 — ландмарк у bob

    function setUp() public {
        city = new CityToken(admin);

        place = new Place(10, admin);
        place.grantRole(place.MINTER_ROLE(), admin);

        vault = new YieldVault(place, city);
        place.setYieldHook(vault); // хук до минта → у мест клок стартует с минта
        city.grantRole(city.MINTER_ROLE(), address(vault)); // vault получает право минтить награды

        place.mint(alice, Place.Category.Park, "ipfs://0");
        place.mint(bob, Place.Category.Landmark, "ipfs://1");
    }

    function test_RatesByCategory() public view {
        assertEq(vault.ratePerDay(Place.Category.Landmark), 15e18);
        assertEq(vault.ratePerDay(Place.Category.Food), 10e18);
        assertEq(vault.ratePerDay(Place.Category.Transit), 8e18);
        assertEq(vault.ratePerDay(Place.Category.Park), 5e18);
    }

    function test_PendingZeroInitially() public view {
        assertEq(vault.pendingYield(PARK), 0);
    }

    function test_AccruesOverTime() public {
        vm.warp(block.timestamp + 1 days);
        assertEq(vault.pendingYield(PARK), 5e18); // Park
        assertEq(vault.pendingYield(LANDMARK), 15e18); // Landmark
    }

    function test_ClaimMintsAndResets() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        uint256 amount = vault.claim(PARK);

        assertEq(amount, 5e18);
        assertEq(city.balanceOf(alice), 5e18);
        assertEq(vault.pendingYield(PARK), 0);
        assertEq(vault.lastClaimAt(PARK), block.timestamp);
    }

    function test_ClaimByNonOwnerReverts() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(bob); // bob не владеет местом 0
        vm.expectRevert(abi.encodeWithSelector(YieldVault.NotPlaceOwner.selector, PARK, bob));
        vault.claim(PARK);
    }

    function test_AccrualAccumulatesAcrossClaims() public {
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        vault.claim(PARK); // +5e18

        vm.warp(block.timestamp + 2 days);
        assertEq(vault.pendingYield(PARK), 10e18);

        vm.prank(alice);
        vault.claim(PARK); // +10e18

        assertEq(city.balanceOf(alice), 15e18);
    }

    /// @dev Доходность линейна по времени: rate * elapsed / 1 day.
    function testFuzz_LinearInTime(uint32 elapsed) public {
        vm.warp(block.timestamp + elapsed);
        assertEq(vault.pendingYield(PARK), 5e18 * uint256(elapsed) / 1 days);
    }

    /// @dev При трансфере доход настилается уходящему владельцу, а не утекает получателю.
    function test_TransferSettlesYieldToSender() public {
        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        place.transferFrom(alice, bob, PARK);

        assertEq(city.balanceOf(alice), 5e18); // Park-доход начислен уходящему alice
        assertEq(vault.pendingYield(PARK), 0); // клок сброшен на нового владельца
        assertEq(place.ownerOf(PARK), bob);
    }

    /// @dev Клок места стартует с минта, а не «задним числом» от запуска экономики.
    function test_MintStartsClockNotBackdated() public {
        vm.warp(block.timestamp + 100 days);
        place.mint(alice, Place.Category.Food, "ipfs://2"); // tokenId 2 на сдвинутом времени

        assertEq(vault.pendingYield(2), 0);
    }

    function test_OnlyPlaceCanSettle() public {
        vm.prank(alice);
        vm.expectRevert(YieldVault.OnlyPlace.selector);
        vault.settle(PARK, alice);
    }

    function test_PendingZeroForNonexistent() public view {
        assertEq(vault.pendingYield(999), 0);
    }
}
