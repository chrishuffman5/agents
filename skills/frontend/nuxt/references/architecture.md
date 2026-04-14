# Nuxt Architecture Reference

> Covers Nuxt 3.x and 4.x. Last updated: 2026-04.

---

## 1. Nitro Server Engine

Nitro is the server engine bundled with Nuxt. It compiles server code into a single deployable output with zero external runtime dependencies (`.output/`), portable across 15+ hosting targets.

### H3 -- The HTTP Framework

Every handler is an H3 event handler:

```ts
// server/api/hello.get.ts
export default defineEventHandler(async (event) => {
  const query = getQuery(event)
  const body = await readBody(event)
  return { message: `Hello ${query.name}` }
})
```

Key H3 utilities: `getQuery`, `readBody`, `getHeaders`, `getCookie`, `setCookie`, `sendRedirect`, `createError`, `setResponseStatus`.

### Server Routes

Files in `server/api/` and `server/routes/` are auto-registered. HTTP method is inferred from filename suffix:

```
server/
  api/
    users.get.ts          -> GET  /api/users
    users.post.ts         -> POST /api/users
    users/[id].get.ts     -> GET  /api/users/:id
    users/[id].delete.ts  -> DELETE /api/users/:id
  routes/
    sitemap.xml.ts        -> GET /sitemap.xml (no /api prefix)
  middleware/
    auth.ts               -> runs on every request
```

### Server Middleware

```ts
// server/middleware/auth.ts
export default defineEventHandler((event) => {
  const token = getHeader(event, 'Authorization')
  if (!token && event.path.startsWith('/api/protected')) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }
})
```

Prefix with numbers for deterministic order: `01.log.ts`, `02.auth.ts`.

### Deployment Presets

| Preset | Notes |
|---|---|
| `node` | Default Node.js server |
| `vercel` / `vercel-edge` | Auto-detected on Vercel |
| `cloudflare-pages` | CF Pages + Workers |
| `netlify` / `netlify-edge` | Auto-detected on Netlify |
| `aws-lambda` | AWS Lambda |
| `azure-functions` | Azure |
| `deno-server` | Deno runtime |
| `bun` | Bun runtime |
| `static` | Pre-rendered static files |

```ts
nitro: { preset: 'cloudflare-pages' }
```

### routeRules -- Hybrid Rendering

Mix SSR, SSG, ISR, and SPA per route:

```ts
routeRules: {
  '/':             { prerender: true },
  '/blog/**':      { isr: 60 },
  '/dashboard/**': { ssr: true },
  '/account/**':   { ssr: false },
  '/api/**':       { cors: true, headers: { 'cache-control': 's-maxage=60' } },
  '/old-page':     { redirect: '/new-page' }
}
```

`isr` requires a compatible preset (Vercel, Cloudflare, Netlify).

---

## 2. Auto-Imports

Nuxt scans specific directories and makes exports globally available -- no `import` statements needed.

| Source | What is imported |
|---|---|
| `components/` | Vue SFCs as components |
| `composables/` | All named/default exports |
| `utils/` | All named/default exports |
| Nuxt core | `useFetch`, `useState`, `useRoute`, `navigateTo`, etc. |
| Vue core | `ref`, `reactive`, `computed`, `watch`, `onMounted`, etc. |

**Component naming:** `components/base/Button.vue` becomes `<BaseButton>` (path flattened to PascalCase).

**Extend or disable:**
```ts
imports: {
  dirs: ['stores/**'],   // add extra scan paths
  autoImport: false      // disable globally
}
```

Run `nuxi prepare` to regenerate `.nuxt/types/` for IDE auto-completion.

---

## 3. File-Based Routing

```
pages/
  index.vue              -> /
  about.vue              -> /about
  blog/[slug].vue        -> /blog/:slug
  blog/[...path].vue     -> /blog/* (catch-all)
  users/[id]/index.vue   -> /users/:id
  [[...opt]].vue         -> optional catch-all
```

**Nested Layouts:**
```vue
<!-- pages/dashboard.vue -->
<script setup>
definePageMeta({ layout: 'admin' })
</script>
```
```vue
<!-- layouts/admin.vue -->
<template>
  <div class="admin-shell"><AdminSidebar /><slot /></div>
</template>
```

**Route Groups (v4):** Wrap directory in parentheses to group without affecting URL:
```
pages/(marketing)/index.vue   -> /
pages/(app)/dashboard.vue     -> /dashboard
```

**Route Middleware:**
```ts
// middleware/auth.ts
export default defineNuxtRouteMiddleware((to) => {
  const user = useSupabaseUser()
  if (!user.value) return navigateTo('/login')
})
```
Apply with `definePageMeta({ middleware: ['auth'] })`. Global middleware: suffix `.global.ts`.

