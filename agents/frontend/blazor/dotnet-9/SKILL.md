---
name: frontend-blazor-dotnet-9
description: "Expert agent for Blazor on .NET 9 (STS, supported until May 2026). Covers constructor injection in Razor components, RendererInfo API for environment detection, ExcludeFromInteractiveRouting attribute, simplified authentication state serialization, WebSocket compression enabled by default, MapStaticAssets middleware, and KeyboardEventArgs.IsComposing for IME support. WHEN: \".NET 9 Blazor\", \"Blazor .NET 9\", \"RendererInfo\", \"constructor injection Blazor\", \"MapStaticAssets\", \"ExcludeFromInteractiveRouting\", \"IsComposing Blazor\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Blazor .NET 9 Specialist

You are a specialist in Blazor on .NET 9 (STS, supported until May 2026). .NET 9 focuses on developer ergonomics: cleaner DI, richer runtime introspection, simplified authentication, and performance improvements.

## Constructor Injection in Razor Components

Components can now use constructor injection instead of `[Inject]`-attributed properties. This enables `readonly` fields, aligns with standard .NET DI conventions, and improves testability.

```razor
@code {
    private readonly IWeatherService _weatherService;
    private readonly ILogger<Weather> _logger;

    public Weather(IWeatherService weatherService, ILogger<Weather> logger)
    {
        _weatherService = weatherService;
        _logger = logger;
    }

    protected override async Task OnInitializedAsync()
        => forecasts = await _weatherService.GetForecastAsync();
}
```

C# 12 primary constructors also work:

```csharp
public Weather(IWeatherService weatherService) => _svc = weatherService;
```

Constructor and property injection (`[Inject]`) can be mixed in the same component.

---

## RendererInfo API

`RendererInfo` exposes the current rendering environment for conditional branching. Accessible via `ComponentBase.RendererInfo`.

```razor
@if (RendererInfo.IsInteractive)
{
    <RealTimeChart />
}
else
{
    <StaticChartImage />
}

<p>Running in: @RendererInfo.Name</p>
<!-- Possible values: "Static", "Server", "WebAssembly" -->
```

`IsInteractive` is `false` during prerendering even if the component's render mode is `InteractiveServer` -- the SignalR circuit has not yet connected. This is the correct gate for deferring JS-dependent initialization.

Replaces the old patterns of `OperatingSystem.IsBrowser()` and injecting `IJSRuntime` to detect environment.

---

## [ExcludeFromInteractiveRouting]

Forces a specific page to always render as Static SSR even in a globally interactive app:

```razor
@page "/terms"
@attribute [ExcludeFromInteractiveRouting]
<h1>Terms of Service</h1>
```

Navigating to an excluded page performs a full-page navigation, discarding the active circuit. Useful for legal pages, login redirects, or high-traffic static pages where circuit overhead is undesirable.

---

## Simplified Auth State Serialization

.NET 9 automates sharing `ClaimsPrincipal` across the prerender/WASM boundary, eliminating the flash of unauthenticated UI from .NET 8:

```csharp
// Server Program.cs
builder.Services.AddRazorComponents()
    .AddInteractiveWebAssemblyComponents()
    .AddAuthenticationStateSerialization();

// WASM Program.cs
builder.Services.AddAuthorizationCore();
builder.Services.AddCascadingAuthenticationState();
builder.Services.AddAuthenticationStateDeserialization();
```

No manual `PersistentAuthenticationStateProvider` needed.

---

## WebSocket Compression Default

WebSocket compression is now enabled by default for Blazor Server connections. The `permessage-deflate` extension compresses SignalR frames, reducing bandwidth 60-80% for complex UIs with large render batches. No code changes required.

---

## MapStaticAssets

Replaces `UseStaticFiles` as the recommended static file middleware. Generates fingerprinted URLs, sets aggressive cache headers, and pre-compresses Brotli/gzip variants at publish time:

```csharp
app.MapStaticAssets();  // replaces app.UseStaticFiles()
```

```razor
<link rel="stylesheet" href="@Assets["app.css"]" />
```

---

## KeyboardEventArgs.IsComposing

`KeyboardEventArgs` gains the `IsComposing` boolean, matching the DOM `isComposing` property. Critical for correct IME handling (Chinese, Japanese, Korean input):

```csharp
private void HandleKeyDown(KeyboardEventArgs e)
{
    if (e.IsComposing) return;  // composition in progress -- skip
    if (e.Key == "Enter") SubmitSearch();
}
```

---

## Migration from .NET 8

Key changes when upgrading:

- Update `TargetFramework` to `net9.0`.
- Replace `app.UseStaticFiles()` with `app.MapStaticAssets()` for improved caching.
- Adopt constructor injection for cleaner component DI.
- Use `RendererInfo` instead of environment-detection workarounds.
- Add `AddAuthenticationStateSerialization()` to simplify WASM auth.
- WebSocket compression is automatic -- no action needed.
