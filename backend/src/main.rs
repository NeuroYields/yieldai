use actix_web::{App, HttpServer};
use tracing::{error, info};
use tracing_subscriber::{EnvFilter, fmt, layer::SubscriberExt, util::SubscriberInitExt};

use crate::config::CONFIG;

mod config;

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Load .env file
    dotenvy::dotenv().ok();

    // Initialize the logger logic
    let file_appender = tracing_appender::rolling::daily("./logs", "yieldai.log");
    let (file_writer, _guard) = tracing_appender::non_blocking(file_appender);

    // Console writer (stdout)
    let console_layer = fmt::layer().pretty(); // Optional: makes console output prettier

    // File layer
    let file_layer = fmt::layer().with_writer(file_writer).with_ansi(false); // don't add colors to the file logs

    // 🔥 Only accept logs that match your crate
    let filter = EnvFilter::new("yieldai=trace");

    // Combine both
    tracing_subscriber::registry()
        .with(filter)
        .with(console_layer)
        .with(file_layer)
        .init();

    info!("Logger initialized Successfully");

    info!("Starting HTTP server at http://localhost:{}", CONFIG.port);

    HttpServer::new(move || App::new())
        .bind(("127.0.0.1", CONFIG.port))?
        .run()
        .await
}
