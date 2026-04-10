# Rust Web Frameworks -- Best Practices Reference

## Project Structure

### Standard Layout

```
myservice/
  src/
    main.rs                # startup, wiring, graceful shutdown
    lib.rs                 # re-exports for integration tests
    config.rs              # Settings struct, env loading
    error.rs               # AppError enum, IntoResponse/ResponseError impl
    routes/
      mod.rs               # Router composition
      users.rs             # user routes and handlers
      orders.rs            # order routes and handlers
    services/
      mod.rs
      user_service.rs      # business logic
      order_service.rs
    repositories/
      mod.rs
      user_repo.rs         # data access
    models/
      mod.rs
      user.rs              # domain types, Serialize/Deserialize
      order.rs
    middleware/
      auth.rs
      logging.rs
    extractors/
      auth_user.rs         # custom FromRequestParts
  migrations/
    20240101_create_users.sql
  tests/
    integration/
      users.rs
      common/mod.rs        # test helpers, TestServer
  Cargo.toml
  Cargo.lock
  Dockerfile
  .sqlx/                   # SQLx offline query cache (commit to VCS)
  config/
    default.toml
    local.toml
```

**Key principles:**
- `src/main.rs` -- Only startup and wiring. Build the router, connect the database, start the server.
- `src/lib.rs` -- Re-export `build_app()` so integration tests can construct the router.
- `src/error.rs` -- Single `AppError` enum with `IntoResponse` (Axum) or `ResponseError` (Actix).
- Keep handlers thin -- extract, validate, call service, return response.
- Business logic in `services/`, not handlers.
- Domain types in `models/` with Serde derives.

### Workspace Layout (Multiple Services)

```
workspace/
  Cargo.toml              # [workspace] members
  crates/
    api-server/            # binary crate
    domain/                # shared domain types
    shared-middleware/     # reusable Tower layers
```

---

## Error Handling

### AppError Implementing IntoResponse (Axum)

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

    #[error("Forbidden")]
    Forbidden,

    #[error("Internal error")]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            AppError::NotFound(msg)   => (StatusCode::NOT_FOUND, msg.clone()),
            AppError::Validation(msg) => (StatusCode::UNPROCESSABLE_ENTITY, msg.clone()),
            AppError::Database(e)     => {
                tracing::error!(error = %e, "Database error");
                (StatusCode::INTERNAL_SERVER_ERROR, "Database error".into())
            }
            AppError::Unauthorized    => (StatusCode::UNAUTHORIZED, "Unauthorized".into()),
            AppError::Forbidden       => (StatusCode::FORBIDDEN, "Forbidden".into()),
            AppError::Internal(e)     => {
                tracing::error!(error = ?e, "Internal error");
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal error".into())
            }
        };

        (status, Json(json!({"error": message}))).into_response()
    }
}

// Type alias for cleaner handler signatures
pub type ApiResult<T> = Result<T, AppError>;
```

### AppError Implementing ResponseError (Actix)

```rust
impl ResponseError for AppError {
    fn status_code(&self) -> StatusCode {
        match self {
            AppError::NotFound(_)   => StatusCode::NOT_FOUND,
            AppError::Validation(_) => StatusCode::UNPROCESSABLE_ENTITY,
            AppError::Database(_)   => StatusCode::INTERNAL_SERVER_ERROR,
            AppError::Unauthorized  => StatusCode::UNAUTHORIZED,
            AppError::Forbidden     => StatusCode::FORBIDDEN,
            AppError::Internal(_)   => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code())
            .json(json!({"error": self.to_string()}))
    }
}
```

### Error Crate Roles

- **thiserror**: Define structured error enums with `#[derive(Error)]`. Use `#[from]` for automatic conversion. Use in domain/service layers.
- **anyhow**: Catch-all `anyhow::Error` with `.context("msg")` for adding context. Use in application plumbing and `main()`.
- Combine them: `AppError::Internal(#[from] anyhow::Error)` catches anything that isn't a specific variant.

---

## Testing

### Axum oneshot Testing Pattern

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

#[tokio::test]
async fn test_create_user() {
    let app = build_test_app().await;
    let resp = post_json(&app, "/api/users",
        json!({"name": "Alice", "email": "alice@example.com"})).await;
    assert_eq!(resp.status(), StatusCode::CREATED);
}
```

### Integration Tests with reqwest

```rust
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
    let client = reqwest::Client::new();

    // Create
    let resp = client
        .post(format!("{}/api/v1/users", server.base_url))
        .json(&json!({"name": "Alice", "email": "alice@example.com"}))
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

