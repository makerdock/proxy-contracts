// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, TokenSupplyExceeded, InsufficientBalance, InsufficientFunds, OutOfRangeRating} from "./utils/Errors.sol";
import {ITeamNFT} from "./interfaces/ITeamNFT.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "hardhat/console.sol";

contract CasterNFT is
    ERC1155,
    Ownable,
    Pausable,
    BackendGateway,
    ERC1155Holder
{
    address public TEAM_NFT_CONTRACT = address(0);
    IERC20 erc20Instance;

    address public TREAUSRY = address(0);
    address public POOL_ADDRESS = address(0);
    address public ROYALTY_ADDRESS = address(0);
    // address public constant LIQUIDITY_ADDRESS = address(0);

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

    constructor(address _erc20Address) ERC1155("https://ipfs.io/ipfs/QmZ9") {
        erc20Instance = IERC20(_erc20Address);
    }

    function currentSupply(uint256 id) public view returns (uint256) {
        return tokenSupply[id];
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Holder, ERC1155) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function stakeNFTs(
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public {
        uint256 totalRating = 0;

        for (uint256 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= balanceOf(msg.sender, _ids[i])) {
                console.log("Insufficient funds");
                revert InsufficientBalance(msg.sender, _ids[i], _amounts[i]);
            }

            totalRating += tokenRating[_ids[i]];
        }

        console.log("ratings -> ", totalRating);

        //Todo: Check the number of NFTs per team => id*amount
        if (totalRating > TEAM_RATINGS_CAP || _ids.length > 5) {
            revert OutOfRangeRating(totalRating, TEAM_RATINGS_CAP);
        }

        emit StakeNFTs(msg.sender, _ids, _amounts);

        ITeamNFT teamNFTContract = ITeamNFT(TEAM_NFT_CONTRACT);
        teamNFTContract.stakeNFTs(msg.sender, _ids, _amounts);
    }

    function updateRatings(
        uint256[] memory ids,
        uint256[] memory ratings
    ) public backendGateway {
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
        // TODO: send eth via .call{ ... }
        payable(msg.sender).transfer(fundsToSendToUser);
        safeTransferFrom(msg.sender, address(this), id, amount, "");
    }

    function mintForfeitedNFT(
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public payable {
        if (balanceOf(address(this), id) < amount) {
            revert InsufficientBalance(address(this), id, amount);
        }

        if (msg.value < tokenPrice[id] * amount) {
            revert InsufficientFunds(msg.sender, tokenPrice[id] * amount);
        }

        tokenPrice[id] += (tokenPrice[id] * PRICE_MULTIPLIER) / 100;

        distributeFunds(msg.value);

        safeTransferFrom(address(this), msg.sender, id, amount, data);
    }

    function mint(uint256 id, uint256 amount) public payable {
        if (currentSupply(id) == MAX_SUPPLY) {
            revert TokenSupplyExceeded(id, MAX_SUPPLY, msg.sender);
        }

        if (tokenPrice[id] == 0) {
            tokenPrice[id] = 0.01 ether;
        }

        uint256 estimatedBondingPrice = getBondingCurvePrice(
            tokenSupply[id] + amount
        );

        if (msg.value < estimatedBondingPrice) {
            revert InsufficientFunds(msg.sender, estimatedBondingPrice);
        }

        distributeFunds(msg.value);

        _mint(msg.sender, id, amount, "");

        tokenSupply[id] += amount;
        tokenPrice[id] = estimatedBondingPrice;
    }

    function mintBatch(
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public payable {
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

        distributeFunds(totalPrice);

        _mintBatch(msg.sender, ids, amounts, data);
    }

    function distributeFunds(uint256 totalPrice) internal {
        uint256 treasuryCut = (totalPrice * TREAUSRY_CUT) / 1000;
        uint256 poolCut = (totalPrice * POOL_CUT) / 1000;
        uint256 creatorCut = (totalPrice * CREATOR_CUT) / 1000;

        console.log("sending funds", treasuryCut, poolCut, creatorCut);

        // TODO: send eth via .call{ ... }
        (bool sentToTreasury, bytes memory data) = TREAUSRY.call{
            value: treasuryCut
        }("");
        require(sentToTreasury, "Failed to send to treasury");

        (bool sentToPool, bytes memory _pData) = POOL_ADDRESS.call{
            value: poolCut
        }("");
        require(sentToPool, "Failed to send to Pool");

        // (bool sentToRoyalty, bytes memory _rData) = ROYALTY_ADDRESS.call{value: creatorCut}("");
        // require(sentToRoyalty, "Failed to send to creator");
    }

    function updateTreasuryAddress(
        address _newTreasuryAddress
    ) public onlyOwner {
        TREAUSRY = _newTreasuryAddress;
    }

    function getMintPriceForToken(
        uint256 _tokenId,
        uint256 _amount
    ) public view returns (uint256) {
        uint256 totalPrice = 0;
        uint256 tempCurrentSupply = tokenSupply[_tokenId];

        for (uint256 i = 0; i < _amount; i++) {
            if (tempCurrentSupply + i >= MAX_SUPPLY) {
                revert TokenSupplyExceeded(_tokenId, MAX_SUPPLY, msg.sender);
            }

            uint256 bondingPrice = getBondingCurvePrice(tempCurrentSupply + i);

            totalPrice += bondingPrice;
        }

        return totalPrice;
    }

    function getBondingCurvePrice(
        uint256 _currentTokenId
    ) internal pure returns (uint256) {
        // TODO: @abhishek fix the calculation
        // (currentToken ** 1.05) x 60
        return (_currentTokenId ** 1) * 60;
    }

    function updatePoolAddress(address _newPoolAddress) public onlyOwner {
        POOL_ADDRESS = _newPoolAddress;
    }

    function updateTeamNFTAddress(address _newTeamNFTAddress) public onlyOwner {
        TEAM_NFT_CONTRACT = _newTeamNFTAddress;
    }

    function updateRoyaltyAddress(address _newRoyaltyAddress) public onlyOwner {
        ROYALTY_ADDRESS = _newRoyaltyAddress;
    }

    function _burn(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }

    function _burnBatch(address from, uint256 id) internal virtual {
        revert InvalidAction(from, id);
    }
}
