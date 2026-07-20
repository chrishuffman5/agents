# Vue.js Architecture Reference

> Covers Vue 3.4, 3.5 (stable), and 3.6 Vapor Mode (beta). Last updated: 2026-04.

---

## 1. Reactivity System

### Proxy-Based Foundation

Vue 3 replaces Vue 2's `Object.defineProperty` with ES Proxy. Every reactive object is wrapped in a Proxy that intercepts `get` (track) and `set`/`deleteProperty` (trigger).

```ts
import { ref, reactive, computed, watch, watchEffect } from 'vue'

// ref -- wraps primitives and objects in a ReactiveRef
const count = ref(0)             // { value: 0 } -- always accessed via .value in JS
count.value++                    // triggers effects
// In template: {{ count }} -- compiler auto-unwraps (no .value)

// reactive -- deep Proxy for plain objects
const state = reactive({ user: { name: 'Alice' }, items: [] })
state.user.name = 'Bob'         // deep tracking -- nested changes trigger effects

// computed -- lazy, cached derived value
const fullName = computed(() => `${state.user.first} ${state.user.last}`)
// Re-evaluates only when tracked deps change; .value returns cached result

// watch -- explicit side effects on reactive sources
watch(count, (newVal, oldVal) => { /* runs when count.value changes */ })
watch(() => state.user.name, (name) => { /* getter form for nested paths */ })
watch([count, () => state.user.name], ([c, n]) => { /* multi-source */ })

// watchEffect -- auto-tracks all reactive reads inside the callback
watchEffect(() => {
  console.log(count.value)       // auto-tracked; re-runs when count changes
})
```

### Dependency Tracking Internals

- **Track:** On reactive `get`, Vue records the current active effect into the dependency set of that property (stored in a `WeakMap<target, Map<key, Set<effect>>>`).
- **Trigger:** On reactive `set`, Vue iterates the dependency set and schedules each effect.
- **Effect scope:** `effectScope()` groups effects for bulk disposal (used internally by components).

### Effect Scheduling

Effects do not run synchronously on trigger. Vue batches them into a microtask queue (`Promise.resolve`). Multiple mutations in the same synchronous block produce one re-render. Use `nextTick()` to await DOM updates.

```ts
import { nextTick } from 'vue'
count.value++
count.value++         // only one re-render scheduled
await nextTick()      // DOM is now updated
```

### Vue 3.5 Reactivity Performance

Vue 3.5 ships a rewritten reactivity engine:
- **56% reduction** in memory usage for reactive objects.
- **~10x faster** array mutation tracking (`push`, `pop`, `splice`, `sort`, `reverse`).
- Achieved via a doubly-linked list for dependency tracking (no Set allocations per-effect per-dep).

---

## 2. Virtual DOM

### Template Compilation

`<template>` is compiled by `@vue/compiler-sfc` into a render function at build time (Vite) or at runtime (`vue.esm-bundler.js`). The compiler output uses `h()` calls (hyperscript) and optimized patch flags.

```ts
// Source template:
// <div class="box">{{ msg }}</div>

// Compiled output (simplified):
import { createElementVNode, toDisplayString, openBlock, createElementBlock } from "vue"

export function render(_ctx) {
  return (openBlock(), createElementBlock("div", { class: "box" },
    toDisplayString(_ctx.msg), 1 /* TEXT */))
}
// Patch flag `1` tells the runtime: only text content can change, skip full diff.
```

### Patch Flags and Static Hoisting

The compiler emits **patch flags** (integers) on VNodes:

| Flag | Meaning |
|---|---|
| `1` | Dynamic text content |
| `2` | Dynamic class |
| `4` | Dynamic style |
| `8` | Dynamic props (named) |
| `16` | Dynamic props (any) |
| `32` | Hydration event handlers |
| `-1` | Static (never diffed) |
| `-2` | `v-once` subtree (hoisted once) |

**Static hoisting:** Nodes with no dynamic bindings are created once outside the render function and reused across renders, reducing VNode allocation.

### Patch Algorithm

The runtime VDOM diff uses a hybrid algorithm:

