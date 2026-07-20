# ASP.NET Core Diagnostics

## Common Middleware Ordering Mistakes

| Symptom | Likely Cause | Fix |
|---|---|---|
| 401 on valid JWT | `UseAuthentication` placed after endpoint mapping, or missing | Move `UseAuthentication()` before `UseAuthorization()` and before `MapControllers()` |
| 403 instead of redirect | `UseAuthorization` before `UseRouting` -- endpoint metadata not available | Move `UseAuthorization()` after `UseRouting()` |
| CORS preflight fails | `UseCors` placed after `UseAuthentication` -- OPTIONS request requires auth | Move `UseCors()` after `UseRouting()` and before `UseAuthentication()` |
| Exceptions not caught | `UseExceptionHandler` placed after middleware that throws | Move `UseExceptionHandler()` to the very first position |
| Static files hit auth | `UseStaticFiles` placed after `UseAuthentication` | Move `UseStaticFiles()` before `UseRouting()` |
| IP address always proxy IP | `UseForwardedHeaders` missing or placed too late | Add `UseForwardedHeaders()` as the first middleware |
| CORS works in dev, fails in prod | `AllowAnyOrigin()` used in dev but not configured for prod domain | Add explicit origin in production CORS policy |

### Correct Order Reference

```csharp
app.UseForwardedHeaders();        // 1. First if behind proxy
app.UseExceptionHandler("/error"); // 2. Catch all exceptions
app.UseHsts();
app.UseHttpsRedirection();
app.UseStaticFiles();              // Before routing
app.UseRouting();                  // Before CORS, Auth
app.UseCors();                     // After routing, before auth
app.UseAuthentication();           // Before authorization
app.UseAuthorization();            // After authentication
app.MapControllers();              // Last
```

---

## DI Resolution Failures

### Captive Dependency

**Error:** `InvalidOperationException: Cannot consume scoped service 'IOrderRepository' from singleton 'OrderService'.`

**Cause:** A Scoped service was injected into a Singleton. The scoped service gets captured for the app's lifetime, breaking per-request isolation.

**Fix:**
```csharp
// Option 1: Make the consumer Scoped too
services.AddScoped<OrderService>();

// Option 2: Inject IServiceScopeFactory and create scopes manually
public class OrderService(IServiceScopeFactory scopeFactory)
{
    public async Task ProcessAsync()
    {
        using var scope = scopeFactory.CreateScope();
        var repo = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
    }
}
```

**Prevention:** Enable scope validation in all environments:
```csharp
builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateScopes = true;
    options.ValidateOnBuild = true;
});
```

### Service Not Registered

**Error:** `InvalidOperationException: Unable to resolve service for type 'IOrderService' while attempting to activate 'OrdersController'.`

**Cause:** The service interface/implementation was not registered in DI.

**Fix:** Add the missing registration:
```csharp
builder.Services.AddScoped<IOrderService, OrderService>();
```

**Common misses:**
- Forgetting `AddDbContext<T>()` for EF Core contexts
- Missing `AddHttpClient()` for `IHttpClientFactory`
- Missing `AddMemoryCache()` for `IMemoryCache`
- Not calling `AddAuthorization()` or `AddAuthentication()`

### Multiple Constructors

**Error:** `InvalidOperationException: Multiple constructors accepting all given argument types have been found.`

**Cause:** DI container cannot determine which constructor to use.

**Fix:** Mark the preferred constructor with `[ActivatorUtilitiesConstructor]`:
```csharp
public class OrderService
{
    [ActivatorUtilitiesConstructor]
    public OrderService(IOrderRepository repo, ILogger<OrderService> logger) { }

    public OrderService(IOrderRepository repo) { }
}
```

### Keyed Service Resolution (.NET 8+)

**Error:** `InvalidOperationException: No service for type 'ICache' has been registered.`

**Cause:** Service was registered with a key but resolved without one (or vice versa).

**Fix:** Use `[FromKeyedServices("key")]` for injection, not `[FromServices]`:
```csharp
// Wrong
public OrderService([FromServices] ICache cache) { }

// Right
public OrderService([FromKeyedServices("redis")] ICache cache) { }
```

---

## Authentication Debugging

### Enable Detailed Auth Logging

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

### Common Auth Issues

| Status | Meaning | Common Cause |
|---|---|---|
| 401 Unauthorized | Token not found, expired, or signature mismatch | Wrong issuer/audience, clock skew, missing `Authorization` header |
| 403 Forbidden | Token valid, user authenticated, lacks required claim/role | Missing role claim, wrong policy name |
| 302 Redirect | Cookie auth redirecting to login | Cookie auth on API endpoint -- add `[ApiController]` or configure events |