### Actix Web Test Utilities

```rust
use actix_web::{test, App, web};

#[actix_web::test]
async fn test_get_user() {
    let app = test::init_service(
        App::new()
            .app_data(web::Data::new(test_db_pool()))
            .service(users_scope())
    ).await;

    let req = test::TestRequest::get().uri("/users/1").to_request();
    let resp = test::call_service(&app, req).await;
    assert!(resp.status().is_success());
}
```

### Mocking with mockall

```rust
use mockall::{automock, predicate::*};

#[automock]
pub trait UserRepository: Send + Sync {
    async fn find_by_id(&self, id: u64) -> Result<Option<User>, DbError>;
    async fn create(&self, user: NewUser) -> Result<User, DbError>;
}

#[tokio::test]
async fn test_user_not_found() {
    let mut mock = MockUserRepository::new();
    mock.expect_find_by_id()
        .with(eq(999u64))
        .times(1)
        .returning(|_| Ok(None));

    let service = UserService::new(Arc::new(mock));
    let result = service.get_user(999).await;
    assert!(matches!(result, Err(ServiceError::NotFound { .. })));
}
```

---

## Database Patterns

### SQLx Compile-Time Checked Queries

SQLx verifies SQL at compile time against a live database (or cached `.sqlx/` metadata).

```rust
use sqlx::{PgPool, FromRow};

#[derive(FromRow, Serialize)]
pub struct User {
    pub id: Uuid,
    pub name: String,
    pub email: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

pub async fn find_user(pool: &PgPool, id: Uuid) -> Result<Option<User>, sqlx::Error> {
    sqlx::query_as!(User,
        "SELECT id, name, email, created_at FROM users WHERE id = $1", id)
        .fetch_optional(pool).await
}

pub async fn create_user(pool: &PgPool, name: &str, email: &str) -> Result<User, sqlx::Error> {
    sqlx::query_as!(User,
        "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at",
        name, email)
        .fetch_one(pool).await
}
```

### Connection Pool Configuration

```rust
use sqlx::postgres::PgPoolOptions;

let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .acquire_timeout(Duration::from_secs(3))
    .idle_timeout(Duration::from_secs(600))
    .max_lifetime(Duration::from_secs(1800))
    .connect(&database_url)
    .await?;
```

### Transactions

```rust
pub async fn transfer(pool: &PgPool, from: Uuid, to: Uuid, amount: i64) -> Result<(), sqlx::Error> {
    let mut tx = pool.begin().await?;

    sqlx::query!("UPDATE accounts SET balance = balance - $1 WHERE id = $2", amount, from)
        .execute(&mut *tx).await?;
    sqlx::query!("UPDATE accounts SET balance = balance + $1 WHERE id = $2", amount, to)
        .execute(&mut *tx).await?;

    tx.commit().await
}
```

### SQLx Offline Mode (CI without Database)

```bash
# Generate query metadata
cargo sqlx prepare -- --lib

# Commit .sqlx/ directory to VCS
# In CI, set SQLX_OFFLINE=true
```

### Diesel (Sync ORM) in Async Handlers

```rust
// Diesel is synchronous -- use spawn_blocking
async fn get_users(State(pool): State<DbPool>) -> impl IntoResponse {
    let users = tokio::task::spawn_blocking(move || {
        let conn = &mut pool.get().unwrap();
        users::table.filter(users::is_active.eq(true)).load::<User>(conn)
    })
    .await
    .unwrap()
    .unwrap();
    Json(users)
}
```

### SeaORM (Async ORM)

```rust
use sea_orm::{Database, EntityTrait, QueryFilter, ColumnTrait, Set, ActiveModelTrait};

let db = Database::connect(&database_url).await?;

let users = user::Entity::find()
    .filter(user::Column::IsActive.eq(true))
    .order_by_asc(user::Column::Name)
    .all(&db).await?;

let new_user = user::ActiveModel {
    name: Set("Alice".to_owned()),
    email: Set("alice@example.com".to_owned()),
    ..Default::default()
};
let inserted = new_user.insert(&db).await?;
```

---

## State Management

### Arc<AppState> Pattern (Axum)

```rust
use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone)]
struct AppState {
    db: PgPool,
    config: Arc<Config>,
    cache: Arc<RwLock<HashMap<String, CachedItem>>>,
}

let state = Arc::new(AppState { db: pool, config, cache: Default::default() });
let app = Router::new()
    .route("/users/:id", get(get_user))
    .with_state(state);
```

