// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import "forge-std/console.sol";

contract Yield is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

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
}
