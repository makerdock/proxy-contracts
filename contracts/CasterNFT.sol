// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, ForbiddenMethod, TokenSupplyExceeded, InsufficientBalance} from "./utils/Errors.sol";
import {IStakeNFT} from "./interfaces/IStakeNFT.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IRoyaltyContract} from "./interfaces/IRoyaltyContract.sol";

contract CasterNFT is
    ERC1155,
    Ownable,
    Pausable,
    BackendGateway,
    ERC1155Holder
{
    IERC20 public erc20Instance;

    address public STAKING_CONTRACT_ADDRESS = address(0);
    address public TREASURY_ADDRESS = address(0);
    address public PRIZE_POOL_ADDRESS = address(0);
    address public ROYALTY_CONTRACT_ADDRESS = address(0);

    uint256 public constant TREASURY_CUT = 20; // 20 / 100 = 2%
    uint256 public constant CREATOR_CUT = 60; // 60 / 100 = 6%
    uint256 public constant POOL_CUT = 20; // 20 / 100 = 2%

    uint256 public constant MAX_SUPPLY = 500;
    uint256 public constant PRICE = 80;
    uint256 public constant MAX_NFT_TEAM = 5; // 10

    mapping(uint256 => uint256) public tokenSupply;
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
    ) public view virtual override(ERC1155Receiver, ERC1155) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function stakeNFTs(
        // address _stakingContractInteraction, maybe pass the staking contract address here?
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes32[] calldata signature
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= balanceOf(msg.sender, _ids[i])) {
                revert InsufficientBalance(msg.sender, _ids[i], _amounts[i]);
            }
        }

        IStakeNFT stakingNFTContract = IStakeNFT(STAKING_CONTRACT_ADDRESS);
        stakingNFTContract.stakeNFTs(msg.sender, _ids, _amounts);

        /**
         * or
         *
         * IStakeNFT stakingNFTContract = IStakeNFT(_stakingContractInteraction);
         * stakingNFTContract.stakeNFTs(msg.sender, _ids, _amounts, signature);
         */

        emit StakeNFTs(msg.sender, _ids, _amounts);
    }

    function forfeitNFT(uint256 id, uint256 amount) public {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

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

        safeTransferFrom(msg.sender, address(this), id, amount, "");
        distributeFunds(fundsToSendToUser, id, amount);

        uint256 leftFunds = fundsToSendToUser - (fundsToSendToUser * 9) / 100;
        erc20Instance.transfer(msg.sender, leftFunds);
    }

    function mintForfeitedNFT(uint256 id, uint256 amount) public payable {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (amount > balanceOf(address(this), id)) {
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
        distributeFunds(estimatedBondingPrice, id, amount);

        tokenSupply[id] += amount;

        safeTransferFrom(address(this), msg.sender, id, amount, "");
    }

    function mint(uint256 id, uint256 amount) public payable {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (currentSupply(id) == MAX_SUPPLY) {
            revert TokenSupplyExceeded(id, MAX_SUPPLY, msg.sender);
        }

        uint256 mintPrice = 0;

        // if user is minting first token
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
        distributeFunds(mintPrice, id, amount);
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

    function distributeFunds(
        uint256 totalPrice,
        uint256 _id,
        uint256 _amount
    ) internal {
        uint256 treasuryCut = (totalPrice * TREASURY_CUT) / 1000;
        uint256 poolCut = (totalPrice * POOL_CUT) / 1000;
        uint256 creatorCut = (totalPrice * CREATOR_CUT) / 1000;

        erc20Instance.transfer(TREASURY_ADDRESS, treasuryCut);
        erc20Instance.transfer(PRIZE_POOL_ADDRESS, poolCut);
        erc20Instance.transfer(ROYALTY_CONTRACT_ADDRESS, creatorCut);

        IRoyaltyContract(ROYALTY_CONTRACT_ADDRESS).updateRewardsMapping(
            _id,
            _amount
        );
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
    ) public pure returns (uint256) {
        // TODO: @abhishek fix the calculation
        // (currentToken ** 1.05) x 60
        return ((_currentTokenId * 1) * 60);
    }

    function updateTreasuryAddress(
        address _newTreasuryAddress
    ) public onlyOwner {
        TREASURY_ADDRESS = _newTreasuryAddress;
    }

    function updatePrizePoolAddress(address _newPoolAddress) public onlyOwner {
        PRIZE_POOL_ADDRESS = _newPoolAddress;
    }

    function updateStakingContractAddress(
        address _newStakingAddress
    ) public onlyOwner {
        STAKING_CONTRACT_ADDRESS = _newStakingAddress;
    }

    function updateRoyaltyContractAddress(
        address _newRoyaltyContractAddress
    ) public onlyOwner {
        ROYALTY_CONTRACT_ADDRESS = _newRoyaltyContractAddress;
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
