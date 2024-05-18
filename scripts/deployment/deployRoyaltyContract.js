const { ethers, network } = require("hardhat")

async function deployRoyaltyContract() {
    const royaltyContract = await ethers.getContractFactory("RoyaltyBank")
    const contract = await royaltyContract.deploy()

    await contract.deployed()

    return contract.address
}

module.exports = {
    deployRoyaltyContract,
}
