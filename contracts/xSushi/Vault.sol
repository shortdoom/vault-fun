// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "./ERC4626.sol";
import { IERC4626 } from "./IERC4626.sol";

import "hardhat/console.sol";

// import { IERC4626 } from "./IERC4626.sol";
// contract Vault is IERC4626 {}

contract Vault is ERC4626 {

    mapping (address => uint256) public balanceOfBoost;
    address public boostToken;

    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _boostToken
    ) ERC4626(_underlying, _name, _symbol) {
        boostToken = _boostToken;
    }

    function enter(uint256 underlyingAmount) public {
        super.deposit(msg.sender, underlyingAmount);
    }

    function leave(uint256 shareAmount) public {
        super.redeem(msg.sender, msg.sender, shareAmount);
    }
    
    // demo overriding calculateShares/Underlying
    // https://resources.curve.fi/guides/boosting-your-crv-rewards
    function boost(uint256 boostAmount) public {
        // boostToken can have some emission limits/be scarce,
        // vault can use linearly growing (up to max) to recalc boost for user 
        // here, we only accure appropriate interest to underlying
        // user sends ERC20 boostToken in N amount, 
        // thus getting higher % of underlying on redemption than users without it
        // can be locked in
    }

    function afterDeposit(uint256 underlyingAmount) internal override {}

    function beforeWithdraw(uint256 underlyingAmount) internal override {}
}
