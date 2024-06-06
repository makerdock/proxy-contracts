// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface INonfungiblePositionManager is IERC721 {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function mint(
        MintParams calldata params
    )
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);
}

contract Token is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _maxSupply); // Mint to msg.sender (TokenDeployer)
    }
}

contract ProxypadDeployerLP {
    // 2.5% tax
    INonfungiblePositionManager nonfungiblePositionManager =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    address internal weth = 0x4200000000000000000000000000000000000006;
    uint24 internal POOL_FEE = 10000;
    uint256 nonce = 0;

    // Deployment
    event NewToken(
        address indexed token,
        address indexed creator,
        string tokenName,
        string tokenSymbol,
        uint256 maxSupply
    );

    function _getMintParams(
        address token,
        uint256 _liquidity,
        uint256 _backingLiquidity,
        address _owner
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
            ? (int24(-220400), int24(0))
            : (int24(0), int24(220400));
        (uint256 amt0, uint256 amt1) = tokenIsLessThanWeth
            ? (_liquidity, _backingLiquidity)
            : (_backingLiquidity, _liquidity);

        params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            // 1% fee
            fee: POOL_FEE,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amt0,
            // allow for a bit of slippage
            amount0Min: amt0 - ((amt0 * 5) / 100),
            amount1Desired: amt1,
            amount1Min: amt1 - ((amt1 * 5) / 100),
            deadline: block.timestamp,
            recipient: _owner
        });

        initialSqrtPrice = tokenIsLessThanWeth
            ? 1252685732681638336686364
            : 5010664478791732988152496286088527;

        //  tokenIsLessThanWeth ? 2374716772012394972971008 : 2643305428826910585518143993544704;
    }

    function deploy(
        string memory _name, // Token name
        string memory _symbol, // Token symbol
        uint256 _maxSupply, // Max supply of Token (50% will be locked for liquidity)
        uint256 _liquidity, // Amount of liquidity to add
        uint256 _backingLiquidity, // Amount of backing liquidity to add
        address owner
    ) external payable returns (address, uint256) {
        uint256 taxAmount = (_maxSupply * 25) / 1000;

        // 1. Create Token, approve to router
        Token t = new Token(_name, _symbol, _maxSupply);

        address token = address(t);

        (address token0, address token1) = token < weth
            ? (token, weth)
            : (weth, token);

        t.approve(address(nonfungiblePositionManager), _liquidity);
        IERC20(weth).approve(
            address(nonfungiblePositionManager),
            _backingLiquidity
        );

        (
            INonfungiblePositionManager.MintParams memory mintParams,
            uint160 initialSquareRootPrice
        ) = _getMintParams({
                token: token,
                _liquidity: _liquidity,
                _backingLiquidity: _backingLiquidity,
                _owner: owner
            });

        nonfungiblePositionManager.createAndInitializePoolIfNecessary({
            token0: token0,
            token1: token1,
            fee: POOL_FEE,
            sqrtPriceX96: initialSquareRootPrice
        });

        (uint256 lpTokenId, , , ) = nonfungiblePositionManager.mint({
            params: mintParams
        });

        // 3. Deployer keeps the rest
        uint256 deployerAmount = _maxSupply - taxAmount;

        if (deployerAmount > 0) {
            t.transfer(msg.sender, deployerAmount);
        }

        // emit NewToken(address(t), msg.sender, _name, _symbol, _maxSupply);

        return (token, lpTokenId);
    }

    function updateNFTManager(address _newNFTManager) external {
        nonfungiblePositionManager = INonfungiblePositionManager(
            _newNFTManager
        );
    }
}
