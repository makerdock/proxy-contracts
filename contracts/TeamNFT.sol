// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {UnAuthorizedAction} from "./utils/Errors.sol";

contract TeamNFT is ERC721("TEAM_NFT", "TN") {
    address public constant CASTER_NFT_CONTRACT = address(0);

    struct StakedNFT {
        uint256[] ids;
        uint256[] amount;
    }

    mapping(uint256 => StakedNFT[]) private tokenIdToStakedNFTsMapping;

    uint256 public tokenId = 0;

    function stakedNFTs(
        address _user,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public {
        tokenId++;

        for (uint256 i = 0; i < _ids.length; i++) {
            IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT);

            // Checking if the NFT is transferred
            // Need to confirm if it's in the same transaction then will it be transferred
            // and is this check is right way
            if (_amounts[i] >= casterNFTContract.balanceOf(_user, _ids[i])) {
                revert UnAuthorizedAction(msg.sender);
            }
        }

        StakedNFT memory userStakedNFTs = StakedNFT({
            ids: _ids,
            amount: _amounts
        });
        tokenIdToStakedNFTsMapping[tokenId].push(userStakedNFTs);

        _mint(_user, tokenId);
    }

    function updateStakedNFTs(
        uint256 _tokenId,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT);

            // Checking if the NFT is transferred
            // Need to confirm if it's in the same transaction then will it be transferred
            // and is this check is right way
            if (
                casterNFTContract.balanceOf(address(this), _ids[i]) >=
                _amounts[i]
            ) {
                revert UnAuthorizedAction(msg.sender);
            }
        }

        StakedNFT memory userStakedNFTs = StakedNFT({
            ids: _ids,
            amount: _amounts
        });
        tokenIdToStakedNFTsMapping[_tokenId].push(userStakedNFTs);
    }

    function unstakeNFTs(
        address user,
        uint256[] memory _ids,
        uint256[] memory amounts
    ) public {
        IERC1155 teamNFTContract = IERC1155(address(this));
        for (uint256 i = 0; i < _ids.length; i++) {
            // Checking if the NFT is transferred
            // Need to confirm if it's in the same transaction then will it be transferred
            // and is this check is right way
            if (
                teamNFTContract.balanceOf(address(this), _ids[i]) > amounts[i]
            ) {
                revert UnAuthorizedAction(msg.sender);
            }
        }

        teamNFTContract.safeBatchTransferFrom(
            address(this),
            user,
            _ids,
            amounts,
            ""
        );
    }
}