1. **Same-type element:** Diff children using keyed algorithm (longest-increasing-subsequence for minimal DOM moves).
2. **Different type:** Unmount old, mount new.
3. **Component:** Compare props/slots, schedule update if changed.

### v-once and v-memo

```html
<!-- v-once: render once, never diff again -->
<ExpensiveList v-once />

<!-- v-memo: re-render subtree only when listed deps change -->
<div v-for="item in list" :key="item.id" v-memo="[item.selected]">
  {{ item.name }}
</div>
<!-- Even if parent re-renders, row skips patching unless item.selected changed -->
```

---

## 3. Single-File Components (SFCs)

### Structure

```html
<script setup lang="ts">
// Compiler macros + component logic
</script>

<template>
  <!-- HTML-superset template -->
</template>

<style scoped>
/* CSS scoped to this component via data-v-xxxxxxxx attribute */
</style>
```

### `<script setup>`

- Syntactic sugar over `setup()` -- everything at top level is automatically returned to the template.
- No need to import `defineProps`, `defineEmits`, etc. -- they are compiler macros (not runtime functions).
- Top-level `await` is supported (component becomes async, wrap parent in `<Suspense>`).

### Compiler Macros

```ts
// defineProps -- typed props declaration
const props = defineProps<{
  title: string
  count?: number
  items: string[]
}>()
// With defaults (Vue 3.5 stable -- reactive destructure):
const { title, count = 0 } = defineProps<{ title: string; count?: number }>()

// defineEmits -- typed event declaration
const emit = defineEmits<{
  update: [value: string]       // tuple syntax (3.3+)
  close: []
}>()
emit('update', 'hello')

// defineModel -- two-way binding (stable in 3.4+)
const modelValue = defineModel<string>()
const count2 = defineModel<number>('count', { default: 0 })
// Parent: <MyInput v-model="text" /> or <Counter v-model:count="n" />

// defineExpose -- explicitly expose to parent refs
defineExpose({ focus, reset })

// defineSlots -- typed slot declarations
const slots = defineSlots<{
  default(props: { item: Item }): any
  header(): any
}>()
```

### Scoped Styles

```html
<style scoped>
/* Compiles to: .btn[data-v-xxxxxxxx] { } */
.btn { color: red; }

/* :deep() -- pierce into child component */
:deep(.child-class) { font-size: 14px; }

/* :slotted() -- style slotted content */
:slotted(p) { margin: 0; }

/* :global() -- escape scoping */
:global(body) { margin: 0; }
</style>
```

---

## 4. Composition API

### Lifecycle Hooks

```ts
import { onMounted, onUpdated, onUnmounted, onBeforeMount,
         onBeforeUpdate, onBeforeUnmount, onErrorCaptured,
         onActivated, onDeactivated } from 'vue'

// Execution order on mount:
// setup() -> onBeforeMount -> [DOM rendered] -> onMounted
// On update: onBeforeUpdate -> [DOM patched] -> onUpdated
// On unmount: onBeforeUnmount -> [teardown] -> onUnmounted
```

### Composables

Composables replace mixins and the Options API. A composable is a function that uses Composition API inside, conventionally prefixed with `use`.

```ts
import { ref, watchEffect, toValue, type MaybeRefOrGetter } from 'vue'

export function useFetch<T>(url: MaybeRefOrGetter<string>) {
  const data = ref<T | null>(null)
  const error = ref<Error | null>(null)
  const loading = ref(false)

  watchEffect(async () => {
    data.value = null
    error.value = null
    loading.value = true
    try {
      const res = await fetch(toValue(url))
      data.value = await res.json()
    } catch (e) {
      error.value = e as Error
    } finally {
      loading.value = false
    }
  })

  return { data, error, loading }
}
```

### provide / inject

```ts
// Parent component
import { provide, ref } from 'vue'
const theme = ref('dark')
provide('theme', theme)                        // provide reactive value
provide(ThemeKey, theme)                       // prefer Symbol keys for typing

// Child component (any depth)
import { inject } from 'vue'
const theme = inject('theme', ref('light'))    // with default
const theme2 = inject<Ref<string>>(ThemeKey)   // typed with Symbol key

// Typed injection key pattern:
import type { InjectionKey, Ref } from 'vue'
export const ThemeKey: InjectionKey<Ref<string>> = Symbol('theme')
```

