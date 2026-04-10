# Go Web Frameworks — Architecture Reference

## Table of Contents

1. [net/http Standard Library](#1-nethttp-standard-library)
2. [Gin Framework](#2-gin-framework)
3. [Fiber Framework](#3-fiber-framework)
4. [Other Notable Frameworks](#4-other-notable-frameworks)
5. [Go Patterns for Web Development](#5-go-patterns-for-web-development)
6. [Database Access](#6-database-access)
7. [Deployment](#7-deployment)
8. [Performance](#8-performance)
9. [Framework Comparison Matrix](#9-framework-comparison-matrix)

---

## 1. net/http Standard Library

### ServeMux — Go 1.22+ Enhanced Routing

Before Go 1.22, `net/http.ServeMux` had very limited routing: no method matching, no path parameters, no wildcards beyond trailing slashes. Go 1.22 fundamentally changed this.

#### Go 1.21 and Earlier (Legacy)

```go
// Old-style mux — no method matching, no path params
mux := http.NewServeMux()
mux.HandleFunc("/users/", handleUsers) // trailing slash = subtree match
mux.HandleFunc("/users", handleUsers)  // exact match
// You had to parse the path manually to extract IDs
```

#### Go 1.22 — Method + Wildcard Routing

```go
mux := http.NewServeMux()

// Method prefix in pattern
mux.HandleFunc("GET /users", listUsers)
mux.HandleFunc("POST /users", createUser)
mux.HandleFunc("GET /users/{id}", getUser)     // {id} is a wildcard segment
mux.HandleFunc("PUT /users/{id}", updateUser)
mux.HandleFunc("DELETE /users/{id}", deleteUser)

// Wildcard at end of path (subtree match)
mux.HandleFunc("GET /files/{path...}", serveFile) // {path...} matches rest of URL

func getUser(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id") // new in Go 1.22
    fmt.Fprintf(w, "user: %s", id)
}
```

#### Go 1.22 Pattern Precedence Rules

- More specific patterns take priority over less specific ones.
- A method-qualified pattern (`GET /foo`) is more specific than an unqualified one (`/foo`).
- An exact segment match beats a wildcard match.
- Patterns ending in `{...}` (subtree wildcards) are lower priority than exact or single-segment wildcards.

```go
mux.HandleFunc("GET /api/users/me", getCurrentUser)  // beats {id} for "me"
mux.HandleFunc("GET /api/users/{id}", getUser)
```

#### Go 1.23 Routing Refinements

Go 1.23 fixed edge cases in wildcard matching and introduced clearer conflict detection at registration time — if two patterns would both match the same request with no clear precedence, `ServeMux` panics on registration instead of silently shadowing.

```go
// Go 1.23 panics at startup if patterns conflict ambiguously:
mux.HandleFunc("/a/{x}/b", h1)
mux.HandleFunc("/a/b/{x}", h2) // OK — these are unambiguous
// mux.HandleFunc("/{x}/b/{y}", h3) — may conflict; caught at registration
```

#### Go 1.24 Routing

Go 1.24 (released February 2025) did not add new routing syntax but improved the internal matching algorithm's performance and fixed additional edge cases around trailing-slash redirect behavior. The stdlib mux now redirects `GET /foo` to `GET /foo/` only when an exact subtree handler is registered, matching documented behavior more precisely.

### Handler and HandlerFunc

```go
// http.Handler interface — the fundamental building block
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}

// http.HandlerFunc — adapter to use a function as Handler
type HandlerFunc func(ResponseWriter, *Request)
func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) { f(w, r) }

// Struct-based handler — preferred for dependency injection
type UserHandler struct {
    db  *sql.DB
    log *slog.Logger
}

func (h *UserHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
    switch r.Method {
    case http.MethodGet:
        h.list(w, r)
    case http.MethodPost:
        h.create(w, r)
    default:
        http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
    }
}

func (h *UserHandler) list(w http.ResponseWriter, r *http.Request) {
    // use h.db, h.log
}
```

### Middleware Pattern

The canonical Go middleware signature is `func(http.Handler) http.Handler`. This composes cleanly without any framework dependency.

```go
// Logger middleware
func Logger(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        // wrap ResponseWriter to capture status code
        rw := &responseWriter{ResponseWriter: w, status: http.StatusOK}
        next.ServeHTTP(rw, r)
        slog.Info("request",
            "method", r.Method,
            "path", r.URL.Path,
            "status", rw.status,
            "duration", time.Since(start),
        )
    })
}

// responseWriter wraps http.ResponseWriter to capture status
type responseWriter struct {
    http.ResponseWriter
    status int
}
func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}

// Auth middleware
func RequireAuth(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if !validateToken(token) {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return // short-circuit — does NOT call next
        }
        next.ServeHTTP(w, r)
    })
}

// Composing middleware (applied right-to-left, executes left-to-right)
func Chain(h http.Handler, middlewares ...func(http.Handler) http.Handler) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        h = middlewares[i](h)
    }
    return h
}

// Usage
handler := Chain(userHandler, Logger, RequireAuth, RateLimit)
mux.Handle("/api/users", handler)
```

### context.Context

`context.Context` flows through every request handler. Use it for cancellation, deadlines, and request-scoped values.

```go
// Storing values in context — use unexported key type to avoid collisions
type contextKey string
const userIDKey contextKey = "userID"

func WithUserID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, userIDKey, id)
}

func UserIDFromContext(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(userIDKey).(string)
    return id, ok
}

// Middleware that enriches context
func AuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        userID := extractUserID(r)
        ctx := WithUserID(r.Context(), userID)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

// Handler respects context cancellation
func (h *Handler) longOperation(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    result, err := h.db.QueryContext(ctx, "SELECT ...")
    if err != nil {
        if ctx.Err() != nil {
            // client disconnected — do not write response
            return
        }
        http.Error(w, "db error", http.StatusInternalServerError)
        return
    }
    _ = result
}
```

### http.Server Configuration

```go
srv := &http.Server{
    Addr:    ":8080",
    Handler: mux,

    // Timeouts — critical for production
    ReadTimeout:       5 * time.Second,   // time to read entire request including body
    ReadHeaderTimeout: 2 * time.Second,   // time to read request headers only
    WriteTimeout:      10 * time.Second,  // time to write response
    IdleTimeout:       120 * time.Second, // keep-alive idle timeout

    MaxHeaderBytes: 1 << 20, // 1 MB

    // TLS — load cert/key
    TLSConfig: &tls.Config{
        MinVersion: tls.VersionTLS12,
        CurvePreferences: []tls.CurveID{
            tls.X25519, tls.CurveP256,
        },
    },
}

// Start with TLS
go srv.ListenAndServeTLS("cert.pem", "key.pem")
```

### Graceful Shutdown

```go
func run(ctx context.Context) error {
    srv := &http.Server{Addr: ":8080", Handler: buildRouter()}

    // Start server in goroutine
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    // Shutdown with timeout
    shutdownCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(shutdownCtx); err != nil {
        return fmt.Errorf("server shutdown: %w", err)
    }
    return nil
}
```

### HTTP/2 Support

```go
// HTTP/2 is automatic with TLS via ListenAndServeTLS
srv := &http.Server{Addr: ":443", Handler: mux}
srv.ListenAndServeTLS("cert.pem", "key.pem") // HTTP/2 enabled automatically

// HTTP/2 cleartext (h2c) — for internal services without TLS
import "golang.org/x/net/http2"
import "golang.org/x/net/http2/h2c"

h2cHandler := h2c.NewHandler(mux, &http2.Server{})
srv := &http.Server{Addr: ":8080", Handler: h2cHandler}
```

### File Serving

```go
// Serve a directory
mux.Handle("GET /static/", http.StripPrefix("/static/", http.FileServer(http.Dir("./public"))))

// Embed files into binary (Go 1.16+)
//go:embed public
var staticFiles embed.FS

mux.Handle("GET /static/", http.StripPrefix("/static/",
    http.FileServer(http.FS(staticFiles)),
))

// Single file download
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    http.ServeFile(w, r, "./reports/report.pdf")
}
```

---

## 2. Gin Framework

Gin (`github.com/gin-gonic/gin`) is the most popular Go web framework. It uses an httprouter-based radix tree for routing, offering ~40x faster routing than stdlib ServeMux (pre-1.22). With Go 1.22's improved stdlib, the gap narrowed for simple cases, but Gin's ecosystem and ergonomics remain compelling.

### Router Basics

```go
import "github.com/gin-gonic/gin"

r := gin.Default() // includes Logger and Recovery middleware
// gin.New() — bare router, no default middleware

r.GET("/users", listUsers)
r.POST("/users", createUser)
r.GET("/users/:id", getUser)       // :id — named parameter
r.GET("/files/*path", serveFiles)  // *path — wildcard (catches all)

r.Run(":8080") // wraps http.ListenAndServe
```

### gin.Context

`*gin.Context` is the central object in every Gin handler — it combines the request, response, params, and helpers.

```go
func getUser(c *gin.Context) {
    // Path parameters
    id := c.Param("id")

    // Query parameters
    page := c.DefaultQuery("page", "1")
    limit := c.Query("limit") // "" if absent

    // Headers
    auth := c.GetHeader("Authorization")

    // Response helpers
    c.JSON(http.StatusOK, gin.H{
        "id":   id,
        "page": page,
        "auth": auth,
    })
    // c.String(200, "text")
    // c.HTML(200, "template.html", data)
    // c.File("path/to/file")
    // c.Redirect(301, "/new-url")
    // c.AbortWithStatus(403)
    _ = limit
}
```

### Middleware (gin.HandlerFunc, c.Next, c.Abort)

```go
// Gin middleware signature: gin.HandlerFunc = func(*gin.Context)
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
            return // c.Abort() stops the chain; return exits this function
        }
        userID := validateToken(token)
        c.Set("userID", userID)  // store in context
        c.Next()                  // call next handler in chain
        // code here runs AFTER downstream handlers (post-processing)
    }
}

func LoggerMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next() // process request
        // post-processing
        slog.Info("request",
            "method", c.Request.Method,
            "path", c.Request.URL.Path,
            "status", c.Writer.Status(),
            "latency", time.Since(start),
        )
    }
}

// Apply globally
r := gin.New()
r.Use(LoggerMiddleware(), AuthMiddleware())

// Apply to specific route group
api := r.Group("/api/v1")
api.Use(AuthMiddleware())
api.GET("/profile", getProfile)
```

### Route Groups

```go
v1 := r.Group("/api/v1")
{
    users := v1.Group("/users")
    users.Use(AuthMiddleware())
    {
        users.GET("", listUsers)
        users.POST("", createUser)
        users.GET("/:id", getUser)
        users.PUT("/:id", updateUser)
        users.DELETE("/:id", deleteUser)
    }

    public := v1.Group("/public")
    {
        public.GET("/health", healthCheck)
        public.POST("/login", login)
    }
}
```

### JSON Binding and Validation

Gin integrates with `go-playground/validator` for struct validation via binding tags.

```go
type CreateUserRequest struct {
    Name     string `json:"name"     binding:"required,min=2,max=100"`
    Email    string `json:"email"    binding:"required,email"`
    Age      int    `json:"age"      binding:"required,gte=18,lte=120"`
    Role     string `json:"role"     binding:"oneof=admin user viewer"`
    Password string `json:"password" binding:"required,min=8"`
}

func createUser(c *gin.Context) {
    var req CreateUserRequest

    // ShouldBind — returns error, handler decides response
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    // MustBindWith — calls c.AbortWithStatus(400) on failure (less control)
    // Prefer ShouldBind in production code

    // After binding, req is validated
    user := createUserInDB(req)
    c.JSON(http.StatusCreated, user)
}

// Query param binding
type ListQuery struct {
    Page  int    `form:"page"  binding:"min=1"`
    Limit int    `form:"limit" binding:"min=1,max=100"`
    Sort  string `form:"sort"  binding:"oneof=asc desc"`
}

func listUsers(c *gin.Context) {
    var q ListQuery
    if err := c.ShouldBindQuery(&q); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
}
```

### Custom Validators

```go
import "github.com/go-playground/validator/v10"

// Register at startup
if v, ok := binding.Validator.Engine().(*validator.Validate); ok {
    v.RegisterValidation("slug", validateSlug)
}

func validateSlug(fl validator.FieldLevel) bool {
    slug := fl.Field().String()
    matched, _ := regexp.MatchString(`^[a-z0-9]+(?:-[a-z0-9]+)*$`, slug)
    return matched
}

// Use in struct
type Post struct {
    Slug string `json:"slug" binding:"required,slug"`
}
```

### Error Handling

```go
// Centralized error handling via gin.Recovery and custom error types
type APIError struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
}

func ErrorHandler() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Next()
        if len(c.Errors) > 0 {
            err := c.Errors.Last()
            switch e := err.Err.(type) {
            case *NotFoundError:
                c.JSON(http.StatusNotFound, APIError{404, e.Error()})
            case *ValidationError:
                c.JSON(http.StatusBadRequest, APIError{400, e.Error()})
            default:
                c.JSON(http.StatusInternalServerError, APIError{500, "internal error"})
            }
        }
    }
}

func handler(c *gin.Context) {
    user, err := getUser(c.Param("id"))
    if err != nil {
        c.Error(err) // attaches error; ErrorHandler middleware processes it
        c.Abort()
        return
    }
    c.JSON(200, user)
}
```

### CORS

```go
import "github.com/gin-contrib/cors"

r.Use(cors.New(cors.Config{
    AllowOrigins:     []string{"https://example.com"},
    AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
    AllowHeaders:     []string{"Authorization", "Content-Type"},
    ExposeHeaders:    []string{"Content-Length"},
    AllowCredentials: true,
    MaxAge:           12 * time.Hour,
}))
```

### File Upload

```go
func uploadFile(c *gin.Context) {
    // Single file
    file, err := c.FormFile("file")
    if err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }

    // Validate size and type
    if file.Size > 10<<20 { // 10 MB
        c.JSON(400, gin.H{"error": "file too large"})
        return
    }

    dst := filepath.Join("./uploads", filepath.Base(file.Filename))
    if err := c.SaveUploadedFile(file, dst); err != nil {
        c.JSON(500, gin.H{"error": "upload failed"})
        return
    }
    c.JSON(200, gin.H{"filename": file.Filename})
}

// Multi-file
func uploadMultiple(c *gin.Context) {
    form, _ := c.MultipartForm()
    files := form.File["files"]
    for _, file := range files {
        c.SaveUploadedFile(file, "./uploads/"+file.Filename)
    }
}
```

### HTML Rendering

```go
r := gin.Default()
r.LoadHTMLGlob("templates/**/*")

r.GET("/", func(c *gin.Context) {
    c.HTML(http.StatusOK, "index.html", gin.H{
        "title": "Home",
        "user":  currentUser,
    })
})
```

---

## 3. Fiber Framework

Fiber (`github.com/gofiber/fiber/v2`) is built on **fasthttp** — not `net/http`. This is the most important architectural distinction. Fiber cannot be used with standard `net/http` middleware, handlers, or clients without adapters.

### fasthttp vs net/http

| Aspect | net/http | fasthttp / Fiber |
|---|---|---|
| Allocation model | Allocates per-request objects | Reuses buffers via sync.Pool |
| Handler signature | `func(http.ResponseWriter, *http.Request)` | `func(*fiber.Ctx) error` |
| Middleware compatibility | Universal Go ecosystem | Fiber-specific (adapters exist but add overhead) |
| Streaming | Full support | Limited |
| WebSocket | `gorilla/websocket`, `nhooyr.io/websocket` | `gofiber/websocket` |
| HTTP/2 | Yes (stdlib) | Limited — fasthttp HTTP/2 support is experimental |

### Basic Setup

```go
import "github.com/gofiber/fiber/v2"

app := fiber.New(fiber.Config{
    Prefork:       false,          // see Prefork section below
    ServerHeader:  "Fiber",
    BodyLimit:     4 * 1024 * 1024, // 4 MB
    ReadTimeout:   5 * time.Second,
    WriteTimeout:  10 * time.Second,
    IdleTimeout:   120 * time.Second,
    ErrorHandler:  customErrorHandler,
})

app.Get("/users", listUsers)
app.Post("/users", createUser)
app.Get("/users/:id", getUser)
app.Get("/files/*", serveFiles) // wildcard

app.Listen(":8080")
```

### Routing and Middleware

```go
// Middleware — returns error or nil
func authMiddleware(c *fiber.Ctx) error {
    token := c.Get("Authorization")
    if token == "" {
        return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
            "error": "unauthorized",
        })
    }
    c.Locals("userID", extractUserID(token))
    return c.Next() // continue chain
}

// Route groups
api := app.Group("/api", authMiddleware)
v1 := api.Group("/v1")
v1.Get("/users", listUsers)
v1.Post("/users", createUser)

// Handler
func getUser(c *fiber.Ctx) error {
    id := c.Params("id")
    page := c.Query("page", "1")
    
    user, err := findUser(id)
    if err != nil {
        return fiber.NewError(fiber.StatusNotFound, "user not found")
    }
    return c.JSON(user)
    _ = page
}
```

### Prefork Mode

Prefork uses `SO_REUSEPORT` to spawn multiple OS processes sharing the same port — no GIL equivalent in Go, but this avoids cross-process goroutine scheduling for very high throughput on multi-core machines.

```go
app := fiber.New(fiber.Config{
    Prefork: true, // spawns runtime.NumCPU() processes
})
// Each process has its own Go runtime — no shared memory
// Incompatible with in-process state (caches, connection pools shared via process)
// Typically only beneficial under extreme load; measure before enabling
```

### Zero-Allocation Design

Fiber/fasthttp achieves zero allocation per request by:
- Reusing `*fasthttp.RequestCtx` objects via `sync.Pool`
- Avoiding `[]byte` → `string` conversions (unsafe pointer tricks)
- Byte-slice-based headers instead of `http.Header` map

**Critical implication**: You must not hold references to `*fiber.Ctx` after the handler returns. Any data you need to retain must be explicitly copied.

```go
func handler(c *fiber.Ctx) error {
    body := c.Body() // returns []byte — valid only during this request
    
    // WRONG — body slice is recycled after handler returns
    go func() { process(body) }()
    
    // CORRECT — copy before goroutine
    bodyCopy := make([]byte, len(body))
    copy(bodyCopy, body)
    go func() { process(bodyCopy) }()
    
    return c.SendString("ok")
}
```

### Fiber Limitations vs net/http

- No direct compatibility with `net/http` middleware (no `http.Handler`).
- HTTP/2 server push and cleartext h2c are not well-supported.
- WebSocket, SSE, and streaming APIs differ from the stdlib patterns.
- `net/http/httptest` cannot be used — use `app.Test()` instead.
- Standard Go profiling endpoints (`/debug/pprof`) require a separate adapter.
- `context.Context` is not natively threaded through — you use `c.Locals()` instead.

```go
// Testing with Fiber (cannot use httptest.NewRecorder)
func TestGetUser(t *testing.T) {
    app := setupApp()
    req := httptest.NewRequest("GET", "/users/123", nil)
    resp, err := app.Test(req, 1000) // timeout in ms
    require.NoError(t, err)
    assert.Equal(t, 200, resp.StatusCode)
}
```

---

## 4. Other Notable Frameworks

### Chi

`github.com/go-chi/chi/v5` — stdlib-compatible (uses `net/http.Handler`), rich middleware stack, clean API. Best choice when you want ergonomics close to Gin but full stdlib compatibility.

```go
import "github.com/go-chi/chi/v5"
import "github.com/go-chi/chi/v5/middleware"

r := chi.NewRouter()
r.Use(middleware.Logger)
r.Use(middleware.Recoverer)
r.Use(middleware.RequestID)
r.Use(middleware.RealIP)

r.Route("/api/v1", func(r chi.Router) {
    r.Use(authMiddleware) // group-scoped middleware
    r.Get("/users", listUsers)
    r.Post("/users", createUser)
    r.Route("/users/{id}", func(r chi.Router) {
        r.Get("/", getUser)
        r.Put("/", updateUser)
        r.Delete("/", deleteUser)
    })
})

// Path parameters
func getUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id") // uses context internally
    _ = id
}
```

### Echo

`github.com/labstack/echo/v4` — similar API to Gin, uses radix tree routing, strong built-in support for binding/validation, WebSocket, HTTP/2. Slightly higher allocation than Gin in benchmarks.

```go
import "github.com/labstack/echo/v4"
import "github.com/labstack/echo/v4/middleware"

e := echo.New()
e.Use(middleware.Logger())
e.Use(middleware.Recover())
e.Use(middleware.CORS())

e.GET("/users/:id", func(c echo.Context) error {
    id := c.Param("id")
    return c.JSON(http.StatusOK, map[string]string{"id": id})
})

// Binding
type CreateReq struct {
    Name  string `json:"name"  validate:"required"`
    Email string `json:"email" validate:"required,email"`
}

func createUser(c echo.Context) error {
    var req CreateReq
    if err := c.Bind(&req); err != nil {
        return echo.NewHTTPError(http.StatusBadRequest, err.Error())
    }
    if err := c.Validate(&req); err != nil {
        return err
    }
    return c.JSON(http.StatusCreated, req)
}
```

### gorilla/mux (Archived)

`github.com/gorilla/mux` was archived in December 2022. It remains widely used in existing codebases but receives no updates. Key features it offered (method matching, path params, regex constraints) are now available in stdlib (Go 1.22+). For new projects, prefer stdlib, Chi, or Gin.

```go
// gorilla/mux — still works, just archived
r := mux.NewRouter()
r.HandleFunc("/users/{id:[0-9]+}", getUser).Methods("GET")
// Migrating: use r.PathValue("id") with Go 1.22 stdlib instead
```

---

## 5. Go Patterns for Web Development

### Struct-Based Handlers and Dependency Injection

Go has no DI framework — inject dependencies via constructors. This is idiomatic and testable.

```go
// Define dependencies as interfaces for testability
type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, u *User) error
    List(ctx context.Context, page, limit int) ([]*User, error)
}

type EmailService interface {
    SendWelcome(ctx context.Context, email string) error
}

// Handler struct holds dependencies
type UserHandler struct {
    repo  UserRepository
    email EmailService
    log   *slog.Logger
}

// Constructor — plain function, no framework
func NewUserHandler(repo UserRepository, email EmailService, log *slog.Logger) *UserHandler {
    return &UserHandler{repo: repo, email: email, log: log}
}

// Register routes — handler method returns http.Handler
func (h *UserHandler) Routes() http.Handler {
    mux := http.NewServeMux()
    mux.HandleFunc("GET /", h.list)
    mux.HandleFunc("POST /", h.create)
    mux.HandleFunc("GET /{id}", h.get)
    return mux
}

// Wire everything in main()
func main() {
    db := mustOpenDB()
    repo := postgres.NewUserRepository(db)
    emailSvc := smtp.NewEmailService(os.Getenv("SMTP_HOST"))
    log := slog.New(slog.NewJSONHandler(os.Stdout, nil))

    userHandler := NewUserHandler(repo, emailSvc, log)

    mux := http.NewServeMux()
    mux.Handle("/api/users/", http.StripPrefix("/api/users", userHandler.Routes()))

    srv := &http.Server{Addr: ":8080", Handler: mux}
    srv.ListenAndServe()
}
```

### Interface-Based Mocking and httptest

```go
// Mock implementation for tests
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

// Table-driven tests with httptest
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
                return &mockUserRepo{users: map[string]*User{
                    "123": {ID: "123", Name: "Alice"},
                }}
            },
            wantStatus: http.StatusOK,
            wantBody:   `"name":"Alice"`,
        },
        {
            name: "not found",
            id:   "999",
            setupRepo: func() UserRepository {
                return &mockUserRepo{users: map[string]*User{}}
            },
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

### Error Handling — No Exceptions

Go uses error returns. Wrap errors with context; sentinel errors for behavior.

```go
// Sentinel errors
var (
    ErrNotFound   = errors.New("not found")
    ErrConflict   = errors.New("conflict")
    ErrForbidden  = errors.New("forbidden")
)

// Error wrapping with context
func (r *pgUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var u User
    err := r.db.QueryRowContext(ctx, `SELECT id, name, email FROM users WHERE id = $1`, id).
        Scan(&u.ID, &u.Name, &u.Email)
    if err == sql.ErrNoRows {
        return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
    }
    if err != nil {
        return nil, fmt.Errorf("findByID: %w", err)
    }
    return &u, nil
}

// Handler maps errors to HTTP status
func (h *UserHandler) get(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id")
    user, err := h.repo.FindByID(r.Context(), id)
    if err != nil {
        switch {
        case errors.Is(err, ErrNotFound):
            http.Error(w, "user not found", http.StatusNotFound)
        case errors.Is(err, ErrForbidden):
            http.Error(w, "forbidden", http.StatusForbidden)
        default:
            h.log.Error("get user", "err", err, "id", id)
            http.Error(w, "internal error", http.StatusInternalServerError)
        }
        return
    }
    encodeJSON(w, user)
}

func encodeJSON(w http.ResponseWriter, v any) {
    w.Header().Set("Content-Type", "application/json")
    if err := json.NewEncoder(w).Encode(v); err != nil {
        // headers already sent — log only
        slog.Error("encode json", "err", err)
    }
}
```

### Middleware Composition Pattern

```go
// Middleware type alias for clarity
type Middleware func(http.Handler) http.Handler

// Stack applies middlewares in order (first = outermost)
func Stack(middlewares ...Middleware) Middleware {
    return func(next http.Handler) http.Handler {
        for i := len(middlewares) - 1; i >= 0; i-- {
            next = middlewares[i](next)
        }
        return next
    }
}

// Usage
stack := Stack(
    RequestID,
    RealIP,
    Logger,
    Recoverer,
    RateLimit(100),
    CORS(corsConfig),
)

mux.Handle("/api/", stack(apiHandler))
```

### Context Propagation

```go
// Always pass context through call stack — never store in struct
func (s *Service) processOrder(ctx context.Context, orderID string) error {
    // Span context flows through
    user, err := s.userRepo.FindByID(ctx, orderID)
    if err != nil {
        return fmt.Errorf("processOrder: %w", err)
    }

    // Context cancellation propagates to all downstream calls
    if err := s.paymentSvc.Charge(ctx, user, amount); err != nil {
        return fmt.Errorf("charge: %w", err)
    }
    return nil
}

// Timeout for specific operations
func (h *Handler) expensiveOp(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
    defer cancel()

    result, err := h.svc.Expensive(ctx)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            http.Error(w, "timeout", http.StatusGatewayTimeout)
            return
        }
        http.Error(w, "error", http.StatusInternalServerError)
        return
    }
    encodeJSON(w, result)
}
```

---

## 6. Database Access

### database/sql — Standard Interface

```go
import "database/sql"
import _ "github.com/lib/pq" // postgres driver (registers itself)

// sql.DB is a connection pool — safe for concurrent use
db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
if err != nil {
    log.Fatal(err)
}

// Configure pool
db.SetMaxOpenConns(25)
db.SetMaxIdleConns(10)
db.SetConnMaxLifetime(5 * time.Minute)
db.SetConnMaxIdleTime(1 * time.Minute)

// Verify connectivity
if err := db.PingContext(ctx); err != nil {
    log.Fatal(err)
}
```

### sqlx — Struct Scanning

`github.com/jmoiron/sqlx` extends `database/sql` with struct scanning, named queries, and in-clause helpers. It uses the same `sql.DB` pool underneath.

```go
import "github.com/jmoiron/sqlx"

db, _ := sqlx.Connect("postgres", dsn)

type User struct {
    ID        string    `db:"id"`
    Name      string    `db:"name"`
    Email     string    `db:"email"`
    CreatedAt time.Time `db:"created_at"`
}

// Get single row into struct
var user User
err := db.GetContext(ctx, &user, `SELECT * FROM users WHERE id = $1`, id)

// Select multiple rows
var users []User
err = db.SelectContext(ctx, &users,
    `SELECT * FROM users WHERE active = true ORDER BY created_at DESC LIMIT $1`, limit)

// Named queries (prevent positional arg mistakes)
_, err = db.NamedExecContext(ctx,
    `INSERT INTO users (name, email) VALUES (:name, :email)`,
    user)
```

### GORM — ORM

`gorm.io/gorm` — full ORM with migrations, associations, hooks, scopes.

```go
import "gorm.io/gorm"
import "gorm.io/driver/postgres"

db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
    Logger: logger.Default.LogMode(logger.Info),
})

// Auto-migrate
db.AutoMigrate(&User{}, &Post{})

// CRUD
db.WithContext(ctx).Create(&user)
db.WithContext(ctx).First(&user, "id = ?", id)
db.WithContext(ctx).Save(&user)
db.WithContext(ctx).Delete(&user)

// Associations
type Post struct {
    gorm.Model
    Title   string
    UserID  uint
    User    User
    Tags    []Tag `gorm:"many2many:post_tags;"`
}

db.WithContext(ctx).Preload("User").Preload("Tags").Find(&posts)

// Scopes
func Paginate(page, limit int) func(*gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        offset := (page - 1) * limit
        return db.Offset(offset).Limit(limit)
    }
}
db.WithContext(ctx).Scopes(Paginate(2, 10)).Find(&users)
```

### pgx — PostgreSQL Native Driver

`github.com/jackc/pgx/v5` — high-performance native Postgres driver. Preferred over `lib/pq` for Postgres-specific features (LISTEN/NOTIFY, COPY, typed arrays, prepared statements).

```go
import "github.com/jackc/pgx/v5/pgxpool"

pool, err := pgxpool.New(ctx, os.Getenv("DATABASE_URL"))
// pgxpool handles connection pooling natively

row := pool.QueryRow(ctx, `SELECT id, name FROM users WHERE id = $1`, id)
var id, name string
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
// database/sql transactions
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

---

## 7. Deployment

### Static Binary

Go compiles to a single static binary by default (when CGO is disabled). This is the primary deployment artifact.

```bash
# Disable CGO for fully static binary (required for scratch images)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o server ./cmd/server

# -s: strip symbol table
# -w: strip DWARF debug info
# Results in ~5-15 MB binary for a typical service
```

### Cross-Compilation

```bash
# Build for multiple targets from one machine
GOOS=linux   GOARCH=amd64  go build -o server-linux-amd64   ./cmd/server
GOOS=linux   GOARCH=arm64  go build -o server-linux-arm64   ./cmd/server
GOOS=darwin  GOARCH=arm64  go build -o server-darwin-arm64  ./cmd/server
GOOS=windows GOARCH=amd64  go build -o server-windows.exe   ./cmd/server
```

### Docker — Scratch and Distroless

```dockerfile
# Multi-stage build — scratch image
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server

# scratch — absolute minimum, no shell, no libc
FROM scratch
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]

# distroless — adds nonroot user, tzdata; easier debugging
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 3
  selector:
    matchLabels: {app: api-server}
  template:
    metadata:
      labels: {app: api-server}
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
          periodSeconds: 10
        readinessProbe:
          httpGet: {path: /readyz, port: 8080}
          initialDelaySeconds: 3
          periodSeconds: 5
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 5"] # drain before SIGTERM
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

# Graceful shutdown — systemd sends SIGTERM, then SIGKILL after TimeoutStopSec
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

### Health Check Endpoints

```go
// Liveness — is the process alive?
mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
})

// Readiness — is the service ready to accept traffic?
mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
    if err := db.PingContext(r.Context()); err != nil {
        http.Error(w, "db unhealthy", http.StatusServiceUnavailable)
        return
    }
    w.WriteHeader(http.StatusOK)
})
```

---

## 8. Performance

### Goroutine-Per-Request Model

Go's runtime schedules goroutines on OS threads (M:N scheduling). Each HTTP request gets its own goroutine. The runtime handles goroutine multiplexing, so you can handle tens of thousands of concurrent connections with modest memory — each goroutine starts with a ~8KB stack that grows as needed.

```
net/http listener
  └─ Accept() → goroutine per connection
       └─ goroutine per request (HTTP/2: multiplexed on one connection goroutine)
