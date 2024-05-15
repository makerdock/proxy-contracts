// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC1155} from "@openzeppelin/contracts/interfaces/IERC1155.sol";

contract StakeNFT is ERC1155Holder {
    address public CASTER_NFT_CONTRACT = address(0);

    struct StakedNFT {
        uint256[] ids;
        uint256[] amounts;
    }

    mapping(uint256 => StakedNFT) private tokenIdToStakedNFTsMapping;
    uint256 public tokenId = 0;

    function updateCasterNFTAddress(address _newCasterNFT) public {
        CASTER_NFT_CONTRACT = _newCasterNFT;
    }

    function stakeNFTs(
        address _user,
        uint256[] memory _ids,
        uint256[] memory _amounts
    ) public {
        IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT);

        for (uint256 i = 0; i < _ids.length; i++) {
            if (_amounts[i] >= casterNFTContract.balanceOf(_user, _ids[i])) {
                revert("incorrect balances");
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
    }

    function getStakedNFTDetails(
        uint256 _tokenId
    ) public view returns (StakedNFT memory) {
        return tokenIdToStakedNFTsMapping[_tokenId];
    }

    function unstake(uint256 _tokenId) public {
        IERC1155 casterNFTContract = IERC1155(CASTER_NFT_CONTRACT);

        StakedNFT memory stakedNFTs = tokenIdToStakedNFTsMapping[_tokenId];

        casterNFTContract.safeBatchTransferFrom(
            address(this),
            msg.sender,
            stakedNFTs.ids,
            stakedNFTs.amounts,
            ""
        );

        delete tokenIdToStakedNFTsMapping[_tokenId];
    }
}
