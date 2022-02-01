import { ethers } from "hardhat";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import hre from "hardhat";
import {DAI_ABI} from "./abi/DAI";

async function main(): Promise<void> {
  let signers: SignerWithAddress[];
  let DAIContract: Contract;

  const [deployer, user1, user2, user3] = await ethers.getSigners();
  signers = [deployer, user1, user2, user3];
  
  await hre.network.provider.request({
    method: "hardhat_impersonateAccount",
    params: ["0x075e72a5edf65f0a5f44699c7654c1a76941ddc8"], // 200 mln dai
  });

  const richDaiOwner = await ethers.getSigner("0x075e72a5edf65f0a5f44699c7654c1a76941ddc8");
  DAIContract = new Contract("0x6b175474e89094c44da98b954eedeac495271d0f", DAI_ABI, richDaiOwner);

  await transferDaiToSigners();

  async function transferDaiToSigners() {
    const toMint = ethers.utils.parseEther("11000");
    for (let i = 0; i < signers.length; i++) {
      await DAIContract.transfer(signers[i].address, toMint);
    }
  }

}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
