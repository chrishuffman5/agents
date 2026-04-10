# Angular Signals Pattern Guide

Patterns and best practices for `signal()`, `computed()`, `effect()`, `linkedSignal()`, and `resource()`.

---

## signal() -- Writable Reactive State

```typescript
import { signal } from '@angular/core';

const count = signal(0);
count();              // read: 0
count.set(5);         // replace
count.update(n => n + 1); // derive from current
```

### Custom Equality

Suppress unnecessary notifications for object-valued signals:

```typescript
const user = signal<User>(
  { id: 1, name: 'Alice' },
  { equal: (a, b) => a.id === b.id }
);
```

### Read-Only View

Expose signals from services without allowing external writes:

```typescript
@Injectable({ providedIn: 'root' })
export class CartService {
  private _items = signal<CartItem[]>([]);
  readonly items = this._items.asReadonly();
}
```

---

## computed() -- Derived Reactive State

Lazy, cached, read-only. Recalculates only when dependencies change.

```typescript
const firstName = signal('Jane');
const lastName = signal('Doe');
const fullName = computed(() => `${firstName()} ${lastName()}`);
```

### Conditional Dependencies

Dependencies are tracked per execution path:

```typescript
const display = computed(() =>
  showEmail() ? email() : 'hidden'
);
// email is only a dependency when showEmail() is true
```

### Chaining

Computeds can depend on other computeds. Angular builds the dependency graph automatically.

```typescript
const base = signal(100);
const taxed = computed(() => base() * 1.08);
const total = computed(() => taxed() + 5.00);
```

### When NOT to Use computed()

- When the derivation has side effects (use `effect()`)
- When the value depends on non-signal state (e.g., `Date.now()`)
- When you need write access to derived state (use `linkedSignal()`)

---

## effect() -- Side Effects

Runs once immediately, then re-runs whenever signal dependencies change.

```typescript
effect(() => {
  document.body.className = theme(); // runs on init and every change
});
```

### Injection Context Requirement

`effect()` must be called inside an injection context (constructor, field initializer) or with an explicit injector:

```typescript
effect(() => { ... }, { injector: this.injector });
```

### onCleanup

```typescript
effect((onCleanup) => {
  const sub = interval(1000).subscribe(() => console.log(tick()));
  onCleanup(() => sub.unsubscribe());
});
```

### Legitimate Use Cases

| Use Case | Notes |
|---|---|
| localStorage sync | Low risk, common pattern |
| Analytics tracking | Read signals, call analytics API |
| DOM manipulation | Canvas, video, third-party libraries |
| Third-party library sync | Migration pattern from Zone.js |

### Anti-Patterns

**Do not write signals in effects** (risk of infinite loops):

```typescript
// BAD
effect(() => { doubled.set(count() * 2); });

// GOOD
const doubled = computed(() => count() * 2);
```

**Do not make API calls in effects** (use `resource()` instead):

```typescript
// BAD
effect(() => {
  this.http.get(`/api/products/${id()}`).subscribe(p => product.set(p));
});

// GOOD
productResource = resource({
  request: this.productId,
  loader: ({ request: id, abortSignal }) =>
    fetch(`/api/products/${id}`, { signal: abortSignal }).then(r => r.json())
});
```

### untracked()

Read a signal without registering a dependency:

```typescript
effect(() => {
  const log = auditLog();  // dependency
  const userId = untracked(() => currentUser()?.id); // not a dependency
  console.log(`User ${userId} triggered:`, log);
});
```

---

## linkedSignal() -- Writable Derived State (v19+)

A writable signal that auto-resets when a source signal changes.

### Shorthand

```typescript
const selectedTab = signal('overview');
const scrollPosition = linkedSignal(() => 0); // resets to 0 on any dependency change
```

### Options Object

```typescript
const options = signal(['A', 'B', 'C']);
const selected = linkedSignal({
  source: options,
  computation: (newOptions, previous) => {
    if (previous && newOptions.includes(previous.value)) return previous.value;
    return newOptions[0];
  },
});
```

### Use Cases

- **Dependent dropdowns**: country changes -> city resets
- **Pagination**: filter changes -> page resets to 1
- **Tab content**: tab changes -> detail panel resets

### Comparison

| | signal() | computed() | linkedSignal() |
|---|---|---|---|
| Writable | Yes | No | Yes |
| Auto-updates from source | No | Yes | Yes |
| User can override | Yes | No | Yes (until source changes) |

---

## resource() and rxResource() -- Async Data (v19+)

### Promise-Based

```typescript
productResource = resource({
  request: this.productId,
  loader: async ({ request: id, abortSignal }) => {
    const res = await fetch(`/api/products/${id}`, { signal: abortSignal });
    return res.json();
  }
});
```

### Observable-Based

```typescript
import { rxResource } from '@angular/core/rxjs-interop';

productResource = rxResource({
  request: this.productId,
  loader: ({ request: id }) =>
    this.http.get<Product>(`/api/products/${id}`)
});
```

### Template Usage

```html
@if (productResource.isLoading()) {
  <app-spinner />
} @else if (productResource.error()) {
  <p>Error: {{ productResource.error() }}</p>
} @else {
  <h2>{{ productResource.value()?.name }}</h2>
}
```

### Status Values

| Status | Meaning |
|---|---|
| `idle` | Request signal is null/undefined |
| `loading` | Initial fetch in progress |
| `reloading` | Re-fetching with previous value available |
| `resolved` | Data available |
| `error` | Loader failed |
| `local` | Value was manually set |

### Key Features

- **Automatic abort**: previous request is cancelled when the request signal changes
- **Null guard**: null/undefined request enters idle state, loader does not run
- **Manual refresh**: `resource.reload()` re-fetches with current parameters
- **Local override**: `resource.set(value)` or `resource.update(fn)` sets local value
