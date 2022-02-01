import { ethers } from "hardhat";
import { Contract } from "ethers";
import { Controller__factory, Strategy, StrategyDAICompoundBasic__factory, Vault__factory } from "../typechain";
import { TestToken__factory } from "../typechain";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre from "hardhat";
import {DAI_ABI} from "./abi/DAI";

const DAI_ADDRESS = "0x6b175474e89094c44da98b954eedeac495271d0f"

async function main(): Promise<void> {
  let signers: SignerWithAddress[];
  let ERC20Contract: Contract;
  let DAIContract: Contract;
  let controllerContract: Contract;
  let vaultContract: Contract;
  let strategyContract: Contract;

  const [deployer, user1, user2, user3] = await ethers.getSigners();
  signers = [deployer, user1, user2, user3];
  
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x075e72a5edf65f0a5f44699c7654c1a76941ddc8"], // 200 mln dai
  });

  const richDaiOwner = await ethers.getSigner("0x075e72a5edf65f0a5f44699c7654c1a76941ddc8");
  DAIContract = new Contract(DAI_ADDRESS, DAI_ABI, richDaiOwner);

  await transferDaiToSigners();

  async function transferDaiToSigners() {
    const toMint = ethers.utils.parseEther("11000");
    for (let i = 0; i < signers.length; i++) {
      await DAIContract.transfer(signers[i].address, toMint);
    }
  }

  // await mintUnderlyingMockToken();
  await deployController();
  await deployVault();
  await deployAndSetStrategy();
  await depositSomeUnderlyingToVault();
  await checkUserBalances();
  await callEarnOnVault();
  await checkUserBalances();
  await callHarvestFromStrat();


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
      DAI_ADDRESS,
      "4626-Sushi",
      "46xS",
      deployer.address,
      controllerContract.address,
    );
  }

  async function checkUserBalances() {
    for (let i = 0; i <= signers.slice(0, 3).length; i++) {
      const vaultInstance = vaultContract.connect(signers[i]);
      const userUnderlyingInVault = await vaultInstance.assetsOf(signers[i].address);
      const userSharesFromUnderlying = await vaultInstance.previewRedeem(userUnderlyingInVault);
      const totalUnderlyingInVault = await vaultInstance.totalAssets();
      const result =
        "totalAssets: " +
        ethers.utils.formatUnits(totalUnderlyingInVault) +
        " User underlyingInVault: " +
        ethers.utils.formatUnits(userUnderlyingInVault.toString()) +
        " user sharesFromUnderlying: " +
        ethers.utils.formatUnits(userSharesFromUnderlying.toString());
      console.log(result);
    }
  }

  // Add Converter to strategy
  async function deployAndSetStrategy() {
    const strategyFactory = new StrategyDAICompoundBasic__factory(deployer);
    strategyContract = await strategyFactory.deploy(controllerContract.address);
    await controllerContract.setVault(DAI_ADDRESS, vaultContract.address);
    await controllerContract.approveStrategy(DAI_ADDRESS, strategyContract.address);
    await controllerContract.setStrategy(DAI_ADDRESS, strategyContract.address);
  }

  async function depositSomeUnderlyingToVault() {
    const depositAmount = ethers.utils.parseEther("10000");
    for (let i = 0; i < signers.length; i++) {
      const instanceERC = DAIContract.connect(signers[i]);
      const instanceVAULT = vaultContract.connect(signers[i]);
      await instanceERC.approve(vaultContract.address, depositAmount);
      await instanceVAULT.deposit(depositAmount, signers[i].address);
    }
  }

  async function callEarnOnVault() {
    await vaultContract.earn();
    for (let index = 0; index < 10; index++) {
      console.log("mining block", index);
      await ethers.provider.send("evm_mine", []);
    }
  }

  async function callHarvestFromStrat() {
    await strategyContract.harvest()
    const balanceOfWant = await strategyContract.balanceOfWant()
    console.log("balanceOfWant:", balanceOfWant.toString());
    // await controllerContract.withdrawAll(DAI_ADDRESS)
    // await checkUserBalances()
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
