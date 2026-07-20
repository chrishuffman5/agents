# Nuxt Server Route Patterns

> Nitro API routes with validation, auth, and typed responses. Last updated: 2026-04.

---

## 1. Route Structure

```
server/
  api/
    users/
      index.get.ts       -> GET  /api/users
      index.post.ts      -> POST /api/users
      [id].get.ts        -> GET  /api/users/:id
      [id].put.ts        -> PUT  /api/users/:id
      [id].delete.ts     -> DELETE /api/users/:id
  routes/
    sitemap.xml.ts       -> GET /sitemap.xml (no /api prefix)
    health.ts            -> GET /health
  middleware/
    01.cors.ts           -> runs on every request (ordered by prefix)
    02.auth.ts
  plugins/
    database.ts          -> runs once at startup (defineNitroPlugin)
  utils/
    db.ts                -> auto-imported in all server/ files
```

---

## 2. Basic Handlers

### GET with Query Parameters

```ts
// server/api/users.get.ts
export default defineEventHandler(async (event) => {
  const { page = '1', limit = '20' } = getQuery(event)
  const users = await db.users.findMany({
    skip: (Number(page) - 1) * Number(limit),
    take: Number(limit),
  })
  return users
})
```

### POST with Body

```ts
// server/api/users.post.ts
export default defineEventHandler(async (event) => {
  const body = await readBody(event)
  const user = await db.users.create({ data: body })
  setResponseStatus(event, 201)
  return user
})
```

---

## 3. Validated Route (Production Pattern)

```ts
// server/api/posts/[id].put.ts
import { z } from 'zod'

const ParamsSchema = z.object({
  id: z.string().regex(/^\d+$/).transform(Number)
})

const BodySchema = z.object({
  title: z.string().min(1).max(200),
  content: z.string().min(1),
  published: z.boolean().optional().default(false),
  tags: z.array(z.string()).max(10).optional().default([])
})

export default defineEventHandler(async (event) => {
  // 1. Validate params
  const params = await getValidatedRouterParams(event, ParamsSchema.parse)

  // 2. Validate body
  const body = await readValidatedBody(event, BodySchema.parse)

  // 3. Auth check
  const session = await getUserSession(event)
  if (!session?.user) {
    throw createError({ statusCode: 401, statusMessage: 'Unauthorized' })
  }

  // 4. Ownership check
  const existing = await db.posts.findUnique({ where: { id: params.id } })
  if (!existing) throw createError({ statusCode: 404, statusMessage: 'Not found' })
  if (existing.authorId !== session.user.id) {
    throw createError({ statusCode: 403, statusMessage: 'Forbidden' })
  }

  // 5. Update
  return await db.posts.update({
    where: { id: params.id },
    data: { ...body, updatedAt: new Date() }
  })
})
```

---

## 4. Server Middleware

```ts
// server/middleware/02.auth.ts
export default defineEventHandler((event) => {
  // Skip non-protected routes
  if (!event.path.startsWith('/api/protected')) return

  const token = getHeader(event, 'Authorization')?.replace('Bearer ', '')
  if (!token) {
    throw createError({ statusCode: 401, statusMessage: 'Missing token' })
  }

  try {
    const payload = verifyJwt(token)
    event.context.user = payload
  } catch {
    throw createError({ statusCode: 401, statusMessage: 'Invalid token' })
  }
})
```

---

## 5. Server Plugins

```ts
// server/plugins/database.ts
export default defineNitroPlugin(async (nitroApp) => {
  const db = await connectDatabase(process.env.DATABASE_URL)

  // Make available via event.context or global
  nitroApp.hooks.hook('request', (event) => {
    event.context.db = db
  })

  // Cleanup on shutdown
  nitroApp.hooks.hook('close', () => db.disconnect())
})
```

---

## 6. Nitro Storage (Universal KV)

```ts
// server/api/cache/[key].get.ts
export default defineEventHandler(async (event) => {
  const { key } = getRouterParams(event)
  const storage = useStorage('cache')
  return await storage.getItem(key)
})

// server/api/cache/[key].put.ts
export default defineEventHandler(async (event) => {
  const { key } = getRouterParams(event)
  const body = await readBody(event)
  const storage = useStorage('cache')
  await storage.setItem(key, body, { ttl: 3600 })
  return { ok: true }
})
```

Configure storage driver in `nuxt.config.ts`:
```ts
nitro: {
  storage: {
    cache: { driver: 'redis', url: process.env.REDIS_URL }
  }
}
```
