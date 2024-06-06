const { ethers, run } = require("hardhat")

async function deployProxypadDeployer() {
    const proxyPadInstance = await ethers.getContractFactory("ProxypadDeployerLP")
    const contract = await proxyPadInstance.deploy()

    await contract.deployed()

    console.log("Proxypad contract deployed to:", contract.address)

    await run("verify:verify", {
        address: contract.address,
        constructorArguments: [],
    })

    return contract.address
}

module.exports = {
    deployProxypadDeployer,
}
