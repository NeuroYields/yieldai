use dashmap::DashMap;
use rig::{agent::Agent, providers::gemini::completion::CompletionModel};
use tracing::info;

use crate::{
    core::{self, init::init_ai_agent},
    types::{EvmProvider, Pool},
};

#[derive(Clone)]
pub struct AppState {
    pub evm_provider: EvmProvider,
    pub pools: DashMap<String, Pool>,
    pub ai_agent: Agent<CompletionModel>,
}

impl AppState {
    pub async fn new() -> Self {
        // Initialize the AI agent
        let ai_agent = init_ai_agent()
            .await
            .expect("Failed to initialize AI agent");

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
            ai_agent,
        }
    }
}
