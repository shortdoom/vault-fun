// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "./ERC4626.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import "hardhat/console.sol";
import "./interfaces/IController.sol";

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

    function balance() public view returns (uint256) {
        return asset.balanceOf(address(this)) + (IController(controller).balanceOf(address(asset)));
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
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
        uint256 balanceAvialable = asset.balanceOf(address(this));
        return (balanceAvialable * min) / max;
    }

    function earn() public {
        uint256 _bal = available();
        asset.transfer(controller, _bal);
        IController(controller).earn(address(asset), _bal); // check if ok
    }

    function depositAll() external {
        deposit(asset.balanceOf(msg.sender), msg.sender);
    }

    function withdrawAll() external {
        uint256 allShares = previewRedeem(assetsOf(msg.sender));
        redeem(allShares, msg.sender, msg.sender);
    }

    function harvest(address reserve, uint256 amount) external {
        require(msg.sender == controller, "!controller");
        require(reserve != address(asset), "token");
        IERC20(reserve).transfer(controller, amount);
    }
}
