# Rust Web Frameworks: Architecture Reference

Covers Axum and Actix Web in depth, with the surrounding ecosystem (Tokio, Tower, Serde, SQLx, error handling, testing, deployment). Code examples throughout reflect idiomatic 2024/2025 Rust.

---

## 1. Axum

Axum is maintained by the Tokio project. It is intentionally thin: routing and extractor machinery live in `axum`, everything else comes from Tower or external crates. This keeps the API surface small and the upgrade story predictable.

### 1.1 Tower Foundation

Every Axum handler ultimately becomes a `tower::Service`. That means you can compose, wrap, and test handlers using any Tower-compatible middleware without Axum-specific knowledge.

```rust
use tower::Service;
use axum::{Router, routing::get};

// Router itself implements Service<Request>
let app: Router = Router::new().route("/", get(root_handler));
```

`Layer` wraps a service to produce a new service:

```rust
use tower::layer::Layer;
use tower_http::trace::TraceLayer;

let app = Router::new()
    .route("/", get(root_handler))
    .layer(TraceLayer::new_for_http());
```

### 1.2 Router

```rust
use axum::{Router, routing::{get, post, put, delete}};

async fn list_users() -> &'static str { "[]" }
async fn create_user() -> &'static str { "{}" }

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

### 1.3 Handlers — Async Functions as Handlers

Any async function whose arguments implement `FromRequestParts` (or `FromRequest`) and whose return type implements `IntoResponse` is a valid handler. No trait bounds appear in function signatures.

```rust
use axum::{
    extract::{Path, Query, State, Json},
    response::IntoResponse,
    http::StatusCode,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Deserialize)]
struct Pagination {
    page: Option<u32>,
    per_page: Option<u32>,
}

#[derive(Serialize)]
struct User {
    id: u64,
    name: String,
}

async fn get_user(
    State(state): State<Arc<AppState>>,
    Path(user_id): Path<u64>,
    Query(pagination): Query<Pagination>,
) -> impl IntoResponse {
    // Extractors resolve left-to-right; all errors short-circuit to 400/422
    match state.db.find_user(user_id).await {
        Ok(user) => (StatusCode::OK, Json(user)).into_response(),
        Err(_)   => StatusCode::NOT_FOUND.into_response(),
    }
}
```

### 1.4 Extractors

| Extractor | Source | Notes |
|-----------|--------|-------|
| `Path<T>` | URL segment | `T: Deserialize` |
| `Query<T>` | Query string | `T: Deserialize`, missing key → 400 |
| `Json<T>` | Body | Consumes body; must be last |
| `State<T>` | App state | `T: Clone + Send + Sync + 'static` |
| `Extension<T>` | Request extensions | Inserted by middleware |
| `TypedHeader<H>` | HTTP header | Via `axum-extra` |
| `Form<T>` | `application/x-www-form-urlencoded` | `T: Deserialize` |
| `Bytes` | Raw body | Full body bytes |
| `Request` | Whole request | Escape hatch |

Custom extractor:

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

### 1.5 Response Types

`IntoResponse` converts a value into `Response<Body>`. Many types implement it out of the box:

```rust
use axum::response::{IntoResponse, Response, Json};
use axum::http::StatusCode;

// Tuple: (StatusCode, Json<T>) → response with status + JSON body
async fn create_item(Json(payload): Json<NewItem>) -> impl IntoResponse {
    (StatusCode::CREATED, Json(Item { id: 1, ..payload }))
}

// Custom response
async fn download_file() -> Response {
    let body = axum::body::Body::from(b"file bytes" as &[u8]);
    Response::builder()
        .status(200)
        .header("Content-Type", "application/octet-stream")
        .body(body)
        .unwrap()
}
```

### 1.6 Middleware

**Function middleware** (simplest):

```rust
use axum::{middleware::{self, Next}, extract::Request, response::Response};

async fn require_auth(
    State(state): State<Arc<AppState>>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    let token = request
        .headers()
        .get("Authorization")
        .ok_or(StatusCode::UNAUTHORIZED)?;

    validate_token(token, &state).await?;
    Ok(next.run(request).await)
}

let app = Router::new()
    .route("/protected", get(protected_handler))
    .route_layer(middleware::from_fn_with_state(state.clone(), require_auth));
```

**Tower layer** middleware (for reuse across projects):

