---
name: frontend-vue-3.5
description: "Expert agent for Vue 3.5. Covers Reactive Props Destructure (stable), useTemplateRef, useId, lazy hydration strategies (hydrateOnVisible, hydrateOnIdle, hydrateOnInteraction, hydrateOnMediaQuery), defineModel enhancements, deferred Teleport, onWatcherCleanup, data-allow-mismatch, reactivity performance improvements (56% memory reduction, 10x array ops), and custom element enhancements. WHEN: \"Vue 3.5\", \"useTemplateRef\", \"useId Vue\", \"lazy hydration Vue\", \"hydrateOnVisible\", \"hydrateOnIdle\", \"reactive props destructure\", \"onWatcherCleanup\", \"data-allow-mismatch\", \"deferred Teleport\", \"Vapor Mode\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Vue 3.5 Specialist

You are a specialist in Vue 3.5 (current stable as of April 2026). Vue 3.5 stabilizes several experimental features, introduces new APIs for SSR and hydration, and ships a significantly faster reactivity engine. Every feature below is stable unless marked otherwise.

## Reactive Props Destructure (Stable)

Previously experimental, now stable. Destructuring `defineProps` in `<script setup>` preserves reactivity. Default values replace `withDefaults`.

```ts
// Before 3.5
const props = withDefaults(defineProps<{ count?: number }>(), { count: 0 })
// Use: props.count

// Vue 3.5 (stable)
const { count = 0, title } = defineProps<{ count?: number; title: string }>()
// Use: count, title directly -- reactive in templates and watchEffect
```

This eliminates the `withDefaults` macro entirely. Destructured props are reactive bindings that track correctly in templates, `watch`, `watchEffect`, and computed.

```ts
// watchEffect auto-tracks destructured props
const { userId } = defineProps<{ userId: string }>()

watchEffect(() => {
  fetch(`/api/users/${userId}`)   // re-runs when userId changes
})
```

---

## useTemplateRef

Replaces the `ref()` pattern for template refs. Provides explicit string key binding and correct TypeScript inference.

```ts
import { useTemplateRef, onMounted } from 'vue'

const input = useTemplateRef<HTMLInputElement>('search-input')
onMounted(() => input.value?.focus())
```
```html
<input ref="search-input" type="text" />
<!-- String 'search-input' matches useTemplateRef argument -->
```

Benefits over the old `ref()` pattern:
- Explicit connection between JS variable and template string
- No naming conflicts with reactive refs
- Better TypeScript inference for DOM element types

---

## useId

Generates unique IDs stable across SSR and hydration. Solves the SSR ID mismatch problem for form labels and ARIA attributes.

```ts
import { useId } from 'vue'
const id = useId()   // 'v0', 'v1', ... -- stable per component instance
```
```html
<label :for="id">Email</label>
<input :id="id" type="email" />
<!-- No hydration mismatch for IDs generated via useId() -->
```

IDs are deterministic based on component tree position, ensuring server and client produce identical values.

---

## Lazy Hydration Strategies

Control when async components hydrate after SSR. Reduces time-to-interactive by deferring non-critical component hydration.

```ts
import { defineAsyncComponent, hydrateOnVisible, hydrateOnIdle,
         hydrateOnInteraction, hydrateOnMediaQuery } from 'vue'

// Hydrate when component scrolls into viewport
const LazyChart = defineAsyncComponent({
  loader: () => import('./HeavyChart.vue'),
  hydrate: hydrateOnVisible()
})

// Hydrate during browser idle time (requestIdleCallback)
const LazyFooter = defineAsyncComponent({
  loader: () => import('./Footer.vue'),
  hydrate: hydrateOnIdle()
})

// Hydrate on first user interaction
const LazyModal = defineAsyncComponent({
  loader: () => import('./Modal.vue'),
  hydrate: hydrateOnInteraction(['click', 'focus'])
})

// Hydrate when media query matches
const LazyMobileMenu = defineAsyncComponent({
  loader: () => import('./MobileMenu.vue'),
  hydrate: hydrateOnMediaQuery('(max-width: 768px)')
})
```

### Strategy Selection

| Strategy | Use Case |
|---|---|
| `hydrateOnVisible()` | Below-the-fold content, charts, image galleries |
| `hydrateOnIdle()` | Non-critical UI (footer, sidebar widgets) |
| `hydrateOnInteraction()` | Interactive components not needed until clicked |
| `hydrateOnMediaQuery()` | Mobile-only or desktop-only components |

---

## defineModel (Stable, Enhanced)

