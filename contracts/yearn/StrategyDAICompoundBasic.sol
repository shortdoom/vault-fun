// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "./interfaces/IERC20.sol";
import "./interfaces/cToken.sol";
import "./interfaces/Comptroller.sol";
import "./interfaces/Uni.sol";
import "./interfaces/IController.sol";
import "hardhat/console.sol";


contract StrategyDAICompoundBasic{

    address public constant want = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    // Comptroller address for compound.finance
    Comptroller public constant compound = Comptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B); 

    address public constant comp = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    address public constant cDAI = address(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address public constant uni = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    // used for comp <> weth <> dai route
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); 

    uint256 public performanceFee = 500;
    uint256 public constant performanceMax = 10000;

    uint256 public withdrawalFee = 50;
    uint256 public constant withdrawalMax = 10000;

    address public governance;
    address public controller;
    address public strategist;

    constructor(address _controller) {
        governance = msg.sender;
        strategist = msg.sender;
        controller = _controller;
    }

    function getName() external pure returns (string memory) {
        return "StrategyDAICompBasic";
    }

    function setStrategist(address _strategist) external {
        require(msg.sender == governance, "!governance");
        strategist = _strategist;
    }

    function setWithdrawalFee(uint256 _withdrawalFee) external {
        require(msg.sender == governance, "!governance");
        withdrawalFee = _withdrawalFee;
    }

    function setPerformanceFee(uint256 _performanceFee) external {
        require(msg.sender == governance, "!governance");
        performanceFee = _performanceFee;
    }

    function deposit() public {
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            IERC20(want).approve(cDAI, 0);
            IERC20(want).approve(cDAI, _want);
            cToken(cDAI).mint(_want);
        }
    }

    // Controller only function for creating additional rewards from dust
    function withdraw(IERC20 _asset) external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        require(want != address(_asset), "want");
        require(cDAI != address(_asset), "cDAI");
        require(comp != address(_asset), "comp");
        balance = _asset.balanceOf(address(this));
        _asset.transfer(controller, balance);
    }

    // Withdraw partial funds, normally used with a vault withdrawal
    function withdraw(uint256 _amount) external {
        require(msg.sender == controller, "!controller");
        uint256 _balance = IERC20(want).balanceOf(address(this));
        if (_balance < _amount) {
            _amount = _withdrawSome(_amount - _balance);
            _amount = _amount +  _balance;
        }

        uint256 _fee = (_amount * withdrawalFee) / withdrawalMax;

        IERC20(want).transfer(IController(controller).rewards(), _fee);
        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds

        IERC20(want).transfer(_vault, _amount -  _fee);
    }

    // Withdraw all funds, normally used when migrating strategies
    function withdrawAll() external returns (uint256 balance) {
        require(msg.sender == controller, "!controller");
        _withdrawAll();

        balance = IERC20(want).balanceOf(address(this));

        address _vault = IController(controller).vaults(address(want));
        require(_vault != address(0), "!vault"); // additional protection so we don't burn the funds
        IERC20(want).transfer(_vault, balance);
    }

    function _withdrawAll() internal {
        uint256 amount = balanceC();
        if (amount > 0) {
            _withdrawSome(balanceCInToken() -  1);
        }
    }

    function harvest() public {
        require(msg.sender == strategist || msg.sender == governance, "!authorized");
        compound.claimComp(address(this));
        uint256 _comp = IERC20(comp).balanceOf(address(this));
        console.log("comp", _comp); // ADD
        if (_comp > 0) {
            IERC20(comp).approve(uni, 0);
            IERC20(comp).approve(uni, _comp);

            address[] memory path = new address[](3);
            path[0] = comp;
            path[1] = weth;
            path[2] = want;

            Uni(uni).swapExactTokensForTokens(_comp, uint256(0), path, address(this), block.timestamp + 1800);
        }
        uint256 _want = IERC20(want).balanceOf(address(this));
        if (_want > 0) {
            uint256 _fee = (_want * performanceFee) / performanceMax;
            IERC20(want).transfer(IController(controller).rewards(), _fee);
            deposit();
        }
    }

    function _withdrawSome(uint256 _amount) internal returns (uint256) {
        uint256 b = balanceC();
        uint256 bT = balanceCInToken();
        // can have unintentional rounding errors
        uint256 amount = ((b *_amount) / bT) + 1;
        uint256 _before = IERC20(want).balanceOf(address(this));
        _withdrawC(amount);
        uint256 _after = IERC20(want).balanceOf(address(this));
        uint256 _withdrew = _after - _before;
        return _withdrew;
    }

    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    function _withdrawC(uint256 amount) internal {
        cToken(cDAI).redeem(amount);
    }

    function balanceCInToken() public view returns (uint256) {
        // Mantisa 1e18 to decimals
        uint256 b = balanceC();
        if (b > 0) {
            b = b * (cToken(cDAI).exchangeRateStored() / 1e18);
        }
        return b;
    }

    function balanceC() public view returns (uint256) {
        return IERC20(cDAI).balanceOf(address(this));
    }

    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceCInToken();
    }

    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        governance = _governance;
    }

    function setController(address _controller) external {
        require(msg.sender == governance, "!governance");
        controller = _controller;
    }
}
