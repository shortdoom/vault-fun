// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { IERC4626 } from "./interfaces/IERC4626.sol";
import { FixedPointMathLib } from "./utils/FixedPointMath.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "hardhat/console.sol";
import "./interfaces/IController.sol";

contract Vault is ERC20, IERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    uint256 public totalFloat;
    uint256 public minFloat = 9500;
    uint256 public constant maxFloat = 10000;

    address public controller;
    address public governance;

    ERC20 public immutable asset;

    constructor(
        ERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _governance,
        address _controller
    ) ERC20(_name, _symbol, _underlying.decimals()) {
        asset = _underlying;
        controller = _controller;
        governance = _governance;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 amount, address to) public override returns (uint256 shares) {
        require((shares = previewDeposit(amount)) != 0, "ZERO_SHARES");

        _mint(to, shares);

        totalFloat += amount;

        emit Deposit(msg.sender, to, amount, shares);

        asset.safeTransferFrom(msg.sender, address(this), amount);

        afterDeposit(amount);
    }

    function mint(uint256 shares, address to) public override returns (uint256 amount) {
        _mint(to, amount = previewMint(shares));

        totalFloat += amount;

        emit Deposit(msg.sender, to, amount, shares);

        asset.safeTransferFrom(msg.sender, address(this), amount);

        afterDeposit(amount);
    }

    function withdraw(
        uint256 amount,
        address to,
        address from
    ) public override returns (uint256 shares) {
        uint256 allowed = allowance[from][msg.sender];
        if (msg.sender != from && allowed != type(uint256).max) allowance[from][msg.sender] = allowed - shares;

        if (amount > idleFloat()) {
            beforeWithdraw(amount);
        }

        _burn(from, shares = previewWithdraw(amount));
        totalFloat -= amount;

        emit Withdraw(from, to, amount, shares);

        asset.safeTransfer(to, amount);
    }

    function redeem(
        uint256 shares,
        address to,
        address from
    ) public override returns (uint256 amount) {
        uint256 allowed = allowance[from][msg.sender];

        if (msg.sender != from && allowed != type(uint256).max) allowance[from][msg.sender] = allowed - shares;
        require((amount = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        if (shares > idleFloat()) {
            beforeWithdraw(shares);
        }

        amount = previewRedeem(shares);
        _burn(from, shares);
        totalFloat -= amount;

        emit Withdraw(from, to, amount, shares);

        asset.safeTransfer(to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Example usage of hook. Pull funds from strategy to Vault if needed.
    /// Withdraw at least requested amount to the Vault. Covers withdraw/performance fees of strat. Leaves dust tokens.
    function beforeWithdraw(uint256 amount) internal {
        uint256 _withdraw = (amount + ((amount * 50) / 10000)) - idleFloat();
        IController(controller).withdraw(address(asset), _withdraw);
    }

    function afterDeposit(uint256 amount) internal {}

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + IController(controller).balanceOf(address(asset));
    }

    function assetsOf(address user) public view override returns (uint256) {
        return previewRedeem(balanceOf[user]);
    }

    function assetsPerShare() public view override returns (uint256) {
        return previewRedeem(10**decimals);
    }

    /// @notice Idle funds in Vault, i.e deposits before earn()
    function idleFloat() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @notice Available to move to strategy. Leave some tokens idle.
    /// @dev Remember, totalFloat returns ALL shares supply, even if underlying is locked outside of Vault.
    function freeFloat() public view returns (uint256) {
        return (totalFloat * minFloat) / maxFloat;
    }

    /// @notice Optional. Left empty here. (No limit) 
    function maxDeposit(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    /// @notice Optional. Left empty here. (No limit) 
    function maxMint(address) public pure override returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address user) public view override returns (uint256) {
        return assetsOf(user);
    }

    function maxRedeem(address user) public view override returns (uint256) {
        return balanceOf[user];
    }

    function previewDeposit(uint256 amount) public view override returns (uint256 shares) {
        uint256 supply = totalSupply;

        return supply == 0 ? amount : amount.mulDivDown(totalSupply, totalAssets());
    }

    function previewMint(uint256 shares) public view override returns (uint256 amount) {
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), totalSupply);
    }

    function previewWithdraw(uint256 amount) public view override returns (uint256 shares) {
        uint256 supply = totalSupply;

        return supply == 0 ? amount : amount.mulDivUp(totalSupply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view override returns (uint256 amount) {
        uint256 supply = totalSupply;

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), totalSupply);
    }

    /*///////////////////////////////////////////////////////////////
                            YEARN V2 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setMin(uint256 _min) external {
        require(msg.sender == governance, "!governance");
        minFloat = _min;
    }

    function setGovernance(address _governance) public {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) public {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }

    function earn() public {
        uint256 _bal = freeFloat();
        asset.transfer(controller, _bal);
        IController(controller).earn(address(asset), _bal);
    }

    function harvest(address reserve, uint256 amount) external {
        require(msg.sender == controller, "!controller");
        require(reserve != address(asset), "token");
        IERC20(reserve).transfer(controller, amount);
    }

    function depositAll() external {
        deposit(asset.balanceOf(msg.sender), msg.sender);
    }

    function withdrawAll() external {
        withdraw(assetsOf(msg.sender), msg.sender, msg.sender);
    }
}
