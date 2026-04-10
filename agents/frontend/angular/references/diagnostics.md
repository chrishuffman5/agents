# Angular Diagnostics Reference

Common errors, build issues, and performance debugging techniques for Angular applications.

---

## 1. Common Errors

### ExpressionChangedAfterItHasBeenCheckedError

**Cause:** A binding value changed after Angular completed its change detection pass. Angular detects this in development mode with a second verification pass and throws.

**Common triggers:**
- Setting a value in `ngAfterViewInit` or `ngAfterContentInit` that is bound in the parent template
- Service value that changes synchronously during change detection
- Computed values that depend on mutable external state

**Solutions:**

```typescript
// Option 1: Defer to next microtask
ngAfterViewInit() {
  Promise.resolve().then(() => this.title = 'New Title');
}

// Option 2: Move initialization to ngOnInit
ngOnInit() {
  this.title = 'New Title'; // safe -- before CD runs on this component
}

// Option 3: Use signals (preferred)
title = signal('');
ngAfterViewInit() {
  this.title.set('New Title'); // signals schedule CD correctly
}
```

### NullInjectorError: No provider for X

**Cause:** Angular cannot find a provider for an injectable in the current injector tree.

**Checklist:**
1. Missing `providedIn: 'root'` on the service
2. Service not listed in `providers[]` of the component or module
3. Missing module import (e.g., `ReactiveFormsModule` not imported for form directives)
4. Using `HttpClient` without `provideHttpClient()` in app config
5. Lazy-loaded route expecting a service from a different injector scope

### Template Parse Errors

| Error | Cause | Fix |
|---|---|---|
| `Can't bind to 'ngModel'` | `FormsModule` not imported | Add `FormsModule` to component imports |
| `'app-child' is not a known element` | Component not imported | Add component to `imports` array |
| `Can't bind to 'routerLink'` | `RouterLink` not imported | Add `RouterLink` to component imports |
| `Can't bind to 'formGroup'` | `ReactiveFormsModule` missing | Add `ReactiveFormsModule` to imports |

### Circular Dependency

Angular DI throws if Service A depends on Service B and Service B depends on Service A.

**Solutions:**
- Introduce a third service that both depend on
- Use `forwardRef(() => ServiceB)` if one is defined after the other in the file
- Refactor responsibilities to break the cycle

### NG0100: Expression has changed after it was checked

Same root cause as ExpressionChangedAfterItHasBeenCheckedError. In Angular 14+, the error code is NG0100. Solutions are identical.

### NG0200: Circular dependency in DI

The injector detected a circular reference. Review the dependency chain and introduce an intermediary service or use `forwardRef()`.

### NG0203: inject() must be called from injection context

`inject()` was called outside a constructor, field initializer, or factory function. Move the call to one of those locations, or pass an `Injector` explicitly.

---

## 2. Build Issues

### Bundle Size Analysis

```bash
ng build --stats-json
npx source-map-explorer "dist/my-app/browser/*.js"
```

Look for: duplicate dependencies, entire library imported when only part is needed, polyfills included unnecessarily.

### Lazy Loading Verification

After build, check `dist/` for chunk files. Each lazy-loaded route should produce a separate `.js` chunk. If everything lands in `main.js`, lazy loading is not working.

```bash
ls -la dist/my-app/browser/
# Expect: main.js, chunk-XXXXX.js (one per lazy route)
```

Verify `loadComponent`/`loadChildren` syntax is correct. Dynamic imports must use string literals for static analysis.

### Tree-Shaking Verification

Common culprits:
- `import * as _ from 'lodash'` -- imports entire lodash (use `import { debounce } from 'lodash-es'`)
- Barrel module re-exporting everything from Angular Material
- Services without `providedIn: 'root'` that are always provided

### AOT Compilation Errors

Production builds always use AOT. If a template error only appears on `ng build` and not `ng serve`, the dev server may be using JIT.

```bash
ng serve --aot   # catch AOT errors during development
```

Common AOT-only errors:
- Dynamic component creation patterns not AOT-compatible
- Template type errors that TypeScript misses in JIT mode
- Arrow functions in decorator metadata (use regular functions)

### Ivy Compatibility

Since v9, Angular uses the Ivy compiler. All third-party packages must be Ivy-compatible. If a package causes build errors, check for an updated version or community fork.

---

## 3. Performance Debugging

### Angular DevTools (Chrome Extension)

**Component Tree:**
- Visualize component hierarchy
- Inspect component inputs/outputs/state
- Find which component owns a piece of DOM

**Profiler:**
- Record a change detection session
- See which components triggered CD and how long each took
- Identify components that check unnecessarily (candidates for OnPush)

**Signal Inspector (v17+):**
- View all signals in a selected component
- Visualize dependency graph between signals and computeds
- Track effect execution timing

### Chrome DevTools Performance Tab

1. Open DevTools -> Performance -> Record
2. Interact with the app
3. Look for long tasks (red bars) in the main thread
4. Flame chart: identify Angular CD cycles vs your code vs rendering

### Identifying Unnecessary Change Detection Cycles

```typescript
// Temporarily add a console.trace to track who triggers checks
get userData() {
  console.trace('userData accessed');
  return this._userData;
}
```

With Angular DevTools Profiler, look for components with many "check" events that have no input changes -- those are candidates for OnPush.

### runOutsideAngular (Zone.js Apps)

```typescript
this.ngZone.runOutsideAngular(() => {
  this.mapElement.addEventListener('mousemove', this.onMouseMove.bind(this));
});
```

High-frequency events (mouse move, scroll, WebSocket) should run outside Angular's zone. Only call `ngZone.run()` when the UI actually needs to update.

### Memory Leak Detection

- Use Chrome DevTools Memory tab -> Heap Snapshot
- Take snapshot before and after navigating away from a component, then compare
- Leaked subscriptions are the most common cause

**Prevention:**
- `takeUntilDestroyed` for RxJS subscriptions
- `async` pipe for template subscriptions
- `toSignal()` for Observable-to-signal conversion (auto-cleanup)
- Manual `unsubscribe()` in `ngOnDestroy` as last resort

```typescript
export class MyComponent implements OnDestroy {
  private subscription = Subscription.EMPTY;

  ngOnInit() {
    this.subscription = this.someService.data$.subscribe(d => this.data = d);
  }

  ngOnDestroy() {
    this.subscription.unsubscribe();
  }
}
```

### Zoneless Debugging

In zoneless mode, if the UI does not update after an action:
1. Verify the state is stored in a signal (not a plain property)
2. Check that the signal is read in the template with `()`
3. For third-party library callbacks, inject `ChangeDetectorRef` and call `markForCheck()`
4. For RxJS streams in templates, ensure the `async` pipe is used

### SSR Hydration Mismatches

When server-rendered HTML does not match client render:
- Use `useEffect`-equivalent (`afterNextRender`) for client-only content
- Check for timezone-dependent formatting (dates, currencies)
- Verify `@defer` blocks with hydrate triggers have `provideClientHydration(withIncrementalHydration())` configured
- Use Angular DevTools to identify hydration error locations
