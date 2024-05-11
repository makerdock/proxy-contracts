// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UnAuthorizedAction} from "./Errors.sol";

contract BackendGateway is Ownable {
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
}
