# Go Web Frameworks -- Best Practices Reference

## Project Structure

### Standard Layout (cmd/internal/pkg)

```
myservice/
  cmd/
    server/
      main.go              # wiring, startup, graceful shutdown
  internal/
    handler/               # HTTP handlers (transport layer)
      user.go
      order.go
    service/               # business logic
      user.go
      order.go
    repository/            # data access
      user.go
      postgres/
        user.go
    middleware/
      auth.go
      logging.go
      ratelimit.go
    model/                 # domain types
      user.go
      order.go
    config/
      config.go
  pkg/                     # reusable packages (rare -- prefer internal)
    httputil/
      respond.go
  migrations/
    001_create_users.up.sql
    001_create_users.down.sql
  go.mod
  go.sum
  Dockerfile
  Makefile
```

**Key principles:**
- `cmd/` -- Each binary gets its own directory. `main.go` only does wiring.
- `internal/` -- Private to this module. Cannot be imported by external projects.
- `pkg/` -- Use sparingly. Most code should be in `internal/`.
- Keep handlers thin -- they translate HTTP to domain calls and domain results to HTTP responses.
- Business logic lives in `service/`, not in handlers.

### Flat Structure (Small Services)

For small services, a flat structure is fine:

```
myservice/
  main.go
  handler.go
  service.go
  repository.go
  model.go
  middleware.go
  go.mod
```

---

## Dependency Injection

### Constructor Injection (Idiomatic Go)

Go has no DI framework -- inject dependencies via constructors. This is idiomatic and testable.

```go
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, u *User) error
    List(ctx context.Context, page, limit int) ([]*User, error)
}

type EmailService interface {
    SendWelcome(ctx context.Context, email string) error
}

type UserHandler struct {
    repo  UserRepository
    email EmailService
    log   *slog.Logger
}

func NewUserHandler(repo UserRepository, email EmailService, log *slog.Logger) *UserHandler {
    return &UserHandler{repo: repo, email: email, log: log}
}
```

### Wire (Compile-Time DI)

For larger applications, `google/wire` generates DI code at compile time:

```go
// wire.go (build tag ensures it's not compiled normally)
//go:build wireinject

func InitializeApp(cfg Config) (*App, error) {
    wire.Build(
        NewPostgresRepo,
        NewEmailService,
        NewUserHandler,
        NewOrderHandler,
        NewApp,
    )
    return nil, nil
}
```

Run `wire ./...` to generate `wire_gen.go` with concrete wiring code.

### Wiring in main()

```go
func main() {
    cfg := config.MustLoad()
    db := mustOpenDB(cfg.DatabaseURL)
    defer db.Close()

    log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

    repo := postgres.NewUserRepository(db)
    emailSvc := smtp.NewEmailService(cfg.SMTPHost)
    userHandler := handler.NewUserHandler(repo, emailSvc, log)

    mux := http.NewServeMux()
    mux.Handle("/api/users/", http.StripPrefix("/api/users", userHandler.Routes()))

    srv := &http.Server{
        Addr:         cfg.Addr,
        Handler:      middleware.Stack(middleware.Logger, middleware.Recoverer)(mux),
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
    }

    // graceful shutdown...
}
```

---

## Testing

### httptest (stdlib)

```go
func TestGetUser(t *testing.T) {
    h := NewUserHandler(&mockRepo{users: map[string]*User{
        "123": {ID: "123", Name: "Alice"},
    }}, &mockEmailSvc{}, slog.Default())

    req := httptest.NewRequest("GET", "/123", nil)
    rec := httptest.NewRecorder()

    h.Routes().ServeHTTP(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)
    assert.Contains(t, rec.Body.String(), `"name":"Alice"`)
}
```

### Table-Driven Tests

```go
func TestUserHandler_Get(t *testing.T) {
    tests := []struct {
        name       string
        id         string
        setupRepo  func() UserRepository
        wantStatus int
        wantBody   string
    }{
        {
            name: "found",
            id:   "123",
            setupRepo: func() UserRepository {
                return &mockRepo{users: map[string]*User{
                    "123": {ID: "123", Name: "Alice"},
                }}
            },
            wantStatus: http.StatusOK,
            wantBody:   `"name":"Alice"`,
        },
        {
            name:       "not found",
            id:         "999",
            setupRepo:  func() UserRepository { return &mockRepo{} },
            wantStatus: http.StatusNotFound,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            h := NewUserHandler(tt.setupRepo(), &mockEmailSvc{}, slog.Default())
            req := httptest.NewRequest("GET", "/"+tt.id, nil)
            rec := httptest.NewRecorder()

            h.Routes().ServeHTTP(rec, req)

            assert.Equal(t, tt.wantStatus, rec.Code)
            if tt.wantBody != "" {
                assert.Contains(t, rec.Body.String(), tt.wantBody)
            }
        })
    }
}
```

