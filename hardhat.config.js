require("@nomicfoundation/hardhat-chai-matchers")
require("@nomiclabs/hardhat-ethers")
require("@typechain/hardhat")
require("hardhat-gas-reporter")
require("solidity-coverage")
require("@nomicfoundation/hardhat-verify")
require("./tasks")
require("dotenv").config()

const COMPILER_SETTINGS = {
    optimizer: {
        enabled: true,
        runs: 200,
    },
    viaIR: true,
    metadata: {
        bytecodeHash: "none",
    },
}

const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || process.env.ALCHEMY_MAINNET_RPC_URL

const PRIVATE_KEY = process.env.PRIVATE_KEY
// optional
const FORKING_BLOCK_NUMBER = parseInt(process.env.FORKING_BLOCK_NUMBER) || 0

// Your API key for Etherscan, obtain one at https://etherscan.io/
const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || "Your etherscan API key"
const REPORT_GAS = process.env.REPORT_GAS || false

const BASE = "https://1rpc.io/base"
const BASE_SEPOLIA_ETH_BROWSER = "https://sepolia.basescan.org/"
const BASE_SEPOLIA_ETH = "https://base-sepolia.blockpi.network/v1/rpc/public"
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.25",
        ...COMPILER_SETTINGS,
        // compilers: [
        //     {
        //         version: "0.8.25",
        //         COMPILER_SETTINGS,
        //     },
        // ],
    },
    allowUnlimitedContractSize: true,
    networks: {
        localhost: {
            chainId: 31337,
        },
        baseSepolia: {
            url: BASE_SEPOLIA_ETH,
            accounts: [PRIVATE_KEY],
            chainId: 84532,
            gasPrice: 1000000000,
        },
        base: {
            url: BASE,
            accounts: [PRIVATE_KEY],
            chainId: 8453,
        },
        degen: {
            url: "https://rpc.degen.tips",
            accounts: [PRIVATE_KEY],
            chainId: 666666666,
        },
    },
    defaultNetwork: "hardhat",
    etherscan: {
        apiKey: {
            base: BASESCAN_API_KEY,
            baseSepolia: BASESCAN_API_KEY,
            degen: "random",
        },
        sourcify: {
            enabled: true,
        },
        customChains: [
            {
                network: "baseSepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api/",
                    browserURL: BASE_SEPOLIA_ETH_BROWSER,
                },
            },
            {
                network: "degen",
                chainId: 666666666,
                urls: {
                    apiURL: "https://explorer.degen.tips/api/",
                    browserURL: "https://explorer.degen.tips/",
                },
            },
        ],
    },
    gasReporter: {
        enabled: REPORT_GAS,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./build/cache",
        artifacts: "./build/artifacts",
    },
    mocha: {
        timeout: 300000, // 300 seconds max for running tests
    },
}

// forge verify-contract --chain-id 666666666 --watch --etherscan-api-key DYJWHWVGMAUW3GAB1EDST9EQKTRVCRXXC9 --compiler-version v0.8.25 0x3CF367cD41eb3AB372bd8000D364729Ec9E67F87 contracts/lp-locker/LpLocker.sol:LpLocker --constructor-args 0x56c65e35f2dd06f659bcfe327c4d7f21c9b69c2f 0x122a73fb6ad4398e93a16dd15bb37843ee26d5a9 1718202470 0 0x122a73fb6ad4398e93a16dd15bb37843ee26d5a9

// address token,
//         address beneficiary,
//         uint64 durationSeconds,
//         uint256 fee,
//         address feeRecipient
