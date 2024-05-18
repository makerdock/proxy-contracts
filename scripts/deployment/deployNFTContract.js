const { ethers, network } = require("hardhat")

async function deployCasterNFTContract(stakingAddress, prizePoolAddress, royaltyAddress) {
    const casterRankFactory = await ethers.getContractFactory("CasterNFT")
    const contract = await casterRankFactory.deploy()

    await contract.deployed()

    const attachedContract = casterRankFactory.attach(contract.address)

    await attachedContract.updateStakingContract(stakingAddress)
    await attachedContract.updatePrizePoolContract(prizePoolAddress)
    await attachedContract.updateRoyaltyContract(royaltyAddress)

    return contract.address
}

module.exports = {
    deployCasterNFTContract,
}
