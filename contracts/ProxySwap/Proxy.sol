// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Proxy is ERC20, ERC20Burnable, Ownable {
    uint256 private constant INITIAL_SUPPLY = 1000000 * 10 ** 18;

    constructor(
        address _tokenOwner
    ) Ownable(_tokenOwner) ERC20("PROXY", "PROXY") {
        _mint(_tokenOwner, INITIAL_SUPPLY);
    }
}
