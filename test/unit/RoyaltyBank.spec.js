const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("RoyaltyBank", function () {
    let RoyaltyBank, royaltyBank, MockERC20, mockERC20
    let owner, addr1, addr2, casterNFT

    beforeEach(async function () {
        ;[owner, addr1, addr2, casterNFT, backend] = await ethers.getSigners()

        MockERC20 = await ethers.getContractFactory("MockERC20")
        mockERC20 = await MockERC20.deploy()
        await mockERC20.deployed()

        RoyaltyBank = await ethers.getContractFactory("RoyaltyBank")
        royaltyBank = await RoyaltyBank.deploy()
        await royaltyBank.deployed()

        // Update token contract address to mockERC20 and set casterNFT address
        await royaltyBank.updateTokenContractAddress(mockERC20.address)
        await royaltyBank.updateCasterNFTAddress(casterNFT.address)
        await royaltyBank.updateServerWallet(backend.address)
    })

    describe("Deployment", function () {
        it("Should set the right token contract address", async function () {
            expect(await royaltyBank.TOKEN_CONTRACT_ADDRESS()).to.equal(mockERC20.address)
        })

        it("Should set the right caster NFT address", async function () {
            expect(await royaltyBank.CASTER_NFT_ADDRESS()).to.equal(casterNFT.address)
        })

        it("Should revert if trying to set an invalid token contract address", async function () {
            await expect(
                royaltyBank.updateTokenContractAddress(ethers.constants.AddressZero)
            ).to.be.revertedWithCustomError(royaltyBank, "InvalidAddress")
        })

        it("Should revert if trying to set an invalid caster NFT address", async function () {
            await expect(
                royaltyBank.updateCasterNFTAddress(ethers.constants.AddressZero)
            ).to.be.revertedWithCustomError(royaltyBank, "InvalidAddress")
        })
    })

    describe("Updating Rewards Mapping", function () {
        it("Should update rewards mapping correctly by caster NFT", async function () {
            await royaltyBank.connect(casterNFT).updateRewardsMapping(1, 100)
            expect(await royaltyBank.royalties(1)).to.equal(100)

            await royaltyBank.connect(casterNFT).updateRewardsMapping(1, 50)
            expect(await royaltyBank.royalties(1)).to.equal(150)
        })

        it("Should revert if non-caster NFT tries to update rewards mapping", async function () {
            await expect(
                royaltyBank.connect(addr1).updateRewardsMapping(1, 100)
            ).to.be.revertedWithCustomError(royaltyBank, "UnAuthorizedAction")
        })
    })

    describe("Claiming Rewards", function () {
        beforeEach(async function () {
            // Transfer tokens to royalty bank contract
            await mockERC20.transfer(royaltyBank.address, ethers.utils.parseUnits("1000", 6))

            // Set rewards
            await royaltyBank
                .connect(casterNFT)
                .updateRewardsMapping(1, ethers.utils.parseUnits("100", 6))
        })

        it("Should allow claiming rewards by the creator", async function () {
            await royaltyBank.connect(backend).claimReward(1, addr1.address)

            expect(await mockERC20.balanceOf(addr1.address)).to.equal(
                ethers.utils.parseUnits("100", 6)
            )
            expect(await royaltyBank.royalties(1)).to.equal(0)
        })

        it("Should revert if a non-backend tries to claim rewards", async function () {
            await expect(
                royaltyBank.connect(addr1).claimReward(1, addr1.address)
            ).to.be.revertedWithCustomError(royaltyBank, "UnAuthorizedAction")
        })
    })
})
