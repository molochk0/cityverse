// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Place} from "../src/Place.sol";

/// @notice Разворачивает Place и засеивает минимальный набор мест Воронежа.
///         Парки — реальные, кальянные — плейсхолдеры (заменим позже).
///         tokenURI пока заглушка ipfs://placeholder/<id> — реальные метаданные/IPFS будут в отдельной фазе.
contract SeedVoronezh is Script {
    uint256 constant MAX_SUPPLY = 50;
    uint256 constant HOOKAH_COUNT = 4;

    function run() external returns (Place place) {
        address deployer = msg.sender;

        vm.startBroadcast();

        place = new Place(MAX_SUPPLY, deployer);
        // deployer — admin контракта; выдаём себе MINTER, чтобы засеять места.
        place.grantRole(place.MINTER_ROLE(), deployer);

        string[] memory parks = _parks();
        for (uint256 i = 0; i < parks.length; i++) {
            _seed(place, deployer, Place.Category.Park, parks[i]);
        }

        for (uint256 i = 1; i <= HOOKAH_COUNT; i++) {
            _seed(place, deployer, Place.Category.Food, string.concat("Hookah Lounge #", vm.toString(i)));
        }

        vm.stopBroadcast();

        console.log("Place deployed at:", address(place));
        console.log("Total seeded:", place.totalMinted());
    }

    function _seed(Place place, address to, Place.Category category, string memory name) internal {
        uint256 tokenId = place.totalMinted();
        string memory uri = string.concat("ipfs://placeholder/", vm.toString(tokenId));
        place.mint(to, category, uri);
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
}