```rust
use tower_http::{
    cors::{CorsLayer, Any},
    compression::CompressionLayer,
    timeout::TimeoutLayer,
};
use std::time::Duration;

let app = Router::new()
    .nest("/api", api_router)
    .layer(
        tower::ServiceBuilder::new()
            .layer(TimeoutLayer::new(Duration::from_secs(30)))
            .layer(CompressionLayer::new())
            .layer(
                CorsLayer::new()
                    .allow_origin(Any)
                    .allow_methods(Any)
                    .allow_headers(Any),
            )
            .layer(TraceLayer::new_for_http()),
    );
```

### 1.7 Error Handling

The idiomatic pattern is a custom `AppError` type that implements `IntoResponse`:

```rust
use axum::{response::{IntoResponse, Response}, http::StatusCode, Json};
use serde_json::json;
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
            AppError::NotFound(msg)    => (StatusCode::NOT_FOUND, msg.clone()),
            AppError::Validation(msg)  => (StatusCode::UNPROCESSABLE_ENTITY, msg.clone()),
            AppError::Database(_)      => (StatusCode::INTERNAL_SERVER_ERROR, "Database error".into()),
            AppError::Unauthorized     => (StatusCode::UNAUTHORIZED, "Unauthorized".into()),
            AppError::Internal(_)      => (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into()),
        };

        tracing::error!(error = ?self, "Request error");

        let body = Json(json!({ "error": message }));
        (status, body).into_response()
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

### 1.8 State Management

State is shared via `Arc<AppState>` cloned into each handler:

```rust
use std::sync::Arc;
use tokio::sync::RwLock;
use sqlx::PgPool;

