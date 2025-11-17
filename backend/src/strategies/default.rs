use actix_web::web;
use anyhow::Result;
use rig::completion::Prompt;
use serde::{Deserialize, Serialize};

use crate::{
    core::coingecko,
    state::AppState,
    types::{RangeSuggestion, StrategyType},
    utils::extract_json_from_markdown,
};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct AIResponse {
    pub low_price: f64,
    pub upper_price: f64,
    pub confidence: f64,
    pub reason: String,
}

pub async fn suggest_liquidity_range(
    app_state: &web::Data<AppState>,
    pool_address: &str,
) -> Result<RangeSuggestion> {
    let ai_agent = &app_state.ai_agent;

    // Fetch coingecko data for the pool
    let coingecko_ohlcv_data = coingecko::get_pool_ohlcv_data(pool_address).await?;

    // Use the AI agent to analyze data and suggest a price range
    let analysis_prompt = format!(
        "Analyze the following OHLCV data and suggest a liquidity range for this pool '{}' based on its history and current market conditions.Identify the general trend, volatility, and any significant events that may have impacted the pool's price. I want teh raneg to be the optimal one to earn more yields in less time but if market are not good use maybe a wider oen for safety. Return the lower price and the upper price, the reason for the suggestion and the confidence level. The reason field should be very explainatory about the decision you've maked. Return only Json object that respect this Schema: {{\"low_price\": number, \"upper_price\": number, \"confidence\": number, \"reason\": string}}. Tis is the coingecko pool history data: {:?}",
        pool_address, coingecko_ohlcv_data
    );

    tracing::debug!("Prompt sent to AI agent...");

    let ai_response_str = ai_agent.prompt(analysis_prompt).await?;

    tracing::info!("AI Response: {:?}", ai_response_str);

    let formatted_md_response = extract_json_from_markdown(&ai_response_str);

    let ai_response: AIResponse = serde_json::from_str(&formatted_md_response)?;

    tracing::info!("AI Response: {:?}", ai_response);

    Ok(RangeSuggestion {
        up_price: ai_response.upper_price,
        down_price: ai_response.low_price,
        confidence: ai_response.confidence,
        reason: ai_response.reason,
        strategy: StrategyType::Default,
    })
}
