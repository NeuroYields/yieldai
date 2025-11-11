# Quick Start: Deploy Yield Contract to BSC

## 1. Setup Environment

```bash
cd contracts

# Create .env file
cat > .env << EOF
PRIVATE_KEY=your_private_key_without_0x_prefix
BSC_RPC_URL=bsc
BSCSCAN_API_KEY=your_bscscan_api_key_optional
EOF

# Load environment
source .env
```

## 2. Deploy to BSC Mainnet

### With Contract Verification

```bash
forge script script/Yield.s.sol:DeployYield \
    --rpc-url bsc \
    --broadcast \
    --verify \
    --etherscan-api-key $BSCSCAN_API_KEY \
    -vvv
```

## 3. Test Deployment (Dry Run)

```bash
forge script script/Yield.s.sol:DeployYield \
    --rpc-url bsc \
    -vvv
```

## Verify Contract Later (if needed)

```bash
forge verify-contract \
    --chain-id 56 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)" \
        0x7b8A01B39D58278b5DE7e48c8449c9f4F5170613 \
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364 \
        0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2 \
        0x13f4EA83D0bd40E75C8222255bc855a974568Dd4) \
    --etherscan-api-key $BSCSCAN_API_KEY \
    --compiler-version v0.8.30+commit.e4e4901c \
    <DEPLOYED_CONTRACT_ADDRESS> \
    src/Yield.sol:Yield
```

## Check Deployment

```bash
# Check if contract is deployed
cast code <DEPLOYED_CONTRACT_ADDRESS> --rpc-url bsc

# Get owner
cast call <DEPLOYED_CONTRACT_ADDRESS> "owner()(address)" --rpc-url bsc

# Get Uniswap NFPM
cast call <DEPLOYED_CONTRACT_ADDRESS> "uniswapNFPM()(address)" --rpc-url bsc
```


current address = 0xbA276291a3EFE899b5B5fB2DFFd513B7347E11D7