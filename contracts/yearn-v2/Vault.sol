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

    uint256 public min = 9500;
    uint256 public constant max = 10000;

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

        emit Deposit(msg.sender, to, amount);

        asset.safeTransferFrom(msg.sender, address(this), amount);

        afterDeposit(amount);
    }

    function mint(uint256 shares, address to) public override returns (uint256 amount) {
        _mint(to, amount = previewMint(shares));

        emit Deposit(msg.sender, to, amount);

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

        uint256 assetAvailable = asset.balanceOf(address(this));

        if (shares > assetAvailable) {
            /// @notice withdraw 0.2% more to Vault. covers withdraw/performance fees of strat. leftover dust. works only with 1e18
            uint256 _withdraw = shares - (assetAvailable - ((assetAvailable / 1000) * 20));
            IController(controller).withdraw(address(asset), _withdraw);
        }

        _burn(from, shares = previewWithdraw(amount));

        emit Withdraw(from, to, amount);

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

        uint256 sharesAvailable = asset.balanceOf(address(this));
        if (shares > sharesAvailable) {
            /// @notice withdraw 0.2% more to Vault. covers withdraw/performance fees of strat. leftover dust. works only with 1e18
            uint256 _withdraw = shares - (sharesAvailable - ((sharesAvailable / 1000) * 20));
            IController(controller).withdraw(address(asset), _withdraw);
        }

        amount = previewRedeem(shares);
        _burn(from, shares);

        emit Withdraw(from, to, amount);

        beforeWithdraw(amount);

        asset.safeTransfer(to, amount);
    }

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
                         INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 amount) internal virtual {}

    function afterDeposit(uint256 amount) internal virtual {}

    /*///////////////////////////////////////////////////////////////
                            YEARN V2 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
