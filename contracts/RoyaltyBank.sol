// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";

contract RoyaltyBank is BackendGateway {
    mapping(uint256 => uint256) public royalties;

    // @abhishek: need to secure this function to avoid any direct external calls
    function updateRewardsMapping(uint256 id, uint256 reward) public {
        if (royalties[id] == 0) {
            royalties[id] = reward;
        } else {
            royalties[id] += reward;
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
