// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LpLocker} from "./LpLocker.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LockerFactory is Ownable(msg.sender) {
    event deployed(
        address indexed lockerAddress,
        address indexed owner,
        uint256 tokenId,
        uint256 lockingPeriod
    );

    address public feeRecipient;

    mapping(address owner => address[] addresses) public owner_addresses;

    constructor() {
        feeRecipient = msg.sender;
    }

    function deploy(
        address token,
        address beneficiary,
        uint64 durationSeconds,
        uint256 tokenId,
        uint256 fees
    ) public payable returns (address) {
        address newLockerAddress = address(
            new LpLocker(
                token,
                beneficiary,
                durationSeconds,
                fees,
                feeRecipient
            )
        );

        if (newLockerAddress == address(0)) {
            revert("Invalid address");
        }

        address[] storage addresses = owner_addresses[beneficiary];
        addresses.push(newLockerAddress);

        owner_addresses[beneficiary] = addresses;

        emit deployed(newLockerAddress, beneficiary, tokenId, durationSeconds);

        return newLockerAddress;
    }

    function setFeeRecipient(address _feeRecipient) public onlyOwner {
        feeRecipient = _feeRecipient;
    }
}

/*

forge create --rpc-url https://rpc.degen.tips --private-key 0x234784c482f83dba9e5f60cb597a4c324b591f1a6e48c8553bc046dbddac451f contracts/lp-locker/LockerFactory.sol:LockerFactory --via-ir --verify --etherscan-api-key DYJWHWVGMAUW3GAB1EDST9EQKTRVCRXXC9

*/
