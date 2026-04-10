# ASP.NET Core: .NET 8 LTS and .NET 9 STS Feature Reference

**TFM:** `net8.0` for .NET 8 LTS, `net9.0` for .NET 9 STS
**Support:** .NET 8 LTS (Nov 2023 – Nov 2026), .NET 9 STS (Nov 2024 – May 2026)
**Source:** Microsoft official docs (learn.microsoft.com), verified April 2026

---

## Table of Contents

- [.NET 8 LTS Features](#net-8-lts-features)
  - [Native AOT for Web APIs](#native-aot-for-web-apis)
  - [Identity API Endpoints](#identity-api-endpoints)
  - [Output Caching Improvements](#output-caching-improvements)
  - [Short-Circuit Routing](#short-circuit-routing)
  - [Form Binding in Minimal APIs](#form-binding-in-minimal-apis)
  - [Keyed DI Services](#keyed-di-services)
  - [Request Timeouts Middleware](#request-timeouts-middleware)
  - [IExceptionHandler Interface](#iexceptionhandler-interface)
  - [Metrics with IMeterFactory](#metrics-with-imeterfactory)
  - [HTTP/3 Improvements](#http3-improvements)
  - [Blazor Web App (Unified Model)](#blazor-web-app-unified-model)
- [.NET 9 STS Features](#net-9-sts-features)
  - [Built-in OpenAPI Document Generation](#built-in-openapi-document-generation)
  - [HybridCache](#hybridcache)
  - [MapStaticAssets](#mapstaticassets)
  - [SignalR Native AOT Support](#signalr-native-aot-support)
  - [TypedResults Improvements](#typedresults-improvements)
  - [Minimal API and OpenAPI Analyzer Improvements](#minimal-api-and-openapi-analyzer-improvements)
- [Breaking Changes](#breaking-changes)
- [Feature Compatibility Matrix](#feature-compatibility-matrix)

---

## .NET 8 LTS Features

### Native AOT for Web APIs

**TFM:** `net8.0` | **Requires:** `<PublishAot>true</PublishAot>` in project file

Native AOT (Ahead-of-Time compilation) publishes a self-contained native executable with no JIT runtime. In .NET 8 this is supported for **Minimal APIs**, **gRPC**, and **Worker Services** only.

#### Benefits
- Smaller container images (~8.5 MB for a simple API on linux-x64)
- Faster startup time
- Lower memory footprint

#### Enabling Native AOT

```xml
<!-- .csproj -->
<PropertyGroup>
  <PublishAot>true</PublishAot>
</PropertyGroup>
```

Use the template directly:

```bash
dotnet new webapiaot -o MyAotApi
```

#### CreateSlimBuilder vs CreateBuilder

The AOT template uses `CreateSlimBuilder` instead of `CreateBuilder` to minimize the app's deployed size:

```csharp
// AOT-optimized startup
using System.Text.Json.Serialization;

var builder = WebApplication.CreateSlimBuilder(args);

// STJ source generator required — reflection is not available in AOT
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonSerializerContext.Default);
});

var app = builder.Build();

var todos = new[] { new Todo(1, "Buy milk", false) };
app.MapGet("/todos", () => todos);
app.MapGet("/todos/{id}", (int id) =>
    todos.FirstOrDefault(t => t.Id == id) is { } todo
        ? Results.Ok(todo)
        : Results.NotFound());

app.Run();

[JsonSerializable(typeof(Todo[]))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }

record Todo(int Id, string Title, bool IsComplete);
```

**What `CreateSlimBuilder` excludes vs `CreateBuilder`:**
- No hosting startup assemblies
- No Windows EventLog / Debug / Event Source logging providers
- No `UseStaticWebAssets` or IIS Integration
- No Kestrel HTTPS or HTTP/3 by default (add via `builder.WebHost.UseKestrelHttpsConfiguration()`)
- No regex/alpha routing constraints

#### AOT Compatibility Table (net8.0)

| Feature | Support |
|---|---|
| Minimal APIs | Partially supported |
| gRPC | Fully supported |
| MVC / Razor Pages | **Not supported** |
| Blazor Server | **Not supported** |
| SignalR | **Not supported** (fixed in .NET 9) |
| JWT Authentication | Fully supported |
| Other Authentication | **Not supported** |
| Output Caching | Fully supported |
| Rate Limiting | Fully supported |
| Health Checks | Fully supported |
| Session | **Not supported** |

#### Key Constraints
- All JSON types must be registered on a `JsonSerializerContext` (source generation required)
- Libraries using runtime reflection, dynamic code generation, or conditional assembly loading are incompatible
- AOT warnings at build time indicate runtime failures at publish time
- Use `EmitCompilerGeneratedFiles=true` in the project file to inspect generated source

---

### Identity API Endpoints

**TFM:** `net8.0` | **Package:** `Microsoft.AspNetCore.Identity.EntityFrameworkCore` (included in framework)

Replaces the need for a separate identity server for SPA / mobile API backends. Provides bearer token and cookie authentication out of the box via a single `MapIdentityApi<TUser>()` call.

#### Setup

```csharp
// Program.cs
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Register Identity with API endpoint support
builder.Services.AddIdentityApiEndpoints<IdentityUser>()
    .AddEntityFrameworkStores<ApplicationDbContext>();

builder.Services.AddAuthorization();

var app = builder.Build();

app.MapIdentityApi<IdentityUser>(); // Maps all Identity endpoints

app.MapGet("/secret", () => "This is protected!")
    .RequireAuthorization();

app.Run();
```

#### Generated Endpoints

| Method | Route | Description |
|---|---|---|
| POST | `/register` | Register a new user |
| POST | `/login` | Login (cookie or token) |
| POST | `/refresh` | Refresh access token |
| GET | `/confirmEmail` | Email confirmation |
| POST | `/resendConfirmationEmail` | Resend confirmation |
| POST | `/forgotPassword` | Initiate password reset |
| POST | `/resetPassword` | Complete password reset |
| POST | `/manage/2fa` | Two-factor auth management |
| GET | `/manage/info` | Get user info |
| POST | `/manage/info` | Update user info |
| POST | `/logout` | Logout (cookie) |

#### Cookie vs. Token Authentication

```jsonc
// Cookie auth — set useCookies=true in query string or body
POST /login?useCookies=true
{ "email": "user@example.com", "password": "P@ssword1" }
// Response: 200 OK with Set-Cookie header

// Bearer token auth — set useCookies=false (default)
POST /login?useCookies=false
{ "email": "user@example.com", "password": "P@ssword1" }
// Response: { "tokenType": "Bearer", "accessToken": "...", "refreshToken": "...", "expiresIn": 3600 }
```

For token auth, subsequent requests use `Authorization: Bearer <accessToken>`.

> **Note:** The tokens are proprietary (not standard JWTs). For full OAuth2/OIDC scenarios, use a proper token server (Duende IdentityServer, OpenIddict, etc.).

---

### Output Caching Improvements

**TFM:** `net8.0` | **Namespace:** `Microsoft.AspNetCore.OutputCaching`

Output caching introduced in .NET 7 gained **Redis backend support** and further policy improvements in .NET 8.

#### Basic Setup

```csharp
builder.Services.AddOutputCache();
// or with Redis backend (new in .NET 8):
builder.Services.AddStackExchangeRedisOutputCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
    options.InstanceName = "MyApp";
});
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(p => p.Expire(TimeSpan.FromSeconds(60)));
    options.AddPolicy("Short", p => p.Expire(TimeSpan.FromSeconds(10)));
    options.AddPolicy("ByUser", p => p.SetVaryByQuery("userId").Expire(TimeSpan.FromMinutes(5)));
});

// ...
app.UseOutputCache(); // Must be after UseCors, after UseRouting for MVC
```

#### Per-Endpoint Caching

```csharp
// Minimal API — fluent
app.MapGet("/products", GetProducts).CacheOutput();
app.MapGet("/products/{id}", GetProductById).CacheOutput("Short");
app.MapGet("/user-data", GetUserData).CacheOutput("ByUser");

// Minimal API — attribute
app.MapGet("/cached", [OutputCache(Duration = 30)] GetData);

// MVC controller
[OutputCache(PolicyName = "Short")]
public IActionResult Get() { ... }
```

#### Cache Key Variation

```csharp
builder.Services.AddOutputCache(options =>
{
    options.AddPolicy("VaryByHeader", p =>
        p.SetVaryByHeader("Accept-Language")
         .SetVaryByQuery("page", "size")
         .Expire(TimeSpan.FromMinutes(2)));
});
```

#### Tag-Based Eviction

```csharp
// Tag endpoints
app.MapGet("/blog/{slug}", GetPost)
    .CacheOutput(p => p.Tag("blog"));

// Evict by tag (e.g., after a post is updated)
app.MapPost("/admin/invalidate-blog", async (IOutputCacheStore store) =>
{
    await store.EvictByTagAsync("blog", default);
    return Results.Ok();
});
```

#### Key Defaults and Limits
- Default expiry: 60 seconds
- Default max body size: 64 MB
- Default cache size: 100 MB
- Only GET/HEAD 200 responses are cached by default
- Authenticated requests and responses with cookies are excluded by default
- Resource locking (stampede protection) is enabled by default — disable with `.SetLocking(false)`
- **Do not use `IDistributedCache` with output caching** — it lacks atomic features required for tag eviction; use `IOutputCacheStore` directly or the built-in Redis package

---

### Short-Circuit Routing

**TFM:** `net8.0` | **Namespace:** `Microsoft.AspNetCore.Routing`

Allows specific routes to skip the full middleware pipeline after routing, returning responses immediately. Useful for well-known paths like `robots.txt` and `favicon.ico` that the app doesn't serve.

#### Single Endpoint

```csharp
// Returns response without running downstream middleware
app.MapGet("/health-simple", () => "OK").ShortCircuit();

// Short-circuit with a specific status code
app.MapGet("/not-found-path", () => { }).ShortCircuit(statusCode: 404);
```

#### Multiple Paths (MapShortCircuit)

```csharp
// Returns 404 for all listed paths, skipping middleware pipeline
app.MapShortCircuit(404, "robots.txt", "favicon.ico", "sitemap.xml");
```

The short-circuit executes after routing but before any middleware that runs after `UseRouting` (e.g., auth, rate limiting). This is a significant performance optimization for high-traffic paths.

---

### Form Binding in Minimal APIs

**TFM:** `net8.0`

Minimal APIs now support binding from HTML form values, `IFormFile`, and `IFormFileCollection`. Antiforgery token validation is integrated.

#### Basic Form Binding

```csharp
app.MapPost("/upload", async (
    [FromForm] string username,
    [FromForm] IFormFile profilePicture,
    HttpContext context) =>
{
    // antiforgery token is validated automatically when using [FromForm]
    using var stream = profilePicture.OpenReadStream();
    // process upload...
    return Results.Ok(new { username, size = profilePicture.Length });
});
```

#### Multiple Files

```csharp
app.MapPost("/upload-many", async (
    [FromForm] string title,
    [FromForm] IFormFileCollection files) =>
{
    foreach (var file in files)
    {
        // process each file
    }
    return Results.Ok();
});
```

#### IFormCollection (Raw Access)

```csharp
app.MapPost("/form-raw", async (IFormCollection form) =>
{
    var name = form["name"];
    var file = form.Files["attachment"];
    return Results.Ok();
});
```

#### Binding to a Record / Class

```csharp
app.MapPost("/contact", ([FromForm] ContactForm form) =>
{
    return Results.Ok(form);
});

record ContactForm(string Name, string Email, string Message);
```

> **Note:** OpenAPI metadata is automatically inferred for form parameters, enabling Swagger UI integration.

---

### Keyed DI Services

**TFM:** `net8.0` | **Namespace:** `Microsoft.Extensions.DependencyInjection`

Register multiple implementations of the same interface with a key, then resolve by key. Keys can be any `object` that correctly implements `Equals`.

#### Registration

```csharp
// Keyed registrations — available for Singleton, Scoped, Transient
builder.Services.AddKeyedSingleton<ICache, MemoryCache>("memory");
builder.Services.AddKeyedSingleton<ICache, DistributedCache>("distributed");
builder.Services.AddKeyedScoped<IMessageSender, EmailSender>("email");
builder.Services.AddKeyedScoped<IMessageSender, SmsSender>("sms");
```

#### Resolution in Minimal APIs

```csharp
app.MapGet("/data/memory",
    ([FromKeyedServices("memory")] ICache cache) => cache.Get("key"));

app.MapGet("/data/distributed",
    ([FromKeyedServices("distributed")] ICache cache) => cache.Get("key"));
```

#### Resolution in MVC Controllers

```csharp
[ApiController]
[Route("api/[controller]")]
public class MessagesController : ControllerBase
{
    [HttpPost("email")]
    public IActionResult SendEmail(
        [FromKeyedServices("email")] IMessageSender sender,
        [FromBody] string message)
    {
        sender.Send(message);
        return Ok();
    }
}
```

#### Resolution in Constructor (with attribute)

```csharp
public class NotificationService
{
    private readonly IMessageSender _emailSender;

    public NotificationService(
        [FromKeyedServices("email")] IMessageSender emailSender)
    {
        _emailSender = emailSender;
    }
}
```

#### Resolution in SignalR Hubs

```csharp
public class ChatHub : Hub
{
    public async Task SendMessage(
        [FromKeyedServices("memory")] ICache cache,
        string message)
    {
        // ...
    }
}
```

#### Blazor Components

```csharp
@code {
    [Inject(Key = "memory")]
    public ICache MemoryCache { get; set; } = default!;
}
```

> **Note:** The `@inject` Razor directive does not support keyed services in .NET 8. Use `[Inject(Key = "...")]` on properties instead.

#### AnyKey Fallback

```csharp
// Register a fallback for any unregistered key
builder.Services.AddKeyedSingleton<ICache>(KeyedService.AnyKey, (sp, key) =>
    new DefaultCache(key?.ToString() ?? "default"));

// GetKeyedServices(KeyedService.AnyKey) returns all explicitly-keyed registrations
```

---

### Request Timeouts Middleware

**TFM:** `net8.0` | **Namespace:** `Microsoft.AspNetCore.Http.Timeouts`  
**Package:** Built into `Microsoft.AspNetCore.App` framework reference

Provides per-endpoint and global request timeout configuration. When a timeout expires, `HttpContext.RequestAborted` is cancelled — the app must handle `TaskCanceledException` and return an appropriate response; the framework does not automatically abort the connection (default behavior returns 504).

> **Important:** Timeouts do not trigger when the app is running under a debugger.

#### Setup

```csharp
builder.Services.AddRequestTimeouts(options =>
{
    // Global default
    options.DefaultPolicy = new RequestTimeoutPolicy
    {
        Timeout = TimeSpan.FromSeconds(30),
        TimeoutStatusCode = 504
    };
    // Named policy with custom response
    options.AddPolicy("LongRunning", new RequestTimeoutPolicy
    {
        Timeout = TimeSpan.FromMinutes(5)
    });
    options.AddPolicy("Fast", TimeSpan.FromSeconds(5));
});

// Must come after UseRouting if UseRouting is explicit
app.UseRequestTimeouts();
```

#### Per-Endpoint Configuration

```csharp
// Fluent extension
app.MapGet("/api/data", async (HttpContext context) =>
{
    try
    {
        await Task.Delay(TimeSpan.FromSeconds(10), context.RequestAborted);
        return Results.Ok("Done");
    }
    catch (TaskCanceledException)
    {
        return Results.StatusCode(504);
    }
}).WithRequestTimeout(TimeSpan.FromSeconds(3));

// Named policy
app.MapGet("/api/report", GenerateReport)
    .WithRequestTimeout("LongRunning");

// Attribute
app.MapGet("/api/fast",
    [RequestTimeout(milliseconds: 2000)] async (HttpContext ctx) =>
    {
        await Task.Delay(5000, ctx.RequestAborted);
        return Results.Ok();
    });
```

#### Disabling Timeouts

```csharp
// Disable for a specific endpoint (ignores global default too)
app.MapGet("/api/stream", StreamData)
    .DisableRequestTimeout();

// Disable via attribute
app.MapGet("/api/unlimited",
    [DisableRequestTimeout] async (HttpContext ctx) => { ... });
```

#### Cancelling a Timeout Mid-Request

```csharp
app.MapGet("/api/conditional", async (HttpContext context) =>
{
    // Cancel the timeout after auth check passes
    var timeoutFeature = context.Features.Get<IHttpRequestTimeoutFeature>();
    if (context.User.IsInRole("Admin"))
        timeoutFeature?.DisableTimeout(); // Cannot cancel after it has expired

    await DoLongWork(context.RequestAborted);
    return Results.Ok();
}).WithRequestTimeout(TimeSpan.FromSeconds(10));
```

---

### IExceptionHandler Interface

**TFM:** `net8.0` | **Namespace:** `Microsoft.AspNetCore.Diagnostics`

Provides a centralized, structured callback for handling known exceptions. Supports multiple registered handlers (called in registration order). First handler returning `true` stops further processing.

#### Interface

```csharp
public interface IExceptionHandler
{
    ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken);
}
```

#### Implementation

```csharp
public class ValidationExceptionHandler : IExceptionHandler
{
    private readonly ILogger<ValidationExceptionHandler> _logger;

    public ValidationExceptionHandler(ILogger<ValidationExceptionHandler> logger)
        => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        if (exception is not ValidationException validationEx)
            return false; // Let the next handler try

        _logger.LogWarning(validationEx, "Validation error");

        httpContext.Response.StatusCode = StatusCodes.Status400BadRequest;
        await httpContext.Response.WriteAsJsonAsync(new
        {
            type = "ValidationError",
            errors = validationEx.Errors
        }, cancellationToken);

        return true; // Handled — stop processing
    }
}

public class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger)
        => _logger = logger;

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext,
        Exception exception,
        CancellationToken cancellationToken)
    {
        _logger.LogError(exception, "Unhandled exception at {Time}", DateTime.UtcNow);

        httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
        await httpContext.Response.WriteAsJsonAsync(new
        {
            type = "InternalServerError",
            message = "An unexpected error occurred"
        }, cancellationToken);

        return true;
    }
}
```

#### Registration

```csharp
// Registration order matters — ValidationExceptionHandler runs first
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();

// UseExceptionHandler must still be in the pipeline to activate handlers
app.UseExceptionHandler(_ => { });
```

> **Note:** Implementations are registered as **singletons**. The middleware still needs `UseExceptionHandler()` to be invoked; `IExceptionHandler` implementations are called within that middleware.

---

### Metrics with IMeterFactory

**TFM:** `net8.0` | **Namespace:** `System.Diagnostics.Metrics`  
**Requires:** `OpenTelemetry.Exporter.Prometheus.AspNetCore` (optional, for export)

ASP.NET Core registers `IMeterFactory` in DI by default. Custom meters should be created via the factory for testability and proper DI integration.

#### Built-in Meters (net8.0)
- `Microsoft.AspNetCore.Hosting` — request counts, durations
- `Microsoft.AspNetCore.Server.Kestrel` — connection metrics
- `Microsoft.AspNetCore.Http.Connections` — SignalR connections
- `Microsoft.AspNetCore.Routing` — route match metrics

#### Custom Metrics via IMeterFactory

```csharp
// Define a metrics service
public class OrderMetrics
{
    private readonly Counter<int> _ordersPlaced;
    private readonly Histogram<double> _orderValue;

    public OrderMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create("MyApp.Orders");
        _ordersPlaced = meter.CreateCounter<int>(
            "myapp.orders.placed",
            unit: "{orders}",
            description: "Number of orders placed");
        _orderValue = meter.CreateHistogram<double>(
            "myapp.orders.value",
            unit: "USD",
            description: "Value of orders placed");
    }

    public void RecordOrder(string region, decimal value)
    {
        var tags = new TagList { { "region", region } };
        _ordersPlaced.Add(1, tags);
        _orderValue.Record((double)value, tags);
    }
}

// Register
builder.Services.AddSingleton<OrderMetrics>();

// Use in endpoint
app.MapPost("/orders", (OrderRequest req, OrderMetrics metrics) =>
{
    // process order...
    metrics.RecordOrder(req.Region, req.Total);
    return Results.Created("/orders/123", req);
});
```

#### OpenTelemetry + Prometheus Export

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddPrometheusExporter();
        metrics.AddMeter(
            "Microsoft.AspNetCore.Hosting",
            "Microsoft.AspNetCore.Server.Kestrel",
            "MyApp.Orders");
        metrics.AddView("http.server.request.duration",
            new ExplicitBucketHistogramConfiguration
            {
                Boundaries = [0, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]
            });
    });

app.MapPrometheusScrapingEndpoint(); // Exposes /metrics
```

#### Enriching Built-in Metrics

```csharp
app.Use(async (context, next) =>
{
    var tagsFeature = context.Features.Get<IHttpMetricsTagsFeature>();
    if (tagsFeature != null)
    {
        var tenant = context.Request.Headers["X-Tenant-Id"].ToString();
        tagsFeature.Tags.Add(new KeyValuePair<string, object?>("tenant", tenant));
    }
    await next(context);
});
```

#### Testing Metrics

```csharp
[Fact]
public async Task OrderEndpoint_IncrementsCounter()
{
    var factory = _webAppFactory; // WebApplicationFactory<Program>
    var meterFactory = factory.Services.GetRequiredService<IMeterFactory>();
    var collector = new MetricCollector<int>(meterFactory,
        "MyApp.Orders", "myapp.orders.placed");

    var client = factory.CreateClient();
    await client.PostAsJsonAsync("/orders", new { Region = "US", Total = 99.99 });

    await collector.WaitForMeasurementsAsync(minCount: 1)
        .WaitAsync(TimeSpan.FromSeconds(5));

    var measurement = collector.GetMeasurementSnapshot().Single();
    Assert.Equal("US", measurement.Tags["region"]);
}
```

---

### HTTP/3 Improvements

**TFM:** `net8.0+` | **Transport:** QUIC (via MsQuic)

HTTP/3 uses QUIC instead of TCP, providing faster connection establishment, no head-of-line blocking, and connection migration. Fully supported in .NET 7+; .NET 8 improved stability and configuration options.

#### Platform Requirements
- **Windows:** Windows 11 Build 22000+ or Windows Server 2022; TLS 1.3
- **Linux:** `libmsquic` package from `packages.microsoft.com`
- **macOS:** Not supported

#### Enabling HTTP/3

```csharp
builder.WebHost.ConfigureKestrel((context, options) =>
{
    options.ListenAnyIP(5001, listenOptions =>
    {
        // Always include HTTP/1.1 and HTTP/2 as fallback
        listenOptions.Protocols = HttpProtocols.Http1AndHttp2AndHttp3;
        listenOptions.UseHttps(); // HTTP/3 requires HTTPS / TLS 1.3
    });
});
```

HTTP/3 is discovered by clients via the `alt-svc` response header, which Kestrel automatically adds. The first request uses HTTP/1.1 or HTTP/2, then upgrades.

#### On Native AOT / SlimBuilder

`CreateSlimBuilder` excludes HTTP/3 by default. Re-enable with:

```csharp
var builder = WebApplication.CreateSlimBuilder(args);
builder.WebHost.UseKestrelHttpsConfiguration();
builder.WebHost.UseQuic(); // Enable HTTP/3
```

#### QUIC Transport Options (.NET 8)

```csharp
builder.WebHost.UseQuic(options =>
{
    options.MaxBidirectionalStreamCount = 200; // default 100
    options.MaxUnidirectionalStreamCount = 20; // default 10
});
```

---

### Blazor Web App (Unified Model)

**TFM:** `net8.0` | **Template:** `blazor`

.NET 8 introduces the **Blazor Web App** project template, unifying Blazor Server and Blazor WebAssembly into a single model with per-component render mode selection. The informal term "Blazor United" refers to this unified model.

#### Render Modes

| Render Mode | Class | Render Location | Interactive |
|---|---|---|---|
| Static SSR | (none) | Server | No |
| Interactive Server | `InteractiveServer` | Server | Yes (SignalR) |
| Interactive WebAssembly | `InteractiveWebAssembly` | Client (WASM) | Yes |
| Interactive Auto | `InteractiveAuto` | Server first, then WASM | Yes |

#### Configuration

```csharp
// Program.cs — Server project
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(Client.App).Assembly);
```

#### Per-Component Render Mode

```razor
<!-- Static SSR (default) -->
<MyComponent />

<!-- Interactive Server -->
<MyComponent @rendermode="InteractiveServer" />

<!-- Interactive WebAssembly -->
<MyComponent @rendermode="InteractiveWebAssembly" />

<!-- Auto (Server then WASM after download) -->
<MyComponent @rendermode="InteractiveAuto" />
```

#### Per-Component-Definition (in .razor file)

```razor
@rendermode InteractiveServer

<h1>This component always renders interactively on the server</h1>
```

#### Streaming Rendering

```razor
@attribute [StreamRendering]

@if (data == null)
{
    <p>Loading...</p>
}
else
{
    <DataGrid Items="data" />
}

@code {
    private Data[]? data;

    protected override async Task OnInitializedAsync()
    {
        // First render shows "Loading..." immediately
        // Second render updates when data arrives
        data = await _service.GetDataAsync();
    }
}
```

---

## .NET 9 STS Features

### Built-in OpenAPI Document Generation

**TFM:** `net9.0` | **Package:** `Microsoft.AspNetCore.OpenApi` (first-party, no Swashbuckle)

.NET 9 ships built-in OpenAPI document generation for both Minimal APIs and controller-based APIs, via `AddOpenApi()` and `MapOpenApi()`. Swashbuckle is no longer required for basic scenarios.

#### Basic Setup

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi(); // Register OpenAPI services

var app = builder.Build();

app.MapOpenApi(); // Exposes /openapi/v1.json

app.MapGet("/hello/{name}", (string name) => $"Hello, {name}!")
    .WithName("GetHello")
    .WithSummary("Says hello")
    .WithDescription("Returns a greeting for the given name");

app.Run();
```

Navigate to `/openapi/v1.json` at runtime to view the generated document.

#### Installation

```bash
dotnet add package Microsoft.AspNetCore.OpenApi
```

#### Build-Time Document Generation

```bash
dotnet add package Microsoft.Extensions.ApiDescription.Server
```

```xml
<!-- .csproj — control output location -->
<PropertyGroup>
  <OpenApiDocumentsDirectory>$(MSBuildProjectDirectory)/openapi</OpenApiDocumentsDirectory>
</PropertyGroup>
```

Run `dotnet build` to emit `openapi/v1.json`.

#### Multiple Documents

```csharp
builder.Services.AddOpenApi("v1");
builder.Services.AddOpenApi("v2", options =>
{
    options.AddDocumentTransformer((document, context, ct) =>
    {
        document.Info.Title = "My API v2";
        return Task.CompletedTask;
    });
});

app.MapOpenApi("/openapi/{documentName}.json"); // Dynamic route

// Tag endpoints to documents
app.MapGet("/v1/resource", GetResource).WithGroupName("v1");
app.MapGet("/v2/resource", GetResourceV2).WithGroupName("v2");
```

#### Document / Operation / Schema Transformers

```csharp
builder.Services.AddOpenApi(options =>
{
    // Document-level transformer
    options.AddDocumentTransformer((doc, ctx, ct) =>
    {
        doc.Info.Contact = new OpenApiContact
        {
            Name = "API Support",
            Email = "api@example.com"
        };
        return Task.CompletedTask;
    });

    // Operation-level transformer (e.g., add security requirement)
    options.AddOperationTransformer((operation, ctx, ct) =>
    {
        if (ctx.Description.ActionDescriptor.EndpointMetadata
                .OfType<IAuthorizeData>().Any())
        {
            operation.Security = [new() { ["Bearer"] = [] }];
        }
        return Task.CompletedTask;
    });

    // Schema transformer
    options.AddSchemaTransformer((schema, ctx, ct) =>
    {
        if (ctx.JsonTypeInfo.Type == typeof(decimal))
            schema.Format = "decimal";
        return Task.CompletedTask;
    });
});
```

> **Breaking from Swashbuckle:** The endpoint is `/openapi/v1.json` by default (not `/swagger/v1/swagger.json`). Swagger UI is not included; use Scalar, Redoc, or NSwag UI as a separate package for interactive documentation.

---

### HybridCache

**TFM:** `net9.0` | **Package:** `Microsoft.Extensions.Caching.Hybrid`  
**Status:** Preview at .NET 9 launch; stable release in a subsequent minor of .NET Extensions

`HybridCache` is a unified caching abstraction combining L1 (in-process `IMemoryCache`) and L2 (out-of-process `IDistributedCache` such as Redis), with built-in stampede protection.

#### Key Advantages over IDistributedCache
- Single `GetOrCreateAsync` call — no manual cache miss handling
- Automatic stampede protection (only one call fetches the data when multiple threads miss simultaneously)
- Configurable serialization
- Supports `TState` pattern to minimize allocations in hot paths

#### Setup

```xml
<!-- .csproj -->
<PackageReference Include="Microsoft.Extensions.Caching.Hybrid" Version="9.0.0" />
```

```csharp
builder.Services.AddHybridCache(options =>
{
    options.MaximumPayloadBytes = 1024 * 1024; // 1 MB
    options.DefaultEntryOptions = new HybridCacheEntryOptions
    {
        Expiration = TimeSpan.FromMinutes(5),
        LocalCacheExpiration = TimeSpan.FromMinutes(1)
    };
});

// Optional: configure an L2 distributed cache (e.g. Redis)
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = builder.Configuration.GetConnectionString("Redis"));
```

#### Basic Usage

```csharp
public class ProductService(HybridCache cache, IProductRepository repo)
{
    public async Task<Product?> GetProductAsync(int id, CancellationToken token = default)
    {
        // Cache key, factory delegate — stampede protected
        return await cache.GetOrCreateAsync(
            $"product:{id}",
            async ct => await repo.GetByIdAsync(id, ct),
            cancellationToken: token);
    }

    public async Task InvalidateProductAsync(int id)
    {
        await cache.RemoveAsync($"product:{id}");
    }
}
```

#### TState Pattern (High-Throughput Scenarios)

```csharp
public async Task<Product?> GetProductAsync(int id, CancellationToken token = default)
{
    return await cache.GetOrCreateAsync(
        $"product:{id}",
        (repo, id),  // TState — avoids closure allocation
        static async (state, ct) => await state.repo.GetByIdAsync(state.id, ct),
        cancellationToken: token);
}
```

#### Comparison: IDistributedCache vs HybridCache

```csharp
// Before (.NET 7/8 — IDistributedCache)
public async Task<Product?> GetProductAsync(int id, CancellationToken token)
{
    var key = $"product:{id}";
    var cached = await _cache.GetStringAsync(key, token);
    if (cached != null)
        return JsonSerializer.Deserialize<Product>(cached);

    var product = await _repo.GetByIdAsync(id, token);
    if (product != null)
        await _cache.SetStringAsync(key,
            JsonSerializer.Serialize(product),
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5) },
            token);

    return product;
}

// After (.NET 9 — HybridCache)
public async Task<Product?> GetProductAsync(int id, CancellationToken token)
    => await _cache.GetOrCreateAsync($"product:{id}",
        async ct => await _repo.GetByIdAsync(id, ct),
        cancellationToken: token);
```

---

### MapStaticAssets

**TFM:** `net9.0`

`MapStaticAssets` is a drop-in replacement for `UseStaticFiles` that adds build-time and publish-time optimization: `gzip` compression in development, `gzip + brotli` at publish, content-hash fingerprinting for cache-busting, proper `ETag` and `Last-Modified` headers, and automatic `Cache-Control: max-age=31536000, immutable` for versioned assets.

#### Usage

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddRazorPages();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseAuthorization();

// Replace UseStaticFiles with MapStaticAssets
app.MapStaticAssets(); // instead of app.UseStaticFiles();

app.MapRazorPages();
app.Run();
```

#### How It Works
- At **build time**: collects all static assets (wwwroot, Razor Class Libraries, etc.)
- At **publish time**: compresses with gzip + brotli, computes content hashes
- At **runtime**: serves pre-compressed versions where supported, sets fingerprinted URLs for cache-busting

#### Performance Impact (from Microsoft benchmarks)

| Asset | Raw | MapStaticAssets | Reduction |
|---|---|---|---|
| bootstrap.min.css | 163 KB | 17.5 KB | 89.3% |
| jquery.min.js | 89.6 KB | 28 KB | 68.7% |
| bootstrap.min.js | 78.5 KB | 6 KB | 92.4% |

Total across a typical Blazor app: ~92% reduction vs serving raw files.

#### When to Use `UseStaticFiles` Instead

`MapStaticAssets` only optimizes assets the app knows about at build/publish time. Use `UseStaticFiles` additionally if:
- Serving files from disk at runtime (user uploads, etc.)
- Serving embedded resources from assemblies not referenced at build time

---

### SignalR Native AOT Support

**TFM:** `net9.0` | **Status:** Partial support (continued from .NET 8 where SignalR had no AOT support)

In .NET 9, both the SignalR client and server support Native AOT compilation and trimming.

#### Enabling SignalR with AOT

```bash
dotnet new webapiaot -o SignalRChatAOTExample
```

```csharp
// Program.cs
using System.Text.Json.Serialization;

var builder = WebApplication.CreateSlimBuilder(args);
builder.Services.AddSignalR();

var app = builder.Build();
app.MapHub<ChatHub>("/chat");
app.Run();

public class ChatHub : Hub
{
    public async Task SendMessage(string user, string message)
        => await Clients.All.SendAsync("ReceiveMessage", user, message);
}

// STJ source generator context required for AOT
[JsonSerializable(typeof(string))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }
```

#### AOT Limitations (net9.0)

| Limitation | Detail |
|---|---|
| Protocol | Only JSON protocol supported (MessagePack not supported) |
| Hub method params | `IAsyncEnumerable<T>` and `ChannelReader<T>` with ValueType `T` not supported |
| Strongly typed hubs | Not supported with `PublishAot`; supported with trim-only (`PublishTrimmed`) |
| Return types | Only `Task`, `Task<T>`, `ValueTask`, `ValueTask<T>` |

#### ActivitySource for Distributed Tracing

.NET 9 adds `ActivitySource` support to SignalR for hub server and client:

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing.AddSource("Microsoft.AspNetCore.SignalR.Server");
    });
```

---

### TypedResults Improvements

**TFM:** `net9.0`

#### InternalServerError (new in .NET 9)

```csharp
app.MapGet("/risky", () =>
{
    try
    {
        return TypedResults.Ok("Success");
    }
    catch (Exception ex)
    {
        // New in .NET 9 — strongly typed 500 response
        return TypedResults.InternalServerError($"Error: {ex.Message}");
    }
});
```

#### ProducesProblem / ProducesValidationProblem on Route Groups

```csharp
// Previously only worked on individual endpoints
var api = app.MapGroup("/api")
    .ProducesProblem(StatusCodes.Status500InternalServerError)
    .ProducesValidationProblem(); // Declares validation errors for all endpoints in group

api.MapGet("/products", GetProducts);
api.MapPost("/products", CreateProduct);
```

#### Problem / ValidationProblem with IEnumerable

```csharp
// Previously required IDictionary<string, object?>
// Now accepts IEnumerable<KeyValuePair<string, object?>>
app.MapGet("/validation-error", () =>
{
    var extensions = new List<KeyValuePair<string, object?>>
    {
        new("correlationId", Guid.NewGuid()),
        new("timestamp", DateTime.UtcNow)
    };

    return TypedResults.Problem(
        "Validation failed",
        extensions: extensions);
});
```

---

### Minimal API and OpenAPI Analyzer Improvements

**TFM:** `net9.0`

.NET 9 ships with improved Roslyn analyzers for Minimal APIs:

#### Analyzer Categories

**Route Analysis**
- Detects ambiguous route templates
- Flags unreachable route definitions
- Warns on route parameter name mismatches

**OpenAPI Metadata**
- Warns when `[FromForm]` parameters lack `[Consumes("multipart/form-data")]` metadata
- Flags missing `[ProducesResponseType]` / `Produces<T>()` for documented endpoints
- Suggests `WithOpenApi()` for endpoints missing OpenAPI metadata

**Type Safety**
- `RouteHandlerAnalyzer` validates that route parameters match handler parameter types
- Warns on nullable mismatches for route parameters

#### Enabling in Project

Analyzers are included automatically with the `Microsoft.AspNetCore.App` framework reference in .NET 9 projects. No additional package is needed. To suppress a specific analyzer:

```csharp
#pragma warning disable ASP0018 // Warns about ambiguous routes
app.MapGet("/items/{id}", GetItemById);
#pragma warning restore ASP0018
```

---

## Breaking Changes

### .NET 8

| Area | Change |
|---|---|
| Identity | `MapIdentityApi` tokens are proprietary (not JWTs) — not compatible with external token validators |
| Blazor | Blazor Server and Blazor WebAssembly are now unified into Blazor Web App — separate project templates still exist but are considered legacy |
| Output Caching | `IDistributedCache` is **not recommended** for output cache storage (missing atomic support for tags) |
| Native AOT | Top-level APIs (`AddControllers`, `AddRazorPages`) now emit `IL2026` AOT warnings — these cannot be used in AOT-published apps |
| Minimal APIs | Form binding with `[FromForm]` includes antiforgery validation by default — add `[IgnoreAntiforgeryToken]` to opt out |
| `CreateSlimBuilder` | Excludes many default features (HTTPS, HTTP/3, IIS, EventLog) — must be explicitly re-added |

### .NET 9

| Area | Change |
|---|---|
| OpenAPI | Default endpoint is `/openapi/v1.json` (not `/swagger/v1/swagger.json`) — update client configs |
| OpenAPI | Swagger UI not included — must add Scalar, Redoc, or NSwag UI separately |
| HybridCache | Preview at launch — API surface may change before stable release |
| MapStaticAssets | Asset fingerprinting changes URLs — CDN configs may need updating |
| SignalR AOT | Strongly typed hubs not supported with `PublishAot` (only with `PublishTrimmed`) |
| TypedResults | `InternalServerError` return type is new — existing `Results.StatusCode(500)` still works |

---

## Feature Compatibility Matrix

| Feature | net8.0 | net9.0 | Notes |
|---|---|---|---|
| Native AOT (Minimal APIs) | Partial | Partial | Reflection not supported |
| Native AOT (MVC) | No | No | Not planned |
| Native AOT (SignalR) | No | Partial | .NET 9 adds support |
| Identity API Endpoints | Yes | Yes | Stable in .NET 8 |
| Output Caching + Redis | Yes | Yes | Redis via separate NuGet |
| Short-Circuit Routing | Yes | Yes | Stable in .NET 8 |
| Form Binding (Minimal) | Yes | Yes | Stable in .NET 8 |
| Keyed DI | Yes | Yes | Stable in .NET 8 |
| Request Timeouts | Yes | Yes | Stable in .NET 8 |
| IExceptionHandler | Yes | Yes | Stable in .NET 8 |
| IMeterFactory | Yes | Yes | Stable in .NET 8 |
| HTTP/3 (stable) | Yes | Yes | Stable since .NET 7 |
| Blazor Web App (unified) | Yes | Yes | Introduced in .NET 8 |
| Built-in OpenAPI | No | Yes | New in .NET 9 |
| HybridCache | No | Preview | Stable post-.NET 9 |
| MapStaticAssets | No | Yes | New in .NET 9 |
| TypedResults.InternalServerError | No | Yes | New in .NET 9 |
| ProducesProblem on groups | No | Yes | New in .NET 9 |
| SignalR ActivitySource | No | Yes | New in .NET 9 |
