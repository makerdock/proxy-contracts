// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

error InvalidAction(address from, uint256 id);
error TokenSupplyExceeded(uint256 id, uint256 maxSupply, address minter);
error InsufficientBalance(address from, uint256 id, uint256 balance);
error InsufficientFunds(address from, uint256 amount);
error OutOfRangeRating(uint256 currentRating, uint256 maxRating);
