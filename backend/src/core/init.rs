use std::str::FromStr;

use alloy::{providers::ProviderBuilder, signers::local::PrivateKeySigner};
use anyhow::Result;

use crate::{config::CONFIG, types::EvmProvider};

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