### Interface-Based Mocking

Define dependencies as interfaces. Create test doubles by implementing the interface. No mocking framework required.

```go
type mockUserRepo struct {
    users map[string]*User
}

func (m *mockUserRepo) FindByID(ctx context.Context, id string) (*User, error) {
    u, ok := m.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return u, nil
}
```

### Testcontainers (Integration Tests)

```go
func TestWithPostgres(t *testing.T) {
    ctx := context.Background()

    pgC, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: testcontainers.ContainerRequest{
            Image:        "postgres:16-alpine",
            ExposedPorts: []string{"5432/tcp"},
            Env: map[string]string{
                "POSTGRES_USER":     "test",
                "POSTGRES_PASSWORD": "test",
                "POSTGRES_DB":       "testdb",
            },
            WaitingFor: wait.ForListeningPort("5432/tcp"),
        },
        Started: true,
    })
    require.NoError(t, err)
    defer pgC.Terminate(ctx)

    host, _ := pgC.Host(ctx)
    port, _ := pgC.MappedPort(ctx, "5432")
    dsn := fmt.Sprintf("postgres://test:test@%s:%s/testdb?sslmode=disable", host, port.Port())

    db, err := sql.Open("postgres", dsn)
    require.NoError(t, err)
    // run migrations, then test...
}
```

### Fiber Testing

Fiber cannot use `httptest.NewRecorder`. Use `app.Test()`:

```go
func TestGetUser(t *testing.T) {
    app := setupApp()
    req := httptest.NewRequest("GET", "/users/123", nil)
    resp, err := app.Test(req, 1000) // timeout in ms
    require.NoError(t, err)
    assert.Equal(t, 200, resp.StatusCode)
}
```

### Benchmarking

```go
func BenchmarkUserHandler_Get(b *testing.B) {
    h := NewUserHandler(&inMemoryRepo{}, &noopEmailSvc{}, slog.Default())
    srv := httptest.NewServer(h.Routes())
    defer srv.Close()

    client := &http.Client{Transport: &http.Transport{MaxIdleConnsPerHost: 100}}

    b.ResetTimer()
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            resp, err := client.Get(srv.URL + "/123")
            if err != nil {
                b.Fatal(err)
            }
            resp.Body.Close()
        }
    })
}
// Run: go test -bench=. -benchmem -count=5 ./...
```

---

## Database Patterns

### Connection Pooling

```go
db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
// sql.DB is a connection pool -- safe for concurrent use

db.SetMaxOpenConns(25)             // max connections to DB
db.SetMaxIdleConns(10)             // idle connections kept open
db.SetConnMaxLifetime(5 * time.Minute)   // recycle connections
db.SetConnMaxIdleTime(1 * time.Minute)   // drop idle connections

// Too many open conns -> DB rejects; too few -> queueing
// Rule of thumb: start with 10-25 per app instance
```

### sqlx Struct Scanning

```go
type User struct {
    ID        string    `db:"id"`
    Name      string    `db:"name"`
    Email     string    `db:"email"`
    CreatedAt time.Time `db:"created_at"`
}

// Get single row
var user User
err := db.GetContext(ctx, &user, `SELECT * FROM users WHERE id = $1`, id)

// Select multiple rows
var users []User
err = db.SelectContext(ctx, &users,
    `SELECT * FROM users WHERE active = true ORDER BY created_at DESC LIMIT $1`, limit)

// Named queries
_, err = db.NamedExecContext(ctx,
    `INSERT INTO users (name, email) VALUES (:name, :email)`, user)
```

### GORM

```go
db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})

// Auto-migrate
db.AutoMigrate(&User{}, &Post{})

// CRUD with context
db.WithContext(ctx).Create(&user)
db.WithContext(ctx).First(&user, "id = ?", id)
db.WithContext(ctx).Preload("Tags").Find(&posts)

// Scopes for reusable query logic
func Paginate(page, limit int) func(*gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        return db.Offset((page - 1) * limit).Limit(limit)
    }
}
db.WithContext(ctx).Scopes(Paginate(2, 10)).Find(&users)
```

