// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {CityToken} from "../src/CityToken.sol";
import {Place} from "../src/Place.sol";
import {YieldVault} from "../src/YieldVault.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {Harberger} from "../src/Harberger.sol";

/// @notice Разворачивает все контракты Cityverse, связывает роли и засеивает места Воронежа.
///         Деплоер становится admin/treasury. Гоняется и на anvil (симуляция), и на тестнете
///         (с --rpc-url ... --broadcast).
contract Deploy is Script {
    uint256 constant MAX_SUPPLY = 50;
    uint256 constant TAX_RATE_BPS = 1000; // 10%/год
    uint256 constant HOOKAH_COUNT = 4;

    struct Deployment {
        CityToken city;
        Place place;
        YieldVault vault;
        Marketplace market;
        Harberger harberger;
    }

    function run() external returns (Deployment memory d) {
        address deployer = msg.sender;

        vm.startBroadcast();

        d.city = new CityToken(deployer);
        d.place = new Place(MAX_SUPPLY, deployer);
        d.vault = new YieldVault(d.place, d.city);
        d.market = new Marketplace(d.place, d.city);
        d.harberger = new Harberger(d.place, d.city, deployer, TAX_RATE_BPS); // treasury = deployer

        // Связи между контрактами:
        d.city.grantRole(d.city.MINTER_ROLE(), address(d.vault)); // vault печатает награды $CITY
        d.place.grantRole(d.place.MINTER_ROLE(), deployer); // deployer сеет места

        _seed(d.place, deployer);

        vm.stopBroadcast();

        _log(d);
    }

    function _seed(Place place, address to) internal {
        string[] memory parks = _parks();
        for (uint256 i = 0; i < parks.length; i++) {
            _mint(place, to, Place.Category.Park, parks[i]);
        }
        for (uint256 i = 1; i <= HOOKAH_COUNT; i++) {
            _mint(place, to, Place.Category.Food, string.concat("Hookah Lounge #", vm.toString(i)));
        }
    }

    function _mint(Place place, address to, Place.Category category, string memory name) internal {
        uint256 tokenId = place.totalMinted();
        place.mint(to, category, string.concat("ipfs://placeholder/", vm.toString(tokenId)));
        console.log(string.concat("  #", vm.toString(tokenId), " ", _label(category), " ", name));
    }

    function _parks() internal pure returns (string[] memory parks) {
        parks = new string[](4);
        parks[0] = "Central Park (Dynamo)";
        parks[1] = "Alye Parusa Park";
        parks[2] = "Orlyonok Park";
        parks[3] = "Koltsovsky Square";
    }

    function _label(Place.Category c) internal pure returns (string memory) {
        if (c == Place.Category.Park) return "Park";
        if (c == Place.Category.Food) return "Food";
        if (c == Place.Category.Transit) return "Transit";
        return "Landmark";
    }

    function _log(Deployment memory d) internal pure {
        console.log("CityToken: ", address(d.city));
        console.log("Place:     ", address(d.place));
        console.log("YieldVault:", address(d.vault));
        console.log("Marketplace:", address(d.market));
        console.log("Harberger: ", address(d.harberger));
    }
}
