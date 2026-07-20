# Go Web Frameworks -- Architecture Reference

## net/http Standard Library

### ServeMux -- Go 1.22+ Enhanced Routing

Go 1.22 fundamentally changed `net/http.ServeMux` by adding method matching and path wildcards. Before 1.22, ServeMux had no method matching, no path parameters, and only trailing-slash subtree matching.

#### Pattern Syntax (Go 1.22+)

```go
mux := http.NewServeMux()

// Method prefix in pattern
mux.HandleFunc("GET /users", listUsers)
mux.HandleFunc("POST /users", createUser)
mux.HandleFunc("GET /users/{id}", getUser)       // {id} is a named wildcard
mux.HandleFunc("PUT /users/{id}", updateUser)
mux.HandleFunc("DELETE /users/{id}", deleteUser)

// Subtree wildcard (matches rest of URL path)
mux.HandleFunc("GET /files/{path...}", serveFile)

func getUser(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("id") // new in Go 1.22
    fmt.Fprintf(w, "user: %s", id)
}
```

#### Precedence Rules

- More specific patterns take priority over less specific ones.
- A method-qualified pattern (`GET /foo`) is more specific than an unqualified one (`/foo`).
- An exact segment match beats a wildcard match.
- Patterns ending in `{...}` (subtree wildcards) are lower priority than exact or single-segment wildcards.

```go
mux.HandleFunc("GET /api/users/me", getCurrentUser)  // beats {id} for "me"
mux.HandleFunc("GET /api/users/{id}", getUser)
```

#### Go 1.23 -- Conflict Detection

Go 1.23 made conflict detection strict: if two patterns would both match the same request with no clear precedence, `ServeMux` panics on registration instead of silently shadowing.

```go
// Go 1.23 panics at startup if patterns conflict ambiguously:
mux.HandleFunc("/a/{x}/b", h1)
mux.HandleFunc("/a/b/{x}", h2) // OK -- these are unambiguous
```

#### Go 1.24 -- Performance Improvements

Go 1.24 improved the internal matching algorithm's performance and fixed trailing-slash redirect edge cases. No new syntax.

### Handler and HandlerFunc

```go
// http.Handler interface -- the fundamental building block
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}

// http.HandlerFunc -- adapter to use a function as Handler
type HandlerFunc func(ResponseWriter, *Request)
func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) { f(w, r) }

// Struct-based handler -- preferred for dependency injection
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
```

### Middleware Pattern

The canonical Go middleware signature is `func(http.Handler) http.Handler`. This composes without any framework dependency.

```go
// Logger middleware
func Logger(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
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

type responseWriter struct {
    http.ResponseWriter
    status int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.status = code
    rw.ResponseWriter.WriteHeader(code)
}

// Auth middleware -- short-circuit by not calling next
func RequireAuth(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if !validateToken(token) {
            http.Error(w, "unauthorized", http.StatusUnauthorized)
            return
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

handler := Chain(userHandler, Logger, RequireAuth, RateLimit)
```

### context.Context Propagation

`context.Context` flows through every request handler. Use it for cancellation, deadlines, and request-scoped values.

```go
// Storing values in context -- use unexported key type to avoid collisions
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
            return // client disconnected -- do not write response
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

    // Timeouts -- critical for production
    ReadTimeout:       5 * time.Second,
    ReadHeaderTimeout: 2 * time.Second,
    WriteTimeout:      10 * time.Second,
    IdleTimeout:       120 * time.Second,

    MaxHeaderBytes: 1 << 20, // 1 MB

    TLSConfig: &tls.Config{
        MinVersion:       tls.VersionTLS12,
        CurvePreferences: []tls.CurveID{tls.X25519, tls.CurveP256},
    },
}
```

### Graceful Shutdown

```go
func run(ctx context.Context) error {
    srv := &http.Server{Addr: ":8080", Handler: buildRouter()}

    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    shutdownCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    return srv.Shutdown(shutdownCtx)
}
```

### HTTP/2 Support

```go
// HTTP/2 is automatic with TLS via ListenAndServeTLS
srv := &http.Server{Addr: ":443", Handler: mux}
srv.ListenAndServeTLS("cert.pem", "key.pem")

// HTTP/2 cleartext (h2c) -- for internal services without TLS
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
```

---

## Gin Framework

Gin uses an httprouter-based radix tree for routing. With Go 1.22's improved stdlib, the routing performance gap narrowed for simple cases, but Gin's ecosystem and ergonomics (binding, validation, error handling) remain compelling.

### Router

```go
r := gin.Default() // includes Logger and Recovery middleware
// gin.New() -- bare router, no default middleware

r.GET("/users", listUsers)
r.POST("/users", createUser)
r.GET("/users/:id", getUser)       // :id -- named parameter
r.GET("/files/*path", serveFiles)  // *path -- wildcard (catches all)
```

