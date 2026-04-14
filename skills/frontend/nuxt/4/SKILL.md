---
name: frontend-nuxt-4
description: "Expert agent for Nuxt 4. Covers the app/ directory structure, shared/ folder for isomorphic code, separate TypeScript configs (app/server/shared), shallowRef as default for data fetching, global useAsyncData key deduplication, useId, useRouteAnnouncer, route groups, type-safe runtimeConfig, and migration from Nuxt 3. WHEN: \"Nuxt 4\", \"Nuxt 4.x\", \"app/ directory Nuxt\", \"shared/ folder Nuxt\", \"shallowRef Nuxt\", \"Nuxt 4 migration\", \"Nuxt 4 upgrade\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Nuxt 4 Specialist

You are a specialist in Nuxt 4 (current stable as of April 2026). Nuxt 4 restructures the project layout, introduces the `shared/` directory, defaults to shallow reactivity for data fetching, and provides separate TypeScript configurations for app, server, and shared code.

## app/ Directory Structure

Nuxt 4 moves application source into an `app/` subdirectory, clearly separating it from server code:

```
nuxt.config.ts                    <- root (unchanged)
server/                           <- server code (unchanged)
  api/  middleware/  plugins/  utils/
app/                              <- application code (NEW)
  pages/
  components/
  composables/
  layouts/
  middleware/
  plugins/
  app.vue
  error.vue
shared/                           <- isomorphic code (NEW)
  utils/
  types/
```

### Benefits

- Clear separation of client and server code
- Prevents accidental import of server code in client bundle
- Each directory has its own TypeScript configuration
- `server/` can have Node.js types; `app/` cannot import them

---

## shared/ Folder

Available in both `app/` and `server/`. Auto-imported like `composables/` and `utils/`.

**Rules:**
- No Vue-specific code (no `ref`, `computed`, `onMounted`)
- No Nitro-specific code (no `defineEventHandler`, `getQuery`)
- Pure isomorphic TypeScript only

```
shared/
  utils/format.ts       -> auto-imported everywhere
  types/index.ts        -> shared type definitions
  validators/schema.ts  -> Zod schemas usable on client and server
```

**Use cases:**
- Validation schemas (Zod) shared between forms and server routes
- Type definitions used by both client and server
- Pure utility functions (formatting, math, string manipulation)
- Constants and configuration shared across boundaries

---

## Separate TypeScript Configs

```
.nuxt/tsconfig.app.json      -> app/ directory types
.nuxt/tsconfig.server.json   -> server/ directory types
.nuxt/tsconfig.shared.json   -> shared/ directory types
tsconfig.json                -> root, extends app config
```

This prevents server types from leaking into client code. Server-specific types (`NodeJS.Process`, `H3Event`) are only available in `server/`. Client-specific types (`Window`, `Document`) are only available in `app/`.

---

## shallowRef for Data Fetching

Nuxt 4 uses `shallowRef` (not `ref`) for `useFetch`/`useAsyncData` data by default:

```ts
// Nuxt 3 -- deep reactive (ref)
data.value.users[0].name = 'Alice'     // triggers reactivity

// Nuxt 4 -- shallow reactive (shallowRef)
data.value.users[0].name = 'Alice'     // does NOT trigger update
data.value = { ...data.value }         // triggers update (replace top level)

// Override: opt into deep reactivity
const { data } = await useFetch('/api/users', { deep: true })
```

### Why the Change

- **Performance:** Shallow reactivity avoids deep proxy wrapping of large API responses
- **Predictability:** Encourages immutable update patterns
- **Alignment:** Matches how most data fetching works (replace, not mutate)

### Migration Pattern

```ts
// Before (Nuxt 3): direct mutation
data.value.items.push(newItem)

// After (Nuxt 4): immutable replacement
data.value = { ...data.value, items: [...data.value.items, newItem] }

// Or opt into deep reactivity
const { data } = await useFetch('/api/items', { deep: true })
data.value.items.push(newItem)   // works with deep: true
```

---

## Global useAsyncData Key Deduplication

In Nuxt 4, multiple components using the same `useAsyncData` key share a single request. The second call returns cached data without re-fetching.

```ts
// Component A
const { data } = await useAsyncData('users', () => $fetch('/api/users'))

// Component B (same key = shared data, no duplicate fetch)
const { data } = await useAsyncData('users', () => $fetch('/api/users'))
```

**Intentional:** For shared state across components.
**Accidental:** Use unique keys for unrelated data to avoid collisions.

---

## Route Groups

Wrap directory in parentheses to group routes without affecting URL:

```
app/pages/
  (marketing)/
    index.vue             -> /
    pricing.vue           -> /pricing
  (app)/
    dashboard.vue         -> /dashboard
    settings.vue          -> /settings
```

Groups organize code logically without adding URL segments.

---

## New APIs

### useId

Generates stable unique IDs for accessibility, safe across SSR and hydration:

```ts
const id = useId()
```
```html
<label :for="id">Email</label>
<input :id="id" type="email" />
```

### useRouteAnnouncer

Announces route changes to screen readers for accessibility:

```ts
const { message, politeness } = useRouteAnnouncer()
// Automatically announces page title on navigation
```

### Type-Safe runtimeConfig

Accessing undefined `runtimeConfig` keys is now a TypeScript error:

```ts
const config = useRuntimeConfig()
config.databaseUrl      // OK -- defined in nuxt.config.ts
config.undefinedKey      // TypeScript error
```

---

## definePageMeta (Static Analysis)

`definePageMeta` is hoisted and statically analyzed at build time. Avoid dynamic values:

```ts
// BAD -- dynamic values fail static analysis
definePageMeta({
  middleware: computed(() => isAdmin ? ['admin'] : []),  // ERROR
})

// GOOD -- static values
definePageMeta({
  middleware: ['auth'],
  layout: 'admin',
})

// For dynamic behavior, use useRoute() at runtime
const route = useRoute()
const isAdmin = computed(() => route.meta.roles?.includes('admin'))
```

---

## Quick Reference

### What Changed from Nuxt 3

| Feature | Nuxt 3 | Nuxt 4 |
|---|---|---|
| Source directory | Root (`pages/`, `components/`) | `app/` subdirectory |
| Isomorphic code | N/A | `shared/` directory |
| TypeScript | Single config | Separate app/server/shared |
| Data reactivity | `ref` (deep) | `shallowRef` (shallow) |
| `useAsyncData` keys | Per-component scope | Global deduplication |
| `definePageMeta` | Runtime evaluation | Static analysis (hoisted) |
| `runtimeConfig` types | Permissive | Strict (undefined = error) |
| Route groups | Not available | `(group)` directory syntax |
| `useId()` | Not available | Stable unique IDs |
| `useRouteAnnouncer()` | Not available | Screen reader announcements |

### Migration Checklist

1. Set `future: { compatibilityVersion: 4 }` in Nuxt 3 to test changes early
2. Move app source files into `app/` directory
3. Update `tsconfig.json` to extend `.nuxt/tsconfig.app.json`
4. Audit nested data mutations (shallowRef change)
5. Review all `useAsyncData` keys for collisions
6. Move shared isomorphic code to `shared/`
7. Remove dynamic values from `definePageMeta`
8. Update third-party modules for v4 compatibility
9. Run `nuxi prepare` after each step
