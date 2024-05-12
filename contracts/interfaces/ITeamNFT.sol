// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ITeamNFT {
    function stakedNFTs(
        address _user,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) external;
}
