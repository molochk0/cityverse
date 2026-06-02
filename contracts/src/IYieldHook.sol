// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Хук, который Place дёргает при каждой смене владельца места, чтобы доход
///         настилался уходящему владельцу (`from`). На минте `from == address(0)`.
interface IYieldHook {
    function settle(uint256 tokenId, address from) external;
}