```

This model means blocking I/O in handlers is fine — the Go scheduler parks the goroutine and runs others. You do not need async/await or callbacks.

### Connection Pooling

```go
// sql.DB pool tuning — measure, don't guess
db.SetMaxOpenConns(25)           // max connections to Postgres
db.SetMaxIdleConns(10)           // idle connections kept open
db.SetConnMaxLifetime(5 * time.Minute)  // recycle connections
db.SetConnMaxIdleTime(1 * time.Minute)  // drop idle connections

// Too many open conns → Postgres rejects; too few → queueing latency
// Rule of thumb: start with 10-25 per app instance
```

### pprof Profiling

```go
import _ "net/http/pprof" // side-effect import registers endpoints

// In development server (separate port — never expose to internet)
go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()

// Collect profiles:
// go tool pprof http://localhost:6060/debug/pprof/heap
// go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
// go tool pprof http://localhost:6060/debug/pprof/goroutine

// Trace
// curl -o trace.out http://localhost:6060/debug/pprof/trace?seconds=5
// go tool trace trace.out
```

### Benchmarking

```go
// Benchmark handler
func BenchmarkUserHandler_Get(b *testing.B) {
    h := NewUserHandler(&inMemoryRepo{}, &noopEmailSvc{}, slog.Default())
    srv := httptest.NewServer(h.Routes())
    defer srv.Close()

    client := &http.Client{Transport: &http.Transport{
        MaxIdleConnsPerHost: 100,
    }}

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
// -benchmem shows allocations per op — key for identifying GC pressure
```

### Allocation Reduction Techniques

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

// Avoid interface conversions in hot paths
// Avoid fmt.Sprintf for simple string building (use strings.Builder or strconv)
// Use encoding/json with pre-allocated structs rather than map[string]any
```

### GC Considerations

Go's GC is concurrent and low-latency (sub-millisecond pauses typical). For request handling:
- Short-lived allocations (per-request objects) are collected efficiently.
- Large, long-lived objects (caches, pools) create GC pressure — use `sync.Pool` or pre-allocate.
- `GOGC` environment variable controls GC frequency (default 100 = GC when heap doubles). Set higher (e.g., 200) to trade memory for CPU.
- `GOMEMLIMIT` (Go 1.19+) sets a soft memory limit, triggering more aggressive GC before OOM.

```bash
# Production tuning example
GOGC=150 GOMEMLIMIT=512MiB ./server
```

---

## 9. Framework Comparison Matrix

| Feature | net/http (1.22+) | Gin | Fiber | Chi | Echo |
|---|---|---|---|---|---|
| stdlib compatible | Yes | Yes | No (fasthttp) | Yes | Yes |
| Path parameters | Yes (`r.PathValue`) | Yes (`c.Param`) | Yes (`c.Params`) | Yes (`chi.URLParam`) | Yes (`c.Param`) |
| Method routing | Yes | Yes | Yes | Yes | Yes |
| Wildcard routing | Yes | Yes | Yes | Yes | Yes |
| Middleware | `func(Handler)Handler` | `gin.HandlerFunc` | `func(*Ctx)error` | `func(Handler)Handler` | `echo.MiddlewareFunc` |
| JSON binding | Manual | Yes (validator) | Yes | Manual | Yes |
| Routing algorithm | Trie (stdlib) | Radix tree | Radix tree | Radix tree | Radix tree |
| HTTP/2 | Yes | Yes | Experimental | Yes | Yes |
| WebSocket | stdlib/libs | gorilla/ws | gofiber/ws | nhooyr/ws | labstack/ws |
| Test support | httptest | httptest | app.Test() | httptest | httptest |
| Active maintenance | Yes | Yes | Yes | Yes | Yes |
| gorilla/mux | Archived — migrate away |||||

### Go Version Routing Comparison

| Capability | Go 1.21 | Go 1.22 | Go 1.23 | Go 1.24 |
|---|---|---|---|---|
| Method matching | No | Yes (`GET /path`) | Yes | Yes |
| Path wildcards | No | Yes (`{id}`) | Yes | Yes |
| Subtree wildcards | Trailing `/` only | Yes (`{path...}`) | Yes | Yes |
| `r.PathValue()` | No | Yes | Yes | Yes |
| Conflict detection | Silent | Basic | Strict (panics) | Strict + improved |
| Redirect behavior | Basic | Improved | Improved | Precise |

### When to Choose What

- **net/http stdlib**: Minimal dependencies, library authors, services consumed by diverse clients, maximum stdlib compatibility. Go 1.22+ makes it viable for most APIs without third-party routing.
- **Gin**: Highest adoption, large ecosystem, fast prototyping, teams familiar with Express/Flask patterns. Best when you want binding + validation out of the box.
- **Chi**: When you want stdlib handler compatibility but better routing ergonomics than raw ServeMux. Ideal for projects that mix stdlib middleware from the ecosystem.
- **Fiber**: Extreme throughput requirements (benchmarks show 2-3x net/http for simple cases), teams coming from Node.js/Express, acceptable to trade stdlib compatibility for performance.
- **Echo**: Solid alternative to Gin with slightly different API; strong WebSocket and SSE support.
- **gorilla/mux**: Only for maintaining existing codebases. Do not start new projects with it.
