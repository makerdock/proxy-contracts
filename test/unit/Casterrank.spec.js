const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("CasterNFT", function () {
    let CasterNFT, casterNFT, MockERC20, mockERC20
    let owner, addr1, addr2, treasury, prizePool, royalty

    beforeEach(async function () {
        ;[owner, addr1, addr2, treasury, prizePool, royalty] = await ethers.getSigners()

        MockERC20 = await ethers.getContractFactory("MockERC20")
        mockERC20 = await MockERC20.deploy()
        await mockERC20.deployed()

        CasterNFT = await ethers.getContractFactory("CasterNFT")
        casterNFT = await CasterNFT.deploy(mockERC20.address)
        await casterNFT.deployed()

        await casterNFT.updateTreasuryAddress(treasury.address)
        await casterNFT.updatePrizePoolAddress(prizePool.address)
        await casterNFT.updateRoyaltyContractAddress(royalty.address)
    })

    describe("Deployment", function () {
        it("Should set the right ERC20 address", async function () {
            expect(await casterNFT.erc20Instance()).to.equal(mockERC20.address)
        })
    })

    describe("Minting", function () {
        it("Should mint tokens correctly", async function () {
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000", 18))

            await casterNFT.connect(addr1).mint(1, 1)

            expect(await casterNFT.currentSupply(1)).to.equal(1)
            expect(await casterNFT.balanceOf(addr1.address, 1)).to.equal(1)
        })

        it("Should fail to mint tokens if max supply is reached", async function () {
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("100000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("100000", 18))

            for (let i = 0; i < 500; i++) {
                await casterNFT.connect(addr1).mint(1, 1)
            }

            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWith(
                "TokenSupplyExceeded"
            )
        })

        it("Should fail to mint tokens if insufficient ERC20 balance", async function () {
            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWith(
                "ERC20: transfer amount exceeds balance"
            )
        })
    })

    describe("Staking", function () {
        it("Should fail to stake if balance is insufficient", async function () {
            await expect(
                casterNFT.connect(addr1).stakeNFTs(addr2.address, [1], [1], "0x", 1)
            ).to.be.revertedWith("InsufficientBalance")
        })
    })

    describe("Forfeiting", function () {
        it("Should forfeit NFTs correctly", async function () {
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000", 18))
            await casterNFT.connect(addr1).mint(1, 1)
            await casterNFT.connect(addr1).forfeitNFT(1, 1)

            expect(await casterNFT.currentSupply(1)).to.equal(0)
            expect(await casterNFT.balanceOf(addr1.address, 1)).to.equal(0)
        })

        it("Should fail to forfeit if balance is insufficient", async function () {
            await expect(casterNFT.connect(addr1).forfeitNFT(1, 1)).to.be.revertedWith(
                "InsufficientBalance"
            )
        })
    })

    describe("Admin Functions", function () {
        it("Should update addresses correctly", async function () {
            await casterNFT.updateTreasuryAddress(addr2.address)
            expect(await casterNFT.TREASURY_ADDRESS()).to.equal(addr2.address)

            await casterNFT.updatePrizePoolAddress(owner.address)
            expect(await casterNFT.PRIZE_POOL_ADDRESS()).to.equal(owner.address)

            await casterNFT.updateRoyaltyContractAddress(addr2.address)
            expect(await casterNFT.ROYALTY_CONTRACT_ADDRESS()).to.equal(addr2.address)
        })

        it("Should fail to update addresses by non-owner", async function () {
            await expect(casterNFT.connect(addr1).updateTreasuryAddress(addr2.address)).to.be
                .reverted
            await expect(casterNFT.connect(addr1).updatePrizePoolAddress(addr2.address)).to.be
                .reverted
            await expect(casterNFT.connect(addr1).updateRoyaltyContractAddress(addr2.address)).to.be
                .reverted
        })
    })

    describe("Pausable", function () {
        it("Should pause and unpause contract", async function () {
            await casterNFT.pause()
            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWith("Pausable: paused")

            await casterNFT.unpause()
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000", 18))
            await casterNFT.connect(addr1).mint(1, 1)

            expect(await casterNFT.currentSupply(1)).to.equal(1)
        })

        it("Should fail to pause/unpause by non-owner", async function () {
            await expect(casterNFT.connect(addr1).pause()).to.be.revertedWith(
                "Ownable: caller is not the owner"
            )
            await expect(casterNFT.connect(addr1).unpause()).to.be.revertedWith(
                "Ownable: caller is not the owner"
            )
        })
    })

    describe("Custom Error Reverts", function () {
        it("Should revert with InvalidAction on mint with zero amount", async function () {
            await expect(casterNFT.connect(addr1).mint(1, 0)).to.be.revertedWith("InvalidAction")
        })

        it("Should revert with InsufficientBalance on stake with zero balance", async function () {
            await expect(
                casterNFT.connect(addr1).stakeNFTs(addr2.address, [1], [1], "0x", 1)
            ).to.be.revertedWith("InsufficientBalance")
        })

        it("Should revert with InvalidAction on forfeit with zero amount", async function () {
            await expect(casterNFT.connect(addr1).forfeitNFT(1, 0)).to.be.revertedWith(
                "InvalidAction"
            )
        })

        it("Should revert with TokenSupplyExceeded when exceeding max supply", async function () {
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("100000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("100000", 18))

            for (let i = 0; i < 500; i++) {
                await casterNFT.connect(addr1).mint(1, 1)
            }

            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWith(
                "TokenSupplyExceeded"
            )
        })
    })
})
