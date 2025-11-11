// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Yield} from "../src/Yield.sol";

contract DeployYield is Script {
    // NonfungiblePositionManager addresses on BNB Chain
    address constant UNISWAP_NFPM = 0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613;
    address constant PANCAKESWAP_NFPM = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;

    // Router addresses on BNB Chain
    address constant UNISWAP_ROUTER = 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2; // Uniswap V3 SwapRouter
    address constant PANCAKESWAP_ROUTER = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4; // PancakeSwap V3 SmartRouter

    function run() external {
        // Get the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Yield contract...");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        
        // Deploy the Yield contract
        Yield yieldContract = new Yield(
            UNISWAP_NFPM,
            PANCAKESWAP_NFPM,
            UNISWAP_ROUTER,
            PANCAKESWAP_ROUTER
        );

        console.log("Yield contract deployed at:", address(yieldContract));
        console.log("");
        console.log("=== Deployment Summary ===");
        console.log("Yield Contract:", address(yieldContract));
        console.log("Uniswap NFPM:", UNISWAP_NFPM);
        console.log("PancakeSwap NFPM:", PANCAKESWAP_NFPM);
        console.log("Uniswap Router:", UNISWAP_ROUTER);
        console.log("PancakeSwap Router:", PANCAKESWAP_ROUTER);
        console.log("Owner:", vm.addr(deployerPrivateKey));

        vm.stopBroadcast();
    }
}

