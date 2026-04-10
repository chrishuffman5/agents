# Rust Web Frameworks -- Architecture Reference

## Axum

Axum is maintained by the Tokio project. It is intentionally thin: routing and extractor machinery live in `axum`, everything else comes from Tower or external crates. This keeps the API surface small and the upgrade story predictable.

### Tower Foundation

Every Axum handler ultimately becomes a `tower::Service`. You can compose, wrap, and test handlers using any Tower-compatible middleware.

```rust
use tower::Service;
use axum::{Router, routing::get};

// Router itself implements Service<Request>
let app: Router = Router::new().route("/", get(root_handler));
```

`Layer` wraps a service to produce a new service:

```rust
use tower_http::trace::TraceLayer;

let app = Router::new()
    .route("/", get(root_handler))
    .layer(TraceLayer::new_for_http());
```

### Router

```rust
use axum::{Router, routing::{get, post, put, delete}};

let users_router = Router::new()
    .route("/", get(list_users).post(create_user));

// Nested routing
let api = Router::new()
    .nest("/users", users_router)
    .nest("/orders", orders_router());

// Fallback for unmatched routes
let app = Router::new()
    .nest("/api/v1", api)
    .fallback(handler_404);
```

### Handlers -- Async Functions as Handlers

Any async function whose arguments implement `FromRequestParts` (or `FromRequest`) and whose return type implements `IntoResponse` is a valid handler. No trait bounds appear in function signatures.

```rust
use axum::{
    extract::{Path, Query, State, Json},
    response::IntoResponse,
    http::StatusCode,
};

#[derive(Deserialize)]
struct Pagination {
    page: Option<u32>,
    per_page: Option<u32>,
}

async fn get_user(
    State(state): State<Arc<AppState>>,
    Path(user_id): Path<u64>,
    Query(pagination): Query<Pagination>,
) -> impl IntoResponse {
    // Extractors resolve left-to-right; errors short-circuit to 400/422
    match state.db.find_user(user_id).await {
        Ok(user) => (StatusCode::OK, Json(user)).into_response(),
        Err(_)   => StatusCode::NOT_FOUND.into_response(),
    }
}
```

### Extractors

| Extractor | Source | Notes |
|---|---|---|
| `Path<T>` | URL segment | `T: Deserialize` |
| `Query<T>` | Query string | `T: Deserialize`, missing key -> 400 |
| `Json<T>` | Body | Consumes body; must be last |
| `State<T>` | App state | `T: Clone + Send + Sync + 'static` |
| `Extension<T>` | Request extensions | Inserted by middleware |
| `TypedHeader<H>` | HTTP header | Via `axum-extra` |
| `Form<T>` | URL-encoded body | `T: Deserialize` |
| `Bytes` | Raw body | Full body bytes |
| `Request` | Whole request | Escape hatch |

#### Custom Extractor

```rust
use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};

struct AuthUser {
    id: u64,
    role: String,
}

#[async_trait]
impl<S> FromRequestParts<S> for AuthUser
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let token = parts
            .headers
            .get("Authorization")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.strip_prefix("Bearer "))
            .ok_or((StatusCode::UNAUTHORIZED, "Missing bearer token"))?;

        validate_token(token)
            .map_err(|_| (StatusCode::UNAUTHORIZED, "Invalid token"))
    }
}
```

### Response Types

`IntoResponse` converts a value into `Response<Body>`. Many types implement it:

```rust
// Tuple: (StatusCode, Json<T>) -> response with status + JSON body
async fn create_item(Json(payload): Json<NewItem>) -> impl IntoResponse {
    (StatusCode::CREATED, Json(Item { id: 1, ..payload }))
}

// Custom response
async fn download_file() -> Response {
    Response::builder()
        .status(200)
        .header("Content-Type", "application/octet-stream")
        .body(Body::from(b"file bytes" as &[u8]))
        .unwrap()
}
```

### Middleware

#### Function Middleware (Simplest)

```rust
use axum::{middleware::{self, Next}, extract::Request, response::Response};

async fn require_auth(
    State(state): State<Arc<AppState>>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let token = request.headers().get("Authorization")
        .ok_or(StatusCode::UNAUTHORIZED)?;
    validate_token(token, &state).await?;
    Ok(next.run(request).await)
}

let app = Router::new()
    .route("/protected", get(protected_handler))
    .route_layer(middleware::from_fn_with_state(state.clone(), require_auth));
```

