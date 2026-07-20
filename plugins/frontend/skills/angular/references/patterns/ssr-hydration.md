# Angular SSR and Hydration Pattern Guide

Route-level render modes, incremental hydration, and event replay for Angular SSR applications.

---

## Route-Level Render Modes

Each route independently chooses its rendering strategy. Eliminates the all-or-nothing tradeoff between SSR and SSG.

**Status:** Developer preview in v19, stable in v20+.

### Configuration

```typescript
// app.routes.server.ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  {
    path: '',
    renderMode: RenderMode.Prerender,  // SSG -- built at deploy time
  },
  {
    path: 'blog/:slug',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      const slugs = await fetchAllSlugs();
      return slugs.map(slug => ({ slug }));
    },
  },
  {
    path: 'dashboard',
    renderMode: RenderMode.Client,  // CSR -- no server render
  },
  {
    path: '**',
    renderMode: RenderMode.Server,  // SSR -- per-request
  },
];
```

### Wiring Up

```typescript
// app.config.server.ts
import { mergeApplicationConfig } from '@angular/core';
import { provideServerRouting } from '@angular/ssr';
import { appConfig } from './app.config';
import { serverRoutes } from './app.routes.server';

export const config = mergeApplicationConfig(appConfig, {
  providers: [
    provideServerRouting(serverRoutes),
  ],
});
```

### Render Mode Summary

| Mode | When HTML Is Produced | Best For |
|---|---|---|
| `RenderMode.Prerender` | Build time | Static content, blogs, marketing pages |
| `RenderMode.Server` | Request time | Auth-gated, personalized, dynamic content |
| `RenderMode.Client` | Browser only | Dashboards, real-time features, post-login UIs |

### Choosing a Render Mode

- **Prerender** when content rarely changes and is not user-specific
- **Server** when content is personalized or requires authentication
- **Client** when the page is entirely interactive with no SEO need

---

## Incremental Hydration

Defers hydration of SSR-rendered content until a trigger fires. The server renders full HTML; the client selectively hydrates subtrees on demand.

**Status:** Developer preview in v19, stable in v20+.

### Setup

```typescript
// app.config.ts
import { provideClientHydration, withIncrementalHydration } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(withIncrementalHydration()),
  ],
};
```

### Usage with @defer

```html
<!-- Hydrate when the block scrolls into view -->
@defer (hydrate on viewport) {
  <app-product-reviews [productId]="id" />
}

<!-- Hydrate on user interaction (click or keydown) -->
@defer (hydrate on interaction) {
  <app-comments-section />
}

<!-- Hydrate on next idle tick -->
@defer (hydrate on idle) {
  <app-recommendations />
}

<!-- Hydrate on mouse hover -->
@defer (hydrate on hover) {
  <app-tooltip-panel />
}

<!-- Hydrate after a timer -->
@defer (hydrate on timer(3000)) {
  <app-cookie-banner />
}

<!-- Hydrate when a signal/expression is truthy -->
@defer (hydrate when isLoggedIn()) {
  <app-user-dashboard />
}

<!-- Never hydrate -- stays as static HTML -->
@defer (hydrate never) {
  <app-static-footer />
}
```

### How It Works

1. During SSR, deferred blocks are rendered as full HTML with an inert marker attribute
2. The Angular runtime skips those blocks during initial hydration
3. When the trigger fires, the runtime fetches the component's JS chunk and hydrates only that subtree
4. Until hydration, the block is fully readable and indexable as static HTML

### Performance Impact

Incremental hydration improves LCP by 40-50% in benchmarks by reducing the JavaScript that must execute before the page becomes interactive.

### Available Hydration Triggers

| Trigger | Fires When |
|---|---|
| `on idle` | Browser is idle (`requestIdleCallback`) |
| `on viewport` | Element scrolls into view |
| `on interaction` | Click or keydown on the element |
| `on hover` | Mouse enters the element |
| `on timer(ms)` | After specified milliseconds |
| `when expr` | Signal/expression becomes truthy |
| `never` | Never hydrates (pure static content) |

---

## Event Replay

Captures user interactions that happen during the hydration window and replays them once hydration completes. Eliminates the "dead zone" problem where early clicks are silently dropped.

**Status:** Opt-in in v18, default in v19+.

### Setup

Event replay is included automatically with `provideClientHydration()` in v19+. No additional configuration required.

```typescript
// Event replay is implicit -- no extra call needed
provideClientHydration()
```

### How It Works

1. A small inline script in the SSR output captures DOM events during the hydration window
2. Events are queued in order (clicks, keypresses, form inputs)
3. After client bootstrap completes, the queue replays in order
4. Works across all standard DOM events

### When to Disable

Event replay is rarely problematic, but can be disabled if it causes issues with specific event handlers:

```typescript
provideClientHydration(withNoEventReplay())
```

---

## Complete SSR Configuration Example

```typescript
// app.config.ts
import { ApplicationConfig } from '@angular/core';
import { provideRouter, withViewTransitions } from '@angular/router';
import { provideClientHydration, withIncrementalHydration } from '@angular/platform-browser';
import { provideHttpClient, withFetch } from '@angular/common/http';
import { provideZonelessChangeDetection } from '@angular/core';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
    provideRouter(routes, withViewTransitions()),
    provideClientHydration(withIncrementalHydration()),
    provideHttpClient(withFetch()),
  ],
};
```

```typescript
// app.config.server.ts
import { mergeApplicationConfig } from '@angular/core';
import { provideServerRouting } from '@angular/ssr';
import { appConfig } from './app.config';
import { serverRoutes } from './app.routes.server';

export const config = mergeApplicationConfig(appConfig, {
  providers: [
    provideServerRouting(serverRoutes),
  ],
});
```

---

## Common SSR Issues

| Issue | Solution |
|---|---|
| Hydration mismatch (server/client differ) | Use `afterNextRender()` for client-only content; check timezone-dependent formatting |
| `@defer` content not server-rendered | Ensure `withIncrementalHydration()` is configured |
| Event handlers not working after SSR | Verify event replay is enabled (default in v19+) |
| Window/document not available in SSR | Guard with `afterNextRender()` or `isPlatformBrowser()` |
| SSR build fails with third-party library | Use dynamic imports or conditional loading with `isPlatformBrowser()` |
