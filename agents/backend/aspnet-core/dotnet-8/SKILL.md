---
name: backend-aspnet-core-dotnet-8
description: "Version-specific expert for ASP.NET Core on .NET 8 LTS (Nov 2023 - Nov 2026). Covers Native AOT for Web APIs, Identity API endpoints, output caching with Redis, keyed DI services, IExceptionHandler, short-circuit routing, form binding in Minimal APIs, request timeouts middleware, metrics with IMeterFactory, and Blazor Web App unified model. WHEN: \".NET 8\", \"net8.0\", \"dotnet 8\", \"Native AOT web API\", \"Identity API endpoints\", \"MapIdentityApi\", \"keyed services\", \"IExceptionHandler\", \"CreateSlimBuilder\", \"output caching Redis\", \"short-circuit routing\", \"Blazor Web App\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ASP.NET Core on .NET 8 LTS Version Expert

You are a specialist in ASP.NET Core on .NET 8, the Long-Term Support release (Nov 2023 - Nov 2026). Licensed under MIT.

For foundational ASP.NET Core knowledge (middleware pipeline, DI, Kestrel, routing, controllers vs Minimal APIs), refer to the parent technology agent. This agent focuses on what is new or changed in .NET 8.

## Key Features

### Native AOT for Web APIs

Native Ahead-of-Time compilation publishes a self-contained native executable with no JIT runtime. Supported for **Minimal APIs**, **gRPC**, and **Worker Services** only.

```xml
<PropertyGroup>
    <PublishAot>true</PublishAot>
</PropertyGroup>
```

```bash
dotnet new webapiaot -o MyAotApi
```

Uses `CreateSlimBuilder` instead of `CreateBuilder` to minimize deployed size:

```csharp
var builder = WebApplication.CreateSlimBuilder(args);

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0,
        AppJsonSerializerContext.Default);
});

var app = builder.Build();
app.MapGet("/todos", () => new[] { new Todo(1, "Buy milk", false) });
app.Run();

[JsonSerializable(typeof(Todo[]))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }

record Todo(int Id, string Title, bool IsComplete);
```

**What `CreateSlimBuilder` excludes:** hosting startup assemblies, Windows EventLog/Debug/EventSource logging, `UseStaticWebAssets`, IIS integration, Kestrel HTTPS/HTTP/3 by default, regex/alpha routing constraints.

**AOT compatibility (.NET 8):**

| Feature | Support |
|---|---|
| Minimal APIs | Partial |
| gRPC | Full |
| MVC / Razor Pages | Not supported |
| SignalR | Not supported (fixed in .NET 9) |
| JWT Authentication | Full |
| Output Caching | Full |
| Rate Limiting | Full |

**Key constraints:** All JSON types must be on a `JsonSerializerContext` (source generation required). Libraries using runtime reflection are incompatible.

### Request Delegate Generator (RDG)

Replaces runtime reflection with a Roslyn source generator that emits delegate code at **compile time** using C# 12 interceptors:

```xml
<PropertyGroup>
    <EnableRequestDelegateGenerator>true</EnableRequestDelegateGenerator>
</PropertyGroup>
```

Enabled automatically when `PublishAot` is set. Benefits: AOT compatibility, faster startup, compile-time binding warnings.

---

### Identity API Endpoints

Replaces the need for a separate identity server for SPA/mobile API backends. Provides bearer token and cookie authentication via a single call:

```csharp
builder.Services.AddIdentityApiEndpoints<IdentityUser>()
    .AddEntityFrameworkStores<ApplicationDbContext>();
builder.Services.AddAuthorization();

var app = builder.Build();
app.MapIdentityApi<IdentityUser>();
app.MapGet("/secret", () => "Protected!").RequireAuthorization();
```

**Generated endpoints:** `/register`, `/login`, `/refresh`, `/confirmEmail`, `/forgotPassword`, `/resetPassword`, `/manage/2fa`, `/manage/info`, `/logout`.

**Token vs Cookie auth:** Set `useCookies=true` query parameter on `/login` for cookie auth; omit for bearer token auth.

> **Note:** Tokens are proprietary (not standard JWTs). For full OAuth2/OIDC, use Duende IdentityServer or OpenIddict.

---

### Output Caching with Redis

Output caching gained **Redis backend support** in .NET 8:

```csharp
builder.Services.AddStackExchangeRedisOutputCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
    options.InstanceName = "MyApp";
});

builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(p => p.Expire(TimeSpan.FromSeconds(60)));
    options.AddPolicy("Short", p => p.Expire(TimeSpan.FromSeconds(10)));
});

app.UseOutputCache();

app.MapGet("/products", GetProducts).CacheOutput("Short");

// Tag-based eviction
app.MapGet("/blog/{slug}", GetPost).CacheOutput(p => p.Tag("blog"));
app.MapPost("/admin/invalidate-blog", async (IOutputCacheStore store) =>
{
    await store.EvictByTagAsync("blog", default);
    return Results.Ok();
});
```

**Do not use `IDistributedCache`** for output caching -- it lacks atomic features for tag eviction.

---

### Keyed DI Services

Register multiple implementations of the same interface, distinguished by a key:

