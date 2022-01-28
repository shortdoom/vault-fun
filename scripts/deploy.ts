import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { Vault__factory } from "../typechain";
import { TestToken__factory } from "../typechain";

async function main(): Promise<void> {
  let testTokenAddress: string;
  let vaultAddress: string;

  const [deployer] = await ethers.getSigners();
  const ERC20Factory = new TestToken__factory(deployer);
  const ERC20Contract = await ERC20Factory.deploy();
  testTokenAddress = ERC20Contract.address;
  const toMint = ethers.utils.parseEther("1337");
  await ERC20Contract.mint(deployer.address, toMint);
  const vaultFactory = new Vault__factory(deployer);
  const vaultContract = await vaultFactory.deploy(testTokenAddress, "4626-Sushi", "46xS");
  vaultAddress = vaultContract.address;
}


main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
