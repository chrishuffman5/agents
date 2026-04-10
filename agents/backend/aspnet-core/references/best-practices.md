# ASP.NET Core Best Practices

## Configuration Patterns

### Structured Configuration

```json
// appsettings.json
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
  }
}
```

### Options Pattern Best Practices

1. **Always use `ValidateOnStart()`** to fail fast on misconfiguration:

```csharp
builder.Services.AddOptions<OrderServiceOptions>()
    .Bind(builder.Configuration.GetSection("OrderService"))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

2. **Use `IOptionsMonitor<T>` in Singletons** (not `IOptionsSnapshot<T>` which is Scoped):

```csharp
public class FeatureFlagService(IOptionsMonitor<FeatureFlags> monitor)
{
    public bool IsBulkImportEnabled => monitor.CurrentValue.EnableBulkImport;
}
```

3. **Use `IOptionsSnapshot<T>` in Scoped services** for per-request configuration refresh:

```csharp
public class OrderService(IOptionsSnapshot<OrderServiceOptions> options)
{
    private readonly OrderServiceOptions _opts = options.Value;
}
```

4. **Never inject `IConfiguration` directly into services.** Bind to strongly-typed options instead.

### User Secrets (Development)

```bash
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=dev;..."
dotnet user-secrets set "ApiKeys:Stripe" "sk_test_..."
```

Stored at `%APPDATA%/Microsoft/UserSecrets/{UserSecretsId}/secrets.json`. Never committed to source control.

---

## Security Hardening

### Authentication Setup

```csharp
// JWT Bearer
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://login.example.com";
        options.Audience = "my-api";
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });
```

### CORS Configuration

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("Production", policy =>
    {
        policy.WithOrigins("https://app.example.com")
              .WithMethods("GET", "POST", "PUT", "DELETE")
              .WithHeaders("Authorization", "Content-Type")
              .SetPreflightMaxAge(TimeSpan.FromHours(1));
    });
});

// NEVER use AllowAnyOrigin() with AllowCredentials() -- browser will reject
```

### HTTPS and HSTS

```csharp
app.UseHsts();               // Strict-Transport-Security header
app.UseHttpsRedirection();   // Redirect HTTP -> HTTPS

// Configure HSTS options
builder.Services.AddHsts(options =>
{
    options.Preload = true;
    options.IncludeSubDomains = true;
    options.MaxAge = TimeSpan.FromDays(365);
});
```

### Rate Limiting (.NET 7+)

```csharp
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("api", opt =>
    {
        opt.Window = TimeSpan.FromMinutes(1);
        opt.PermitLimit = 100;
        opt.QueueLimit = 10;
        opt.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
    });

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
});

app.UseRateLimiter();

app.MapGet("/api/data", GetData).RequireRateLimiting("api");
```

### Security Headers

Add security headers via middleware:

```csharp
app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["X-XSS-Protection"] = "1; mode=block";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    context.Response.Headers["Content-Security-Policy"] = "default-src 'self'";
    await next();
});
```

### Anti-Forgery (Form Endpoints)

```csharp
builder.Services.AddAntiforgery();
app.UseAntiforgery();

// Minimal API form binding validates antiforgery tokens automatically (.NET 8+)
app.MapPost("/form", ([FromForm] string name) => Results.Ok(name));
```

---

## Performance Tuning

### Response Compression

```csharp
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<BrotliCompressionProvider>();
    options.Providers.Add<GzipCompressionProvider>();
});

builder.Services.Configure<BrotliCompressionProviderOptions>(options =>
    options.Level = CompressionLevel.Optimal);

app.UseResponseCompression(); // Before UseStaticFiles
```

### Output Caching (.NET 7+)

```csharp
builder.Services.AddOutputCache(options =>
{
    options.AddBasePolicy(p => p.Expire(TimeSpan.FromSeconds(60)));
    options.AddPolicy("Short", p => p.Expire(TimeSpan.FromSeconds(10)));
    options.AddPolicy("ByUser", p =>
        p.SetVaryByQuery("userId").Expire(TimeSpan.FromMinutes(5)));
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

**Redis backend (.NET 8+):**

```csharp
builder.Services.AddStackExchangeRedisOutputCache(options =>
{
    options.Configuration = builder.Configuration.GetConnectionString("Redis");
    options.InstanceName = "MyApp";
});
```

### Kestrel Tuning

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxConcurrentConnections = 1000;
    options.Limits.MaxRequestBodySize = 10 * 1024 * 1024;  // 10 MB
    options.Limits.MinRequestBodyDataRate = new MinDataRate(
        bytesPerSecond: 100, gracePeriod: TimeSpan.FromSeconds(10));
    options.Limits.Http2.MaxStreamsPerConnection = 100;
});
```

### Connection Pooling (HttpClient)

```csharp
// Use IHttpClientFactory -- never create HttpClient instances directly
builder.Services.AddHttpClient("github", client =>
{
    client.BaseAddress = new Uri("https://api.github.com/");
    client.DefaultRequestHeaders.Add("User-Agent", "MyApp");
}).ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
{
    PooledConnectionLifetime = TimeSpan.FromMinutes(5),
    MaxConnectionsPerServer = 100
});
```