#[derive(Clone)]
struct AppState {
    db: PgPool,
    config: Arc<Config>,
    // Mutable shared state uses RwLock or DashMap
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

### 1.9 Nested Routers and Fallback

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

### 1.10 WebSocket Support

```rust
use axum::{
    extract::{ws::{WebSocket, WebSocketUpgrade, Message}, State},
    response::IntoResponse,
};

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

### 1.11 Server-Sent Events (SSE)

```rust
use axum::response::sse::{Event, Sse};
use futures::stream::{self, Stream};
use std::time::Duration;
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

### 1.12 Testing Axum

```rust
use axum::{body::Body, http::{Request, StatusCode}};
use tower::ServiceExt; // for `.oneshot()`
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

## 2. Actix Web

Actix Web 4.x runs on Tokio but retains the Actix actor runtime for WebSocket handling and background actors. Its `App` builder pattern provides a different ergonomic feel from Axum's functional composition.

### 2.1 Actor System and Runtime

Actix Web's `HttpServer` spawns one worker per CPU core, each running its own single-threaded Tokio runtime. The `actix` crate provides actors (`Actor` trait, `Addr<A>`) for managing stateful concurrent processes.

```rust
use actix::prelude::*;

struct Counter {
    count: u64,
}

impl Actor for Counter {
    type Context = Context<Self>;
}

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

### 2.2 App Builder

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

### 2.3 Extractors

```rust
use actix_web::{web, HttpRequest, HttpResponse, Result};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct UserPath {
    id: u64,
}

#[derive(Deserialize)]
struct UserQuery {
    include_deleted: Option<bool>,
}

#[derive(Deserialize)]
struct CreateUserBody {
    name: String,
    email: String,
}

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

async fn create_user(
    body: web::Json<CreateUserBody>,
    db: web::Data<DbPool>,
) -> Result<HttpResponse> {
    let user = db.create_user(&body.name, &body.email).await
        .map_err(actix_web::error::ErrorInternalServerError)?;

    Ok(HttpResponse::Created().json(user))
}
```

### 2.4 Middleware — Transform Trait

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

pub struct AuthMiddlewareService<S> {
    service: Rc<S>,
}

impl<S, B> Service<ServiceRequest> for AuthMiddlewareService<S>
where
    S: Service<ServiceRequest, Response = ServiceResponse<B>, Error = Error> + 'static,
    B: 'static,
{
    type Response = ServiceResponse<B>;
    type Error = Error;
    type Future = LocalBoxFuture<'static, Result<Self::Response, Self::Error>>;

    actix_web::dev::forward_ready!(service);

    fn call(&self, req: ServiceRequest) -> Self::Future {
        let svc = self.service.clone();
        Box::pin(async move {
            let token = req.headers()
                .get("Authorization")
                .ok_or_else(|| actix_web::error::ErrorUnauthorized("Missing token"))?;
            // validate...
            svc.call(req).await
        })
    }
}

// Using wrap_fn for simpler cases
let app = App::new()
    .wrap_fn(|req, srv| {
        println!("Request: {} {}", req.method(), req.uri());
        srv.call(req)
    });
```

### 2.5 Guards

Guards allow conditional routing based on request properties:

```rust
use actix_web::{guard, web, App};

App::new()
    .service(
        web::resource("/api/endpoint")
            .guard(guard::Header("Content-Type", "application/json"))
            .route(web::post().to(json_handler))
    )
    .service(
        web::resource("/api/endpoint")
            .route(web::post().to(unsupported_media_type_handler))
    );

// Custom guard
struct ApiVersionGuard(u32);

impl guard::Guard for ApiVersionGuard {
    fn check(&self, ctx: &guard::GuardContext<'_>) -> bool {
        ctx.head()
            .headers()
            .get("X-API-Version")
            .and_then(|v| v.to_str().ok())
            .and_then(|v| v.parse::<u32>().ok())
            .map(|v| v == self.0)
            .unwrap_or(false)
    }
}
```

### 2.6 Error Handling — ResponseError Trait

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
            AppError::NotFound(_)    => actix_web::http::StatusCode::NOT_FOUND,
            AppError::Validation(_)  => actix_web::http::StatusCode::UNPROCESSABLE_ENTITY,
            AppError::Database(_)    => actix_web::http::StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Unauthorized   => actix_web::http::StatusCode::UNAUTHORIZED,
        }
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code())
            .json(serde_json::json!({ "error": self.to_string() }))
    }
}

// Handler using custom error
async fn get_item(path: web::Path<u64>, db: web::Data<DbPool>) -> Result<HttpResponse, AppError> {
    let item = db.find(path.into_inner()).await?
        .ok_or_else(|| AppError::NotFound("Item".into()))?;
    Ok(HttpResponse::Ok().json(item))
}
```

### 2.7 State with web::Data

```rust
use actix_web::web;
use std::sync::Arc;
use tokio::sync::Mutex;

struct AppState {
    counter: Mutex<u64>,
    db: PgPool,
}

// web::Data<T> is Arc<T> internally
let data = web::Data::new(AppState {
    counter: Mutex::new(0),
    db: pool,
});

App::new().app_data(data.clone())

// In handler
async fn increment(state: web::Data<AppState>) -> HttpResponse {
    let mut counter = state.counter.lock().await;
    *counter += 1;
    HttpResponse::Ok().json(*counter)
}
```

### 2.8 WebSocket with Actix Actors

```rust
use actix::{Actor, ActorContext, Handler, StreamHandler};
use actix_web::{web, HttpRequest, HttpResponse};
use actix_web_actors::ws;

struct WsSession {
    heartbeat: std::time::Instant,
}

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
            Ok(ws::Message::Binary(b)) => ctx.binary(b),
            Ok(ws::Message::Close(r)) => {
                ctx.close(r);
                ctx.stop();
            }
            _ => {}
        }
    }
}

async fn ws_route(req: HttpRequest, stream: web::Payload) -> actix_web::Result<HttpResponse> {
    ws::start(WsSession { heartbeat: std::time::Instant::now() }, &req, stream)
}
```

### 2.9 Testing Actix Web

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
        .set_json(serde_json::json!({ "name": "Alice", "email": "alice@example.com" }))
        .to_request();

    let resp = test::call_service(&app, req).await;
    assert!(resp.status().is_success());

    let body: serde_json::Value = test::read_body_json(resp).await;
    assert_eq!(body["name"], "Alice");
}
```

---

## 3. Tokio Runtime

### 3.1 Multi-Threaded Scheduler

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

### 3.2 Task Spawning

```rust
use tokio::task::{self, JoinSet};

// Spawn async task on the runtime
let handle = task::spawn(async {
    compute().await
});
let result = handle.await.unwrap(); // JoinHandle<T>

// CPU-bound work — runs on blocking thread pool
let result = task::spawn_blocking(|| {
    heavy_cpu_work()
}).await.unwrap();

// JoinSet for managing multiple tasks
let mut set = JoinSet::new();
for i in 0..10 {
    set.spawn(async move { fetch_item(i).await });
}
while let Some(result) = set.join_next().await {
    process(result.unwrap());
}
```

### 3.3 select! and Cancellation

```rust
use tokio::{time, sync::oneshot};