#### Tower Layer Middleware (Reusable)

```rust
use tower_http::{
    cors::{CorsLayer, Any},
    compression::CompressionLayer,
    timeout::TimeoutLayer,
};

let app = Router::new()
    .nest("/api", api_router)
    .layer(
        tower::ServiceBuilder::new()
            .layer(TimeoutLayer::new(Duration::from_secs(30)))
            .layer(CompressionLayer::new())
            .layer(CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any))
            .layer(TraceLayer::new_for_http()),
    );
```

### Error Handling

The idiomatic pattern is a custom `AppError` type implementing `IntoResponse`:

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Validation error: {0}")]
    Validation(String),
    #[error("Database error")]
    Database(#[from] sqlx::Error),
    #[error("Unauthorized")]
    Unauthorized,
    #[error("Internal error")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::NotFound(msg)   => (StatusCode::NOT_FOUND, msg.clone()),
            AppError::Validation(msg) => (StatusCode::UNPROCESSABLE_ENTITY, msg.clone()),
            AppError::Database(_)     => (StatusCode::INTERNAL_SERVER_ERROR, "Database error".into()),
            AppError::Unauthorized    => (StatusCode::UNAUTHORIZED, "Unauthorized".into()),
            AppError::Internal(_)     => (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into()),
        };
        tracing::error!(error = ?self, "Request error");
        (status, Json(json!({"error": message}))).into_response()
    }
}

// Handler returning Result<T, AppError>
async fn get_user(
    State(db): State<Arc<DbPool>>,
    Path(id): Path<u64>,
) -> Result<Json<User>, AppError> {
    let user = db.find_user(id).await
        .map_err(AppError::Database)?
        .ok_or_else(|| AppError::NotFound(format!("User {id}")))?;
    Ok(Json(user))
}
```

### State Management

```rust
#[derive(Clone)]
struct AppState {
    db: PgPool,
    config: Arc<Config>,
    cache: Arc<RwLock<HashMap<String, String>>>,
}

#[tokio::main]
async fn main() {
    let pool = PgPool::connect(&std::env::var("DATABASE_URL").unwrap()).await.unwrap();
    let state = Arc::new(AppState {
        db: pool,
        config: Arc::new(Config::from_env()),
        cache: Arc::new(RwLock::new(HashMap::new())),
    });

    let app = Router::new()
        .route("/users/:id", get(get_user))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
```

### Nested Routers and Fallback

```rust
fn orders_router() -> Router<Arc<AppState>> {
    Router::new()
        .route("/", get(list_orders).post(create_order))
        .route("/:id", get(get_order).put(update_order).delete(delete_order))
        .route("/:id/items", get(list_order_items))
}

let app = Router::new()
    .nest("/api/v1/users", users_router())
    .nest("/api/v1/orders", orders_router())
    .fallback(|| async { (StatusCode::NOT_FOUND, "Not found") });
```

### WebSocket Support

```rust
use axum::extract::ws::{WebSocket, WebSocketUpgrade, Message};

async fn ws_handler(
    ws: WebSocketUpgrade,
    State(state): State<Arc<AppState>>,
) -> impl IntoResponse {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

async fn handle_socket(mut socket: WebSocket, state: Arc<AppState>) {
    while let Some(Ok(msg)) = socket.recv().await {
        match msg {
            Message::Text(text) => {
                if socket.send(Message::Text(format!("echo: {text}"))).await.is_err() {
                    break;
                }
            }
            Message::Close(_) => break,
            _ => {}
        }
    }
}
```

### Server-Sent Events (SSE)

```rust
use axum::response::sse::{Event, Sse};
use futures::stream::{self, Stream};
use tokio_stream::StreamExt as _;

async fn sse_handler() -> Sse<impl Stream<Item = Result<Event, std::convert::Infallible>>> {
    let stream = stream::repeat_with(|| {
        Event::default().data(format!("tick at {:?}", std::time::SystemTime::now()))
    })
    .map(Ok)
    .throttle(Duration::from_secs(1));

    Sse::new(stream).keep_alive(
        axum::response::sse::KeepAlive::new()
            .interval(Duration::from_secs(15))
            .text("keep-alive"),
    )
}
```

### Testing Axum

```rust
use axum::{body::Body, http::{Request, StatusCode}};
use tower::ServiceExt;
use http_body_util::BodyExt;

#[tokio::test]
async fn test_get_user() {
    let app = app_with_test_state();

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/users/1")
                .header("Authorization", "Bearer test-token")
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    assert_eq!(response.status(), StatusCode::OK);

    let body = response.into_body().collect().await.unwrap().to_bytes();
    let user: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(user["id"], 1);
}
```

---

## Actix Web

Actix Web 4.x runs on Tokio but retains the Actix actor runtime for WebSocket handling and background actors. Its `App` builder pattern provides a different ergonomic feel from Axum's functional composition.

### Actor System and Runtime

Actix Web's `HttpServer` spawns one worker per CPU core, each running its own single-threaded Tokio runtime. The `actix` crate provides actors (`Actor` trait, `Addr<A>`) for managing stateful concurrent processes.

```rust
use actix::prelude::*;

struct Counter { count: u64 }
impl Actor for Counter { type Context = Context<Self>; }

#[derive(Message)]
#[rtype(result = "u64")]
struct Increment;

impl Handler<Increment> for Counter {
    type Result = u64;
    fn handle(&mut self, _: Increment, _: &mut Context<Self>) -> u64 {
        self.count += 1;
        self.count
    }
}
```

### App Builder

```rust
use actix_web::{web, App, HttpServer, middleware};

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let pool = create_pool().await;

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .wrap(middleware::Logger::default())
            .wrap(middleware::Compress::default())
            .service(
                web::scope("/api/v1")
                    .service(users_scope())
                    .service(orders_scope()),
            )
    })
    .bind("0.0.0.0:8080")?
    .workers(4)
    .run()
    .await
}

