use dashmap::DashMap;
use tracing::info;

use crate::{
    core,
    types::{EvmProvider, Pool},
};

#[derive(Clone, Debug)]
pub struct AppState {
    pub evm_provider: EvmProvider,
    pub pools: DashMap<String, Pool>,
}

impl AppState {
    pub async fn new() -> Self {
        let evm_provider = core::init::init_evm_provider()
            .await
            .expect("Failed to initialize EVM provider");
        let pools = core::init::init_pools_state(&evm_provider)
            .await
            .expect("Failed to initialize pools state");

        info!("Pools state initialized: {:?}", pools);

        Self {
            evm_provider,
            pools,
        }
    }
}
