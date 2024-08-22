// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import {INonfungiblePositionManager, IUniswapV3Factory, ILockerFactory, ILocker} from "../interface.sol";
import {Bytes32AddressLib} from "../Bytes32AddressLib.sol";

contract Token is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, maxSupply_);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}

contract SocialDexDeployer is Ownable {
    using TickMath for int24;
    using Bytes32AddressLib for bytes32;

    address public taxCollector;
    uint64 public defaultLockingPeriod = 33275115461;
    uint8 public taxRate = 25; // 25 / 1000 -> 2.5 %
    uint8 public lpFeesCut = 50; // 3 / 100 -> 3%
    ILockerFactory public liquidityLocker;

    address public weth;
    IUniswapV3Factory public uniswapV3Factory;
    INonfungiblePositionManager public positionManager;
    ISwapRouter public immutable swapRouter;

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
        uint64 defaultLockingPeriod_,
        address swapRouter_
    ) Ownable(msg.sender) {
        taxCollector = taxCollector_;
        weth = weth_;
        liquidityLocker = ILockerFactory(locker_);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        positionManager = INonfungiblePositionManager(positionManager_);
        defaultLockingPeriod = defaultLockingPeriod_;
        swapRouter = ISwapRouter(swapRouter_);
    }

    function deployToken(
        string calldata _name,
        string calldata _symbol,
        uint256 _supply,
        uint256 _ownerSupply,
        int24 _initialTick,
        uint24 _fee,
        bytes32 _salt,
        address _deployer,
        uint256 _amountOut
    ) external payable returns (Token token, uint256 tokenId) {
        int24 tickSpacing = uniswapV3Factory.feeAmountTickSpacing(_fee);

        require(
            tickSpacing != 0 && _initialTick % tickSpacing == 0,
            "Invalid tick"
        );

        token = new Token{salt: keccak256(abi.encode(msg.sender, _salt))}(
            _name,
            _symbol,
            _supply
        );

        uint256 tax = (_supply * taxRate) / 1000;

        uint256 initialLiquidity = _supply - _ownerSupply - tax;

        require(address(token) < weth, "Invalid salt");
        require(_supply >= initialLiquidity, "Invalid supply amount");

        token.transfer(taxCollector, tax);

        uint160 sqrtPriceX96 = _initialTick.getSqrtRatioAtTick();
        address pool = uniswapV3Factory.createPool(address(token), weth, _fee);
        IUniswapV3Factory(pool).initialize(sqrtPriceX96);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams(
                address(token),
                weth,
                _fee,
                _initialTick,
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

        address lockerAddress = liquidityLocker.deploy(
            address(positionManager),
            _deployer,
            defaultLockingPeriod,
            tokenId,
            lpFeesCut
        );

        positionManager.safeTransferFrom(address(this), lockerAddress, tokenId);

        ILocker(lockerAddress).initializer(tokenId);

        if (msg.value > 0) {
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: weth, // The token we are exchanging from (ETH wrapped as WETH)
                    tokenOut: address(token), // The token we are exchanging to
                    fee: 0, // The pool fee
                    recipient: msg.sender, // The recipient address
                    deadline: block.timestamp, // The deadline for the swap
                    amountIn: msg.value, // The amount of ETH (WETH) to be swapped
                    amountOutMinimum: _amountOut, // Minimum amount of DAI to receive
                    sqrtPriceLimitX96: 0 // No price limit
                });

            // The call to `exactInputSingle` executes the swap.
            swapRouter.exactInputSingle{value: msg.value}(swapParams);
        }

        emit TokenCreated(
            address(token),
            tokenId,
            msg.sender,
            _name,
            _symbol,
            _supply,
            initialLiquidity,
            lockerAddress
        );
    }

    function predictToken(
        address deployer,
        string calldata name,
        string calldata symbol,
        uint256 supply,
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

    function updateProtocolFees(uint8 newFee) external onlyOwner {
        lpFeesCut = newFee;
    }

    function updateTaxRate(uint8 newRate) external onlyOwner {
        taxRate = newRate;
    }
}

/// @notice Given a tickSpacing, compute the maximum usable tick
function maxUsableTick(int24 tickSpacing) pure returns (int24) {
    unchecked {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }
}
