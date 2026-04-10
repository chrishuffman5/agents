# ASP.NET Core Architecture Deep Reference

## Middleware Pipeline Internals

### The RequestDelegate Chain

Every middleware component is a `RequestDelegate` -- a `Func<HttpContext, Task>`. The pipeline is built at startup by composing delegates. Each middleware wraps the next, creating a Russian-doll pattern.

```csharp
// The fundamental delegate signature
public delegate Task RequestDelegate(HttpContext context);

// Convention-based middleware (most common)
public class TimingMiddleware
{
    private readonly RequestDelegate _next;

    public TimingMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        var sw = Stopwatch.StartNew();
        await _next(context);   // downstream
        sw.Stop();
        context.Response.Headers["X-Elapsed-Ms"] = sw.ElapsedMilliseconds.ToString();
    }
}

// IMiddleware interface (DI-friendly, resolved per request)
public class AuditMiddleware : IMiddleware
{
    private readonly IAuditService _audit;

    public AuditMiddleware(IAuditService audit) => _audit = audit;

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        _audit.LogRequest(context.Request);
        await next(context);
        _audit.LogResponse(context.Response);
    }
}

// IMiddleware must be registered as a service
builder.Services.AddScoped<AuditMiddleware>();
app.UseMiddleware<AuditMiddleware>();
```

**Convention-based vs IMiddleware:**
- Convention-based: constructor receives `RequestDelegate`; services injected into `InvokeAsync` parameters. Singleton by default.
- `IMiddleware`: resolved from DI each request; must be registered as a service; cleaner for complex middleware with scoped dependencies.

### Correct Production Middleware Order

Microsoft's recommended order. Deviation causes bugs -- especially around auth and CORS:

```csharp
var app = builder.Build();

// 1. Exception handler — FIRST to catch all downstream exceptions
if (app.Environment.IsDevelopment())
    app.UseDeveloperExceptionPage();
else
    app.UseExceptionHandler("/error");

// 2. HSTS — Strict-Transport-Security header
app.UseHsts();

// 3. HTTPS redirect — before auth so redirects happen on insecure requests
app.UseHttpsRedirection();

// 4. Static files — short-circuit before routing (no auth on static files by default)
app.UseStaticFiles();

// 5. Routing — MUST come before CORS, Auth, and Endpoints
app.UseRouting();

// 6. CORS — after UseRouting, before UseAuthorization
app.UseCors("MyPolicy");

// 7. Authentication — identifies the user
app.UseAuthentication();

// 8. Authorization — checks permissions (requires routing to know the endpoint)
app.UseAuthorization();

// 9. Custom middleware
app.UseMiddleware<TimingMiddleware>();

// 10. Endpoints
app.MapControllers();
app.MapHealthChecks("/health");
```

### Pipeline Branching

```csharp
// Map — branch on URL prefix; does NOT rejoin main pipeline
app.Map("/api/legacy", legacyApp =>
{
    legacyApp.UseMiddleware<LegacyMiddleware>();
    legacyApp.Run(async ctx => await ctx.Response.WriteAsync("Legacy"));
});

// MapWhen — branch on any predicate; does NOT rejoin
app.MapWhen(ctx => ctx.Request.Headers.ContainsKey("X-Special"), specialApp =>
{
    specialApp.UseMiddleware<SpecialMiddleware>();
});

// UseWhen — conditional detour; REJOINS main pipeline
app.UseWhen(
    ctx => ctx.Request.Path.StartsWithSegments("/api"),
    apiApp => apiApp.UseMiddleware<ApiLoggingMiddleware>()
);
```

**Key distinction:** `Map`/`MapWhen` create terminal forks. `UseWhen` creates a conditional detour -- execution returns to the main pipeline unless the branch short-circuits.

### Short-Circuit Patterns

```csharp
// Run() — terminal middleware, never calls next
app.Run(async context => await context.Response.WriteAsync("Terminal"));

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

### Middleware vs Filters

| Concern | Middleware | Filters |
|---|---|---|
| Scope | Every HTTP request | MVC/controller/action scope only |
| Context | `HttpContext` only | `ActionExecutingContext`, model state, etc. |
| Access to routing | No (before routing) | Yes (after routing, endpoint known) |
| Registration | `app.UseXxx()` | Attribute, global filter, or service filter |
| Use for | Auth, CORS, logging, compression | Validation, caching, audit per-action |

**Rule of thumb:** Cross-cutting concerns that apply to all requests and don't need MVC context --> middleware. Concerns that need routing/model binding context or are scoped to specific controllers --> filters.

---

## Dependency Injection Container

### Service Lifetimes

```csharp
services.AddTransient<IEmailSender, SmtpEmailSender>();    // New every time
services.AddScoped<IOrderRepository, EfOrderRepository>(); // One per HTTP request
services.AddSingleton<IMemoryCache, MemoryCache>();        // One for app lifetime
```

**Captive dependency trap:** A Scoped or Transient service injected into a Singleton gets captured for the Singleton's lifetime. Scope validation catches this:

```csharp
builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateScopes = true;
    options.ValidateOnBuild = true;  // Validates at startup
});
```

### Open Generic Registration

```csharp
services.AddScoped(typeof(IRepository<>), typeof(EfRepository<>));

