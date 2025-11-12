use actix_web::{HttpResponse, Responder, get, post, web};

use crate::{state::AppState, types::Pool};

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
