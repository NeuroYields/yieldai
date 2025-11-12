use std::str::FromStr;

use alloy::{providers::ProviderBuilder, signers::local::PrivateKeySigner};
use anyhow::Result;
use dashmap::DashMap;

use crate::{
    config::CONFIG,
    core,
    types::{EvmProvider, Pool},
};

/// Initialize the EVM provider using the configuration of the toml file and .env
pub async fn init_evm_provider() -> Result<EvmProvider> {
    let private_key = CONFIG.private_key.as_str();
    let chain_id = CONFIG.toml.chain.chain_id;
    let rpc_url = CONFIG.toml.chain.rpc_url.as_str();

    let evm_signer = PrivateKeySigner::from_str(private_key)?;

    // Init provider with the specified rpc url in config
    let evm_provider = ProviderBuilder::new()
        .with_chain_id(chain_id)
        .wallet(evm_signer)
        .connect(rpc_url)
        .await?;

    Ok(evm_provider)
}

/// Initialize the pools state by looping on all pools defined in the toml file and fetching their blockchain details
pub async fn init_pools_state() -> Result<DashMap<String, Pool>> {
    let pools = DashMap::new();

    for pool_config in CONFIG.toml.pools.iter() {
        let pool_details =
            core::pools::fetch_pool_blockchain_details(&pool_config.address, &pool_config.dex_type).await?;

        pools.insert(pool_config.address.clone(), pool_details);
    }

    Ok(pools)
}
