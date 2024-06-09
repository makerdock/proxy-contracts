// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LpLocker.sol";

contract LockerFactory {
    event deployed(
        address indexed lockerAddress,
        address indexed owner,
        uint256 tokenId,
        uint256 lockingPeriod
    );

    //maps the owner to the amount of contract deployed
    mapping(address owner => address[] addresses) public owner_addresses;

    function deploy(
        address token,
        address beneficiary,
        uint64 durationSeconds,
        uint256 tokenId
    ) public payable returns (address) {
        address newLockerAddress = address(
            new LpLocker(token, beneficiary, durationSeconds)
        );

        if (newLockerAddress == address(0)) {
            revert("Invalid address");
        }

        address[] storage addresses = owner_addresses[beneficiary];
        addresses.push(newLockerAddress);

        owner_addresses[beneficiary] = addresses;

        emit deployed(newLockerAddress, msg.sender, tokenId, durationSeconds);

        return newLockerAddress;
    }
}

/*

forge create --rpc-url https://rpc.degen.tips --private-key 0x234784c482f83dba9e5f60cb597a4c324b591f1a6e48c8553bc046dbddac451f contracts/lp-locker/LockerFactory.sol:LockerFactory --via-ir --verify --etherscan-api-key DYJWHWVGMAUW3GAB1EDST9EQKTRVCRXXC9

*/
