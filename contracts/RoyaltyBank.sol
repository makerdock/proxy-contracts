// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvalidAddress, UnAuthorizedAction, InsufficientFunds} from "./utils/Errors.sol";

contract RoyaltyBank is BackendGateway {
    address public TOKEN_CONTRACT_ADDRESS = address(0);
    address public CASTER_NFT_ADDRESS = address(0);
    mapping(uint256 => uint256) public royalties;

    function updateRewardsMapping(uint256 id, uint256 reward) public {
        if (msg.sender != CASTER_NFT_ADDRESS) {
            revert UnAuthorizedAction(msg.sender);
        }

        if (royalties[id] == 0) {
            royalties[id] = reward;
        } else {
            royalties[id] += reward;
        }
    }

    function updateCasterNFTAddress(
        address _nftMintingContract
    ) public onlyOwner {
        if (_newTokenContract == address(0)) {
            revert InvalidAddress(_newTokenContract);
        }
        CASTER_NFT_ADDRESS = _nftMintingContract;
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

        IERC20 token = IERC20(TOKEN_CONTRACT_ADDRESS);
        if (token.balanceOf(address(this)) >= rewards) {
            royalties[id] = 0;

            IERC20(TOKEN_CONTRACT_ADDRESS).transfer(creatorAddress, rewards);
        } else {
            revert InsufficientFunds(address(this), rewards);
        }
    }
}
