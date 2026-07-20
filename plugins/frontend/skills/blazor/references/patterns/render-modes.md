# Blazor Render Mode Patterns

Decision tree and configuration patterns for selecting the right render mode.

---

## Decision Tree

```
START
  |
  v
Does the page need SEO or serve as a landing/marketing page?
  | YES --> Static SSR (optionally with Enhanced Forms for interactivity)
  |
  NO
  v
Does the component need real-time server push (SignalR events, live data)?
  | YES --> Interactive Server
  |
  NO
  v
Must the app work offline or be deployed to a CDN (no persistent server)?
  | YES --> Interactive WebAssembly
  |           WARNING: initial download ~4-6 MB; consider lazy loading
  |
  NO
  v
Is initial load speed critical AND offline is a nice-to-have?
  | YES --> Interactive Auto
  |           (Server on first visit, WASM on repeat visits)
  |
  NO
  v
Is latency acceptable? (user on high-latency or unreliable network?)
  | HIGH LATENCY --> Interactive WebAssembly (or Auto)
  |
  LOW LATENCY / INTRANET
  v
Interactive Server
  (simpler deployment, no API layer needed, full server resource access)
```

---

## Tradeoff Matrix

| Concern | Static SSR | Interactive Server | Interactive WASM | Interactive Auto |
|---|---|---|---|---|
| Initial load speed | Fastest | Fast (with prerender) | Slow (download) | Fast then fast |
| SEO | Best | Good (prerender) | Poor | Good |
| Offline support | None | None | Yes | Yes (after first load) |
| Server memory per user | Minimal | High (circuit) | None | Low (circuit drops) |
| Network sensitivity | Stateless | Sensitive | None (after load) | Balanced |
| Deployment complexity | Low | Medium | Medium | High |

---

## Configuration Patterns

### Page-Level Render Mode

```razor
@page "/dashboard"
@rendermode InteractiveServer
```

### Component-Level at Usage Site

```razor
@* Applied where the component is used, not in the component itself *@
<MyChart @rendermode="InteractiveWebAssembly" />
```

### Global Render Mode (All Pages)

```razor
@* In App.razor -- makes the entire app Interactive Server *@
<Routes @rendermode="InteractiveServer" />
```

### Disable Prerendering

```razor
<MyChart @rendermode="new InteractiveServerRenderMode(prerender: false)" />
<MyWidget @rendermode="new InteractiveWebAssemblyRenderMode(prerender: false)" />
```

Disable prerendering when:
- Component initialization causes side effects (duplicate DB writes, API calls).
- JS interop needed immediately (not safe during prerender).
- Auth-dependent UI flashes incorrect state during prerender.

### Mixed Modes on One Page

```razor
@page "/mixed"

@* Static content -- no render mode, zero overhead *@
<StaticHero />
<StaticFooter />

@* Interactive islands *@
<LiveChat @rendermode="InteractiveServer" />
<OfflineCalculator @rendermode="InteractiveWebAssembly" />
```

### Force Static for Specific Pages (.NET 9+)

```razor
@page "/terms"
@attribute [ExcludeFromInteractiveRouting]

@* Always Static SSR even in a globally interactive app *@
<h1>Terms of Service</h1>
```

---

## Inheritance Rules

- Child components inherit parent's render mode unless overridden at usage site.
- A child cannot upgrade itself to more interactive than its parent.
- `@rendermode` in the component's own file only works for routable pages (`@page`).
- Non-routable components receive their render mode from the parent's usage site.

---

## When to Use Each Mode

**Static SSR**: Marketing pages, landing pages, documentation, SEO content, blog posts. Add Enhanced Forms for light interactivity (contact forms, search).

**Interactive Server**: Internal dashboards, admin panels, real-time collaboration, intranet apps with low latency. Best when server resource access is frequent.

**Interactive WebAssembly**: Offline-capable tools, CDN-deployed SPAs, computation-heavy client apps (CAD, editors), apps targeting unreliable networks.

**Interactive Auto**: Public-facing apps needing fast first load and eventual offline support. E-commerce product pages, SaaS dashboards.