### web::Data Pattern (Actix)

```rust
// web::Data<T> is Arc<T> internally
let data = web::Data::new(AppState { db: pool, config });
App::new().app_data(data.clone())
```

### Mutable Shared State

- Use `tokio::sync::RwLock` for read-heavy workloads.
- Use `tokio::sync::Mutex` for write-heavy workloads.
- Use `DashMap` for concurrent hash map access without locking the entire map.
- **Never** use `std::sync::Mutex` in async code -- it blocks the Tokio worker thread.

---

## Deployment

### Static Binary with musl

```bash
rustup target add x86_64-unknown-linux-musl
cargo build --release --target x86_64-unknown-linux-musl
```

The resulting binary has zero dynamic library dependencies.

```toml
# .cargo/config.toml
[target.x86_64-unknown-linux-musl]
linker = "x86_64-linux-musl-gcc"
```

### Minimal Docker Image (scratch)

```dockerfile
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

FROM scratch
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/myapp /app
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
EXPOSE 3000
ENTRYPOINT ["/app"]
```

Final image: 5-15 MB.

### Release Profile

```toml
[profile.release]
opt-level = 3       # maximum optimization
lto = true          # link-time optimization for smaller, faster binary
codegen-units = 1   # single unit for better optimization (slower compile)
panic = "abort"     # remove panic unwinding code
strip = true        # strip debug symbols
```

### Cross-Compilation

```bash
cargo install cross --git https://github.com/cross-rs/cross
cross build --release --target aarch64-unknown-linux-musl
```

### Development Workflow

```bash
# cargo-watch: restart on file changes
cargo install cargo-watch
cargo watch -x "run --bin server"

# With environment reload
cargo watch -s "cargo run" -w src -w migrations
```

---

## Performance

### Release Profile Optimizations

- `lto = true` -- Link-time optimization produces smaller, faster binaries at the cost of compile time.
- `codegen-units = 1` -- Better optimization but slower compilation.
- `panic = "abort"` -- Removes unwinding code, reducing binary size.
- `strip = true` -- Removes debug symbols from the binary.

### Async Runtime Tuning

- `#[tokio::main]` defaults to `num_cpus` worker threads. Override with `worker_threads`.
- Use `spawn_blocking` for CPU-bound or synchronous code (Diesel, bcrypt, image processing).
- Use `JoinSet` for concurrent task management instead of `Vec<JoinHandle>`.
- Avoid holding `MutexGuard` across `.await` points.

### Connection Pool Sizing

```rust
PgPoolOptions::new()
    .max_connections(20)    // start with 2x worker threads
    .min_connections(5)     // avoid cold start latency
    .acquire_timeout(Duration::from_secs(3))
```

Rule of thumb: `max_connections` = 2-4x the number of Tokio worker threads. Too many connections waste Postgres resources.

### Compile-Time Optimization

```bash
# Profile compilation time
cargo build --timings

# Use mold linker for faster dev builds
[target.x86_64-unknown-linux-gnu]
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
```

---

## Configuration

### config Crate

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

### Tracing Setup

```rust
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

tracing_subscriber::registry()
    .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
    .with(tracing_subscriber::fmt::layer().json())
    .init();
```

---

## Common Crates

| Category | Crate | Purpose |
|---|---|---|
| Framework | `axum` | Tower-based web framework |
| Framework | `actix-web` | Actor-based web framework |
| Runtime | `tokio` | Async runtime |
| Middleware | `tower`, `tower-http` | Service/Layer ecosystem |
| Serialization | `serde`, `serde_json` | JSON serialization |
| Database | `sqlx` | Async SQL with compile-time checks |
| Database | `diesel` | Sync ORM |
| Database | `sea-orm` | Async ORM |
| Error handling | `thiserror` | Derive Error for enums |
| Error handling | `anyhow` | Flexible error context |
| Validation | `validator` | Struct validation with derives |
| Config | `config` | Layered configuration |
| Tracing | `tracing`, `tracing-subscriber` | Structured logging/tracing |
| HTTP client | `reqwest` | Async HTTP client |
| UUID | `uuid` | UUID types |
| DateTime | `chrono` | Date/time types |
| Password | `argon2` | Password hashing |
| JWT | `jsonwebtoken` | JWT encode/decode |
| Testing | `mockall` | Mock generation |
| Testing | `reqwest` | Integration test client |
| Testing | `testcontainers` | Docker-based integration tests |
| CLI | `clap` | Command-line argument parsing |
