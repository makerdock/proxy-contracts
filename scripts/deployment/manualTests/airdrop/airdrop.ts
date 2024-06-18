import ethers from "ethers"
import abi from "./abi.json"
import claimAbi from "./claimABI.json"
import { StandardMerkleTree } from "@openzeppelin/merkle-tree"

const privateKey = process.env.PRIVATE_KEY

if (!privateKey) {
    throw new Error("PRIVATE_KEY is not set")
}

const provider = new ethers.providers.JsonRpcProvider("https://rpc.degen.tips")
const wallet = new ethers.Wallet(privateKey, provider)
const signer = wallet.connect(provider)

const erc20ABI = [
    {
        constant: false,
        inputs: [
            {
                name: "_spender",
                type: "address",
            },
            {
                name: "_value",
                type: "uint256",
            },
        ],
        name: "approve",
        outputs: [
            {
                name: "",
                type: "bool",
            },
        ],
        payable: false,
        stateMutability: "nonpayable",
        type: "function",
    },
]

const airdropTokenAddress = "0xde0f23f3475e0227d68e3e4caed1c409b652b443"
const airdropContractAddress = "0xf627e018e01b706f4a6a060c56c358eea82b7214"

const contract = new ethers.Contract(airdropContractAddress, abi, signer)
const erc20Contract = new ethers.Contract(airdropTokenAddress, erc20ABI, signer)
const claimAirdropContract = (claimAddress) => new ethers.Contract(claimAddress, claimAbi, signer)

const createMerkleTrees = (data) => {
    const tree = StandardMerkleTree.of(data, ["address", "uint256"])

    generateAllProofs(data)

    return tree.root
}

// @deeksha: use this to generate all the proofs when adding proofs to the users table
const generateAllProofs = (data) => {
    const tree = StandardMerkleTree.of(data, ["address", "uint256"])

    const proofUserMapping = {}

    for (const [i, v] of tree.entries()) {
        const [address] = v

        const proof = tree.getProof(i)

        proofUserMapping[address] = proof
    }

    return proofUserMapping
}

const addresses = [
    [signer.address, 10000000000000000000n],
    ["0xB1C2eCe930c84709Fb484D19d81381637a848d94", 10000000000000000000n],
]

const merkleRoot = createMerkleTrees(addresses)

const proofs = generateAllProofs(addresses)

async function main() {
    const tx = await erc20Contract.approve(airdropContractAddress, 100000000000000000000n)
    const { transactionHash } = await tx.wait()

    console.log("Approved ERC20 tokens", transactionHash)

    console.log("Merkle Root", merkleRoot)

    const contractTx = await contract.deployAirdrop(
        airdropTokenAddress,
        merkleRoot,
        20000000000000000000n
    )

    const transaction = await contractTx.wait()

    console.log("Airdrop contract deployed", transaction.transactionHash)

    const { logs } = transaction
    const tokenAirdropLog = logs[logs.length - 1]
    const { topics } = tokenAirdropLog
    const addressWithZeros = topics[topics.length - 1]
    const [airdropAddress] = ethers.utils.defaultAbiCoder.decode(["address"], addressWithZeros)

    console.log("airdropAddress", airdropAddress)

    const claimingContract = claimAirdropContract(airdropAddress)

    const merkleHash = await claimingContract.rootHash()
    const claimingToken = await claimingContract.token()

    console.log("Merkle Hash", merkleHash)
    console.log("Claiming Token", claimingToken)
    console.log("Proof", proofs[signer.address], proofs)

    const claimTx = await claimAirdropContract(airdropAddress).claimTokens(
        10000000000000000000n,
        proofs[signer.address]
    )

    const claimTransaction = await claimTx.wait()

    console.log("Claimed airdrop", claimTransaction.transactionHash)
}

main()
