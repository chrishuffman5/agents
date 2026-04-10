# Nuxt Data Fetching Patterns

> useFetch vs useAsyncData vs $fetch decision tree and SSR patterns. Last updated: 2026-04.

---

## 1. Decision Tree

```
Is this a simple HTTP fetch to a known URL?
|
+- YES -> Does the URL have reactive params?
|         +- YES -> useFetch('/api/path', { query: reactiveRef, watch: [reactiveRef] })
|         +- NO  -> useFetch('/api/path')
|
+- NO -> Is the source non-HTTP (DB, file, complex logic)?
          +- YES -> useAsyncData('unique-key', () => myAsyncFn())
          +- NO -> Need explicit cache key control?
                   +- YES -> useAsyncData('my-key', () => $fetch('/api/path'))
                   +- NO  -> useFetch('/api/path')

USE $fetch ONLY in:
  - Event handlers (button click, form submit)
  - server/api/ route handlers
  - onMounted with { server: false }

ADD lazy: true when data is not critical for initial render.
ADD pick/transform when API returns large objects (reduces HTML payload).
NEVER call $fetch at <script setup> top level for SSR data.
```

---

## 2. useFetch Patterns

### Basic

```ts
const { data, status, error, refresh } = await useFetch('/api/users')
```

### With Options

```ts
const { data } = await useFetch('/api/products', {
  method: 'GET',
  query: { page: currentPage.value, limit: 20 },
  pick: ['id', 'title', 'price'],     // reduce payload
  transform: (res) => res.products,    // unwrap response
  watch: [currentPage],               // re-fetch on change
  lazy: false,                         // block navigation (default)
  server: true,                        // run on server (default)
})
```

### Typed Response

```ts
interface User { id: number; name: string; email: string }

const { data } = await useFetch<User[]>('/api/users')
// data.value is Ref<User[] | null>
```

### Conditional Fetch

```ts
const { data, refresh } = await useFetch('/api/profile', {
  server: false,       // client-only
  lazy: true,          // non-blocking
  immediate: false,    // don't fetch on mount
})

// Manually trigger when needed
async function loadProfile() {
  await refresh()
}
```

---

## 3. useAsyncData Patterns

### Custom Async Logic

```ts
const { data } = await useAsyncData('dashboard-stats', async () => {
  const [users, revenue, orders] = await Promise.all([
    $fetch('/api/stats/users'),
    $fetch('/api/stats/revenue'),
    $fetch('/api/stats/orders'),
  ])
  return { users, revenue, orders }
})
```

### Reactive Key

```ts
const { data } = await useAsyncData(
  () => `user-${userId.value}`,          // key as function = reactive
  () => $fetch(`/api/users/${userId.value}`)
)
```

### With Transform and Watch

```ts
const { data } = await useAsyncData(
  'filtered-products',
  () => $fetch('/api/products', { query: { category: category.value } }),
  {
    watch: [category],
    transform: (products) => products.filter(p => p.inStock),
  }
)
```

---

## 4. Parallel Fetches

```ts
const [{ data: user }, { data: posts }, { data: comments }] = await Promise.all([
  useFetch('/api/user'),
  useFetch('/api/posts'),
  useFetch('/api/comments'),
])
```

---

## 5. Error Handling

### Client-Side

```ts
const { data, error } = await useFetch('/api/users')

// error.value shape: { statusCode, statusMessage, data }
```

```vue
<template>
  <div v-if="error" class="error">
    <p>{{ error.statusCode }}: {{ error.statusMessage }}</p>
    <button @click="refresh()">Retry</button>
  </div>
  <div v-else-if="data">
    <!-- render data -->
  </div>
</template>
```

### Server-Side Errors

```ts
// server/api/users.get.ts
export default defineEventHandler(async () => {
  const users = await db.users.findMany()
  if (!users.length) {
    throw createError({
      statusCode: 404,
      statusMessage: 'No users found',
      data: { hint: 'Check your database connection' }
    })
  }
  return users
})
```

---

## 6. Caching and Revalidation

### Manual Refresh

```ts
const { data, refresh } = await useFetch('/api/notifications')

// Refresh on user action
async function markRead(id: number) {
  await $fetch(`/api/notifications/${id}`, { method: 'PATCH' })
  await refresh()
}
```

### Key-Based Cache Busting

```ts
const { data } = await useAsyncData(
  () => `products-${category.value}-${page.value}`,
  () => $fetch('/api/products', { query: { category: category.value, page: page.value } })
)
// New key = new fetch; old cache entry kept until garbage collected
```

---

## 7. SSR-Safe State

### useState vs ref

```ts
// BAD -- ref initializes independently on server and client
const count = ref(0)

// GOOD -- useState transfers via SSR payload
const count = useState('counter', () => 0)
```

### Shared Composable State

```ts
// composables/useAuth.ts
export const useAuth = () => {
  const user = useState<User | null>('auth-user', () => null)
  const isLoggedIn = computed(() => !!user.value)

  async function login(credentials: LoginInput) {
    user.value = await $fetch('/api/auth/login', {
      method: 'POST', body: credentials
    })
  }

  async function logout() {
    await $fetch('/api/auth/logout', { method: 'POST' })
    user.value = null
  }

  return { user, isLoggedIn, login, logout }
}
```