### JWT Token Validation

```csharp
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://login.example.com";
        options.Audience = "my-api";

        // Debug events
        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                Console.WriteLine($"Auth failed: {context.Exception.Message}");
                return Task.CompletedTask;
            },
            OnTokenValidated = context =>
            {
                Console.WriteLine($"Token valid for: {context.Principal?.Identity?.Name}");
                return Task.CompletedTask;
            }
        };
    });
```

### Cookie Auth Redirect (.NET 10 Breaking Change)

In .NET 10, cookie auth returns 401/403 directly for API endpoints instead of redirecting. If you need the old redirect behavior:

```csharp
builder.Services.AddAuthentication()
    .AddCookie(options =>
    {
        options.Events.OnRedirectToLogin = context =>
        {
            context.Response.Redirect(context.RedirectUri);
            return Task.CompletedTask;
        };
    });
```

### Inspecting Endpoint Auth Requirements

```csharp
app.Use(async (context, next) =>
{
    var endpoint = context.GetEndpoint();
    var authMetadata = endpoint?.Metadata.GetOrderedMetadata<IAuthorizeData>();
    var allowAnon = endpoint?.Metadata.GetMetadata<IAllowAnonymous>();
    // Log these for debugging
    await next();
});
```

---

## Model Binding Issues

### Debugging Binding Sources

Set logging level for binding diagnostics:
```json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.AspNetCore.Mvc": "Debug",
      "Microsoft.AspNetCore.Routing": "Debug"
    }
  }
}
```

### Common Binding Failures

| Issue | Cause | Fix |
|---|---|---|
| Body always null | Missing `[FromBody]` or wrong `Content-Type` | Ensure `Content-Type: application/json` and `[FromBody]` attribute |
| Query param ignored | Name mismatch between query string and parameter | Use `[FromQuery(Name = "actual_name")]` |
| Route value not bound | Parameter name doesn't match route template token | Ensure names match: `{id}` -> `int id` |
| Complex type from query | `[ApiController]` infers complex types from body | Add explicit `[FromQuery]` |
| Form binding 400 | Antiforgery validation failed (.NET 8+) | Add `[IgnoreAntiforgeryToken]` or configure antiforgery |

### Missing [ApiController] Behavior

Without `[ApiController]`:
- No automatic 400 on invalid ModelState
- No binding source inference (complex types not auto-from-body)
- No ProblemDetails responses

Always use `[ApiController]` on Web API controllers.

---

## Performance Profiling

### Built-in Metrics (.NET 8+)

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddMeter(
            "Microsoft.AspNetCore.Hosting",         // Request counts, durations
            "Microsoft.AspNetCore.Server.Kestrel",  // Connection metrics
            "Microsoft.AspNetCore.Routing");         // Route match metrics

        metrics.AddPrometheusExporter();
    });

app.MapPrometheusScrapingEndpoint(); // Exposes /metrics
```

### Enriching Metrics with Custom Tags

```csharp
app.Use(async (context, next) =>
{
    var tagsFeature = context.Features.Get<IHttpMetricsTagsFeature>();
    if (tagsFeature != null)
    {
        tagsFeature.Tags.Add(new KeyValuePair<string, object?>(
            "tenant", context.Request.Headers["X-Tenant-Id"].ToString()));
    }
    await next(context);
});
```

### Diagnosing Slow Requests

1. **Enable request timing middleware:**
```csharp
app.Use(async (context, next) =>
{
    var sw = Stopwatch.StartNew();
    await next();
    sw.Stop();
    if (sw.ElapsedMilliseconds > 1000)
    {
        var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
        logger.LogWarning("Slow request: {Method} {Path} took {Ms}ms",
            context.Request.Method, context.Request.Path, sw.ElapsedMilliseconds);
    }
});
```

2. **Check for N+1 queries:** Enable EF Core logging at `Information` level to see generated SQL.

3. **Check for synchronous I/O:** Kestrel logs warnings for synchronous I/O by default. Look for `SynchronousIO` in logs.

### Memory Diagnostics

```csharp
// dotnet-counters for live monitoring
// dotnet counters monitor --process-id <PID> Microsoft.AspNetCore.Hosting

// dotnet-dump for heap analysis
// dotnet dump collect --process-id <PID>
// dotnet dump analyze <dump-file>
```

---

## Kestrel Connection Issues

### Connection Debugging

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxConcurrentConnections = 1000;
    options.ConfigureHttpsDefaults(https =>
        https.SslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13);
});
```

