use anyhow::Result;

/// Convert a tick to a price.
/// It caclulate the price1 which the price of token1 per token0
pub fn tick_to_price(tick: i32, token0_decimals: u8, token1_decimals: u8) -> Result<f64> {
    let price_tick = 1.0001f64.powi(tick as i32);

    let diff_decimals = token1_decimals as i8 - token0_decimals as i8;

    let price = price_tick / 10f64.powi(diff_decimals as i32);

    Ok(price)
}
