// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract TestToken is ERC20 ("4626-Sushi", "46xS", 18){

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
