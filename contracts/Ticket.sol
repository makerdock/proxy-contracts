// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Ticket is ReentrancyGuard, Pausable, Ownable(msg.sender) {
    IERC20 public degenToken;
    address public prizePool;
    address public treasury;
    uint256 public ticketPrice = 1 * 10 ** 18; // Example price in DEGEN tokens

    event TicketPurchased(address indexed user, uint256 timestamp, uint256 fid);

    constructor(address _degenToken, address _prizePool, address _treasury) {
        degenToken = IERC20(_degenToken);
        prizePool = _prizePool;
        treasury = _treasury;
    }

    function buyTicket(uint256 fid) external whenNotPaused nonReentrant {
        // Transfer DEGEN tokens
        uint256 halfPrice = ticketPrice / 2;
        degenToken.transferFrom(msg.sender, prizePool, halfPrice);
        degenToken.transferFrom(msg.sender, treasury, halfPrice);

        // Emit event for ticket purchase
        emit TicketPurchased(msg.sender, block.timestamp, fid);
    }

    // Admin functions
    function setTicketPrice(uint256 newPrice) external onlyOwner {
        ticketPrice = newPrice;
    }

    function updatePrizePool(address _prizePool) external onlyOwner {
        prizePool = _prizePool;
    }

    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
