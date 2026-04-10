# Composition API Patterns

> Composable design, ref vs reactive, provide/inject, effectScope. Last updated: 2026-04.

---

## 1. Composable Design Principles

1. **Return refs, not raw values** -- Callers destructure without losing reactivity.
2. **Accept `MaybeRefOrGetter<T>`** -- Works with refs, getters, or raw values via `toValue()`.
3. **Clean up side effects** -- Return a `stop` function or use `onUnmounted`.
4. **Use `effectScope`** for grouping effects in long-lived composables.
5. **Prefix with `use`** -- Convention signaling reactive composition.

### Basic Composable

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

### Composable with Cleanup

```ts
import { ref, onUnmounted } from 'vue'

export function useEventListener<K extends keyof WindowEventMap>(
  event: K,
  handler: (e: WindowEventMap[K]) => void,
  target: EventTarget = window
) {
  const isActive = ref(true)

  target.addEventListener(event, handler as EventListener)

  function stop() {
    if (isActive.value) {
      target.removeEventListener(event, handler as EventListener)
      isActive.value = false
    }
  }

  onUnmounted(stop)
  return { isActive, stop }
}
```

### Composable Composition

Composables can call other composables to build complex behavior:

```ts
export function useSearchableList<T>(
  items: MaybeRefOrGetter<T[]>,
  searchFields: (keyof T)[]
) {
  const query = ref('')
  const { value: debouncedQuery } = useDebounce(query, 300)

  const filtered = computed(() => {
    const q = toValue(debouncedQuery).toLowerCase()
    if (!q) return toValue(items)
    return toValue(items).filter(item =>
      searchFields.some(f => String(item[f]).toLowerCase().includes(q))
    )
  })

  const { currentItems, totalPages, next, prev } = usePagination(filtered)

  return { query, filtered, currentItems, totalPages, next, prev }
}
```

---

## 2. ref vs reactive

| Criterion | Use `ref` | Use `reactive` |
|---|---|---|
| Primitives | Always | N/A (objects only) |
| Objects | Preferred (explicit `.value`) | OK for internal grouped state |
| Destructuring | Safe (ref stays reactive) | Loses reactivity |
| Template auto-unwrap | Yes (top-level ref) | Yes |
| Return from composable | Always | Avoid (breaks on destructure) |

**Rule of thumb:** Use `ref` for everything returned from composables. Use `reactive` only for internal grouped state that will not be destructured.

### toRefs for Safe Destructuring

```ts
import { toRefs } from 'vue'

const state = reactive({ x: 0, y: 0 })
const { x, y } = toRefs(state)   // x and y are Ref<number> -- stay reactive
```

### toValue for Flexible Input

```ts
import { toValue, computed, type MaybeRefOrGetter } from 'vue'

function useDouble(n: MaybeRefOrGetter<number>) {
  return computed(() => toValue(n) * 2)
}

useDouble(5)                      // raw value
useDouble(count)                  // ref
useDouble(() => count.value + 1)  // getter
```

---

## 3. provide / inject

### Basic Usage

```ts
// Parent
import { provide, ref } from 'vue'
const theme = ref('dark')
provide('theme', theme)

// Child (any depth)
import { inject } from 'vue'
const theme = inject('theme', ref('light'))   // with default
```

### Typed Injection Keys

```ts
import type { InjectionKey, Ref } from 'vue'

export const ThemeKey: InjectionKey<Ref<string>> = Symbol('theme')

// Parent
provide(ThemeKey, theme)

// Child
const theme = inject(ThemeKey)   // type: Ref<string> | undefined
const theme2 = inject(ThemeKey, ref('light'))  // type: Ref<string>
```

### Read-Only Injection

Prevent consumers from mutating provided state:

```ts
import { provide, readonly } from 'vue'

const user = ref({ name: 'Alice' })
provide('user', readonly(user))   // consumers cannot mutate
```

### Plugin-Style Provide

```ts
// Composable that provides and injects
export function createNotificationSystem() {
  const notifications = ref<Notification[]>([])

  function notify(msg: string) {
    notifications.value.push({ id: Date.now(), msg })
  }

  return { notifications, notify }
}

// In App.vue setup
const system = createNotificationSystem()
provide(NotificationKey, system)

// In any descendant
const { notify } = inject(NotificationKey)!
```

---

## 4. effectScope

Groups reactive effects for bulk disposal. Used internally by components but useful for non-component contexts (testing, libraries).

```ts
import { effectScope, ref, watchEffect } from 'vue'

const scope = effectScope()

scope.run(() => {
  const count = ref(0)

  watchEffect(() => {
    console.log(count.value)    // tracked within scope
  })

  watch(count, (val) => {
    console.log('Changed:', val)
  })
})

// Later: dispose all effects in the scope
scope.stop()
```

### Nested Scopes

```ts
const parent = effectScope()

parent.run(() => {
  const child = effectScope(true)  // detached = true -- not stopped with parent

  child.run(() => {
    // these effects survive parent.stop()
  })
})
```

---

## 5. Async Composables

### With watchEffect (Auto-Tracking)

```ts
export function useFetch<T>(url: MaybeRefOrGetter<string>) {
  const data = ref<T | null>(null)
  const error = ref<Error | null>(null)
  const loading = ref(false)

  watchEffect(async () => {
    loading.value = true
    error.value = null
    try {
      const res = await fetch(toValue(url))
      if (!res.ok) throw new Error(res.statusText)
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

### With watch + Abort (Explicit Source)

```ts
export function useFetchExplicit<T>(url: Ref<string>) {
  const data = ref<T | null>(null)
  const loading = ref(false)

  watch(url, (newUrl) => {
    const controller = new AbortController()
    onWatcherCleanup(() => controller.abort())

    loading.value = true
    fetch(newUrl, { signal: controller.signal })
      .then(r => r.json())
      .then(d => { data.value = d })
      .finally(() => { loading.value = false })
  }, { immediate: true })

  return { data, loading }
}
```
