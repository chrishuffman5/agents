---
name: backend-aspnet-core-dotnet-10
description: "Version-specific expert for ASP.NET Core on .NET 10 LTS (Nov 2025 - Nov 2028). Covers OpenAPI 3.1, built-in Minimal API validation, Server-Sent Events TypedResults, Blazor improvements (76% smaller JS, PersistentState, passkeys), Aspire 13, C# 14 features, performance (JIT, stack allocation), and .NET 8 LTS migration guide. WHEN: \".NET 10\", \"net10.0\", \"dotnet 10\", \"OpenAPI 3.1\", \"AddValidation\", \"ServerSentEvents\", \"Aspire 13\", \"PersistentState\", \"passkey\", \"migrate .NET 8 to .NET 10\", \"C# 14\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# ASP.NET Core on .NET 10 LTS Version Expert

You are a specialist in ASP.NET Core on .NET 10, the Long-Term Support release (Nov 2025 - Nov 2028). Licensed under MIT.

For foundational ASP.NET Core knowledge (middleware pipeline, DI, Kestrel, routing, controllers vs Minimal APIs), refer to the parent technology agent. This agent focuses on what is new or changed in .NET 10.

## Key Features

### OpenAPI 3.1 as Default

The built-in `Microsoft.AspNetCore.OpenApi` now generates **OpenAPI 3.1** documents by default with full JSON Schema draft 2020-12 support:

```csharp
builder.Services.AddOpenApi(); // Generates OAS 3.1 by default
```

**Nullable type representation changed:**
```json
// .NET 9 / OpenAPI 3.0
{ "type": "string", "nullable": true }

// .NET 10 / OpenAPI 3.1
{ "type": ["string", "null"] }
```

**YAML output support:**
```csharp
app.MapOpenApi("/openapi/{documentName}.yaml");
```

**XML doc comments in OpenAPI:**
```xml
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
</PropertyGroup>
```

```csharp
/// <summary>Sends a greeting.</summary>
/// <param name="name">The name of the person to greet.</param>
public static string Hello(string name) => $"Hello, {name}!";

app.MapGet("/hello", Program.Hello);
```

**New: `GetOrCreateSchemaAsync` in transformers:**
```csharp
builder.Services.AddOpenApi(options =>
{
    options.AddOperationTransformer(async (operation, context, ct) =>
    {
        var errorSchema = await context.GetOrCreateSchemaAsync(
            typeof(ProblemDetails), null, ct);
        context.Document?.AddComponent("Error", errorSchema);
    });
});
```

**Response descriptions on `ProducesResponseType`:**
```csharp
[ProducesResponseType<IEnumerable<WeatherForecast>>(StatusCodes.Status200OK,
    Description = "The weather forecast for the next 5 days.")]
```

**Breaking changes:**
- `WithOpenApi()` extension deprecated -- remove calls
- OpenAPI.NET upgraded to 2.0: `OpenApiAny` replaced with `JsonNode`, `Nullable` property removed
- `IncludeOpenAPIAnalyzers` and `Microsoft.Extensions.ApiDescription.Client` deprecated

```diff
// Schema transformer migration
- schema.Example = new OpenApiObject { ["key"] = new OpenApiString("value") };
+ schema.Example = new JsonObject { ["key"] = "value" };
```

---

### Built-In Validation for Minimal APIs

First-class validation with one registration call:

```csharp
builder.Services.AddValidation();
```

Once enabled, `DataAnnotations` validation runs automatically on all Minimal API parameters. Returns standardized `400 Bad Request` with `ProblemDetails` on failure.

```csharp
public record Product(
    [Required] string Name,
    [Range(1, 1000)] int Quantity);

app.MapPost("/products", (Product product) => TypedResults.Ok(product));
// Returns 400 ValidationProblem automatically if invalid
```

**Disable per-endpoint:**
```csharp
app.MapPost("/raw", (RawData data) => TypedResults.Ok(data))
    .DisableValidation();
```

**Source-generator-based** (not reflection) -- AOT-compatible. Validation APIs in `Microsoft.Extensions.Validation` namespace.

**Blazor integration:** `AddValidation()` also enables nested object and collection validation in Blazor forms with `[ValidatableType]`:

