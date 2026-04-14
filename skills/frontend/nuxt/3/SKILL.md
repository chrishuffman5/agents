---
name: frontend-nuxt-3
description: "Expert agent for Nuxt 3. Covers Nuxt 3 architecture, features, and migration path to Nuxt 4. Includes flat directory structure, Nitro engine, auto-imports, Composition API integration, and compatibility version flag for early v4 adoption. WHEN: \"Nuxt 3\", \"Nuxt 3.x\", \"migrate Nuxt 3 to 4\", \"Nuxt 3 upgrade\", \"compatibilityVersion\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Nuxt 3 Specialist

You are a specialist in Nuxt 3 (3.x series). Nuxt 3 is a full-stack Vue 3 framework built on Nitro, Vite, and the Composition API. This agent covers Nuxt 3 features and the migration path to Nuxt 4.

## Nuxt 3 Architecture

### Flat Directory Structure

```
nuxt.config.ts
pages/
components/
composables/
layouts/
middleware/
plugins/
app.vue
error.vue
server/
  api/
  middleware/
  plugins/
```

All application code lives at the root level (unlike Nuxt 4's `app/` directory).

### Key Features

- **Nitro server engine** -- Universal deployment to 15+ targets
- **Vite-powered** -- Fast HMR and optimized builds
- **Auto-imports** -- Components, composables, Vue APIs auto-available
- **File-based routing** -- `pages/` directory maps to routes
- **TypeScript first** -- Full type safety with auto-generated types
- **Composition API** -- `<script setup>` as the standard
- **Hybrid rendering** -- SSR, SSG, ISR, SPA per route via `routeRules`

### Data Fetching

```ts
// useFetch -- SSR-safe with deduplication
const { data } = await useFetch('/api/users')

// useAsyncData -- custom async logic
const { data } = await useAsyncData('key', () => $fetch('/api/data'))

// Note: In Nuxt 3, data is deep reactive (ref), not shallowRef
data.value.users[0].name = 'Alice'   // triggers reactivity
```

---

## Compatibility Version Flag

Enable Nuxt 4 behavior in Nuxt 3 without moving files:

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  future: { compatibilityVersion: 4 }
})
```

This activates:
- `shallowRef` for `useFetch`/`useAsyncData` data (instead of deep `ref`)
- Shared `useAsyncData` keys (global deduplication)
- Stricter `definePageMeta` static analysis
- New `useId()` and `useRouteAnnouncer()` APIs
- Type-safe `runtimeConfig` (accessing undefined keys is a TypeScript error)

---

## Migration to Nuxt 4

### Step-by-Step

1. **Enable compatibility flag** -- `future: { compatibilityVersion: 4 }` to catch issues early.

2. **Move to `app/` directory** (optional but recommended):
   ```
   pages/        -> app/pages/
   components/   -> app/components/
   composables/  -> app/composables/
   layouts/      -> app/layouts/
   middleware/    -> app/middleware/
   plugins/      -> app/plugins/
   app.vue       -> app/app.vue
   error.vue     -> app/error.vue
   ```

3. **Update TypeScript config** -- Extend `.nuxt/tsconfig.app.json` instead of `.nuxt/tsconfig.json`.

4. **Audit nested mutations** -- `shallowRef` change means `data.value.nested.prop = x` no longer triggers reactivity. Replace with top-level reassignment or opt in with `{ deep: true }`.

5. **Review `useAsyncData` keys** -- Shared keys now deduplicate globally. Unrelated data with the same key will collide.

6. **Move isomorphic code to `shared/`** -- New directory auto-imported in both `app/` and `server/`. Must be pure TypeScript (no Vue or Nitro imports).

7. **Fix `definePageMeta` dynamic values** -- Statically analyzed at build time. Replace dynamic values with `useRoute()` at runtime.

8. **Update third-party modules** -- Check for `compatibilityVersion: 4` support.

9. **Run `nuxi prepare`** after each step to regenerate types.

### Key Behavioral Changes

| Feature | Nuxt 3 | Nuxt 4 |
|---|---|---|
| Data reactivity | `ref` (deep) | `shallowRef` (shallow) |
| `useAsyncData` keys | Per-component | Global deduplication |
| Directory structure | Flat root | `app/` subdirectory |
| TypeScript configs | Single | Separate (app/server/shared) |
| `shared/` folder | N/A | Auto-imported isomorphic code |
| `definePageMeta` | Runtime eval | Static analysis (hoisted) |

### Common Migration Issues

- **Nested data mutations break:** `data.value.items[0].name = 'x'` no longer triggers updates. Replace with `data.value = { ...data.value }` or use `{ deep: true }` option.
- **Key collisions:** Two components using `useAsyncData('users', ...)` now share the same cache entry globally.
- **Module incompatibility:** Some modules may not support v4 yet. Check module documentation.
