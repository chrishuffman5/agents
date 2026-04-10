---
name: backend-aspnet-core-dotnet-9
description: "Version-specific expert for ASP.NET Core on .NET 9 STS (Nov 2024 - May 2026). Covers built-in OpenAPI document generation, HybridCache, MapStaticAssets, SignalR Native AOT support, TypedResults improvements, and OpenAPI analyzer improvements. WHEN: \".NET 9\", \"net9.0\", \"dotnet 9\", \"AddOpenApi\", \"MapOpenApi\", \"HybridCache\", \"MapStaticAssets\", \"SignalR AOT\", \"TypedResults.InternalServerError\", \"ProducesProblem groups\", \"Scalar API\"."
license: MIT
metadata:
  version: "1.0.0"
  author: chris
---

# ASP.NET Core on .NET 9 STS Version Expert

You are a specialist in ASP.NET Core on .NET 9, the Standard-Term Support release (Nov 2024 - May 2026). Licensed under MIT.

For foundational ASP.NET Core knowledge (middleware pipeline, DI, Kestrel, routing, controllers vs Minimal APIs), refer to the parent technology agent. This agent focuses on what is new or changed in .NET 9.

## Key Features

### Built-in OpenAPI Document Generation

.NET 9 ships first-class OpenAPI generation for both Minimal APIs and controllers via `Microsoft.AspNetCore.OpenApi`. Swashbuckle is no longer required.

```csharp
builder.Services.AddOpenApi();
var app = builder.Build();
app.MapOpenApi(); // Serves at /openapi/v1.json

app.MapGet("/hello/{name}", (string name) => $"Hello, {name}!")
    .WithName("GetHello")
    .WithSummary("Says hello")
    .WithDescription("Returns a greeting for the given name");
```

**Key differences from Swashbuckle:**
- Default endpoint: `/openapi/v1.json` (not `/swagger/v1/swagger.json`)
- No Swagger UI included -- add Scalar, Redoc, or NSwag UI separately

```csharp
// NuGet: Scalar.AspNetCore
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(); // UI at /scalar/v1
}
```

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

app.MapOpenApi("/openapi/{documentName}.json");

