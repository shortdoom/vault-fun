import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";
import { Vault__factory, Controller__factory,StrategyDAICompoundBasic__factory } from "../typechain";
import { TestToken__factory } from "../typechain";
import { BigNumber, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

chai.use(solidity);
const { expect } = chai;

describe("Vault", async () => {
  let VaultContract: Contract;
  let controllerContract: Contract;
  let strategyContract: Contract;
  let signers: SignerWithAddress[];
  let ERC20Contract: Contract;
  let testTokenAddress: string;
  let depositAmount: BigNumber;
  let expectedTotal: BigNumber;
  let withdrawAmount: BigNumber;

  const [deployer, user1, user2] = await ethers.getSigners();
  signers = [deployer, user1, user2];

  before("Deploy MockERC20 Token", async () => {
    const ERC20Factory = new TestToken__factory(signers[0]);
    ERC20Contract = await ERC20Factory.deploy();
    testTokenAddress = ERC20Contract.address;
    const toDeposit = ethers.utils.parseEther("1337");
    for (let i = 0; i < signers.slice(0, 3).length; i++) {
      await ERC20Contract.mint(signers[i].address, toDeposit);
    }
  });

  before("Deploy Controller contract", async () => {
    const controllerFactory = new Controller__factory(deployer);
    controllerContract = await controllerFactory.deploy("0x0000000000000000000000000000000000000000");
  });

  before("Deploy Vault contract", async () => {
    const vaultFactory = new Vault__factory(signers[0]);
    VaultContract = await vaultFactory.deploy(
      ERC20Contract.address,
      "4626-Sushi",
      "46xS",
      deployer.address,
      controllerContract.address,
    );
  });

  before("Deploy Strategy contract", async () => {
    const strategyFactory = new StrategyDAICompoundBasic__factory(deployer);
    strategyContract = await strategyFactory.deploy(controllerContract.address);
    await controllerContract.setVault(ERC20Contract.address, VaultContract.address);
    await controllerContract.approveStrategy(ERC20Contract.address, strategyContract.address);
    await controllerContract.setStrategy(ERC20Contract.address, strategyContract.address);
  });
});
