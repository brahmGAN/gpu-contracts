const hre = require("hardhat")

const main = async () => {
  try {

    const GPURentalMarketplace = await hre.ethers.deployContract("GPURentalMarketplace")
    await GPURentalMarketplace.waitForDeployment()
    console.log(`Logic Contract deployed at ${GPURentalMarketplace.target}`)

    const Proxy = await hre.ethers.deployContract("Proxy",["0x8129fc1c",GPURentalMarketplace.target])
    await Proxy.waitForDeployment()
    console.log(`Proxy Contract deployed at ${Proxy.target}`)

  } catch (error) {
    console.error(error);
  }
}

main()
