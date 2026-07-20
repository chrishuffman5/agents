# Vue.js Diagnostics Reference

> Troubleshooting guide for reactivity pitfalls, template errors, and hydration mismatches. Last updated: 2026-04.

---

## 1. Reactivity Pitfalls

### Losing Reactivity via Destructuring

```ts
// PROBLEM: destructuring reactive loses reactivity
const state = reactive({ count: 0, name: 'Alice' })
const { count } = state           // count is a plain number -- NOT reactive

// FIX 1: use toRefs
const { count, name } = toRefs(state)   // Ref<number> -- reactive

// FIX 2: use ref instead of reactive
const count2 = ref(0)
// Never destructure ref.value -- always use count2.value directly
```

### ref vs reactive Confusion

```ts
// ref requires .value in script, auto-unwrapped in template
const msg = ref('hello')
msg.value = 'world'               // JS -- .value required
// <p>{{ msg }}</p>                // template -- no .value

// reactive does NOT need .value
const form = reactive({ email: '', password: '' })
form.email = 'a@b.com'

// Mixing: reactive wrapping a ref auto-unwraps
const state = reactive({ msg })    // state.msg is 'hello', not { value: 'hello' }

// PITFALL: ref inside ref does NOT auto-unwrap in script
const nested = ref({ inner: ref(0) })
nested.value.inner.value           // must chain .value
```

### Deep vs Shallow Reactivity

```ts
// reactive is deep by default
const deep = reactive({ a: { b: { c: 1 } } })
deep.a.b.c = 2                    // triggers at every level

// shallowReactive -- only top level tracked
const shallow = shallowReactive({ a: { b: 1 } })
shallow.a = { b: 2 }              // triggers
shallow.a.b = 3                   // does NOT trigger

// shallowRef -- only .value assignment triggers
const sObj = shallowRef({ x: 1 })
sObj.value.x = 2                  // does NOT trigger
sObj.value = { x: 2 }             // triggers
```

### Reactive Props Destructure (Vue 3.5)

```ts
// Before 3.5: never destructure props
// After 3.5: safe reactive destructure in script setup
const { title, count = 0 } = defineProps<{ title: string; count?: number }>()
// These are reactive bindings -- using in template tracks correctly
// Default values work without withDefaults()
```

### Watchers Without Cleanup

```ts
// PROBLEM: fetch without abort on re-trigger
watch(id, async (newId) => {
  data.value = await fetch(`/api/${newId}`).then(r => r.json())
  // Previous fetch may resolve after new one, causing stale data
})

// FIX: onWatcherCleanup (Vue 3.5)
import { watch, onWatcherCleanup } from 'vue'
watch(id, (newId) => {
  const controller = new AbortController()
  onWatcherCleanup(() => controller.abort())
  fetch(`/api/${newId}`, { signal: controller.signal })
    .then(r => r.json()).then(d => { data.value = d })
})
```

---

## 2. Template Errors

### Common Compiler Warnings

| Warning | Cause | Fix |
|---|---|---|
| `Property 'X' does not exist on type` | Accessing undefined prop/variable | Check `defineProps` or import |
| `Extraneous non-emits event listeners` | Parent passes `@foo` but child lacks emit declaration | Add to `defineEmits` |
| `Component has already been defined` | Circular import or duplicate registration | Check import paths |
| `v-model argument is not supported` | `v-model:arg` on component without matching `defineModel` | Add `defineModel('arg')` |
| `Non-function value encountered for default slot` | Wrong slot syntax | Use `<template #default>` |

### Slot Scoping Issues

```html
<!-- Parent: access slot props via v-slot -->
<DataTable :rows="rows">
  <template #row="{ item }">
    <td>{{ item.name }}</td>
  </template>
</DataTable>

<!-- Child: expose slot prop -->
<template>
  <tr v-for="item in rows" :key="item.id">
    <slot name="row" :item="item" />
  </tr>
</template>
```

### v-for Key Warnings

```html
<!-- Missing key: runtime warning and subtle bugs -->
<li v-for="item in list" :key="item.id">  <!-- always provide stable key -->

<!-- Anti-pattern: index as key (breaks on reorder) -->
<li v-for="(item, index) in list" :key="index">  <!-- AVOID for mutable lists -->
```

### Component Name Casing

```html
<!-- PascalCase in template (recommended) -->
<MyComponent />

<!-- kebab-case also works -->
<my-component />

<!-- PITFALL: mixing casing inconsistently confuses DevTools and auto-imports -->
```

---

## 3. Hydration Mismatches

### Causes

Hydration mismatches occur in SSR (Nuxt, Vite SSR) when server-rendered HTML does not match client-side render output.

Common causes:
- **Date/time values** -- `new Date()` differs server vs client
- **Random values** -- `Math.random()`, `crypto.randomUUID()`
- **Browser-only APIs** -- `window`, `localStorage`, `navigator` during SSR
- **Conditional rendering on client state** -- `v-if="isLoggedIn"` with different initialization
- **HTML formatting** -- Extra whitespace, self-closing tags

### Diagnosing

Vue logs hydration warnings to the browser console in development:
```
[Vue warn]: Hydration node mismatch:
- Client vnode: div
- Server rendered DOM: span
```

### Fixes

```ts
// Fix 1: defer client-only content to onMounted
const isClient = ref(false)
onMounted(() => { isClient.value = true })
// <div v-if="isClient">{{ new Date() }}</div>

// Fix 2: <ClientOnly> component (Nuxt provides this)
// <ClientOnly><LocalTimestamp /></ClientOnly>

// Fix 3: data-allow-mismatch (Vue 3.5)
// <span data-allow-mismatch="text">{{ new Date().toLocaleString() }}</span>
// Values: "text" | "children" | "class" | "style" | "attribute"
```

### Hydration with Lazy Components

```ts
// Async components with hydration strategies (3.5)
const LazyWidget = defineAsyncComponent({
  loader: () => import('./Widget.vue'),
  hydrate: hydrateOnVisible()
})
// Server renders the component; client only hydrates when visible
// Prevents hydration cost for below-the-fold content
```

---

## 4. Build and Runtime Issues

### Vite Build Errors

| Error | Cause | Fix |
|---|---|---|
| `Failed to resolve import` | Missing dependency or wrong path | Check `resolve.alias` in vite.config.ts |
| `Cannot use JSX` | Missing `"jsx": "preserve"` in tsconfig | Add to `compilerOptions` |
| `Module not found: .vue` | Missing Vue plugin | Ensure `@vitejs/plugin-vue` is in `vite.config.ts` |
| `Duplicate module` | Multiple Vue instances in bundle | Configure `resolve.dedupe: ['vue']` |

### Runtime Warnings

| Warning | Fix |
|---|---|
| `[Vue warn]: Failed to resolve component` | Register globally or import locally |
| `[Vue warn]: Unhandled error during execution of scheduler` | Check `onErrorCaptured` or error boundary |
| `[Vue warn]: Injection not found` | Ensure `provide` is called in ancestor |
| `[Vue warn]: Maximum recursive updates exceeded` | Infinite loop in watcher/computed -- break the cycle |

### DevTools Debugging

1. **Component not showing in tree:** Ensure development mode (`process.env.NODE_ENV !== 'production'`).
2. **Reactivity not tracked:** Check that the value is a `ref`/`reactive`/`computed`, not a plain variable.
3. **Performance profiling:** Enable `app.config.performance = true` to see render timing in DevTools timeline.
