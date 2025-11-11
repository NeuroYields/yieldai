use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
#[serde(rename_all = "PascalCase")]
pub enum DexType {
    UniswapV3,
    PancakeSwapV3,
}

/// Custom deserializer that converts to lowercase
/// 'de is rust lifetime standard for deserialization
pub fn lowercase_address<'de, D>(deserializer: D) -> Result<String, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let s: String = Deserialize::deserialize(deserializer)?;
    Ok(s.to_lowercase())
}