fn users_scope() -> actix_web::Scope {
    web::scope("/users")
        .route("", web::get().to(list_users))
        .route("", web::post().to(create_user))
        .route("/{id}", web::get().to(get_user))
        .route("/{id}", web::put().to(update_user))
        .route("/{id}", web::delete().to(delete_user))
}
```

### Extractors

```rust
use actix_web::{web, HttpRequest, HttpResponse, Result};

#[derive(Deserialize)]
struct UserPath { id: u64 }

#[derive(Deserialize)]
struct UserQuery { include_deleted: Option<bool> }

async fn get_user(
    req: HttpRequest,
    path: web::Path<UserPath>,
    query: web::Query<UserQuery>,
    db: web::Data<DbPool>,
) -> Result<HttpResponse> {
    let user = db.find_user(path.id).await
        .map_err(actix_web::error::ErrorInternalServerError)?
        .ok_or_else(|| actix_web::error::ErrorNotFound("User not found"))?;
    Ok(HttpResponse::Ok().json(user))
}
```

### Middleware -- Transform Trait

Full custom Actix middleware requires implementing `Transform`. This is more verbose than Tower layers:

```rust
use actix_web::{
    dev::{Service, ServiceRequest, ServiceResponse, Transform},
    Error, HttpMessage,
};
use futures::future::{ok, LocalBoxFuture, Ready};
use std::rc::Rc;

pub struct AuthMiddleware;

impl<S, B> Transform<S, ServiceRequest> for AuthMiddleware
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Transform = AuthMiddlewareService<S>;
    type InitError = ();
    type Future = Ready<Result<Self::Transform, Self::InitError>>;

    fn new_transform(&self, service: S) -> Self::Future {
        ok(AuthMiddlewareService { service: Rc::new(service) })
    }
}
```

For simpler cases, use `wrap_fn`:

```rust
App::new()
    .wrap_fn(|req, srv| {
        println!("Request: {} {}", req.method(), req.uri());
        srv.call(req)
    });
```

### Guards

Guards allow conditional routing based on request properties:

```rust
use actix_web::{guard, web};

App::new()
    .service(
        web::resource("/api/endpoint")
            .guard(guard::Header("Content-Type", "application/json"))
            .route(web::post().to(json_handler))
    );

// Custom guard
struct ApiVersionGuard(u32);

impl guard::Guard for ApiVersionGuard {
    fn check(&self, ctx: &guard::GuardContext<'_>) -> bool {
        ctx.head().headers().get("X-API-Version")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.parse::<u32>().ok())
            .map(|v| v == self.0)
            .unwrap_or(false)
    }
}
```

### Error Handling -- ResponseError Trait

```rust
use actix_web::{HttpResponse, ResponseError};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Validation failed: {0}")]
    Validation(String),
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("Unauthorized")]
    Unauthorized,
}

