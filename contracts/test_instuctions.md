# Yield Contract Testing Instructions

This guide explains how to run the Yield contract tests using Foundry's fork testing on BNB Chain.

## Prerequisites

1. **Foundry installed** - Make sure you have Foundry installed
2. **BNB Chain RPC URL** - You need access to a BNB Chain RPC endpoint

## Getting a BNB Chain RPC URL

You can get a free RPC URL from:
- **Public RPC**: `https://bsc-dataseed.binance.org/` (rate-limited)

## Running the Tests

### Option 1: Using Command Line RPC URL

Run all tests with fork:
```bash
forge test --fork-url https://bsc-dataseed.binance.org/ -vvv
```

Run specific test:
```bash
forge test --fork-url https://bsc-dataseed.binance.org/ --match-test test_GetPoolDetails_UniswapV3 -vvv
```

Run tests for specific contract:
```bash
forge test --fork-url https://bsc-dataseed.binance.org/ --match-contract YieldTest -vvv
```

### Option 2: Using Environment Variable

Set the RPC URL as an environment variable:
```bash
export BSC_RPC_URL="https://bsc-dataseed.binance.org/"
forge test --fork-url $BSC_RPC_URL -vvv
```

### Option 3: Using .env File (Recommended)

1. Create a `.env` file in the `contracts` directory:
```bash
BSC_RPC_URL=https://bsc-dataseed.binance.org/
# Or use your premium RPC provider
# BSC_RPC_URL=https://your-premium-rpc-url.com/your-api-key
```

2. Update `foundry.toml` to use the environment variable:
```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
bsc = "${BSC_RPC_URL}"
```

3. Run tests:
```bash
forge test --fork-url bsc -vvv
```

## Test Verbosity Levels

- `-v`: Show test results
- `-vv`: Show test results + logs
- `-vvv`: Show test results + logs + stack traces
- `-vvvv`: Show test results + logs + stack traces + setup traces
- `-vvvvv`: Show everything including storage changes

### Run tests matching a pattern:
```bash
forge test --fork-url $BSC_RPC_URL --match-test test_GetPoolDetails -vvv
```

### Run tests with gas reporting:
```bash
forge test --fork-url $BSC_RPC_URL --gas-report -vvv
```