# Blazor Architecture Reference

Deep reference for Blazor Web App architecture across .NET 8, 9, and 10. Covers render modes, Razor components, dependency injection, SignalR, WebAssembly, Hybrid, and enhanced navigation.

---

## Render Modes

Blazor Web App (.NET 8+) unifies all rendering strategies under one model. Each component or page can opt into a specific render mode independently.

### Four Render Modes

| Mode | Directive | Rendering Location | Interactivity |
|---|---|---|---|
| Static SSR | _(default / none)_ | Server, HTML streamed | None -- plain HTML |
| Interactive Server | `@rendermode InteractiveServer` | Server via SignalR | Full, real-time |
| Interactive WebAssembly | `@rendermode InteractiveWebAssembly` | Browser (.NET WASM) | Full, client-side |
| Interactive Auto | `@rendermode InteractiveAuto` | Server first, then WASM | Full, progressive |

### Static SSR

Default mode. No `@rendermode` directive needed. Server renders HTML on each request and streams it. No persistent connection. Fastest initial load, smallest payload. No event handlers (`@onclick` etc.) are active -- use `<form>` with Enhanced Form Handling. Best for content pages, landing pages, SEO-critical content.

### Interactive Server

Component runs on the server inside a circuit -- a dedicated SignalR connection per user session. UI events sent to server; DOM diffs streamed back as binary patches. Full access to server resources (DB, file system, secrets) without CORS. Latency-sensitive: each keypress round-trips to server. Best for intranet tools, dashboards, apps needing server resources.

### Interactive WebAssembly

.NET runtime + app assemblies downloaded to the browser and run in WASM sandbox. After initial download, no server connection required. Cannot directly access server-side resources -- must call APIs. Best for offline-capable apps, high-interactivity UI, CDN-deployable SPAs.

### Interactive Auto

Phase 1: renders as Interactive Server while WASM assets download in background. Phase 2: subsequent visits use WASM (assets cached). Fast first interactive without sacrificing offline capability. Requires both Server and WASM projects.

### Per-Component and Per-Page Configuration

```razor
@* Per-page: apply to entire routable page *@
@page "/dashboard"
@rendermode InteractiveServer

@* Per-component: applied at usage site *@
<MyChart @rendermode="InteractiveWebAssembly" />

@* Disable prerendering for a specific component *@
<MyChart @rendermode="new InteractiveServerRenderMode(prerender: false)" />
```

The `@rendermode` at the component usage site overrides any page-level setting for that component.

### Prerendering

Enabled by default for Interactive Server and Interactive WebAssembly. Server generates static HTML immediately (fast FCP), then hydrates once the circuit/WASM is ready.

State loss hazard: `OnInitializedAsync` runs twice -- once during prerender (no circuit), once after hydration. Use `PersistentComponentState` to carry prerender data into the interactive phase. Disable selectively with `new InteractiveServerRenderMode(prerender: false)` when prerender causes side effects.

---

## Razor Components

### File Structure

```razor
@page "/counter"
@rendermode InteractiveServer

<h1>Count: @currentCount</h1>
<button @onclick="Increment">+1</button>

@code {
    private int currentCount = 0;

    [Parameter] public int InitialValue { get; set; } = 0;

    protected override void OnInitialized()
    {
        currentCount = InitialValue;
    }

    private void Increment() => currentCount++;
}
```

### Parameters

```csharp
[Parameter] public string Title { get; set; } = string.Empty;
[Parameter] public RenderFragment? ChildContent { get; set; }     // slot pattern
[Parameter] public EventCallback<int> OnChange { get; set; }      // typed events
[Parameter(CaptureUnmatchedValues = true)]
public Dictionary<string, object>? AdditionalAttributes { get; set; }  // attribute splatting
```

### Event Handling

```razor
<button @onclick="() => count++">Inc</button>
<button @onclick="HandleClick">Click</button>
<button @onclick="LoadDataAsync">Load</button>
<button @onclick:stopPropagation @onclick="Handle">Safe</button>
<form @onsubmit:preventDefault @onsubmit="Submit">...</form>
```

### Component Lifecycle

| Method | When Called | Notes |
|---|---|---|
| `SetParametersAsync` | Before each render, parameters set | Override to short-circuit |
| `OnInitialized(Async)` | Once on first render | Avoid side effects during prerender |
| `OnParametersSet(Async)` | After each parameter update | React to parent changes |
| `ShouldRender` | Before each render | Return `false` to skip re-render |
| `OnAfterRender(Async)` | After DOM update | `firstRender` flag; safe for JS interop |
| `Dispose(Async)` | Component removed | Unsubscribe events, cancel tokens |

```csharp
protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender)
    {
        await JS.InvokeVoidAsync("initChart", chartRef);
    }
}
```

### Cascading Parameters

```razor
@* Provider *@
<CascadingValue Value="currentTheme" Name="Theme">
    <Router ... />
</CascadingValue>

@* Consumer *@
@code {
    [CascadingParameter(Name = "Theme")] public string Theme { get; set; } = "light";
}
```

---

## Dependency Injection

### Registration Lifetimes

```csharp
builder.Services.AddScoped<IUserService, UserService>();       // per-circuit (Server) / per-session (WASM)
builder.Services.AddSingleton<IConfigService, ConfigService>(); // app lifetime
builder.Services.AddTransient<IEmailSender, SmtpEmailSender>(); // new instance every time
```

Lifetime behavior differs by render mode:

