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

        RoyaltyBank = await ethers.getContractFactory("RoyaltyBank")
        royaltyBank = await RoyaltyBank.deploy()
        await royaltyBank.deployed()

        await casterNFT.updateTreasuryAddress(treasury.address)
        await casterNFT.updatePrizePoolAddress(prizePool.address)
        await casterNFT.updateRoyaltyContractAddress(royaltyBank.address)

        await royaltyBank.updateCasterNFTAddress(casterNFT.address)
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
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("1000000000000000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000000000000000", 18))

            for (let i = 0; i < 500; i++) {
                await casterNFT.connect(addr1).mint(1, 1)
            }

            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
                "TokenSupplyExceeded"
            )
        })

        it("Should fail to mint tokens if insufficient ERC20 allowance", async function () {
            // Transfer some tokens to addr1 but not enough to mint
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10", 18)) // Assuming 10 tokens are not enough

            // Attempt to mint with insufficient balance
            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
                "InsufficientAllowance"
            )
        })

        it("Should fail to mint tokens if insufficient ERC20 balance", async function () {
            // Transfer some tokens to addr1 but not enough to mint
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("1", 18)) // Assuming 10 tokens are not enough

            // Approve CasterNFT contract to spend addr1's tokens
            await mockERC20.connect(addr1).approve(casterNFT.address, "80")

            // Attempt to mint with insufficient balance
            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
                "InsufficientAllowance"
            )
        })
    })

    describe("Staking", function () {
        it("Should fail to stake if balance is insufficient", async function () {
            await expect(
                casterNFT.connect(addr1).stakeNFTs(addr2.address, [1], [1], "0x", 1)
            ).to.be.revertedWithCustomError(casterNFT, "InsufficientBalance")
        })
    })

    describe("Forfeiting", function () {
        it("Should forfeit NFTs correctly", async function () {
            // Transfer sufficient ERC20 tokens to addr1
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10000", 18))

            // Approve CasterNFT contract to spend addr1's tokens
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("10000", 18))

            // Mint an NFT for addr1
            await casterNFT.connect(addr1).mint(1, 1)

            console.log(await casterNFT.balanceOf(addr1.address, 1))
            console.log(await mockERC20.balanceOf(addr1.address))
            console.log(await mockERC20.balanceOf(casterNFT.address))

            // Ensure the token was minted
            expect(await casterNFT.currentSupply(1)).to.equal(1)
            expect(await casterNFT.balanceOf(addr1.address, 1)).to.equal(1)

            // Forfeit the NFT
            await casterNFT.connect(addr1).forfeitNFT(1, 1)

            // Ensure the token was forfeited
            expect(await casterNFT.currentSupply(1)).to.equal(0)
            expect(await casterNFT.balanceOf(addr1.address, 1)).to.equal(0)
        })

        it("Should fail to forfeit if balance is insufficient", async function () {
            await expect(casterNFT.connect(addr1).forfeitNFT(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
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
            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
                "EnforcedPause"
            )

            await casterNFT.unpause()
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("10000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000", 18))
            await casterNFT.connect(addr1).mint(1, 1)

            expect(await casterNFT.currentSupply(1)).to.equal(1)
        })

        it("Should fail to pause/unpause by non-owner", async function () {
            await expect(casterNFT.connect(addr1).pause()).to.be.revertedWithCustomError(
                casterNFT,
                "OwnableUnauthorizedAccount"
            )
            await expect(casterNFT.connect(addr1).unpause()).to.be.revertedWithCustomError(
                casterNFT,
                "OwnableUnauthorizedAccount"
            )
        })
    })

    describe("Custom Error Reverts", function () {
        it("Should revert with InvalidAction on mint with zero amount", async function () {
            await expect(casterNFT.connect(addr1).mint(1, 0)).to.be.revertedWithCustomError(
                casterNFT,
                "InvalidAction"
            )
        })

        it("Should revert with InsufficientBalance on stake with zero balance", async function () {
            await expect(
                casterNFT.connect(addr1).stakeNFTs(addr2.address, [1], [1], "0x", 1)
            ).to.be.revertedWithCustomError(casterNFT, "InsufficientBalance")
        })

        it("Should revert with InvalidAction on forfeit with zero amount", async function () {
            await expect(casterNFT.connect(addr1).forfeitNFT(1, 0)).to.be.revertedWithCustomError(
                casterNFT,
                "InvalidAction"
            )
        })

        it("Should revert with TokenSupplyExceeded when exceeding max supply", async function () {
            await mockERC20.transfer(addr1.address, ethers.utils.parseUnits("1000000000000000", 18))
            await mockERC20
                .connect(addr1)
                .approve(casterNFT.address, ethers.utils.parseUnits("1000000000000000", 18))

            for (let i = 0; i < 500; i++) {
                await casterNFT.connect(addr1).mint(1, 1)
            }

            await expect(casterNFT.connect(addr1).mint(1, 1)).to.be.revertedWithCustomError(
                casterNFT,
                "TokenSupplyExceeded"
            )
        })
    })

    describe("Bonding Curve Price Calculation", function () {
        it("Should return the correct bonding curve price for token ID 1", async function () {
            const price = await casterNFT.getMintPriceForToken(1, 1)
            const expectedPrice = ethers.utils.parseUnits("80", 18) // 1 -> 80
            expect(price).to.equal(expectedPrice)
        })

        it("Should return the correct bonding curve price for token ID 2", async function () {
            const price = await casterNFT.getMintPriceForToken(1, 2)
            const expectedPrice = ethers.utils.parseUnits("204", 18) // 2 -> 124.84
            expect(price).to.be.closeTo(expectedPrice, ethers.utils.parseUnits("0.01", 18))
        })

        it("Should return the correct bonding curve price for token ID 3", async function () {
            const price = await casterNFT.getMintPriceForToken(1, 3)
            const expectedPrice = ethers.utils.parseUnits("394", 18) // 3 -> 190
            expect(price).to.equal(expectedPrice)
        })
    })
})
