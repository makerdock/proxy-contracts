// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {InvalidAction, TokenSupplyExceeded, InsufficientBalance, InsufficientFunds, OutOfRangeRating} from "./Errors.sol";

contract CasterNFT is ERC1155, Ownable, Pausable {
    address public constant TEAM_NFT_CONTRACT = address(0);

    address public constant TREAUSRY = address(0);
    address public constant POOL_ADDRESS = address(0);
    address public constant LIQUIDITY_ADDRESS = address(0);
    // address public constant ROYALTY_ADDRESS = address(0);

    uint256 public constant TREAUSRY_CUT = 200; // 200 / 100 = 2%
    uint256 public constant CREATOR_CUT = 600; // 600 / 100 = 6%
    uint256 public constant POOL_CUT = 200; // 200 / 100 = 2%

    uint256 public constant MAX_SUPPLY = 500;
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant PRICE_MULTIPLIER = 150;
    uint256 public constant TEAM_RATINGS_CAP = 250;

    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenStaked;
    mapping(uint256 => uint256) public tokenPrice;
    mapping(uint256 => uint256) public tokenRating;

    event StakeNFTs(address indexed staker, uint256[] ids, uint256[] amounts);

    constructor() ERC1155("https://ipfs.io/ipfs/QmZ9") {}

    function currentSupply(uint256 id) public view returns (uint256) {
        return tokenSupply[id];
    }

    function stakeNFTs(uint256[] memory ids, uint256[] memory amounts) public {
        uint256 totalRating = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            if (amounts[i] > balanceOf(msg.sender, ids[i])) {
                revert InsufficientBalance(msg.sender, ids[i], amounts[i]);
            }

            totalRating += tokenRating[ids[i]];
        }

        if (totalRating > TEAM_RATINGS_CAP) {
            revert OutOfRangeRating(totalRating, TEAM_RATINGS_CAP);
        }

        emit StakeNFTs(msg.sender, ids, amounts);
        safeBatchTransferFrom(msg.sender, TEAM_NFT_CONTRACT, ids, amounts, "");
    }

    function updateRatings(
        uint256[] memory ids,
        uint256[] memory ratings
    ) public onlyOwner {
        for (uint256 i = 0; i < ids.length; i++) {
            tokenRating[ids[i]] = ratings[i];
        }
    }

    function forfeitNFT(uint256 id, uint256 amount) public {
        if (amount > balanceOf(msg.sender, id)) {
            revert InsufficientBalance(msg.sender, id, amount);
        }

        uint256 fundsToSendToUser = 0;

        for (uint256 i = 0; i < amount; i++) {
            fundsToSendToUser += tokenPrice[id];
            tokenPrice[id] =
                tokenPrice[id] -
                (tokenPrice[id] * PRICE_MULTIPLIER) /
                100;
        }

        payable(msg.sender).transfer(fundsToSendToUser);

        safeTransferFrom(msg.sender, address(this), id, amount, "");
    }

    function mintForfeitedNFT(
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public payable onlyOwner {
        if (balanceOf(address(this), id) < amount) {
            revert InsufficientBalance(address(this), id, amount);
        }

        if (msg.value < tokenPrice[id] * amount) {
            revert InsufficientFunds(msg.sender, tokenPrice[id] * amount);
        }

        tokenPrice[id] =
            tokenPrice[id] +
            (tokenPrice[id] * PRICE_MULTIPLIER) /
            100;

        safeTransferFrom(address(this), msg.sender, id, amount, data);
    }

    function mint(
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public payable onlyOwner {
        if (currentSupply(id) < MAX_SUPPLY) {
            revert TokenSupplyExceeded(id, MAX_SUPPLY, msg.sender);
        }

        uint256 totalPrice = tokenPrice[id] * amount;

        if (msg.value < totalPrice) {
            revert InsufficientFunds(msg.sender, totalPrice);
        }

        tokenSupply[id] += amount;
        tokenPrice[id] =
            tokenPrice[id] +
            (tokenPrice[id] * PRICE_MULTIPLIER) /
            100;

        uint256 treasuryCut = (totalPrice * TREAUSRY_CUT) / 1000;
        uint256 poolCut = (totalPrice * POOL_CUT) / 1000;

        payable(TREAUSRY).transfer(treasuryCut);
        payable(POOL_ADDRESS).transfer(poolCut);

        _mint(msg.sender, id, amount, data);
    }

    function mintBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public payable onlyOwner {
        uint256 totalPrice = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            if (currentSupply(ids[i]) < MAX_SUPPLY) {
                revert TokenSupplyExceeded(ids[i], MAX_SUPPLY, msg.sender);
            }

            totalPrice += tokenPrice[ids[i]] * amounts[i];
        }

        if (msg.value < totalPrice) {
            revert InsufficientFunds(msg.sender, totalPrice);
        }

        for (uint256 i = 0; i < ids.length; i++) {
            tokenSupply[ids[i]] += amounts[i];
            tokenPrice[ids[i]] = (tokenPrice[ids[i]] * PRICE_MULTIPLIER) / 100;
        }

        uint256 treasuryCut = (totalPrice * TREAUSRY_CUT) / 1000;
        uint256 poolCut = (totalPrice * POOL_CUT) / 1000;

        payable(TREAUSRY).transfer(treasuryCut);
        payable(POOL_ADDRESS).transfer(poolCut);

        _mintBatch(msg.sender, ids, amounts, data);
    }

    function _burn(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }

    function _burnBatch(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }
}