async fn with_timeout(rx: oneshot::Receiver<String>) {
    tokio::select! {
        result = rx => {
            println!("Got: {:?}", result);
        }
        _ = time::sleep(std::time::Duration::from_secs(5)) => {
            println!("Timeout");
        }
    }
}

// Graceful shutdown
async fn serve_with_shutdown(app: Router) {
    let (tx, rx) = oneshot::channel::<()>();

    // Spawn signal handler
    tokio::spawn(async move {
        tokio::signal::ctrl_c().await.ok();
        let _ = tx.send(());
    });

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app)
        .with_graceful_shutdown(async { rx.await.ok(); })
        .await
        .unwrap();
}
```

### 3.4 Channels

```rust
use tokio::sync::{mpsc, broadcast, watch};

// mpsc — multiple producers, single consumer
let (tx, mut rx) = mpsc::channel::<String>(100);
tokio::spawn(async move {
    while let Some(msg) = rx.recv().await {
        process(msg);
    }
});
tx.send("hello".into()).await.unwrap();

// broadcast — multiple producers, multiple consumers (each get every message)
let (btx, _) = broadcast::channel::<Event>(1024);
let mut brx1 = btx.subscribe();
let mut brx2 = btx.subscribe();
btx.send(Event::new()).unwrap();

// watch — single value, multiple readers see latest
let (wtx, wrx) = watch::channel(Config::default());
let current = wrx.borrow().clone(); // non-async read
wtx.send(new_config).unwrap();
```

---

## 4. Tower Ecosystem

### 4.1 Service Trait

```rust
use tower::Service;
use std::future::Future;
use std::task::{Context, Poll};

// The core abstraction
trait Service<Request> {
    type Response;
    type Error;
    type Future: Future<Output = Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>>;
    fn call(&mut self, req: Request) -> Self::Future;
}
```

### 4.2 Layer Trait and ServiceBuilder

```rust
use tower::{ServiceBuilder, layer::Layer};
use tower_http::{
    timeout::TimeoutLayer,
    limit::RequestBodyLimitLayer,
    cors::CorsLayer,
    compression::CompressionLayer,
    trace::TraceLayer,
    auth::RequireAuthorizationLayer,
    concurrency_limit::ConcurrencyLimitLayer,
};
use std::time::Duration;

let service = ServiceBuilder::new()
    .layer(TraceLayer::new_for_http())
    .layer(TimeoutLayer::new(Duration::from_secs(30)))
    .layer(ConcurrencyLimitLayer::new(100))
    .layer(CompressionLayer::new())
    .layer(CorsLayer::permissive())
    .layer(RequestBodyLimitLayer::new(10 * 1024 * 1024)) // 10MB
    .service(inner_service);
```

### 4.3 Common Tower Middleware

```rust
use tower::retry::{Policy, Retry};
use tower::util::ServiceExt;

#[derive(Clone)]
struct RetryPolicy {
    max_retries: usize,
}

impl<Req: Clone, Res, E> Policy<Req, Res, E> for RetryPolicy {
    type Future = std::future::Ready<Self>;

    fn retry(&self, _req: &mut Req, result: &mut Result<Res, E>) -> Option<Self::Future> {
        if result.is_err() && self.max_retries > 0 {
            Some(std::future::ready(RetryPolicy { max_retries: self.max_retries - 1 }))
        } else {
            None
        }
    }

    fn clone_request(&self, req: &Req) -> Option<Req> {
        Some(req.clone())
    }
}
```

---

## 5. Serde

### 5.1 Derive Macros

```rust
use serde::{Deserialize, Serialize};

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

### 5.2 Custom Serialization

```rust
use serde::{Serializer, Deserializer, de};
use chrono::{DateTime, Utc};

fn serialize_datetime<S: Serializer>(dt: &DateTime<Utc>, s: S) -> Result<S::Ok, S::Error> {
    s.serialize_str(&dt.to_rfc3339())
}

fn deserialize_datetime<'de, D: Deserializer<'de>>(d: D) -> Result<DateTime<Utc>, D::Error> {
    let s = String::deserialize(d)?;
    DateTime::parse_from_rfc3339(&s)
        .map(|dt| dt.with_timezone(&Utc))
        .map_err(de::Error::custom)
}

#[derive(Serialize, Deserialize)]
pub struct Event {
    #[serde(serialize_with = "serialize_datetime", deserialize_with = "deserialize_datetime")]
    pub created_at: DateTime<Utc>,
}
```

