// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, InsufficientAllowance, TokenSupplyExceeded, InsufficientBalance} from "./utils/Errors.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IRoyaltyContract} from "./interfaces/IRoyaltyContract.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// import {ABDKMathQuadLib} from "./utils/ABDKMathQuadLib.sol";

contract CasterNFT is
    ERC1155,
    Ownable,
    Pausable,
    BackendGateway,
    ReentrancyGuard
{
    IERC20 public erc20Instance;

    address public TREASURY_ADDRESS;
    address public PRIZE_POOL_ADDRESS;
    address public ROYALTY_CONTRACT_ADDRESS;

    uint8 public constant TREASURY_CUT = 2;
    uint8 public constant CREATOR_CUT = 6;
    uint8 public constant POOL_CUT = 2;

    uint16 public maxSupply = 500;
    uint8 public erc20Decimals = 18;

    mapping(uint256 => uint16) public currentTokenSupply;
    mapping(address => bool) public mintSelfNFT;

    event MintedNFT(address indexed user, uint256 indexed id, uint8 amount);
    event ForfeitedNFT(address indexed user, uint256 indexed id, uint8 amount);
    event SelfMint(address indexed user, uint256 indexed id);

    constructor(address _erc20Address) ERC1155("https://ipfs.io/ipfs/QmZ9") {
        erc20Instance = IERC20(_erc20Address);
    }

    function currentSupply(uint256 id) public view returns (uint256) {
        return currentTokenSupply[id];
    }

    function updateMaxSupply(
        uint16 _newMaxSupply
    ) public onlyOwner whenNotPaused {
        maxSupply = _newMaxSupply;
    }

    function mint(uint256 id, uint8 amount) public payable whenNotPaused {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (currentSupply(id) == maxSupply) {
            revert TokenSupplyExceeded(id, maxSupply, msg.sender);
        }

        uint256 mintPrice = 0;

        for (uint256 i = 1; i <= amount; i++) {
            uint256 estimatedBondingPrice = getBondingCurvePrice(
                currentTokenSupply[id] + i
            );
            mintPrice += estimatedBondingPrice;
        }

        mintPrice +=
            (mintPrice * (TREASURY_CUT + CREATOR_CUT + POOL_CUT)) /
            100;

        mintPrice = formatPrice(mintPrice);

        if (mintPrice > erc20Instance.allowance(msg.sender, address(this))) {
            revert InsufficientAllowance(msg.sender, mintPrice);
        }

        erc20Instance.transferFrom(msg.sender, address(this), mintPrice);
        distributeFunds(mintPrice, id);
        _mint(msg.sender, id, amount, "");

        currentTokenSupply[id] += amount;

        emit MintedNFT(msg.sender, id, amount);
    }

    function mintSelfCreatorNFT(
        address _userAddress,
        uint256 _tokenId
    ) public backendGateway whenNotPaused {
        if (mintSelfNFT[_userAddress] == true) {
            revert InvalidAction(_userAddress, _tokenId);
        }

        mintSelfNFT[_userAddress] = true;

        _mint(_userAddress, _tokenId, 1, "");
        currentTokenSupply[_tokenId] += 1;

        emit SelfMint(_userAddress, _tokenId);
    }

    function forfeitNFT(
        uint256 id,
        uint8 amount
    ) public whenNotPaused nonReentrant {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (amount > balanceOf(msg.sender, id)) {
            revert InsufficientBalance(msg.sender, id, amount);
        }

        currentTokenSupply[id] -= amount;

        uint256 fundsToSendToUser = 0;

        for (uint256 i = 1; i <= amount; i++) {
            uint256 estimatedBondingPrice = getBondingCurvePrice(
                currentTokenSupply[id] - i
            );
            fundsToSendToUser += estimatedBondingPrice;
        }

        fundsToSendToUser = formatPrice(fundsToSendToUser);

        uint256 leftFunds = (fundsToSendToUser *
            (100 - (TREASURY_CUT + POOL_CUT + CREATOR_CUT))) / 100;

        super._burn(msg.sender, id, amount);

        distributeFunds(fundsToSendToUser, id);
        erc20Instance.transfer(msg.sender, leftFunds);

        emit ForfeitedNFT(msg.sender, id, amount);
    }

    function distributeFunds(uint256 totalPrice, uint256 _id) internal {
        uint256 treasuryCut = (totalPrice * TREASURY_CUT) / 100;
        uint256 poolCut = (totalPrice * POOL_CUT) / 100;
        uint256 creatorCut = (totalPrice * CREATOR_CUT) / 100;

        erc20Instance.transfer(TREASURY_ADDRESS, treasuryCut);
        erc20Instance.transfer(PRIZE_POOL_ADDRESS, poolCut);
        erc20Instance.transfer(ROYALTY_CONTRACT_ADDRESS, creatorCut);

        IRoyaltyContract(ROYALTY_CONTRACT_ADDRESS).updateRewardsMapping(
            _id,
            creatorCut
        );
    }

    function getMintPriceForToken(
        uint256 _tokenId,
        uint256 _amount
    ) public view returns (uint256) {
        uint256 totalPrice = 0;
        uint256 tokenSupply = currentTokenSupply[_tokenId];

        for (uint256 i = 1; i <= _amount; i++) {
            if (tokenSupply + i >= maxSupply) {
                revert TokenSupplyExceeded(_tokenId, maxSupply, msg.sender);
            }

            uint256 bondingPrice = getBondingCurvePrice(tokenSupply + i);

            totalPrice += bondingPrice;
        }

        totalPrice +=
            (totalPrice * (TREASURY_CUT + CREATOR_CUT + POOL_CUT)) /
            100;

        return formatPrice(totalPrice);
    }

    function getBondingCurvePrice(
        uint256 _currentTokenId
    ) internal pure returns (uint256) {
        // return ABDKMathQuadLib.powAndMultiply(_currentTokenId);

        return (_currentTokenId) * 60;
    }

    function updateTreasuryAddress(
        address _newTreasuryAddress
    ) public onlyOwner whenNotPaused {
        TREASURY_ADDRESS = _newTreasuryAddress;
    }

    function updatePrizePoolAddress(
        address _newPoolAddress
    ) public onlyOwner whenNotPaused {
        PRIZE_POOL_ADDRESS = _newPoolAddress;
    }

    function updateRoyaltyContractAddress(
        address _newRoyaltyContractAddress
    ) public onlyOwner whenNotPaused {
        ROYALTY_CONTRACT_ADDRESS = _newRoyaltyContractAddress;
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }

    function formatPrice(uint256 _price) public view returns (uint256) {
        return _price * 10 ** erc20Decimals;
    }

    function updateERC20Decimals(
        uint8 _decimals
    ) public onlyOwner whenNotPaused {
        erc20Decimals = _decimals;
    }
}
