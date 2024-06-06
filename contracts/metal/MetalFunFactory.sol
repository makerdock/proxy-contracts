// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {POOL_FEE} from "./Constants.sol";
import {InstantLiquidityToken} from "./InstantLiquidityToken.sol";
import {INonfungiblePositionManager} from "./TokenFactory.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MetalFunFactory is Ownable, ERC721Holder {
    uint256 immutable TOTAL_SUPPLY = 923_500_000 ether;

    error UNSUPPORTED_CHAIN();

    event TokenFactoryDeployment(
        address indexed token,
        uint256 indexed tokenId,
        address indexed recipient,
        string name,
        string symbol
    );

    struct Storage {
        // a nonce to ensure unique token ids for each deployment
        uint96 deploymentNonce;
        // the instant liquidity token contract
        InstantLiquidityToken instantLiquidityToken;
    }

    Storage public s =
        Storage({
            deploymentNonce: 0,
            instantLiquidityToken: InstantLiquidityToken(
                0xD74D14ebe305c93D023C966640788f05593F0fdE
            )
        });

    constructor() Ownable(msg.sender) {
        uint256 chainId = block.chainid;

        if (
            // mainnet
            chainId != 1 &&
            // goerli
            chainId != 5 &&
            // arbitrum
            chainId != 42161 &&
            // optimism
            chainId != 10 &&
            // polygon
            chainId != 137 &&
            // bnb
            chainId != 56 &&
            // base
            chainId != 8453 &&
            // base sepolia
            chainId != 84532 &&
            // sepolia
            chainId != 11155111 &&
            // zora
            chainId != 7777777 &&
            // degen chain
            chainId != 666666666
        ) revert UNSUPPORTED_CHAIN();
    }

    /**
     * @dev sourced from: https://docs.uniswap.org/contracts/v3/reference/deployments
     */
    function _getAddresses()
        internal
        view
        returns (
            address weth,
            INonfungiblePositionManager nonFungiblePositionManager
        )
    {
        uint256 chainId = block.chainid;
        // Mainnet, Goerli, Arbitrum, Optimism, Polygon
        nonFungiblePositionManager = INonfungiblePositionManager(
            0xC36442b4a4522E871399CD717aBDD847Ab11FE88
        );

        // mainnet
        if (chainId == 1) weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        // goerli
        if (chainId == 5) weth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
        // arbitrum
        if (chainId == 42161) weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        // optimism
        if (chainId == 10) weth = 0x4200000000000000000000000000000000000006;
        // polygon
        if (chainId == 137) weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        // bnb
        if (chainId == 56) {
            weth = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613
            );
        }
        // base
        if (chainId == 8453) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
            );
        }
        // base sepolia
        if (chainId == 84532) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0x27F971cb582BF9E50F397e4d29a5C7A34f11faA2
            );
        }
        // sepolia
        if (chainId == 11155111) {
            weth = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0x1238536071E1c677A632429e3655c799b22cDA52
            );
        }
        // zora
        if (chainId == 7777777) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0xbC91e8DfA3fF18De43853372A3d7dfe585137D78
            );
        }
        // degen chain
        if (chainId == 666666666) {
            // wrapped degen
            weth = 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387;
            nonFungiblePositionManager = INonfungiblePositionManager( // proxy swap
                0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f
            );
        }
    }

    function _getMintParams(
        address token,
        address weth
    )
        internal
        view
        returns (
            INonfungiblePositionManager.MintParams memory params,
            uint160 initialSqrtPrice
        )
    {
        bool tokenIsLessThanWeth = token < weth;
        (address token0, address token1) = tokenIsLessThanWeth
            ? (token, weth)
            : (weth, token);
        (int24 tickLower, int24 tickUpper) = tokenIsLessThanWeth
            ? (int24(-208400), int24(0))
            : (int24(0), int24(208400));
        (uint256 amt0, uint256 amt1) = tokenIsLessThanWeth
            ? (uint256(TOTAL_SUPPLY), uint256(0))
            : (uint256(0), uint256(TOTAL_SUPPLY));

        params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            // 1% fee
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amt0,
            // allow for a bit of slippage
            amount0Min: amt0 - (amt0 / 1e8),
            amount1Desired: amt1,
            amount1Min: amt1 - (amt1 / 1e8),
            deadline: block.timestamp,
            recipient: address(this)
        });

        // ETH price @ $3228
        // wanted token value = $0,0000029
        initialSqrtPrice = tokenIsLessThanWeth
            ? 2363603296768335609331712
            : 2655734041312737263542517807185920;
    }

    function _deploy(
        string memory _name,
        string memory _symbol
    ) internal returns (InstantLiquidityToken, uint256) {
        // get the addresses per-chain
        (
            address weth,
            INonfungiblePositionManager nonfungiblePositionManager
        ) = _getAddresses();
        address token;
        {
            Storage memory store = s;
            // deploy and initialize a new token
            token = Clones.cloneDeterministic(
                address(store.instantLiquidityToken),
                keccak256(abi.encode(block.chainid, store.deploymentNonce))
            );
            IERC20 deployedToken = new InstantLiquidityToken({
                _mintTo: address(this),
                _totalSupply: TOTAL_SUPPLY,
                _name: _name,
                _symbol: _symbol
            });
            token = address(deployedToken);
            s.deploymentNonce += 1;
        }

        // sort the tokens and the amounts
        (address token0, address token1) = token < weth
            ? (token, weth)
            : (weth, token);

        // approve the non-fungible position mgr for the pool liquidity amount
        InstantLiquidityToken(token).approve({
            spender: address(nonfungiblePositionManager),
            value: TOTAL_SUPPLY
        });

        (
            INonfungiblePositionManager.MintParams memory mintParams,
            uint160 initialSquareRootPrice
        ) = _getMintParams({token: token, weth: weth});

        // create the pool
        nonfungiblePositionManager.createAndInitializePoolIfNecessary({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            sqrtPriceX96: initialSquareRootPrice
        });

        // mint the position
        (uint256 lpTokenId, , , ) = nonfungiblePositionManager.mint({
            params: mintParams
        });

        return (InstantLiquidityToken(token), lpTokenId);
    }

    function deploy(
        string memory _name,
        string memory _symbol
    ) public returns (InstantLiquidityToken token, uint256 lpTokenId) {
        (token, lpTokenId) = _deploy(_name, _symbol);

        emit TokenFactoryDeployment(
            address(token),
            lpTokenId,
            msg.sender,
            _name,
            _symbol
        );
    }

    function collectFees(
        address _recipient,
        uint256[] memory _tokenIds
    ) public onlyOwner {
        (
            ,
            INonfungiblePositionManager nonfungiblePositionManager
        ) = _getAddresses();

        for (uint256 i; i < _tokenIds.length; ++i) {
            nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    recipient: _recipient,
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max,
                    tokenId: _tokenIds[i]
                })
            );
        }
    }

    function setInstantLiquidityToken(
        address _instantLiquidityToken
    ) public onlyOwner {
        s.instantLiquidityToken = InstantLiquidityToken(_instantLiquidityToken);
    }
}
