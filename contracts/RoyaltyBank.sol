// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvalidAddress} from "./utils/Errors.sol";

contract RoyaltyBank is BackendGateway {
    address public TOKEN_CONTRACT_ADDRESS = address(0);
    mapping(uint256 => uint256) public royalties;

    // @abhishek: need to secure this function to avoid any direct external calls
    function updateRewardsMapping(uint256 id, uint256 reward) public {
        if (royalties[id] == 0) {
            royalties[id] = reward;
        } else {
            royalties[id] += reward;
        }
    }

    function updateTokenContractAddress(
        address _newTokenContract
    ) public onlyOwner {
        if (_newTokenContract == address(0)) {
            revert InvalidAddress(_newTokenContract);
        }
        TOKEN_CONTRACT_ADDRESS = _newTokenContract;
    }

    function claimReward(
        uint256 id,
        address creatorAddress
    ) public backendGateway {
        uint256 rewards = royalties[id];

        royalties[id] = 0;

        IERC20(TOKEN_CONTRACT_ADDRESS).transfer(creatorAddress, rewards);
    }
}
