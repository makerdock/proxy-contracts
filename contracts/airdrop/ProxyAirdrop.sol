// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropTokens {
    address public token;
    bytes32 public rootHash;

    mapping(address => bool) public isClaimed;
    event ClaimedTokens(address indexed user, uint256 amount);

    constructor(address tokenAddress, bytes32 _rootHash) {
        token = tokenAddress;
        rootHash = _rootHash;
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

        isClaimed[msg.sender] = true;

        if (token == address(0)) {
            (bool success, ) = msg.sender.call{value: _claimAmount}("");
            require(success, "Transfer failed");
        } else {
            IERC20(token).transfer(msg.sender, _claimAmount);
        }

        emit ClaimedTokens(msg.sender, _claimAmount);
    }
}

contract ProxyAirdrop is Ownable {
    constructor() Ownable(msg.sender) {}

    event AirdropDeployed(
        address indexed tokenAddress,
        address indexed deployer,
        address indexed collectionAddress,
        uint256 totalAirdropTokens
    );

    function deployAirdrop(
        address tokenAddress,
        bytes32 _rootHash,
        uint256 _totalAirdropTokens
    ) public payable {
        AirdropTokens airdrop = new AirdropTokens(tokenAddress, _rootHash);

        if (tokenAddress == address(0)) {
            require(msg.value == _totalAirdropTokens, "Invalid amount");
            (bool success, ) = address(airdrop).call{
                value: _totalAirdropTokens
            }("");
            require(success, "Transfer failed");
        } else {
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(airdrop),
                _totalAirdropTokens
            );
        }

        emit AirdropDeployed(
            tokenAddress,
            msg.sender,
            address(airdrop),
            _totalAirdropTokens
        );
    }
}