impl ResponseError for AppError {
    fn status_code(&self) -> actix_web::http::StatusCode {
        match self {
            AppError::NotFound(_)   => actix_web::http::StatusCode::NOT_FOUND,
            AppError::Validation(_) => actix_web::http::StatusCode::UNPROCESSABLE_ENTITY,
            AppError::Database(_)   => actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Unauthorized  => actix_web::http::StatusCode::UNAUTHORIZED,
        }
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code())
            .json(serde_json::json!({"error": self.to_string()}))
    }
}
```

### State with web::Data

```rust
// web::Data<T> is Arc<T> internally
struct AppState {
    counter: tokio::sync::Mutex<u64>,
    db: PgPool,
}

let data = web::Data::new(AppState { counter: Mutex::new(0), db: pool });
App::new().app_data(data.clone())

async fn increment(state: web::Data<AppState>) -> HttpResponse {
    let mut counter = state.counter.lock().await;
    *counter += 1;
    HttpResponse::Ok().json(*counter)
}
```

### WebSocket with Actix Actors

```rust
use actix_web_actors::ws;

struct WsSession { heartbeat: std::time::Instant }

impl Actor for WsSession {
    type Context = ws::WebsocketContext<Self>;
    fn started(&mut self, ctx: &mut Self::Context) {
        self.schedule_heartbeat(ctx);
    }
}

impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WsSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut Self::Context) {
        match msg {
            Ok(ws::Message::Ping(m))  => ctx.pong(&m),
            Ok(ws::Message::Text(t))  => ctx.text(format!("echo: {t}")),
            Ok(ws::Message::Close(r)) => { ctx.close(r); ctx.stop(); }
            _ => {}
        }
    }
}

async fn ws_route(req: HttpRequest, stream: web::Payload) -> actix_web::Result<HttpResponse> {
    ws::start(WsSession { heartbeat: std::time::Instant::now() }, &req, stream)
}
```

### Testing Actix Web

```rust
use actix_web::{test, App, web};

#[actix_web::test]
async fn test_create_user() {
    let app = test::init_service(
        App::new()
            .app_data(web::Data::new(test_db_pool()))
            .service(web::scope("/api").service(
                web::resource("/users").route(web::post().to(create_user))
            ))
    ).await;

    let req = test::TestRequest::post()
        .uri("/api/users")
        .set_json(json!({"name": "Alice", "email": "alice@example.com"}))
        .to_request();

    let resp = test::call_service(&app, req).await;
    assert!(resp.status().is_success());

    let body: serde_json::Value = test::read_body_json(resp).await;
    assert_eq!(body["name"], "Alice");
}
```

---

## Tokio Runtime

### Multi-Threaded Scheduler

```rust
#[tokio::main]
async fn main() {
    // Equivalent to:
    tokio::runtime::Builder::new_multi_thread()
        .worker_threads(num_cpus::get())
        .enable_all()
        .build()
        .unwrap()
        .block_on(async { /* ... */ });
}
```

### Task Spawning

```rust
use tokio::task::{self, JoinSet};

// Spawn async task on the runtime
let handle = task::spawn(async { compute().await });
let result = handle.await.unwrap();

// CPU-bound work -- runs on blocking thread pool
let result = task::spawn_blocking(|| heavy_cpu_work()).await.unwrap();

// JoinSet for managing multiple tasks
let mut set = JoinSet::new();
for i in 0..10 {
    set.spawn(async move { fetch_item(i).await });
}
while let Some(result) = set.join_next().await {
    process(result.unwrap());
}
```

### select! and Cancellation

```rust
use tokio::{time, sync::oneshot};

async fn with_timeout(rx: oneshot::Receiver<String>) {
    tokio::select! {
        result = rx => println!("Got: {:?}", result),
        _ = time::sleep(Duration::from_secs(5)) => println!("Timeout"),
    }
}

// Graceful shutdown
async fn serve_with_shutdown(app: Router) {
    let (tx, rx) = oneshot::channel::<()>();
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        let _ = tx.send(());
    });

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(async { rx.await.ok(); })
        .await.unwrap();
}
```

### Channels

```rust
use tokio::sync::{mpsc, broadcast, watch};

