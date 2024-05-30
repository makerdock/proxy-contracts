// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { run } = require("hardhat")
const { deployCasterNFTContract } = require("./deployNFTContract")
const { deployPrizePoolContract } = require("./deployPrizePoolContract")
const { deployRoyaltyContract } = require("./deployRoyaltyContract")

async function main() {
    await run("compile")

    const prizePoolContract = await deployPrizePoolContract()
    const royaltyContract = await deployRoyaltyContract()
    const casterrankContract = await deployCasterNFTContract(prizePoolContract, royaltyContract)

    console.log("********************* Contracts Deployed *********************")
    console.log("CasterRank NFT Contract: ", casterrankContract)
    console.log("Prize Pool Contract: ", prizePoolContract)
    console.log("Royalty Contract: ", royaltyContract)
    console.log("**************************************************************")

    const royaltyContractInstance = await ethers.getContractFactory("RoyaltyBank")
    const attachedRoyalyContract = await royaltyContractInstance.attach(royaltyContract)

    await attachedRoyalyContract.updateCasterNFTAddress(casterrankContract)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
