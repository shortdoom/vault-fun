import { ethers } from "hardhat";
import { Contract, ContractFactory } from "ethers";

async function main(): Promise<void> {
  const TestTokenFactory: ContractFactory = await ethers.getContractFactory("TestToken");
  const testToken: Contract = await TestTokenFactory.deploy();
  await testToken.deployed();
  console.log("TestToken deployed to: ", testToken.address);
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
