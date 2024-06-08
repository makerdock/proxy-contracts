import ethers from "ethers"
import abi from "./abi.json"

const privateKey = process.env.PRIVATE_KEY

if (!privateKey) {
    throw new Error("PRIVATE_KEY is not set")
}

const provider = new ethers.providers.JsonRpcProvider("https://rpc.degen.tips")
const wallet = new ethers.Wallet(privateKey, provider)
const signer = wallet.connect(provider)

const contract = new ethers.Contract("0x68df0bf99c85998f65fe9e4cc2110c329d3b9ecb", abi, signer)

async function main() {
    const result = await contract.weth()
    console.log(result)

    const [salt, predictedAddress] = await contract.generateSalt(
        signer.address,
        "ABHI",
        "ABHI",
        1000000000000000000000000n
    )
    console.log({ salt, predictedAddress })

    const creation = await contract.deployToken(
        "ABHI",
        "ABHI",
        1000000000000000000000000n,
        signer.address,
        100000000000000000000000n,
        -23200,
        10000,
        salt
    )

    const receipt = await creation.wait()

    console.log(receipt.transactionHash)
}

main()
