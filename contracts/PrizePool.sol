// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";
import {InvalidParams} from "./utils/Errors.sol";

contract PrizePool is BackendGateway {
    mapping(address => uint256) public winnerMapping;

    function updateWinnerMapping(
        address[] memory _winningAddresses,
        uint256[] memory _winningAmount
    ) public backendGateway {
        if (_winningAddresses.length == _winningAmount.length) {
            revert InvalidParams();
        }

        for (uint256 i = 0; i < _winningsAddresses.lengt; i++) {
            // doing a > 0 check instead of == 0 to check for undefined as well
            if (winnerMapping[_winningAddresses[i]] > 0) {
                winnerMapping[_winningAddresses[i]] += _winningAmount[i];
            } else {
                winnerMapping[_winningAddresses[i]] = _winningAmount[i];
            }
        }
    }

    function claimWinnings() public {
        if (_winnerMapping[msg.sender] > 0) {
            payable(msg.sender).transfer(_winnerMapping[msg.sender]);
            delete _winnerMapping[msg.sender];
        }
    }
}