### JSON Serialization

```csharp
// Configure System.Text.Json globally
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    options.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    options.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
});
```

### Request Timeouts (.NET 8+)

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

---

## Testing Patterns

### Integration Testing with WebApplicationFactory

```csharp
public class OrderApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public OrderApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace real DB with in-memory
                services.RemoveAll<DbContextOptions<AppDbContext>>();
                services.AddDbContext<AppDbContext>(options =>
                    options.UseInMemoryDatabase("TestDb"));
            });
        }).CreateClient();
    }

    [Fact]
    public async Task GetOrders_Returns200()
    {
        var response = await _client.GetAsync("/api/orders");
        response.EnsureSuccessStatusCode();
        var orders = await response.Content.ReadFromJsonAsync<List<OrderDto>>();
        Assert.NotNull(orders);
    }
}
```

### Unit Testing Minimal API Handlers with TypedResults

```csharp
[Fact]
public async Task GetTodo_Returns404_WhenMissing()
{
    await using var db = new MockDb().CreateDbContext();

    var result = await TodoEndpoints.GetTodo(999, db);

    Assert.IsType<NotFound>(result.Result);
}
```

### Testing Custom Metrics

```csharp
[Fact]
public async Task OrderEndpoint_IncrementsCounter()
{
    var meterFactory = _factory.Services.GetRequiredService<IMeterFactory>();
    var collector = new MetricCollector<int>(meterFactory,
        "MyApp.Orders", "myapp.orders.placed");

    await _client.PostAsJsonAsync("/orders", new { Region = "US", Total = 99.99 });

    await collector.WaitForMeasurementsAsync(minCount: 1)
        .WaitAsync(TimeSpan.FromSeconds(5));

    Assert.Equal("US", collector.GetMeasurementSnapshot().Single().Tags["region"]);
}
```

---

## Deployment Patterns

### Docker Multi-Stage Build

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

**.NET 10 change:** Default container images are Ubuntu (not Debian). Check OS-specific dependencies.

### Health Checks

```csharp
builder.Services.AddHealthChecks()
    .AddSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")!)
    .AddRedis(builder.Configuration.GetConnectionString("Redis")!)
    .AddCheck<CustomHealthCheck>("custom");

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = _ => false  // Always healthy (liveness)
});
```

### Azure App Service

- Windows: in-process IIS hosting or out-of-process
- Linux: runs in Docker containers
- Configuration via Application Settings (maps to environment variables)
- Enable "Always On" to prevent cold starts
- Use deployment slots for blue/green deployments

### Native AOT Deployment (.NET 8+)

```xml
<PropertyGroup>
    <PublishAot>true</PublishAot>
</PropertyGroup>
```

```bash
dotnet publish -c Release -r linux-x64
# Produces ~8.5 MB self-contained native executable
```

Requires `CreateSlimBuilder` and STJ source generators. MVC/Razor Pages not supported.

---

## Error Handling Best Practices

### Centralized Exception Handling (.NET 8+)

```csharp
public class ValidationExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken ct)
    {
        if (exception is not ValidationException validationEx)
            return false;

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

// Registration order matters -- first handler that returns true wins
builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
app.UseExceptionHandler(_ => { });
```

### ProblemDetails for All Error Responses

```csharp
builder.Services.AddProblemDetails(options =>
{
    options.CustomizeProblemDetails = ctx =>
    {
        ctx.ProblemDetails.Extensions["traceId"] =
            Activity.Current?.Id ?? ctx.HttpContext.TraceIdentifier;
        ctx.ProblemDetails.Extensions["instance"] = ctx.HttpContext.Request.Path;
    };
});
```

### Never Expose Stack Traces in Production

The `UseDeveloperExceptionPage()` middleware should only be used in Development. In Production, use `UseExceptionHandler` which returns a generic error without sensitive details.

---

## API Design

### Versioning

```csharp
// NuGet: Asp.Versioning.Http (Minimal APIs) or Asp.Versioning.Mvc (Controllers)
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ApiVersionReader = ApiVersionReader.Combine(
        new UrlSegmentApiVersionReader(),
        new HeaderApiVersionReader("X-Api-Version"));
});
```

### Pagination

```csharp
app.MapGet("/api/orders", async (int page = 1, int size = 20, OrderDb db) =>
{
    var total = await db.Orders.CountAsync();
    var items = await db.Orders
        .Skip((page - 1) * size)
        .Take(size)
        .ToListAsync();

    return Results.Ok(new { items, total, page, size,
        totalPages = (int)Math.Ceiling(total / (double)size) });
});
```

### Consistent Response Envelope

Keep responses consistent across endpoints. Use ProblemDetails for errors (RFC 7807) and a simple wrapper for success:

```csharp
// Success: return the resource directly (REST standard)
return TypedResults.Ok(order);

// Error: always ProblemDetails
return TypedResults.Problem(
    title: "Order not found",
    detail: $"Order {id} does not exist",
    statusCode: 404);
```