### gin.Context

`*gin.Context` combines the request, response, params, and helpers in a single object.

```go
func getUser(c *gin.Context) {
    id := c.Param("id")
    page := c.DefaultQuery("page", "1")
    auth := c.GetHeader("Authorization")

    c.JSON(http.StatusOK, gin.H{"id": id, "page": page})
    // Also: c.String(), c.HTML(), c.File(), c.Redirect()
    // c.AbortWithStatus(403) -- stop chain
}
```

### Middleware

```go
// Gin middleware signature: gin.HandlerFunc = func(*gin.Context)
func AuthMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
            return
        }
        c.Set("userID", validateToken(token))
        c.Next() // call next handler in chain
        // code here runs AFTER downstream handlers (post-processing)
    }
}

// Apply globally
r := gin.New()
r.Use(LoggerMiddleware(), AuthMiddleware())

// Apply to route group
api := r.Group("/api/v1")
api.Use(AuthMiddleware())
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
    }

    public := v1.Group("/public")
    {
        public.GET("/health", healthCheck)
    }
}
```

### JSON Binding and Validation

Gin integrates with `go-playground/validator` via binding tags.

```go
type CreateUserRequest struct {
    Name     string `json:"name"     binding:"required,min=2,max=100"`
    Email    string `json:"email"    binding:"required,email"`
    Age      int    `json:"age"      binding:"required,gte=18,lte=120"`
    Role     string `json:"role"     binding:"oneof=admin user viewer"`
}

func createUser(c *gin.Context) {
    var req CreateUserRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    // req is validated
}

// Query param binding
type ListQuery struct {
    Page  int    `form:"page"  binding:"min=1"`
    Limit int    `form:"limit" binding:"min=1,max=100"`
    Sort  string `form:"sort"  binding:"oneof=asc desc"`
}
```

### Error Handling

```go
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
                c.JSON(404, APIError{404, e.Error()})
            case *ValidationError:
                c.JSON(400, APIError{400, e.Error()})
            default:
                c.JSON(500, APIError{500, "internal error"})
            }
        }
    }
}

func handler(c *gin.Context) {
    user, err := getUser(c.Param("id"))
    if err != nil {
        c.Error(err) // attaches error; ErrorHandler processes it
        c.Abort()
        return
    }
    c.JSON(200, user)
}
```

---

## Fiber Framework

Fiber is built on **fasthttp** -- not `net/http`. This is the most important architectural distinction. Fiber cannot use standard `net/http` middleware, handlers, or `httptest` without adapters.

### fasthttp vs net/http

| Aspect | net/http | fasthttp / Fiber |
|---|---|---|
| Allocation model | Allocates per-request objects | Reuses buffers via sync.Pool |
| Handler signature | `func(http.ResponseWriter, *http.Request)` | `func(*fiber.Ctx) error` |
| Middleware compatibility | Universal Go ecosystem | Fiber-specific only |
| Streaming | Full support | Limited |
| HTTP/2 | Yes | Experimental |
| Testing | `httptest` | `app.Test()` |

### Setup and Routing

```go
app := fiber.New(fiber.Config{
    Prefork:      false,
    BodyLimit:    4 * 1024 * 1024,
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    ErrorHandler: customErrorHandler,
})

app.Get("/users", listUsers)
app.Post("/users", createUser)
app.Get("/users/:id", getUser)

api := app.Group("/api", authMiddleware)
v1 := api.Group("/v1")
v1.Get("/users", listUsers)
```

### Middleware

```go
func authMiddleware(c *fiber.Ctx) error {
    token := c.Get("Authorization")
    if token == "" {
        return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "unauthorized"})
    }
    c.Locals("userID", extractUserID(token))
    return c.Next()
}
```

### Zero-Allocation Design -- Critical Implications

Fiber/fasthttp achieves zero allocation per request by reusing `*fasthttp.RequestCtx` objects via `sync.Pool`. You **must not hold references** to `*fiber.Ctx` or its data after the handler returns.

```go
func handler(c *fiber.Ctx) error {
    body := c.Body() // valid only during this request

    // WRONG -- body slice is recycled after handler returns
    go func() { process(body) }()

    // CORRECT -- copy before goroutine
    bodyCopy := make([]byte, len(body))
    copy(bodyCopy, body)
    go func() { process(bodyCopy) }()

    return c.SendString("ok")
}
```

### Prefork Mode

Uses `SO_REUSEPORT` to spawn multiple OS processes sharing the same port. Each process has its own Go runtime with no shared memory. Only beneficial under extreme load -- measure before enabling.

### Fiber Limitations vs net/http

- No direct `http.Handler` compatibility
- HTTP/2 server push and h2c not well-supported
- `net/http/httptest` cannot be used -- use `app.Test()`
- `context.Context` not natively threaded through -- use `c.Locals()`
- pprof endpoints require a separate adapter

