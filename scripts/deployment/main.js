// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { run } = require("hardhat")
const { deployCasterNFTContract } = require("./deployNFTContract")
const { deployStakingContract } = require("./deployStakingContract")
const { deployPrizePoolContract } = require("./deployPrizePoolContract")
const { deployRoyaltyContract } = require("./deployRoyaltyContract")

async function main() {
    await run("compile")

    const stakingContract = await deployStakingContract()
    const prizePoolContract = await deployPrizePoolContract()
    const royaltyContract = await deployRoyaltyContract()
    const casterrankContract = await deployCasterNFTContract(
        stakingContract.address,
        prizePoolContract.address,
        royaltyContract.address
    )

    console.log("********************* Contracts Deployed *********************")
    console.log("CasterRank NFT Contract: ", casterrankContract.address)
    console.log("Staking Contract: ", stakingContract.address)
    console.log("Prize Pool Contract: ", prizePoolContract.address)
    console.log("Royalty Contract: ", royaltyContract.address)
    console.log("**************************************************************")

    const attachedStakingContract = await stakingContract.attach(stakingContract.address)

    const attachedRoyalyContract = await royaltyContract.attach(royaltyContract.address)

    await attachedStakingContract.updateCasterRankContract(casterrankContract.address)
    await attachedRoyalyContract.updateCasterRankContract(casterrankContract.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
