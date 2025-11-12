use std::str::FromStr;
use std::sync::Arc;
use std::time::Instant;

use alloy::{providers::ProviderBuilder, signers::local::PrivateKeySigner};
use anyhow::Result;
use dashmap::DashMap;
use futures::stream::{self, StreamExt, TryStreamExt};
use rig::{agent::Agent, client::CompletionClient, providers::gemini::{self, completion::{CompletionModel, gemini_api_types::{AdditionalParameters, GenerationConfig}}}};
use tokio::sync::Semaphore;
use tracing::{debug, info};

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

/// Initialize the pools state by concurrently fetching all pools defined in the toml file
///
/// This function fetches blockchain data for multiple pools in parallel to improve performance.
/// Instead of fetching pools one-by-one (which would be slow), we fetch multiple pools at the
/// same time, but we limit how many can run simultaneously to avoid overwhelming the RPC server.
///
/// # How it works:
/// 1. Creates a shared thread-safe HashMap (DashMap) to store pool data
/// 2. Uses a Semaphore to limit concurrent requests (like a bouncer at a club - only N people allowed in)
/// 3. Spawns async tasks for each pool that need to be fetched
/// 4. Each task waits for a "permit" from the semaphore before making the RPC call
/// 5. Collects all results and returns the populated DashMap
///
/// # Arguments:
/// * `evm_provider` - A reference to the blockchain provider used to make RPC calls
///
/// # Returns:
/// * `Result<DashMap<String, Pool>>` - A thread-safe HashMap containing all pool data, or an error
pub async fn init_pools_state(evm_provider: &EvmProvider) -> Result<DashMap<String, Pool>> {
    // ============================================================================
    // STEP 1: Setup - Prepare timing and logging
    // ============================================================================

    // Record the start time so we can measure how long initialization takes
    let start_time = Instant::now();

    // Get the total number of pools we need to fetch
    let pool_count = CONFIG.toml.pools.len();

    // Log that we're starting the initialization process
    info!(
        "Starting concurrent pool initialization for {} pools with max {} concurrent tasks",
        pool_count,
        crate::config::MAX_ALLOWED_THREADS
    );

    // ============================================================================
    // STEP 2: Create shared data structures
    // ============================================================================

    // Arc = "Atomic Reference Counted" - allows multiple async tasks to safely share ownership
    // DashMap = A concurrent HashMap that can be safely accessed from multiple threads
    // Think of Arc as a "shared ownership wrapper" - multiple tasks can hold a reference to the same data
    let pools = Arc::new(DashMap::new());

    // Create a semaphore to limit how many tasks can run at the same time
    // Semaphore = A counter that controls access to a resource
    // Example: If MAX_ALLOWED_THREADS = 8, only 8 tasks can fetch data at once
    // When a task finishes, it releases its "permit" and another task can start
    let semaphore = Arc::new(Semaphore::new(crate::config::MAX_ALLOWED_THREADS));

    // ============================================================================
    // STEP 3: Create a stream of concurrent tasks
    // ============================================================================

    // stream::iter() - Converts the pool configs into a stream (like an iterator but for async)
    // .map() - Transforms each pool config into an async task
    let fetch_tasks = stream::iter(CONFIG.toml.pools.iter())
        .map(|pool_config| {
            // Clone the Arc pointers so each async task has its own reference
            // This is cheap - we're not copying the data, just incrementing a reference counter
            let pools = Arc::clone(&pools);
            let semaphore = Arc::clone(&semaphore);

            // Clone the pool data we need for this specific task
            // We need to clone because the async block needs to own this data
            let address = pool_config.address.clone();
            let dex_type = pool_config.dex_type.clone();

            // Create an async block that will fetch data for ONE pool
            // "async move" means this block takes ownership of the cloned variables above
            async move {
                // ----------------------------------------------------------------
                // STEP 3a: Acquire a semaphore permit (rate limiting)
                // ----------------------------------------------------------------

                // Try to acquire a permit from the semaphore
                // If all permits are taken, this will wait until one becomes available
                // The underscore prefix (_permit) tells Rust we won't use this variable directly
                // But we need to keep it alive - when it's dropped, the permit is automatically released
                let _permit = semaphore
                    .acquire()
                    .await
                    .map_err(|e| anyhow::anyhow!("Failed to acquire semaphore permit: {}", e))?;

                debug!("Fetching pool data for address: {}", address);

                // ----------------------------------------------------------------
                // STEP 3b: Fetch the pool data from the blockchain
                // ----------------------------------------------------------------

                // Make the actual RPC call to fetch pool details
                // This is the slow I/O operation we're trying to parallelize
                let result =
                    core::pools::fetch_pool_blockchain_details(evm_provider, &address, &dex_type)
                        .await;

                // ----------------------------------------------------------------
                // STEP 3c: Handle the result and store in DashMap
                // ----------------------------------------------------------------

                // Check if the fetch was successful
                match result {
                    Ok(pool_details) => {
                        // Success! Insert the pool data into our shared DashMap
                        // DashMap handles thread-safety internally, so this is safe
                        pools.insert(address.clone(), pool_details);
                        debug!("Successfully fetched and stored pool: {}", address);
                        Ok(())
                    }
                    Err(e) => {
                        // If there was an error, propagate it up
                        // This will cause the entire initialization to fail
                        Err(e)
                    }
                }

                // When this async block ends, _permit is dropped and the semaphore
                // permit is automatically released, allowing another task to start
            }
        })
        // buffer_unordered() - Run up to N tasks concurrently and collect results as they complete
        // The "unordered" part means we don't care what order the results come back in
        .buffer_unordered(crate::config::MAX_ALLOWED_THREADS);

    // ============================================================================
    // STEP 4: Wait for all tasks to complete and check for errors
    // ============================================================================

    // PERFORMANCE NOTE: We use try_collect() instead of collect() + loop
    //
    // Why this is efficient:
    // - try_collect() stops immediately on the first error (short-circuits)
    // - No intermediate Vec allocation needed
    // - The compiler can optimize this better than a manual loop
    // - Time complexity: O(1) if error occurs early, O(n) worst case (same as loop)
    fetch_tasks.try_collect::<Vec<()>>().await?;

    // ============================================================================
    // STEP 6: Log success metrics
    // ============================================================================

    // Calculate how long the entire process took
    let elapsed = start_time.elapsed();

    // Log performance metrics
    info!(
        "Successfully initialized {} pools in {:.2}s (avg {:.2}ms per pool)",
        pool_count,
        elapsed.as_secs_f64(),
        elapsed.as_millis() as f64 / pool_count as f64
    );

    // ============================================================================
    // STEP 7: Extract and return the DashMap
    // ============================================================================

    // Arc::try_unwrap() attempts to extract the inner value from the Arc
    // This only works if there's exactly ONE reference left (which there should be)
    // If there are still other references, this returns an Err with the Arc back
    // .map_err() converts that error into an anyhow error with a helpful message
    Arc::try_unwrap(pools).map_err(|_| {
        anyhow::anyhow!("Failed to unwrap Arc<DashMap> - there are still active references")
    })
}


/// Initialize the AI agent using the Google Gemini provider
pub async fn init_ai_agent() -> Result<Agent<CompletionModel>> {
    // Initialize the Google Gemini client
    let client = gemini::Client::from_env();

    let gen_cfg = GenerationConfig {
        ..Default::default()
    };

    let cfg = AdditionalParameters::default().with_config(gen_cfg);

    // Create agent with a single context prompt
    let agent = client
        .agent("gemini-flash-latest")
        .preamble("You are a liquidity manager AI assistant. Your goal is to help users optimize their Liquidity provision strategies on  uniswap V3 pools on EVM-compatible blockchains by suggesting the best price range to provide liquidity based on current market conditions and historical data (data will be provided to you on the prompt by coingecko).")
        .temperature(0.0)
        .additional_params(serde_json::to_value(cfg)?) 
        .build();

    tracing::info!("AI Agent initialized successfully.");

    Ok(agent)
}
