// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import "forge-std/console.sol";

contract Yield is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Enum to specify which DEX to use
    enum DexType {
        UNISWAP,
        PANCAKESWAP
    }

    /// @notice Struct to hold pool details
    struct PoolDetails {
        address pool;
        address token0;
        address token1;
        string token0Name;
        string token0Symbol;
        uint8 token0Decimals;
        string token1Name;
        string token1Symbol;
        uint8 token1Decimals;
        uint24 fee;
        int24 tickSpacing;
        int24 currentTick;
        uint160 sqrtPriceX96;
        uint128 liquidity;
    }

    /// @notice Address of Uniswap V3 NonfungiblePositionManager
    address public uniswapNFPM;

    /// @notice Address of PancakeSwap V3 NonfungiblePositionManager
    address public pancakeswapNFPM;

    /// @notice Event emitted when NFPM addresses are updated
    event NFPMAddressUpdated(DexType indexed dexType, address indexed nfpm);

    /// @notice Event emitted when liquidity is added
    event LiquidityAdded(
        DexType indexed dexType,
        uint256 indexed tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );

    constructor() Ownable(msg.sender) {}

    /// @notice Get all details for a Uniswap V3 or PancakeSwap V3 pool
    /// @param poolAddress The address of the pool
    /// @return details A struct containing all pool and token details
    function getPoolDetails(
        address poolAddress
    ) external returns (PoolDetails memory details) {
        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress);

        // Get pool basic info
        details.pool = poolAddress;
        details.token0 = pool.token0();
        details.token1 = pool.token1();
        details.fee = pool.fee();
        details.tickSpacing = pool.tickSpacing();
        details.liquidity = pool.liquidity();

        console.log("Fetched pool data from:", poolAddress);

        // Get slot0 data (current tick and price)
        (uint160 sqrtPriceX96, int24 tick, , , , , ) = pool.slot0();
        console.log("Current tick:", tick);
        details.currentTick = tick;
        details.sqrtPriceX96 = sqrtPriceX96;

        IERC20Metadata token0 = IERC20Metadata(details.token0);
        IERC20Metadata token1 = IERC20Metadata(details.token1);

        // Get token0 details with try-catch to handle non-standard tokens
        details.token0Name = token0.name();
        details.token0Symbol = token0.symbol();
        details.token0Decimals = token0.decimals();

        // Get token1 details with try-catch to handle non-standard tokens
        details.token1Name = token1.name();
        details.token1Symbol = token1.symbol();
        details.token1Decimals = token1.decimals();

        return details;
    }

    /// @notice Set the Uniswap V3 NonfungiblePositionManager address
    /// @param _nfpm The address of the Uniswap V3 NFPM
    function setUniswapNFPM(address _nfpm) external onlyOwner {
        require(_nfpm != address(0), "Invalid address");
        uniswapNFPM = _nfpm;
        emit NFPMAddressUpdated(DexType.UNISWAP, _nfpm);
    }

    /// @notice Set the PancakeSwap V3 NonfungiblePositionManager address
    /// @param _nfpm The address of the PancakeSwap V3 NFPM
    function setPancakeswapNFPM(address _nfpm) external onlyOwner {
        require(_nfpm != address(0), "Invalid address");
        pancakeswapNFPM = _nfpm;
        emit NFPMAddressUpdated(DexType.PANCAKESWAP, _nfpm);
    }

    /// @notice Add liquidity to a pool using the specified DEX's NonfungiblePositionManager
    /// @param dexType The DEX to use (UNISWAP or PANCAKESWAP)
    /// @param params The mint parameters for adding liquidity
    /// @return tokenId The ID of the newly minted position NFT
    /// @return liquidity The amount of liquidity added
    /// @return amount0 The actual amount of token0 added
    /// @return amount1 The actual amount of token1 added
    function addLiquidity(
        DexType dexType,
        INonfungiblePositionManager.MintParams calldata params
    )
        external
        nonReentrant
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        // Get the appropriate NFPM address based on DEX type
        address nfpm = dexType == DexType.UNISWAP ? uniswapNFPM : pancakeswapNFPM;
        require(nfpm != address(0), "NFPM not set");

        // Transfer tokens from user to this contract
        IERC20(params.token0).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount0Desired
        );
        IERC20(params.token1).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount1Desired
        );

        // Approve NFPM to spend tokens
        IERC20(params.token0).forceApprove(nfpm, params.amount0Desired);
        IERC20(params.token1).forceApprove(nfpm, params.amount1Desired);

        // Mint the position
        (tokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(nfpm).mint(params);

        // Refund any unused tokens to the user
        if (params.amount0Desired > amount0) {
            IERC20(params.token0).safeTransfer(msg.sender, params.amount0Desired - amount0);
        }
        if (params.amount1Desired > amount1) {
            IERC20(params.token1).safeTransfer(msg.sender, params.amount1Desired - amount1);
        }

        // Reset approvals to 0 for security
        IERC20(params.token0).forceApprove(nfpm, 0);
        IERC20(params.token1).forceApprove(nfpm, 0);

        emit LiquidityAdded(dexType, tokenId, liquidity, amount0, amount1);

        console.log("Liquidity added successfully");
        console.log("Token ID:", tokenId);
        console.log("Liquidity:", liquidity);
        console.log("Amount0:", amount0);
        console.log("Amount1:", amount1);

        return (tokenId, liquidity, amount0, amount1);
    }
}
