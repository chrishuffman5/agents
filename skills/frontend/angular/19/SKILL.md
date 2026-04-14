---
name: frontend-angular-19
description: "Expert agent for Angular 19 (LTS, EOL May 2026). Covers linkedSignal (experimental), resource()/rxResource() (experimental), incremental hydration (developer preview), route-level render modes (developer preview), event replay (stable, default), CSS/template HMR, standalone implicit default, and migration from v18. WHEN: \"Angular 19\", \"angular 19\", \"angular v19\", \"linkedSignal\", \"resource angular\", \"rxResource\", \"incremental hydration preview\", \"route render mode preview\", \"event replay angular\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Angular 19 Specialist

You are a specialist in Angular 19 (LTS, released November 2024, EOL May 2026). Angular 19 matures the signals ecosystem, introduces experimental async data primitives, and previews the full-stack rendering story that stabilizes in v20.

## linkedSignal (Experimental)

A writable signal that automatically resets to a computed value whenever its source signal changes. Unlike `computed()`, the result is writable -- you can override it, but it snaps back when the source updates.

```typescript
import { linkedSignal, signal } from '@angular/core';

const source = signal('A');
const linked = linkedSignal(() => source() + '-default');

linked();           // 'A-default'
linked.set('custom');
linked();           // 'custom'
source.set('B');
linked();           // 'B-default'  <-- auto-reset
```

### Advanced Form with Options Object

```typescript
linkedSignal<string[]>({
  source: this.selectedCategory,
  computation: (cat, previous) => {
    if (previous && this.catalog[cat]?.includes(previous.value)) {
      return previous.value;  // preserve selection if still valid
    }
    return this.catalog[cat]?.[0] ?? '';
  },
});
```

### Use Cases

- Dropdown B resets when dropdown A changes
- Pagination resets to page 1 when filters change
- Form sections reinitialize on parent selection change

---

## resource() and rxResource() (Experimental)

Async data loading integrated into the signal graph. Dependencies tracked reactively; re-fetch fires automatically when any signal dependency changes.

### resource() -- Promise-Based

```typescript
import { resource, signal } from '@angular/core';

userId = signal(1);

userResource = resource({
  request: () => ({ id: this.userId() }),
  loader: ({ request, abortSignal }) =>
    fetch(`/api/users/${request.id}`, { signal: abortSignal })
      .then(r => r.json()),
});
```

### rxResource() -- Observable-Based

```typescript
import { rxResource } from '@angular/core/rxjs-interop';

productResource = rxResource({
  request: () => this.productId(),
  loader: ({ request }) =>
    this.http.get<Product>(`/api/products/${request}`),
});
```

### Status Lifecycle

| Status | Meaning |
|---|---|
| `idle` | No request made yet (request is null/undefined) |
| `loading` | Initial fetch in progress |
| `reloading` | Re-fetching after dependency change |
| `resolved` | Data available |
| `error` | Fetch failed |
| `local` | Value was set locally |

### Template Pattern

```html
@if (userResource.isLoading()) {
  <app-spinner />
} @else if (userResource.error()) {
  <p>Error: {{ userResource.error() }}</p>
} @else {
  <app-user-card [user]="userResource.value()!" />
}
```

### Key Behaviors

- `abortSignal` automatically cancels in-flight requests when the request signal changes (prevents race conditions)
- When request evaluates to `undefined` or `null`, the resource enters idle state and the loader does not run
- `resource.reload()` triggers a re-fetch with current parameters

---

## Incremental Hydration (Developer Preview)

Defers hydration of SSR-rendered content until a trigger fires. Uses the existing `@defer` block syntax.

### Enable

```typescript
import { provideClientHydration, withIncrementalHydration } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(withIncrementalHydration()),
  ],
};
```

### Syntax

```html
@defer (hydrate on viewport) {
  <app-product-reviews />
}

@defer (hydrate on idle) {
  <app-recommendations />
}

@defer (hydrate on interaction) {
  <app-comments />
}

@defer (hydrate on hover) {
  <app-tooltip-panel />
}

@defer (hydrate on timer(3000)) {
  <app-cookie-banner />
}

@defer (hydrate when isLoggedIn()) {
  <app-user-dashboard />
}

@defer (hydrate never) {
  <app-static-footer />
}
```

