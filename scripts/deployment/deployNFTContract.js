const { ethers, run } = require("hardhat")

async function deployCasterNFTContract(stakingAddress, prizePoolAddress, royaltyAddress) {
    // Sepolia: 0xe830FD11041DD651B097D526aa8bF52f1C660A39
    // Base: 0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed
    const DEGEN_ADDRESS = "0xe830FD11041DD651B097D526aa8bF52f1C660A39"

    const casterRankFactory = await ethers.getContractFactory("CasterNFT")
    const contract = await casterRankFactory.deploy(DEGEN_ADDRESS)

    await contract.deployed()

    console.log("CasterNFT deployed to:", contract.address)

    const attachedContract = casterRankFactory.attach(contract.address)

    // await run("verify:verify", {
    //     address: contract.address,
    //     constructorArguments: [DEGEN_ADDRESS],
    // })

    console.log({
        stakingAddress,
        prizePoolAddress,
        royaltyAddress,
    })

    await attachedContract.updateWhitelistedStakingContracts(stakingAddress, 1)
    await attachedContract.updatePrizePoolAddress(prizePoolAddress)
    await attachedContract.updateRoyaltyContractAddress(royaltyAddress)

    return contract.address
}

module.exports = {
    deployCasterNFTContract,
}
