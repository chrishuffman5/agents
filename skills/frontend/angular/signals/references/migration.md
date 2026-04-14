# Zone.js to Zoneless Migration and RxJS Interop Reference

Step-by-step migration guide from Zone.js to zoneless change detection, and patterns for bridging RxJS Observables with Angular Signals.

---

## Zone.js to Zoneless Migration

### Migration Strategy Overview

The migration is incremental. The goal is to make every component self-sufficient about when it needs to re-render, rather than relying on Zone.js to trigger checks globally.

### Step 1: Adopt OnPush Everywhere

Before touching Zone.js, convert all components to `ChangeDetectionStrategy.OnPush`. This forces you to find places where change detection is relied upon implicitly.

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
})
```

Use the Angular schematic:

```bash
ng generate @angular/core:use-change-detection-on-push
```

### Step 2: Replace Imperative State with Signals

Convert `BehaviorSubject` and mutable class properties to signals where practical:

```typescript
// Before
export class UserService {
  private _user = new BehaviorSubject<User | null>(null);
  user$ = this._user.asObservable();
  setUser(u: User) { this._user.next(u); }
}

// After
export class UserService {
  user = signal<User | null>(null);
  setUser(u: User) { this.user.set(u); }
}
```

### Step 3: Use toSignal() for RxJS Interop

Where you cannot convert an Observable to a signal (complex pipelines, HTTP streams), use `toSignal()`:

```typescript
@Component({ ... })
export class OrderListComponent {
  private orderService = inject(OrderService);
  orders = toSignal(this.orderService.orders$, { initialValue: [] });
}
```

### Step 4: Audit Third-Party Libraries

Some libraries depend on Zone.js. Common culprits:
- Legacy UI component libraries (pre-v17 versions)
- WebSocket wrappers
- Libraries using `setTimeout` without Angular awareness

Mitigation:
- Upgrade the library to a signals-aware version
- Use `markForCheck()` on the component after library callbacks
- Call `NgZone.run()` if Zone.js is partially present

### Step 5: Enable Zoneless

```typescript
// app.config.ts
provideZonelessChangeDetection()
```

### Step 6: Remove zone.js

In `angular.json`, remove `zone.js` from polyfills. Uninstall:

```bash
npm uninstall zone.js
```

### Step 7: Run Tests

Update TestBed to use zoneless:

```typescript
TestBed.configureTestingModule({
  providers: [provideZonelessChangeDetection()]
});

fixture.detectChanges();
await fixture.whenStable();
```

### Step 8: Use the v21 Migration Schematic

```bash
ng generate @angular/core:onpush_zoneless_migration
```

This schematic:
- Adds `ChangeDetectionStrategy.OnPush` to all components
- Converts `@Input()`/`@Output()` to `input()`/`output()` where straightforward
- Updates `angular.json` to remove `zone.js` polyfill
- Adds `provideZonelessChangeDetection()` to app config

### Hybrid Mode (Transition Period)

During migration, `provideZoneChangeDetection()` and OnPush components coexist. Zone.js still runs, but OnPush components only update when explicitly triggered. Migrate component by component.

---

## How Zoneless Change Detection Works

### Zone.js Model (Legacy)

Zone.js monkey-patches browser APIs at load time: `setTimeout`, `Promise.then`, `addEventListener`, `fetch`, `requestAnimationFrame`. Every patched async operation notifies Angular, triggering full-tree change detection.

**Costs:**
- ~25-30KB added to bundle
- CD runs on every timer tick, event, or HTTP response -- even unrelated ones
- Third-party timers trigger Angular checks unexpectedly

### Zoneless Model

With `provideZonelessChangeDetection()`, Angular's scheduler runs change detection only when something explicitly signals a change:

| Trigger | How Angular Knows |
|---|---|
| Signal value changes | Internal notification from signal graph |
| Component event handler fires | Framework wraps event dispatch |
| `markForCheck()` called | Explicit opt-in |
| `async` pipe emits | Pipe calls `markForCheck()` internally |
| `resource()`/`rxResource()` resolves | Internal notification |

No polling. No monkey-patching. Change detection is surgical.

---

## RxJS Interop

### toSignal() -- Observable to Signal

```typescript
import { toSignal } from '@angular/core/rxjs-interop';

price = toSignal(this.priceService.price$, { initialValue: 0 });
```

**Options:**

| Option | Type | Purpose |
|---|---|---|
| `initialValue` | `T` | Value before Observable emits |
| `requireSync` | `boolean` | Throws if Observable does not emit synchronously |
| `manualCleanup` | `boolean` | Opt-out of automatic DestroyRef unsubscription |
| `injector` | `Injector` | Use outside injection context |

**Automatic Cleanup:** `toSignal()` subscribes and unsubscribes via `DestroyRef`. No manual cleanup needed.

**requireSync Pattern:** For BehaviorSubjects that always emit synchronously:

```typescript
const currentUser = toSignal(this.auth.currentUser$, { requireSync: true });
// Type is User, not User | undefined
```

### toObservable() -- Signal to Observable

```typescript
import { toObservable } from '@angular/core/rxjs-interop';

results$ = toObservable(this.query).pipe(
  debounceTime(300),
  distinctUntilChanged(),
  switchMap(q => this.searchService.search(q))
);
```

Emits current value immediately on subscription, then on every signal change. Uses an `effect()` internally.

### Bridging Patterns

| Need | Pattern |
|---|---|
| HTTP data in component | `toSignal(this.http.get<T>(url))` |
| Signal into RxJS pipeline | `toObservable(signal).pipe(...)` |
| Two-way bridge | `toObservable()` -> pipe -> `toSignal()` |
| BehaviorSubject to signal | `toSignal(subject$, { requireSync: true })` |
| NgRx store to signal | `toSignal(store.select(mySelector))` |

### Complete Bridge Example

```typescript
@Component({ ... })
export class SearchComponent {
  query = signal('');

  // Signal -> Observable -> RxJS pipeline -> Signal
  results$ = toObservable(this.query).pipe(
    debounceTime(300),
    distinctUntilChanged(),
    switchMap(q => this.searchService.search(q))
  );

  results = toSignal(this.results$, { initialValue: [] });
}
```

---

## State Management Patterns

### Local Component State

```typescript
@Component({ ... })
export class FilterComponent {
  searchTerm = signal('');
  activeOnly = signal(false);
  currentPage = signal(1);

  filteredItems = computed(() =>
    this.allItems()
      .filter(i => !this.activeOnly() || i.active)
      .filter(i => i.name.includes(this.searchTerm()))
  );

  pageItems = computed(() => {
    const page = this.currentPage();
    return this.filteredItems().slice((page - 1) * 10, page * 10);
  });
}
```

### Shared Service State

```typescript
@Injectable({ providedIn: 'root' })
export class CartService {
  private _items = signal<CartItem[]>([]);
  readonly items = this._items.asReadonly();
  readonly total = computed(() => this._items().reduce((s, i) => s + i.price * i.qty, 0));

  addItem(item: CartItem) {
    this._items.update(items => [...items, item]);
  }
}
```

### Using untracked()

Read a signal without registering a dependency:

```typescript
effect(() => {
  const log = auditLog();  // dependency
  const userId = untracked(() => currentUser()?.id); // not tracked
  console.log(`User ${userId} triggered:`, log);
});
```
