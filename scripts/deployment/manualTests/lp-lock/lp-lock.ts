import ethers from "ethers"
import abi from "./abi.json"
import locker from "./locker.json"
import nftmanagerAbi from "./nftManager.json"
import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

const privateKey = process.env.PRIVATE_KEY

if (!privateKey) {
    throw new Error("PRIVATE_KEY is not set")
}

const provider = new ethers.providers.JsonRpcProvider("https://ham.calderachain.xyz/http")
const wallet = new ethers.Wallet(privateKey, provider)
const signer = wallet.connect(provider)

const factoryContractAddress = "0x8E38F63BE3D9fB1B79D0DA3F17f3A56deBA7080D"
// const lpLockerAddress = "0x3cf367cd41eb3ab372bd8000d364729ec9e67f87"
const nftManagerAddress = "0xD088322Fa988225B3936555894E1D21c1A727859"

const nftId = 23

const contract = new ethers.Contract(factoryContractAddress, abi, signer)
const nftManagerContract = new ethers.Contract(nftManagerAddress, nftmanagerAbi, signer)
const lockerContract = (lockerAddress) => new ethers.Contract(lockerAddress, locker, signer)

const currentEpochTime = Math.floor(Date.now() / 1000)
const epochDuration = currentEpochTime + 60

async function main() {
    const feeReceiver = await contract.feeRecipient()

    console.log({
        feeReceiver,
        nftManagerAddress,
        signer: signer.address,
        epochDuration,
        nftId,
    })

    const contractTx = await contract.deploy(
        nftManagerAddress,
        signer.address,
        epochDuration,
        nftId,
        0
        // {
        //     gasPrice: ethers.BigNumber.from("1000000"),
        //     gasLimit: ethers.BigNumber.from("1000000"),
        // }
    )

    console.log("Deploying locker from factory", contractTx.hash)

    const contractReceipt = await contractTx.wait()

    console.log("Locker deployed from factory", contractReceipt.transactionHash)

    const { logs } = contractReceipt
    const deployLog = logs[logs.length - 1]
    const { topics } = deployLog
    const deployAddress = topics[1]
    const [formattedDeployAddress] = ethers.utils.defaultAbiCoder.decode(["address"], deployAddress)

    console.log("Locker address", formattedDeployAddress)

    // const nftApproval = await nftManagerContract.approve(formattedDeployAddress, nftId)
    const nftApproval = await nftManagerContract.transferFrom(
        signer.address,
        formattedDeployAddress,
        nftId
    )
    const nftApprovalReceipt = await nftApproval.wait()

    console.log("NFT approved", nftApprovalReceipt.transactionHash)

    const lockerInstance = lockerContract(formattedDeployAddress)

    // const lockerTx = await lockerInstance.initializer(nftId)
    // const lockerReceipt = await lockerTx.wait()

    // console.log("Locker initialized", lockerReceipt.transactionHash)
}

async function canRelease() {
    const lockerInstance = lockerContract("0x3319302fA48Dc721c1697f596fc0C3E06DA9B45D")
    const canRelease = await lockerInstance.vestingSchedule()
    console.log("Can release", canRelease.toString())
}

async function contractDetails() {
    const lockerInstance = lockerContract("0x3319302fA48Dc721c1697f596fc0C3E06DA9B45D")

    // const initFlag = await lockerInstance.flag()
    // console.log("Details", initFlag)

    const owner = await lockerInstance.owner()
    console.log("Owner", owner)
}

async function initializer() {
    const lockerInstance = lockerContract("0x3319302fA48Dc721c1697f596fc0C3E06DA9B45D")
    const canRelease = await lockerInstance.initializer(nftId)
    console.log("Can release", canRelease)
}

async function release() {
    const lockerInstance = lockerContract("0x3319302fA48Dc721c1697f596fc0C3E06DA9B45D")

    const canRelease = await lockerInstance.vestingSchedule()
    console.log("Can release", canRelease.toString())

    // const collectFees = await lockerInstance.collectFees(signer.address, nftId)
    // const collectFeesReceipt = await collectFees.wait()

    // console.log("Fees collected", collectFeesReceipt.transactionHash)

    const releaseTx = await lockerInstance.release()
    const releaseReceipt = await releaseTx.wait()

    console.log("Released", releaseReceipt.transactionHash)
}

main()
// initializer()
// canRelease()
// release()
// contractDetails()
