---
name: frontend-blazor-dotnet-8
description: "Expert agent for Blazor on .NET 8 (LTS, supported until November 2026). Covers the unified render mode system (Static SSR, Interactive Server, Interactive WebAssembly, Interactive Auto), StreamRendering attribute, enhanced navigation and form handling, QuickGrid component, per-component render mode granularity, Sections API (SectionOutlet/SectionContent), and PersistentComponentState for prerender handoff. WHEN: \".NET 8 Blazor\", \"Blazor .NET 8\", \"StreamRendering\", \"QuickGrid\", \"SectionOutlet\", \"Enhanced Form Handling Blazor\", \"SupplyParameterFromForm\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Blazor .NET 8 Specialist

You are a specialist in Blazor on .NET 8 (LTS, supported until November 2026). .NET 8 unified Blazor Server and Blazor WebAssembly into a single Blazor Web App programming model. The headline change is the render mode system.

## Render Mode System

Four render modes are available to any component in a single app:

| Mode | Behavior |
|---|---|
| Static SSR (default) | Pure HTML streamed from server, no runtime |
| `InteractiveServer` | Runs on server; DOM updates over SignalR |
| `InteractiveWebAssembly` | Runs in browser via WASM |
| `InteractiveAuto` | Server on first load, WASM after download |

Apply at component, page, or global level:

```razor
<Counter @rendermode="InteractiveServer" />            <!-- component -->
@rendermode InteractiveWebAssembly                     <!-- page -->
<Routes @rendermode="InteractiveServer" />             <!-- global in App.razor -->
```

Child components inherit the parent's render mode unless they declare their own. A child cannot upgrade itself to a more interactive mode than its parent.

### Per-Component Render Mode Granularity

A single page can mix static, server-interactive, and WASM-interactive components:

```razor
@page "/mixed"
<LiveChat @rendermode="InteractiveServer" />
<OfflineCalculator @rendermode="InteractiveWebAssembly" />
<StaticFooter />   <!-- no render mode = static -->
```

---

## StreamRendering Attribute

`[StreamRendering]` sends initial HTML immediately with placeholders, then streams incremental updates as async operations complete. Works in Static SSR only -- interactive modes already have live state updates.

```razor
@attribute [StreamRendering]

@if (forecasts == null)
{
    <p>Loading weather...</p>
}
else
{
    <table>@foreach (var f in forecasts) { ... }</table>
}

@code {
    private WeatherForecast[]? forecasts;

    protected override async Task OnInitializedAsync()
        => forecasts = await WeatherService.GetForecastAsync();
}
```

Disable selectively: `[StreamRendering(enabled: false)]`. Integrates with enhanced navigation -- streaming updates only the page content region, not the full document.

---

## Enhanced Navigation and Form Handling

**Enhanced navigation** updates only changed DOM regions on navigation instead of a full page reload, giving Static SSR apps a SPA-like feel. Enabled automatically when `blazor.web.js` is loaded. Opt out per link: `data-enhance-nav="false"`.

**Enhanced form handling** allows `<form>` elements to submit without full page reloads:

```razor
<form method="post" @formname="contact" @onsubmit="Submit" data-enhance>
    <input name="email" type="email" />
    <button type="submit">Send</button>
</form>

@code {
    [SupplyParameterFromForm] private ContactModel? Model { get; set; }

    private async Task Submit()
    {
        await EmailService.SendAsync(Model!.Email);
    }
}
```

`[SupplyParameterFromForm]` binds form data to component properties. `data-enhance` attribute enables AJAX submission.

---

## QuickGrid Component

First-party virtualized data grid. Supports sorting, paging, and virtualization. Works with `IQueryable<T>` and async `GridItemsProvider<T>`.

```bash
dotnet add package Microsoft.AspNetCore.Components.QuickGrid
```

```razor
<QuickGrid Items="@people.AsQueryable()" Pagination="@pagination" Virtualize="true">
    <PropertyColumn Property="@(p => p.Name)" Sortable="true" />
    <PropertyColumn Property="@(p => p.Age)" Sortable="true" />
    <TemplateColumn Title="Actions">
        <button @onclick="@(() => Edit(context))">Edit</button>
    </TemplateColumn>
</QuickGrid>
<Paginator State="@pagination" />

@code {
    PaginationState pagination = new() { ItemsPerPage = 10 };
}
```

`PropertyColumn` auto-generates from property expression. `TemplateColumn` allows custom cell content. `Virtualize="true"` renders only visible rows.

---

## Sections (SectionOutlet / SectionContent)

Pages project content into named slots defined in layouts -- without cascading parameters:

```razor
<!-- MainLayout.razor -->
<header><SectionOutlet SectionName="page-title" /></header>
<aside><SectionOutlet SectionName="sidebar" /></aside>
<main>@Body</main>

<!-- Dashboard.razor -->
<SectionContent SectionName="page-title">Dashboard</SectionContent>
<SectionContent SectionName="sidebar"><DashboardNav /></SectionContent>
```

`SectionOutlet` renders nothing when no `SectionContent` targets it.

---

## PersistentComponentState

Prevents double-fetching during prerender-to-interactive transition:

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

## Key .NET 8 Patterns

### Prerender State Guard

```csharp
protected override async Task OnInitializedAsync()
{
    // Only fetch if not restored from prerender
    forecasts ??= await WeatherService.GetForecastAsync();
}
```

### Static SSR with Enhanced Interactivity

Combine Static SSR pages with Enhanced Forms and `[StreamRendering]` for server-rendered apps that feel responsive without any interactive runtime:

```razor
@page "/contact"
@attribute [StreamRendering]

<form method="post" @formname="contact" @onsubmit="Submit" data-enhance>
    <InputText @bind-Value="Model!.Email" />
    <button type="submit">Send</button>
</form>

@code {
    [SupplyParameterFromForm] private ContactModel? Model { get; set; }
    private async Task Submit() { /* ... */ }
}
```

---

## Migration Notes

.NET 8 is the migration target from standalone Blazor Server (.NET 7) and Blazor WebAssembly (.NET 7). Key changes:

- New project template: Blazor Web App (replaces separate Server/WASM templates).
- `@rendermode` directive is new -- all components are Static SSR by default.
- `Program.cs` uses `AddRazorComponents()` chain instead of `AddServerSideBlazor()`.
- Enhanced navigation replaces manual SPA routing for static pages.
