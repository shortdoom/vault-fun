// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "./ERC4626.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import "hardhat/console.sol";
import "./interfaces/IController.sol";

// Just fucking implement compoundDAIBasic strat
// Does it work? :)

contract Vault is ERC4626 {
    uint256 public min = 9500;
    uint256 public constant max = 10000;

    address public controller;
    address public governance;

    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _governance,
        address _controller
    ) ERC4626(_underlying, _name, _symbol) {
        controller = _controller;
        governance = _governance;
    }

    function setMin(uint256 _min) external {
        require(msg.sender == governance, "!governance");
        min = _min;
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) public {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    function available() public view returns (uint256) {
        uint256 balance = underlying.balanceOf(address(this));
        return (balance * min) / max;
    }

    function earn() public {
        uint256 _bal = available();
        underlying.transfer(controller, _bal);
        IController(controller).earn(address(underlying), _bal); // check if ok
    }

    function depositAll() external {
        deposit(msg.sender, underlying.balanceOf(msg.sender));
    }

    function withdrawAll() external {
        uint256 allShares = calculateShares(balanceOfUnderlying(msg.sender));
        super.redeem(msg.sender, msg.sender, allShares);
    }

    function harvest(address reserve, uint256 amount) external {
        require(msg.sender == controller, "!controller");
        require(reserve != address(underlying), "token");
        IERC20(reserve).transfer(controller, amount);
    }
}