### pgx (PostgreSQL Native)

```go
pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))

row := pool.QueryRow(ctx, `SELECT id, name FROM users WHERE id = $1`, id)
err = row.Scan(&id, &name)

// Batch queries
batch := &pgx.Batch{}
batch.Queue(`INSERT INTO events (type) VALUES ($1)`, "login")
batch.Queue(`UPDATE users SET last_login = now() WHERE id = $1`, userID)
results := pool.SendBatch(ctx, batch)
defer results.Close()
```

### Transactions

```go
tx, err := db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
if err != nil {
    return err
}
defer func() {
    if p := recover(); p != nil {
        tx.Rollback()
        panic(p)
    } else if err != nil {
        tx.Rollback()
    } else {
        err = tx.Commit()
    }
}()

_, err = tx.ExecContext(ctx, `UPDATE accounts SET balance = balance - $1 WHERE id = $2`, amount, fromID)
if err != nil {
    return err
}
_, err = tx.ExecContext(ctx, `UPDATE accounts SET balance = balance + $1 WHERE id = $2`, amount, toID)
return err
```

### Database Migrations

Use `golang-migrate/migrate`:

```bash
# Create migration
migrate create -ext sql -dir migrations -seq create_users

# Run migrations
migrate -path migrations -database "$DATABASE_URL" up

# Rollback
migrate -path migrations -database "$DATABASE_URL" down 1
```

---

## Error Handling

### Sentinel Errors

```go
var (
    ErrNotFound  = errors.New("not found")
    ErrConflict  = errors.New("conflict")
    ErrForbidden = errors.New("forbidden")
)

// Wrap with context
func (r *repo) FindByID(ctx context.Context, id string) (*User, error) {
    err := r.db.QueryRowContext(ctx, `SELECT ...`, id).Scan(&u)
    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
    }
    return &u, err
}

// Check with errors.Is
if errors.Is(err, ErrNotFound) {
    http.Error(w, "not found", http.StatusNotFound)
}
```

### Custom Error Types

```go
type ValidationError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s - %s", e.Field, e.Message)
}

// Check with errors.As
var ve *ValidationError
if errors.As(err, &ve) {
    c.JSON(400, ve)
}
```

### JSON Error Responses

```go
func encodeJSON(w http.ResponseWriter, v any) {
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(v); err != nil {
        slog.Error("encode json", "err", err)
    }
}

func errorResponse(w http.ResponseWriter, status int, message string) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(map[string]string{"error": message})
}
```

---

## Deployment

### Static Binary

```bash
# Fully static binary (no libc dependency)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server ./cmd/server
# -s: strip symbol table
# -w: strip DWARF debug info
# Result: ~5-15 MB for a typical service
```

### Cross-Compilation

```bash
GOOS=linux   GOARCH=amd64  go build -o server-linux-amd64   ./cmd/server
GOOS=linux   GOARCH=arm64  go build -o server-linux-arm64   ./cmd/server
GOOS=darwin  GOARCH=arm64  go build -o server-darwin-arm64  ./cmd/server
GOOS=windows GOARCH=amd64  go build -o server-windows.exe   ./cmd/server
```

### Docker (scratch / distroless)

```dockerfile
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server

# scratch -- absolute minimum, no shell, no libc
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

```dockerfile
# distroless -- adds nonroot user, tzdata; easier debugging
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Systemd

```ini
[Unit]
Description=Go API Server
After=network.target

[Service]
Type=simple
User=api
WorkingDirectory=/opt/api
ExecStart=/opt/api/server
Restart=always
RestartSec=5
Environment=PORT=8080
EnvironmentFile=/etc/api/env
LimitNOFILE=65536
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

### Health Check Endpoints

```go
mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
})

mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
    if err := db.PingContext(r.Context()); err != nil {
        http.Error(w, "db unhealthy", http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
})
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: api
        image: myregistry/api-server:v1.2.3
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef: {name: db-secret, key: url}
        resources:
          requests: {cpu: "100m", memory: "64Mi"}
          limits:   {cpu: "500m", memory: "256Mi"}
        livenessProbe:
          httpGet: {path: /healthz, port: 8080}
          initialDelaySeconds: 5
        readinessProbe:
          httpGet: {path: /readyz, port: 8080}
          initialDelaySeconds: 3
