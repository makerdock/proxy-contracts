const { ethers, network } = require("hardhat")

async function deployPrizePoolContract() {
    const prizePoolContract = await ethers.getContractFactory("PrizePool")
    const contract = await prizePoolContract.deploy()

    await contract.deployed()

    return contract.address
}

module.exports = {
    deployPrizePoolContract,
}
