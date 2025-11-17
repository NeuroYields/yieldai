pub mod amm_math;

pub fn extract_json_from_markdown(md: &str) -> String {
    let json_block = md.replace("```json", "").replace("```", "");
    json_block.trim().to_string()
}
