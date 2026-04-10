# .NET 10 LTS — ASP.NET Core Research

> **Status**: GA (Generally Available)
> **Released**: November 2025
> **LTS Support**: 3 years — until November 10, 2028
> **Predecessor LTS**: .NET 8 (EOL November 10, 2026)
> **Typical enterprise path**: .NET 8 LTS → .NET 10 LTS (skipping .NET 9 STS)

---

## Table of Contents

1. [Release Overview](#1-release-overview)
2. [OpenAPI Improvements](#2-openapi-improvements)
3. [Blazor Improvements](#3-blazor-improvements)
4. [Minimal API Improvements](#4-minimal-api-improvements)
5. [Authentication & Security](#5-authentication--security)
6. [Performance: Runtime, Kestrel, HTTP/3](#6-performance-runtime-kestrel-http3)
7. [SignalR Enhancements](#7-signalr-enhancements)
8. [gRPC Improvements](#8-grpc-improvements)
9. [Native AOT Expanded Support](#9-native-aot-expanded-support)
10. [Observability & Diagnostics](#10-observability--diagnostics)
11. [Aspire 13 (Cloud-Native Stack)](#11-aspire-13-cloud-native-stack)
12. [C# 14 Key Additions](#12-c-14-key-additions)
13. [Breaking Changes](#13-breaking-changes)
14. [Migration Guide: .NET 8 LTS → .NET 10 LTS](#14-migration-guide-net-8-lts--net-10-lts)
15. [New Project Templates & Defaults](#15-new-project-templates--defaults)

---

## 1. Release Overview

.NET 10 is the Long-Term Support release following .NET 9 (STS). It ships with ASP.NET Core 10, EF Core 10, C# 14, and Aspire 13. The headline themes are:

- **AI-first developer experience** — built-in Microsoft Agent Framework, `Microsoft.Extensions.AI`, Model Context Protocol (MCP) support
- **Performance** — JIT de-abstraction, stack allocation expansion, AVX10.2, Arm64 write-barrier improvements
- **OpenAPI 3.1** — promoted to default, full JSON Schema draft 2020-12 support
- **Blazor completeness** — 76% smaller JS bundle, persistent state, improved form validation, passkey auth
- **Minimal API maturity** — built-in validation, Server-Sent Events, improved form handling
- **Aspire 13** — rebranded as "Aspire", polyglot (Python + JS + .NET), `aspire do` pipeline, MCP-backed dashboard

---

## 2. OpenAPI Improvements

### 2.1 OpenAPI 3.1 Now the Default

The built-in `Microsoft.AspNetCore.OpenApi` package now generates **OpenAPI 3.1** documents by default, upgrading from 3.0. This brings full JSON Schema draft 2020-12 support.

```csharp
// Explicit version opt-in (3.1 is now default)
builder.Services.AddOpenApi(options =>
{
    options.OpenApiVersion = Microsoft.OpenApi.OpenApiSpecVersion.OpenApi3_1;
});
```

Build-time document generation:

```xml
<PropertyGroup>
    <OpenApiGenerateDocuments>true</OpenApiGenerateDocuments>
    <OpenApiGenerateDocumentsOptions>--openapi-version OpenApi3_1</OpenApiGenerateDocumentsOptions>
</PropertyGroup>
```

### 2.2 Nullable Type Representation Changed

OpenAPI 3.1 drops the `nullable: true` property. Types now use array notation:

```json
// .NET 9 / OpenAPI 3.0
{ "type": "string", "nullable": true }

// .NET 10 / OpenAPI 3.1
{ "type": ["string", "null"] }
```

Complex nullable types use `oneOf`:

```json
{
  "oneOf": [
    { "$ref": "#/components/schemas/Address" },
    { "type": "null" }
  ]
}
```

### 2.3 YAML Output Support

```csharp
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi("/openapi/{documentName}.yaml");
}
```

### 2.4 XML Documentation Comments in OpenAPI

Enable in the project file:

```xml
<PropertyGroup>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
</PropertyGroup>
```

XML doc comments on handler methods, `[AsParameters]` classes, and return types are now automatically extracted into the OpenAPI document via a compile-time source generator:

```csharp
static partial class Program
{
    /// <summary>Sends a greeting.</summary>
    /// <remarks>Greeting a person by their name.</remarks>
    /// <param name="name">The name of the person to greet.</param>
    /// <returns>A greeting.</returns>
    public static string Hello(string name) => $"Hello, {name}!";
}

app.MapGet("/hello", Program.Hello);
```

### 2.5 Response Description on ProducesResponseType

```csharp
[HttpGet(Name = "GetWeatherForecast")]
[ProducesResponseType<IEnumerable<WeatherForecast>>(StatusCodes.Status200OK,
    Description = "The weather forecast for the next 5 days.")]
public IEnumerable<WeatherForecast> Get() { ... }
```

### 2.6 Schema Generation in Transformers (`GetOrCreateSchemaAsync`)

A new method on the transformer context lets you reuse ASP.NET Core's own schema logic:

```csharp
builder.Services.AddOpenApi(options =>
{
    options.AddOperationTransformer(async (operation, context, cancellationToken) =>
    {
        var errorSchema = await context.GetOrCreateSchemaAsync(
            typeof(ProblemDetails), null, cancellationToken);
        context.Document?.AddComponent("Error", errorSchema);

        operation.Responses ??= new OpenApiResponses();
        operation.Responses["4XX"] = new OpenApiResponse
        {
            Description = "Bad Request",
            Content = new Dictionary<string, OpenApiMediaType>
            {
                ["application/problem+json"] = new OpenApiMediaType
                {
                    Schema = new OpenApiSchemaReference("Error", context.Document)
                }
            }
        };
    });
});
```

### 2.7 OpenAPI.NET 2.0 — Breaking Change for Transformer Authors

The underlying library was upgraded from OpenAPI.NET 1.x to 2.0. Key changes:

- `OpenApiAny` replaced with `System.Text.Json.Nodes.JsonNode`
- `OpenApiSchema.Nullable` property removed
- Entity types are now interfaces (`IOpenApiSchema`)
- HTTP method is now an object, not an enum

Migration of existing schema transformers:

```csharp
// Old (.NET 9 / OpenAPI.NET 1.x)
schema.Example = new OpenApiObject
{
    ["date"] = new OpenApiString(DateTime.Now.AddDays(1).ToString("yyyy-MM-dd")),
};

// New (.NET 10 / OpenAPI.NET 2.0)
schema.Example = new JsonObject
{
    ["date"] = DateTime.Now.AddDays(1).ToString("yyyy-MM-dd"),
};
```

### 2.8 Native AOT Web API Template Includes OpenAPI

The **ASP.NET Core Web API (Native AOT)** project template now includes `Microsoft.AspNetCore.OpenApi` by default. Disable with `--no-openapi`.

### 2.9 `WithOpenApi` Extension Deprecated

> **Breaking change (source incompatible)**

The `WithOpenApi()` extension method on endpoints is deprecated. The built-in OpenAPI pipeline now handles this automatically. Remove calls to `WithOpenApi()`.

### 2.10 OpenAPI Analyzer & ApiDescription.Client Deprecated

- `IncludeOpenAPIAnalyzers` MSBuild property is deprecated
- `Microsoft.Extensions.ApiDescription.Client` NuGet package deprecated

Use `<OpenApiGenerateDocuments>true</OpenApiGenerateDocuments>` instead.

---

## 3. Blazor Improvements

### 3.1 Blazor Script Bundle — 76% Smaller

The `blazor.web.js` script dropped from ~183 KB to ~43 KB, reducing load times and cache invalidation frequency.

### 3.2 Blazor Framework Asset Preloading

Framework assets are preloaded via `Link` headers in Blazor Web Apps, and via `<link rel="preload">` in standalone WebAssembly:

```html
<link rel="preload" id="webassembly" />
```

### 3.3 Declarative Persistent State (`[PersistentState]`)

Replaces the verbose `PersistentComponentState` service pattern with a simple attribute:

```razor
@page "/movies"
@inject IMovieService MovieService

@if (MoviesList == null)
{
    <p><em>Loading...</em></p>
}
else
{
    <QuickGrid Items="MoviesList.AsQueryable()">...</QuickGrid>
}

@code {
    [PersistentState]
    public List<Movie>? MoviesList { get; set; }

    protected override async Task OnInitializedAsync()
    {
        MoviesList ??= await MovieService.GetMoviesAsync();
    }
}
```

Advanced options:

```csharp
[PersistentState(AllowUpdates = true)]
public WeatherForecast[]? Forecasts { get; set; }

[PersistentState(RestoreBehavior = RestoreBehavior.SkipInitialValue)]
public string NoPrerenderedData { get; set; }

[PersistentState(RestoreBehavior = RestoreBehavior.SkipLastSnapshot)]
public int CounterNotRestoredOnReconnect { get; set; }
```

Custom serializer:

```csharp
builder.Services.AddSingleton<PersistentComponentStateSerializer<TUser>, CustomUserSerializer>();
```

### 3.4 Improved Form Validation (Nested Objects & Collections)

Enable in `Program.cs`:

```csharp
builder.Services.AddValidation();
```

Mark complex types with `[ValidatableType]`:

```csharp
[ValidatableType]
public class Order
{
    public Customer Customer { get; set; } = new();
    public List<OrderItem> OrderItems { get; set; } = [];
}

public class Customer
{
    [Required(ErrorMessage = "Name is required.")]
    public string? FullName { get; set; }

    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress]
    public string? Email { get; set; }
}
```

Validation is now **source-generator-based** (not reflection), making it AOT-compatible. Use `[SkipValidation]` to exclude specific properties.

### 3.5 New JavaScript Interop APIs

**Async (all render modes):**

```csharp
// Construct JS object
var classRef = await JSRuntime.InvokeConstructorAsync("jsInterop.TestClass", "Blazor!");
var text = await classRef.GetValueAsync<string>("text");

// Get/set JS properties
var num = await JSRuntime.GetValueAsync<int>("jsInterop.testObject.num");
await JSRuntime.SetValueAsync("jsInterop.testObject.num", 30);
```

**Sync (WebAssembly only, `IJSInProcessRuntime`):**

```csharp
var inProcRuntime = ((IJSInProcessRuntime)JSRuntime);
var classRef = inProcRuntime.InvokeConstructor("jsInterop.TestClass", "Blazor!");
inProcRuntime.SetValue("jsInterop.testObject.num", 20);
```

### 3.6 Reconnection UI Component

The Blazor Web App template now includes a `ReconnectModal` component with collocated stylesheet and JavaScript. A new `components-reconnect-state-changed` DOM event allows programmatic reconnection state handling:

```javascript
document.addEventListener('components-reconnect-state-changed', (e) => {
    const state = e.detail.state; // 'retrying', 'failed', 'rejected', 'connected'
    console.log('Reconnect state:', state);
});
```

New reconnection state: `"retrying"` — distinct from existing states, allows differentiated UI during retry attempts. No inline styles are inserted (CSP-safe).

### 3.7 Not-Found Handling

```razor
<Router AppAssembly="@typeof(Program).Assembly" NotFoundPage="typeof(Pages.NotFound)">
    <Found Context="routeData">
        <RouteView RouteData="@routeData" />
        <FocusOnNavigate RouteData="@routeData" Selector="h1" />
    </Found>
</Router>
```

Programmatic 404:

```csharp
NavigationManager.NotFound();
```

Status code re-execution middleware:

```csharp
app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
```

### 3.8 NavLink Improvements

- `NavLink` with `NavLinkMatch.All` now ignores query strings and fragments when determining active state.
- `NavigationManager.NavigateTo` no longer scrolls to top on same-page navigations.

### 3.9 QuickGrid Enhancements

Apply CSS classes to rows based on row data:

```razor
<QuickGrid Items="forecasts" RowClass="GetRowClass">
    ...
</QuickGrid>

@code {
    private string? GetRowClass(WeatherForecast f) =>
        f.TemperatureC > 30 ? "hot-day" : null;
}
```

Programmatically close column options:

```razor
<PropertyColumn Property="@(m => m.Title)" Title="Title">
    <ColumnOptions>
        <input type="search" @bind="titleFilter"
               @bind:after="@(() => movieGrid.HideColumnOptionsAsync())" />
    </ColumnOptions>
</PropertyColumn>
```

### 3.10 HttpClient Response Streaming — Breaking Change

> **Breaking change (behavioral)**

Response streaming in Blazor WebAssembly `HttpClient` is now **enabled by default**. `ReadAsStreamAsync()` now returns `BrowserHttpReadStream` (no sync operations) instead of `MemoryStream`.

```csharp
// Opt-out globally in project file:
// <WasmEnableStreamingResponse>false</WasmEnableStreamingResponse>

// Opt-out per-request:
requestMessage.SetBrowserResponseStreamingEnabled(false);
```

### 3.11 Boot Configuration File Inlined

`blazor.boot.json` is now inlined into `dotnet.js`. This affects:
- Integrity check scripts that reference `blazor.boot.json`
- Custom boot resource loading that references the file by name

### 3.12 Passkey Authentication (WebAuthn / FIDO2)

ASP.NET Core Identity now supports passwordless passkey authentication. The Blazor Web App template includes passkey registration/login UI out of the box.

### 3.13 Circuit State Persistence

Server-side Blazor can now persist circuit state across disconnections, handling browser throttling, mobile app switching, and network interruptions.

### 3.14 Hot Reload for Blazor WebAssembly

```xml
<PropertyGroup>
  <WasmEnableHotReload>true</WasmEnableHotReload>
</PropertyGroup>
```

Enabled by default for `Debug` configuration.

### 3.15 New `InputHidden` Component

```razor
<EditForm Model="Parameter" OnValidSubmit="Submit" FormName="Example">
    <InputHidden id="hidden" @bind-Value="Parameter" />
    <button type="submit">Submit</button>
</EditForm>
```

### 3.16 `BlazorCacheBootResources` Removed

All Blazor client assets are now fingerprinted and cached by the browser automatically. Remove this MSBuild property if present:

```diff
- <BlazorCacheBootResources>...</BlazorCacheBootResources>
```

---

## 4. Minimal API Improvements

### 4.1 Built-In Validation

Validation is now a first-class feature with one registration call:

```csharp
builder.Services.AddValidation();
```

Once enabled, `DataAnnotations` validation runs automatically on all Minimal API parameters (route, query, header, body). Returns a standardized `400 Bad Request` with `ProblemDetails` on failure.

Disable per-endpoint:

```csharp
app.MapPost("/products",
    ([EvenNumber(ErrorMessage = "Product ID must be even")] int productId, [Required] string name)
        => TypedResults.Ok(productId))
    .DisableValidation();
```

Validation on record types:

```csharp
public record Product(
    [Required] string Name,
    [Range(1, 1000)] int Quantity);

app.MapPost("/products", (Product product) => TypedResults.Ok(product));
```

Custom error responses via `IProblemDetailsService`:

```csharp
builder.Services.AddProblemDetails();
```

Validation APIs moved to `Microsoft.Extensions.Validation` namespace (backward-compatible redirect from old location).

### 4.2 Server-Sent Events (SSE) — `TypedResults.ServerSentEvents`

```csharp
app.MapGet("/heartrate", (CancellationToken cancellationToken) =>
{
    async IAsyncEnumerable<HeartRateRecord> GetHeartRate(
        [EnumeratorCancellation] CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            yield return HeartRateRecord.Create(Random.Shared.Next(60, 100));
            await Task.Delay(2000, ct);
        }
    }

    return TypedResults.ServerSentEvents(GetHeartRate(cancellationToken),
                                          eventType: "heartRate");
});
```

### 4.3 Empty String as Null for Nullable Form Values

When posting form data, empty strings now bind to `null` for nullable value types:

```csharp
app.MapPost("/todo", ([FromForm] Todo todo) => TypedResults.Ok(todo));

public class Todo
{
    public int Id { get; set; }
    public DateOnly? DueDate { get; set; }  // Empty string → null
    public string Title { get; set; }
    public bool IsCompleted { get; set; }
}
```

---

## 5. Authentication & Security

### 5.1 Passkey Authentication

ASP.NET Core Identity adds WebAuthn/FIDO2 passkey support. Users can authenticate using biometrics or security keys instead of passwords. The Blazor Web App template provides out-of-the-box passkey management UI.

### 5.2 Cookie Auth No Longer Redirects for API Endpoints

> **Breaking change (behavioral)**

For endpoints identified as API endpoints (`[ApiController]`, Minimal APIs returning JSON, `TypedResults`, SignalR), cookie authentication now returns **401/403 directly** instead of redirecting to the login page.

Override default behavior if needed:

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

### 5.3 Authentication & Authorization Metrics

New meters expose auth activity for Aspire/OpenTelemetry dashboards:

**Authentication meter** — `Microsoft.AspNetCore.Authentication`:
- Authenticated request duration
- Challenge count, Forbid count
- Sign-in count, Sign-out count

**Authorization meter** — `Microsoft.AspNetCore.Authorization`:
- Authorization-required request count

**ASP.NET Core Identity meter** — `Microsoft.AspNetCore.Identity`:
- `aspnetcore.identity.user.create.duration`
- `aspnetcore.identity.sign_in.sign_ins`
- `aspnetcore.identity.sign_in.check_password_attempts`
- `aspnetcore.identity.user.verify_token_attempts`
- (and more)

### 5.4 `.localhost` TLD Support

ASP.NET Core / Kestrel now supports `.localhost` top-level domain per RFC 2606/6761:

```json
// launchSettings.json
"applicationUrl": "https://myapp.dev.localhost:7099;http://myapp.dev.localhost:5036"
```

```bash
dotnet new web -n MyApp --localhost-tld
```

The dev cert is automatically valid for `*.dev.localhost`. Kestrel binds to `127.0.0.1`/`::1`.

### 5.5 IPNetwork / KnownNetworks Obsolete

> **Breaking change (source incompatible)**

`IPNetwork` and `ForwardedHeadersOptions.KnownNetworks` are obsolete. Use `KnownIpNetworks` instead:

```csharp
// Old
options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));

// New
options.KnownIpNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
```

### 5.6 Customizable HTTP.sys Security Descriptors

```csharp
var options = new HttpSysOptions();
options.RequestQueueSecurityDescriptor = new GenericSecurityDescriptor(/* ... */);
```

Allows fine-grained control over which Windows users/groups can access the HTTP.sys request queue.

### 5.7 WebAuthn Security Samples Updated

New OIDC, Entra ID, and Windows Authentication samples updated, including:
- `MinimalApiJwt` — demonstrates secure external API calls
- Configuration via `appsettings.json`
- Encrypted distributed token cache for web farm scenarios
- Azure Key Vault + Azure Managed Identities integration

---

## 6. Performance: Runtime, Kestrel, HTTP/3

### 6.1 JIT Improvements

**Struct argument code generation** — physical promotion now eliminates intermediate stack stores when packing struct members into shared registers. Example: passing a `Point(int x, int y)` on x64 now uses a single register instruction instead of store+load.

**Improved loop inversion** — switched from lexical to graph-based loop recognition, enabling more natural loops (`while`, `for`) to benefit from loop cloning, unrolling, and induction variable optimizations.

**Array interface method devirtualization** — the JIT can now devirtualize and inline array interface methods (e.g., `IEnumerable<T>` over `T[]`), eliminating virtual dispatch overhead in `foreach` over arrays.

**Inlining improvements**:
- Methods that become eligible for devirtualization after previous inlining are now considered
- Methods with `try-finally` blocks can be inlined
- Inliner heuristics updated to favor candidates returning small fixed-size arrays (stack-allocation candidates)
- Profile data influences inliner size tolerance more aggressively

**Code layout** — block reordering now modeled as an asymmetric Travelling Salesman Problem with a 3-opt heuristic. Improves hot path density and reduces branch distances.

### 6.2 Stack Allocation Expansion

Stack allocation now covers:
- Small fixed-size arrays of **value types** (new in .NET 10)
- Small fixed-size arrays of **reference types** (new in .NET 10)
- Objects referenced by **local struct fields** (escape analysis improvement)
- **Delegates** / closures (partial; `Func<>` objects that don't escape)

```csharp
// All three allocations may now be stack-allocated:
static void Print()
{
    string[] words = {"Hello", "World!"};  // stack-allocated in .NET 10
    foreach (var str in words)
        Console.WriteLine(str);
}
```

### 6.3 AVX10.2 Support

New `System.Runtime.Intrinsics.X86.Avx10v2` class. Currently disabled by default pending hardware availability.

### 6.4 Arm64 Write-Barrier Improvements

Dynamic write-barrier selection (previously x64-only) is now available on Arm64, handling GC regions more precisely. Benchmarks show **8%–20% GC pause reduction** with the new defaults on Arm64.

### 6.5 Automatic Memory Pool Eviction (Kestrel)

Kestrel, IIS, and HTTP.sys now automatically release memory pool memory to the OS when the application is idle. No configuration required.

```csharp
// Metrics available under "Microsoft.AspNetCore.MemoryPool" meter
```

Custom memory pool factory:

```csharp
services.AddSingleton<IMemoryPoolFactory<byte>, CustomMemoryPoolFactory>();

public class CustomMemoryPoolFactory : IMemoryPoolFactory<byte>
{
    public MemoryPool<byte> Create() => MemoryPool<byte>.Shared;
}
```

### 6.6 JSON + PipeReader Deserialization

MVC, Minimal APIs, and `HttpRequestJsonExtensions.ReadFromJsonAsync` now support `PipeReader`-based JSON deserialization for improved throughput with large payloads.

**Breaking change** for custom `JsonConverter` implementations that don't handle `HasValueSequence`:

```csharp
public override T? Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
{
    if (reader.HasValueSequence)
    {
        var bytes = reader.ValueSequence.ToArray();
        // handle ReadOnlySequence path
    }
    else
    {
        var span = reader.ValueSpan;
        // handle ReadOnlySpan path
    }
}

// Quick opt-out (temporary):
AppContext.SetSwitch("Microsoft.AspNetCore.UseStreamBasedJsonParsing", true);
```

### 6.7 HTTP/3 Note

HTTP/3 support is disabled by default when `PublishTrimmed` is enabled (new in .NET 10 — breaking change). Enable explicitly if needed:

```xml
<PropertyGroup>
    <PublishTrimmed>true</PublishTrimmed>
    <EnableHttp3>true</EnableHttp3>
</PropertyGroup>
```

---

## 7. SignalR Enhancements

### 7.1 Improved Reconnection State Events

The new `components-reconnect-state-changed` DOM event provides granular reconnection tracking with the new `"retrying"` state:

```javascript
document.addEventListener('components-reconnect-state-changed', (e) => {
    switch (e.detail.state) {
        case 'retrying':   // New in .NET 10
            showRetryingUI();
            break;
        case 'failed':
            showFailedUI();
            break;
        case 'rejected':
            showRejectedUI();
            break;
        case 'connected':
            hideReconnectUI();
            break;
    }
});
```

A CSS class `components-reconnect-state-retrying` is also set on the reconnect UI element.

### 7.2 ReconnectModal Component in Template

The Blazor Web App project template now ships a `ReconnectModal` component with collocated stylesheet and JavaScript, CSP-compliant (no programmatic inline styles).

### 7.3 Persistent Component State During Reconnection

`[PersistentState]` with `RestoreBehavior.SkipLastSnapshot` excludes state from being restored on reconnect (useful for live counters or ephemeral data):

```csharp
[PersistentState(RestoreBehavior = RestoreBehavior.SkipLastSnapshot)]
public int LiveCounter { get; set; }
```

---

## 8. gRPC Improvements

### 8.1 OpenAPI Support in gRPC JSON Transcoding

The `Microsoft.AspNetCore.Grpc.JsonTranscoding` package (v10.0.x) integrates with the new OpenAPI 3.1 pipeline. gRPC services exposed via JSON transcoding now automatically appear in the generated OpenAPI document.

### 8.2 File-Based App Support

The `#:package` directive (new in .NET 10 SDK) works with gRPC transcoding:

```csharp
#:package Microsoft.AspNetCore.Grpc.JsonTranscoding@10.0.3
```

### 8.3 Continued Stability

gRPC in .NET 10 continues to benefit from:
- HTTP/3 / QUIC transport (reduced head-of-line blocking)
- Kestrel memory pool eviction (lower idle memory)
- JIT inlining improvements for generated protobuf serializers

---

## 9. Native AOT Expanded Support

### 9.1 OpenAPI in AOT Template

The **ASP.NET Core Web API (Native AOT)** project template now includes `Microsoft.AspNetCore.OpenApi` by default. In previous releases it was excluded due to reflection usage. The package is now source-generator-based for AOT compatibility.

### 9.2 Blazor Form Validation — AOT Compatible

The new source-generator-based validation (`AddValidation()`) replaces reflection-based `DataAnnotations` validation, making form validation AOT-safe in Blazor WebAssembly.

### 9.3 NativeAOT Preinitializer Improvements

NativeAOT's type preinitializer now supports all `conv.*` and `neg` opcodes, enabling preinitialization of methods with casting or negation operations.

### 9.4 SDK Improvements for AOT

- File-based apps (single `.cs` no project file) now support `dotnet publish` with Native AOT
- `dotnet tool exec` — one-shot tool execution
- `any` RuntimeIdentifier for platform-flexible tool packages

### 9.5 HTTP/3 Disabled with `PublishTrimmed`

HTTP/3 (QUIC) support is excluded when `PublishTrimmed=true` to reduce binary size. Enable it explicitly if required (see §6.7).

---

## 10. Observability & Diagnostics

### 10.1 Authentication & Identity Metrics

Full OpenTelemetry-compatible meters (see §5.2 and §5.3).

### 10.2 Memory Pool Metrics

New `Microsoft.AspNetCore.MemoryPool` meter with per-pool allocation/eviction telemetry.

### 10.3 Blazor Component Lifecycle Metrics

New metrics for:
- Component lifecycle (mount, render, unmount)
- Navigation events
- Event handling
- Circuit management (server-side)

### 10.4 Configurable Exception Handler Diagnostics

```csharp
app.UseExceptionHandler(new ExceptionHandlerOptions
{
    SuppressDiagnosticsCallback = context => false
});
```

**Breaking change**: By default, exceptions handled by `IExceptionHandler` are no longer logged automatically. Configure explicitly if exception logging is needed.

### 10.5 Default Trace Context Propagator — W3C Standard

The default trace context propagator is now W3C TraceContext (instead of the legacy format). This affects distributed tracing header propagation when calling external services.

---

## 11. Aspire 13 (Cloud-Native Stack)

Aspire 13 ships alongside .NET 10. The ".NET" prefix is dropped — it is now just **Aspire**.

### 11.1 Polyglot Platform — Python & JavaScript

Python and JavaScript receive first-class orchestration support alongside .NET:

```csharp
// Python (AppHost)
var api = builder.AddPythonApp("fastapi-backend", "backend/", "main.py")
                 .WithUvicorn()           // ASGI support
                 .WithEnvironment("ENV", "production");

// JavaScript (AppHost)
var frontend = builder.AddJavaScriptApp("react-frontend", "frontend/")
                      .WithVite()
                      .WaitFor(api);
```

Features:
- Automatic package manager detection (uv/pip/venv for Python, npm/yarn/pnpm for JS)
- VS Code debugging with breakpoints across all languages
- Production Dockerfile auto-generation

### 11.2 Single-File AppHost

Define an entire distributed application in a single `.cs` file without a `.csproj`:

```csharp
#:sdk Aspire.AppHost.Sdk@13.0
var builder = DistributedApplication.CreateBuilder(args);

var db = builder.AddPostgres("db").AddDatabase("appdb");
var api = builder.AddProject<Projects.MyApi>("api").WithReference(db);
builder.AddProject<Projects.MyFrontend>("frontend").WithReference(api);

await builder.Build().RunAsync();
```

### 11.3 `aspire do` — Pipeline Orchestration

A new composable build/deploy pipeline system:

```bash
aspire do build
aspire do deploy --target azure
```

Supports step dependencies, parallel execution, and replaces monolithic deployment approaches.

### 11.4 Dashboard MCP Server

The Aspire dashboard now exposes an MCP server endpoint, enabling AI assistants (GitHub Copilot, Claude, etc.) to query resources, access telemetry data, and execute commands directly from development environments.

### 11.5 Templates via CLI

```bash
aspire init          # Interactive solution setup
aspire new           # Curated starter templates
```

Includes a React + FastAPI multi-language example template out of the box.

---

## 12. C# 14 Key Additions

Relevant to ASP.NET Core development:

| Feature | Description |
|---|---|
| **Field-backed properties** | `field` keyword in `get`/`set` — smoother auto-property migration |
| **Extension blocks** | `extension` keyword for static/instance extension methods and properties |
| **Null-conditional assignment** | `x?.Property = value` syntax |
| **`nameof` unbound generics** | `nameof(List<>)` — useful in diagnostics/logging |
| **Span implicit conversions** | First-class `Span<T>` / `ReadOnlySpan<T>` implicit conversions |
| **Partial constructors** | `partial` instance constructors and events |
| **Lambda ref params** | `ref`, `in`, `out` in lambdas without explicit types |

---

## 13. Breaking Changes

### 13.1 ASP.NET Core Breaking Changes (Full List)

| Change | Type | Migration Action |
|---|---|---|
| `WithOpenApi()` extension deprecated | Source incompatible | Remove calls; built-in pipeline handles it |
| OpenAPI 3.1 default + OpenAPI.NET 2.0 | Source incompatible | Update schema transformers to use `JsonNode` instead of `OpenApiObject`/`OpenApiString` |
| `IActionContextAccessor` / `ActionContextAccessor` obsolete | Source incompatible | Use `IHttpContextAccessor` or inject `ActionContext` via `IActionContextAccessor` replacement |
| `WebHostBuilder`, `IWebHost`, `WebHost` obsolete | Source incompatible | Migrate to `WebApplicationBuilder` / `WebApplication` |
| `IPNetwork` / `KnownNetworks` obsolete | Source incompatible | Use `KnownIpNetworks` with `IPNetwork` |
| `IncludeOpenAPIAnalyzers` / API analyzers deprecated | Source incompatible | Remove property; use `<OpenApiGenerateDocuments>` |
| `Microsoft.Extensions.ApiDescription.Client` deprecated | Source incompatible | Migrate to built-in OpenAPI document generation |
| Razor runtime compilation obsolete | Source incompatible | Remove `AddRazorRuntimeCompilation()`; use hot reload |
| Cookie auth no longer redirects for API endpoints | Behavioral | Verify auth flows; add explicit redirect handlers if needed |
| Exception diagnostics suppressed when `TryHandleAsync` returns `true` | Behavioral | Add explicit logging in `IExceptionHandler` if required |
| Blazor HttpClient response streaming enabled by default | Behavioral | Add `SetBrowserResponseStreamingEnabled(false)` for sync-dependent code |
| `BlazorCacheBootResources` MSBuild property removed | Build | Remove property from `.csproj` |
| Blazor WebAssembly environment via `launchSettings.json` removed | Build | Use `<WasmApplicationEnvironmentName>` in `.csproj` |
| `blazor.boot.json` inlined into `dotnet.js` | Build | Update any scripts that reference `blazor.boot.json` directly |
| HTTP/3 disabled with `PublishTrimmed` | Build | Add `<EnableHttp3>true</EnableHttp3>` if needed |

### 13.2 .NET 10 Platform Breaking Changes Relevant to ASP.NET Core

| Change | Type | Notes |
|---|---|---|
| Default container images use Ubuntu (not Debian) | Behavioral | Check OS-specific code, package installs |
| `BackgroundService.ExecuteAsync` runs as full `Task` | Behavioral | Exceptions now propagate differently |
| `GetKeyedService()` / `GetKeyedServices()` with `AnyKey` fixed | Behavioral | Keyed DI behavior corrected |
| Null values preserved in configuration | Behavioral | `IConfiguration` null handling changed |
| Console log message no longer duplicated | Behavioral | Log output formatting changes |
| `ProviderAliasAttribute` moved assembly | Source incompatible | Update `using` directives |
| `Default trace context propagator → W3C` | Behavioral | Distributed tracing header format |
| `System.Linq.AsyncEnumerable` in core libraries | Source incompatible | Namespace conflicts if using external `AsyncEnumerable` |
| HTTP/3 disabled with `PublishTrimmed` | Source incompatible | Opt-in required |
| Streaming HTTP responses enabled by default in browser | Behavioral | Blazor WASM `HttpClient` behavior |

---

## 14. Migration Guide: .NET 8 LTS → .NET 10 LTS

### 14.1 Context

- Skipping .NET 9 (STS) is the **recommended enterprise path**
- .NET 8 EOL: **November 10, 2026** — plan migration before this date
- Breaking changes from both .NET 9 and .NET 10 must be addressed
- Recommended timeline: 3–6 months for large projects

### 14.2 Step 1 — Update Target Framework

```diff
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
-    <TargetFramework>net8.0</TargetFramework>
+    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
</Project>
```

Multi-targeting (parallel validation):

```xml
<TargetFrameworks>net8.0;net10.0</TargetFrameworks>
```

### 14.3 Step 2 — Update `global.json`

```diff
{
  "sdk": {
-    "version": "8.0.xxx"
+    "version": "10.0.100"
  }
}
```

### 14.4 Step 3 — Update NuGet Package Versions

```diff
<ItemGroup>
-  <PackageReference Include="Microsoft.AspNetCore.JsonPatch" Version="8.0.0" />
-  <PackageReference Include="Microsoft.EntityFrameworkCore.Tools" Version="8.0.0" />
-  <PackageReference Include="Microsoft.Extensions.Caching.Abstractions" Version="8.0.0" />
+  <PackageReference Include="Microsoft.AspNetCore.JsonPatch" Version="10.0.0" />
+  <PackageReference Include="Microsoft.EntityFrameworkCore.Tools" Version="10.0.0" />
+  <PackageReference Include="Microsoft.Extensions.Caching.Abstractions" Version="10.0.0" />
</ItemGroup>
```

Update all `Microsoft.AspNetCore.*`, `Microsoft.EntityFrameworkCore.*`, `Microsoft.Extensions.*`, and `System.Net.Http.Json` to `10.0.x`.

### 14.5 Step 4 — Use .NET Upgrade Assistant (Automated)

```bash
dotnet tool install -g upgrade-assistant
upgrade-assistant upgrade ./MyApp.sln
```

### 14.6 Step 5 — Address WebHostBuilder Obsolescence

```csharp
// Old (obsolete in .NET 10)
var host = new WebHostBuilder()
    .UseKestrel()
    .UseStartup<Startup>()
    .Build();

// New
var builder = WebApplication.CreateBuilder(args);
// Configure services...
var app = builder.Build();
// Configure middleware...
app.Run();
```

### 14.7 Step 6 — Address OpenAPI Changes

Remove deprecated `WithOpenApi()` calls:

```diff
- app.MapGet("/hello", () => "Hello").WithOpenApi();
+ app.MapGet("/hello", () => "Hello");
```

Replace `IncludeOpenAPIAnalyzers` with `OpenApiGenerateDocuments`:

```diff
- <IncludeOpenAPIAnalyzers>true</IncludeOpenAPIAnalyzers>
+ <OpenApiGenerateDocuments>true</OpenApiGenerateDocuments>
```

Update schema transformers to use `JsonNode`:

```diff
- schema.Example = new OpenApiObject { ["key"] = new OpenApiString("value") };
+ schema.Example = new JsonObject { ["key"] = "value" };
```

Remove `Nullable` property checks:

```diff
- if (schema.Nullable) { ... }
+ if (schema.Type?.Contains("null") == true) { ... }
```

### 14.8 Step 7 — Address Blazor Changes

```diff
# launchSettings.json (WASM environment — no longer used)
# Move to .csproj:
+ <WasmApplicationEnvironmentName>Staging</WasmApplicationEnvironmentName>

# Remove from .csproj:
- <BlazorCacheBootResources>false</BlazorCacheBootResources>
```

Replace verbose persistent state pattern:

```diff
# Old (.NET 8)
- [Inject] private PersistentComponentState ApplicationState { get; set; }
- private PersistingComponentStateSubscription _subscription;
- protected override void OnInitialized() {
-     _subscription = ApplicationState.RegisterOnPersisting(PersistData);
-     if (!ApplicationState.TryTakeFromJson<List<Movie>>("movies", out var movies))
-         movies = await MovieService.GetMoviesAsync();
-     MoviesList = movies;
- }
- private Task PersistData() {
-     ApplicationState.PersistAsJson("movies", MoviesList);
-     return Task.CompletedTask;
- }

# New (.NET 10)
+ [PersistentState]
+ public List<Movie>? MoviesList { get; set; }
+ protected override async Task OnInitializedAsync() {
+     MoviesList ??= await MovieService.GetMoviesAsync();
+ }
```

### 14.9 Step 8 — Address Auth & Cookie Changes

If your app uses cookie auth on API endpoints, verify that unauthenticated requests now get 401/403 instead of redirects. Add explicit redirect handlers if the old behavior was intentional:

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

Replace `KnownNetworks` (if used for proxy forwarding):

```diff
- options.KnownNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
+ options.KnownIpNetworks.Add(new IPNetwork(IPAddress.Parse("10.0.0.0"), 8));
```

### 14.10 Step 9 — Add Validation to Minimal APIs (Optional)

Take advantage of the new built-in validation:

```csharp
// Program.cs
builder.Services.AddValidation();

// Endpoints automatically validated — no other changes needed
// if models already have DataAnnotations attributes
```

### 14.11 Step 10 — Enable New Observability Features (Optional)

```csharp
// Authentication metrics (automatic with .NET 10 auth middleware)
// Identity metrics (automatic with .NET 10 Identity)
// Memory pool metrics (automatic with Kestrel)

// Wire up to Aspire / OpenTelemetry:
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddMeter("Microsoft.AspNetCore.Authentication");
        metrics.AddMeter("Microsoft.AspNetCore.Identity");
        metrics.AddMeter("Microsoft.AspNetCore.MemoryPool");
    });
```

### 14.12 Step 11 — Test

- Run unit and integration tests
- Check container image behavior (now Ubuntu by default)
- Validate distributed tracing (W3C propagator is now default)
- Test Blazor reconnection UI if applicable
- Verify auth flows (cookie redirect behavior change)

---

## 15. New Project Templates & Defaults

### 15.1 Template Changes

| Template | Notable Default Changes |
|---|---|
| `dotnet new web` | Includes OpenAPI 3.1 by default |
| `dotnet new webapi` | OpenAPI 3.1, `AddValidation()` option |
| `dotnet new webapi --aot` | Now includes `Microsoft.AspNetCore.OpenApi` |
| `dotnet new blazor` | Includes `ReconnectModal`, passkey UI wiring |
| `dotnet new blazor --localhost-tld` | Binds to `*.dev.localhost` with dev cert |
| `dotnet new sln` | Defaults to `.slnx` format (new in .NET 10 SDK) |

### 15.2 SDK Defaults Changed

- `dotnet restore` now audits **transitive packages** (not just direct)
- `dotnet tool install --local` creates a tool manifest by default
- `PackageReference` without a version now raises an error (`NU1015`)
- `--interactive` defaults to `true` in user-facing scenarios
- CLI non-command data goes to `stderr` (not `stdout`)
- `dotnet watch` logs to `stderr`

### 15.3 Container Image Defaults

Default .NET 10 container images are now based on **Ubuntu** (not Debian Bookworm). If you have OS-specific dependencies (apt packages, paths), update Dockerfiles.

---

## Sources

- [What's new in ASP.NET Core 10.0 — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/release-notes/aspnetcore-10.0?view=aspnetcore-10.0)
- [What's new in .NET 10 — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview)
- [What's new in .NET 10 Runtime — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/runtime)
- [Breaking changes in .NET 10 — Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/compatibility/10)
- [Breaking changes in ASP.NET Core 10 — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/breaking-changes/10/overview?view=aspnetcore-10.0)
- [Migrate from ASP.NET Core .NET 9 to .NET 10 — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/migration/90-to-100?view=aspnetcore-10.0)
- [Announcing .NET 10 — .NET Blog](https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/)
- [What's new in Aspire 13 — aspire.dev](https://aspire.dev/whats-new/aspire-13/)
- [ASP.NET Core in .NET 10: Major Updates — InfoQ](https://www.infoq.com/news/2025/12/asp-net-core-10-release/)
- [Breaking Changes in .NET 10: A Migration Guide from .NET 8 — GapVelocity](https://www.gapvelocity.ai/blog/dotnet8-to-dotnet10-migration-guide)
- [.NET 10 breaking changes and upgrade tips — Duende Software](https://duendesoftware.com/blog/20251104-dotnet-10-breaking-changes-to-keep-an-eye-on-when-upgrading)
- [Customize OpenAPI documents — Microsoft Learn](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/customize-openapi?view=aspnetcore-10.0)
- [Aspire 13 launches — hexmaster.nl](https://hexmaster.nl/posts/aspire-13-launches-a-new-era/)
