// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {INonfungiblePositionManager, IUniswapV3Factory, ILockerFactory} from "./interface.sol";

contract Token is ERC20 {
    bytes32 private rootHash;
    mapping(address => bool) public isClaimed;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        bytes32 rootHash_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, maxSupply_); // Mint to msg.sender (TokenDeployer)
        rootHash = rootHash_;
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
        isClaimed[msg.sender] = true;
        IERC20(address(this)).transfer(msg.sender, _claimAmount);
    }
}

contract ProxypadDeployer is Ownable {
    using TickMath for int24;
    using Bytes32AddressLib for bytes32;

    uint256 internal constant OWNER_SUPPLY_DENOM = 20;
    uint256 internal constant Q96 = 1 << 96;

    address public taxCollector;
    uint8 public taxRate = 25; // 25 / 1000 -> 2.5 %
    uint64 public defaultLockingPeriod = 33275115461;
    ILockerFactory public liquidityLocker;

    // wDEGEN: 0xEb54dACB4C2ccb64F8074eceEa33b5eBb38E5387
    // wETH:   0x4200000000000000000000000000000000000006
    address public weth;

    // degen: 0x652e3Dc407e951BD0aFcB0697B911e81F0dDC876
    // base:  0x33128a8fC17869897dcE68Ed026d694621f6FDfD
    IUniswapV3Factory public uniswapV3Factory;

    // degen: 0x56c65e35f2Dd06f659BCFe327C4D7F21c9b69C2f
    // base:  0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
    INonfungiblePositionManager public positionManager;

    event TokenCreated(
        address tokenAddress,
        uint256 lpNftId,
        address deployer,
        string name,
        string symbol,
        uint256 supply,
        uint256 initialLiquidity,
        address lockerAddress
    );

    constructor(
        address taxCollector_,
        address weth_,
        address locker_,
        address uniswapV3Factory_,
        address positionManager_,
        uint64 defaultLockingPeriod_
    ) Ownable(msg.sender) {
        taxCollector = taxCollector_;
        weth = weth_;
        liquidityLocker = ILockerFactory(locker_);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        positionManager = INonfungiblePositionManager(positionManager_);
        defaultLockingPeriod = defaultLockingPeriod_;
    }

    function deployToken(
        string calldata name,
        string calldata symbol,
        uint256 supply,
        address supplyOwner,
        uint256 initialLiquidity,
        int24 initialTick,
        uint24 fee,
        bytes32 salt,
        uint256 distribution,
        bytes32 rootHash
    ) external returns (Token token, uint256 tokenId) {
        int24 tickSpacing = uniswapV3Factory.feeAmountTickSpacing(fee);
        require(
            tickSpacing != 0 && initialTick % tickSpacing == 0,
            "Invalid tick"
        );

        token = new Token{salt: keccak256(abi.encode(msg.sender, salt))}(
            name,
            symbol,
            supply,
            rootHash
        );
        require(address(token) < weth, "Invalid salt");

        require(
            supply >= initialLiquidity + distribution,
            "Invalid supply amount"
        );

        uint256 tax = (supply * taxRate) / 1000;

        uint256 ownerSupply = supply - tax - distribution - initialLiquidity;

        token.transfer(taxCollector, tax);

        if (distribution > 0) {
            token.transfer(address(token), distribution);
        }

        token.transfer(supplyOwner, ownerSupply);

        uint160 sqrtPriceX96 = initialTick.getSqrtRatioAtTick();
        address pool = uniswapV3Factory.createPool(address(token), weth, fee);
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(token),
                weth,
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

        positionManager.safeTransferFrom(
            address(this),
            address(liquidityLocker),
            tokenId,
            abi.encode(supplyOwner)
        );

        address lockerAddress = liquidityLocker.deploy(
            address(token),
            supplyOwner,
            defaultLockingPeriod,
            tokenId,
            3
        );

        emit TokenCreated(
            address(token),
            tokenId,
            msg.sender,
            name,
            symbol,
            supply,
            initialLiquidity,
            lockerAddress
        );
    }

    function predictToken(
        address deployer,
        string calldata name,
        string calldata symbol,
        uint256 supply,
        bytes32 rootHash,
        bytes32 salt
    ) public view returns (address) {
        bytes32 create2Salt = keccak256(abi.encode(deployer, salt));
        return
            keccak256(
                abi.encodePacked(
                    bytes1(0xFF),
                    address(this),
                    create2Salt,
                    keccak256(
                        abi.encodePacked(
                            type(Token).creationCode,
                            abi.encode(name, symbol, supply, rootHash)
                        )
                    )
                )
            ).fromLast20Bytes();
    }

    function generateSalt(
        address deployer,
        string calldata name,
        string calldata symbol,
        uint256 supply,
        bytes32 rootHash
    ) external view returns (bytes32 salt, address token) {
        for (uint256 i; ; i++) {
            salt = bytes32(i);
            token = predictToken(
                deployer,
                name,
                symbol,
                supply,
                rootHash,
                salt
            );
            if (token < weth && token.code.length == 0) {
                break;
            }
        }
    }

    function updateTaxCollector(address newCollector) external onlyOwner {
        taxCollector = newCollector;
    }

    function updateLiquidityLocker(address newLocker) external onlyOwner {
        liquidityLocker = ILockerFactory(newLocker);
    }

    function updateDefaultLockingPeriod(uint64 newPeriod) external onlyOwner {
        defaultLockingPeriod = newPeriod;
    }
}

/// @notice Given a tickSpacing, compute the maximum usable tick
function maxUsableTick(int24 tickSpacing) pure returns (int24) {
    unchecked {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}
