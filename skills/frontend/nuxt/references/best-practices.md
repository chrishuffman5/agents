# Nuxt Best Practices Reference

> Covers data fetching patterns, server routes, deployment, and module development. Last updated: 2026-04.

---

## 1. Data Fetching Patterns

### Avoid Double-Fetch (The #1 SSR Mistake)

```ts
// BAD -- fetches on server AND again on client
const data = ref(null)
onMounted(async () => { data.value = await $fetch('/api/users') })

// GOOD -- fetches once on server; result transferred in payload
const { data } = await useFetch('/api/users')
```

### Reduce Payload with pick/transform

```ts
const { data } = await useFetch('/api/products', {
  pick: ['id', 'title', 'price'],   // only these fields in HTML payload
  transform: (res) => res.products   // unwrap wrapper object
})
```

### Error Handling

```ts
const { data, error } = await useFetch('/api/users')
// error.value = { statusCode, statusMessage, data }

// Server-side: throw typed errors
throw createError({ statusCode: 404, statusMessage: 'Not found', data: { id } })
```

### SSR-Safe Shared State

Use `useState`, not `ref`, for cross-component shared state:

```ts
// composables/useCounter.ts
export const useCounter = () => useState('counter', () => 0)
// Same key = same reactive ref; included in SSR payload
```

### Lazy Mode

```ts
const { data, status } = await useFetch('/api/analytics', { lazy: true })
// Does not block navigation; check status === 'pending' for skeleton
```

### Refresh and Invalidation

```ts
const { data, refresh } = await useFetch('/api/notifications')

// Manual refresh
await refresh()

// Watch-based refresh
const { data } = await useFetch('/api/items', { watch: [category] })
```

---

## 2. Server Route Best Practices

### Recommended Structure

```
server/
  api/users/
    index.get.ts   index.post.ts   [id].get.ts   [id].put.ts   [id].delete.ts
  middleware/
    01.cors.ts   02.auth.ts
  plugins/
    database.ts     <- runs once at startup (defineNitroPlugin)
  utils/
    db.ts           <- auto-imported in all server/ files
```

### Validation with Zod

```ts
// server/api/posts/[id].put.ts
import { z } from 'zod'

const BodySchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
  published: z.boolean().optional().default(false),
})

export default defineEventHandler(async (event) => {
  const params = await getValidatedRouterParams(event, z.object({
    id: z.string().regex(/^\d+$/).transform(Number)
  }).parse)

  const body = await readValidatedBody(event, BodySchema.parse)

  return await db.posts.update({
    where: { id: params.id },
    data: body
  })
})
```

### Validation Utilities

| Utility | Purpose |
|---|---|
| `getValidatedRouterParams(event, fn)` | Validate `:param` path segments |
| `getValidatedQuery(event, fn)` | Validate `?query` string params |
| `readValidatedBody(event, fn)` | Validate parsed request body |
| `createError({ statusCode, statusMessage })` | Throw typed HTTP error |

### Nitro Storage (Universal KV)

```ts
export default defineEventHandler(async () => {
  const storage = useStorage('cache')
  await storage.setItem('key', { value: 123 }, { ttl: 60 })
  return await storage.getItem('key')
})
```

Configure driver: `nitro: { storage: { cache: { driver: 'redis', url: process.env.REDIS_URL } } }`.

### Server Plugin

```ts
// server/plugins/database.ts
export default defineNitroPlugin(async (nitroApp) => {
  const db = await connectDatabase()
  nitroApp.hooks.hook('close', () => db.disconnect())
})
```

---

## 3. Deployment

### Rendering Modes

| Mode | When to use | Command |
|---|---|---|
| SSR | Auth, personalization, dynamic data | `nuxi build` |
| Static (SSG) | Marketing, docs, infrequent updates | `nuxi generate` |
| Hybrid | Mix of static + dynamic per route | `nuxi build` + routeRules |
| SPA | Client-only, no SEO | `ssr: false` |

### Node.js Production

```bash
nuxi build
node .output/server/index.mjs
```

### Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY .output .output
ENV PORT=3000
CMD ["node", ".output/server/index.mjs"]
```

### Platform-Specific

**Vercel/Netlify/Cloudflare:** Zero-config with auto-detected presets. For edge runtime, set preset explicitly:

```ts
nitro: { preset: 'vercel-edge' }
// or 'netlify-edge', 'cloudflare-pages'
```

### Environment Variables

- Runtime: `NUXT_*` prefix overrides `runtimeConfig` keys at startup
- Build-time: standard `process.env` in `nuxt.config.ts`
- Client-side: only `runtimeConfig.public` values are exposed

---

## 4. Module Development

### Structure

```
my-nuxt-module/
  src/
    module.ts               <- defineNuxtModule entry
    runtime/
      components/  composables/  server/api/  plugins/
  playground/               <- test Nuxt app
  package.json
```

Use `nuxt-module-build`: `"build": "nuxt-module-build build"`.

### Runtime Config Pattern

```ts
// In setup():
nuxt.options.runtimeConfig.public.myModule = defu(
  nuxt.options.runtimeConfig.public.myModule, { apiUrl: options.apiUrl }
)
// In runtime composable:
export const useMyModule = () => useRuntimeConfig().public.myModule
```

### Key Hooks

```ts
nuxt.hook('pages:extend', (pages) => {
  pages.push({ name: 'custom', path: '/custom', file: '...' })
})
nuxt.hook('components:dirs', (dirs) => {
  dirs.push({ path: resolver.resolve('./runtime/components') })
})
nuxt.hook('nitro:config', (nitroConfig) => {
  /* mutate Nitro config */
})
```

---

## 5. Performance

### Payload Optimization

- Use `pick` to whitelist fields from API responses
- Use `transform` to unwrap nested objects
- Large payloads slow SSR-to-client transfer and increase HTML size

### Code Splitting

- Pages are automatically code-split
- Use `defineAsyncComponent` for heavy non-page components
- Lazy-load modules that are not needed on every page

### Caching

```ts
routeRules: {
  '/api/public/**': { cache: { maxAge: 60 } },       // CDN cache
  '/api/user/**': { cache: false },                    // never cache
  '/blog/**': { isr: 3600 },                           // revalidate hourly
}
```

### Pre-rendering

Pre-render all static pages at build time:

```ts
routeRules: {
  '/': { prerender: true },
  '/about': { prerender: true },
  '/blog/**': { prerender: true },
}
```

Or use `nuxi generate` to pre-render the entire site.