// Closed generic takes precedence
services.AddScoped<IRepository<Customer>, CachedCustomerRepository>();
// IRepository<Customer> -> CachedCustomerRepository
// IRepository<Order>    -> EfRepository<Order>
```

### Factory Pattern

```csharp
services.AddScoped<IOrderService>(sp =>
{
    var config = sp.GetRequiredService<IOptions<OrderConfig>>().Value;
    var repo = sp.GetRequiredService<IOrderRepository>();
    return new OrderService(repo, config.MaxRetries);
});
```

### Keyed Services (.NET 8+)

```csharp
services.AddKeyedSingleton<ICache, MemoryCache>("memory");
services.AddKeyedSingleton<ICache, RedisCache>("redis");

// Constructor injection
public class OrderService(
    [FromKeyedServices("redis")] ICache cache) { }

// Manual resolution
var cache = sp.GetRequiredKeyedService<ICache>("redis");
```

### Resolving Outside the Request Pipeline

```csharp
// At startup — use the root scope
using var scope = app.Services.CreateScope();
var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
await db.Database.MigrateAsync();

// In background services — create a scope per operation
public class MyBackgroundService(IServiceScopeFactory scopeFactory) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var repo = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
    }
}
```

---

## Kestrel Server

### Architecture

Kestrel is ASP.NET Core's cross-platform web server using managed sockets via `System.Net.Sockets` for async I/O. It is the "inner" server:

```
Client -> [Reverse Proxy: Nginx/IIS/YARP] -> [Kestrel] -> ASP.NET Core Pipeline
```

### HTTP/2 and HTTP/3

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(5001, listenOptions =>
    {
        listenOptions.UseHttps();
        listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;
    });

    // Connection limits
    options.Limits.MaxConcurrentConnections = 100;
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024;  // 10 MB
    options.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(2);
    options.Limits.RequestHeadersTimeout = TimeSpan.FromSeconds(30);
});
```

HTTP/3 requires TLS 1.3, Windows 11+ or Linux with `libmsquic`. Not supported on macOS.

### Certificate Configuration

```json
// appsettings.json (preferred for production)
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

Forwarded Headers Middleware is critical behind a proxy:

```csharp
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto,
    KnownProxies = { IPAddress.Parse("10.0.0.1") }
});
```

Must be placed before all other middleware. IIS does this automatically; Nginx/Linux requires manual setup.

---

## Routing Engine

### Endpoint Routing

Endpoint routing decouples route matching from execution. `UseRouting()` selects the endpoint; middleware between routing and endpoints can inspect `HttpContext.GetEndpoint()`.

```csharp
// Inspect endpoint metadata in middleware
public async Task InvokeAsync(HttpContext context)
{
    var endpoint = context.GetEndpoint();
    var authAttr = endpoint?.Metadata.GetMetadata<AuthorizeAttribute>();
    if (authAttr != null) { /* custom logic */ }
    await _next(context);
}
```

### Route Constraints

| Constraint | Example | Matches |
|---|---|---|
| `int` | `{id:int}` | 32-bit integer |
| `guid` | `{id:guid}` | GUID format |
| `alpha` | `{name:alpha}` | A-Z, a-z |
| `minlength(n)` | `{code:minlength(3)}` | Min string length |
| `range(min,max)` | `{age:range(1,120)}` | Integer in range |
| `regex(expr)` | `{slug:regex(^[a-z0-9-]+$)}` | Regex match |

```csharp
// Multiple constraints chained
[HttpGet("{id:int:min(1)}")]
public IActionResult GetById(int id) => Ok();
```

### Custom Route Constraint

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

services.Configure<RouteOptions>(options =>
    options.ConstraintMap.Add("even", typeof(EvenNumberConstraint)));
```

---

## Filter Pipeline (Controllers)

### Execution Order

