# Svelte/SvelteKit Diagnostics Reference

> Troubleshooting guide for compiler errors, SSR issues, and runes migration. Last updated: 2026-04.

---

## 1. Compiler Errors

| Error | Cause | Fix |
|---|---|---|
| "Rune-like symbol outside runes mode" | `$state`/`$derived` used without runes enabled | Enable globally: `compilerOptions: { runes: true }` in `svelte.config.js`, or per-file: `<svelte:options runes={true} />` |
| "Cannot use $props() outside component initialization" | `$props()` called inside function or conditional | Move to top level of `<script>` |
| "bind: on non-bindable prop" | Parent uses `bind:value` but child lacks `$bindable` | Declare `let { value = $bindable() } = $props()` in child |
| Snippet/slot confusion | Mixing Svelte 4 `<slot />` with runes mode | Use `{@render children()}` instead of `<slot />` |
| "Cannot import $env/static/private in client code" | Private env imported in browser-accessible module | Move import to `+page.server.js` or `src/lib/server/` |
| "Component not found" | Missing or misspelled import | Check import path; SvelteKit does not auto-import components |

---

## 2. SSR Issues

### window/document Access

These globals do not exist in Node.js:

```svelte
<script>
  import { browser } from '$app/environment';

  // Safe: $effect runs only in browser
  $effect(() => {
    window.addEventListener('resize', handler);
    return () => window.removeEventListener('resize', handler);
  });

  // Safe: explicit guard
  if (browser) {
    localStorage.setItem('key', 'value');
  }
</script>
```

### Browser-Only Libraries

Dynamic import inside `onMount`:

```svelte
<script>
  import { onMount } from 'svelte';

  onMount(async () => {
    const { default: Chart } = await import('chart.js/auto');
    // initialize chart
  });
</script>
```

`onMount` never runs during SSR.

### Hydration Mismatches

Logged as `"hydration mismatch"`. Common causes:
- `Date.now()` / `Math.random()` during render
- Browser extension DOM modifications
- Different locale formatting on server vs client

Fix: move non-deterministic values into `$effect` or `onMount`.

---

## 3. Runes Migration Pitfalls

### $: Removed in Runes Mode

```svelte
<!-- Svelte 4 -->
<script>
  let count = 0;
  $: doubled = count * 2;
  $: { console.log(count); }
</script>

<!-- Svelte 5 (runes) -->
<script>
  let count = $state(0);
  let doubled = $derived(count * 2);
  $effect(() => { console.log(count); });
</script>
```

### Object Mutation Now Works

In Svelte 4, `obj.prop = x` was not reactive (required reassignment). In Svelte 5, `$state` objects have deep reactive proxies:

```svelte
<script>
  // Svelte 4: obj = { ...obj, prop: x }  (had to reassign)
  // Svelte 5: obj.prop = x               (tracked automatically)
  let user = $state({ name: 'Alice' });
  user.name = 'Bob';                      // reactive!
</script>
```

### Effect Cycles

Reading and writing the same `$state` in a `$effect` creates an infinite loop:

```svelte
<script>
  let count = $state(0);

  // BAD: infinite loop
  $effect(() => { count = count + 1; });

  // GOOD: use $derived for computed values
  let doubled = $derived(count * 2);
</script>
```

### Store $ Shorthand

Auto-subscription `$myStore` still works but may not behave as expected inside rune expressions. Prefer `.svelte.ts` module-level `$state` for new shared state.

### Effect Timing

`$effect` fires after DOM update. For pre-DOM reads (measuring dimensions), use `$effect.pre`.

### Migration Table

| Svelte 4 | Svelte 5 |
|---|---|
| `let count = 0` | `let count = $state(0)` |
| `export let value` | `let { value } = $props()` |
| `$: doubled = count * 2` | `let doubled = $derived(count * 2)` |
| `$: { doEffect(count); }` | `$effect(() => { doEffect(count); })` |
| `<svelte:component this={C} />` | `<C />` (dynamic component) |
| `<slot />` | `{@render children()}` (snippets) |
| Stores as primary state | `.svelte.ts` module-level `$state` preferred |

---

## 4. SvelteKit Common Issues

| Issue | Cause | Fix |
|---|---|---|
| 404 on direct URL access (static) | No HTML file for client route | `adapter({ fallback: '200.html' })` |
| CSRF error on form POST | Origin header validation | Set `ORIGIN` env var; or disable in test config |
| Stale `PageData` types | Generated types out of date | Restart dev server or `npx svelte-kit sync` |
| Load not re-running | Params/URL unchanged | Use `depends()` + `invalidate()`, or `invalidateAll()` |
| Server code leaking to client | Import from `$lib/server/` in client | Move import to server-only module |
| `fetch` relative URL in server load | Server has no origin context | Use absolute URL or SvelteKit's `fetch` argument |

### Error Pages

```svelte
<!-- src/routes/+error.svelte -->
<script>
  import { page } from '$app/stores';
</script>

<h1>{$page.status}</h1>
<p>{$page.error?.message}</p>
```

### Debug Techniques

1. **Compiler warnings:** Check terminal output during dev for Svelte warnings
2. **Type generation:** Run `npx svelte-kit sync` to refresh `./$types`
3. **SSR output:** View page source to verify server-rendered HTML
4. **Network tab:** Check that load data arrives as JSON payload, not full page reload
5. **`$inspect`:** Add `$inspect(variable)` for reactive debugging (dev only)