---

## 4. Data Fetching

### The Three Options

| | `useFetch` | `useAsyncData` | `$fetch` |
|---|---|---|---|
| SSR dedup | Yes | Yes | No |
| Reactive key | URL string (auto) | Explicit key arg | N/A |
| Best for | Simple URL fetches | Custom async logic | Mutations, event handlers |

### useFetch

```ts
const { data, status, error, refresh } = await useFetch('/api/users', {
  method: 'GET',
  query: { page: 1 },
  lazy: false,
  server: true,
  pick: ['id', 'name'],
  transform: (res) => res.users,
  watch: [currentPage]
})
```

### useAsyncData

```ts
const { data: user } = await useAsyncData(
  'user-profile',
  () => $fetch(`/api/users/${userId.value}`),
  { watch: [userId], transform: (u) => u }
)
```

Reactive key as function (re-fetches when `userId` changes):
```ts
useAsyncData(
  () => `user-${userId.value}`,
  () => $fetch(`/api/users/${userId.value}`)
)
```

### $fetch

Use in event handlers or mutations -- no SSR deduplication:
```ts
async function submitForm() {
  await $fetch('/api/contact', { method: 'POST', body: formData.value })
}
```

### Parallel Fetches

```ts
const [{ data: user }, { data: posts }] = await Promise.all([
  useFetch('/api/user'),
  useFetch('/api/posts')
])
```

---

## 5. Modules Ecosystem

### defineNuxtModule

```ts
export default defineNuxtModule<ModuleOptions>({
  meta: { name: 'my-module', configKey: 'myModule', compatibility: { nuxt: '>=3.0.0' } },
  defaults: { apiUrl: '/api' },
  async setup(options, nuxt) {
    const resolver = createResolver(import.meta.url)
    addComponent({ name: 'MyWidget', filePath: resolver.resolve('./runtime/components/MyWidget.vue') })
    addImports({ name: 'useMyThing', from: resolver.resolve('./runtime/composables/useMyThing') })
    addServerHandler({ route: '/api/endpoint', handler: resolver.resolve('./runtime/server/api/endpoint.ts') })
  }
})
```

### Notable Modules

| Module | Package | Purpose |
|---|---|---|
| Image | `@nuxt/image` | Responsive images, multi-provider optimization |
| Content | `@nuxt/content` | File-based CMS with MDC and querying |
| UI | `@nuxt/ui` | Component library (Tailwind + Radix) |
| Auth | `@sidebase/nuxt-auth` | Auth.js integration |
| i18n | `@nuxtjs/i18n` | Internationalization with Vue I18n |
| Pinia | `@pinia/nuxt` | State management |
| Color Mode | `@nuxtjs/color-mode` | Dark/light mode, no flash |

---

## 6. Runtime Config

```ts
// nuxt.config.ts
runtimeConfig: {
  databaseUrl: process.env.DATABASE_URL,   // server-only
  jwtSecret: process.env.JWT_SECRET,
  public: {
    apiBase: process.env.NUXT_PUBLIC_API_BASE || '/api',
    appTitle: 'My App'
  }
}
```

Server-only keys are never exposed to the client bundle. Public keys are available everywhere via `useRuntimeConfig().public`.

Environment variables prefixed with `NUXT_` override matching `runtimeConfig` keys at runtime (e.g., `NUXT_DATABASE_URL` overrides `runtimeConfig.databaseUrl`).

---

## 7. Nuxt DevTools

Enable: `devtools: { enabled: true }`. Appears at bottom of browser in dev mode.

| Panel | Purpose |
|---|---|
| Pages | All routes, middleware, layout assignments |
| Components | Inspector overlay -- hover to see source, props, slots |
| Imports | All auto-imports: name, source, used/unused status |
| Payload | SSR payload: `useAsyncData` keys and serialized values |
| Runtime Config | View/edit `runtimeConfig` live |
| Performance | Component render times, hydration cost |
| Terminal | Embedded nuxi command runner |

Set `NUXT_DEVTOOLS_OPEN_IN_EDITOR=vscode` in `.env` for one-click "open in editor".

---

## 8. SSR and Hydration

### SSR-Safe State

Use `useState` instead of `ref` for state that must survive SSR-to-client transfer:

```ts
// composables/useCounter.ts
export const useCounter = () => useState('counter', () => 0)
// Same key = same reactive ref on server and client; included in SSR payload
```

### ClientOnly

```vue
<ClientOnly>
  <BrowserOnlyComponent />
  <template #fallback>Loading...</template>
</ClientOnly>
```

### Conditional Server/Client Code

```ts
if (import.meta.server) { /* server-only code */ }
if (import.meta.client) { /* client-only code */ }
```
