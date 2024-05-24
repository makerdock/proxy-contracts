const { expect } = require("chai")
const { ethers } = require("hardhat")

describe("PrizePool", function () {
    let PrizePool, prizePool, MockERC20, mockERC20
    let owner, addr1, addr2, backend

    beforeEach(async function () {
        ;[owner, addr1, addr2, backend] = await ethers.getSigners()

        MockERC20 = await ethers.getContractFactory("MockERC20")
        mockERC20 = await MockERC20.deploy()
        await mockERC20.deployed()

        PrizePool = await ethers.getContractFactory("PrizePool")
        prizePool = await PrizePool.deploy()
        await prizePool.deployed()

        // Update token contract address to mockERC20
        await prizePool.updateTokenContractAddress(mockERC20.address)
        await prizePool.updateServerWallet(backend.address)
    })

    describe("Deployment", function () {
        it("Should set the right token contract address", async function () {
            expect(await prizePool.TOKEN_CONTRACT_ADDRESS()).to.equal(mockERC20.address)
        })

        it("Should revert if trying to set an invalid token contract address", async function () {
            await expect(
                prizePool.updateTokenContractAddress(ethers.constants.AddressZero)
            ).to.be.revertedWith("Invalid address")
        })
    })

    describe("Winner Mapping Update", function () {
        it("Should update winner mapping correctly", async function () {
            const winningAddresses = [addr1.address, addr2.address]
            const winningAmounts = [100, 200]

            await prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)

            expect(await prizePool.winnerMapping(addr1.address)).to.equal(100)
            expect(await prizePool.winnerMapping(addr2.address)).to.equal(200)
        })

        it("Should update winner mapping by adding to existing amounts", async function () {
            const winningAddresses = [addr1.address, addr2.address]
            const winningAmounts = [100, 200]

            await prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)
            await prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)

            expect(await prizePool.winnerMapping(addr1.address)).to.equal(200)
            expect(await prizePool.winnerMapping(addr2.address)).to.equal(400)
        })

        it("Should revert if winning addresses and amounts length mismatch", async function () {
            const winningAddresses = [addr1.address, addr2.address]
            const winningAmounts = [100]

            await expect(
                prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)
            ).to.be.revertedWithCustomError(prizePool, "InvalidParams")
        })
    })

    describe("Claim Winnings", function () {
        beforeEach(async function () {
            // Transfer tokens to prize pool contract
            await mockERC20.transfer(prizePool.address, ethers.utils.parseUnits("1000", 18))

            // Set winning amounts
            const winningAddresses = [addr1.address, addr2.address]
            const winningAmounts = [
                ethers.utils.parseUnits("100", 18),
                ethers.utils.parseUnits("200", 18),
            ]

            await prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)
        })

        it("Should allow winners to claim their winnings", async function () {
            await prizePool.connect(addr1).claimWinnings()
            await prizePool.connect(addr2).claimWinnings()

            expect(await mockERC20.balanceOf(addr1.address)).to.equal(
                ethers.utils.parseUnits("100", 18)
            )
            expect(await mockERC20.balanceOf(addr2.address)).to.equal(
                ethers.utils.parseUnits("200", 18)
            )
            expect(await prizePool.winnerMapping(addr1.address)).to.equal(0)
            expect(await prizePool.winnerMapping(addr2.address)).to.equal(0)
        })

        it("Should revert if winner tries to claim more than available balance", async function () {
            const winningAddresses = [addr1.address]
            const winningAmounts = [ethers.utils.parseUnits("1100", 18)]

            await prizePool.connect(backend).updateWinnerMapping(winningAddresses, winningAmounts)

            await expect(prizePool.connect(addr1).claimWinnings()).to.be.revertedWithCustomError(
                prizePool,
                "InsufficientFunds"
            )
        })
    })
})
