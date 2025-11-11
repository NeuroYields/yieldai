use crate::{core, types::EvmProvider};

#[derive(Clone, Debug)]
pub struct AppState {
    pub evm_provider: EvmProvider,
}

impl AppState {
    pub async fn new() -> Self {
        let evm_provider = core::init::init_evm_provider()
            .await
            .expect("Failed to initialize EVM provider");

        Self { evm_provider }
    }
}
