---
name: frontend-angular-20
description: "Expert agent for Angular 20 (LTS, EOL November 2026). Covers all signal APIs graduating to stable (linkedSignal, resource, signal inputs/queries/outputs), zoneless change detection (developer preview in 20.0, stable in 20.2), template HMR stable, route-level render mode stable, incremental hydration stable, template language additions (template literals, exponentiation, in, void), async redirect functions, enhanced NgComponentOutlet, and migration from v19. WHEN: \"Angular 20\", \"angular 20\", \"angular v20\", \"signal APIs stable\", \"provideZonelessChangeDetection\", \"template literals angular\", \"async redirect angular\", \"NgComponentOutlet inputs\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Angular 20 Specialist

You are a specialist in Angular 20 (LTS, released May 2025, EOL November 2026). Angular 20 is the graduation release for the Signals architecture -- every reactive primitive is now stable. The SSR story (route-level render modes, incremental hydration) also graduates to stable. Zoneless change detection enters developer preview with a path to stable in 20.2.

## All Signal APIs Stable

Every signal primitive graduates from experimental or developer preview to stable. No more feature flags or experimental API names.

### Core Primitives

```typescript
import { signal, computed, effect, linkedSignal } from '@angular/core';

const count = signal(0);
count.set(1);
count.update(n => n + 1);

const doubled = computed(() => count() * 2);

effect(() => {
  console.log('count is now', count());
});

const items = signal(['a', 'b', 'c']);
const selectedIndex = linkedSignal(() => items().length > 0 ? 0 : -1);
```

### RxJS Interop (Stable)

```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

const tick = toSignal(interval(1000), { initialValue: 0 });
const count$ = toObservable(count);
```

### Render Hooks (Stable)

```typescript
import { afterEveryRender, afterNextRender } from '@angular/core';

afterNextRender(() => {
  chart.initialize(canvasRef.nativeElement);
});
```

### PendingTasks (Stable)

Tracks outstanding async work. Useful for SSR to delay serialization.

```typescript
import { PendingTasks } from '@angular/core';

const tasks = inject(PendingTasks);
const done = tasks.add();
try { await fetchData(); } finally { done(); }
```

---

## Signal Queries and Inputs Stable

Signal-based queries and inputs replace decorator-based APIs for all new code.

### Signal Queries

```typescript
import { viewChild, viewChildren, contentChild, contentChildren } from '@angular/core';

chartCanvas = viewChild<ElementRef<HTMLCanvasElement>>('chart');
chartCanvasRequired = viewChild.required<ElementRef<HTMLCanvasElement>>('chart');
itemComponents = viewChildren(ItemComponent);
icon = contentChild(IconComponent);
tabs = contentChildren(TabComponent);
```

Signal queries update reactively -- reading them in `computed()` or `effect()` automatically re-runs when results change.

### Signal Inputs

```typescript
import { input, model } from '@angular/core';

name = input<string>('');
userId = input.required<string>();
isExpanded = model(false); // two-way binding
```

### Signal Outputs

```typescript
import { output } from '@angular/core';

searched = output<string>();
cleared = output<void>();
```

---

## Zoneless Change Detection

Angular 20 ships `provideZonelessChangeDetection()` as the stable provider name (renamed from `provideExperimentalZonelessChangeDetection`). Developer preview in 20.0, fully stable in 20.2.

### Setup

```typescript
import { provideZonelessChangeDetection } from '@angular/core';

export const appConfig: ApplicationConfig = {
  providers: [
    provideZonelessChangeDetection(),
  ],
};
```

Remove `zone.js` from `polyfills` in `angular.json`:

```json
{ "polyfills": [] }
```

### How It Works

Change detection is driven entirely by signal reads and explicit `markForCheck()` calls:
- Signal value changes in templates schedule a check automatically
- `async` pipe continues to work (calls `markForCheck()` internally)
- Third-party libraries relying on Zone.js may need `markForCheck()` in callbacks

### Why Zoneless

| Concern | Zone.js | Zoneless |
|---|---|---|
| Bundle size | ~100 KB | Eliminated |
| Async patching | Monkey-patches all browser APIs | None |
| Change detection | Triggered by any async event | Signal-driven, surgical |
| Debugging | Stack traces include zone frames | Clean stack traces |

### CLI Prompts

`ng new` in Angular 20 asks whether to enable zoneless change detection during project scaffolding.

---

## Template HMR Stable and Default

Hot Module Replacement for templates and styles is stable and enabled by default. No configuration required.

- Template and style changes replace the component in the running app without full reload
- Component state (signal values, form state, scroll position) is preserved
- TypeScript class changes still trigger a full reload

---

## Route-Level Render Mode Stable

Per-route rendering strategy (SSR, SSG, CSR) graduates from developer preview to stable.

```typescript
// app.routes.server.ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  { path: '', renderMode: RenderMode.Prerender },
  {
    path: 'blog/:slug',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      const slugs = await fetchAllSlugs();
      return slugs.map(slug => ({ slug }));
    },
  },
  { path: 'dashboard', renderMode: RenderMode.Client },
  { path: '**', renderMode: RenderMode.Server },
];
```

```typescript
// app.config.server.ts
import { provideServerRouting } from '@angular/ssr';

export const config = mergeApplicationConfig(appConfig, {
  providers: [provideServerRouting(serverRoutes)],
});
```

---

## Incremental Hydration Stable

Defers hydration of non-critical UI until needed. Improves LCP by 40-50% in benchmarks.

