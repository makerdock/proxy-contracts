// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, ForbiddenMethod, TokenSupplyExceeded, InsufficientBalance} from "./utils/Errors.sol";
import {IStakeNFT} from "./interfaces/IStakeNFT.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IRoyaltyContract} from "./interfaces/IRoyaltyContract.sol";

contract CasterNFT is ERC1155, Ownable, Pausable, BackendGateway {
    IERC20 public erc20Instance;

    address public TREASURY_ADDRESS = address(0);
    address public PRIZE_POOL_ADDRESS = address(0);
    address public ROYALTY_CONTRACT_ADDRESS = address(0);

    mapping(address => bool) private whitelistedStakingContracts;

    uint8 public constant TREASURY_CUT = 20; // 20 / 100 = 2%
    uint8 public constant CREATOR_CUT = 60; // 60 / 100 = 6%
    uint8 public constant POOL_CUT = 20; // 20 / 100 = 2%

    uint16 public constant MAX_SUPPLY = 500;
    uint8 public constant PRICE = 80;

    mapping(uint256 => uint16) public tokenSupply;
    mapping(uint256 => bool) public mintSelfNFT;

    event Minted(address indexed minter, uint256 indexed id, uint8 amount);

    constructor(address _erc20Address) ERC1155("https://ipfs.io/ipfs/QmZ9") {
        erc20Instance = IERC20(_erc20Address);
    }

    function currentSupply(uint256 id) public view returns (uint256) {
        return tokenSupply[id];
    }

    function stakeNFTs(
        address _stakingContractAddress,
        uint256[] memory _ids,
        uint256[] memory _amounts, // safeTransferFrom needs uint256
        bytes memory _signature,
        uint32 _nonce
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= balanceOf(msg.sender, _ids[i])) {
                revert InsufficientBalance(msg.sender, _ids[i], _amounts[i]);
            }
        }

        IStakeNFT stakingNFTContract = IStakeNFT(_stakingContractAddress);
        stakingNFTContract.stakeNFTs(
            msg.sender,
            _ids,
            _amounts,
            _signature,
            _nonce
        );
    }

    function forfeitNFT(uint256 id, uint8 amount) public {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (amount > balanceOf(msg.sender, id)) {
            revert InsufficientBalance(msg.sender, id, amount);
        }

        super._burn(msg.sender, id, amount);
        tokenSupply[id] -= amount;

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

    function mint(uint256 id, uint16 amount) public payable {
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
        uint16 _amount
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

    function updateWhitelistedStakingContracts(
        address _stakingContractAddress,
        bool _isWhitelisted
    ) public onlyOwner {
        whitelistedStakingContracts[_stakingContractAddress] = _isWhitelisted;
    }

    function updateTreasuryAddress(
        address _newTreasuryAddress
    ) public onlyOwner {
        TREASURY_ADDRESS = _newTreasuryAddress;
    }

    function updatePrizePoolAddress(address _newPoolAddress) public onlyOwner {
        PRIZE_POOL_ADDRESS = _newPoolAddress;
    }

    function updateRoyaltyContractAddress(
        address _newRoyaltyContractAddress
    ) public onlyOwner {
        ROYALTY_CONTRACT_ADDRESS = _newRoyaltyContractAddress;
    }

    function _burn(address from, uint256 id) internal virtual {
        revert ForbiddenMethod();
    }

    function _burnBatch(address from, uint256 id) internal virtual {
        revert ForbiddenMethod();
    }
}
