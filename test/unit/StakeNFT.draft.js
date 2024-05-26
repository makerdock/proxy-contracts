const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("StakeNFT", function () {
    let StakeNFT, stakeNFT, CasterNFT, casterNFT, owner, addr1, addr2, backend

    beforeEach(async function () {
        ;[owner, addr1, addr2, backend] = await ethers.getSigners()

        MockERC20 = await ethers.getContractFactory("MockERC20")
        mockERC20 = await MockERC20.deploy()
        await mockERC20.deployed()

        // Deploy CasterNFT contract
        CasterNFT = await ethers.getContractFactory("CasterNFT")
        casterNFT = await CasterNFT.deploy(mockERC20.address)
        await casterNFT.deployed()

        // Deploy StakeNFT contract
        StakeNFT = await ethers.getContractFactory("StakeNFT")
        stakeNFT = await StakeNFT.deploy()
        await stakeNFT.deployed()

        // Set CasterNFT contract address
        await stakeNFT.updateCasterNFTAddress(casterNFT.address)

        // Mint some NFTs to addr1
        await casterNFT.connect(addr1).mint(addr1.address, 1, 10, "0x")
        await casterNFT.connect(addr1).mint(addr1.address, 2, 5, "0x")
    })

    describe("Deployment", function () {
        it("Should set the right CasterNFT contract address", async function () {
            expect(await stakeNFT.CASTER_NFT_CONTRACT_ADDRESS()).to.equal(casterNFT.address)
        })
    })

    describe("Staking NFTs", function () {
        it("Should stake NFTs correctly", async function () {
            const ids = [1, 2]
            const amounts = [5, 3]
            const nonce = 1
            const signature = await generateSignature(addr1, nonce)

            await casterNFT.connect(addr1).setApprovalForAll(stakeNFT.address, true)

            await stakeNFT.connect(backend).stakeNFTs(addr1.address, ids, amounts, signature, nonce)

            const stakedNFTDetails = await stakeNFT.getStakedNFTDetails(1)

            expect(stakedNFTDetails.ids).to.deep.equal(ids)
            expect(stakedNFTDetails.amounts).to.deep.equal(amounts)
        })

        it("Should revert if user tries to stake more than they own", async function () {
            const ids = [1, 2]
            const amounts = [11, 6] // Exceeding owned amounts
            const nonce = 1
            const signature = await generateSignature(addr1, nonce)

            await casterNFT.connect(addr1).setApprovalForAll(stakeNFT.address, true)

            await expect(
                stakeNFT.connect(backend).stakeNFTs(addr1.address, ids, amounts, signature, nonce)
            ).to.be.revertedWith("InsufficientBalance")
        })

        it("Should revert if signature is invalid", async function () {
            const ids = [1, 2]
            const amounts = [5, 3]
            const nonce = 1
            const invalidSignature = "0x" // Invalid signature

            await casterNFT.connect(addr1).setApprovalForAll(stakeNFT.address, true)

            await expect(
                stakeNFT
                    .connect(backend)
                    .stakeNFTs(addr1.address, ids, amounts, invalidSignature, nonce)
            ).to.be.reverted
        })
    })

    describe("Unstaking NFTs", function () {
        beforeEach(async function () {
            const ids = [1, 2]
            const amounts = [5, 3]
            const nonce = 1
            const signature = await generateSignature(addr1, nonce)

            await casterNFT.connect(addr1).setApprovalForAll(stakeNFT.address, true)
            await stakeNFT.connect(backend).stakeNFTs(addr1.address, ids, amounts, signature, nonce)
        })

        it("Should unstake NFTs correctly", async function () {
            await stakeNFT.connect(addr1).unstake(1)

            const balance1 = await casterNFT.balanceOf(addr1.address, 1)
            const balance2 = await casterNFT.balanceOf(addr1.address, 2)

            expect(balance1).to.equal(10)
            expect(balance2).to.equal(5)
        })

        it("Should revert if non-owner tries to unstake", async function () {
            await expect(stakeNFT.connect(addr2).unstake(1)).to.be.revertedWith(
                "UnAuthorizedAction"
            )
        })
    })

    async function generateSignature(user, nonce) {
        // This function should generate a valid signature for the staking
        // The implementation of this function depends on the verifySignature logic in your contract
        // Assuming a simple signature logic here for demonstration purposes
        const message = ethers.utils.solidityKeccak256(["address", "uint32"], [user.address, nonce])
        const messageBytes = ethers.utils.arrayify(message)
        return await user.signMessage(messageBytes)
    }
})
