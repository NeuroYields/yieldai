// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Yield} from "../src/Yield.sol";

contract YieldTest is Test {
    Yield public yieldContract;

    address constant ASTER_TOKEN = 0x000Ae314E2A2172a039B26378814C252734f556A; // ASTER token on BNB Chain
    address constant USDT_TOKEN = 0x55d398326f99059fF775485246999027B3197955; // USDT token on BNB Chain

    // PancakeSwap V3 pools on BNB Chain
    address constant PAN_ASTER_USDT_POOL =
        0xaeaD6bd31dd66Eb3A6216aAF271D0E661585b0b1; // ASTER/USDT 0.25% fee

    // Uniswap V3 pools on BNB chain
    address constant UNI_ASTER_USDT_POOL =
        0x30Db6DFDb8817765797bd62316e41F5f4E431E93; // ASTER/USDT 0.3% fee

    function setUp() public {
        // Deploy the Yield contract
        yieldContract = new Yield();
    }

    /// @notice Test getting pool details for PancakeSwap V3 pool (USDT/ASTER)
    function test_GetPoolDetails_PancakeSwap() public {
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            PAN_ASTER_USDT_POOL
        );

        // Log pool details
        console.log("=== ASTER/USDT Pool Details ===");
        console.log("Pool Address:", details.pool);
        console.log("Token0:", details.token0);
        console.log("Token1:", details.token1);
        console.log("Token0 Name:", details.token0Name);
        console.log("Token0 Symbol:", details.token0Symbol);
        console.log("Token0 Decimals:", details.token0Decimals);
        console.log("Token1 Name:", details.token1Name);
        console.log("Token1 Symbol:", details.token1Symbol);
        console.log("Token1 Decimals:", details.token1Decimals);
        console.log("Fee:", details.fee);
        console.log("Tick Spacing:", details.tickSpacing);
        console.log("Current Tick:", details.currentTick);
        console.log("Liquidity:", details.liquidity);
        console.log("Sqrt Price X96:", details.sqrtPriceX96);

        // Assertions
        assertEq(details.pool, PAN_ASTER_USDT_POOL, "Pool address mismatch");
        assertTrue(
            details.token0 != address(0),
            "Token0 should not be zero address"
        );
        assertTrue(
            details.token1 != address(0),
            "Token1 should not be zero address"
        );
        assertTrue(
            bytes(details.token0Name).length > 0,
            "Token0 name should not be empty"
        );
        assertTrue(
            bytes(details.token1Name).length > 0,
            "Token1 name should not be empty"
        );
        assertTrue(details.fee > 0, "Fee should be greater than 0");
        assertTrue(details.liquidity > 0, "Liquidity should be greater than 0");
    }

    /// @notice Test getting pool details for Uniswap V3 pool (USDT/ASTER)
    function test_GetPoolDetails_UniswapV3() public {
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            UNI_ASTER_USDT_POOL
        );

        // Log pool details
        console.log("=== ASTER/USDT Pool Details ===");
        console.log("Pool Address:", details.pool);
        console.log("Token0:", details.token0);
        console.log("Token1:", details.token1);
        console.log("Token0 Name:", details.token0Name);
        console.log("Token0 Symbol:", details.token0Symbol);
        console.log("Token0 Decimals:", details.token0Decimals);
        console.log("Token1 Name:", details.token1Name);
        console.log("Token1 Symbol:", details.token1Symbol);
        console.log("Token1 Decimals:", details.token1Decimals);
        console.log("Fee:", details.fee);
        console.log("Tick Spacing:", details.tickSpacing);
        console.log("Current Tick:", details.currentTick);
        console.log("Liquidity:", details.liquidity);
        console.log("Sqrt Price X96:", details.sqrtPriceX96);
    }
}
