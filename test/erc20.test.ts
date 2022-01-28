import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Vault__factory } from "../typechain";
import { TestToken__factory } from "../typechain";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

chai.use(solidity);
const { expect } = chai;

const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f";

describe("Vault", () => {
  let VaultContract: Contract;
  let signers: SignerWithAddress[];
  let ERC20Contract: Contract;
  let testTokenAddress: string;
  let depositAmount: BigNumber;
  let expectedTotal: BigNumber;
  let withdrawAmount: BigNumber;

  before("Deploy MockERC20 Token", async () => {
    const [deployer, user1, user2] = await ethers.getSigners();
    signers = [deployer, user1, user2];
    const ERC20Factory = new TestToken__factory(signers[0]);
    ERC20Contract = await ERC20Factory.deploy();
    testTokenAddress = ERC20Contract.address;
    const toDeposit = ethers.utils.parseEther("1337");
    for (let i = 0; i < signers.slice(0, 3).length; i++) {
      await ERC20Contract.mint(signers[i].address, toDeposit);
    }
  });

  before("Deploy vault contract", async () => {
    const vaultFactory = new Vault__factory(signers[0]);
    VaultContract = await vaultFactory.deploy(testTokenAddress, "4626-Sushi", "46xS", DAI_ADDRESS);
  });

  describe("Start Single Deposit", async () => {

    it("Deposit 129 Tokens", async () => {
      depositAmount = ethers.utils.parseEther("129");
      await ERC20Contract.approve(VaultContract.address, depositAmount);
      await VaultContract.enter(depositAmount);
    });

    it("Underlying managed in Vault after 1 deposit", async () => {
      const totalHolding = await VaultContract.totalUnderlying();
      console.log("Underlying managed in Vault after 1 deposit:", ethers.utils.formatUnits(totalHolding.toString(), "ether"));
      expect(await VaultContract.totalUnderlying()).to.be.eq(depositAmount);
    });
  });

  describe("Start Multiple Deposits", async () => {

    it("Deposit 4 times", async () => {
      depositAmount = ethers.utils.parseEther("100");
      for (let i = 0; i < signers.slice(0, 3).length; i++) {
        const instanceERC = ERC20Contract.connect(signers[i]);
        const instanceVAULT = VaultContract.connect(signers[i]);
        await instanceERC.approve(VaultContract.address, depositAmount);
        await instanceVAULT.enter(depositAmount);
      }
    });

    it("Underlying managed in Vault after 4 deposits", async () => {
      const totalHolding = await VaultContract.totalUnderlying();
      console.log("Underlying managed in Vault after 4 deposits:", ethers.utils.formatUnits(totalHolding.toString(), "ether"));
      expectedTotal = depositAmount.mul(BigNumber.from(3)).add(ethers.utils.parseEther("129"));
      expect(totalHolding).to.be.eq(expectedTotal)
    });


  });

  describe("Simulate income transfer in underlying to Vault", async () => {

    before("Deploy vault contract", async () => {
      const instanceERC = ERC20Contract.connect(signers[0]);
      await instanceERC.transfer(VaultContract.address, depositAmount.add(depositAmount));
    });

    it("Underlying managed in Vault after simulated income transfer", async () => {
      const totalHolding = await VaultContract.totalUnderlying();
      console.log("Underlying managed in Vault after simulated income transfer:", ethers.utils.formatUnits(totalHolding.toString(), "ether"));
      const newTotal = expectedTotal.add(depositAmount.add(depositAmount));
      expect(totalHolding).to.be.eq(newTotal)
    });


  });

  describe("Start Single Withdraw", async () => {
    
    it("Show user balances:", async () => {
      withdrawAmount = ethers.utils.parseEther("100");
      const vaultInstance = VaultContract.connect(signers[2])
      const userUnderlyingInVault = await vaultInstance.balanceOfUnderlying(signers[2].address);
      const userSharesFromUnderlying = await vaultInstance.calculateShares(userUnderlyingInVault);
      console.log("underlyingInVault:", ethers.utils.formatUnits(userUnderlyingInVault.toString()), "sharesFromUnderlying:", ethers.utils.formatUnits(userSharesFromUnderlying.toString()))
    });

    it("Withdraw full underlying", async () => {
      withdrawAmount = ethers.utils.parseEther("100");
      const vaultInstance = VaultContract.connect(signers[2])
      await vaultInstance.leave(withdrawAmount);
    });

    it("Underlying managed in Vault after 2 withdraws", async () => {
      const totalHolding = await VaultContract.totalUnderlying();
      console.log("Underlying managed in Vault after 2 withdraws:", ethers.utils.formatUnits(totalHolding.toString(), "ether"));
      // expect(await VaultContract.totalUnderlying()).to.be.eq(depositAmount);
    });
  });


});
