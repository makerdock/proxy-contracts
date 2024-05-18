// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IRoyaltyContract {
    function updateRewardsMapping(uint256 id, uint256 reward) external;
}