### Available Triggers

| Trigger | Fires When |
|---|---|
| `on idle` | Browser is idle (`requestIdleCallback`) |
| `on viewport` | Element scrolls into view |
| `on interaction` | Click or keydown on element |
| `on hover` | Mouse enters element |
| `on timer(ms)` | After specified milliseconds |
| `when expr` | Signal/expression becomes truthy |
| `never` | Never hydrates (pure static content) |

The server renders full HTML for all deferred content. The client skips downloading and executing component JavaScript until the trigger fires.

---

## Route-Level Render Mode (Developer Preview)

Each route independently chooses its rendering strategy: SSR, SSG (prerender), or CSR.

### Configuration

```typescript
// app.routes.server.ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  {
    path: '',
    renderMode: RenderMode.Prerender,
  },
  {
    path: 'products/:id',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      const ids = await fetchProductIds();
      return ids.map(id => ({ id: String(id) }));
    },
  },
  {
    path: 'dashboard',
    renderMode: RenderMode.Server,
  },
  {
    path: 'settings',
    renderMode: RenderMode.Client,
  },
  {
    path: '**',
    renderMode: RenderMode.Server,
  },
];
```

### Wiring

```typescript
// app.config.server.ts
import { mergeApplicationConfig } from '@angular/core';
import { provideServerRendering, withRoutes } from '@angular/ssr';
import { serverRoutes } from './app.routes.server';
import { appConfig } from './app.config';

const serverConfig: ApplicationConfig = {
  providers: [
    provideServerRendering(withRoutes(serverRoutes)),
  ],
};

export const config = mergeApplicationConfig(appConfig, serverConfig);
```

### Render Modes

| Value | Behavior |
|---|---|
| `RenderMode.Server` | Full SSR per request |
| `RenderMode.Prerender` | Static generation at build time |
| `RenderMode.Client` | No server render, CSR only |

---

## Event Replay (Stable, Default)

Captures user interactions during the hydration window and replays them once hydration completes. Enabled by default in v19 with `provideClientHydration()`.

```typescript
// No extra configuration needed -- included by default with SSR
provideClientHydration()
// withEventReplay() was opt-in in v18, now implicit in v19
```

Events are queued in a small inline script in the SSR output. After client bootstrap, the queue replays in order across all standard DOM events.

---

## CSS and Template HMR

Hot Module Replacement for styles and templates without full page reload, preserving component state (signal values, form state, router position).

Active by default in `ng serve` for v19 projects. No configuration needed.

```json
// angular.json -- to disable HMR if needed
"serve": {
  "options": { "hmr": false }
}
```

---

## Standalone Default

`standalone: true` is now implicit for newly generated components. The flag can be omitted in new code. Legacy `standalone: false` remains supported.

```typescript
// v19: standalone: true is inferred
@Component({
  selector: 'app-root',
  imports: [RouterOutlet, CommonModule],
  templateUrl: './app.component.html',
})
export class AppComponent {}
```

---

## Migration Notes (v18 to v19)

1. **Event replay**: `withEventReplay()` is now default in `provideClientHydration()`. Remove explicit calls (harmless but redundant).
2. **standalone default**: `ng generate` produces standalone components by default. Existing NgModule components are unaffected.
3. **@angular/ssr changes**: `ServerRoute` and `RenderMode` are new exports from `@angular/ssr`. Ensure `@angular/ssr` is updated to v19.
4. **rxResource import**: `rxResource` lives in `@angular/core/rxjs-interop`, not `@angular/core`.
5. **Zoneless**: `provideExperimentalZonelessChangeDetection()` continues from v18. Not default.
6. **Node.js**: Requires Node.js 18.19+ or 20.9+.
7. **TypeScript**: Requires TypeScript 5.5 or 5.6.

```bash
ng update @angular/core@19 @angular/cli@19
```

---

## Dependency Versions

| Package | Version |
|---|---|
| `@angular/core` | `^19.0.0` |
| `@angular/cli` | `^19.0.0` |
| `@angular/ssr` | `^19.0.0` |
| `typescript` | `~5.6.0` |
| `rxjs` | `~7.8.0` |
| `zone.js` | `~0.15.0` |
| Node.js | `18.19+` or `20.9+` |
