// SPDX-License-Identifier: MIT

pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {InvalidAction, TokenSupplyExceeded, InsufficientBalance, InsufficientFunds} from "./Errors.sol";

contract CasterNFT is ERC1155, Ownable, Pausable {
    address public constant TEAM_NFT_CONTRACT = address(0);
    uint256 public constant MAX_SUPPLY = 500;
    uint256 public constant PRICE = 0.1 ether;
    uint256 public constant PRICE_MULTIPLIER = 150;

    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenStaked;
    mapping(uint256 => uint256) public tokenPrice;

    event StakeNFTs(address indexed staker, uint256[] ids, uint256[] amounts);

    constructor() ERC1155("https://ipfs.io/ipfs/QmZ9") {}

    function currentSupply(uint256 id) public view returns (uint256) {
        return tokenSupply[id];
    }

    function stakeNFTs(uint256[] memory ids, uint256[] memory amounts) public {
        for (uint256 i = 0; i < ids.length; i++) {
            if (amounts[i] > balanceOf(msg.sender, ids[i])) {
                revert InsufficientBalance(msg.sender, ids[i], amounts[i]);
            }
        }

        emit StakeNFTs(msg.sender, ids, amounts);
        safeBatchTransferFrom(msg.sender, TEAM_NFT_CONTRACT, ids, amounts, "");
    }

    function mint(
        address account,
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

        tokenPrice[id] = (tokenPrice[id] * PRICE_MULTIPLIER) / 100;

        _mint(account, id, amount, data);
    }

    function mintBatch(
        address account,
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

        _mintBatch(account, ids, amounts, data);
    }

    function _burn(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }

    function _burnBatch(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }
}
