// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.1/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@5.0.1/token/ERC20/extensions/ERC20Permit.sol";

contract Group9 is ERC20, ERC20Permit {
    constructor() ERC20("Group9", "GP9") ERC20Permit("Group9") {
        _mint(msg.sender, 999999 * 10 ** decimals());
    }
}
