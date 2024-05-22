// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";
import {BackendGateway} from "./utils/BackendGateway.sol";
import {InsufficientBalance, UnAuthorizedAction} from "./utils/Errors.sol";

contract StakeNFT is ERC1155Holder, BackendGateway {
    address public CASTER_NFT_CONTRACT_ADDRESS = address(0);

    struct StakedNFT {
        uint256[] ids;
        uint256[] amounts;
    }

    mapping(uint256 => StakedNFT) private tokenIdToStakedNFTsMapping;
    mapping(uint256 => address) private tokenIdToUserMapping;
    uint256 public tokenId = 0;

    function updateCasterNFTAddress(address _newCasterNFT) public onlyOwner {
        CASTER_NFT_CONTRACT_ADDRESS = _newCasterNFT;
    }

    function stakeNFTs(
        address _user,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        // @abhishek: implement a backend signature validation
        bytes32[] calldata signature,
        uint256 nonce
    ) public {
        // TBD: validate token

        IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT_ADDRESS);

        for (uint8 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= casterNFTContract.balanceOf(_user, _ids[i])) {
                revert InsufficientBalance(_user, _ids[i], _amounts[i]);
            }
        }

        casterNFTContract.safeBatchTransferFrom(
            _user,
            address(this),
            _ids,
            _amounts,
            ""
        );

        StakedNFT memory userStakedNFTs = StakedNFT({
            ids: _ids,
            amounts: _amounts
        });

        tokenId++;
        tokenIdToStakedNFTsMapping[tokenId] = userStakedNFTs;
        tokenIdToUserMapping[tokenId] = _user;
    }

    function getStakedNFTDetails(
        uint256 _tokenId
    ) public view returns (StakedNFT memory) {
        return tokenIdToStakedNFTsMapping[_tokenId];
    }

    function unstake(uint256 _tokenId) public {
        if (tokenIdToUserMapping[_tokenId] != msg.sender) {
            revert UnAuthorizedAction(msg.sender);
        }

        IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT_ADDRESS);

        StakedNFT memory stakedNFTs = tokenIdToStakedNFTsMapping[_tokenId];

        delete tokenIdToStakedNFTsMapping[_tokenId];
        delete tokenIdToUserMapping[_tokenId];

        casterNFTContract.safeBatchTransferFrom(
            address(this),
            msg.sender,
            stakedNFTs.ids,
            stakedNFTs.amounts,
            ""
        );
    }
}
