const { ethers, run, network } = require("hardhat")

async function deployStakingContract() {
    console.log(network)

    const stakingContract = await ethers.getContractFactory("StakeNFT")
    const contract = await stakingContract.deploy()

    await contract.deployed()

    console.log("StakeNFT deployed to:", contract.address)

    await run("verify:verify", {
        address: contract.address,
        constructorArguments: [],
    })

    return contract.address
}

module.exports = {
    deployStakingContract,
}
