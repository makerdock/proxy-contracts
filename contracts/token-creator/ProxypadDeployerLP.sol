// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
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

interface IUniswapV3Factory {
    function initialize(uint160 sqrtPriceX96) external;

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
}

contract Token is ERC20 {
    bytes32 private rootHash;

    mapping(address => bool) public isClaimed;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply
    )
        // bytes32 _rootHash
        ERC20(_name, _symbol)
    {
        _mint(msg.sender, _maxSupply); // Mint to msg.sender (TokenDeployer)
        // rootHash = _rootHash;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function claimTokens(
        uint256 _claimAmount,
        bytes32[] calldata proof
    ) public {
        if (isClaimed[msg.sender] == true) {
            revert("User already claimed tokens");
        }

        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, _claimAmount)))
        );
        require(MerkleProof.verify(proof, rootHash, leaf), "Invalid proof");
        IERC20(address(this)).transfer(msg.sender, _claimAmount);
    }
}

contract ProxypadDeployerLP is Ownable(msg.sender) {
    using TickMath for *;
    using Bytes32AddressLib for *;

    uint256 internal constant OWNER_SUPPLY_DENOM = 20; // 1/20 = 5%
    uint256 internal constant Q96 = 1 << 96;

    // wDEGEN: 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387
    // wETH:   0x4200000000000000000000000000000000000006
    address public WETH = 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387;
    address public liquidityLocker;

    // degen: 0x652e3Dc407e951BD0aFcB0697B911e81F0dDC876
    // base:  0x33128a8fC17869897dcE68Ed026d694621f6FDfD
    IUniswapV3Factory public uniswapV3Factory =
        IUniswapV3Factory(0x652e3Dc407e951BD0aFcB0697B911e81F0dDC876);

    // degen: 0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f
    // base:  0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
    INonfungiblePositionManager public positionManager =
        INonfungiblePositionManager(0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f);

    Deployment[] internal deployments;
    mapping(Token token => uint256) public tokenIdOf;

    struct Deployment {
        Token token;
        uint256 tokenId; // ID of the Uniswap v3 position
    }

    event TokenCreated(address tokenAddress, uint256 tokenId, address deployer);

    constructor(address locker_) {
        liquidityLocker = locker_;
    }

    function deployToken(
        string calldata name,
        string calldata symbol,
        uint256 supply,
        address supplyOwner,
        uint256 initialLiquidity,
        // uint256 distribution,
        int24 initialTick,
        uint24 fee,
        bytes32 salt
    )
        external
        returns (
            // bytes32 rootHash
            Token token,
            uint256 tokenId
        )
    {
        // validate initialTick
        int24 tickSpacing = uniswapV3Factory.feeAmountTickSpacing(fee);
        require(tickSpacing != 0 && initialTick % tickSpacing == 0, "TICK");

        // deploy token
        // force token to be token0 of the Uniswap pool to simplify logic
        // frontend will need to ensure the salt is unique and results in token address < WETH
        token = new Token{salt: keccak256(abi.encode(msg.sender, salt))}(
            name,
            symbol,
            supply
        );
        require(address(token) < WETH, "SALT");

        // require(supply >= distribution + initialLiquidity, "MAX_SUPPLY");

        // transfer ownerSupply to supplyOwner
        uint256 ownerSupply = supply - initialLiquidity;
        token.transfer(supplyOwner, ownerSupply);

        // if (distribution > 0) {
        //     token.transfer(address(token), distribution);
        // }

        // create Uniswap v3 pool for token/WETH pair
        {
            uint160 sqrtPriceX96 = initialTick.getSqrtRatioAtTick();
            address pool = uniswapV3Factory.createPool(
                address(token),
                WETH,
                fee
            );
            IUniswapV3Factory(pool).initialize(sqrtPriceX96);
        }

        // use remaining tokens to mint liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(token),
                WETH,
                fee,
                initialTick,
                maxUsableTick(tickSpacing),
                initialLiquidity,
                0,
                0,
                0,
                address(this),
                block.timestamp
            );
        token.approve(address(positionManager), initialLiquidity);
        (tokenId, , , ) = positionManager.mint(params);

        // safe transfer position NFT to locker
        positionManager.safeTransferFrom(
            address(this),
            address(liquidityLocker),
            tokenId,
            abi.encode(supplyOwner)
        );

        deployments.push(Deployment({token: token, tokenId: tokenId}));
        tokenIdOf[token] = tokenId;

        emit TokenCreated(address(token), tokenId, msg.sender);
    }

    function predictToken(
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
            token = predictToken(deployer, name, symbol, supply, salt);
            if (token < WETH && token.code.length == 0) {
                break;
            }
        }
    }

    function updateLiquidityLocker(address locker_) external onlyOwner {
        liquidityLocker = locker_;
    }
}

/// @notice Given a tickSpacing, compute the maximum usable tick
function maxUsableTick(int24 tickSpacing) pure returns (int24) {
    unchecked {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}
