// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IManager.sol";

interface INonfungiblePositionManager is IERC721 {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);
}

contract LpLocker is Context, Ownable {
    event ERC721Released(address indexed token, uint256 amount);

    event LockId(uint256 _id);

    event LockDuration(uint256 _time);

    uint256 private _released;
    mapping(address => uint256) public _erc721Released;
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
        //already false but lets be safe
        flag = false;
        e721Token = token;
        emit LockDuration(durationSeconds);
    }

    function initializer(uint256 token_id) public {
        require(flag == false, "contract already initialized");
        _erc721Released[e721Token] = token_id;
        flag = true;
        positionManager = NonFungibleContract(e721Token);
        SafeERC721.transferFrom(owner(), address(this), token_id);
        emit LockId(token_id);
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable virtual {}

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return duration();
    }

    /**
     * @dev returns the tokenId of the locked LP
     */
    function released(address token) public view virtual returns (uint256) {
        return _erc721Released[token];
    }

    /**
     * @dev Release the token that have already vested.
     *
     * Emits a {ERC721Released} event.
     */
    function release() public virtual {
        if (vestingSchedule() != 0) {
            revert();
        }
        uint256 id = _erc721Released[e721Token];
        emit ERC721Released(e721Token, id);
        SafeERC721.transferFrom(address(this), owner(), id);
    }

    function withdrawERC20(address _token) public {
        require(owner() == msg.sender, "only owner can call");
        IERC20 IToken = IERC20(_token);
        IToken.transferFrom(address(this), owner(), IToken.balanceOf(owner()));
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
        // base
        if (chainId == 8453) {
            weth = 0x4200000000000000000000000000000000000006;
            nonFungiblePositionManager = INonfungiblePositionManager(
                0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1
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

    //Use collect fees to collect the fees
    function collectFees(address _recipient, uint256 _tokenId) public {
        require(owner() == msg.sender, "only owner can call");
        (
            ,
            INonfungiblePositionManager nonfungiblePositionManager
        ) = _getAddresses();
        nonfungiblePositionManager.collect(
            INonfungiblePositionManager.CollectParams({
                recipient: _recipient,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max,
                tokenId: _tokenId
            })
        );
    }

    /**
     * Checks the vesting schedule for the token
     */
    function vestingSchedule() public view returns (uint256) {
        if (block.timestamp > duration()) {
            return 0;
        } else {
            return duration() - block.timestamp;
        }
    }
}
