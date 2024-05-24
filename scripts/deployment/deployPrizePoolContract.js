const { ethers, run } = require("hardhat")

async function deployPrizePoolContract() {
    const prizePoolContract = await ethers.getContractFactory("PrizePool")
    const contract = await prizePoolContract.deploy()

    await contract.deployed()

    console.log("PrizePool deployed to:", contract.address)

    // await run("verify:verify", {
    //     address: contract.address,
    //     constructorArguments: [],
    // })

    return contract.address
}

module.exports = {
    deployPrizePoolContract,
}
