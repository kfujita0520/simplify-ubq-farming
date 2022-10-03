// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.4;

/**
 * @title Ubiquity.
 * @dev Ubiquity Dollar (uAD).
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDepositZap.sol";
import "./interfaces/IBondingV2.sol";
import "./interfaces/IBondingShareV2.sol";
import 'hardhat/console.sol';
// import {Helpers} from "./helpers.sol";
// import {Events} from "./events.sol";


contract DirectUBQFarmer is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;//decimal 6
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;//decimal 6
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant UAD3CRVf = 0x20955CB69Ae1515962177D164dfC9522feef567E;
    address public constant UAD = 0x0F644658510c95CB46955e55D7BA9DDa9E9fBEc6;
    address public constant UBQ = 0x4e38D89362f7e5db0096CE44ebD021c3962aA9a0;
    address public constant DepositZapUAD = 0xA79828DF1850E8a3A3064576f380D90aECDD3359;
    address public constant BondingV2 = 0xC251eCD9f1bD5230823F9A0F99a44A87Ddd4CA38;
    address public constant BondingShareV2 = 0x2dA07859613C14F6f05c97eFE37B9B4F212b5eF5;


    constructor() {
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) public virtual returns (bytes4) {
        // Called when receiving ERC1155 token at staking.
        // operator: BondingV2 contract
        // from: address(0x)
        // id: bonding share ID
        // value: 1
        // data: 0x
        // msg.sender: BondingShareV2 contract
        return this.onERC1155Received.selector;
    }


    /**
     * @dev Deposit into Ubiquity protocol
     * @notice Stable coin (DAI / USDC / USDT / uAD) => uAD3CRV-f => Ubiquity BondingShare
     * @notice STEP 1 : Change (DAI / USDC / USDT / uAD) to 3CRV at uAD3CRV MetaPool
     * @notice STEP 2 : uAD3CRV-f => Ubiquity BondingShare
     * @param token Token deposited : DAI, USDC, USDT or uAD
     * @param amount Amount of tokens to deposit (For max: `uint256(-1)`)
     * @param durationWeeks Duration in weeks tokens will be locked (1-208)
     */
    function deposit(
        address token,
        uint256 amount,
        uint256 durationWeeks
    ) external nonReentrant returns (uint256 bondingShareId) {


        // DAI / USDC / USDT / UAD
        require(isMetaPoolCoin(token), "Invalid token: must be DAI, USDC, USDT, or uAD");
        require(amount > 0, "amount must be positive vale");
        require(durationWeeks >= 1 && durationWeeks <= 208, "duration weeks must be between 1 and 208");

        //Note, due to USDT implementation, normal transferFrom does not work and have an error of "function returned an unexpected amount of data"
        //require(IERC20(token).transferFrom(msg.sender, address(this), amount), "sender cannot transfer specified fund");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        uint256 lpAmount;//UAD3CRVf
        //[UAD, DAI, USDC, USDT]
        uint256[4] memory tokenAmounts = [
            token == UAD ? amount : 0,
            token == DAI ? amount : 0,
            token == USDC ? amount : 0,
            token == USDT ? amount : 0
        ];

        //STEP1: add DAI, USDC, USDT or uAD into metapool liquidity and get UAD3CRVf
        IERC20(token).safeIncreaseAllowance(DepositZapUAD, amount);
        lpAmount = IDepositZap(DepositZapUAD).add_liquidity(UAD3CRVf, tokenAmounts, 0);
        console.log('lpAmount: %s', lpAmount);

        //STEP2: stake UAD3CRVf to BondingV2
        //TODO approve token to be transferred to Bonding V2 contract
        IERC20(UAD3CRVf).safeIncreaseAllowance(BondingV2, lpAmount);
        bondingShareId = IBondingV2(BondingV2).deposit(lpAmount, durationWeeks);
        console.log('bondingShareId: %s', bondingShareId);

        IBondingShareV2(BondingShareV2).safeTransferFrom(address(this), msg.sender, bondingShareId, 1, '0x');

        //TODO emit Events

    }

    /**
     * @dev Withdraw from Ubiquity protocol
     * @notice Ubiquity BondingShare => uAD3CRV-f  => stable coin (DAI / USDC / USDT / uAD)
     * @notice STEP 1 : Ubiquity BondingShare  => uAD3CRV-f
     * @notice STEP 2 : uAD3CRV-f => stable coin (DAI / USDC / USDT / uAD)
     * @param bondingShareId Bonding Share Id to withdraw
     * @param token Token to withdraw to : DAI, USDC, USDT, 3CRV or uAD
     */
    function withdraw(
        uint256 bondingShareId,
        address token
    ) external nonReentrant returns (uint256 tokenAmount) {

        // DAI / USDC / USDT / UAD
        require(isMetaPoolCoin(token), "Invalid token: must be DAI, USDC, USDT, uAD");
        uint256[] memory bondingShareIds = IBondingShareV2(BondingShareV2).holderTokens(msg.sender);
        //Need to verify msg.sender by holderToken history.
        //bond.minter is this contract address so that cannot use it for verification.
        require(isIdIncluded(bondingShareIds, bondingShareId), "sender is not true bond owner");

        //transfer bondingShare NFT token from msg.sender to this address
        IBondingShareV2(BondingShareV2).safeTransferFrom(msg.sender, address(this), bondingShareId, 1, '0x');

        // Get Bond
        IBondingShareV2.Bond memory bond = IBondingShareV2(BondingShareV2).getBond(bondingShareId);

        // STEP 1 : Withdraw Ubiquity Bonding Shares to get back uAD3CRV-f LPs
        //address bonding = ubiquityManager.bondingContractAddress();
        IBondingShareV2(BondingShareV2).setApprovalForAll(BondingV2, true);
        IBondingV2(BondingV2).removeLiquidity(bond.lpAmount, bondingShareId);
        IBondingShareV2(BondingShareV2).setApprovalForAll(BondingV2, false);

        uint256 lpAmount = IERC20(UAD3CRVf).balanceOf(address(this));
        console.log('lpAmount: %s', lpAmount);
        console.log('bond.lpAmount: %s', bond.lpAmount);
        uint256 ubqAmount = IERC20(UBQ).balanceOf(address(this));
        console.log('ubqAmount: %s', ubqAmount);


        // STEP2 : Withdraw  3Crv LPs from meta pool to get back UAD, DAI, USDC or USDT
        uint128 tokenIndex = token == UAD ? 0 : (token == DAI ? 1 : (token == USDC ? 2 : 3));
        IERC20(UAD3CRVf).approve(DepositZapUAD, lpAmount);
        tokenAmount = IDepositZap(DepositZapUAD).remove_liquidity_one_coin(UAD3CRVf, lpAmount, int128(tokenIndex), 0); //[UAD, DAI, USDC, USDT]

        console.log('tokenAmount: %s', tokenAmount);

        IERC20(token).safeTransfer(msg.sender, tokenAmount);
        IERC20(UBQ).safeTransfer(msg.sender, ubqAmount);

        //TODO event


    }

    function isIdIncluded(uint256[] memory idList, uint256 id) internal pure returns (bool){
        for (uint i=0; i < idList.length; i++){
            if (idList[i]==id){
                return true;
            }
        }
        return false;

    }

    function isMetaPoolCoin(address token) public pure returns (bool) {
        return (token == USDT || token == USDC || token == DAI || token == UAD);
    }

}