app.MapGet("/v1/resource", GetResource).WithGroupName("v1");
app.MapGet("/v2/resource", GetResourceV2).WithGroupName("v2");
```

#### Document / Operation / Schema Transformers

```csharp
builder.Services.AddOpenApi(options =>
{
    // Document-level
    options.AddDocumentTransformer((doc, ctx, ct) =>
    {
        doc.Info.Contact = new OpenApiContact
        {
            Name = "API Support", Email = "api@example.com"
        };
        return Task.CompletedTask;
    });

    // Operation-level (e.g., add security requirement)
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

#### Build-Time Generation

```bash
dotnet add package Microsoft.Extensions.ApiDescription.Server
dotnet build  # Outputs openapi/v1.json
```

```xml
<PropertyGroup>
    <OpenApiDocumentsDirectory>$(MSBuildProjectDirectory)/openapi</OpenApiDocumentsDirectory>
</PropertyGroup>
```

---

### HybridCache

Unified caching abstraction combining L1 (in-process `IMemoryCache`) and L2 (out-of-process `IDistributedCache` like Redis), with built-in stampede protection.

```xml
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

// Optional L2 backend
builder.Services.AddStackExchangeRedisCache(options =>
    options.Configuration = builder.Configuration.GetConnectionString("Redis"));
```

#### Basic Usage

```csharp
public class ProductService(HybridCache cache, IProductRepository repo)
{
    public async Task<Product?> GetProductAsync(int id, CancellationToken ct = default)
    {
        return await cache.GetOrCreateAsync(
            $"product:{id}",
            async token => await repo.GetByIdAsync(id, token),
            cancellationToken: ct);
    }

    public async Task InvalidateProductAsync(int id)
    {
        await cache.RemoveAsync($"product:{id}");
    }
}
```

#### TState Pattern (High-Throughput)

Avoids closure allocation in hot paths:

```csharp
return await cache.GetOrCreateAsync(
    $"product:{id}",
    (repo, id),  // TState -- avoids closure
    static async (state, ct) => await state.repo.GetByIdAsync(state.id, ct),
    cancellationToken: ct);
```

**Key advantages over `IDistributedCache`:**
- Single `GetOrCreateAsync` call (no manual cache miss handling)
- Automatic stampede protection
- Configurable serialization
- L1 + L2 in one abstraction

---

### MapStaticAssets

Drop-in replacement for `UseStaticFiles` with build-time and publish-time optimization:

```csharp
app.MapStaticAssets(); // Instead of app.UseStaticFiles()
```

**What it does:**
- Build time: collects static assets (wwwroot, Razor Class Libraries)
- Publish time: compresses with gzip + brotli, computes content hashes
- Runtime: serves pre-compressed versions, fingerprinted URLs for cache-busting

**Performance impact (Microsoft benchmarks):**

| Asset | Raw | MapStaticAssets | Reduction |
|---|---|---|---|
| bootstrap.min.css | 163 KB | 17.5 KB | 89.3% |
| jquery.min.js | 89.6 KB | 28 KB | 68.7% |
| bootstrap.min.js | 78.5 KB | 6 KB | 92.4% |

**When to keep `UseStaticFiles`:** For files not known at build time (user uploads, runtime-loaded resources).

---

### SignalR Native AOT Support

Both SignalR client and server support Native AOT compilation in .NET 9:

```csharp
var builder = WebApplication.CreateSlimBuilder(args);
builder.Services.AddSignalR();

var app = builder.Build();
app.MapHub<ChatHub>("/chat");
app.Run();

[JsonSerializable(typeof(string))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }
```

**AOT limitations (.NET 9):**

| Limitation | Detail |
|---|---|
| Protocol | JSON only (MessagePack not supported) |
| Strongly typed hubs | Not supported with `PublishAot` (only `PublishTrimmed`) |
| Return types | `Task`, `Task<T>`, `ValueTask`, `ValueTask<T>` only |

#### ActivitySource for Distributed Tracing

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracing =>
    {
        tracing.AddSource("Microsoft.AspNetCore.SignalR.Server");
    });
```

---

### TypedResults Improvements

#### InternalServerError (new)

```csharp
app.MapGet("/risky", () =>
{
    try { return TypedResults.Ok("Success"); }
    catch (Exception ex)
    {
        return TypedResults.InternalServerError($"Error: {ex.Message}");
    }
});
```

#### ProducesProblem / ProducesValidationProblem on Route Groups

Previously only worked on individual endpoints:

```csharp
var api = app.MapGroup("/api")
    .ProducesProblem(StatusCodes.Status500InternalServerError)
    .ProducesValidationProblem();

api.MapGet("/products", GetProducts);
api.MapPost("/products", CreateProduct);
```

#### Problem/ValidationProblem with IEnumerable

```csharp
var extensions = new List<KeyValuePair<string, object?>>
{
    new("correlationId", Guid.NewGuid()),
    new("timestamp", DateTime.UtcNow)
};
return TypedResults.Problem("Validation failed", extensions: extensions);
```

---

### Minimal API and OpenAPI Analyzer Improvements

.NET 9 ships improved Roslyn analyzers included automatically with the framework reference:

**Route analysis:** Detects ambiguous routes, unreachable definitions, parameter name mismatches.

**OpenAPI metadata:** Warns when `[FromForm]` parameters lack `[Consumes]` metadata, flags missing `[ProducesResponseType]`.

**Type safety:** `RouteHandlerAnalyzer` validates route parameter types, warns on nullable mismatches.

```csharp
#pragma warning disable ASP0018 // Suppress specific analyzer
app.MapGet("/items/{id}", GetItemById);
#pragma warning restore ASP0018
```

---

## Breaking Changes

| Area | Change |
|---|---|
| OpenAPI | Default endpoint is `/openapi/v1.json` (not `/swagger/v1/swagger.json`) |
| OpenAPI | Swagger UI not included -- add Scalar, Redoc, or NSwag UI |
| HybridCache | Preview at launch -- API surface may change |
| MapStaticAssets | Asset fingerprinting changes URLs -- CDN configs may need updating |
| SignalR AOT | Strongly typed hubs not supported with `PublishAot` |
| TypedResults | `InternalServerError` is new -- existing `Results.StatusCode(500)` still works |

## Compatibility

- **STS:** Supported until May 2026
- **TFM:** `net9.0`
- **Enterprise guidance:** Skip .NET 9 STS; go .NET 8 LTS -> .NET 10 LTS. Use .NET 9 only for greenfield non-LTS projects.
- **C# version:** C# 13
