use anyhow::Result;
use reqwest::header::{ACCEPT, HeaderMap, HeaderValue};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use tracing::info;
use utoipa::ToSchema;

use crate::{
    config::{CONFIG},
};

#[derive(Clone, Debug, Serialize, Deserialize, ToSchema)]
pub struct CoingeckoOhlcvRes {
    pub data: CoingeckoResData,
}

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct CoingeckoResData {
    pub id: String,
    pub attributes: CoingeckoResDataAttributes,
}

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct CoingeckoResDataAttributes {
    pub ohlcv_list: Vec<OhlcvEntry>,
}

#[derive(Debug, Serialize, Deserialize, Clone, ToSchema)]
pub struct OhlcvEntry(
    i64, // timestamp (UNIX)
    f64, // open
    f64, // high
    f64, // low
    f64, // close
    f64, // volume
);

pub async fn get_pool_ohlcv_data(pool_address: &str) -> Result<CoingeckoOhlcvRes> {
    let url = format!(
        "https://api.coingecko.com/api/v3/onchain/networks/{}/pools/{}/ohlcv/day?token=base&currency=token&limit=1000",
        CONFIG.toml.chain.coingecko_id, pool_address
    );

    let coingecko_api_key = &CONFIG.coingecko_api_key;

    // Set up headers
    let mut headers = HeaderMap::new();

    headers.insert(ACCEPT, HeaderValue::from_static("application/json"));
    headers.insert(
        "x-cg-demo-api-key",
        HeaderValue::from_str(&coingecko_api_key)?,
    );

    // Make request
    let client = reqwest::Client::new();

    let response = client.get(url).headers(headers).send().await?;

    let ohlcv_data_res: Value = response.json().await?;

    let ohlcv_data: CoingeckoOhlcvRes = serde_json::from_value(ohlcv_data_res)?;

    info!(
        "Coingecko data fetched successfully: {:?}",
        ohlcv_data.data.attributes.ohlcv_list.len()
    );

    Ok(ohlcv_data)
}