### 5.3 Enums — Tagged and Untagged

```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]  // {"type":"Text","data":"hello"}
pub enum Notification {
    Text(String),
    Image { url: String, alt: String },
    Action { label: String, href: String },
}

#[derive(Serialize, Deserialize)]
#[serde(untagged)]  // tries each variant in order
pub enum IdOrName {
    Id(u64),
    Name(String),
}
```

### 5.4 Flatten and Deny Unknown Fields

```rust
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PaginatedRequest {
    #[serde(flatten)]
    pub pagination: Pagination,
    #[serde(flatten)]
    pub filter: FilterParams,
    pub sort: Option<String>,
}

#[derive(Serialize, Deserialize, Default)]
pub struct Pagination {
    #[serde(default = "default_page")]
    pub page: u32,
    #[serde(default = "default_per_page")]
    pub per_page: u32,
}

fn default_page() -> u32 { 1 }
fn default_per_page() -> u32 { 20 }
```

---

## 6. Database

### 6.1 SQLx — Compile-Time Checked Queries

SQLx uses procedural macros to verify SQL at compile time against a live database (or cached `.sqlx/` metadata).

```rust
use sqlx::{PgPool, FromRow};
use uuid::Uuid;

#[derive(FromRow, Serialize)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn find_user(pool: &PgPool, id: Uuid) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as!(
        User,
        "SELECT id, name, email, created_at FROM users WHERE id = $1",
        id
    )
    .fetch_optional(pool)
    .await
}

pub async fn create_user(pool: &PgPool, name: &str, email: &str) -> Result<User, sqlx::Error> {
    sqlx::query_as!(
        User,
        "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at",
        name,
        email
    )
    .fetch_one(pool)
    .await
}

// Transactions
pub async fn transfer(pool: &PgPool, from: Uuid, to: Uuid, amount: i64) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query!("UPDATE accounts SET balance = balance - $1 WHERE id = $2", amount, from)
        .execute(&mut *tx).await?;
    sqlx::query!("UPDATE accounts SET balance = balance + $1 WHERE id = $2", amount, to)
        .execute(&mut *tx).await?;

    tx.commit().await
}
```

### 6.2 Connection Pool Configuration

```rust
use sqlx::postgres::PgPoolOptions;

let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .acquire_timeout(std::time::Duration::from_secs(3))
    .idle_timeout(std::time::Duration::from_secs(600))
    .max_lifetime(std::time::Duration::from_secs(1800))
    .connect(&database_url)
    .await?;
```

### 6.3 Diesel — Sync ORM

Diesel generates type-safe query builders from a schema. It is synchronous; use `spawn_blocking` with Axum/Actix.

```rust
use diesel::prelude::*;
use diesel::r2d2::{self, ConnectionManager};

type DbPool = r2d2::Pool<ConnectionManager<PgConnection>>;

// schema.rs (generated by diesel print-schema)
diesel::table! {
    users (id) {
        id -> Int8,
        name -> Text,
        email -> Text,
    }
}

fn list_users(pool: &DbPool) -> QueryResult<Vec<User>> {
    use crate::schema::users::dsl::*;
    let conn = &mut pool.get().unwrap();
    users.filter(is_active.eq(true)).order(name.asc()).load::<User>(conn)
}

// In Axum handler
async fn get_users(State(pool): State<DbPool>) -> impl IntoResponse {
    let users = tokio::task::spawn_blocking(move || list_users(&pool))
        .await
        .unwrap()
        .unwrap();
    Json(users)
}
```

### 6.4 SeaORM — Async ORM

```rust
use sea_orm::{Database, EntityTrait, QueryFilter, ColumnTrait, Set, ActiveModelTrait};

let db = Database::connect(&database_url).await?;

// Find with filter
let users = user::Entity::find()
    .filter(user::Column::IsActive.eq(true))
    .order_by_asc(user::Column::Name)
    .all(&db)
    .await?;

// Insert
let new_user = user::ActiveModel {
    name: Set("Alice".to_owned()),
    email: Set("alice@example.com".to_owned()),
    ..Default::default()
};
let inserted = new_user.insert(&db).await?;
```

