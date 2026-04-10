# ASP.NET Core Web API Architecture — Cross-Version Reference

> Covers .NET 6 through .NET 10. Version-specific features are tagged inline.
> Audience: senior .NET developers debugging and architecting production systems.

---

## Table of Contents

1. [Request Pipeline & Middleware](#1-request-pipeline--middleware)
2. [Dependency Injection](#2-dependency-injection)
3. [Routing](#3-routing)
4. [Kestrel Server](#4-kestrel-server)
5. [Model Binding & Validation](#5-model-binding--validation)
6. [Filters](#6-filters)
7. [Configuration System](#7-configuration-system)
8. [Hosting Models](#8-hosting-models)
9. [Controllers vs Minimal APIs](#9-controllers-vs-minimal-apis)

---

## 1. Request Pipeline & Middleware

### How the Pipeline Works

ASP.NET Core processes every HTTP request through a linear chain of middleware components. Each component receives the `HttpContext`, can inspect and modify the request and response, optionally calls `next()` to pass control downstream, and can act on the response on the way back out. The pipeline is bidirectional — middleware runs in registration order on the way in, and in reverse on the way out.

```csharp
// The fundamental middleware delegate signature
public delegate Task RequestDelegate(HttpContext context);

// Convention-based middleware
public class MyMiddleware
{
    private readonly RequestDelegate _next;

    public MyMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        // Before — runs on request going IN
        await _next(context);
        // After — runs on response coming OUT
    }
}

// IMiddleware interface (strongly-typed, DI-friendly, preferred for complex middleware)
public class MyMiddleware : IMiddleware
{
    private readonly IMyService _service;

    public MyMiddleware(IMyService service) => _service = service;

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        await next(context);
    }
}

// Register IMiddleware implementations as services first
builder.Services.AddScoped<MyMiddleware>();
app.UseMiddleware<MyMiddleware>();
```

**Difference: Convention-based vs IMiddleware**
- Convention-based: constructor receives `RequestDelegate`; services injected into `Invoke`/`InvokeAsync` parameters (supports scoped services).
- `IMiddleware`: interface-based; resolved from DI each request; must be registered as a service; cleaner and testable.

### Built-in Middleware — Correct Production Order

Microsoft's recommended order (deviation causes bugs — especially around auth and CORS):

```csharp
var app = builder.Build();

// 1. Exception handler / developer page — must be FIRST to catch all downstream exceptions
if (app.Environment.IsDevelopment())
    app.UseDeveloperExceptionPage();
else
    app.UseExceptionHandler("/error");

// 2. HSTS — adds Strict-Transport-Security header
app.UseHsts();

// 3. HTTPS redirect — before any auth so redirects happen on insecure requests
app.UseHttpsRedirection();

// 4. Static files — short-circuit before routing (no auth on static files by default)
app.UseStaticFiles();

// 5. Routing — MUST come before CORS, Auth, and Endpoints
app.UseRouting();

// 6. CORS — MUST be after UseRouting and before UseAuthorization
app.UseCors("MyPolicy");

// 7. Authentication — identifies the user
app.UseAuthentication();

// 8. Authorization — checks what the user can do (requires routing to know the endpoint)
app.UseAuthorization();

// 9. Custom middleware (request-specific logic)
app.UseMiddleware<MyMiddleware>();

// 10. Endpoints (controllers, minimal API endpoints, health checks, etc.)
app.MapControllers();
app.MapHealthChecks("/health");

app.Run();
```

**Critical ordering rules:**
- `UseExceptionHandler` first — otherwise exceptions thrown before it are unhandled.
- `UseStaticFiles` before `UseRouting` — avoids routing overhead for static content.
- `UseRouting` before `UseCors` — CORS policy evaluation needs the matched endpoint.
- `UseAuthentication` before `UseAuthorization` — auth must establish identity before checking permissions.
- `UseCors` before `UseAuthentication` — preflight OPTIONS requests must not require auth.

### Pipeline Branching: Map, MapWhen, UseWhen

```csharp
// Map — branch on URL path prefix; branch does NOT rejoin main pipeline
app.Map("/api/legacy", legacyApp =>
{
    legacyApp.UseMiddleware<LegacyMiddleware>();
    legacyApp.Run(async ctx => await ctx.Response.WriteAsync("Legacy branch"));
});

// MapWhen — branch on any HttpContext predicate; branch does NOT rejoin
app.MapWhen(ctx => ctx.Request.Headers.ContainsKey("X-Special"), specialApp =>
{
    specialApp.UseMiddleware<SpecialMiddleware>();
});

// UseWhen — branch on predicate; branch REJOINS main pipeline if not terminated
app.UseWhen(
    ctx => ctx.Request.Path.StartsWithSegments("/api"),
    apiApp => apiApp.UseMiddleware<ApiLoggingMiddleware>()
);
// Execution continues in main pipeline after UseWhen branch
```

**Key distinction:** `Map`/`MapWhen` create terminal forks (the branch handles the request entirely). `UseWhen` creates a conditional detour — execution returns to the main pipeline unless the branch short-circuits.

### Middleware vs Filters

| Concern | Middleware | Filters |
|---|---|---|
| Scope | Every HTTP request | MVC/controller/action scope only |
| Context | `HttpContext` only | `ActionExecutingContext`, `ActionExecutedContext`, etc. |
| Access to routing | No (before routing) | Yes (after routing, endpoint known) |
| Access to model state | No | Yes |
| Registration | `app.UseXxx()` | Attribute, global filter, or service filter |
| Use for | Auth, CORS, logging, exceptions, compression | Validation, caching, response formatting, audit logging per-action |

**Rule of thumb:** Cross-cutting concerns that apply to all requests and don't need MVC context → middleware. Concerns that need routing/model binding context or are scoped to specific controllers/actions → filters.

### Short-Circuit Patterns

```csharp
// Run() — terminal middleware, never calls next
app.Run(async context =>
{
    await context.Response.WriteAsync("Terminal response");
});

// Short-circuit inside middleware
public async Task InvokeAsync(HttpContext context)
{
    if (!context.Request.Headers.ContainsKey("X-API-Key"))
    {
        context.Response.StatusCode = 401;
        return; // Do NOT call next
    }
    await _next(context);
}
```

---

## 2. Dependency Injection

### Built-in DI Container

ASP.NET Core ships with `Microsoft.Extensions.DependencyInjection` — a conforming container. For advanced scenarios (Autofac, StructureMap, etc.), it integrates via `IServiceProviderFactory<TContainerBuilder>`.

Key interfaces:
- `IServiceCollection` — the registration contract (builder phase)
- `IServiceProvider` — the resolution contract (runtime phase)
- `IServiceScope` / `IServiceScopeFactory` — create child scopes

### Service Lifetimes

```csharp
// Transient — new instance every time it's requested
services.AddTransient<IEmailSender, SmtpEmailSender>();

// Scoped — one instance per HTTP request (per DI scope)
services.AddScoped<IOrderRepository, EfOrderRepository>();

// Singleton — one instance for the entire application lifetime
services.AddSingleton<IMemoryCache, MemoryCache>();
```

**Captive dependency trap:** Never inject a `Scoped` or `Transient` service into a `Singleton` — the short-lived service gets captured and lives as long as the singleton. ASP.NET Core's scope validation (enabled by default in Development) will throw `InvalidOperationException` at startup.

```csharp
// Enable scope validation in all environments (recommended for CI)
builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateScopes = true;
    options.ValidateOnBuild = true; // .NET 6+: validates at build time
});
```

### Keyed Services (.NET 8+)

Register multiple implementations of the same interface, distinguished by a key:

```csharp
// Registration
services.AddKeyedSingleton<ICache, MemoryCache>("memory");
services.AddKeyedSingleton<ICache, RedisCache>("redis");
services.AddKeyedScoped<IPaymentProcessor, StripeProcessor>("stripe");
services.AddKeyedScoped<IPaymentProcessor, PayPalProcessor>("paypal");

// Constructor injection — use [FromKeyedServices]
public class OrderService
{
    public OrderService(
        [FromKeyedServices("redis")] ICache cache,
        [FromKeyedServices("stripe")] IPaymentProcessor payment)
    { }
}

// Manual resolution
var cache = serviceProvider.GetRequiredKeyedService<ICache>("redis");
```

**Namespace:** `Microsoft.Extensions.DependencyInjection` (no extra package needed in .NET 8+).

### Open Generic Registration

Register a generic interface/implementation once for all type arguments:

```csharp
// Register open generic — works for IRepository<Customer>, IRepository<Order>, etc.
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
services.AddSingleton(typeof(ILogger<>), typeof(Logger<>)); // Already done by AddLogging

// Closed generic takes precedence over open generic
services.AddScoped<IRepository<Customer>, CachedCustomerRepository>();
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));
// IRepository<Customer> → CachedCustomerRepository
// IRepository<Order>    → EfRepository<Order>
```

### Factory Pattern

```csharp
// Simple factory delegate
services.AddScoped<IOrderService>(sp =>
{
    var config = sp.GetRequiredService<IOptions<OrderConfig>>().Value;
    var repo = sp.GetRequiredService<IOrderRepository>();
    return new OrderService(repo, config.MaxRetries);
});

// Named factory (pre-.NET 8 pattern for keyed-like behavior)
services.AddSingleton<Func<string, ICache>>(sp => key => key switch
{
    "memory" => sp.GetRequiredService<MemoryCache>(),
    "redis"  => sp.GetRequiredService<RedisCache>(),
    _        => throw new ArgumentException($"Unknown cache key: {key}")
});

// Usage
public class OrderService
{
    private readonly ICache _cache;
    public OrderService(Func<string, ICache> cacheFactory)
        => _cache = cacheFactory("redis");
}
```

### Resolving Services Outside the Request Pipeline

```csharp
// At startup (before app.Run) — use the root scope
using var scope = app.Services.CreateScope();
var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
await dbContext.Database.MigrateAsync();

// In background services — always create a scope per operation
public class MyBackgroundService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var scope = _scopeFactory.CreateScope();
        var repo = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
        // ...
    }
}
```

---

## 3. Routing

### Endpoint Routing (Default since .NET Core 3.0)

Endpoint routing decouples route matching from execution. `UseRouting()` selects the endpoint; `UseAuthorization()` and other middleware can then inspect `HttpContext.GetEndpoint()` before the endpoint runs.

```csharp
// Endpoint metadata access in middleware
public async Task InvokeAsync(HttpContext context)
{
    var endpoint = context.GetEndpoint();
    var authAttr = endpoint?.Metadata.GetMetadata<AuthorizeAttribute>();
    if (authAttr != null) { /* custom logic */ }
    await _next(context);
}
```

### Attribute Routing

Controllers inherit route prefixes from `[Route]` on the class; actions append with `[HttpGet]`, `[HttpPost]`, etc.

```csharp
[ApiController]
[Route("api/v{version:apiVersion}/[controller]")]
public class OrdersController : ControllerBase
{
    // GET api/v1/orders
    [HttpGet]
    public IActionResult GetAll() => Ok();

    // GET api/v1/orders/42
    [HttpGet("{id:int}")]
    public IActionResult GetById(int id) => Ok();

    // POST api/v1/orders
    [HttpPost]
    public IActionResult Create([FromBody] CreateOrderRequest req) => Created($"/orders/{1}", req);

    // Route name for link generation
    [HttpGet("{id:int}", Name = "GetOrder")]
    public IActionResult GetByIdNamed(int id) => Ok();
}
```

**Token replacement:** `[controller]`, `[action]`, `[area]` are replaced at build time with controller/action/area names (stripped of "Controller" suffix).

### Conventional Routing (MVC)

```csharp
// Defined at endpoint registration, not on the controller
app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

// Or for Web API only:
app.MapControllers(); // Uses attribute routes only
```

### Route Constraints

Built-in constraints — applied inline with `{param:constraint}`:

| Constraint | Example | Matches |
|---|---|---|
| `int` | `{id:int}` | 32-bit integer |
| `long` | `{id:long}` | 64-bit integer |
| `guid` | `{id:guid}` | GUID format |
| `bool` | `{flag:bool}` | `true`/`false` |
| `datetime` | `{date:datetime}` | Parseable `DateTime` |
| `decimal` | `{price:decimal}` | Decimal number |
| `double` | `{d:double}` | Double |
| `float` | `{f:float}` | Float |
| `alpha` | `{name:alpha}` | A-Z, a-z only |
| `minlength(n)` | `{code:minlength(3)}` | Minimum string length |
| `maxlength(n)` | `{code:maxlength(10)}` | Maximum string length |
| `length(n)` | `{zip:length(5)}` | Exact string length |
| `range(min,max)` | `{age:range(1,120)}` | Integer in range |
| `regex(expr)` | `{ssn:regex(\\d{{3}}-\\d{{2}}-\\d{{4}})}` | Regex match |

```csharp
// Multiple constraints chained with colons
[HttpGet("{id:int:min(1)}")]
public IActionResult GetById(int id) => Ok();
```

**Custom route constraint:**

```csharp
public class EvenNumberConstraint : IRouteConstraint
{
    public bool Match(HttpContext? httpContext, IRouter? route, string routeKey,
        RouteValueDictionary values, RouteDirection routeDirection)
    {
        if (values.TryGetValue(routeKey, out var val) && val is string s)
            return int.TryParse(s, out int n) && n % 2 == 0;
        return false;
    }
}

// Register in DI
services.Configure<RouteOptions>(options =>
    options.ConstraintMap.Add("even", typeof(EvenNumberConstraint)));

// Usage
[HttpGet("{id:even}")]
public IActionResult GetByEvenId(int id) => Ok();
```

### Minimal API Route Registration

```csharp
// MapGet/MapPost/MapPut/MapDelete/MapPatch
app.MapGet("/products/{id:int}", (int id, IProductService svc) =>
    svc.GetById(id) is Product p ? Results.Ok(p) : Results.NotFound());

app.MapPost("/products", async ([FromBody] CreateProductRequest req, IProductService svc) =>
{
    var product = await svc.CreateAsync(req);
    return Results.CreatedAtRoute("GetProduct", new { id = product.Id }, product);
}).WithName("GetProduct");

// Route groups (.NET 7+)
var productsGroup = app.MapGroup("/api/products")
    .RequireAuthorization()
    .WithTags("Products");

productsGroup.MapGet("/", (IProductService svc) => svc.GetAll());
productsGroup.MapGet("/{id:int}", (int id, IProductService svc) => svc.GetById(id));
```

---

## 4. Kestrel Server

### Architecture

Kestrel is ASP.NET Core's cross-platform, high-performance web server. It uses libuv (older) or managed sockets via `System.Net.Sockets` (current) for async I/O. It is always the "inner" server:

```
Client → [Reverse Proxy: Nginx/IIS/YARP] → [Kestrel] → ASP.NET Core Pipeline
```

In direct-to-internet scenarios (no reverse proxy), Kestrel handles TLS termination, HTTP/2 negotiation, and connection limits directly.

### HTTP/2 Support

- **Default since .NET Core 3.0.** Requires TLS (HTTPS) in most cases.
- Enabled automatically when TLS is configured.
- Protocol negotiation via ALPN (Application-Layer Protocol Negotiation) during TLS handshake.

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(5001, listenOptions =>
    {
        listenOptions.UseHttps("cert.pfx", "password");
        listenOptions.Protocols = HttpProtocols.Http1AndHttp2; // Default
    });

    // HTTP/2 limits
    options.Limits.Http2.MaxStreamsPerConnection = 100;       // default: 100
    options.Limits.Http2.HeaderTableSize = 4096;              // default: 4096 bytes
    options.Limits.Http2.MaxFrameSize = 16384;                // default: 16,384 bytes (2^14)
    options.Limits.Http2.MaxRequestHeaderFieldSize = 8192;    // default: 8,192 bytes
    options.Limits.Http2.InitialConnectionWindowSize = 131072; // default: 128 KB
    options.Limits.Http2.InitialStreamWindowSize = 98304;     // default: 96 KB
    options.Limits.Http2.KeepAlivePingDelay = TimeSpan.FromSeconds(30);
    options.Limits.Http2.KeepAlivePingTimeout = TimeSpan.FromSeconds(60);
});
```

### HTTP/3 Support (.NET 7+)

HTTP/3 uses QUIC (UDP-based). First request upgrades from HTTP/1.1 or HTTP/2 via the `alt-svc` response header.

```csharp
// HTTP/3 requires .NET 7+ and OS QUIC support (Windows 11, Linux with libmsquic)
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(5001, listenOptions =>
    {
        listenOptions.UseHttps();
        listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;
    });
});
```

**Limitations:**
- Requires `libmsquic` on Linux.
- Browsers reject self-signed certificates for HTTP/3 (use Let's Encrypt or trusted CA in dev with `dotnet dev-certs`).
- Not all reverse proxies support QUIC pass-through.

### Connection Limits and Timeouts

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    // Connection limits
    options.Limits.MaxConcurrentConnections = 100;          // null = unlimited
    options.Limits.MaxConcurrentUpgradedConnections = 100;  // WebSocket connections

    // Request limits
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024;   // 10 MB default
    options.Limits.MaxRequestHeaderCount = 100;              // default: 100
    options.Limits.MaxRequestHeadersTotalSize = 32768;       // 32 KB default
    options.Limits.MaxRequestLineSize = 8192;                // 8 KB default

    // Timeouts
    options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
    options.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);

    // Per-request body rate
    options.Limits.MinRequestBodyDataRate = new MinDataRate(
        bytesPerSecond: 100, gracePeriod: TimeSpan.FromSeconds(10));
    options.Limits.MinResponseDataRate = new MinDataRate(
        bytesPerSecond: 100, gracePeriod: TimeSpan.FromSeconds(10));
});
```

### Certificate Configuration

```csharp
// Via code
options.ListenAnyIP(443, listenOptions =>
{
    listenOptions.UseHttps(httpsOptions =>
    {
        httpsOptions.ServerCertificate = new X509Certificate2("cert.pfx", "password");
        // Or from store
        httpsOptions.ServerCertificateSelector = (context, name) =>
            CertificateSelector.GetCertificate(name);
    });
});
```

```json
// Via appsettings.json (preferred for production)
{
  "Kestrel": {
    "Endpoints": {
      "Https": {
        "Url": "https://*:5001",
        "Certificate": {
          "Path": "/certs/cert.pfx",
          "Password": "secret"
        }
      }
    }
  }
}
```

### Reverse Proxy Configuration

**Forwarded Headers Middleware** is critical when behind a proxy — otherwise `HttpContext.Connection.RemoteIpAddress` and `HttpContext.Request.Scheme` reflect the proxy, not the client:

```csharp
// MUST be placed before all other middleware
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
    // Restrict to known proxy IPs in production
    KnownProxies = { IPAddress.Parse("10.0.0.1") }
});
```

**IIS integration** calls `UseIISIntegration()` automatically (via `CreateBuilder`), which configures forwarded headers. Linux/Nginx does not — you must add it manually.

**YARP (Yet Another Reverse Proxy) — .NET native reverse proxy:**

```csharp
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

app.MapReverseProxy();
```

```json
// appsettings.json
{
  "ReverseProxy": {
    "Routes": {
      "route1": { "ClusterId": "backend", "Match": { "Path": "/api/{**catch-all}" } }
    },
    "Clusters": {
      "backend": {
        "Destinations": {
          "dest1": { "Address": "http://backend-service:8080/" }
        }
      }
    }
  }
}
```

---

## 5. Model Binding & Validation

### Binding Sources

| Attribute | Source | Notes |
|---|---|---|
| `[FromBody]` | Request body | Only one per action; uses input formatters (JSON by default) |
| `[FromQuery]` | Query string | `?name=value` |
| `[FromRoute]` | Route data | `{id}` in route template |
| `[FromHeader]` | HTTP headers | Case-insensitive |
| `[FromForm]` | Form fields | `multipart/form-data` or `application/x-www-form-urlencoded` |
| `[FromServices]` | DI container | Injects a service directly into action parameter |

```csharp
[HttpPost("{id:int}")]
public async Task<IActionResult> Update(
    [FromRoute] int id,
    [FromBody] UpdateOrderRequest body,
    [FromQuery] bool dryRun,
    [FromHeader(Name = "X-Correlation-Id")] string correlationId,
    [FromServices] IOrderService orderService)
{
    // ...
}
```

**`[ApiController]` attribute effects:**
- Automatic 400 response when `ModelState.IsValid == false` (no need to check manually).
- Binding source inference: complex types from body, simple types from route/query.
- Problem details responses for validation errors.

### Default Binding Inference (with `[ApiController]`)

- `[FromBody]`: complex types not decorated with another source attribute.
- `[FromRoute]`: parameters that match a route template token.
- `[FromQuery]`: everything else.

### Custom Model Binders

```csharp
// 1. Implement IModelBinder
public class CommaSeparatedArrayBinder : IModelBinder
{
    public Task BindModelAsync(ModelBindingContext bindingContext)
    {
        var value = bindingContext.ValueProvider.GetValue(bindingContext.ModelName);
        if (value == ValueProviderResult.None)
        {
            bindingContext.Result = ModelBindingResult.Failed();
            return Task.CompletedTask;
        }

        var ids = value.FirstValue?
            .Split(',', StringSplitOptions.RemoveEmptyEntries)
            .Select(int.Parse)
            .ToArray() ?? Array.Empty<int>();

        bindingContext.Result = ModelBindingResult.Success(ids);
        return Task.CompletedTask;
    }
}

// 2. Implement IModelBinderProvider
public class CommaSeparatedArrayBinderProvider : IModelBinderProvider
{
    public IModelBinder? GetBinder(ModelBinderProviderContext context)
    {
        if (context.Metadata.ModelType == typeof(int[]))
            return new BinderTypeModelBinder(typeof(CommaSeparatedArrayBinder));
        return null;
    }
}

// 3. Register — insert at the beginning to take precedence
services.AddControllers(options =>
{
    options.ModelBinderProviders.Insert(0, new CommaSeparatedArrayBinderProvider());
});

// Alternative: attribute-based application
[HttpGet]
public IActionResult Filter([ModelBinder(typeof(CommaSeparatedArrayBinder))] int[] ids) => Ok();
```

### DataAnnotations Validation

```csharp
public class CreateOrderRequest
{
    [Required]
    [MaxLength(100)]
    public string CustomerName { get; set; } = string.Empty;

    [Range(1, int.MaxValue, ErrorMessage = "At least one item required")]
    public int ItemCount { get; set; }

    [EmailAddress]
    public string? Email { get; set; }

    [RegularExpression(@"^\d{4}-\d{2}-\d{2}$")]
    public string? DeliveryDate { get; set; }

    // Custom attribute
    [FutureDate]
    public DateTime? ScheduledAt { get; set; }
}

// Custom validation attribute
public class FutureDateAttribute : ValidationAttribute
{
    protected override ValidationResult? IsValid(object? value, ValidationContext ctx)
    {
        if (value is DateTime date && date <= DateTime.UtcNow)
            return new ValidationResult("Date must be in the future.");
        return ValidationResult.Success;
    }
}
```

### FluentValidation Integration

```csharp
// Install: FluentValidation.AspNetCore
services.AddFluentValidationAutoValidation();
services.AddValidatorsFromAssemblyContaining<CreateOrderRequestValidator>();

public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>
{
    public CreateOrderRequestValidator()
    {
        RuleFor(x => x.CustomerName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.ItemCount).GreaterThan(0);
        RuleFor(x => x.Email).EmailAddress().When(x => x.Email != null);
        RuleFor(x => x.ScheduledAt)
            .GreaterThan(DateTime.UtcNow)
            .When(x => x.ScheduledAt.HasValue);

        // Async rules
        RuleFor(x => x.CustomerName)
            .MustAsync(async (name, ct) => await IsUniqueAsync(name, ct))
            .WithMessage("Customer name must be unique");
    }
}
```

### Problem Details (.NET 7+ built-in)

```csharp
// Register the Problem Details service (.NET 7+)
services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier;
    };
});

// Automatic validation error response shape (with [ApiController]):
// HTTP 400
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "CustomerName": ["The CustomerName field is required."],
    "ItemCount": ["At least one item required"]
  }
}

// Custom problem details result in an action
return Problem(
    title: "Order not found",
    detail: $"Order {id} does not exist",
    statusCode: StatusCodes.Status404NotFound,
    type: "https://example.com/errors/order-not-found"
);
```

**Built-in validation in Minimal APIs (.NET 10+):**

```csharp
// .NET 10: automatic DataAnnotations validation, no extra config needed
app.MapPost("/orders", ([FromBody] CreateOrderRequest req) =>
    Results.Ok(req))
    .WithParameterValidation(); // .NET 10 extension
```

---

## 6. Filters

### Filter Types and Pipeline Order

Filters run after routing/model binding, inside the MVC layer. Execution order:

```
Request →
  [Authorization Filters]      — only "before", no "after"; short-circuit on deny
  [Resource Filters — Before]  — before model binding
    [Model Binding]
  [Action Filters — Before]    — before action method
    [Action Method]
  [Action Filters — After]     — after action method
  [Result Filters — Before]    — before result execution
    [IActionResult.ExecuteResultAsync]
  [Result Filters — After]     — after result execution
← Response
  [Resource Filters — After]
  [Exception Filters]          — wraps entire filter pipeline
```

Exception filters run when an unhandled exception occurs anywhere in the filter pipeline (not in middleware above it — that's why you still need `UseExceptionHandler`).

### Filter Interfaces

```csharp
// Authorization
public interface IAuthorizationFilter { void OnAuthorization(AuthorizationFilterContext ctx); }
public interface IAsyncAuthorizationFilter { Task OnAuthorizationAsync(AuthorizationFilterContext ctx); }

// Resource
public interface IResourceFilter
{
    void OnResourceExecuting(ResourceExecutingContext ctx);
    void OnResourceExecuted(ResourceExecutedContext ctx);
}

// Action
public interface IActionFilter
{
    void OnActionExecuting(ActionExecutingContext ctx);
    void OnActionExecuted(ActionExecutedContext ctx);
}
public interface IAsyncActionFilter
{
    Task OnActionExecutionAsync(ActionExecutingContext ctx, ActionExecutionDelegate next);
}

// Exception
public interface IExceptionFilter { void OnException(ExceptionContext ctx); }
public interface IAsyncExceptionFilter { Task OnExceptionAsync(ExceptionContext ctx); }

// Result
public interface IResultFilter
{
    void OnResultExecuting(ResultExecutingContext ctx);
    void OnResultExecuted(ResultExecutedContext ctx);
}
```

### Implementation Examples

```csharp
// Action filter — logging + timing
public class RequestTimingFilter : IAsyncActionFilter
{
    private readonly ILogger<RequestTimingFilter> _logger;

    public RequestTimingFilter(ILogger<RequestTimingFilter> logger)
        => _logger = logger;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var sw = Stopwatch.StartNew();
        var executed = await next(); // Run the action
        sw.Stop();

        if (executed.Exception != null)
            _logger.LogError(executed.Exception, "Action failed");
        else
            _logger.LogInformation("Action took {Ms}ms", sw.ElapsedMilliseconds);
    }
}

// Exception filter — convert exceptions to problem details
public class GlobalExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        context.Result = context.Exception switch
        {
            NotFoundException ex => new NotFoundObjectResult(new ProblemDetails
            {
                Title = "Resource not found",
                Detail = ex.Message,
                Status = 404
            }),
            ValidationException ex => new BadRequestObjectResult(new ProblemDetails
            {
                Title = "Validation failed",
                Detail = ex.Message,
                Status = 400
            }),
            _ => new ObjectResult(new ProblemDetails { Status = 500 }) { StatusCode = 500 }
        };
        context.ExceptionHandled = true;
    }
}

// Resource filter — short-circuit with cache
public class CacheResourceFilter : IResourceFilter
{
    private static readonly Dictionary<string, IActionResult> _cache = new();

    public void OnResourceExecuting(ResourceExecutingContext context)
    {
        var key = context.HttpContext.Request.Path;
        if (_cache.TryGetValue(key, out var cached))
            context.Result = cached; // Short-circuits — skips model binding, action, result filters
    }

    public void OnResourceExecuted(ResourceExecutedContext context)
    {
        var key = context.HttpContext.Request.Path;
        if (context.Result != null)
            _cache[key] = context.Result;
    }
}
```

### Filter Registration

```csharp
// Global — applies to all controllers and actions
services.AddControllers(options =>
{
    options.Filters.Add<GlobalExceptionFilter>();
    options.Filters.Add(new RequestTimingFilter()); // Instance (no DI)
    options.Filters.Add(typeof(AnotherFilter));     // Type (resolved from DI)
});

// Controller-level
[ServiceFilter(typeof(RequestTimingFilter))] // Resolved from DI
[TypeFilter(typeof(AnotherFilter))]          // Created with DI, not pre-registered
public class OrdersController : ControllerBase { }

// Action-level
[HttpGet("{id}")]
[ServiceFilter(typeof(CacheResourceFilter))]
public IActionResult GetById(int id) => Ok();

// ServiceFilter requires pre-registration:
services.AddScoped<RequestTimingFilter>();
```

### Filter Execution Order (within the same scope)

For filters of the same type at multiple levels, the order is:
1. Global filters
2. Controller filters
3. Action filters

On the way "out" (after execution): reverse order (action → controller → global).

**Override with `Order` property:**

```csharp
[ServiceFilter(typeof(MyFilter), Order = -1000)] // Runs first
public class OrdersController : ControllerBase { }
```

---

## 7. Configuration System

### Configuration Sources and Priority

Sources are stacked; later sources override earlier ones. Default order in `WebApplication.CreateBuilder`:

1. `appsettings.json`
2. `appsettings.{Environment}.json`
3. User Secrets (Development environment only)
4. Environment variables
5. Command-line arguments

```csharp
// Custom sources
builder.Configuration
    .AddJsonFile("custom.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables(prefix: "MYAPP_")
    .AddCommandLine(args)
    .AddAzureKeyVault(new Uri("https://myvault.vault.azure.net/"),
        new DefaultAzureCredential());
```

### appsettings.json Structure

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=.;Database=Orders;Integrated Security=true"
  },
  "OrderService": {
    "MaxRetries": 3,
    "TimeoutSeconds": 30,
    "FeatureFlags": {
      "EnableBulkImport": true
    }
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

**Environment variable mapping:** Use `__` (double underscore) as hierarchy separator:
`OrderService__MaxRetries=5` maps to `OrderService:MaxRetries`.

### User Secrets (Development)

```bash
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=dev;..."
dotnet user-secrets set "ApiKeys:Stripe" "sk_test_..."
```

Stored at `%APPDATA%/Microsoft/UserSecrets/{UserSecretsId}/secrets.json` (Windows). Never committed to source control. Automatically loaded when `ASPNETCORE_ENVIRONMENT=Development`.

### Azure Key Vault Integration

```csharp
// Install: Azure.Extensions.AspNetCore.Configuration.Secrets
if (!builder.Environment.IsDevelopment())
{
    var keyVaultUri = new Uri(builder.Configuration["KeyVault:Uri"]!);
    builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential());
}
```

**Naming convention:** Azure Key Vault secret names use `--` (double dash) instead of `:` because secret names can't contain colons. The provider automatically translates `--` → `:`.

So the secret `OrderService--MaxRetries` maps to `OrderService:MaxRetries`.

**Live reloading from Key Vault:**

```csharp
builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential(),
    new AzureKeyVaultConfigurationOptions
    {
        ReloadInterval = TimeSpan.FromMinutes(5) // Background polling
    });
```

### Options Pattern

**IOptions\<T\>** — Singleton; reads config once at startup; never reflects changes.

```csharp
services.Configure<OrderServiceOptions>(
    builder.Configuration.GetSection("OrderService"));

public class OrderController : ControllerBase
{
    private readonly OrderServiceOptions _options;

    public OrderController(IOptions<OrderServiceOptions> options)
        => _options = options.Value; // Snapshot from startup
}
```

**IOptionsSnapshot\<T\>** — Scoped; re-reads config per HTTP request; reflects `reloadOnChange: true`.

```csharp
public class OrderService
{
    private readonly OrderServiceOptions _options;

    public OrderService(IOptionsSnapshot<OrderServiceOptions> options)
        => _options = options.Value; // Fresh per request
}
// Cannot be injected into Singletons (scoped service captive dependency)
```

**IOptionsMonitor\<T\>** — Singleton; reflects changes in real time via `OnChange` callback.

```csharp
public class FeatureFlagService
{
    private readonly IOptionsMonitor<FeatureFlags> _monitor;

    public FeatureFlagService(IOptionsMonitor<FeatureFlags> monitor)
    {
        _monitor = monitor;
        monitor.OnChange(flags =>
            Console.WriteLine($"Feature flags changed: {flags.EnableBulkImport}"));
    }

    public bool IsBulkImportEnabled =>
        _monitor.CurrentValue.EnableBulkImport; // Always current value
}
// Safe to inject into Singletons; use in background services
```

**Named options:**

```csharp
services.Configure<SmtpOptions>("primary",
    builder.Configuration.GetSection("Smtp:Primary"));
services.Configure<SmtpOptions>("backup",
    builder.Configuration.GetSection("Smtp:Backup"));

// Inject
public class EmailService
{
    public EmailService(IOptionsMonitor<SmtpOptions> options)
    {
        var primary = options.Get("primary");
        var backup  = options.Get("backup");
    }
}
```

**Options validation:**

```csharp
services.AddOptions<OrderServiceOptions>()
    .Bind(builder.Configuration.GetSection("OrderService"))
    .ValidateDataAnnotations()       // Validates [Required], [Range], etc.
    .ValidateOnStart();              // .NET 6+: throws at startup if invalid

// Or custom validation
services.AddOptions<OrderServiceOptions>()
    .Bind(builder.Configuration.GetSection("OrderService"))
    .Validate(opts => opts.MaxRetries is >= 1 and <= 10,
        "MaxRetries must be between 1 and 10")
    .ValidateOnStart();
```

---

## 8. Hosting Models

### In-Process Hosting (IIS)

The app runs inside the IIS worker process (`w3wp.exe`). The server is `IISHttpServer` (not Kestrel). IIS handles the TCP connection, TLS, and HTTP parsing, then passes requests directly to the ASP.NET Core pipeline in-process.

**Characteristics:**
- Default since ASP.NET Core 3.0 when deployed to IIS.
- Higher throughput than out-of-process (no inter-process communication).
- Single process for IIS and app — crash in app can affect IIS worker.
- Apps published as a single-file executable cannot use in-process hosting.

```xml
<!-- web.config -->
<aspNetCore processPath="dotnet" arguments=".\MyApp.dll"
            hostingModel="inprocess" />
```

### Out-of-Process Hosting (IIS as Reverse Proxy)

The app runs in a separate `dotnet.exe` process. Kestrel is the actual web server. IIS acts as a reverse proxy forwarding to Kestrel via the ASP.NET Core Module.

```xml
<aspNetCore processPath="dotnet" arguments=".\MyApp.dll"
            hostingModel="outofprocess" />
```

**Characteristics:**
- Kestrel listens on a random local port (IIS discovers via named pipe or HTTP).
- App process isolated from IIS worker.
- Supports single-file executables.
- Slight overhead from proxy hop.

### Self-Contained vs Framework-Dependent

```bash
# Framework-dependent — requires .NET runtime on target machine
dotnet publish -c Release -r win-x64

# Self-contained — bundles the runtime
dotnet publish -c Release -r win-x64 --self-contained true

# Single file — single executable (can't use in-process IIS hosting)
dotnet publish -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true
```

### Docker

```dockerfile
# Multi-stage build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
EXPOSE 8080
COPY --from=build /app/publish .
# ASP.NET Core 8+: default port changed to 8080 (non-root)
ENV ASPNETCORE_HTTP_PORTS=8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

**Important .NET 8 change:** The default HTTP port in official Docker images changed from 80 to 8080 to avoid running as root. Use `ASPNETCORE_HTTP_PORTS` env var or update your port mappings.

### Linux (Nginx + systemd)

```nginx
# /etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name example.com;
    
    location / {
        proxy_pass         http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header   Upgrade $http_upgrade;
        proxy_set_header   Connection keep-alive;
        proxy_set_header   Host $host;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My ASP.NET Core App
After=network.target

[Service]
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/dotnet /var/www/myapp/MyApp.dll
Restart=always
RestartSec=10
SyslogIdentifier=myapp
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
```

### Azure App Service

- Windows: supports in-process IIS hosting or out-of-process.
- Linux: runs in Docker containers; no IIS.
- Configuration via App Service Application Settings (maps to environment variables — overrides appsettings.json).
- Enable "Always On" to prevent cold starts.
- Deployment slots for blue/green deployments.

```bash
# Deploy via Azure CLI
az webapp deploy --resource-group myRG --name myApp \
  --src-path publish.zip --type zip
```

### Generic Host vs WebApplication (.NET 6+)

```csharp
// .NET 6+ minimal hosting model (preferred)
var builder = WebApplication.CreateBuilder(args);
// builder.Host — access IHostBuilder for advanced config
// builder.WebHost — access IWebHostBuilder for Kestrel/server config
// builder.Services — IServiceCollection
// builder.Configuration — IConfiguration
// builder.Environment — IWebHostEnvironment
var app = builder.Build();
app.Run();

// Legacy (still valid, more control)
Host.CreateDefaultBuilder(args)
    .ConfigureWebHostDefaults(web => web.UseStartup<Startup>())
    .Build()
    .Run();
```

---

## 9. Controllers vs Minimal APIs

### Controllers (MVC Pattern)

Controllers inherit from `ControllerBase` (Web API) or `Controller` (MVC + views).

```csharp
[ApiController]
[Route("api/[controller]")]
[Produces("application/json")]
public class OrdersController : ControllerBase
{
    private readonly IOrderService _service;
    private readonly ILogger<OrdersController> _logger;

    public OrdersController(IOrderService service, ILogger<OrdersController> logger)
    {
        _service = service;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<OrderDto>), 200)]
    public async Task<IActionResult> GetAll(CancellationToken ct)
        => Ok(await _service.GetAllAsync(ct));

    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(OrderDto), 200)]
    [ProducesResponseType(404)]
    public async Task<IActionResult> GetById(int id, CancellationToken ct)
    {
        var order = await _service.GetByIdAsync(id, ct);
        return order is null ? NotFound() : Ok(order);
    }
}
```

**What controllers give you:**
- Familiar MVC structure; well-understood by teams.
- Full filter pipeline (authorization, resource, action, exception, result filters).
- `IActionResult` return type hierarchy (`Ok()`, `NotFound()`, `Created()`, etc.).
- `ModelState`, `TempData`, `ControllerContext`.
- Attribute routing with token replacement.
- Built-in `[ApiController]` behavior (automatic 400 on invalid model state, binding inference).
- Better support for API versioning libraries (Asp.Versioning).

### Minimal APIs (Lambda Pattern)

Introduced in .NET 6; significantly improved each release.

```csharp
// Basic
app.MapGet("/api/orders", async (IOrderService svc, CancellationToken ct) =>
    Results.Ok(await svc.GetAllAsync(ct)));

app.MapGet("/api/orders/{id:int}", async (int id, IOrderService svc, CancellationToken ct) =>
    await svc.GetByIdAsync(id, ct) is Order o
        ? Results.Ok(o)
        : Results.NotFound());

app.MapPost("/api/orders", async ([FromBody] CreateOrderRequest req,
    IOrderService svc, CancellationToken ct) =>
{
    var order = await svc.CreateAsync(req, ct);
    return Results.CreatedAtRoute("GetOrder", new { order.Id }, order);
}).WithName("GetOrder")
  .WithTags("Orders")
  .RequireAuthorization()
  .Produces<Order>(201)
  .ProducesProblem(400)
  .WithOpenApi();

// Route groups (.NET 7+)
var api = app.MapGroup("/api").RequireAuthorization();
var orders = api.MapGroup("/orders").WithTags("Orders");
orders.MapGet("/", GetAll);
orders.MapGet("/{id:int}", GetById);

// Endpoint handlers as static methods (recommended for testability)
static async Task<IResult> GetAll(IOrderService svc, CancellationToken ct)
    => Results.Ok(await svc.GetAllAsync(ct));
```

**Filters in Minimal APIs (.NET 7+):**

```csharp
app.MapPost("/orders", CreateOrder)
    .AddEndpointFilter<ValidationFilter<CreateOrderRequest>>()
    .AddEndpointFilter(async (ctx, next) =>
    {
        // Before
        var result = await next(ctx);
        // After
        return result;
    });

public class ValidationFilter<T> : IEndpointFilter where T : class
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext ctx, EndpointFilterDelegate next)
    {
        var arg = ctx.GetArgument<T>(0);
        var validator = ctx.HttpContext.RequestServices.GetRequiredService<IValidator<T>>();
        var result = await validator.ValidateAsync(arg);
        if (!result.IsValid)
            return Results.ValidationProblem(result.ToDictionary());
        return await next(ctx);
    }
}
```

### Architectural Trade-offs

| Dimension | Controllers | Minimal APIs |
|---|---|---|
| **Performance** | Slightly lower (reflection, more overhead) | Faster startup and throughput; "pay for play" |
| **Code organization** | Natural grouping per controller class | Explicit grouping via route groups or extension methods |
| **Testability** | Easy: instantiate controller with mocked deps | Easy: test endpoint handlers as static methods |
| **Filter pipeline** | Full MVC filter pipeline | Endpoint filters only (lighter, no Resource/Result filters) |
| **Model binding** | Automatic inference, custom binders | Same automatic inference; custom binders supported |
| **Validation** | `[ApiController]` auto-validates | Manual in .NET 6-9; auto in .NET 10 with `WithParameterValidation()` |
| **OpenAPI/Swagger** | Swashbuckle via XML/attributes | Built-in `Microsoft.AspNetCore.OpenApi` (.NET 9+); `WithOpenApi()` |
| **API versioning** | Well-supported by `Asp.Versioning` | Supported via `Asp.Versioning.Http` (.NET 7+) |
| **Scalability** | Excellent for large APIs with many endpoints | Can get cluttered in Program.cs without discipline |
| **Learning curve** | Higher for new developers | Lower initial; nuances around DI/filters require learning |
| **File upload** | `IFormFile` injection | `IFormFile` parameter binding (.NET 7+) |

### When to Use Which

**Use Controllers when:**
- Greenfield or brownfield large enterprise API (many endpoints, many teams).
- Need the full MVC filter pipeline (especially complex authorization or caching at resource level).
- Team is already familiar with MVC; migration cost outweighs gains.
- Heavy reliance on API versioning and content negotiation.

**Use Minimal APIs when:**
- Microservices with a focused set of endpoints.
- Performance is critical (serverless, high-throughput).
- New project starting with .NET 8+.
- Prefer explicit, functional style over convention-based.

**Migration path (incremental):**

Controllers and Minimal APIs coexist in the same application. You can migrate controller by controller:

```csharp
// Both work simultaneously
app.MapControllers();       // Serves controller-based routes
app.MapGet("/v2/orders", MinimalHandler); // Minimal API alongside
```

### Organizing Minimal APIs at Scale

```csharp
// Extension method pattern — keeps Program.cs clean
public static class OrderEndpoints
{
    public static RouteGroupBuilder MapOrderEndpoints(this RouteGroupBuilder group)
    {
        group.MapGet("/", GetAll);
        group.MapGet("/{id:int}", GetById);
        group.MapPost("/", Create);
        group.MapPut("/{id:int}", Update);
        group.MapDelete("/{id:int}", Delete);
        return group;
    }

    private static async Task<IResult> GetAll(IOrderService svc, CancellationToken ct)
        => Results.Ok(await svc.GetAllAsync(ct));

    // ... other handlers
}

// IEndpointRouteBuilderExtensions pattern
public interface IEndpointDefinition
{
    void DefineEndpoints(WebApplication app);
}

// In Program.cs
var api = app.MapGroup("/api/v1").RequireAuthorization();
api.MapGroup("/orders").MapOrderEndpoints();
api.MapGroup("/products").MapProductEndpoints();
```

---

## Cross-Version Feature Matrix

| Feature | .NET 6 | .NET 7 | .NET 8 | .NET 9 | .NET 10 |
|---|---|---|---|---|---|
| Minimal APIs | Yes | Yes | Yes | Yes | Yes |
| Route Groups | No | Yes | Yes | Yes | Yes |
| Endpoint Filters | No | Yes | Yes | Yes | Yes |
| Keyed DI Services | No | No | Yes | Yes | Yes |
| `ValidateOnStart` options | Yes | Yes | Yes | Yes | Yes |
| HTTP/3 (stable) | Preview | Yes | Yes | Yes | Yes |
| Built-in OpenAPI gen | No | No | No | Yes | Yes (3.1 + YAML) |
| Passkey/WebAuthn Identity | No | No | No | No | Yes |
| Minimal API built-in validation | No | No | No | No | Yes |
| `ServerSentEvents` result | No | No | No | No | Yes |
| Docker default port 8080 | No | No | Yes | Yes | Yes |

---

## Production Debugging Quick Reference

### Common Middleware Order Mistakes

| Symptom | Likely Cause |
|---|---|
| 401 on valid JWT | `UseAuthentication` placed after endpoint mapping, or missing entirely |
| 403 instead of redirect | `UseAuthorization` before `UseRouting` — endpoint metadata not available |
| CORS preflight fails | `UseCors` placed after `UseAuthentication` — OPTIONS request requires auth |
| Exceptions not caught | `UseExceptionHandler` placed after middleware that throws |
| Static files hit auth | `UseStaticFiles` placed after `UseAuthentication` |
| IP address always proxy | `UseForwardedHeaders` missing or placed too late |

### Diagnosing Authentication Issues

Enable detailed auth logging:

```json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.AspNetCore.Authentication": "Debug",
      "Microsoft.AspNetCore.Authorization": "Debug"
    }
  }
}
```

- **401 Unauthorized** — token not found, expired, or signature mismatch. Check issuer/audience config.
- **403 Forbidden** — token valid, user authenticated, but lacks required claim or role.
- Use `context.GetEndpoint()?.Metadata` in middleware to inspect what auth requirements an endpoint has.

### DI Scope Validation

Enable scope validation in all environments to catch captive dependency issues early:

```csharp
builder.Host.UseDefaultServiceProvider(opt =>
{
    opt.ValidateScopes = true;
    opt.ValidateOnBuild = true;
});
```

### Kestrel Connection Debugging

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    // Reject requests early if over limit
    options.Limits.MaxConcurrentConnections = 1000;
    // Log connection-level events
    options.ConfigureHttpsDefaults(https =>
        https.SslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13);
});
```

Enable `Microsoft.AspNetCore.Server.Kestrel` logging at `Debug` level to trace connection lifecycle.

### Model Binding Debugging

Set `Microsoft.AspNetCore.Mvc` logging level to `Debug` to see binding source selection and constraint failures. Custom binder providers must be inserted at the correct position — insert at index 0 for highest priority, or use LINQ to find an existing provider and insert relative to it.
