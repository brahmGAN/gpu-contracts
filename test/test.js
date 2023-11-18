const { expect } = require("chai")
const { ethers } = require("hardhat")


describe('GPURentalMarketplace', () => {

    async function mainDeploy(){

        const [owner] = await ethers.getSigners();

        const GPURentalMarketplace = await hre.ethers.deployContract("GPURentalMarketplace")
        await GPURentalMarketplace.waitForDeployment()

        const Proxy = await hre.ethers.deployContract("Proxy",["0x8129fc1c",GPURentalMarketplace.target])
        await Proxy.waitForDeployment()

        const ProxyV1 = await GPURentalMarketplace.attach(Proxy.target);

        return {ProxyV1,owner}

    }

    describe('Deployement', () => { 

        // Properly deployed
        it("Is properly deployed", async() => {

            const {ProxyV1,owner} = await mainDeploy()
            const testOwner  = await ProxyV1.owner()
            expect(testOwner).to.equal(owner.address)

        })

        // Is upgradable 
        it("Is upgrading", async() => {

            const {ProxyV1,owner} = await mainDeploy()

            const GPURentalMarketplaceV2 = await hre.ethers.deployContract("GPURentalMarketplaceV2")
            await GPURentalMarketplaceV2.waitForDeployment()

            const upgrade = ProxyV1.updateCode(GPURentalMarketplaceV2.target)
            const ProxyV2 = await GPURentalMarketplaceV2.attach(ProxyV1.target);

            // Check new added function
            const increase = await ProxyV2.increase()
            const machineId = await ProxyV2.machineId()

            expect(machineId).to.equal(10001)

        })

     })

    mainDeploy()

})