---

## 7. Error Handling

### 7.1 thiserror for Library Errors

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

### 7.2 anyhow for Application Code

```rust
use anyhow::{Context, Result, bail, ensure};

async fn process_order(id: u64) -> Result<()> {
    let order = db.find_order(id).await
        .context("Failed to fetch order from database")?;

    ensure!(order.status == "pending", "Order {} is not in pending state", id);

    let payment = charge_card(&order).await
        .with_context(|| format!("Payment failed for order {id}"))?;

    if payment.amount != order.total {
        bail!("Payment amount mismatch: expected {}, got {}", order.total, payment.amount);
    }

    Ok(())
}
```

### 7.3 Result<T, AppError> Pattern in Axum

```rust
// Type alias for cleaner handler signatures
pub type ApiResult<T> = Result<T, AppError>;

async fn create_order(
    State(state): State<Arc<AppState>>,
    Json(body): Json<CreateOrderRequest>,
) -> ApiResult<(StatusCode, Json<Order>)> {
    body.validate().map_err(|e| AppError::Validation(e.to_string()))?;

    let order = state.order_service
        .create(body)
        .await
        .map_err(AppError::Internal)?;

    Ok((StatusCode::CREATED, Json(order)))
}
```

---

## 8. Testing

### 8.1 Integration Tests with reqwest

```rust
use reqwest::Client;

struct TestServer {
    base_url: String,
    _guard: tokio::task::JoinHandle<()>,
}

impl TestServer {
    async fn spawn() -> Self {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let port = listener.local_addr().unwrap().port();
        let app = build_test_app().await;

        let guard = tokio::spawn(async move {
            axum::serve(listener, app).await.unwrap();
        });

        TestServer { base_url: format!("http://127.0.0.1:{port}"), _guard: guard }
    }
}

#[tokio::test]
async fn test_full_user_lifecycle() {
    let server = TestServer::spawn().await;
    let client = Client::new();

    // Create
    let resp = client
        .post(format!("{}/api/v1/users", server.base_url))
        .json(&serde_json::json!({ "name": "Alice", "email": "alice@example.com" }))
        .send().await.unwrap();
    assert_eq!(resp.status(), 201);
    let user: serde_json::Value = resp.json().await.unwrap();
    let user_id = user["id"].as_u64().unwrap();

    // Read
    let resp = client
        .get(format!("{}/api/v1/users/{user_id}", server.base_url))
        .send().await.unwrap();
    assert_eq!(resp.status(), 200);
}
```

### 8.2 Mocking with mockall

```rust
use mockall::{automock, predicate::*};

#[automock]
pub trait UserRepository: Send + Sync {
    async fn find_by_id(&self, id: u64) -> Result<Option<User>, DbError>;
    async fn create(&self, user: NewUser) -> Result<User, DbError>;
}

#[tokio::test]
async fn test_user_service_not_found() {
    let mut mock_repo = MockUserRepository::new();
    mock_repo
        .expect_find_by_id()
        .with(eq(999u64))
        .times(1)
        .returning(|_| Ok(None));

    let service = UserService::new(Arc::new(mock_repo));
    let result = service.get_user(999).await;

    assert!(matches!(result, Err(ServiceError::NotFound { .. })));
}
```

### 8.3 Axum oneshot Testing Pattern

```rust
use axum::{body::Body, http::Request};
use tower::ServiceExt;
use http_body_util::BodyExt;

async fn post_json(app: &Router, uri: &str, body: serde_json::Value) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri(uri)
                .header("Content-Type", "application/json")
                .body(Body::from(serde_json::to_vec(&body).unwrap()))
                .unwrap(),
        )
        .await
        .unwrap()
}
```

---

## 9. Deployment

### 9.1 Static Binary with musl

```toml
# .cargo/config.toml
[target.x86_64-unknown-linux-musl]
linker = "x86_64-linux-musl-gcc"
```

```bash
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
```

The resulting binary has zero dynamic library dependencies and runs on any x86-64 Linux system.

### 9.2 Minimal Docker Image (scratch)

```dockerfile
# Build stage
FROM rust:1.82-slim AS builder
RUN rustup target add x86_64-unknown-linux-musl
RUN apt-get update && apt-get install -y musl-tools

WORKDIR /app
COPY Cargo.toml Cargo.lock ./
# Cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release --target x86_64-unknown-linux-musl
RUN rm -f target/x86_64-unknown-linux-musl/release/deps/myapp*

COPY src ./src
RUN cargo build --release --target x86_64-unknown-linux-musl

# Runtime stage — scratch has no OS at all
FROM scratch
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/myapp /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 3000
ENTRYPOINT ["/app"]
```

