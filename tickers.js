const { TickMath } = require("@uniswap/v3-sdk")
const { BigNumber } = require("ethers")
const bn = require("bignumber.js")
const JSBI = require("jsbi")

const token0 = BigNumber.from("6000000000000000000") // Example token0 value (1 ETH in wei)
const token1 = BigNumber.from("1000000000000000000000") // Example token1 value (0.5 ETH in wei)
const sqrtP = new bn(token0.toString()).div(token1.toString()).sqrt()

const Q96 = new bn(2).pow(96)

const P = sqrtP.multipliedBy(Q96).toFixed(0)

console.log({ P })

const result = TickMath.getTickAtSqrtRatio(JSBI.BigInt(P))

let adjustment = 200 * Math.floor(result / 200)

console.log({ result, adjustment })
