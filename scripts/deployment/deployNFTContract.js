const { ethers, network } = require("hardhat")

async function deployCasterNFTContract() {
    const nftContractFactory = await ethers.getContractFactory("CasterNFT")
    const nftContract = await nftContractFactory.deploy()

    await nftContract.deployed()

    console.log("CasterNFT address -> ", nftContract.address)
}

module.exports = {
    deployCasterNFTContract,
}