Enable `Microsoft.AspNetCore.Server.Kestrel` at `Debug` level to trace connection lifecycle.

### Common Connection Issues

| Issue | Cause | Fix |
|---|---|---|
| Connection refused | App not listening on expected port | Check `ASPNETCORE_URLS` or `ASPNETCORE_HTTP_PORTS` |
| SSL/TLS handshake failure | Certificate issue or protocol mismatch | Verify cert validity, enable TLS 1.2+ |
| Connection reset | Request body too large | Increase `MaxRequestBodySize` |
| 502 Bad Gateway | Reverse proxy can't reach Kestrel | Check proxy config, Kestrel binding address |
| HTTP/3 not working | Missing QUIC support | Install `libmsquic` (Linux), require Windows 11+ |

### Docker Port Binding

```dockerfile
# .NET 8+ default port is 8080 (non-root)
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
```

If using the old port 80, explicitly set `ASPNETCORE_HTTP_PORTS=80`.

---

## Configuration Errors

### Missing Configuration

**Error:** `InvalidOperationException: Value cannot be null. (Parameter 'connectionString')`

**Cause:** Connection string not found in configuration.

**Diagnosis:**
```csharp
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (string.IsNullOrEmpty(connectionString))
    throw new InvalidOperationException("DefaultConnection not configured");
```

### Environment-Specific Configuration Not Loading

**Cause:** `ASPNETCORE_ENVIRONMENT` not set, defaulting to `Production`.

**Fix:** Set the environment:
```bash
# Development
export ASPNETCORE_ENVIRONMENT=Development

# Or in launchSettings.json
"environmentVariables": {
    "ASPNETCORE_ENVIRONMENT": "Development"
}
```

### Configuration Reload Not Working

**Cause:** Using `IOptions<T>` (reads once) instead of `IOptionsSnapshot<T>` or `IOptionsMonitor<T>`.

```csharp
// Won't reflect changes:
IOptions<MyOptions> options  // Singleton, reads at startup

// Will reflect changes:
IOptionsSnapshot<MyOptions> options  // Scoped, per-request
IOptionsMonitor<MyOptions> options   // Singleton, real-time via OnChange
```

---

## OpenAPI / Swagger Issues

### .NET 9+: Endpoint Changed

Default OpenAPI endpoint changed from `/swagger/v1/swagger.json` to `/openapi/v1.json`. Update API client configurations.

### .NET 10: WithOpenApi() Deprecated

Remove `WithOpenApi()` calls. The built-in pipeline handles metadata automatically.

```diff
- app.MapGet("/hello", () => "Hello").WithOpenApi();
+ app.MapGet("/hello", () => "Hello");
```

### .NET 10: Schema Transformer Migration

```diff
// OpenAPI.NET 1.x -> 2.0
- schema.Example = new OpenApiObject { ["key"] = new OpenApiString("value") };
+ schema.Example = new JsonObject { ["key"] = "value" };
```

### Missing Response Types in OpenAPI

Use `TypedResults` instead of `Results` for automatic OpenAPI metadata:

```csharp
// Manual annotation needed:
app.MapGet("/todo/{id}", GetTodo).Produces<Todo>().Produces(404);

// Automatic:
app.MapGet("/todo/{id}",
    async Task<Results<Ok<Todo>, NotFound>> (int id, TodoDb db) => ...);
```

---

## Native AOT Issues

### Common AOT Failures

| Issue | Cause | Fix |
|---|---|---|
| `MissingMethodException` at runtime | Reflection-based code trimmed | Use source generators, add `[DynamicDependency]` |
| JSON serialization fails | Missing `JsonSerializerContext` | Add STJ source generator context |
| MVC not working | Controllers not supported in AOT | Use Minimal APIs |
| SignalR MessagePack fails | Not AOT-compatible (.NET 9) | Use JSON protocol only |
| Trimming warnings | Library uses reflection | Check `PublishTrimmed` warnings, suppress or fix |

### Required Source Generator for JSON

```csharp
[JsonSerializable(typeof(Todo[]))]
[JsonSerializable(typeof(ProblemDetails))]
internal partial class AppJsonSerializerContext : JsonSerializerContext { }

builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0,
        AppJsonSerializerContext.Default);
});
```

### Inspecting Generated Source

```xml
<PropertyGroup>
    <EmitCompilerGeneratedFiles>true</EmitCompilerGeneratedFiles>
</PropertyGroup>
```

Generated files appear in `obj/Debug/net10.0/generated/`.
