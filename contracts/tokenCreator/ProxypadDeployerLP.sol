// SPDX-License-Identifier: MIT
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

interface IUniswapV3Pool {
    function initialize(uint160 sqrtPriceX96) external;

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
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
    IUniswapV3Pool public immutable uniswapV3Factory =
        IUniswapV3Pool(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    address public immutable weth = 0x4200000000000000000000000000000000000006;

    // Deployment event
    event NewToken(
        address indexed token,
        address indexed creator,
        string tokenName,
        string tokenSymbol,
        uint256 maxSupply
    );

    function deploy(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _liquidity,
        uint24 _fee,
        int24 _initialSqrtPrice,
        bytes32 _salt,
        address _owner
    ) external payable returns (address, uint256) {
        // validate initialTick
        int24 tickSpacing = uniswapV3Factory.feeAmountTickSpacing(_fee);
        require(
            tickSpacing != 0 && _initialSqrtPrice % tickSpacing == 0,
            "TICK"
        );

        // deploy token
        // force token to be token0 of the Uniswap pool to simplify logic
        // frontend will need to ensure the salt is unique and results in token address < WETH
        Token token = new Token{salt: keccak256(abi.encode(msg.sender, _salt))}(
            _name,
            _symbol,
            _maxSupply
        );

        require(address(token) < weth, "SALT");

        // transfer ownerSupply to supplyOwner
        uint256 ownerSupply = _maxSupply - _liquidity;
        token.transfer(_owner, ownerSupply);

        // create Uniswap v3 pool for token/WETH pair
        {
            uint160 sqrtPriceX96 = _initialSqrtPrice.getSqrtRatioAtTick();
            address pool = uniswapV3Factory.createPool(
                address(token),
                weth,
                _fee
            );
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        }

        // use remaining tokens to mint liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(token),
                weth,
                _fee,
                _initialSqrtPrice,
                maxUsableTick(tickSpacing),
                _liquidity,
                0,
                0,
                0,
                _owner,
                block.timestamp
            );
        token.approve(address(nonfungiblePositionManager), _liquidity);
        (uint256 lpTokenId, , , ) = nonfungiblePositionManager.mint(params);

        // emit NewToken(address(token), msg.sender, _name, _symbol, _maxSupply);

        return (address(token), lpTokenId);
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
