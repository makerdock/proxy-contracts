// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";

contract RoyaltyBank is BackendGateway {
    mapping(uint256 => uint256) public royalties;

    // 1434 <> 500 DEGEN

    // How to secure this?
    // maybe whitelist it?
    function updateRewardsMapping(
        uint256[] memory ids,
        uint256[] memory rewards
    ) public {
        for (uint256 i = 0; i < ids.length; i++) {
            royalties[ids[i]] = rewards[i];
        }
    }

    function claimReward(
        uint256 id,
        address creatorAddress
    ) public backendGateway {
        royalties[id] = 0;
        payable(creatorAddress).transfer(royalties[id]);
    }
}
