use std::str::FromStr;

use alloy::primitives::Address;
use alloy::sol;
use anyhow::Result;

use crate::config::CONFIG;
use crate::config::FEE_FACTOR;
use crate::types::DexType;
use crate::types::EvmProvider;
use crate::types::Pool;
use crate::types::Token;

sol!(
    #[derive(Debug)]
    #[sol(rpc)]
    Yield,
    "./src/yield_abi.json",
);

pub async fn fetch_pool_blockchain_details(
    evm_provider: &EvmProvider,
    pool_address: &str,
    dex_type: &DexType,
) -> Result<Pool> {
    let contract_address = Address::from_str(&CONFIG.contract_address)?;
    let pool_address = Address::from_str(pool_address)?;

    let yield_contract = Yield::new(contract_address, evm_provider);

    let pool_details: Yield::PoolDetails =
        yield_contract.getPoolDetails(pool_address).call().await?;

    // Descale fee value
    let fee_scaled: f64 = pool_details.fee.into();
    let fee = fee_scaled / FEE_FACTOR;

    Ok(Pool {
        address: pool_address.to_string(),
        dex_type: dex_type.clone(),
        token0: Token {
            address: pool_details.token0.to_string(),
            symbol: pool_details.token0Symbol,
            decimals: pool_details.token0Decimals,
        },
        token1: Token {
            address: pool_details.token1.to_string(),
            symbol: pool_details.token1Symbol,
            decimals: pool_details.token1Decimals,
        },
        fee,
        tick_spacing: pool_details.tickSpacing.as_i32(),
        current_tick: pool_details.currentTick.as_i32(),
        price0: 0.0, // Placeholder, implement price calculation logic
        price1: 0.0, // Placeholder, implement price calculation logic
    })
}
