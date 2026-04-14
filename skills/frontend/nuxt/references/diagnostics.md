# Nuxt Diagnostics Reference

> Troubleshooting guide for build errors, hydration mismatches, and data fetching issues. Last updated: 2026-04.

---

## 1. Build Errors

| Error | Fix |
|---|---|
| `Cannot find module` | Run `nuxi prepare` to regenerate `.nuxt/types/` |
| Unknown composable/component | Ensure file is in scanned directory; run `nuxi dev` |
| Circular dependency | Break cycle -- move shared logic to a third file |
| Vite plugin conflict | Check module order; use `nuxt.hook('vite:extendConfig')` |
| `TypeScript error in .vue file` | Run `nuxi typecheck`; ensure vue-tsc is installed |
| Module compatibility error | Check module supports your Nuxt version; update module |

### nuxi prepare

Always run `nuxi prepare` after:
- Adding/removing files in scanned directories
- Changing `nuxt.config.ts` module list
- Updating Nuxt or module versions
- Changing TypeScript configuration

This regenerates `.nuxt/types/` which powers auto-import IntelliSense.

---

## 2. Hydration Mismatches

**Symptom:** `[Vue warn]: Hydration mismatch` -- server DOM differs from client render.

| Cause | Fix |
|---|---|
| `Date.now()` / `Math.random()` in render | Seed with `useState` server-side |
| `localStorage` / `window` in setup | Wrap in `onMounted` or `if (import.meta.client)` |
| Inconsistent server/client data | Ensure `useFetch` key is stable |
| Third-party components | Wrap in `<ClientOnly>` |
| Browser extensions modifying DOM | Not a bug; ignore or add `data-allow-mismatch` |

```vue
<ClientOnly>
  <BrowserOnlyComponent />
  <template #fallback>Loading...</template>
</ClientOnly>
```

### Debugging Steps

1. Open browser DevTools console -- Vue shows the mismatch diff
2. Check Nuxt DevTools Payload panel for SSR data consistency
3. Compare server-rendered HTML (view source) with client render
4. Wrap suspect components in `<ClientOnly>` to isolate

---

## 3. Data Fetching Gotchas

| Issue | Cause | Fix |
|---|---|---|
| Stale data on re-navigation | `useFetch` static key no re-fetch | Add `watch` or call `refresh()` |
| Key collision | Two `useAsyncData` same key share data | Use unique keys |
| Pending forever | `server: false` + `lazy: false` | Use `lazy: true` with `server: false` |
| Body in GET | `readBody` on GET handler | Use `getQuery` for GET params |
| Double fetch | `$fetch` in setup + `onMounted` | Replace with `useFetch` |
| Type errors on data | Missing generic type | `useFetch<MyType>('/api/...')` |

### Common Patterns

```ts
// Pending state handling
const { data, status } = await useFetch('/api/items', { lazy: true })
// status: 'idle' | 'pending' | 'success' | 'error'

// Conditional fetch
const { data } = await useFetch('/api/user', {
  server: false,      // client-only
  lazy: true,         // non-blocking
  immediate: false,   // don't fetch on mount
})
// Manually trigger: await refresh()
```

---

## 4. Runtime Errors

| Error | Cause | Fix |
|---|---|---|
| `useState` key mismatch | Different keys on server/client | Ensure consistent key strings |
| `navigateTo` in setup fails | Called before route is ready | Use in middleware or event handler |
| Module `setup()` error | Module throws during initialization | Check module logs; update module |
| `createError` not caught | Missing error boundary | Add `error.vue` page |

### Error Handling

```vue
<!-- error.vue (app-level error page) -->
<script setup>
const error = useError()
const handleClear = () => clearError({ redirect: '/' })
</script>

<template>
  <div>
    <h1>{{ error.statusCode }}</h1>
    <p>{{ error.message }}</p>
    <button @click="handleClear">Go Home</button>
  </div>
</template>
```

### showError vs createError

- `createError` -- throw in server routes for HTTP errors
- `showError` -- trigger error page from client-side code
- `clearError` -- dismiss error and optionally redirect

---

## 5. Deployment Issues

| Issue | Fix |
|---|---|
| Missing env vars in production | Use `NUXT_*` prefix for runtime override |
| Wrong preset auto-detected | Set `nitro: { preset: 'node' }` explicitly |
| Static assets 404 | Check `app.baseURL` in config |
| Edge runtime incompatible code | Avoid Node.js-only APIs (fs, path) in server routes |
| Large `.output` size | Enable `nitro: { minify: true, compressPublicAssets: true }` |
