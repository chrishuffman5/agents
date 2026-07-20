# Vue.js Best Practices Reference

> Covers composable design, Pinia patterns, TypeScript integration, performance, and testing. Last updated: 2026-04.

---

## 1. Composable Design

### Principles

1. **Return refs, not raw values** -- Callers can destructure without losing reactivity.
2. **Accept `MaybeRefOrGetter<T>` parameters** -- Works with refs, getters, or raw values.
3. **Clean up side effects** -- Use `onUnmounted` or return a `stop` function.
4. **Use `effectScope`** for grouping cleanup in long-lived composables.
5. **Prefix with `use`** -- Convention that signals reactive composition.

```ts
import { ref, watch, toValue, type MaybeRefOrGetter } from 'vue'

export function useLocalStorage<T>(key: string, initialValue: T) {
  const stored = localStorage.getItem(key)
  const data = ref<T>(stored ? JSON.parse(stored) : initialValue)

  watch(data, (val) => {
    localStorage.setItem(key, JSON.stringify(val))
  }, { deep: true })

  return data
}
```

### Composable Composition

Composables can call other composables. Build complex behavior by composing small, focused pieces:

```ts
export function useSearchableList<T>(items: MaybeRefOrGetter<T[]>, searchFields: (keyof T)[]) {
  const { query, debouncedQuery } = useDebounce('', 300)
  const filtered = computed(() => {
    const q = debouncedQuery.value.toLowerCase()
    if (!q) return toValue(items)
    return toValue(items).filter(item =>
      searchFields.some(f => String(item[f]).toLowerCase().includes(q))
    )
  })
  const { currentItems, currentPage, totalPages, next, prev } = usePagination(filtered)
  return { query, filtered, currentItems, currentPage, totalPages, next, prev }
}
```

---

## 2. Pinia Best Practices

### Setup Stores (Preferred)

Setup syntax provides full TypeScript inference and composable compatibility:

```ts
export const useProductStore = defineStore('products', () => {
  // State
  const items = ref<Product[]>([])
  const loading = ref(false)

  // Getters
  const sorted = computed(() => [...items.value].sort((a, b) => a.name.localeCompare(b.name)))

  // Actions
  async function fetchProducts() {
    loading.value = true
    try {
      items.value = await $fetch('/api/products')
    } finally {
      loading.value = false
    }
  }

  function $reset() {
    items.value = []
    loading.value = false
  }

  return { items, loading, sorted, fetchProducts, $reset }
})
```

### Reactive Destructuring

```ts
import { storeToRefs } from 'pinia'
const store = useProductStore()
const { items, sorted } = storeToRefs(store)     // reactive refs
const { fetchProducts } = store                   // actions (not reactive)
```

### Store Composition

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

  return { cartItems, total }
})
```

### SSR Hydration

```ts
// Server: serialize state
const pinia = createPinia()
app.use(pinia)
const state = pinia.state.value      // plain object, JSON-safe

// Client: hydrate
pinia.state.value = window.__PINIA_STATE__
```

---

## 3. TypeScript Integration

### Project Setup

- Use `vue-tsc` for type checking (replaces `tsc` for `.vue` files).
- Install Volar extension in VS Code for SFC IntelliSense.
- Set `"moduleResolution": "Bundler"` in tsconfig for Vite compatibility.
- Set `"verbatimModuleSyntax": true` to enforce `import type` for type-only imports.

### Type Patterns

```ts
// Typed injection keys
import type { InjectionKey, Ref } from 'vue'
export const ThemeKey: InjectionKey<Ref<string>> = Symbol('theme')

// Generic components (3.3+)
// <script setup lang="ts" generic="T extends { id: number }">
const props = defineProps<{ items: T[]; selected: T }>()

// Global component type registration
declare module 'vue' {
  interface GlobalComponents {
    MyButton: typeof import('@/components/MyButton.vue').default
  }
}
```

---

## 4. Performance Optimization

### shallowRef and shallowReactive

```ts
import { shallowRef, shallowReactive, triggerRef } from 'vue'

