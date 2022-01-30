import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { Controller__factory, StrategyDAICompoundBasic__factory, Vault__factory } from "../typechain";
import { TestToken__factory } from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

async function main(): Promise<void> {
  let signers: SignerWithAddress[];
  let ERC20Contract: Contract;
  let controllerContract: Contract;
  let vaultContract: Contract;
  let strategyContract: Contract;

  const [deployer, user1, user2, user3] = await ethers.getSigners();
  signers = [deployer, user1, user2, user3];

  await mintUnderlyingMockToken();
  await deployController();
  await deployVault();
  console.log("Done");
  await deployAndSetStrategy();
  await depositSomeUnderlyingToVault();
  await checkUserBalances(signers);
  await callEarnOnVault();
  await checkUserBalances(signers);

  async function mintUnderlyingMockToken() {
    const ERC20Factory = new TestToken__factory(deployer);
    ERC20Contract = await ERC20Factory.deploy();
    const toMint = ethers.utils.parseEther("1000");
    for (let i = 0; i < signers.length; i++) {
      const instanceERC = ERC20Contract.connect(signers[i]);
      await instanceERC.mint(signers[i].address, toMint);
    }
  }

  async function deployController() {
    const controllerFactory = new Controller__factory(deployer);
    controllerContract = await controllerFactory.deploy("0x0000000000000000000000000000000000000000");
  }

  async function deployVault() {
    const vaultFactory = new Vault__factory(deployer);
    vaultContract = await vaultFactory.deploy(
      ERC20Contract.address,
      "4626-Sushi",
      "46xS",
      deployer.address,
      controllerContract.address,
    );
  }

  async function checkUserBalances(signers: SignerWithAddress[]) {
    for (let i = 0; i <= signers.slice(0, 3).length; i++) {
      const vaultInstance = vaultContract.connect(signers[i])
      const userUnderlyingInVault = await vaultInstance.balanceOfUnderlying(signers[i].address);
      const userSharesFromUnderlying = await vaultInstance.calculateShares(userUnderlyingInVault);
      const totalUnderlyingInVault = await vaultInstance.totalUnderlying();
      const result = "TotalUnderlying: " + ethers.utils.formatUnits(totalUnderlyingInVault) + " User underlyingInVault: " + ethers.utils.formatUnits(userUnderlyingInVault.toString()) + " user sharesFromUnderlying: " + ethers.utils.formatUnits(userSharesFromUnderlying.toString())
      console.log(result);
    }
  }

  async function deployAndSetStrategy() {
    const strategyFactory = new StrategyDAICompoundBasic__factory(deployer);
    strategyContract = await strategyFactory.deploy(controllerContract.address);
    await controllerContract.approveStrategy(ERC20Contract.address, strategyContract.address);
    await controllerContract.setStrategy(ERC20Contract.address, strategyContract.address);
  }

  async function depositSomeUnderlyingToVault() {
    const depositAmount = ethers.utils.parseEther("100");
    for (let i = 0; i < signers.length; i++) {
      const instanceERC = ERC20Contract.connect(signers[i]);
      const instanceVAULT = vaultContract.connect(signers[i]);
      await instanceERC.approve(vaultContract.address, depositAmount);
      await instanceVAULT.deposit(signers[i].address, depositAmount);
    }
  }

  async function callEarnOnVault() {
    await vaultContract.earn();
    for (let index = 0; index < 10; index++) {
      console.log("mining block", index);
      await ethers.provider.send("evm_mine", []);
    }
  }
  // use hre to move at least XXX blocks into the future, after that ...
  // compare old underlying vs after earnings

  async function callHarvestFromStrat() {}
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