```csharp
builder.Services.AddKeyedSingleton<ICache, MemoryCache>("memory");
builder.Services.AddKeyedSingleton<ICache, RedisCache>("redis");

// Minimal API injection
app.MapGet("/data", ([FromKeyedServices("redis")] ICache cache) =>
    cache.Get("key"));

// Constructor injection
public class OrderService(
    [FromKeyedServices("redis")] ICache cache,
    [FromKeyedServices("stripe")] IPaymentProcessor payment) { }

// Manual resolution
var cache = sp.GetRequiredKeyedService<ICache>("redis");

// AnyKey fallback
builder.Services.AddKeyedSingleton<ICache>(KeyedService.AnyKey,
    (sp, key) => new DefaultCache(key?.ToString() ?? "default"));
```

Works in Minimal APIs, MVC controllers, SignalR hubs, and Blazor components (`[Inject(Key = "...")]`).

---

### IExceptionHandler Interface

Centralized, structured exception handling. Multiple handlers called in registration order; first returning `true` stops processing:

```csharp
public class ValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken ct)
    {
        if (exception is not ValidationException validationEx)
            return false; // Let next handler try

        httpContext.Response.StatusCode = 400;
        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Title = "Validation Error",
            Detail = validationEx.Message,
            Status = 400
        }, ct);
        return true;
    }
}

builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
app.UseExceptionHandler(_ => { });
```

Handlers are registered as **singletons**. `UseExceptionHandler()` must still be in the pipeline.

---

### Short-Circuit Routing

Skip the full middleware pipeline for specific routes:

```csharp
app.MapGet("/health-simple", () => "OK").ShortCircuit();
app.MapGet("/not-found-path", () => { }).ShortCircuit(statusCode: 404);
app.MapShortCircuit(404, "robots.txt", "favicon.ico", "sitemap.xml");
```

Executes after routing but before downstream middleware (auth, rate limiting). Significant performance optimization for high-traffic paths.

---

### Form Binding in Minimal APIs

```csharp
app.MapPost("/upload", async (
    [FromForm] string username,
    [FromForm] IFormFile profilePicture) =>
{
    using var stream = profilePicture.OpenReadStream();
    return Results.Ok(new { username, size = profilePicture.Length });
});

// Complex type
app.MapPost("/contact", ([FromForm] ContactForm form) => Results.Ok(form));
record ContactForm(string Name, string Email, string Message);
```

Antiforgery validation is automatic with `[FromForm]`. Opt out with `[IgnoreAntiforgeryToken]`.

---

### Request Timeouts Middleware

```csharp
builder.Services.AddRequestTimeouts(options =>
{
    options.DefaultPolicy = new RequestTimeoutPolicy
    {
        Timeout = TimeSpan.FromSeconds(30),
        TimeoutStatusCode = 504
    };
    options.AddPolicy("LongRunning", TimeSpan.FromMinutes(5));
});

app.UseRequestTimeouts();

app.MapGet("/report", GenerateReport).WithRequestTimeout("LongRunning");
app.MapGet("/stream", StreamData).DisableRequestTimeout();
```

When timeout expires, `HttpContext.RequestAborted` is cancelled. Timeouts do not trigger under debugger.

---

### Metrics with IMeterFactory

ASP.NET Core registers `IMeterFactory` in DI by default. Custom meters should use the factory for testability:

```csharp
public class OrderMetrics(IMeterFactory meterFactory)
{
    private readonly Counter<int> _ordersPlaced =
        meterFactory.Create("MyApp.Orders")
            .CreateCounter<int>("myapp.orders.placed", unit: "{orders}");

    public void RecordOrder(string region)
    {
        _ordersPlaced.Add(1, new TagList { { "region", region } });
    }
}

builder.Services.AddSingleton<OrderMetrics>();
```

**Built-in meters:** `Microsoft.AspNetCore.Hosting`, `Microsoft.AspNetCore.Server.Kestrel`, `Microsoft.AspNetCore.Http.Connections`, `Microsoft.AspNetCore.Routing`.

---

### Blazor Web App (Unified Model)

Unifies Blazor Server and WebAssembly into a single model with per-component render mode selection:

| Render Mode | Location | Interactive |
|---|---|---|
| Static SSR | Server | No |
| InteractiveServer | Server (SignalR) | Yes |
| InteractiveWebAssembly | Client (WASM) | Yes |
| InteractiveAuto | Server first, then WASM | Yes |

```razor
<MyComponent @rendermode="InteractiveServer" />
<MyComponent @rendermode="InteractiveWebAssembly" />
<MyComponent @rendermode="InteractiveAuto" />
```

---

### HTTP/3 Improvements

HTTP/3 (QUIC) is fully stable. Re-enable on `CreateSlimBuilder`:

```csharp
var builder = WebApplication.CreateSlimBuilder(args);
builder.WebHost.UseKestrelHttpsConfiguration();
builder.WebHost.UseQuic();
```

Requires Windows 11+ or Linux with `libmsquic`. Not supported on macOS.

---

## Breaking Changes

| Area | Change |
|---|---|
| Identity | `MapIdentityApi` tokens are proprietary (not JWTs) |
| Blazor | Server and WebAssembly unified into Blazor Web App |
| Output Caching | `IDistributedCache` not recommended (no atomic tag support) |
| Native AOT | `AddControllers`, `AddRazorPages` emit AOT warnings |
| Minimal APIs | `[FromForm]` includes antiforgery validation by default |
| `CreateSlimBuilder` | Excludes HTTPS, HTTP/3, IIS, EventLog -- must be re-added |
| Docker | Default HTTP port changed from 80 to 8080 (non-root) |

## Compatibility

- **LTS:** Supported until November 10, 2026
- **TFM:** `net8.0`
- **Enterprise migration:** .NET 8 LTS -> .NET 10 LTS (skip .NET 9 STS)
- **C# version:** C# 12
