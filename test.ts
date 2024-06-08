import ethers from "ethers"
import abi from "./abi.json"

const privateKey = process.env.PRIVATE_KEY

if (!privateKey) {
    throw new Error("PRIVATE_KEY is not set")
}

const provider = new ethers.providers.JsonRpcProvider("https://rpc.degen.tips")
const wallet = new ethers.Wallet(privateKey, provider)
const signer = wallet.connect(provider)

const contract = new ethers.Contract("0xa4c94e283c21b6e6f00014e0e10ac7b2fc959d51", abi, signer)

async function main() {
    const result = await contract.weth()
    console.log(result)

    const [salt, predictedAddress] = await contract.generateSalt(
        signer.address,
        "BHIM",
        "BHIM",
        1000000000000000000000000n,
        "0xe1e7581a239e3f0021bb65d1d58fd61a4488191f72a1b6d255083884835374b3"
    )
    console.log({ salt, predictedAddress })

    const creation = await contract.deployToken(
        "BHIM",
        "BHIM",
        1000000000000000000000000n,
        signer.address,
        100000000000000000000000n,
        -23200,
        10000,
        salt,
        100000000000000000000000n,
        "0xe1e7581a239e3f0021bb65d1d58fd61a4488191f72a1b6d255083884835374b3"
    )

    const receipt = await creation.wait()

    console.log(receipt.transactionHash)
}

main()
