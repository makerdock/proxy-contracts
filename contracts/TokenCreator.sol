// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20 {
    bytes32 private rootHash;

    mapping(address => bool) public isClaimed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        bytes32 _rootHash
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _maxSupply); // Mint to msg.sender (TokenDeployer)
        rootHash = _rootHash;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function claimTokens(
        uint256 _claimAmount,
        bytes32[] calldata proof
    ) public {
        if (isClaimed[msg.sender] == true) {
            revert("User already claimed tokens");
        }

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, _claimAmount)))
        );
        require(MerkleProof.verify(proof, rootHash, leaf), "Invalid proof");
        IERC20(address(this)).transfer(msg.sender, _claimAmount);
    }
}

contract TokepadDeployer is Ownable(msg.sender) {
    // 2.5% tax
    address internal TAX_RECIPIENT = 0xeba814370974756Ab572D9e804187fd72A2Ab58a;

    // Deployment
    event NewToken(
        address indexed token,
        address indexed creator,
        uint256 maxSupply,
        uint256 deployerAmount
    );

    function deploy(
        string memory _name, // Token name
        string memory _symbol, // Token symbol
        uint256 _maxSupply, // Max supply of Token (50% will be locked for liquidity)
        uint256 _sum, // Amounts to reserver for distribution
        bytes32 rootHash
    ) external payable returns (address) {
        uint256 taxAmount = (_maxSupply * 25) / 1000;

        require(_sum + taxAmount <= _maxSupply, "!math");

        // 1. Create Token, approve to router
        Token t = new Token(_name, _symbol, _maxSupply, rootHash);

        // 2. Pay the 5% tax
        t.transfer(TAX_RECIPIENT, taxAmount);

        // 3. Deployer keeps the rest
        uint256 deployerAmount = _maxSupply - taxAmount - _sum;

        if (deployerAmount > 0) {
            t.transfer(msg.sender, deployerAmount);
        }

        emit NewToken(address(t), msg.sender, _maxSupply, deployerAmount);

        return address(t);
    }

    function updateTaxRecipient(address _newRecipient) external onlyOwner {
        require(msg.sender == TAX_RECIPIENT, "!auth");
        TAX_RECIPIENT = _newRecipient;
    }
}