Final image size is typically 5–15 MB.

### 9.3 Cross-Compilation

```toml
# Cargo.toml
[profile.release]
opt-level = 3
lto = true         # Link-time optimization for smaller, faster binary
codegen-units = 1  # Single unit for better optimization
panic = "abort"    # Remove panic unwinding code
strip = true       # Strip debug symbols
```

```bash
# Using cross (Docker-based cross-compilation)
cargo install cross --git https://github.com/cross-rs/cross
cross build --release --target aarch64-unknown-linux-musl
```

### 9.4 Development Workflow

```bash
# cargo-watch: restart on file changes
cargo install cargo-watch
cargo watch -x "run --bin server"

# With environment reload
cargo watch -s "cargo run" -w src -w migrations

# sqlx offline mode (for CI without database)
cargo sqlx prepare -- --lib
# Commit .sqlx/ directory; set SQLX_OFFLINE=true in CI
```

### 9.5 Environment and Configuration

```rust
use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;

#[derive(Deserialize)]
pub struct Settings {
    pub database_url: String,
    pub server_port: u16,
    pub jwt_secret: String,
    pub log_level: String,
}

impl Settings {
    pub fn load() -> Result<Self, ConfigError> {
        Config::builder()
            .add_source(File::with_name("config/default").required(false))
            .add_source(File::with_name("config/local").required(false))
            .add_source(Environment::default().separator("__"))
            .build()?
            .try_deserialize()
    }
}
```

---

## 10. Axum vs Actix Web — Decision Guide

### Core Differences

| Dimension | Axum | Actix Web |
|-----------|------|-----------|
| Runtime model | Tokio, standard async | Tokio + Actix actor runtime |
| Composition | Tower Service/Layer | App builder, Transform trait |
| State sharing | `Arc<AppState>` + `.with_state()` | `web::Data<T>` (internally Arc) |
| Middleware API | `from_fn`, Tower layers | `Transform` trait, `wrap_fn` |
| WebSocket | `axum::extract::ws` | `actix-web-actors::ws` |
| Error handling | `IntoResponse` for error types | `ResponseError` trait |
| Benchmarks | Excellent (~94% of Actix) | Historically highest Techempower |
| Ecosystem fit | Tower, hyper, everything Tokio | Self-contained, Actix ecosystem |
| Learning curve | Moderate (Tower concepts) | Steeper (actor model) |
| Compile times | Moderate | Moderate |

### Choose Axum When

- Your team is already using Tower middleware (auth, tracing, rate-limiting)
- You want maximum composability — handlers, layers, and services all interoperate uniformly via the `Service` trait
- You value a smaller API surface and want the framework to "stay out of the way"
- You need tight integration with hyper or other Tokio-ecosystem crates
- You are building microservices that will share middleware across multiple services via a shared `tower::Layer` library

### Choose Actix Web When

- You need the actor model for managing stateful WebSocket sessions at scale (hundreds of thousands of concurrent connections with per-connection state machines)
- You require the absolute highest raw throughput and your profiling confirms the difference matters
- Your team has existing Actix ecosystem investment (actix-session, actix-files, actix-multipart)
- You need fine-grained worker control (Actix Web's per-worker isolation can simplify certain threading models)

### Practical Recommendation

For new projects without specific actor-model requirements: **start with Axum**. The Tower ecosystem, Tokio project backing, and lower conceptual overhead make it the better default. Actix Web remains the right choice when actor-per-connection state management is a first-class requirement.

```rust
// Axum: composable, functional
let app = Router::new()
    .route("/users/:id", get(get_user))
    .with_state(state)
    .layer(auth_layer)
    .layer(trace_layer);

// Actix: builder, imperative
App::new()
    .app_data(web::Data::new(state))
    .wrap(AuthMiddleware)
    .wrap(middleware::Logger::default())
    .service(web::resource("/users/{id}").route(web::get().to(get_user)))
```

Both frameworks are production-proven, actively maintained, and capable of handling millions of requests per second on modest hardware. The ecosystem differences matter more than raw performance in the vast majority of applications.
