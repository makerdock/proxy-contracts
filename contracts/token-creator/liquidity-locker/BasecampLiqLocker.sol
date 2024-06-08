// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.25;

import {ERC20} from "./ERC20.sol";
import {ERC721TokenReceiver} from "./ERC721TokenReceiver.sol";
import {Owned} from "./Owned.sol";
import {SafeTransferLib} from "./SafeTransferLib.sol";
import {FixedPointMathLib} from "./FixedPointMathLib.sol";

import {LibMulticaller} from "./LibMulticaller.sol";

interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(
        CollectParams calldata params
    ) external returns (uint256 amount0, uint256 amount1);

    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

/// @title LiquidityLocker
/// @notice Locks Uniswap V3 liquidity positions while retaining the right to claim fees
/// @author zefram.eth
contract LiquidityLocker is Owned, ERC721TokenReceiver {
    using SafeTransferLib for *;
    using FixedPointMathLib for *;

    uint256 internal constant WAD = 1e18;

    INonfungiblePositionManager public immutable positionManager =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    uint96 public protocolFeeWad;
    address public protocolFeeRecipient;
    mapping(uint256 id => address) public ownerOf;

    event Lock(uint256 indexed id, address indexed owner);
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );
    event SetProtocolFee(
        uint96 indexed protocolFeeWad_,
        address indexed protocolFeeRecipient_
    );
    event ClaimFees(
        uint256 indexed id,
        address indexed recipient,
        uint256 recipientFee0,
        uint256 recipientFee1,
        uint256 protocolFee0,
        uint256 protocolFee1
    );

    constructor(uint96 protocolFeeWad_) Owned(msg.sender) {
        require(protocolFeeWad_ <= WAD, "FEE");
        protocolFeeWad = protocolFeeWad_;
        protocolFeeRecipient = msg.sender;
        emit SetProtocolFee(protocolFeeWad_, msg.sender);
    }

    function setProtocolFee(
        uint96 protocolFeeWad_,
        address protocolFeeRecipient_
    ) external onlyOwner {
        require(protocolFeeWad_ <= WAD, "FEE");
        protocolFeeWad = protocolFeeWad_;
        protocolFeeRecipient = protocolFeeRecipient_;
        emit SetProtocolFee(protocolFeeWad_, protocolFeeRecipient_);
    }

    function claimFees(
        uint256 id,
        address recipient
    )
        external
        returns (
            uint256 recipientFee0,
            uint256 recipientFee1,
            uint256 protocolFee0,
            uint256 protocolFee1
        )
    {
        // verify sender
        address msgSender = LibMulticaller.senderOrSigner();
        require(ownerOf[id] == msgSender, "AUTH");

        // claim fees
        (uint256 amount0, uint256 amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: id,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // split fees between recipient and protocol
        (uint96 protocolFeeWad_, address protocolFeeRecipient_) = (
            protocolFeeWad,
            protocolFeeRecipient
        );
        (protocolFee0, protocolFee1) = (
            amount0.mulWadUp(protocolFeeWad_),
            amount1.mulWadUp(protocolFeeWad_)
        );
        (recipientFee0, recipientFee1) = (
            amount0 - protocolFee0,
            amount1 - protocolFee1
        );

        // transfer fee tokens
        (, , address token0, address token1, , , , , , , , ) = positionManager
            .positions(id);
        _transferTokenIfNeeded(
            ERC20(token0),
            protocolFeeRecipient_,
            protocolFee0
        );
        _transferTokenIfNeeded(
            ERC20(token1),
            protocolFeeRecipient_,
            protocolFee1
        );
        _transferTokenIfNeeded(ERC20(token0), recipient, recipientFee0);
        _transferTokenIfNeeded(ERC20(token1), recipient, recipientFee1);

        emit ClaimFees(
            id,
            recipient,
            recipientFee0,
            recipientFee1,
            protocolFee0,
            protocolFee1
        );
    }

    function transfer(uint256 id, address to) external {
        // verify sender
        address msgSender = LibMulticaller.senderOrSigner();
        require(ownerOf[id] == msgSender, "AUTH");

        ownerOf[id] = to;

        emit Transfer(msgSender, to, id);
    }

    function onERC721Received(
        address,
        address from,
        uint256 id,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == address(positionManager), "AUTH");

        // get owner address
        address owner;
        if (data.length != 0) {
            // provided data
            // decode into owner address
            owner = abi.decode(data, (address));
        } else {
            // no data
            // owner is just from
            owner = from;
        }

        // give right to claim fees to owner
        ownerOf[id] = owner;

        emit Lock(id, owner);
        emit Transfer(address(0), owner, id);

        return ERC721TokenReceiver.onERC721Received.selector;
    }

    function _transferTokenIfNeeded(
        ERC20 token,
        address to,
        uint256 amount
    ) internal {
        if (amount != 0) {
            token.safeTransfer(to, amount);
        }
    }
}