// mpsc -- multiple producers, single consumer
let (tx, mut rx) = mpsc::channel::<String>(100);
tokio::spawn(async move {
    while let Some(msg) = rx.recv().await { process(msg); }
});

// broadcast -- multiple consumers, each get every message
let (btx, _) = broadcast::channel::<Event>(1024);
let mut brx = btx.subscribe();

// watch -- single value, multiple readers see latest
let (wtx, wrx) = watch::channel(Config::default());
let current = wrx.borrow().clone();
```

---

## Tower Ecosystem

### Service Trait

```rust
trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>>;
    fn call(&mut self, req: Request) -> Self::Future;
}
```

### Layer Trait and ServiceBuilder

```rust
use tower::ServiceBuilder;
use tower_http::{
    timeout::TimeoutLayer,
    limit::RequestBodyLimitLayer,
    cors::CorsLayer,
    compression::CompressionLayer,
    trace::TraceLayer,
    concurrency_limit::ConcurrencyLimitLayer,
};

let service = ServiceBuilder::new()
    .layer(TraceLayer::new_for_http())
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(ConcurrencyLimitLayer::new(100))
    .layer(CompressionLayer::new())
    .layer(CorsLayer::permissive())
    .layer(RequestBodyLimitLayer::new(10 * 1024 * 1024))
    .service(inner_service);
```

### Common Tower Middleware (tower-http)

| Layer | Purpose |
|---|---|
| `TraceLayer` | Request/response tracing via `tracing` |
| `TimeoutLayer` | Request timeout |
| `CorsLayer` | CORS headers |
| `CompressionLayer` | Response compression (gzip, br, zstd) |
| `ConcurrencyLimitLayer` | Max concurrent requests |
| `RequestBodyLimitLayer` | Body size limit |
| `RequireAuthorizationLayer` | Basic/bearer auth |

---

## Serde

### Derive Macros

```rust
#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct UserResponse {
    pub user_id: u64,
    pub full_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub is_active: bool,
}
```

### Custom Serialization

```rust
fn serialize_datetime<S: Serializer>(dt: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
    s.serialize_str(&dt.to_rfc3339())
}
```

### Enums -- Tagged and Untagged

```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]  // {"type":"Text","data":"hello"}
pub enum Notification {
    Text(String),
    Image { url: String, alt: String },
}

#[derive(Serialize, Deserialize)]
#[serde(untagged)]  // tries each variant in order
pub enum IdOrName {
    Id(u64),
    Name(String),
}
```

### Flatten and Deny Unknown Fields

```rust
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PaginatedRequest {
    #[serde(flatten)]
    pub pagination: Pagination,
    pub sort: Option<String>,
}

#[derive(Serialize, Deserialize, Default)]
pub struct Pagination {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_per_page")]
    pub per_page: u32,
}
```

---

## Error Handling Patterns

### thiserror for Library/Domain Errors

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ServiceError {
    #[error("Resource not found: {resource} with id {id}")]
    NotFound { resource: &'static str, id: u64 },
    #[error("Permission denied")]
    Forbidden,
    #[error("Invalid input: {0}")]
    Validation(String),
    #[error("Database error")]
    Database(#[from] sqlx::Error),
    #[error("External service error: {service}")]
    ExternalService { service: String, #[source] source: reqwest::Error },
}
```

### anyhow for Application Code

```rust
use anyhow::{Context, Result, bail, ensure};

async fn process_order(id: u64) -> Result<()> {
    let order = db.find_order(id).await
        .context("Failed to fetch order from database")?;
    ensure!(order.status == "pending", "Order {} is not in pending state", id);
    let payment = charge_card(&order).await
        .with_context(|| format!("Payment failed for order {id}"))?;
    if payment.amount != order.total {
        bail!("Payment amount mismatch");
    }
    Ok(())
}
```

### Result<T, AppError> Pattern

```rust
pub type ApiResult<T> = Result<T, AppError>;

async fn create_order(
    State(state): State<Arc<AppState>>,
    Json(body): Json<CreateOrderRequest>,
) -> ApiResult<(StatusCode, Json<Order>)> {
    body.validate().map_err(|e| AppError::Validation(e.to_string()))?;
    let order = state.order_service.create(body).await.map_err(AppError::Internal)?;
    Ok((StatusCode::CREATED, Json(order)))
}
```