```

---

## Performance

### pprof Profiling

```go
import _ "net/http/pprof"

// Start pprof on a separate port (never expose to internet)
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()

// Collect profiles:
// go tool pprof http://localhost:6060/debug/pprof/heap
// go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
// go tool pprof http://localhost:6060/debug/pprof/goroutine
// curl -o trace.out http://localhost:6060/debug/pprof/trace?seconds=5
// go tool trace trace.out
```

### Allocation Reduction

```go
// sync.Pool for frequently allocated objects
var bufPool = sync.Pool{
    New: func() any { return new(bytes.Buffer) },
}

func handler(w http.ResponseWriter, r *http.Request) {
    buf := bufPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufPool.Put(buf)
    json.NewEncoder(buf).Encode(response)
    w.Write(buf.Bytes())
}
```

### GC Tuning

```bash
# GOGC controls GC frequency (default 100 = GC when heap doubles)
# Higher = less CPU on GC, more memory usage
GOGC=150 GOMEMLIMIT=512MiB ./server
```

- `GOGC`: Set higher (e.g., 200) to trade memory for CPU.
- `GOMEMLIMIT` (Go 1.19+): Soft memory limit, triggers aggressive GC before OOM.
- Short-lived per-request allocations are collected efficiently.
- Large long-lived objects (caches) create GC pressure -- use `sync.Pool` or pre-allocate.

---

## Security

### Server Timeouts

Always set timeouts in production. Unbounded timeouts allow slowloris attacks.

```go
srv := &http.Server{
    ReadTimeout:       5 * time.Second,
    ReadHeaderTimeout: 2 * time.Second,
    WriteTimeout:      10 * time.Second,
    IdleTimeout:       120 * time.Second,
    MaxHeaderBytes:    1 << 20,
}
```

### CORS

```go
// Gin
r.Use(cors.New(cors.Config{
    AllowOrigins:     []string{"https://example.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "DELETE"},
    AllowHeaders:     []string{"Authorization", "Content-Type"},
    AllowCredentials: true,
    MaxAge:           12 * time.Hour,
}))
```

### Input Validation

- Use `go-playground/validator` (integrated in Gin) for struct tag validation.
- Validate path parameters (e.g., UUID format) before database queries.
- Limit body size with `http.MaxBytesReader`.
- Sanitize user input before database operations.

### TLS

```go
srv.TLSConfig = &tls.Config{
    MinVersion:       tls.VersionTLS12,
    CurvePreferences: []tls.CurveID{tls.X25519, tls.CurveP256},
}
srv.ListenAndServeTLS("cert.pem", "key.pem")
```

---

## Common Libraries

| Category | Library | Notes |
|---|---|---|
| Logging | `log/slog` (stdlib) | Structured logging, Go 1.21+ |
| Validation | `go-playground/validator/v10` | Struct tag validation |
| HTTP client | `net/http` (stdlib) | Built-in with connection pooling |
| WebSocket | `nhooyr.io/websocket` | Modern, stdlib-compatible |
| UUID | `google/uuid` | UUID generation/parsing |
| Config | `spf13/viper` | Config files + env + flags |
| Config (lighter) | `koanf` | Lighter alternative to viper |
| Migrations | `golang-migrate/migrate` | Database migrations |
| Testing | `stretchr/testify` | Assertions, require, suite |
| Testing (containers) | `testcontainers/testcontainers-go` | Docker-based integration tests |
| Mocking | `vektra/mockery` | Generate mocks from interfaces |
| CLI | `spf13/cobra` | CLI framework (if server has CLI) |
| Metrics | `prometheus/client_golang` | Prometheus metrics |
| Tracing | `go.opentelemetry.io/otel` | OpenTelemetry |
| Rate limiting | `golang.org/x/time/rate` | Token bucket rate limiter |
| JWT | `golang-jwt/jwt/v5` | JWT parsing/signing |
| Password hashing | `golang.org/x/crypto/bcrypt` | bcrypt |
| Database (Postgres) | `jackc/pgx/v5` | Native Postgres driver |
| Database (general) | `jmoiron/sqlx` | Extends database/sql |
| ORM | `gorm.io/gorm` | Full ORM |
