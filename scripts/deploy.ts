import { ethers, network } from "hardhat";
import { utils } from "ethers";

import { TestGelato } from "../typechain-types/contracts/TestGelato"
import { GelatoSplitableTimeBatch } from "../typechain-types/contracts/GelatoSplitableTimeBatch"

async function main() {

  let testGelato: TestGelato;
  let resolver: GelatoSplitableTimeBatch;

  let GELATO_WHITELIST_ROLE = utils.keccak256(utils.toUtf8Bytes("GELATO_WHITELIST"))
  let BATCH_WHITELIST_ROLE = utils.keccak256(utils.toUtf8Bytes("BATCH_WHITELIST"))  

  if (network.name === "mumbai") {

    const TestGelato = await ethers.getContractFactory("TestGelato")
    testGelato = await TestGelato.deploy();
    console.log(`TestGelato contract deployed at address ${testGelato.address}`)    

    const GelatoSplitableTimeBatch = await ethers.getContractFactory("GelatoSplitableTimeBatch")
    resolver = await GelatoSplitableTimeBatch.deploy(1679875200,1800,300,50000,1500000000);  // Monday 27 March 2023 00:00:00 GMT , 30 min repeat , 5 min timewindow , 50000 min gas, 1.5 gwei max gas price
    console.log(`Resolver contract deployed at address ${resolver.address}`) 

    await resolver.bindTargetContract(testGelato.address)
    await resolver.grantRole(GELATO_WHITELIST_ROLE,"0xce39a5ad467343f8ec1d68ce723628d6a9e5296e")
    await testGelato.grantRole(BATCH_WHITELIST_ROLE,resolver.address)
    console.log(`Access right granted`) 

  } 
  else {
    const TestGelato = await ethers.getContractFactory("TestGelato")
    testGelato = await TestGelato.deploy();
    console.log(`TestGelato contract deployed at address ${testGelato.address}`)    

    const GelatoSplitableTimeBatch = await ethers.getContractFactory("GelatoSplitableTimeBatch")
    resolver = await GelatoSplitableTimeBatch.deploy(1679875200,1800,300,50000,1500000000);  // Monday 27 March 2023 00:00:00 GMT , 30 min repeat , 5 min timewindow , 50000 min gas, 1.5 gwei max gas price
    console.log(`Resolver contract deployed at address ${resolver.address}`) 

    await resolver.bindTargetContract(testGelato.address)
    await resolver.grantRole(GELATO_WHITELIST_ROLE,"0xce39a5ad467343f8ec1d68ce723628d6a9e5296e")   // not valid on localhost
    await testGelato.grantRole(BATCH_WHITELIST_ROLE,resolver.address)
    console.log(`Access right granted`) 

    console.log(GELATO_WHITELIST_ROLE)
    console.log(BATCH_WHITELIST_ROLE)

  }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
