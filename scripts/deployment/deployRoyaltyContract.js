const { ethers, run } = require("hardhat")

async function deployRoyaltyContract() {
    const royaltyContract = await ethers.getContractFactory("RoyaltyBank")
    const contract = await royaltyContract.deploy()

    await contract.deployed()

    console.log("RoyaltyBank deployed to:", contract.address)

    await run("verify:verify", {
        address: contract.address,
        constructorArguments: [],
    })

    return contract.address
}

module.exports = {
    deployRoyaltyContract,
}
