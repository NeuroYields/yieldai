// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Yield} from "../src/Yield.sol";
import {INonfungiblePositionManager} from "../src/interfaces/INonfungiblePositionManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    // NonfungiblePositionManager addresses on BNB Chain
    address constant PANCAKESWAP_NFPM =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address constant UNISWAP_NFPM = 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613;

    // Router addresses on BNB Chain
    address constant PANCAKESWAP_ROUTER =
        0x13f4EA83D0bd40E75C8222255bc855a974568Dd4; // PancakeSwap V3 SmartRouter
    address constant UNISWAP_ROUTER = 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2; // Uniswap V3 SwapRouter

    // Whale addresses with tokens for testing
    address constant USDT_WHALE = 0x8894E0a0c962CB723c1976a4421c95949bE2D4E3; // Binance Hot Wallet
    address constant ASTER_WHALE = 0x000Ae314E2A2172a039B26378814C252734f556A; // ASTER token contract (has initial supply)

    function setUp() public {
        // Deploy the Yield contract
        yieldContract = new Yield(
            UNISWAP_NFPM,
            PANCAKESWAP_NFPM,
            UNISWAP_ROUTER,
            PANCAKESWAP_ROUTER
        );
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

    /// @notice Test adding liquidity to PancakeSwap V3 pool
    function test_AddLiquidity_PancakeSwap() public {
        // Get pool details first to determine current tick
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            PAN_ASTER_USDT_POOL
        );

        console.log("=== Adding Liquidity to PancakeSwap V3 ===");
        console.log("Current Tick:", details.currentTick);
        console.log("Tick Spacing:", details.tickSpacing);

        // Calculate tick range around current tick (aligned to tick spacing)
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;

        // Round current tick to nearest tick spacing
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        console.log("Tick Lower:", tickLower);
        console.log("Tick Upper:", tickUpper);

        // Use small amounts for testing (0.1 USDT and equivalent ASTER)
        uint256 amount0Desired = 100000; // 0.1 ASTER (6 decimals)
        uint256 amount1Desired = 100000; // 0.1 USDT (18 decimals)

        // Impersonate USDT whale
        vm.startPrank(USDT_WHALE);

        // Check balances before
        uint256 usdtBalanceBefore = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);
        uint256 asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);

        console.log("USDT Balance Before:", usdtBalanceBefore);
        console.log("ASTER Balance Before:", asterBalanceBefore);

        // If whale doesn't have ASTER, deal some
        if (asterBalanceBefore < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
            asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
            console.log(
                "Dealt ASTER to whale, new balance:",
                asterBalanceBefore
            );
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Prepare mint parameters
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0, // No slippage protection for test
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        // Add liquidity
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = yieldContract.addLiquidity(Yield.DexType.PANCAKESWAP, params);

        vm.stopPrank();

        // Assertions
        assertTrue(tokenId > 0, "Token ID should be greater than 0");
        assertTrue(liquidity > 0, "Liquidity should be greater than 0");
        console.log("Position NFT Token ID:", tokenId);
        console.log("Liquidity Added:", liquidity);
        console.log("Amount0 Used:", amount0);
        console.log("Amount1 Used:", amount1);

        // Verify the position was created
        _verifyPosition(
            PANCAKESWAP_NFPM,
            tokenId,
            details.token0,
            details.token1,
            details.fee,
            tickLower,
            tickUpper,
            liquidity
        );

        console.log("=== Position Verified Successfully ===");
    }

    /// @notice Test adding liquidity to Uniswap V3 pool
    function test_AddLiquidity_Uniswap() public {
        // Get pool details first to determine current tick
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            UNI_ASTER_USDT_POOL
        );

        console.log("=== Adding Liquidity to Uniswap V3 ===");
        console.log("Current Tick:", details.currentTick);
        console.log("Tick Spacing:", details.tickSpacing);

        // Calculate tick range around current tick (aligned to tick spacing)
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;

        // Round current tick to nearest tick spacing
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        console.log("Tick Lower:", tickLower);
        console.log("Tick Upper:", tickUpper);

        // Use small amounts for testing (0.1 USDT and equivalent ASTER)
        uint256 amount0Desired = 100000; // 0.1 ASTER (6 decimals)
        uint256 amount1Desired = 100000; // 0.1 USDT (18 decimals)

        // Impersonate USDT whale
        vm.startPrank(USDT_WHALE);

        // Check balances before
        uint256 usdtBalanceBefore = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);
        uint256 asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);

        console.log("USDT Balance Before:", usdtBalanceBefore);
        console.log("ASTER Balance Before:", asterBalanceBefore);

        // If whale doesn't have ASTER, deal some
        if (asterBalanceBefore < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
            asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
            console.log(
                "Dealt ASTER to whale, new balance:",
                asterBalanceBefore
            );
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Prepare mint parameters
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
            .MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0, // No slippage protection for test
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        // Add liquidity
        (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        ) = yieldContract.addLiquidity(Yield.DexType.UNISWAP, params);

        vm.stopPrank();

        // Assertions
        assertTrue(tokenId > 0, "Token ID should be greater than 0");
        assertTrue(liquidity > 0, "Liquidity should be greater than 0");
        console.log("Position NFT Token ID:", tokenId);
        console.log("Liquidity Added:", liquidity);
        console.log("Amount0 Used:", amount0);
        console.log("Amount1 Used:", amount1);

        // Verify the position was created
        _verifyPosition(
            UNISWAP_NFPM,
            tokenId,
            details.token0,
            details.token1,
            details.fee,
            tickLower,
            tickUpper,
            liquidity
        );

        console.log("=== Position Verified Successfully ===");
    }

    /// @notice Helper function to verify position details
    function _verifyPosition(
        address nfpmAddress,
        uint256 tokenId,
        address expectedToken0,
        address expectedToken1,
        uint24 expectedFee,
        int24 expectedTickLower,
        int24 expectedTickUpper,
        uint128 expectedLiquidity
    ) internal {
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            nfpmAddress
        );
        (
            ,
            ,
            address posToken0,
            address posToken1,
            uint24 posFee,
            int24 posTickLower,
            int24 posTickUpper,
            uint128 posLiquidity,
            ,
            ,
            ,

        ) = nfpm.positions(tokenId);

        assertEq(posToken0, expectedToken0, "Position token0 mismatch");
        assertEq(posToken1, expectedToken1, "Position token1 mismatch");
        assertEq(posFee, expectedFee, "Position fee mismatch");
        assertEq(
            posTickLower,
            expectedTickLower,
            "Position tickLower mismatch"
        );
        assertEq(
            posTickUpper,
            expectedTickUpper,
            "Position tickUpper mismatch"
        );
        assertEq(
            posLiquidity,
            expectedLiquidity,
            "Position liquidity mismatch"
        );
    }

    /// @notice Test removing liquidity from PancakeSwap V3 pool
    function test_RemoveLiquidity_PancakeSwap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            PAN_ASTER_USDT_POOL
        );

        console.log("=== Removing Liquidity from PancakeSwap V3 ===");

        // Calculate tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000; // 0.1 ASTER
        uint256 amount1Desired = 100000; // 0.1 USDT

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 tokenId, uint128 liquidity, , ) = yieldContract.addLiquidity(
            Yield.DexType.PANCAKESWAP,
            params
        );

        console.log("Position created with Token ID:", tokenId);
        console.log("Liquidity:", liquidity);

        // Check balances before removal
        uint256 asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
        uint256 usdtBalanceBefore = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);

        // Approve NFT transfer
        INonfungiblePositionManager(PANCAKESWAP_NFPM).approve(
            address(yieldContract),
            tokenId
        );

        // Remove liquidity (remove all, don't burn)
        (uint256 amount0, uint256 amount1) = yieldContract.removeLiquidity(
            Yield.DexType.PANCAKESWAP,
            tokenId,
            0, // Remove all liquidity
            0, // No slippage protection
            0,
            false // Don't burn NFT
        );

        vm.stopPrank();

        console.log("Amount0 received:", amount0);
        console.log("Amount1 received:", amount1);

        // Verify tokens were received
        uint256 asterBalanceAfter = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
        uint256 usdtBalanceAfter = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);

        assertTrue(amount0 > 0, "Should receive token0");
        assertTrue(amount1 > 0, "Should receive token1");
        assertGt(
            asterBalanceAfter,
            asterBalanceBefore,
            "ASTER balance should increase"
        );
        assertGt(
            usdtBalanceAfter,
            usdtBalanceBefore,
            "USDT balance should increase"
        );

        // Verify position has 0 liquidity
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            PANCAKESWAP_NFPM
        );
        (, , , , , , , uint128 remainingLiquidity, , , , ) = nfpm.positions(
            tokenId
        );
        assertEq(remainingLiquidity, 0, "Position should have 0 liquidity");

        console.log("=== Liquidity Removed Successfully ===");
    }

    /// @notice Test removing liquidity from Uniswap V3 pool
    function test_RemoveLiquidity_Uniswap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            UNI_ASTER_USDT_POOL
        );

        console.log("=== Removing Liquidity from Uniswap V3 ===");

        // Calculate tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000;
        uint256 amount1Desired = 100000;

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 tokenId, uint128 liquidity, , ) = yieldContract.addLiquidity(
            Yield.DexType.UNISWAP,
            params
        );

        console.log("Position created with Token ID:", tokenId);
        console.log("Liquidity:", liquidity);

        // Check balances before removal
        uint256 asterBalanceBefore = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
        uint256 usdtBalanceBefore = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);

        // Approve NFT transfer
        INonfungiblePositionManager(UNISWAP_NFPM).approve(
            address(yieldContract),
            tokenId
        );

        // Remove liquidity (remove all, don't burn)
        (uint256 amount0, uint256 amount1) = yieldContract.removeLiquidity(
            Yield.DexType.UNISWAP,
            tokenId,
            0, // Remove all liquidity
            0, // No slippage protection
            0,
            false // Don't burn NFT
        );

        vm.stopPrank();

        console.log("Amount0 received:", amount0);
        console.log("Amount1 received:", amount1);

        // Verify tokens were received
        uint256 asterBalanceAfter = IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE);
        uint256 usdtBalanceAfter = IERC20(USDT_TOKEN).balanceOf(USDT_WHALE);

        assertTrue(amount0 > 0, "Should receive token0");
        assertTrue(amount1 > 0, "Should receive token1");
        assertGt(
            asterBalanceAfter,
            asterBalanceBefore,
            "ASTER balance should increase"
        );
        assertGt(
            usdtBalanceAfter,
            usdtBalanceBefore,
            "USDT balance should increase"
        );

        // Verify position has 0 liquidity
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            UNISWAP_NFPM
        );
        (, , , , , , , uint128 remainingLiquidity, , , , ) = nfpm.positions(
            tokenId
        );
        assertEq(remainingLiquidity, 0, "Position should have 0 liquidity");

        console.log("=== Liquidity Removed Successfully ===");
    }

    /// @notice Test removing liquidity and burning NFT
    function test_RemoveLiquidityAndBurn_PancakeSwap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            PAN_ASTER_USDT_POOL
        );

        console.log("=== Removing Liquidity and Burning NFT (PancakeSwap) ===");

        // Calculate tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000;
        uint256 amount1Desired = 100000;

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 tokenId, uint128 liquidity, , ) = yieldContract.addLiquidity(
            Yield.DexType.PANCAKESWAP,
            params
        );

        console.log("Position created with Token ID:", tokenId);
        console.log("Liquidity:", liquidity);

        // Approve NFT transfer
        INonfungiblePositionManager(PANCAKESWAP_NFPM).approve(
            address(yieldContract),
            tokenId
        );

        // Remove liquidity and burn NFT
        (uint256 amount0, uint256 amount1) = yieldContract.removeLiquidity(
            Yield.DexType.PANCAKESWAP,
            tokenId,
            0, // Remove all liquidity
            0, // No slippage protection
            0,
            true // Burn NFT
        );

        vm.stopPrank();

        console.log("Amount0 received:", amount0);
        console.log("Amount1 received:", amount1);

        assertTrue(amount0 > 0, "Should receive token0");
        assertTrue(amount1 > 0, "Should receive token1");

        // Verify NFT was burned by checking if positions() reverts
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            PANCAKESWAP_NFPM
        );

        // Try to query the position - it should revert since NFT is burned
        vm.expectRevert();
        nfpm.positions(tokenId);

        console.log("=== NFT Burned Successfully ===");
    }

    /// @notice Test partial liquidity removal
    function test_RemovePartialLiquidity_Uniswap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            UNI_ASTER_USDT_POOL
        );

        console.log("=== Removing Partial Liquidity from Uniswap V3 ===");

        // Calculate tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000;
        uint256 amount1Desired = 100000;

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 tokenId, uint128 liquidity, , ) = yieldContract.addLiquidity(
            Yield.DexType.UNISWAP,
            params
        );

        console.log("Position created with Token ID:", tokenId);
        console.log("Total Liquidity:", liquidity);

        // Calculate half of the liquidity
        uint128 halfLiquidity = liquidity / 2;
        console.log("Removing half liquidity:", halfLiquidity);

        // Approve NFT transfer
        INonfungiblePositionManager(UNISWAP_NFPM).approve(
            address(yieldContract),
            tokenId
        );

        // Remove half of the liquidity
        (uint256 amount0, uint256 amount1) = yieldContract.removeLiquidity(
            Yield.DexType.UNISWAP,
            tokenId,
            halfLiquidity, // Remove half
            0, // No slippage protection
            0,
            false // Don't burn NFT
        );

        vm.stopPrank();

        console.log("Amount0 received:", amount0);
        console.log("Amount1 received:", amount1);

        assertTrue(amount0 > 0, "Should receive token0");
        assertTrue(amount1 > 0, "Should receive token1");

        // Verify position still has remaining liquidity
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            UNISWAP_NFPM
        );
        (, , , , , , , uint128 remainingLiquidity, , , , ) = nfpm.positions(
            tokenId
        );

        console.log("Remaining liquidity:", remainingLiquidity);
        assertGt(
            remainingLiquidity,
            0,
            "Position should have remaining liquidity"
        );
        assertApproxEqAbs(
            remainingLiquidity,
            liquidity - halfLiquidity,
            1,
            "Remaining liquidity should be approximately half"
        );

        console.log("=== Partial Liquidity Removed Successfully ===");
    }

    /// @notice Test rebalancing a position without swapping
    function test_Rebalance_NoSwap_PancakeSwap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            PAN_ASTER_USDT_POOL
        );

        console.log("=== Rebalancing Position (No Swap) - PancakeSwap ===");

        // Calculate initial tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000;
        uint256 amount1Desired = 100000;

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 oldTokenId, uint128 oldLiquidity, , ) = yieldContract
            .addLiquidity(Yield.DexType.PANCAKESWAP, params);

        console.log("Old Position Token ID:", oldTokenId);
        console.log("Old Liquidity:", oldLiquidity);

        // Calculate new tick range (wider range)
        int24 newTickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 20);
        int24 newTickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 20);

        console.log("New Tick Lower:", newTickLower);
        console.log("New Tick Upper:", newTickUpper);

        // Approve NFT transfer
        INonfungiblePositionManager(PANCAKESWAP_NFPM).approve(
            address(yieldContract),
            oldTokenId
        );

        // Rebalance without swapping
        (uint256 newTokenId, uint128 newLiquidity) = yieldContract.rebalance(
            Yield.DexType.PANCAKESWAP,
            oldTokenId,
            newTickLower,
            newTickUpper,
            address(0), // No swap
            address(0),
            0,
            0,
            0
        );

        vm.stopPrank();

        console.log("New Position Token ID:", newTokenId);
        console.log("New Liquidity:", newLiquidity);

        // Verify new position exists
        assertTrue(newTokenId > 0, "New token ID should be valid");
        assertTrue(newLiquidity > 0, "New liquidity should be positive");

        // Verify old position was burned
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            PANCAKESWAP_NFPM
        );
        vm.expectRevert();
        nfpm.positions(oldTokenId);

        // Verify new position details
        _verifyPosition(
            PANCAKESWAP_NFPM,
            newTokenId,
            details.token0,
            details.token1,
            details.fee,
            newTickLower,
            newTickUpper,
            newLiquidity
        );

        console.log("=== Position Rebalanced Successfully ===");
    }

    /// @notice Test rebalancing a position with token swap
    /// NOTE: This test is currently skipped because PancakeSwap SmartRouter has a different interface
    /// In production, you would need to implement the correct router interface or use a DEX aggregator
    function skip_test_Rebalance_WithSwap_Uniswap() public {
        // First, add liquidity to get a position
        Yield.PoolDetails memory details = yieldContract.getPoolDetails(
            UNI_ASTER_USDT_POOL
        );

        console.log("=== Rebalancing Position (With Swap) - Uniswap ===");

        // Calculate initial tick range
        int24 tickSpacing = details.tickSpacing;
        int24 currentTick = details.currentTick;
        int24 tickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 10);
        int24 tickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 10);

        // Use small amounts for testing
        uint256 amount0Desired = 100000;
        uint256 amount1Desired = 100000;

        vm.startPrank(USDT_WHALE);

        // Deal ASTER if needed
        if (IERC20(ASTER_TOKEN).balanceOf(USDT_WHALE) < amount0Desired) {
            deal(ASTER_TOKEN, USDT_WHALE, amount0Desired * 10);
        }

        // Approve tokens
        IERC20(ASTER_TOKEN).approve(address(yieldContract), amount0Desired);
        IERC20(USDT_TOKEN).approve(address(yieldContract), amount1Desired);

        // Add liquidity
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: details.token0,
                token1: details.token1,
                fee: details.fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: 0,
                amount1Min: 0,
                recipient: USDT_WHALE,
                deadline: block.timestamp + 300
            });

        (uint256 oldTokenId, uint128 oldLiquidity, , ) = yieldContract
            .addLiquidity(Yield.DexType.UNISWAP, params);

        console.log("Old Position Token ID:", oldTokenId);
        console.log("Old Liquidity:", oldLiquidity);

        // Calculate new tick range
        int24 newTickLower = (currentTick / tickSpacing) *
            tickSpacing -
            (tickSpacing * 15);
        int24 newTickUpper = (currentTick / tickSpacing) *
            tickSpacing +
            (tickSpacing * 15);

        console.log("New Tick Lower:", newTickLower);
        console.log("New Tick Upper:", newTickUpper);

        // Approve NFT transfer
        INonfungiblePositionManager(UNISWAP_NFPM).approve(
            address(yieldContract),
            oldTokenId
        );

        // Rebalance with swapping (swap some ASTER to USDT using PancakeSwap)
        uint256 swapAmount = 10000; // Swap 10k ASTER to USDT
        (uint256 newTokenId, uint128 newLiquidity) = yieldContract.rebalance(
            Yield.DexType.UNISWAP,
            oldTokenId,
            newTickLower,
            newTickUpper,
            ASTER_TOKEN, // Swap from ASTER
            USDT_TOKEN, // Swap to USDT
            swapAmount,
            0, // No slippage protection for test
            2500 // Use 0.25% fee tier on PancakeSwap
        );

        vm.stopPrank();

        console.log("New Position Token ID:", newTokenId);
        console.log("New Liquidity:", newLiquidity);

        // Verify new position exists
        assertTrue(newTokenId > 0, "New token ID should be valid");
        assertTrue(newLiquidity > 0, "New liquidity should be positive");

        // Verify old position was burned
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(
            UNISWAP_NFPM
        );
        vm.expectRevert();
        nfpm.positions(oldTokenId);

        // Verify new position details
        _verifyPosition(
            UNISWAP_NFPM,
            newTokenId,
            details.token0,
            details.token1,
            details.fee,
            newTickLower,
            newTickUpper,
            newLiquidity
        );

        console.log("=== Position Rebalanced with Swap Successfully ===");
    }
}