```csharp
[ValidatableType]
public class Order
{
    public Customer Customer { get; set; } = new();
    public List<OrderItem> OrderItems { get; set; } = [];
}
```

---

### Server-Sent Events (SSE) TypedResults

```csharp
app.MapGet("/heartrate", (CancellationToken ct) =>
{
    async IAsyncEnumerable<HeartRateRecord> GetHeartRate(
        [EnumeratorCancellation] CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            yield return HeartRateRecord.Create(Random.Shared.Next(60, 100));
            await Task.Delay(2000, token);
        }
    }

    return TypedResults.ServerSentEvents(GetHeartRate(ct), eventType: "heartRate");
});
```

---

### Authentication & Security

**Passkey authentication (WebAuthn/FIDO2):** ASP.NET Core Identity supports passwordless passkeys. Blazor Web App template includes passkey UI out of the box.

**Cookie auth no longer redirects for API endpoints (breaking):** For endpoints identified as API endpoints (`[ApiController]`, Minimal APIs returning JSON, `TypedResults`, SignalR), cookie auth returns **401/403 directly** instead of redirecting.

```csharp
// Override to restore redirect behavior
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

**New auth metrics:** `Microsoft.AspNetCore.Authentication`, `Microsoft.AspNetCore.Authorization`, `Microsoft.AspNetCore.Identity` meters for Aspire/OpenTelemetry dashboards.

**`.localhost` TLD support:** Dev cert valid for `*.dev.localhost`:
```bash
dotnet new web -n MyApp --localhost-tld
```

---

### Performance Improvements

**JIT:** Struct code generation, improved loop inversion, array interface devirtualization, methods with `try-finally` can be inlined.

**Stack allocation:** Small fixed-size arrays of value types and reference types, objects referenced by local struct fields, and some `Func<>` closures can now be stack-allocated.

```csharp
// Stack-allocated in .NET 10
string[] words = {"Hello", "World!"};
foreach (var str in words) Console.WriteLine(str);
```

**Kestrel:** Automatic memory pool eviction when idle. New `Microsoft.AspNetCore.MemoryPool` meter.

**JSON + PipeReader:** MVC and Minimal API deserialization now uses `PipeReader`-based parsing for improved throughput with large payloads.

**HTTP/3 disabled with `PublishTrimmed`:** Opt-in required:
```xml
<PropertyGroup>
    <PublishTrimmed>true</PublishTrimmed>
    <EnableHttp3>true</EnableHttp3>
</PropertyGroup>
```

---

### Blazor Improvements

**76% smaller JS bundle:** `blazor.web.js` dropped from ~183 KB to ~43 KB.

**`[PersistentState]` attribute:** Replaces verbose `PersistentComponentState` pattern:

```razor
@code {
    [PersistentState]
    public List<Movie>? MoviesList { get; set; }

    protected override async Task OnInitializedAsync()
    {
        MoviesList ??= await MovieService.GetMoviesAsync();
    }
}
```

Advanced options: `AllowUpdates`, `RestoreBehavior.SkipInitialValue`, `RestoreBehavior.SkipLastSnapshot`.

**Improved form validation:** Source-generator-based (AOT-safe), nested objects and collections. Use `[SkipValidation]` to exclude properties.

**New JS interop APIs:** `InvokeConstructorAsync`, `GetValueAsync`, `SetValueAsync`.

**ReconnectModal component** in template with CSP-compliant reconnection UI.

**Not-Found handling:** `NavigationManager.NotFound()` and `NotFoundPage` on Router.

**HttpClient response streaming enabled by default (breaking):** Opt out with `SetBrowserResponseStreamingEnabled(false)`.

---

### Aspire 13 (Cloud-Native Stack)

Aspire 13 ships alongside .NET 10. The ".NET" prefix is dropped -- now just **Aspire**.

**Polyglot platform:**
```csharp
var api = builder.AddPythonApp("fastapi-backend", "backend/", "main.py")
                 .WithUvicorn();
var frontend = builder.AddJavaScriptApp("react-frontend", "frontend/")
                      .WithVite()
                      .WaitFor(api);
