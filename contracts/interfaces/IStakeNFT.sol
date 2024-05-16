// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IStakeNFT {
    function stakeNFTs(
        address _user,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external;
}