```typescript
provideClientHydration(withIncrementalHydration())
```

```html
@defer (hydrate on viewport) {
  <app-product-reviews [productId]="id" />
}

@defer (hydrate on interaction) {
  <app-comments-section />
}

@defer (hydrate never) {
  <app-static-footer />
}
```

---

## Template Language Additions

Angular 20 expands the template expression language with four new operators.

### Template Literals

```html
<p>{{ `Hello, ${user.name}! You have ${messages().length} messages.` }}</p>
<img [alt]="`Profile photo of ${user.name}`" [src]="user.avatarUrl" />
```

### Exponentiation Operator

```html
<p>Area: {{ sideLength() ** 2 }} sq units</p>
```

### in Keyword

```html
@if ('email' in user()) {
  <a [href]="'mailto:' + user().email">{{ user().email }}</a>
}
```

### void Operator

```html
<button (click)="void router.navigate(['/home'])">Home</button>
```

---

## Async Redirect Functions

`redirectTo` in route configuration now accepts async functions:

```typescript
export const routes: Routes = [
  {
    path: 'old-dashboard',
    redirectTo: async (route) => {
      const flags = await inject(FeatureFlagService).load();
      return flags.newDashboard ? '/dashboard-v2' : '/dashboard';
    },
  },
  {
    path: 'profile',
    redirectTo: (route) => {
      return inject(AuthService).currentUser$.pipe(
        take(1),
        map(user => user ? `/users/${user.id}` : '/login')
      );
    },
  },
];
```

Both `Promise` and `Observable` return types are supported.

---

## NgComponentOutlet Enhanced

`NgComponentOutlet` now supports binding inputs, outputs, and directives to dynamically rendered components.

```html
<ng-container
  *ngComponentOutlet="
    activeWidget();
    inputs: widgetInputs();
    outputs: widgetOutputs();
    directives: widgetDirectives()
  "
/>
```

| Binding | Type | Description |
|---|---|---|
| `inputs` | `Record<string, unknown>` | Maps to `@Input()` or `input()` |
| `outputs` | `Record<string, Function>` | Maps to `@Output()` or `output()` |
| `directives` | `Type<unknown>[]` | Applied as host directives |

---

## Breaking Changes

### Node.js 18 Dropped

Node.js 18 reached end-of-life. Use Node.js 20.9.0 or later.

### TypeScript < 5.8 Dropped

Angular 20 requires TypeScript 5.8+.

### ng-reflect-* Attributes Removed

Development-mode `ng-reflect-*` attributes are removed. Update tests that query these attributes.

```typescript
// Before (no longer works)
expect(el.getAttribute('ng-reflect-name')).toBe('Alice');

// After
expect(component.name()).toBe('Alice');
```

### InjectFlags API Removed

Migration schematic provided:

```bash
ng update @angular/core --migrate-only --name=inject-flags
```

### HammerJS Deprecated

Built-in HammerJS integration is deprecated. Use Pointer Events or standalone gesture libraries.

### provideExperimentalZonelessChangeDetection Renamed

```typescript
// Before (v18/v19)
provideExperimentalZonelessChangeDetection()

// After (v20)
provideZonelessChangeDetection()
```

Migration schematic handles this rename automatically.

---

## Migration: v19 to v20

```bash
# Step 1: Update Node.js to 20.9+
node --version

# Step 2: Run ng update
ng update @angular/core@20 @angular/cli@20

# Step 3: Update TypeScript
npm install --save-dev typescript@^5.8.0

# Step 4: Remove zone.js (if adopting zoneless)
npm uninstall zone.js
# Remove from angular.json polyfills

# Step 5: Fix ng-reflect test assertions
# Replace getAttribute('ng-reflect-*') with component property access

# Step 6: Remove HammerJS (if used)
npm uninstall hammerjs @types/hammerjs
```

---

## Pattern: Signal-Based Component (v20)

```typescript
import {
  Component, computed, effect, inject, input, output,
  signal, viewChild, ElementRef, afterNextRender,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';

@Component({
  selector: 'app-product-detail',
  standalone: true,
  template: `
    <div [class.loading]="isLoading()">
      @if (product(); as p) {
        <h1>{{ p.name }}</h1>
        <p>{{ \`$\${p.price.toFixed(2)}\` }}</p>
        <canvas #previewCanvas></canvas>
        <button (click)="addToCart()" [disabled]="!inStock()">
          {{ inStock() ? 'Add to Cart' : 'Out of Stock' }}
        </button>
      }
    </div>
  `,
})
export class ProductDetailComponent {
  private productService = inject(ProductService);
  private cartService = inject(CartService);

  productId = input.required<string>();
  showPreview = input(false);
  added = output<string>();

  previewCanvas = viewChild<ElementRef<HTMLCanvasElement>>('previewCanvas');

  product = toSignal(
    this.productService.getProduct$(this.productId()),
    { initialValue: null }
  );

  isLoading = signal(false);
  inStock = computed(() => {
    const p = this.product();
    return p !== null && p.stock > 0;
  });

  constructor() {
    effect(() => console.log('Loading product:', this.productId()));

    afterNextRender(() => {
      const canvas = this.previewCanvas();
      if (canvas && this.showPreview()) {
        initializePreview(canvas.nativeElement);
      }
    });
  }

  addToCart() {
    const p = this.product();
    if (!p) return;
    this.cartService.add(p);
    this.added.emit(p.id);
  }
}
```
