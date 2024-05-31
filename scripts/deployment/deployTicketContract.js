const { ethers, run } = require("hardhat")

async function deployTicketContract() {
    const ticketContractInstance = await ethers.getContractFactory("Ticket")
    const contract = await ticketContractInstance.deploy()

    await contract.deployed()

    console.log("Ticket contract deployed to:", contract.address)

    await run("verify:verify", {
        address: contract.address,
        constructorArguments: [],
    })

    return contract.address
}

module.exports = {
    deployTicketContract,
}
