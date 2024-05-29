// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BackendGateway} from "./utils/BackendGateway.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {InvalidParams, InsufficientFunds, InvalidAddress} from "./utils/Errors.sol";

contract PrizePool is BackendGateway {
    mapping(address => uint256) public winnerMapping;
    address public TOKEN_CONTRACT_ADDRESS;

    event WinnerMappingUpdated(address indexed winner, uint256 amount);
    event WinningsClaimed(address indexed winner, uint256 amount);

    function updateTokenContractAddress(
        address _newTokenContract
    ) public onlyOwner {
        if (_newTokenContract == address(0)) {
            revert InvalidAddress(_newTokenContract);
        }

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
            emit WinnerMappingUpdated(_winningAddresses[i], _winningAmount[i]);
        }
    }

    function claimWinnings() public {
        IERC20 token = IERC20(TOKEN_CONTRACT_ADDRESS);

        if (winnerMapping[msg.sender] > 0) {
            if (token.balanceOf(address(this)) >= winnerMapping[msg.sender]) {
                uint256 winnings = winnerMapping[msg.sender];
                winnerMapping[msg.sender] = 0;
                token.transfer(msg.sender, winnings);
                emit WinningsClaimed(msg.sender, winnings);
            } else {
                revert InsufficientFunds(
                    address(this),
                    winnerMapping[msg.sender]
                );
            }
        }
    }
}
