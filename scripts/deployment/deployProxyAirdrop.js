const { ethers, run } = require("hardhat")

async function deployProxyAirdrop() {
    const proxyPadInstance = await ethers.getContractFactory("ProxyAirdrop")
    const contract = await proxyPadInstance.deploy()

    await contract.deployed()

    console.log("ProxyAirdrop contract deployed to:", contract.address)

    await run("verify:verify", {
        address: contract.address,
        constructorArguments: [],
    })

    return contract.address
}

module.exports = {
    deployProxyAirdrop,
}
