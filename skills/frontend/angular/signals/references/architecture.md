# Angular Signals Architecture Reference

Deep reference for signal primitives, computed values, effects, linkedSignal, resource, and signal-based component APIs.

---

## 1. Signal Primitives

### What Is a Signal

A signal is a reactive value container. Reading a signal inside a reactive context (computed, effect, template) automatically registers a dependency. When the signal's value changes, all dependents are notified synchronously.

```typescript
import { signal } from '@angular/core';

const count = signal(0);
console.log(count()); // 0
count.set(5);
count.update(v => v + 1);
```

### Equality Checking

Angular uses `Object.is` by default. Custom equality functions suppress unnecessary notifications:

```typescript
const user = signal<User>(
  { id: 1, name: 'Alice' },
  { equal: (a, b) => a.id === b.id }
);
```

| Scenario | Behavior |
|---|---|
| Primitive (number, string, boolean) | `Object.is` -- efficient |
| Object/Array (default) | Reference equality only |
| Object with custom equal fn | Structural comparison |
| NaN === NaN | `Object.is` returns true -- unchanged |

### Reactive Contexts

Places Angular tracks signal reads:
- Template expressions in a signal-aware component
- `computed()` derivations
- `effect()` callbacks
- `resource()` request functions

Reading outside a reactive context works but does not establish a tracked dependency.

---

## 2. computed()

Derived signal whose value recalculates when dependencies change. Lazy, cached, read-only.

```typescript
const firstName = signal('Jane');
const lastName = signal('Doe');
const fullName = computed(() => `${firstName()} ${lastName()}`);
```

### Dependency Tracking

Dependencies tracked per execution path. Conditional reads create dynamic graphs:

```typescript
const display = computed(() =>
  showEmail() ? email() : 'hidden'
);
// email tracked only when showEmail() is true
```

### Computed with Equality

```typescript
const expensiveList = computed(
  () => items().filter(i => i.active),
  { equal: (a, b) => a.length === b.length && a.every((v, i) => v === b[i]) }
);
```

### Chaining

Computeds depend on other computeds. Angular builds a dependency graph. Circular dependencies throw at runtime.

```typescript
const base = signal(100);
const taxed = computed(() => base() * 1.08);
const total = computed(() => taxed() + 5.00);
```

---

## 3. effect()

Schedules a side-effecting function to run when signal dependencies change. Runs once immediately to establish dependencies.

```typescript
effect(() => {
  document.body.className = theme();
});
```

### Injection Context

Must be called in an injection context or with an explicit injector:

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

### Execution Timing

Effects are asynchronous -- they run during Angular's change detection cycle (microtask queue flush). Multiple rapid signal mutations within a synchronous block result in a single effect execution.

### allowSignalWrites

For rare legitimate cases:

```typescript
effect(() => {
  if (authService.isExpired()) {
    sessionSignal.set(null);
  }
}, { allowSignalWrites: true });
```

Use sparingly. Indicates a design smell in most cases.

---

## 4. linkedSignal()

Writable signal that auto-resets when a source signal changes. Bridges `signal()` (writable, no auto-reset) and `computed()` (auto-updating, read-only).

### Shorthand

```typescript
const selectedTab = signal('overview');
const scrollPosition = linkedSignal(() => 0);
// scrollPosition resets to 0 whenever any dependency changes
```

### Options Object

```typescript
const selected = linkedSignal({
  source: options,
  computation: (newOptions, previous) => {
    if (previous && newOptions.includes(previous.value)) return previous.value;
    return newOptions[0];
  },
  equal: (a, b) => a === b
});
```

### Comparison

| | signal() | computed() | linkedSignal() |
|---|---|---|---|
| Writable | Yes | No | Yes |
| Auto-updates from source | No | Yes | Yes |
| User can override | Yes | No | Yes (until source changes) |

---

## 5. resource() and rxResource()

Async data loading with signals as the reactive layer.

### resource() -- Promise-Based

```typescript
productResource = resource({
  request: this.productId,
  loader: async ({ request: id, abortSignal }) => {
    const res = await fetch(`/api/products/${id}`, { signal: abortSignal });
    return res.json();
  }
});
```

### rxResource() -- Observable-Based

```typescript
import { rxResource } from '@angular/core/rxjs-interop';

productResource = rxResource({
  request: this.productId,
  loader: ({ request: id }) => this.http.get<Product>(`/api/products/${id}`)
});
```

### Resource API

```typescript
resource.value()      // Signal<T | undefined>
resource.status()     // Signal<ResourceStatus>
resource.error()      // Signal<unknown>
resource.isLoading()  // Signal<boolean>
resource.reload()     // re-fetch with current params
resource.set(value)   // manually set value (status -> 'local')
resource.update(fn)   // update value via function
```

### Status Values

| Status | Meaning |
|---|---|
| `idle` | Request signal is null/undefined |
| `loading` | Initial fetch in progress |
| `reloading` | Re-fetching, previous value available |
| `resolved` | Data available |
| `error` | Loader failed |
| `local` | Value manually set |

### Request Signal Shape

- Raw signal: `request: this.productId`
- Computed: `request: computed(() => ({ id: this.productId(), locale: this.locale() }))`
- Null/undefined: enters idle state, loader does not run

---

## 6. Signal Inputs, Outputs, and Model

### input()

```typescript
title = input<string>('Default Title');  // optional
count = input.required<number>();         // required
```

Returns `InputSignal<T>` -- read-only signal. Use in templates: `{{ title() }}`.

### input() vs @Input()

| Feature | @Input() | input() |
|---|---|---|
| Type safety | Weaker | Strong (`input.required<T>()`) |
| Reactive | No (need ngOnChanges) | Yes (it is a signal) |
| Works with computed() | No | Yes |
| Transform support | `@Input({ transform })` | `input({ transform })` |

### model() -- Two-Way Binding

```typescript
count = model(0); // ModelSignal<number>
```

Both an InputSignal (receives) and an OutputEmitterRef (emits `countChange` automatically).

Parent: `<app-counter [(count)]="parentCount" />`

### output()

```typescript
searched = output<string>();
searched.emit(query);
```

Equivalent to `@Output() EventEmitter<T>` but integrates better with signals.

---

## 7. Signal Queries

### viewChild()

```typescript
canvas = viewChild<ElementRef<HTMLCanvasElement>>('canvas');       // T | undefined
canvas2 = viewChild.required<ElementRef<HTMLCanvasElement>>('canvas'); // T (throws if missing)
```

### viewChildren()

```typescript
items = viewChildren<ItemComponent>(ItemComponent); // Signal<readonly ItemComponent[]>
```

### contentChild() and contentChildren()

```typescript
icon = contentChild(IconComponent);
children = contentChildren(ListItemComponent);
```

### Signal Queries vs Decorator Queries

| Feature | @ViewChild | viewChild() |
|---|---|---|
| Reactive in computed/effect | No | Yes |
| Required enforcement | Runtime error | `viewChild.required()` |
| Type safety | Weaker | Stronger |

Signal queries update when the view is initialized. In templates, they are always current. In code, read them after view initialization.
