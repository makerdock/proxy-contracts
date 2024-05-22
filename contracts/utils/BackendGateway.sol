// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UnAuthorizedAction, InvalidSignature, InvalidServerWallet} from "./Errors.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BackendGateway is Ownable(msg.sender) {
    using ECDSA for bytes32;
    address public serverWallet = address(0);

    modifier backendGateway() {
        if (msg.sender != serverWallet) {
            revert UnAuthorizedAction(msg.sender);
        }
        _;
    }

    function updateServerWallet(address _newServerWallet) public onlyOwner {
        serverWallet = _newServerWallet;
    }

    function verifySignature(
        address _user,
        uint256 nonce,
        bytes memory signature
    ) internal view returns (bool) {
        if (serverWallet == address(0)) {
            revert InvalidServerWallet();
        }

        bytes32 hash = keccak256(abi.encodePacked(_user, nonce));
        bytes32 signedHash = MessageHashUtils.toEthSignedMessageHash(hash);

        if (ECDSA.recover(signedHash, signature) == serverWallet) {
            return true;
        } else {
            revert InvalidSignature();
        }
    }
}
