use actix_web::{HttpResponse, Responder, get, post, web};

use crate::{
    core::{self, coingecko::CoingeckoOhlcvRes},
    state::AppState,
    types::Pool,
};

#[utoipa::path(
        responses(
            (status = 200, description = "Home page", body = String),
        )
    )]
#[get("/")]
async fn get_index_service() -> impl Responder {
    HttpResponse::Ok().body("UP")
}

#[utoipa::path(
    responses(
        (status = 200, description = "Health check", body = String),
    )
)]
#[get("/health")]
async fn get_health_service() -> impl Responder {
    HttpResponse::Ok().body("ok")
}

#[utoipa::path(
    responses(
        (status = 200, description = "Pools", body = Vec<Pool>),
    )
)]
#[get("/pools")]
async fn get_pools_service(app_state: web::Data<AppState>) -> impl Responder {
    let pools_map = &app_state.pools;
    let pools: Vec<Pool> = pools_map
        .iter()
        .map(|entry| entry.value().clone())
        .collect();
    HttpResponse::Ok().json(pools)
}

#[utoipa::path(
    responses(
        (status = 200, description = "Pool", body = CoingeckoOhlcvRes),
    )
)]
#[get("/pool/{pool_address}/coingecko/ohlcv")]
async fn get_pool_coingecko_ohlcv_service(pool_address: web::Path<String>) -> impl Responder {
    let pool_address = pool_address.into_inner();

    let ohlcv_data_result = match core::coingecko::get_pool_ohlcv_data(&pool_address).await {
        Ok(data) => data,
        Err(err) => {
            return HttpResponse::InternalServerError()
                .body(format!("Error fetching OHLCV data: {}", err));
        }
    };

    HttpResponse::Ok().json(ohlcv_data_result)
}
