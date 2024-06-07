const BigNumber = require("bignumber.js")

// Constants for full range ticks in Uniswap V3
const MIN_TICK = -887272
const MAX_TICK = 887272

// Function to get tick spacing based on fee tier
function getTickSpacing(feeTier) {
    const tickSpacingMap = {
        500: 10, // 0.05% fee tier
        3000: 60, // 0.3% fee tier
        10000: 200, // 1% fee tier
    }
    return tickSpacingMap[feeTier]
}

// Function to calculate initial square root price in Q64.96 format and tick values for a new Uniswap V3 pool
function calculateUniswapV3Params(token0Price, token1Price, feeTier) {
    // Calculate the price ratio (P = token0Price / token1Price)
    const priceRatio = new BigNumber(token0Price).div(token1Price)

    // Calculate the square root of the price ratio
    const sqrtPrice = priceRatio.sqrt()

    // Convert the square root price to Q64.96 format
    const Q96 = new BigNumber(2).pow(96)
    const sqrtPriceX96 = sqrtPrice.multipliedBy(Q96)

    // Calculate the initial tick from the price ratio
    const initialTick = Math.log(priceRatio.toNumber()) / Math.log(1.0001)

    // Get tick spacing based on fee tier
    const tickSpacing = getTickSpacing(feeTier)

    // Determine tickLower and tickUpper based on initial tick and tickSpacing
    const tickLower = Math.floor(initialTick / tickSpacing) * tickSpacing
    const tickUpper = Math.ceil(initialTick / tickSpacing) * tickSpacing

    // Clamp the tick values within the allowed range
    const clampedTickLower = Math.max(tickLower, MIN_TICK)
    const clampedTickUpper = Math.min(tickUpper, MAX_TICK)

    return {
        sqrtPriceX96: sqrtPriceX96.toFixed(0), // Return as string to handle large numbers
        tickLower: clampedTickLower,
        tickUpper: clampedTickUpper,
    }
}

// Example usage:
const token0Price = 1 // Price of TOKEN in terms of DEGEN
const token1Price = 10000 // Price of DEGEN in terms of TOKEN
const feeTier = 3000 // 0.3% fee tier

const { sqrtPriceX96, tickLower, tickUpper } = calculateUniswapV3Params(
    token0Price,
    token1Price,
    feeTier
)

console.log("Initial sqrtPriceX96:", sqrtPriceX96)
console.log("Tick Lower:", tickLower)
console.log("Tick Upper:", tickUpper)
