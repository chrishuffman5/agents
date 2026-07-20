# Blazor Best Practices Reference

Guidelines for render mode selection, state management, JS interop, performance, and authentication in Blazor Web Apps.

---

## Render Mode Selection

### Decision Tree

```
START
  |
  v
Does the page need SEO or serve as a landing/marketing page?
  | YES --> Static SSR (with Enhanced Forms for interactivity)
  |
  NO
  v
Does the component need real-time server push (SignalR, live data)?
  | YES --> Interactive Server
  |
  NO
  v
Must the app work offline or be deployed to CDN (no persistent server)?
  | YES --> Interactive WebAssembly
  |
  NO
  v
Is initial load speed critical AND offline is a nice-to-have?
  | YES --> Interactive Auto
  |
  NO
  v
Is latency acceptable?
  | HIGH LATENCY --> Interactive WebAssembly (or Auto)
  |
  LOW LATENCY / INTRANET --> Interactive Server
```

### Tradeoff Matrix

| Concern | Static SSR | Interactive Server | Interactive WASM | Interactive Auto |
|---|---|---|---|---|
| Initial load | Fastest | Fast (prerender) | Slow (download) | Fast then fast |
| SEO | Best | Good (prerender) | Poor | Good |
| Offline | None | None | Yes | Yes (after load) |
| Server memory | Minimal | High (circuit) | None | Low |
| Network sensitivity | Stateless | Sensitive | None (after load) | Balanced |

### Per-Component Granularity

Mix render modes on a single page. Keep the page Static SSR and only promote individual components to interactive as needed:

```razor
@page "/mixed"
<LiveChat @rendermode="InteractiveServer" />
<OfflineCalculator @rendermode="InteractiveWebAssembly" />
<StaticFooter />   <!-- no render mode = static -->
```

---

## State Management

### Scoped Services (Primary Pattern)

Scoped services act as state containers shared across components in the same circuit:

```csharp
public class AppState
{
    public string UserName { get; private set; } = string.Empty;
    public event Action? OnChange;

    public void SetUser(string name)
    {
        UserName = name;
        OnChange?.Invoke();
    }
}

builder.Services.AddScoped<AppState>();
```

```razor
@inject AppState State
@implements IDisposable

@State.UserName

@code {
    protected override void OnInitialized() => State.OnChange += StateHasChanged;
    public void Dispose() => State.OnChange -= StateHasChanged;
}
```

### PersistentComponentState (Prerender Handoff)

Prevents double-fetching during prerender-to-interactive transition:

```csharp
@inject PersistentComponentState AppState

protected override async Task OnInitializedAsync()
{
    _subscription = AppState.RegisterOnPersisting(Persist);
    if (!AppState.TryTakeFromJson<WeatherData[]>("weather", out forecasts))
        forecasts = await WeatherService.GetForecastAsync();
}

private Task Persist()
{
    AppState.PersistAsJson("weather", forecasts);
    return Task.CompletedTask;
}
```

### [PersistentState] (.NET 10)

Declarative replacement for PersistentComponentState boilerplate:

```csharp
[PersistentState] private WeatherData[]? forecasts;

protected override async Task OnInitializedAsync()
    => forecasts ??= await WeatherService.GetForecastAsync();
```

### Cascading Values

Use for low-frequency, app-wide data (theme, locale, auth). Avoid for frequently-changing state.

### Browser Storage

Use Blazored.LocalStorage or manual JS interop for client-side persistence:

```csharp
await JS.InvokeVoidAsync("localStorage.setItem", "key", value);
var stored = await JS.InvokeAsync<string>("localStorage.getItem", "key");
```

---

## JS Interop

### Prefer Module Isolation

Avoid global namespace pollution. Load JS as ES modules:

```csharp
private IJSObjectReference? _module;

protected override async Task OnAfterRenderAsync(bool firstRender)
{
    if (firstRender)
        _module = await JS.InvokeAsync<IJSObjectReference>(
            "import", "./js/myComponent.js");
}

await _module!.InvokeVoidAsync("init", elementRef);

public async ValueTask DisposeAsync()
{
    if (_module is not null)
        await _module.DisposeAsync();
}
```

### Always Dispose References

Both `IJSObjectReference` (module handles) and `DotNetObjectReference` (.NET callbacks) are GC roots. Dispose in `DisposeAsync`.

### Call JS Only After Render

JS interop is only safe in `OnAfterRenderAsync`. The DOM does not exist during `OnInitialized`.

### Synchronous Interop (WASM Only)

```csharp
if (JS is IJSInProcessRuntime inProcess)
{
    var value = inProcess.Invoke<string>("getTitle");
}
```

---

## Performance

### AOT vs IL Interpretation

| | IL Interpretation | AOT |
|---|---|---|
| Download | Smaller (~4-6 MB) | Larger (~8-15 MB) |
| Startup | Faster download | Slower download |
| Runtime | Slower execution | 2-5x faster |
| Build time | Fast | Much slower |
| Use case | Most apps | Compute-heavy apps |

### IL Trimming

Enabled by default for WASM Release builds. Reduces download 30-50%. Test thoroughly -- reflection-heavy code may break. Use `[DynamicDependency]` annotations.

### Virtualization

Render only visible items in large lists:

```razor
<Virtualize Items="@allItems" Context="item">
    <ItemContent>
        <div>@item.Name</div>
    </ItemContent>
    <Placeholder>
        <div class="skeleton"></div>
    </Placeholder>
</Virtualize>
```

For server-side data, use `ItemsProvider` with paging.

### Minimize Re-Renders

```csharp
protected override bool ShouldRender() => _isDirty;
```

Prefer `EventCallback` over `Action` -- `EventCallback` auto-calls `StateHasChanged` only on the owning component.

### Lazy Loading Assemblies

Defer heavy assemblies (PDF generators, chart libraries) until first use:

```xml
<BlazorWebAssemblyLazyLoad Include="HeavyChartLib.dll" />
```

### Compression

Brotli compression enabled by default for WASM publish. Ensure server serves `.br` files.

---

## Authentication

### Setup

```csharp
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddAuthentication(...)
    .AddCookie()
    .AddOpenIdConnect("oidc", options => { ... });
```

### AuthorizeView

```razor
<AuthorizeView>
    <Authorized>Hello, @context.User.Identity?.Name</Authorized>
    <NotAuthorized><a href="/login">Sign in</a></NotAuthorized>
</AuthorizeView>

<AuthorizeView Roles="Admin,Manager">
    <AdminPanel />
</AuthorizeView>
```

### [Authorize] on Pages

```razor
@page "/admin"
@attribute [Authorize(Roles = "Admin")]
```

### Per-Render-Mode Considerations

- **Static SSR**: Standard ASP.NET Core auth. `HttpContext` available. Cookies and redirects work.
- **Interactive Server**: `HttpContext` not available. Use `AuthenticationStateProvider`.
- **Interactive WASM**: Auth state serialized from server. Use `PersistentAuthenticationStateProvider` (.NET 8) or simplified serialization (.NET 9+).

```csharp
// .NET 9+ simplified auth serialization
// Server
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyComponents()
    .AddAuthenticationStateSerialization();

// WASM client
builder.Services.AddAuthorizationCore();
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddAuthenticationStateDeserialization();
```
