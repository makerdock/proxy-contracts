// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidAction, InsufficientAllowance, TokenSupplyExceeded, InsufficientBalance, InvalidStakingAddress} from "./utils/Errors.sol";
import {IStakeNFT} from "./interfaces/IStakeNFT.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IRoyaltyContract} from "./interfaces/IRoyaltyContract.sol";
import {ABDKMathQuadLib} from "./utils/ABDKMathQuadLib.sol";

contract CasterNFT is ERC1155, Ownable, Pausable, BackendGateway {
    IERC20 public erc20Instance;

    address public TREASURY_ADDRESS = address(0);
    address public PRIZE_POOL_ADDRESS = address(0);
    address public ROYALTY_CONTRACT_ADDRESS = address(0);

    mapping(address => uint8) private whitelistedStakingContracts;

    uint8 public constant TREASURY_CUT = 2; // 2 / 100 = 2%
    uint8 public constant CREATOR_CUT = 6; // 6 / 100 = 6%
    uint8 public constant POOL_CUT = 2; // 2 / 100 = 2%

    uint16 public maxSupply = 500;
    uint8 public erc20Decimals = 18;
    uint8 public constant PRICE = 80;

    mapping(uint256 => uint16) public currentTokenSupply;
    mapping(uint256 => bool) public mintSelfNFT;

    event Minted(address indexed minter, uint256 indexed id, uint8 amount);

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

    function stakeNFTs(
        address _stakingContractAddress,
        uint256[] memory _ids,
        uint256[] memory _amounts, // safeTransferFrom needs uint256
        bytes memory _signature,
        uint32 _nonce
    ) public whenNotPaused {
        for (uint256 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= balanceOf(msg.sender, _ids[i])) {
                revert InsufficientBalance(msg.sender, _ids[i], _amounts[i]);
            }
        }

        if (whitelistedStakingContracts[_stakingContractAddress] != 1) {
            revert InvalidStakingAddress(msg.sender);
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

    function forfeitNFT(uint256 id, uint8 amount) public whenNotPaused {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (amount > balanceOf(msg.sender, id)) {
            revert InsufficientBalance(msg.sender, id, amount);
        }

        currentTokenSupply[id] -= amount;

        uint256 fundsToSendToUser = 0;

        for (uint256 i = 0; i < amount; i++) {
            uint256 estimatedBondingPrice = getBondingCurvePrice(
                currentTokenSupply[id] - i + 1
            );
            fundsToSendToUser += estimatedBondingPrice;
        }

        fundsToSendToUser = formatPrice(fundsToSendToUser);

        uint256 leftFunds = fundsToSendToUser -
            (fundsToSendToUser * (TREASURY_CUT + POOL_CUT + CREATOR_CUT)) /
            100;

        super._burn(msg.sender, id, amount);

        distributeFunds(fundsToSendToUser, id, amount);
        erc20Instance.transfer(msg.sender, leftFunds);
    }

    function mint(uint256 id, uint16 amount) public payable whenNotPaused {
        if (amount == 0) {
            revert InvalidAction(msg.sender, id);
        }

        if (currentSupply(id) == maxSupply) {
            revert TokenSupplyExceeded(id, maxSupply, msg.sender);
        }

        uint256 mintPrice = 0;

        // if user is minting first token
        if (currentTokenSupply[id] == 0 && amount == 1) {
            mintPrice = PRICE;
        } else {
            for (uint256 i = 0; i < amount; i++) {
                uint256 estimatedBondingPrice = getBondingCurvePrice(
                    currentTokenSupply[id] + (i + 1)
                );
                mintPrice += estimatedBondingPrice;
            }
        }

        mintPrice = formatPrice(mintPrice);

        if (mintPrice > erc20Instance.allowance(msg.sender, address(this))) {
            revert InsufficientAllowance(msg.sender, mintPrice);
        }

        erc20Instance.transferFrom(msg.sender, address(this), mintPrice);
        distributeFunds(mintPrice, id, amount);
        _mint(msg.sender, id, amount, "");

        currentTokenSupply[id] += amount;
    }

    function mintSelfCreatorNFT(
        address _userAddress,
        uint256 _tokenId
    ) public backendGateway whenNotPaused {
        if (mintSelfNFT[_tokenId] == true) {
            revert InvalidAction(_userAddress, _tokenId);
        }

        _mint(_userAddress, _tokenId, 1, "");
        currentTokenSupply[_tokenId] += 1;
    }

    function distributeFunds(
        uint256 totalPrice,
        uint256 _id,
        uint16 _amount
    ) internal {
        uint256 treasuryCut = (totalPrice * TREASURY_CUT) / 100;
        uint256 poolCut = (totalPrice * POOL_CUT) / 100;
        uint256 creatorCut = (totalPrice * CREATOR_CUT) / 100;

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
        uint256 tokenSupply = currentTokenSupply[_tokenId];

        for (uint256 i = 0; i < _amount; i++) {
            if (tokenSupply + i >= maxSupply) {
                revert TokenSupplyExceeded(_tokenId, maxSupply, msg.sender);
            }

            uint256 bondingPrice = getBondingCurvePrice(tokenSupply + (i + 1));

            totalPrice += bondingPrice;
        }

        return totalPrice;
    }

    function getBondingCurvePrice(
        uint256 _currentTokenId
    ) internal pure returns (uint256) {
        if (_currentTokenId == 1 || _currentTokenId == 0) {
            return PRICE;
        }

        return ABDKMathQuadLib.powAndMultiply(_currentTokenId);

        // // TODO: @abhishek fix the calculation
        // // (currentToken ** 1.05) x 60
        // return ((_currentTokenId * 1) * 60);
    }

    function updateWhitelistedStakingContracts(
        address _stakingContractAddress,
        uint8 _isWhitelisted // 1 -> whitelisted, 0 -> not whitelisted
    ) public onlyOwner whenNotPaused {
        whitelistedStakingContracts[_stakingContractAddress] = _isWhitelisted;
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