// shallowRef -- only .value assignment is reactive
const bigList = shallowRef<Item[]>([])
bigList.value = newList           // triggers
bigList.value.push(item)          // does NOT trigger
triggerRef(bigList)               // force trigger after mutation

// shallowReactive -- only top-level keys are reactive
const state = shallowReactive({ meta: { page: 1 } })
state.meta = { page: 2 }         // triggers
state.meta.page = 2              // does NOT trigger
```

### Computed Caching

```ts
// computed caches based on reactive dependencies
const sorted = computed(() => [...items.value].sort(compareFn))
// Only re-evaluates when items.value changes

// Anti-pattern: method in template (re-runs every render)
// <div>{{ sortItems() }}</div>  // BAD -- recalculates on every render
// <div>{{ sorted }}</div>       // GOOD -- cached
```

### v-memo for Large Lists

```html
<TransactionRow
  v-for="tx in transactions"
  :key="tx.id"
  v-memo="[tx.status, tx.amount]"
  :tx="tx"
/>
<!-- Row skips patching unless status or amount changed -->
```

### Lazy Hydration (3.5)

Defer hydration of non-critical components in SSR:

```ts
const LazyChart = defineAsyncComponent({
  loader: () => import('./HeavyChart.vue'),
  hydrate: hydrateOnVisible()         // hydrate when scrolled into view
})

const LazyFooter = defineAsyncComponent({
  loader: () => import('./Footer.vue'),
  hydrate: hydrateOnIdle()            // hydrate during browser idle time
})
```

### Component Splitting

- Use `defineAsyncComponent` for route-level and heavy components.
- Avoid over-splitting small components (network overhead outweighs render cost).
- Use `<KeepAlive>` to cache stateful components across route changes.

---

## 5. Testing

### Setup: Vitest + @vue/test-utils

```bash
npm install -D vitest @vue/test-utils @vitejs/plugin-vue jsdom happy-dom
```

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
    globals: true,
  },
})
```

### Component Testing

```ts
import { describe, it, expect, vi } from 'vitest'
import { mount } from '@vue/test-utils'
import MyButton from '@/components/MyButton.vue'

describe('MyButton', () => {
  it('renders slot content', () => {
    const wrapper = mount(MyButton, { slots: { default: 'Click me' } })
    expect(wrapper.text()).toBe('Click me')
  })

  it('emits click event', async () => {
    const wrapper = mount(MyButton)
    await wrapper.trigger('click')
    expect(wrapper.emitted('click')).toHaveLength(1)
  })
})
```

### Composable Testing

```ts
import { useFetch } from '@/composables/useFetch'
import { ref, nextTick } from 'vue'

describe('useFetch', () => {
  beforeEach(() => { vi.stubGlobal('fetch', vi.fn()) })

  it('fetches data', async () => {
    vi.mocked(fetch).mockResolvedValue({
      json: () => Promise.resolve({ id: 1 })
    } as Response)

    const { data, loading } = useFetch('/api/item')
    expect(loading.value).toBe(true)
    await nextTick()
    await nextTick()
    expect(data.value).toEqual({ id: 1 })
  })
})
```

### Pinia in Tests

```ts
import { createPinia, setActivePinia } from 'pinia'

beforeEach(() => {
  setActivePinia(createPinia())   // fresh Pinia per test
})
```

---

## 6. Accessibility

### Form Labels with useId

```ts
const id = useId()
```
```html
<label :for="id">Email</label>
<input :id="id" type="email" />
```

### ARIA Patterns

```html
<button :aria-expanded="isOpen" :aria-controls="panelId" @click="toggle">
  {{ isOpen ? 'Close' : 'Open' }}
</button>
<div :id="panelId" v-show="isOpen" role="region">
  <!-- panel content -->
</div>
```

### Focus Management

```ts
const dialogRef = useTemplateRef<HTMLDialogElement>('dialog')

function openDialog() {
  dialogRef.value?.showModal()
}
```
