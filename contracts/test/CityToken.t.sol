// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CityToken} from "../src/CityToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract CityTokenTest is Test {
    CityToken internal token;

    address internal admin = address(this);
    address internal minter = makeAddr("minter");
    address internal alice = makeAddr("alice");

    function setUp() public {
        token = new CityToken(admin);
    }

    function test_Metadata() public view {
        assertEq(token.name(), "Cityverse Token");
        assertEq(token.symbol(), "CITY");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
    }

    function test_AdminHasAdminRole() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_NonMinterCannotMint() public {
        // Кешируем роль ДО prank: иначе token.MINTER_ROLE() стал бы "следующим вызовом" и съел prank.
        bytes32 role = token.MINTER_ROLE();
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role)
        );
        token.mint(alice, 1e18);
    }

    function test_MinterCanMint() public {
        token.grantRole(token.MINTER_ROLE(), minter);

        vm.prank(minter);
        token.mint(alice, 5e18);

        assertEq(token.balanceOf(alice), 5e18);
        assertEq(token.totalSupply(), 5e18);
    }

    function test_AdminCanRevokeMinter() public {
        bytes32 role = token.MINTER_ROLE();
        token.grantRole(role, minter);
        token.revokeRole(role, minter);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, minter, role)
        );
        token.mint(alice, 1e18);
    }

    function testFuzz_MinterMintsArbitraryAmount(uint96 amount) public {
        token.grantRole(token.MINTER_ROLE(), minter);

        vm.prank(minter);
        token.mint(alice, amount);

        assertEq(token.balanceOf(alice), amount);
        assertEq(token.totalSupply(), amount);
    }
}
