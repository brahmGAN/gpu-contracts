const hre = require("hardhat")

const main = async () => {
  try {

    const GPURentalMarketplace = await hre.ethers.deployContract("GPURentalMarketplace")

    await GPURentalMarketplace.waitForDeployment()

    console.log(`Contract deployed at ${GPURentalMarketplace.target}`)

  } catch (error) {
    console.error(error);
  }
}

main()
