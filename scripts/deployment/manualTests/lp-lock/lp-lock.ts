import ethers from "ethers"
import abi from "./abi.json"
import locker from "./locker.json"
import nftmanagerAbi from "./nftManager.json"
import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

const privateKey = process.env.PRIVATE_KEY

if (!privateKey) {
    throw new Error("PRIVATE_KEY is not set")
}

const provider = new ethers.providers.JsonRpcProvider("https://rpc.degen.tips")
const wallet = new ethers.Wallet(privateKey, provider)
const signer = wallet.connect(provider)

const factoryContractAddress = "0x053898aB911CDE9C1979a57922002EaD5906f574"
// const lpLockerAddress = "0x3cf367cd41eb3ab372bd8000d364729ec9e67f87"
const nftManagerAddress = "0x56c65e35f2dd06f659bcfe327c4d7f21c9b69c2f"

const nftId = 816

const contract = new ethers.Contract(factoryContractAddress, abi, signer)
const nftManagerContract = new ethers.Contract(nftManagerAddress, nftmanagerAbi, signer)
const lockerContract = (lockerAddress) => new ethers.Contract(lockerAddress, locker, signer)

const currentEpochTime = Math.floor(Date.now() / 1000)
const epochDuration = currentEpochTime + 60

async function main() {
    const contractTx = await contract.deploy(
        nftManagerAddress,
        signer.address,
        epochDuration,
        nftId,
        0
    )
    const contractReceipt = await contractTx.wait()

    console.log("Locker deployed from factory", contractReceipt.transactionHash)

    const { logs } = contractReceipt
    const deployLog = logs[logs.length - 1]
    const { topics } = deployLog
    const deployAddress = topics[1]
    const [formattedDeployAddress] = ethers.utils.defaultAbiCoder.decode(["address"], deployAddress)

    console.log("Locker address", formattedDeployAddress)

    const nftApproval = await nftManagerContract.approve(formattedDeployAddress, nftId)
    const nftApprovalReceipt = await nftApproval.wait()

    console.log("NFT approved", nftApprovalReceipt.transactionHash)

    const lockerInstance = lockerContract(formattedDeployAddress)

    const lockerTx = await lockerInstance.initializer(nftId)
    const lockerReceipt = await lockerTx.wait()

    console.log("Locker initialized", lockerReceipt.transactionHash)
}

async function canRelease() {
    const lockerInstance = lockerContract("0x586Caa88af36cDb274bf7028Cb92c58249E423f4")
    const canRelease = await lockerInstance.vestingSchedule()
    console.log("Can release", canRelease.toString())
}

async function release() {
    const lockerInstance = lockerContract("0x586Caa88af36cDb274bf7028Cb92c58249E423f4")

    const canRelease = await lockerInstance.vestingSchedule()
    console.log("Can release", canRelease.toString())

    const collectFees = await lockerInstance.collectFees(signer.address, nftId)
    const collectFeesReceipt = await collectFees.wait()

    console.log("Fees collected", collectFeesReceipt.transactionHash)

    const releaseTx = await lockerInstance.release()
    const releaseReceipt = await releaseTx.wait()

    console.log("Released", releaseReceipt.transactionHash)
}

// main()
// canRelease()
release()