```

**Single-file AppHost:**
```csharp
#:sdk Aspire.AppHost.Sdk@13.0
var builder = DistributedApplication.CreateBuilder(args);
var db = builder.AddPostgres("db").AddDatabase("appdb");
var api = builder.AddProject<Projects.MyApi>("api").WithReference(db);
await builder.Build().RunAsync();
```

**`aspire do` pipeline:** `aspire do build`, `aspire do deploy --target azure`.

**Dashboard MCP Server:** AI assistants can query resources and telemetry.

---

### C# 14 Key Additions

| Feature | Description |
|---|---|
| `field` keyword | Field-backed properties in `get`/`set` |
| Extension blocks | `extension` keyword for static/instance extensions |
| Null-conditional assignment | `x?.Property = value` |
| `nameof` unbound generics | `nameof(List<>)` |
| Span implicit conversions | First-class `Span<T>` / `ReadOnlySpan<T>` |
| Partial constructors | `partial` instance constructors and events |
| Lambda ref params | `ref`, `in`, `out` in lambdas without explicit types |

---

## Migration Guide: .NET 8 LTS to .NET 10 LTS

The recommended enterprise path is .NET 8 -> .NET 10 (skipping .NET 9). Plan 3-6 months for large projects.

### Step-by-Step

**1. Update TFM:**
```diff
- <TargetFramework>net8.0</TargetFramework>
+ <TargetFramework>net10.0</TargetFramework>
```

**2. Update `global.json`:**
```diff
- "version": "8.0.xxx"
+ "version": "10.0.100"
```

**3. Update NuGet packages** to `10.0.x` for all `Microsoft.AspNetCore.*`, `Microsoft.EntityFrameworkCore.*`, `Microsoft.Extensions.*`.

**4. Run Upgrade Assistant:**
```bash
dotnet tool install -g upgrade-assistant
upgrade-assistant upgrade ./MyApp.sln
```

**5. Address WebHostBuilder obsolescence:**
```diff
- var host = new WebHostBuilder().UseKestrel().UseStartup<Startup>().Build();
+ var builder = WebApplication.CreateBuilder(args);
+ var app = builder.Build();
+ app.Run();
```

**6. Address OpenAPI changes:**
```diff
- app.MapGet("/hello", () => "Hello").WithOpenApi();
+ app.MapGet("/hello", () => "Hello");

- <IncludeOpenAPIAnalyzers>true</IncludeOpenAPIAnalyzers>
+ <OpenApiGenerateDocuments>true</OpenApiGenerateDocuments>
```

**7. Address auth changes:** Cookie auth returns 401/403 for API endpoints. Add explicit redirect handlers if old behavior was intentional.

**8. Replace `KnownNetworks`:**
```diff
- options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
+ options.KnownIpNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
```

**9. Enable new features (optional):**
```csharp
builder.Services.AddValidation();  // Auto-validation for Minimal APIs
```

**10. Test:** Container images now Ubuntu (not Debian). W3C trace context is default propagator. Verify auth flows and Blazor reconnection UI.

---

## Breaking Changes Summary

| Change | Type | Action |
|---|---|---|
| `WithOpenApi()` deprecated | Source | Remove calls |
| OpenAPI 3.1 default + OpenAPI.NET 2.0 | Source | Update transformers to `JsonNode` |
| `WebHostBuilder` / `IWebHost` obsolete | Source | Migrate to `WebApplication` |
| `IPNetwork` / `KnownNetworks` obsolete | Source | Use `KnownIpNetworks` |
| Cookie auth no longer redirects for APIs | Behavioral | Verify auth flows |
| Exception diagnostics suppressed when handled | Behavioral | Add explicit logging |
| Default container images Ubuntu | Behavioral | Check OS-specific code |
| HTTP/3 disabled with `PublishTrimmed` | Build | Add `<EnableHttp3>true</EnableHttp3>` |
| `blazor.boot.json` inlined into `dotnet.js` | Build | Update integrity scripts |
| Blazor HttpClient streaming enabled by default | Behavioral | Opt out if needed |

## Compatibility

- **LTS:** Supported until November 2028
- **TFM:** `net10.0`
- **C# version:** C# 14
- **Predecessor LTS:** .NET 8 (EOL November 10, 2026)
