// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropTokens {
    IERC20 public token;
    bytes32 public rootHash;

    event ClaimedTokens(address indexed user, uint256 amount);

    constructor(address tokenAddress, bytes32 _rootHash) {
        token = IERC20(tokenAddress);
        rootHash = _rootHash;
    }

    function claimTokens(
        uint256 _claimAmount,
        bytes32[] calldata proof
    ) public {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _claimAmount));
        require(MerkleProof.verify(proof, rootHash, leaf), "Invalid proof");
        token.transfer(msg.sender, _claimAmount);
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
    ) public {
        AirdropTokens airdrop = new AirdropTokens(tokenAddress, _rootHash);

        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(airdrop),
            _totalAirdropTokens
        );

        emit AirdropDeployed(
            tokenAddress,
            msg.sender,
            address(airdrop),
            _totalAirdropTokens
        );
    }
}