---

## Other Frameworks

### Chi

stdlib-compatible (`net/http.Handler`), rich middleware stack, clean API. Best when you want ergonomics close to Gin with full stdlib compatibility.

```go
r := chi.NewRouter()
r.Use(middleware.Logger, middleware.Recoverer, middleware.RequestID)

r.Route("/api/v1", func(r chi.Router) {
    r.Use(authMiddleware)
    r.Get("/users", listUsers)
    r.Route("/users/{id}", func(r chi.Router) {
        r.Get("/", getUser)
        r.Put("/", updateUser)
        r.Delete("/", deleteUser)
    })
})

func getUser(w http.ResponseWriter, r *http.Request) {
    id := chi.URLParam(r, "id")
}
```

### Echo

Similar API to Gin, uses radix tree routing, strong binding/validation, WebSocket, HTTP/2. Slightly higher allocation than Gin.

```go
e := echo.New()
e.Use(middleware.Logger(), middleware.Recover(), middleware.CORS())

e.GET("/users/:id", func(c echo.Context) error {
    id := c.Param("id")
    return c.JSON(http.StatusOK, map[string]string{"id": id})
})
```

### gorilla/mux (Archived)

Archived December 2022. Still works in existing codebases but receives no updates. All features it offered (method matching, path params, regex) are now in stdlib (Go 1.22+). Do not use for new projects.

---

## Handler Patterns

### Struct-Based Handlers (Dependency Injection)

```go
type UserHandler struct {
    repo  UserRepository
    email EmailService
    log   *slog.Logger
}

func NewUserHandler(repo UserRepository, email EmailService, log *slog.Logger) *UserHandler {
    return &UserHandler{repo: repo, email: email, log: log}
}

func (h *UserHandler) Routes() http.Handler {
    mux := http.NewServeMux()
    mux.HandleFunc("GET /", h.list)
    mux.HandleFunc("POST /", h.create)
    mux.HandleFunc("GET /{id}", h.get)
    return mux
}
```

### Closure-Based Handlers

```go
func makeGetUser(repo UserRepository) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        user, err := repo.FindByID(r.Context(), r.PathValue("id"))
        // ...
    }
}
```

### Middleware Composition

```go
type Middleware func(http.Handler) http.Handler

func Stack(middlewares ...Middleware) Middleware {
    return func(next http.Handler) http.Handler {
        for i := len(middlewares) - 1; i >= 0; i-- {
            next = middlewares[i](next)
        }
        return next
    }
}

stack := Stack(RequestID, RealIP, Logger, Recoverer, RateLimit(100))
mux.Handle("/api/", stack(apiHandler))
```

---

## Goroutine-Per-Request Model

Go's runtime schedules goroutines on OS threads (M:N scheduling). Each HTTP request gets its own goroutine. The runtime handles multiplexing, so tens of thousands of concurrent connections work with modest memory (~8KB initial stack per goroutine, grows as needed).

```
net/http listener
  Accept() -> goroutine per connection
    -> goroutine per request (HTTP/2: multiplexed on one connection goroutine)
```

Blocking I/O in handlers is fine -- the Go scheduler parks the goroutine and runs others. No async/await or callbacks needed.

---

## Framework Comparison Matrix

| Feature | net/http (1.22+) | Gin | Fiber | Chi | Echo |
|---|---|---|---|---|---|
| stdlib compatible | Yes | Yes | No (fasthttp) | Yes | Yes |
| Path parameters | `r.PathValue` | `c.Param` | `c.Params` | `chi.URLParam` | `c.Param` |
| Method routing | Yes | Yes | Yes | Yes | Yes |
| Middleware | `func(Handler)Handler` | `gin.HandlerFunc` | `func(*Ctx)error` | `func(Handler)Handler` | `echo.MiddlewareFunc` |
| JSON binding | Manual | Yes (validator) | Yes | Manual | Yes |
| Routing algorithm | Trie | Radix tree | Radix tree | Radix tree | Radix tree |
| HTTP/2 | Yes | Yes | Experimental | Yes | Yes |
| Test support | httptest | httptest | app.Test() | httptest | httptest |

### Go Version Routing Evolution

| Capability | Go 1.21 | Go 1.22 | Go 1.23 | Go 1.24 |
|---|---|---|---|---|
| Method matching | No | Yes (`GET /path`) | Yes | Yes |
| Path wildcards | No | Yes (`{id}`) | Yes | Yes |
| Subtree wildcards | Trailing `/` only | Yes (`{path...}`) | Yes | Yes |
| `r.PathValue()` | No | Yes | Yes | Yes |
| Conflict detection | Silent | Basic | Strict (panics) | Strict + improved |
