const { expect } = require("chai")
const { ethers } = require("hardhat")

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

describe('GPURentalMarketplace', () => {

    async function mainDeploy(){

        const [owner,otherAccount] = await ethers.getSigners();

        const GPURentalMarketplace = await hre.ethers.deployContract("GPURentalMarketplace")
        await GPURentalMarketplace.waitForDeployment()

        const Proxy = await hre.ethers.deployContract("Proxy",["0x8129fc1c",GPURentalMarketplace.target])
        await Proxy.waitForDeployment()

        const ProxyV1 = await GPURentalMarketplace.attach(Proxy.target);

        return {ProxyV1,owner,otherAccount}

    }

    describe('Deployement Testing', () => { 

        // Properly deployed
        it("Is properly deployed", async() => {

            const {ProxyV1,owner} = await mainDeploy()

            // Check owner is initialized 
            const testOwner  = await ProxyV1.owner()
            expect(testOwner).to.equal(owner.address)

        })

        // Is upgradable 
        it("Is upgrading", async() => {

            const {ProxyV1,owner} = await mainDeploy()

            // console.log(`Main contract and Proxy Deployed`)
            // await sleep(5*1000)

            // Deployed new contract logic
            const GPURentalMarketplaceV2 = await hre.ethers.deployContract("GPURentalMarketplaceV2")
            await GPURentalMarketplaceV2.waitForDeployment()

            // console.log(`V2 contract Deployed`)

            // Update contract login in old proxy contract
            const upgrade = ProxyV1.updateCode(GPURentalMarketplaceV2.target)
            const ProxyV2 = await GPURentalMarketplaceV2.attach(ProxyV1.target);

            // console.log(`Proxy contract updated!`)
            // await sleep(5*1000)

            // Check new added function
            const increase = await ProxyV2.increase()

            // console.log(`New function used!`)
            // await sleep(5*1000)
            
            const machineId = await ProxyV2.machineId()
            expect(machineId).to.equal(10001)

        })

    })

    describe('Functions Testing', () => {

        it("Register User Check", async() => {

            const {ProxyV1,owner,otherAccount} = await mainDeploy()

            // Unauthorized call check
            await expect(
                ProxyV1.registerUser(
                    "0xanon", 
                    100000, 
                    "test", 
                    otherAccount.address
                )
            )
            .to.be.revertedWith("Unauthorized call");

            // Event Testing 
            await expect(
                ProxyV1.registerUser(
                    "0xanon", 
                    100000, 
                    "test", 
                    owner.address
                )
            )
            .to.emit(ProxyV1, "userRegistered")
            .withArgs(owner.address, "0xanon");

            const userInfo = await ProxyV1.users(owner.address)

            expect(userInfo[0]).to.equal("0xanon")

        })

        it("Register Machine Check", async() => {

            const {ProxyV1,owner} = await mainDeploy()
            await ProxyV1.registerUser("0xanon", 100000, "test", owner.address)

            // Unauthorized call 
            await expect(
                ProxyV1.registerMachines(
                    "AMD EPYC 7R32", 
                    "NVIDIA A10G",
                    22,
                    8,
                    512,
                    8,
                    "3.235.148.209",
                    [22,80],
                    "Asia",
                    800,
                    owner.address
                )
            )
            .to.be.revertedWith("Unauthorized request");

            // Keys Setup
            await ProxyV1.setKeys(
                owner.address,
                "0xcE408f35c3D43F5609151310309De73f3e57Ec76",
                "0x6e54ebe8067bE3dc516D8a14bb40f4224b83FB46"
            )

            // Event Testing 
            await expect(
                ProxyV1.registerMachines(
                    "AMD EPYC 7R32", 
                    "NVIDIA A10G",
                    22,
                    10,
                    512,
                    8,
                    "3.235.148.209",
                    [22,80],
                    "Asia",
                    8,
                    owner.address
                )
            )
            .to.emit(ProxyV1, "MachineListed")
            .withArgs(10001, "NVIDIA A10G");

            const machineInfo = await ProxyV1.machines(10001)
            expect(machineInfo[0]).to.equal("AMD EPYC 7R32")

        })

        it("Rent Machine Check", async() => {

            const {ProxyV1,owner} = await mainDeploy()
            await ProxyV1.registerUser("0xanon", 100000, "test", owner.address)

            // Keys Setup
            await ProxyV1.setKeys(
                owner.address,
                "0xcE408f35c3D43F5609151310309De73f3e57Ec76",
                "0x6e54ebe8067bE3dc516D8a14bb40f4224b83FB46"
            )

            // Register Machine
            await ProxyV1.registerMachines("AMD EPYC 7R32", "NVIDIA A10G",22,10,512,8,"3.235.148.209",[22,80],"Asia",5,owner.address)


            // Gpoint Fallback check
            await expect(
                ProxyV1.rentMachine(
                    10001,
                    2,
                    101
                )
            )
            .to.be.revertedWith("Not enough Gpoints");

            // Event Test
            await expect(
                ProxyV1.rentMachine(
                    10001,
                    1,
                    101
                )
            )
            .to.emit(ProxyV1, "MachineRented")
            .withArgs(1, 10001, owner.address);

        })

        it("Complete Order Check", async() => {

            const {ProxyV1,owner} = await mainDeploy()
            await ProxyV1.registerUser("0xanon", 100000, "test", owner.address)

            // Keys Setup
            await ProxyV1.setKeys(
                owner.address,
                "0xcE408f35c3D43F5609151310309De73f3e57Ec76",
                "0x6e54ebe8067bE3dc516D8a14bb40f4224b83FB46"
            )

            // Register Machine
            await ProxyV1.registerMachines("AMD EPYC 7R32", "NVIDIA A10G",22,10,512,8,"3.235.148.209",[22,80],"Asia",1,owner.address)

            // Rent Machine
            await ProxyV1.rentMachine(10001,2,101)

            // Check complete order before order
            await expect(
                ProxyV1.completeOrder(1)
            )
            .to.be.revertedWithoutReason()

            // Set the next block timestamp to end order timestamp
            const currentTimestamp = (await ethers.provider.getBlock()).timestamp;
            await ethers.provider.send("evm_setNextBlockTimestamp", [currentTimestamp + 3600*2]);

            await ProxyV1.completeOrder(1)

            // Check if order is completed
            const orderInfo = await ProxyV1.orders(1)
            expect(orderInfo.isPending).to.equal(false)

        })


    })

})