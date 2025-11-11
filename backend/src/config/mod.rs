use once_cell::sync::Lazy;

#[derive(Debug, Clone)]
pub struct Config {
    pub contract_address: String,
    pub port: u16,
}

impl Config {
    pub fn load() -> Self {
        let contract_address =
            std::env::var("CONTRACT_ADDRESS").expect("CONTRACT_ADDRESS must be set");
        let port: u16 = std::env::var("PORT")
            .unwrap_or_else(|_| "8080".to_string())
            .parse()
            .expect("PORT must be a valid u16 number");

        Self {
            contract_address,
            port,
        }
    }
}

// Define a globally accessible static Config instance
pub static CONFIG: Lazy<Config> = Lazy::new(Config::load);


