# Pinia State Management Patterns

> Store patterns, SSR hydration, DevTools integration, testing. Last updated: 2026-04.

---

## 1. Store Patterns

### Setup Store (Preferred)

Setup syntax provides full TypeScript inference and composable compatibility:

```ts
// stores/products.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

interface Product { id: number; name: string; price: number; category: string }

export const useProductStore = defineStore('products', () => {
  // -- State --
  const items = ref<Product[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)
  const selectedCategory = ref<string | null>(null)

  // -- Getters (computed) --
  const filtered = computed(() =>
    selectedCategory.value
      ? items.value.filter(p => p.category === selectedCategory.value)
      : items.value
  )

  const categories = computed(() =>
    [...new Set(items.value.map(p => p.category))].sort()
  )

  const totalValue = computed(() =>
    filtered.value.reduce((sum, p) => sum + p.price, 0)
  )

  // -- Actions --
  async function fetchProducts() {
    loading.value = true
    error.value = null
    try {
      const res = await fetch('/api/products')
      if (!res.ok) throw new Error(res.statusText)
      items.value = await res.json()
    } catch (e) {
      error.value = (e as Error).message
    } finally {
      loading.value = false
    }
  }

  function setCategory(cat: string | null) {
    selectedCategory.value = cat
  }

  function $reset() {
    items.value = []
    loading.value = false
    error.value = null
    selectedCategory.value = null
  }

  return {
    items, loading, error, selectedCategory,
    filtered, categories, totalValue,
    fetchProducts, setCategory, $reset,
  }
})
```

### Options Store (Alternative)

```ts
export const useCounterStore = defineStore('counter', {
  state: () => ({ count: 0, name: 'counter' }),
  getters: {
    doubleCount: (state) => state.count * 2,
  },
  actions: {
    increment() { this.count++ },
    async fetchAndSet(id: number) {
      this.count = await fetch(`/api/count/${id}`).then(r => r.json())
    },
  },
})
```

Options stores have a built-in `$reset()` method. Setup stores must implement it manually.

---

## 2. Reactive Destructuring

```ts
import { storeToRefs } from 'pinia'

const store = useProductStore()

// Reactive refs -- stays connected to store
const { items, filtered, loading } = storeToRefs(store)

// Actions -- destructure directly (not reactive, just functions)
const { fetchProducts, setCategory } = store
```

**Never destructure state/getters without `storeToRefs`** -- they lose reactivity.

---

## 3. Store Composition

Stores can use other stores:

```ts
export const useCartStore = defineStore('cart', () => {
  const products = useProductStore()
  const cartItems = ref<CartItem[]>([])

  const total = computed(() =>
    cartItems.value.reduce((sum, ci) => {
      const product = products.items.find(p => p.id === ci.productId)
      return sum + (product?.price ?? 0) * ci.quantity
    }, 0)
  )

  function addToCart(productId: number, quantity = 1) {
    const existing = cartItems.value.find(ci => ci.productId === productId)
    if (existing) {
      existing.quantity += quantity
    } else {
      cartItems.value.push({ productId, quantity })
    }
  }

  return { cartItems, total, addToCart }
})
```

---

## 4. SSR Hydration

### Server Side

```ts
import { createPinia } from 'pinia'

const pinia = createPinia()
app.use(pinia)

// After SSR rendering, serialize state
const piniaState = JSON.stringify(pinia.state.value)
// Inject into HTML: <script>window.__PINIA_STATE__ = ${piniaState}</script>
```

### Client Side

```ts
const pinia = createPinia()

// Hydrate before app.mount
if (window.__PINIA_STATE__) {
  pinia.state.value = JSON.parse(window.__PINIA_STATE__)
}

app.use(pinia)
app.mount('#app')
```

### Nuxt Integration

With `@pinia/nuxt` module, SSR hydration is automatic. No manual serialization needed.

```ts
// nuxt.config.ts
export default defineNuxtConfig({
  modules: ['@pinia/nuxt'],
})
```

---

## 5. Plugins

### Persistence Plugin

```ts
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)

// In store definition
export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(null)
  return { token }
}, {
  persist: true,   // persists to localStorage by default
})
```

### Custom Plugin

```ts
pinia.use(({ store }) => {
  // Add $log action to every store
  store.$log = () => console.log(JSON.stringify(store.$state, null, 2))

  // Subscribe to all mutations
  store.$subscribe((mutation, state) => {
    console.log(`[${store.$id}] ${mutation.type}`, mutation.events)
  })
})
```

---

## 6. DevTools Integration

Pinia integrates with Vue DevTools automatically:

- **State panel:** View and edit store state in real time
- **Getters panel:** See computed values and their dependencies
- **Timeline:** Action invocations with payloads and timing
- **Time travel:** Revert state to previous mutation snapshots

No additional configuration required. Works out of the box when Vue DevTools is installed.

---

## 7. Testing Pinia Stores

### Setup

```ts
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, it, expect, vi } from 'vitest'

beforeEach(() => {
  setActivePinia(createPinia())   // fresh Pinia instance per test
})
```

### Testing Actions

```ts
describe('useProductStore', () => {
  it('fetches products', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve([{ id: 1, name: 'Widget', price: 10, category: 'A' }])
    }))

    const store = useProductStore()
    await store.fetchProducts()

    expect(store.items).toHaveLength(1)
    expect(store.items[0].name).toBe('Widget')
    expect(store.loading).toBe(false)
  })
})
```

### Testing Getters

```ts
it('filters by category', () => {
  const store = useProductStore()
  store.items = [
    { id: 1, name: 'A', price: 10, category: 'tools' },
    { id: 2, name: 'B', price: 20, category: 'parts' },
  ]
  store.setCategory('tools')
  expect(store.filtered).toHaveLength(1)
  expect(store.filtered[0].name).toBe('A')
})
```

### Testing with Components

```ts
import { mount } from '@vue/test-utils'
import { createTestingPinia } from '@pinia/testing'

const wrapper = mount(ProductList, {
  global: {
    plugins: [createTestingPinia({
      initialState: {
        products: { items: [{ id: 1, name: 'Test', price: 5, category: 'x' }] }
      },
      stubActions: false,   // false = run real actions; true = stub all
    })],
  },
})
```
