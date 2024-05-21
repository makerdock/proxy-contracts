// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvalidParams} from "./utils/Errors.sol";

contract PrizePool is BackendGateway {
    mapping(address => uint256) public winnerMapping;
    address public TOKEN_CONTRACT_ADDRESS = address(0);

    function updateTokenContractAddress(
        address _newTokenContract
    ) public onlyOwner {
        require(_newTokenContract != address(0), "Invalid address");
        TOKEN_CONTRACT_ADDRESS = _newTokenContract;
    }

    function updateWinnerMapping(
        address[] memory _winningAddresses,
        uint256[] memory _winningAmount
    ) public backendGateway {
        if (_winningAddresses.length != _winningAmount.length) {
            revert InvalidParams();
        }

        for (uint256 i = 0; i < _winningAddresses.length; i++) {
            // doing a > 0 check instead of == 0 to check for undefined as well
            if (winnerMapping[_winningAddresses[i]] > 0) {
                winnerMapping[_winningAddresses[i]] += _winningAmount[i];
            } else {
                winnerMapping[_winningAddresses[i]] = _winningAmount[i];
            }
        }
    }
    //Todo: Change Trasfer to call
    function claimWinnings() public {
        if (winnerMapping[msg.sender] > 0) {
            uint256 winnings = winnerMapping[msg.sender];
            IERC20(TOKEN_CONTRACT_ADDRESS).transfer(
                msg.sender,
                winnerMapping[msg.sender]
            );

            delete winnerMapping[msg.sender];
        }
    }
}