- **Interactive Server**: Scoped = per SignalR circuit. One instance shared across all components in a user's circuit.
- **Interactive WebAssembly**: Scoped = effectively singleton within the browser session.
- **Static SSR**: Scoped = per HTTP request (standard ASP.NET Core behavior).

### Injection Approaches

```razor
@* Directive injection *@
@inject IUserService UserService
@inject NavigationManager Nav
@inject IJSRuntime JS
```

```csharp
// Property injection
[Inject] private IUserService UserService { get; set; } = default!;

// Constructor injection (.NET 9+)
public MyComponentBase(IUserService userService, ILogger<Weather> logger)
{
    _userService = userService;
    _logger = logger;
}
```

### Scoped Service Pitfalls

- Never inject a Scoped service into a Singleton.
- `HttpContext` is not reliably available in interactive components. Use `AuthenticationStateProvider` and `NavigationManager` instead.
- Use `IHttpContextAccessor` only during prerender (Static SSR phase).

---

## SignalR for Interactive Server

### Architecture

```
Browser                          Server
  |                                |
  |-- WebSocket (SignalR) -------->|  Circuit established
  |                                |  Component tree lives here
  |<-- Binary DOM diff (MessagePack)|
  |-- UI Event (click, input) ---->|
  |<-- Updated DOM patches --------|
```

### Circuit Management

Each connected user has one circuit -- an in-memory object graph holding all component state. Circuits are cleaned up after a configurable disconnect timeout (default: 3 minutes).

Memory pressure: 1000 concurrent users = 1000 circuits. Plan memory accordingly.

```csharp
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents(options =>
    {
        options.DisconnectedCircuitMaxRetained = 100;
        options.DisconnectedCircuitRetentionPeriod = TimeSpan.FromMinutes(3);
        options.JSInteropDefaultCallTimeout = TimeSpan.FromSeconds(60);
    });
```

### Reconnection

Blazor auto-reconnects on transient disconnects. Customize behavior:

```javascript
Blazor.start({
    circuit: {
        reconnectionOptions: {
            maxRetries: 5,
            retryIntervalMilliseconds: (previousAttempts, maxRetries) =>
                previousAttempts >= maxRetries ? null : previousAttempts * 2000
        }
    }
});
```

### Scalability

Sticky sessions required: a user's requests must route to the same server.

- Azure: ARR affinity cookie (default on App Service).
- NGINX: `ip_hash` or cookie-based upstream.
- Multi-server: use Azure SignalR Service or Redis backplane.

```csharp
builder.Services.AddSignalR().AddAzureSignalR(connectionString);
```

---

## WebAssembly Runtime

### How .NET Runs in the Browser

- `dotnet.wasm` -- the .NET runtime compiled to WebAssembly.
- App assemblies (`.dll`) downloaded separately and interpreted.
- IL Interpretation (default): smaller download, slower execution.
- AOT Compilation: entire app compiled to WASM ahead of time -- larger download, near-native speed.

### Download Sizes

| Scenario | Approximate Size (compressed) |
|---|---|
| Baseline WASM runtime | ~2 MB |
| Typical small app | ~4-6 MB |
| With IL Trimming | ~2-3 MB |
| With AOT | ~8-15 MB (but faster) |

### Lazy Loading Assemblies

```xml
<BlazorWebAssemblyLazyLoad Include="HeavyFeature.dll" />
```

```csharp
@inject LazyAssemblyLoader AssemblyLoader
var assemblies = await AssemblyLoader.LoadAssembliesAsync(new[] { "HeavyFeature.dll" });
```

### PWA Support

```xml
<ServiceWorkerAssetsManifest>service-worker-assets.js</ServiceWorkerAssetsManifest>
```

---

## Blazor Hybrid

Blazor Hybrid embeds Blazor components inside a native app via `BlazorWebView`. No server, no WASM download -- .NET runs natively on the device.

| Host | Platform |
|---|---|
| .NET MAUI | iOS, Android, macOS, Windows |
| WPF | Windows |
| Windows Forms | Windows |

Key differences: `BlazorWebView` renders into the platform's native WebView. Direct access to native device APIs via .NET MAUI. No network required for UI. Share component libraries between Hybrid and Web targets.

```csharp
// MauiProgram.cs
builder.Services.AddMauiBlazorWebView();
```

---

## Enhanced Navigation

Enhanced Navigation (.NET 8+) intercepts link clicks and form submissions, fetches only the changed content, and patches the DOM -- SPA-like speed without a full page reload. Works for Static SSR pages without SignalR or WASM.

### Enhanced Form Handling

```razor
<form method="post" @formname="contact" @onsubmit="Submit" data-enhance>
    <input name="email" type="email" />
    <button type="submit">Send</button>
</form>

@code {
    [SupplyParameterFromForm] public string? Email { get; set; }

    private async Task Submit()
    {
        await EmailService.SendAsync(Email!);
    }
}
```

### Disabling Enhanced Navigation

```html
<a href="/legacy-page" data-enhance-nav="false">Legacy</a>
```

---

## Sections (.NET 8+)

Pages project content into named slots defined in layouts:

```razor
<!-- MainLayout.razor -->
<header><SectionOutlet SectionName="page-title" /></header>
<aside><SectionOutlet SectionName="sidebar" /></aside>
<main>@Body</main>

<!-- Dashboard.razor -->
<SectionContent SectionName="page-title">Dashboard</SectionContent>
<SectionContent SectionName="sidebar"><DashboardNav /></SectionContent>
```
