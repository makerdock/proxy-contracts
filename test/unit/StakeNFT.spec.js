const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("StakeNFT", function () {
    let StakeNFT, stakeNFT, casterNFT, CasterNFT, owner, addr1, addr2, backend

    beforeEach(async function () {
        ;[owner, addr1, addr2, backend, prizePool, treasury] = await ethers.getSigners()

        MockERC20 = await ethers.getContractFactory("MockERC20")
        mockERC20 = await MockERC20.deploy()
        await mockERC20.deployed()

        StakeNFT = await ethers.getContractFactory("StakeNFT")
        stakeNFT = await StakeNFT.deploy()
        await stakeNFT.deployed()

        // Update CasterNFT address

        CasterNFT = await ethers.getContractFactory("CasterNFT")
        casterNFT = await CasterNFT.deploy(mockERC20.address)
        await casterNFT.deployed()

        RoyaltyBank = await ethers.getContractFactory("RoyaltyBank")
        royaltyBank = await RoyaltyBank.deploy()
        await royaltyBank.deployed()

        await casterNFT.updateTreasuryAddress(treasury.address)
        await casterNFT.updatePrizePoolAddress(prizePool.address)
        await casterNFT.updateRoyaltyContractAddress(royaltyBank.address)

        await royaltyBank.updateCasterNFTAddress(casterNFT.address)
        await stakeNFT.updateCasterNFTAddress(casterNFT.address)
        await stakeNFT.updateServerWallet(backend.address)

        // Mint some NFTs to addr1
        await mockERC20.transfer(addr1.address, ethers.utils.parseEther("1000000000000")) // Transfer some mock tokens to addr1
        await mockERC20
            .connect(addr1)
            .approve(casterNFT.address, ethers.utils.parseEther("1000000000000"))

        await casterNFT.connect(addr1).mint(1, 10)
        await casterNFT.connect(addr1).mint(2, 5)
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
            const signature = await generateSignature(addr1.address, nonce)

            console.log({ signature })

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
            const signature = await generateSignature(addr1.address, nonce)

            await casterNFT.connect(addr1).setApprovalForAll(stakeNFT.address, true)

            await expect(
                stakeNFT.connect(backend).stakeNFTs(addr1.address, ids, amounts, signature, nonce)
            ).to.be.revertedWithCustomError(stakeNFT, "InsufficientBalance")
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
            const signature = await generateSignature(addr1.address, nonce)

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
            await expect(stakeNFT.connect(addr2).unstake(1)).to.be.revertedWithCustomError(
                stakeNFT,
                "UnAuthorizedAction"
            )
        })
    })

    async function generateSignature(address, nonce) {
        const message = ethers.utils.solidityKeccak256(["address", "uint32"], [address, nonce])
        const messageBytes = ethers.utils.arrayify(message)
        const signature = await backend.signMessage(messageBytes)
        return signature
    }
})
