// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "./interfaces/INonfungiblePositionManager.sol";
import {ISwapRouter} from "./interfaces/ISwapRouter.sol";
import "forge-std/console.sol";

contract Yield is Ownable, ReentrancyGuard, IERC721Receiver {
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

    /// @notice Address of Uniswap V3 SwapRouter
    address public uniswapRouter;

    /// @notice Address of PancakeSwap V3 SmartRouter
    address public pancakeswapRouter;

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

    /// @notice Event emitted when liquidity is removed
    event LiquidityRemoved(
        DexType indexed dexType,
        uint256 indexed tokenId,
        uint128 liquidityRemoved,
        uint256 amount0,
        uint256 amount1,
        bool burned
    );

    /// @notice Event emitted when tokens are swapped
    event TokensSwapped(
        DexType indexed dexType,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    /// @notice Event emitted when position is rebalanced
    event PositionRebalanced(
        DexType indexed dexType,
        uint256 indexed oldTokenId,
        uint256 indexed newTokenId,
        uint128 newLiquidity
    );

    constructor(
        address _uniswapNFPM,
        address _pancakeswapNFPM,
        address _uniswapRouter,
        address _pancakeswapRouter
    ) Ownable(msg.sender) {
        uniswapNFPM = _uniswapNFPM;
        pancakeswapNFPM = _pancakeswapNFPM;
        uniswapRouter = _uniswapRouter;
        pancakeswapRouter = _pancakeswapRouter;
    }

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

    /// @notice Set the Uniswap V3 SwapRouter address
    /// @param _router The address of the Uniswap V3 SwapRouter
    function setUniswapRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid address");
        uniswapRouter = _router;
    }

    /// @notice Set the PancakeSwap V3 SmartRouter address
    /// @param _router The address of the PancakeSwap V3 SmartRouter
    function setPancakeswapRouter(address _router) external onlyOwner {
        require(_router != address(0), "Invalid address");
        pancakeswapRouter = _router;
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
        address nfpm = dexType == DexType.UNISWAP
            ? uniswapNFPM
            : pancakeswapNFPM;
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
        (tokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(
            nfpm
        ).mint(params);

        // Refund any unused tokens to the user
        if (params.amount0Desired > amount0) {
            IERC20(params.token0).safeTransfer(
                msg.sender,
                params.amount0Desired - amount0
            );
        }
        if (params.amount1Desired > amount1) {
            IERC20(params.token1).safeTransfer(
                msg.sender,
                params.amount1Desired - amount1
            );
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

    /// @notice Remove liquidity from a position
    /// @param dexType The DEX to use (UNISWAP or PANCAKESWAP)
    /// @param tokenId The ID of the position NFT
    /// @param liquidityToRemove The amount of liquidity to remove (use 0 to remove all)
    /// @param amount0Min Minimum amount of token0 to receive
    /// @param amount1Min Minimum amount of token1 to receive
    /// @param burnNFT Whether to burn the NFT after removing all liquidity
    /// @return amount0 The amount of token0 received
    /// @return amount1 The amount of token1 received
    function removeLiquidity(
        DexType dexType,
        uint256 tokenId,
        uint128 liquidityToRemove,
        uint256 amount0Min,
        uint256 amount1Min,
        bool burnNFT
    ) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        // Get the appropriate NFPM address based on DEX type
        address nfpm = dexType == DexType.UNISWAP
            ? uniswapNFPM
            : pancakeswapNFPM;
        require(nfpm != address(0), "NFPM not set");

        INonfungiblePositionManager nfpmContract = INonfungiblePositionManager(
            nfpm
        );

        // Get position details to determine liquidity
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 positionLiquidity,
            ,
            ,
            ,

        ) = nfpmContract.positions(tokenId);

        // If liquidityToRemove is 0, remove all liquidity
        uint128 liquidityAmount = liquidityToRemove == 0
            ? positionLiquidity
            : liquidityToRemove;
        require(liquidityAmount > 0, "No liquidity to remove");
        require(liquidityAmount <= positionLiquidity, "Insufficient liquidity");

        // Transfer NFT from user to this contract
        nfpmContract.transferFrom(msg.sender, address(this), tokenId);

        // Decrease liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidityAmount,
                    amount0Min: amount0Min,
                    amount1Min: amount1Min,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nfpmContract.decreaseLiquidity(decreaseParams);

        // Collect the tokens
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: msg.sender,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (uint256 collected0, uint256 collected1) = nfpmContract.collect(
            collectParams
        );

        // Burn NFT if requested and all liquidity is removed
        bool burned = false;
        if (burnNFT && liquidityAmount == positionLiquidity) {
            nfpmContract.burn(tokenId);
            burned = true;
        } else {
            // Transfer NFT back to user
            nfpmContract.transferFrom(address(this), msg.sender, tokenId);
        }

        emit LiquidityRemoved(
            dexType,
            tokenId,
            liquidityAmount,
            collected0,
            collected1,
            burned
        );

        console.log("Liquidity removed successfully");
        console.log("Token ID:", tokenId);
        console.log("Liquidity removed:", liquidityAmount);
        console.log("Amount0 collected:", collected0);
        console.log("Amount1 collected:", collected1);
        console.log("NFT burned:", burned);

        return (collected0, collected1);
    }

    /// @notice Rebalance a position by removing liquidity, optionally swapping, and re-adding with new range
    /// @param dexType The DEX where the new position will be created
    /// @param tokenId The ID of the existing position to rebalance
    /// @param newTickLower The new lower tick for the position
    /// @param newTickUpper The new upper tick for the position
    /// @param swapTokenIn The token to swap from (address(0) if no swap)
    /// @param swapTokenOut The token to swap to (address(0) if no swap)
    /// @param swapAmount The amount to swap (0 if no swap)
    /// @param swapAmountOutMin Minimum amount to receive from swap
    /// @param swapFee The fee tier of the pool to use for swapping
    /// @return newTokenId The ID of the newly created position
    /// @return liquidity The amount of liquidity in the new position
    function rebalance(
        DexType dexType,
        uint256 tokenId,
        int24 newTickLower,
        int24 newTickUpper,
        address swapTokenIn,
        address swapTokenOut,
        uint256 swapAmount,
        uint256 swapAmountOutMin,
        uint24 swapFee
    ) external nonReentrant returns (uint256 newTokenId, uint128 liquidity) {
        // Get the NFPM for the existing position
        address oldNfpm = dexType == DexType.UNISWAP
            ? uniswapNFPM
            : pancakeswapNFPM;
        require(oldNfpm != address(0), "NFPM not set");

        INonfungiblePositionManager nfpmContract = INonfungiblePositionManager(
            oldNfpm
        );

        // Get position details
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            uint128 positionLiquidity,
            ,
            ,
            ,

        ) = nfpmContract.positions(tokenId);

        require(positionLiquidity > 0, "No liquidity in position");

        // Transfer NFT from user to this contract
        nfpmContract.transferFrom(msg.sender, address(this), tokenId);

        // Remove all liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory decreaseParams = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: positionLiquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        nfpmContract.decreaseLiquidity(decreaseParams);

        // Collect the tokens to this contract
        INonfungiblePositionManager.CollectParams
            memory collectParams = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (uint256 amount0, uint256 amount1) = nfpmContract.collect(
            collectParams
        );

        // Burn the old NFT
        nfpmContract.burn(tokenId);

        console.log("Removed liquidity from old position");
        console.log("Amount0:", amount0);
        console.log("Amount1:", amount1);

        // Perform swap if specified
        if (
            swapTokenIn != address(0) &&
            swapTokenOut != address(0) &&
            swapAmount > 0
        ) {
            // Use the opposite DEX for swapping
            DexType swapDex = dexType == DexType.UNISWAP
                ? DexType.PANCAKESWAP
                : DexType.UNISWAP;
            address router = swapDex == DexType.UNISWAP
                ? uniswapRouter
                : pancakeswapRouter;
            require(router != address(0), "Router not set");

            // Approve router to spend tokens
            IERC20(swapTokenIn).forceApprove(router, swapAmount);

            // Execute swap
            ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: swapTokenIn,
                    tokenOut: swapTokenOut,
                    fee: swapFee,
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: swapAmount,
                    amountOutMinimum: swapAmountOutMin,
                    sqrtPriceLimitX96: 0
                });

            uint256 amountOut = ISwapRouter(router).exactInputSingle(
                swapParams
            );

            // Update balances after swap
            if (swapTokenIn == token0) {
                amount0 -= swapAmount;
                amount1 += amountOut;
            } else {
                amount1 -= swapAmount;
                amount0 += amountOut;
            }

            emit TokensSwapped(
                swapDex,
                swapTokenIn,
                swapTokenOut,
                swapAmount,
                amountOut
            );

            console.log("Swapped tokens");
            console.log("Amount in:", swapAmount);
            console.log("Amount out:", amountOut);
        }

        // Re-add liquidity with new range
        IERC20(token0).forceApprove(oldNfpm, amount0);
        IERC20(token1).forceApprove(oldNfpm, amount1);

        INonfungiblePositionManager.MintParams
            memory mintParams = INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: newTickLower,
                tickUpper: newTickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: msg.sender,
                deadline: block.timestamp
            });

        uint256 amount0Used;
        uint256 amount1Used;
        (newTokenId, liquidity, amount0Used, amount1Used) = nfpmContract.mint(
            mintParams
        );

        // Refund any unused tokens to the user
        if (amount0 > amount0Used) {
            IERC20(token0).safeTransfer(msg.sender, amount0 - amount0Used);
        }
        if (amount1 > amount1Used) {
            IERC20(token1).safeTransfer(msg.sender, amount1 - amount1Used);
        }

        // Reset approvals
        IERC20(token0).forceApprove(oldNfpm, 0);
        IERC20(token1).forceApprove(oldNfpm, 0);

        emit PositionRebalanced(dexType, tokenId, newTokenId, liquidity);

        console.log("Rebalanced position successfully");
        console.log("Old Token ID:", tokenId);
        console.log("New Token ID:", newTokenId);
        console.log("New Liquidity:", liquidity);

        return (newTokenId, liquidity);
    }

    /// @notice withdraw function to retrieve any ERC20 tokens accidentally sent to this contract
    /// @param token The address of the ERC20 token to withdraw
    /// @param amount The amount of tokens to withdraw
    /// @param to The address to send the tokens to
    function withdraw(
        address token,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(to != address(0), "Invalid recipient");
        IERC20(token).safeTransfer(to, amount);
    }

    /// @notice ERC721 receiver implementation to accept NFT transfers
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
