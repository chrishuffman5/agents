# Vue TypeScript Patterns

> Typed props, emits, model, generic components, injection keys. Last updated: 2026-04.

---

## 1. Typed Props

### Basic Props

```ts
<script setup lang="ts">
const props = defineProps<{
  title: string
  count?: number
  items: string[]
  formatter?: (item: string) => string
}>()
</script>
```

### Props with Defaults (Vue 3.5 Reactive Destructure)

```ts
<script setup lang="ts">
const { title, count = 0, items = [] } = defineProps<{
  title: string
  count?: number
  items?: string[]
}>()
// Reactive in templates; no withDefaults() needed
</script>
```

### Complex Props

```ts
<script setup lang="ts">
interface Item { id: number; label: string; metadata?: Record<string, unknown> }

const props = defineProps<{
  items: Item[]
  selected?: number
  renderItem?: (item: Item) => string
  variant: 'primary' | 'secondary' | 'ghost'
}>()
</script>
```

---

## 2. Typed Emits

### Tuple Syntax (3.3+)

```ts
<script setup lang="ts">
const emit = defineEmits<{
  'update:selected': [id: number]
  delete: [id: number]
  bulkDelete: [ids: number[]]
  close: []
}>()

emit('update:selected', 42)   // type-checked
emit('close')                  // no payload required
</script>
```

---

## 3. Typed defineModel

```ts
<script setup lang="ts">
// Basic v-model
const modelValue = defineModel<string>()

// Named model
const checked = defineModel<boolean>('checked')

// With transform
const count = defineModel<number>('count', {
  default: 0,
  set(value) { return Math.max(0, value) }
})
</script>

<!-- Parent usage -->
<!-- <MyInput v-model="text" /> -->
<!-- <Counter v-model:count="myCount" /> -->
<!-- <Toggle v-model:checked="isOn" /> -->
```

---

## 4. Generic Components

```ts
<script setup lang="ts" generic="T extends { id: number }">
const props = defineProps<{
  items: T[]
  selected?: T
}>()

const emit = defineEmits<{
  select: [item: T]
}>()

// T is inferred from usage:
// <GenericList :items="users" @select="handleUser" />
// where users: User[] and User extends { id: number }
</script>

<template>
  <ul>
    <li v-for="item in items" :key="item.id"
        :class="{ active: selected?.id === item.id }"
        @click="emit('select', item)">
      <slot :item="item">{{ item.id }}</slot>
    </li>
  </ul>
</template>
```

---

## 5. Typed Injection Keys

```ts
// keys.ts
import type { InjectionKey, Ref } from 'vue'

export const ThemeKey: InjectionKey<Ref<'light' | 'dark'>> = Symbol('theme')
export const ApiClientKey: InjectionKey<ApiClient> = Symbol('api-client')

// Provider
import { provide, ref } from 'vue'
import { ThemeKey } from '@/keys'
const theme = ref<'light' | 'dark'>('dark')
provide(ThemeKey, theme)

// Consumer
import { inject } from 'vue'
import { ThemeKey } from '@/keys'
const theme = inject(ThemeKey)            // Ref<'light' | 'dark'> | undefined
const theme2 = inject(ThemeKey, ref('light'))  // Ref<'light' | 'dark'>
```

---

## 6. Typed Template Refs

### useTemplateRef (Vue 3.5)

```ts
<script setup lang="ts">
import { useTemplateRef, onMounted } from 'vue'

const inputEl = useTemplateRef<HTMLInputElement>('search-input')
onMounted(() => inputEl.value?.focus())
</script>

<template>
  <input ref="search-input" type="text" />
</template>
```

### Component Refs

```ts
<script setup lang="ts">
import { useTemplateRef } from 'vue'
import type { ComponentPublicInstance } from 'vue'
import MyForm from './MyForm.vue'

const formRef = useTemplateRef<InstanceType<typeof MyForm>>('my-form')

function submit() {
  formRef.value?.validate()   // type-safe access to exposed methods
}
</script>

<template>
  <MyForm ref="my-form" />
</template>
```

---

## 7. Typed Slots

```ts
<script setup lang="ts">
interface Row { id: number; name: string }

const slots = defineSlots<{
  default(props: { items: Row[] }): any
  header(): any
  row(props: { item: Row; index: number }): any
  empty(): any
}>()
</script>
```

---

## 8. Global Type Augmentation

### Component Registration

```ts
// env.d.ts or components.d.ts
import MyButton from '@/components/MyButton.vue'
import MyInput from '@/components/MyInput.vue'

declare module 'vue' {
  interface GlobalComponents {
    MyButton: typeof MyButton
    MyInput: typeof MyInput
  }
}
```

### Router Meta Types

```ts
declare module 'vue-router' {
  interface RouteMeta {
    requiresAuth?: boolean
    title?: string
    roles?: string[]
  }
}
```
