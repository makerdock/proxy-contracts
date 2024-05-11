// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract RoyaltyBank {
    // TODO: figure a way to make this safer
    // or we can drive claiming through backend
    mapping(uint256 => uint256) public royalties;

    function updateRewardsMapping(
        uint256[] memory ids,
        uint256[] memory rewards
    ) public {
        for (uint256 i = 0; i < ids.length; i++) {
            royalties[ids[i]] = rewards[i];
        }
    }

    function claimReward(uint256 id) public {
        royalties[id] = 0;
        payable(msg.sender).transfer(royalties[id]);
    }
}