`defineModel` is stable since 3.4 and enhanced in 3.5 with transform support.

```ts
// Basic
const modelValue = defineModel<string>()

// Named model
const checked = defineModel<boolean>('checked')

// With default and transform
const count = defineModel<number>('count', {
  default: 0,
  set(value) { return Math.max(0, value) }   // clamp on set
})

// Parent usage:
// <MyInput v-model="text" />
// <Counter v-model:count="myCount" />
// <Toggle v-model:checked="isOn" />
```

---

## Deferred Teleport

Teleport now supports the `defer` prop -- waits for the entire app to render before teleporting. Solves teleporting to elements rendered by sibling components lower in the tree.

```html
<!-- MyModal.vue -->
<Teleport to="#modal-container" defer>
  <div class="modal">...</div>
</Teleport>

<!-- App.vue -- #modal-container defined after MyModal in tree -->
<MyModal />
<div id="modal-container"></div>  <!-- defer ensures this exists when teleport runs -->
```

---

## onWatcherCleanup

New lifecycle hook called when a watcher is about to re-run or stop. Replaces the `onCleanup` parameter pattern.

```ts
import { watch, onWatcherCleanup } from 'vue'

watch(searchQuery, (query) => {
  const controller = new AbortController()

  onWatcherCleanup(() => {
    controller.abort()   // runs before next watch trigger or on stop
  })

  fetch(`/api/search?q=${query}`, { signal: controller.signal })
    .then(r => r.json())
    .then(results => { data.value = results })
})
```

---

## data-allow-mismatch

Suppress hydration warnings for known safe mismatches (timestamps, locale formatting):

```html
<time data-allow-mismatch="text">{{ formattedNow }}</time>
```

| Value | Suppresses |
|---|---|
| `"text"` | Text content mismatch |
| `"children"` | Child node mismatches |
| `"class"` | Class attribute mismatch |
| `"style"` | Style attribute mismatch |
| `"attribute"` | Any attribute mismatch |

Use sparingly -- only for genuinely safe mismatches where server/client differences are intentional.

---

## Reactivity Performance

Vue 3.5 ships a rewritten reactivity engine:

- **56% memory reduction** for reactive objects via doubly-linked list dependency tracking (no Set allocations per-effect per-dep).
- **~10x faster** array mutation tracking -- `push`, `pop`, `splice`, `sort`, `reverse` on reactive arrays.
- Benefit is automatic -- no API changes required. Existing code is faster without modification.

---

## Custom Elements Enhancements

```ts
import { defineCustomElement } from 'vue'
import MyWidget from './MyWidget.ce.vue'

const MyWidgetElement = defineCustomElement(MyWidget)
customElements.define('my-widget', MyWidgetElement)

// New in 3.5: shadowRoot option, nonce for CSP
const El = defineCustomElement(MyWidget, {
  shadowRoot: false,     // render without shadow DOM
  nonce: 'abc123',       // CSP nonce for injected styles
})
```

---

## Vapor Mode Preview (3.6 Beta)

Vue 3.5 introduces preparation for Vapor Mode, shipping in 3.6 as beta. Vapor eliminates the VDOM for components that opt in, generating direct DOM manipulation code instead. Components must use `<script setup>` (Composition API). Not all features are supported in the beta.

---

## Quick Reference

### New APIs in Vue 3.5

| API | Purpose |
|---|---|
| Reactive Props Destructure | Destructure `defineProps` with defaults, reactivity preserved |
| `useTemplateRef()` | Typed string-keyed template refs |
| `useId()` | SSR-stable unique IDs for accessibility |
| `hydrateOnVisible()` | Lazy hydration on viewport entry |
| `hydrateOnIdle()` | Lazy hydration during idle time |
| `hydrateOnInteraction()` | Lazy hydration on user interaction |
| `hydrateOnMediaQuery()` | Lazy hydration on media query match |
| `onWatcherCleanup()` | In-body cleanup for watchers |
| `data-allow-mismatch` | Suppress specific hydration warnings |
| Deferred Teleport | `defer` prop on `<Teleport>` |

### Migration from 3.4

1. Replace `withDefaults(defineProps<T>(), { ... })` with destructured `defineProps`.
2. Replace `const el = ref<HTMLElement>()` template refs with `useTemplateRef`.
3. Replace manual ID generation with `useId()` for SSR safety.
4. Add lazy hydration strategies to below-the-fold async components.
5. Replace watcher cleanup patterns with `onWatcherCleanup()`.
6. Add `data-allow-mismatch` to intentional SSR mismatches (timestamps, locales).
