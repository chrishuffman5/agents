# Blazor State Management Patterns

Patterns for managing state across components and render modes in Blazor Web Apps.

---

## Scoped Services (Primary Pattern)

Register a class as a scoped service. In Interactive Server, scoped = per-circuit. In WASM, scoped = per-session (effectively singleton).

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

// Program.cs
builder.Services.AddScoped<AppState>();
```

```razor
@inject AppState State
@implements IDisposable

<p>@State.UserName</p>

@code {
    protected override void OnInitialized() => State.OnChange += StateHasChanged;
    public void Dispose() => State.OnChange -= StateHasChanged;
}
```

Always unsubscribe in `Dispose` to prevent memory leaks.

---

## PersistentComponentState (Prerender Handoff)

Prevents double-fetching during the prerender-to-interactive transition. Available in .NET 8+.

```csharp
@inject PersistentComponentState AppState

private WeatherData[]? forecasts;
private PersistingComponentStateSubscription _subscription;

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

public void Dispose() => _subscription.Dispose();
```

---

## [PersistentState] Attribute (.NET 10)

Declarative shorthand replacing the PersistentComponentState boilerplate:

```csharp
[PersistentState] private WeatherData[]? forecasts;

protected override async Task OnInitializedAsync()
    => forecasts ??= await WeatherService.GetForecastAsync();
```

Multiple `[PersistentState]` fields coexist in one component. Custom key: `[PersistentState(Key = "my-key")]`.

---

## Cascading Parameters

Cascade values from parent to all descendants without explicit parameter passing:

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

Best for: theme, locale, authentication state. Avoid for frequently-changing data (triggers re-render of all consumers).

---

## Browser Storage via JS Interop

For persistent client-side state across sessions:

```csharp
// Write
await JS.InvokeVoidAsync("localStorage.setItem", "key", value);

// Read
var stored = await JS.InvokeAsync<string>("localStorage.getItem", "key");
```

Or use Blazored.LocalStorage for a typed, injectable abstraction.

---

## State Guidance by Render Mode

| Render Mode | Scoped Service Scope | Persistence Strategy |
|---|---|---|
| Static SSR | Per HTTP request | Enhanced Forms, URL state |
| Interactive Server | Per circuit | Scoped services, PersistentComponentState |
| Interactive WASM | Per session (singleton) | Scoped services, localStorage |
| Interactive Auto | Per circuit then per session | PersistentComponentState for handoff |
