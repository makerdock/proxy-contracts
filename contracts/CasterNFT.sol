// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, ForbiddenMethod, TokenSupplyExceeded, InsufficientBalance, InsufficientFunds, OutOfRangeRating} from "./utils/Errors.sol";
import {IStakeNFT} from "./interfaces/IStakeNFT.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract CasterNFT is
    ERC1155,
    Ownable,
    Pausable,
    BackendGateway,
    ERC1155Holder
{
    IERC20 public erc20Instance;

    address public STAKING_NFT_CONTRACT = address(0);
    address public TREAUSRY = address(0);
    address public POOL_ADDRESS = address(0);
    address public ROYALTY_ADDRESS = address(0);
    // address public constant LIQUIDITY_ADDRESS = address(0);

    uint256 public constant TREAUSRY_CUT = 20; // 20 / 100 = 2%
    uint256 public constant CREATOR_CUT = 60; // 60 / 100 = 6%
    uint256 public constant POOL_CUT = 20; // 20 / 100 = 2%

    uint256 public constant MAX_SUPPLY = 500;
    uint256 public constant PRICE = 80;
    uint256 public constant PRICE_MULTIPLIER = 150;
    uint256 public constant TEAM_RATINGS_CAP = 250;

    mapping(uint256 => uint256) public tokenSupply;
    mapping(uint256 => uint256) public tokenRating;
    mapping(uint256 => bool) public mintSelfNFT;

    event Minted(address indexed minter, uint256 indexed id, uint256 amount);
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
                revert InsufficientBalance(msg.sender, _ids[i], _amounts[i]);
            }

            totalRating += tokenRating[_ids[i]];
        }

        //Todo: Check the number of NFTs per team => id*amount
        if (totalRating > TEAM_RATINGS_CAP || _ids.length > 5) {
            revert OutOfRangeRating(totalRating, TEAM_RATINGS_CAP);
        }

        emit StakeNFTs(msg.sender, _ids, _amounts);

        IStakeNFT stakingNFTContract = IStakeNFT(STAKING_NFT_CONTRACT);
        stakingNFTContract.stakeNFTs(msg.sender, _ids, _amounts);
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
            uint256 estimatedBondingPrice = getBondingCurvePrice(
                tokenSupply[id] - i + 1
            );
            fundsToSendToUser += estimatedBondingPrice;
        }

        distributeFunds(fundsToSendToUser);

        uint256 leftFunds = fundsToSendToUser - (fundsToSendToUser * 9) / 100;

        erc20Instance.transfer(msg.sender, leftFunds);

        safeTransferFrom(msg.sender, address(this), id, amount, "");
    }

    function mintForfeitedNFT(uint256 id, uint256 amount) public payable {
        if (balanceOf(address(this), id) < amount) {
            revert InsufficientBalance(address(this), id, amount);
        }

        uint256 estimatedBondingPrice = getBondingCurvePrice(
            tokenSupply[id] + amount
        );
        erc20Instance.transferFrom(
            msg.sender,
            address(this),
            estimatedBondingPrice
        );

        distributeFunds(estimatedBondingPrice);

        tokenSupply[id] += amount;
        safeTransferFrom(address(this), msg.sender, id, amount, "");
    }

    function mint(uint256 id, uint256 amount) public payable {
        if (currentSupply(id) == MAX_SUPPLY) {
            revert TokenSupplyExceeded(id, MAX_SUPPLY, msg.sender);
        }

        uint256 mintPrice = 0;

        if (tokenSupply[id] == 0 && amount == 1) {
            mintPrice = PRICE;
        } else {
            for (uint256 i = 0; i < amount; i++) {
                uint256 estimatedBondingPrice = getBondingCurvePrice(
                    tokenSupply[id] + (i + 1)
                );
                mintPrice += estimatedBondingPrice;
            }
        }

        erc20Instance.transferFrom(msg.sender, address(this), mintPrice);
        distributeFunds(mintPrice);
        _mint(msg.sender, id, amount, "");

        tokenSupply[id] += amount;
    }

    function mintSelfCreatorNFT(
        address _userAddress,
        uint256 _tokenId
    ) public backendGateway {
        if (mintSelfNFT[_tokenId] == true) {
            revert InvalidAction(_userAddress, _tokenId);
        }

        _mint(_userAddress, _tokenId, 1, "");
        tokenSupply[_tokenId] += 1;
    }

    function distributeFunds(uint256 totalPrice) public {
        uint256 treasuryCut = (totalPrice * TREAUSRY_CUT) / 1000;
        uint256 poolCut = (totalPrice * POOL_CUT) / 1000;
        uint256 creatorCut = (totalPrice * CREATOR_CUT) / 1000;

        erc20Instance.transfer(TREAUSRY, treasuryCut);
        erc20Instance.transfer(POOL_ADDRESS, poolCut);
        erc20Instance.transfer(ROYALTY_ADDRESS, creatorCut);
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

    function updateTreasuryAddress(
        address _newTreasuryAddress
    ) public onlyOwner {
        TREAUSRY = _newTreasuryAddress;
    }

    function getBondingCurvePrice(
        uint256 _currentTokenId
    ) internal pure returns (uint256) {
        // TODO: @abhishek fix the calculation
        // (currentToken ** 1.05) x 60
        return ((_currentTokenId * 1) * 60);
    }

    function updatePoolAddress(address _newPoolAddress) public onlyOwner {
        POOL_ADDRESS = _newPoolAddress;
    }

    function updateStakeNFTAddress(
        address _newStakeNFTAddress
    ) public onlyOwner {
        STAKING_NFT_CONTRACT = _newStakeNFTAddress;
    }

    function updateRoyaltyAddress(address _newRoyaltyAddress) public onlyOwner {
        ROYALTY_ADDRESS = _newRoyaltyAddress;
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        revert ForbiddenMethod();
    }

    function _burn(address from, uint256 id) internal virtual {
        revert ForbiddenMethod();
    }

    function _burnBatch(address from, uint256 id) internal virtual {
        revert ForbiddenMethod();
    }
}
