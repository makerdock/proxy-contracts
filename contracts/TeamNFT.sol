// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract TeamNFT {
    // 0xuser: [ 1 => [ 2, 34, 5 ] ]
    mapping(address => mapping(uint256 => uint256[])[]) public userStakedNFTs;

    function updateStakedNFTs(address _user) public {}
}
