use std::fs;

use once_cell::sync::Lazy;
use serde::Deserialize;

use crate::types::{DexType, lowercase_address};

#[derive(Debug, Deserialize, Clone)]
pub struct TomlConfig {
    pub chain: ChainConfig,
    pub pools: Vec<PoolConfig>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct ChainConfig {
    pub rpc_url: String,
    pub chain_id: u64,
}

#[derive(Debug, Deserialize, Clone)]
pub struct PoolConfig {
    #[serde(deserialize_with = "lowercase_address")]
    pub address: String,
    pub dex_type: DexType,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub contract_address: String,
    pub private_key: String,
    pub port: u16,
    pub toml: TomlConfig,
}

impl Config {
    pub fn load() -> Self {
        let contract_address =
            std::env::var("CONTRACT_ADDRESS").expect("CONTRACT_ADDRESS must be set");
        let private_key = std::env::var("PRIVATE_KEY").expect("PRIVATE_KEY must be set");
        let port: u16 = std::env::var("PORT")
            .unwrap_or_else(|_| "8080".to_string())
            .parse()
            .expect("PORT must be a valid u16 number");

        let path = "src/config/bnb.toml";

        // Read the toml configuration
        let data = fs::read_to_string(path).expect("Unable to read config file");

        let config: TomlConfig = toml::from_str(&data).expect("Unable to parse config file");

        Self {
            contract_address,
            private_key,
            port,
            toml: config,
        }
    }
}

// Define a globally accessible static Config instance
pub static CONFIG: Lazy<Config> = Lazy::new(Config::load);

// CONSTANTS
pub const FEE_FACTOR: f64 = 10_000.0;