---

## 5. Vapor Mode (3.6 Beta)

Vapor Mode is an opt-in compilation target that eliminates the Virtual DOM entirely for maximum performance.

### How It Works

Instead of creating VNodes and diffing them, the Vapor compiler generates direct DOM manipulation code. Reactive bindings map directly to DOM property updates via fine-grained effects. Uses the **Alien Signals** reactivity engine (a rewrite of `@vue/reactivity`) for even faster signal propagation.

### Requirements

- Component must use `<script setup>` (Composition API).
- Opt in per-component with the `vapor` compiler option.
- Not all Vue features are supported yet (complex slots, some directives in beta).

### Trade-offs

| | VDOM Mode | Vapor Mode |
|---|---|---|
| Bundle size | Slightly larger (runtime diff) | Smaller per-component |
| First paint | Fast | Faster |
| Update performance | Batch + diff | Fine-grained, no diff |
| Compatibility | Full Vue API | Composition API + script setup required |
| Status | Stable | 3.6 Beta |

### Usage (when stable)

```ts
// vite.config.ts (future API -- subject to change)
import vue from '@vitejs/plugin-vue'
export default {
  plugins: [vue({ vapor: true })]   // enable globally
}

// Per-component opt-in (proposed):
// <script setup vapor>
```

---

## 6. SSR and Hydration

### Server-Side Rendering

Vue supports streaming SSR via `renderToString` and `renderToNodeStream` (or `renderToWebStream`). Frameworks like Nuxt handle this automatically.

```ts
import { createSSRApp } from 'vue'
import { renderToString } from 'vue/server-renderer'

const app = createSSRApp(App)
const html = await renderToString(app)
```

### Hydration

Client-side Vue attaches event listeners and reactivity to server-rendered HTML without re-creating DOM nodes. Hydration mismatches (different server/client output) produce warnings and can cause UI bugs.

Common causes of mismatches:
- `Date.now()`, `Math.random()` during render
- Browser-only APIs (`window`, `localStorage`) in setup
- Conditional rendering based on client-only state

### data-allow-mismatch (Vue 3.5)

```html
<!-- Suppress hydration warnings for known safe mismatches -->
<time data-allow-mismatch="text">{{ formattedNow }}</time>
<!-- Values: "text" | "children" | "class" | "style" | "attribute" -->
```

### Lazy Hydration (Vue 3.5)

```ts
import { defineAsyncComponent, hydrateOnVisible, hydrateOnIdle,
         hydrateOnInteraction, hydrateOnMediaQuery } from 'vue'

const LazyChart = defineAsyncComponent({
  loader: () => import('./HeavyChart.vue'),
  hydrate: hydrateOnVisible()
})

const LazyFooter = defineAsyncComponent({
  loader: () => import('./Footer.vue'),
  hydrate: hydrateOnIdle()
})

const LazyModal = defineAsyncComponent({
  loader: () => import('./Modal.vue'),
  hydrate: hydrateOnInteraction(['click', 'focus'])
})
```

---

## 7. Vue Router Integration

### Route Configuration

```ts
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: () => import('./pages/Home.vue') },
    { path: '/user/:id', component: () => import('./pages/User.vue'), props: true },
    { path: '/:pathMatch(.*)*', component: () => import('./pages/NotFound.vue') },
  ],
})
```

### Navigation Guards

```ts
router.beforeEach(async (to, from) => {
  const auth = useAuthStore()
  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
})
```

### Composables

```ts
import { useRoute, useRouter } from 'vue-router'
const route = useRoute()          // reactive route object
const router = useRouter()        // programmatic navigation
```

---

## 8. Vue DevTools

### Features

- **Component tree inspector:** Browse hierarchy, view props/state/computed/emitted events
- **Reactivity inspector:** View dependency graph for reactive values
- **Pinia panel:** State, getters, action timeline with payloads
- **Timeline:** Event timeline for mutations, navigations, and performance marks
- **Performance:** Component render times, update frequency

### Configuration

```ts
// main.ts -- DevTools is automatically available in development
app.config.performance = true    // enable performance timing in DevTools
```