```
Request ->
  [Authorization Filters]      — short-circuit on deny
  [Resource Filters - Before]  — before model binding
    [Model Binding]
  [Action Filters - Before]    — before action method
    [Action Method]
  [Action Filters - After]
  [Result Filters - Before]
    [IActionResult.ExecuteResultAsync]
  [Result Filters - After]
<- Response
  [Resource Filters - After]
  [Exception Filters]          — wraps entire filter pipeline
```

### Filter Implementation Examples

```csharp
// Action filter -- logging + timing
public class RequestTimingFilter : IAsyncActionFilter
{
    private readonly ILogger<RequestTimingFilter> _logger;

    public RequestTimingFilter(ILogger<RequestTimingFilter> logger) => _logger = logger;

    public async Task OnActionExecutionAsync(
        ActionExecutingContext context, ActionExecutionDelegate next)
    {
        var sw = Stopwatch.StartNew();
        var executed = await next();
        sw.Stop();
        _logger.LogInformation("Action took {Ms}ms", sw.ElapsedMilliseconds);
    }
}

// Exception filter -- convert exceptions to ProblemDetails
public class GlobalExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        context.Result = context.Exception switch
        {
            NotFoundException ex => new NotFoundObjectResult(new ProblemDetails
            {
                Title = "Resource not found", Detail = ex.Message, Status = 404
            }),
            _ => new ObjectResult(new ProblemDetails { Status = 500 }) { StatusCode = 500 }
        };
        context.ExceptionHandled = true;
    }
}
```

### Filter Registration

```csharp
// Global
services.AddControllers(options =>
{
    options.Filters.Add<GlobalExceptionFilter>();
    options.Filters.Add(typeof(RequestTimingFilter));
});

// Controller-level
[ServiceFilter(typeof(RequestTimingFilter))]
public class OrdersController : ControllerBase { }

// Action-level
[HttpGet("{id}")]
[ServiceFilter(typeof(CacheResourceFilter))]
public IActionResult GetById(int id) => Ok();
```

---

## Hosting Models

### In-Process (IIS)

App runs inside `w3wp.exe`. Server is `IISHttpServer` (not Kestrel). Higher throughput, no inter-process communication. Default when deployed to IIS.

```xml
<aspNetCore processPath="dotnet" arguments=".\MyApp.dll" hostingModel="inprocess" />
```

### Out-of-Process (IIS as Reverse Proxy)

App runs in separate `dotnet.exe`. Kestrel is the server. IIS forwards requests.

### Self-Hosted (Linux)

```ini
# /etc/systemd/system/myapp.service
[Service]
WorkingDirectory=/var/www/myapp
ExecStart=/usr/bin/dotnet /var/www/myapp/MyApp.dll
Restart=always
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
```

### Docker

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
EXPOSE 8080
COPY --from=build /app/publish .
ENV ASPNETCORE_HTTP_PORTS=8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

Default port changed to 8080 in .NET 8+ Docker images (non-root).

### Generic Host vs WebApplication

```csharp
// .NET 6+ minimal hosting (preferred)
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.Run();

// Legacy (still valid)
Host.CreateDefaultBuilder(args)
    .ConfigureWebHostDefaults(web => web.UseStartup<Startup>())
    .Build()
    .Run();
```

---

## Configuration System

### Source Priority (later overrides earlier)

1. `appsettings.json`
2. `appsettings.{Environment}.json`
3. User Secrets (Development only)
4. Environment variables
5. Command-line arguments

### Options Pattern

```csharp
// IOptions<T>        -- Singleton, reads once at startup
// IOptionsSnapshot<T> -- Scoped, re-reads per request
// IOptionsMonitor<T>  -- Singleton, reflects changes via OnChange

builder.Services.AddOptions<OrderServiceOptions>()
    .Bind(builder.Configuration.GetSection("OrderService"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

### Named Options

```csharp
services.Configure<SmtpOptions>("primary",
    builder.Configuration.GetSection("Smtp:Primary"));
services.Configure<SmtpOptions>("backup",
    builder.Configuration.GetSection("Smtp:Backup"));

// Resolve
public class EmailService(IOptionsMonitor<SmtpOptions> options)
{
    private readonly SmtpOptions _primary = options.Get("primary");
}
```

### Environment Variable Mapping

Use `__` (double underscore) as hierarchy separator: `OrderService__MaxRetries=5` maps to `OrderService:MaxRetries`.

### Azure Key Vault

Secret names use `--` (double dash) instead of `:`. The provider translates `--` to `:` automatically. `OrderService--MaxRetries` maps to `OrderService:MaxRetries`.

```csharp
builder.Configuration.AddAzureKeyVault(keyVaultUri, new DefaultAzureCredential(),
    new AzureKeyVaultConfigurationOptions
    {
        ReloadInterval = TimeSpan.FromMinutes(5)
    });
```
