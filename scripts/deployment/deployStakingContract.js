const { ethers, network } = require("hardhat")

async function deployStakingContract() {
    const stakingContract = await ethers.getContractFactory("StakeNFT")
    const contract = await stakingContract.deploy()

    await contract.deployed()

    return contract.address
}

module.exports = {
    deployStakingContract,
}
