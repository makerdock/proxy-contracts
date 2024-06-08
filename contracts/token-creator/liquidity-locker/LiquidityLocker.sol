// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface NonFungibleContract {
    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The address that is approved for spending
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return fee The fee associated with the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The higher end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
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

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param params tokenId The ID of the NFT for which tokens are being collected,
    /// recipient The account that should receive the tokens,
    /// amount0Max The maximum amount of token0 to collect,
    /// amount1Max The maximum amount of token1 to collect
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);
}

contract LpLocker is Context, Ownable {
    event ERC721Released(address indexed token, uint256 amount);

    event LockId(uint256 _id);

    event LockDuration(uint256 _time);

    uint256 private _released;
    mapping(address token => uint256) public _erc721Released;
    IERC721 private SafeERC721;
    uint64 private immutable _duration;
    address private immutable e721Token;
    bool private flag;
    NonFungibleContract private positionManager;
    string public constant version = "0.0.1";

    /**
     * @dev Sets the sender as the initial owner, the beneficiary as the pending owner, and the duration for the lock
     * vesting duration of the vesting wallet.
     */
    constructor(
        address token,
        address beneficiary,
        uint64 durationSeconds
    ) payable Ownable(beneficiary) {
        _duration = durationSeconds;
        SafeERC721 = IERC721(token);
        // already false but lets be safe
        flag = false;
        e721Token = token;
        emit LockDuration(durationSeconds);
    }

    function initializer(uint256 _tokenId) public {
        require(flag == false, "contract already initialized");
        _erc721Released[e721Token] = _tokenId;
        flag = true;
        positionManager = NonFungibleContract(e721Token);
        SafeERC721.transferFrom(owner(), address(this), _tokenId);
        emit LockId(_tokenId);
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    /**
     * @dev returns the tokenId of the locked LP
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc721Released[token];
    }

    function withdrawERC20(address _token) public {
        require(owner() == msg.sender, "only owner can call");
        IERC20 IToken = IERC20(_token);
        IToken.transferFrom(address(this), owner(), IToken.balanceOf(owner()));
    }

    /**
     * Use The multicall to collect fees
     */
    function multicall(
        bytes[] calldata data
    ) public payable returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            results[i] = result;
        }
    }
}
