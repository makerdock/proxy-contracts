// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

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
    using SafeERC20 for IERC20;
    using Bytes32AddressLib for *;
    using TickMath for *;

    INonfungiblePositionManager public immutable nonfungiblePositionManager =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    address public immutable weth = 0x4200000000000000000000000000000000000006;
    uint256 internal nonce = 0;

    // Deployment event
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
        uint24 _fee,
        int24 tickLower,
        int24 tickUpper,
        address owner
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

        (int24 lowerTick, int24 upperTick) = tokenIsLessThanWeth
            ? (tickLower, tickUpper)
            : (tickUpper, tickLower);

        (uint256 amt0, uint256 amt1) = tokenIsLessThanWeth
            ? (_liquidity, _backingLiquidity)
            : (_backingLiquidity, _liquidity);

        params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: _fee,
            tickLower: lowerTick,
            tickUpper: upperTick,
            amount0Desired: amt0,
            amount0Min: amt0 - ((amt0 * 5) / 1000),
            amount1Desired: amt1,
            amount1Min: amt1 - ((amt1 * 5) / 1000),
            recipient: owner,
            deadline: block.timestamp
        });

        initialSqrtPrice = tokenIsLessThanWeth
            ? 1252685732681638336686364
            : 5010664478791732988152496286088527;
    }

    function deploy(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _liquidity,
        uint256 _backingLiquidity,
        uint24 fee,
        int24 initialSqrtPrice,
        bytes32 salt,
        address owner
    ) external payable returns (address, uint256) {
        Token t = new Token{
            salt: keccak256(abi.encodePacked(msg.sender, salt))
        }(_name, _symbol, _maxSupply);

        address token = address(t);

        t.approve(address(nonfungiblePositionManager), _liquidity);
        IERC20(weth).approve(
            address(nonfungiblePositionManager),
            _backingLiquidity
        );

        // (
        //     INonfungiblePositionManager.MintParams memory mintParams,
        //     uint160 initialSqrtPrice
        // ) = _getMintParams({
        //         token: token,
        //         _liquidity: _liquidity,
        //         _backingLiquidity: _backingLiquidity,
        //         _fee: fee,
        //         tickUpper: upperTick,
        //         tickLower: lowerTick,
        //         owner: owner
        //     });

        nonfungiblePositionManager.createAndInitializePoolIfNecessary({
            token0: token,
            token1: weth,
            fee: fee,
            sqrtPriceX96: initialSqrtPrice.getSqrtRatioAtTick()
        });

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                token,
                weth,
                fee,
                initialSqrtPrice,
                maxUsableTick(initialSqrtPrice),
                _liquidity,
                _liquidity - ((_liquidity * 5) / 1000),
                _backingLiquidity,
                _backingLiquidity - ((_backingLiquidity * 5) / 1000),
                owner,
                block.timestamp
            );

        (uint256 lpTokenId, , , ) = nonfungiblePositionManager.mint(params);

        nonce += 1;

        // emit NewToken(address(t), msg.sender, _name, _symbol, _maxSupply);

        return (token, lpTokenId);
    }

    function predictBasecamp(
        address deployer,
        string calldata name,
        string calldata symbol,
        uint256 supply,
        bytes32 salt
    ) public view returns (address result) {
        bytes32 create2Salt = keccak256(abi.encode(deployer, salt));
        result = keccak256(
            abi.encodePacked(
                bytes1(0xFF),
                address(this),
                create2Salt,
                keccak256(
                    bytes.concat(
                        type(Token).creationCode,
                        abi.encode(name, symbol, supply)
                    )
                )
            )
        ).fromLast20Bytes();
    }

    function generateSalt(
        address deployer,
        string calldata name,
        string calldata symbol,
        uint256 supply
    ) external view returns (bytes32 salt, address token) {
        for (uint256 i; ; i++) {
            salt = bytes32(i);
            token = predictBasecamp(deployer, name, symbol, supply, salt);
            if (token < weth && token.code.length == 0) {
                break;
            }
        }
    }

    function maxUsableTick(int24 tickSpacing) public pure returns (int24) {
        unchecked {
            return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        }
    }
}
