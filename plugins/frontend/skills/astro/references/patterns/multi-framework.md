# Astro Multi-Framework Patterns

Patterns for mixing React, Vue, Svelte, and other frameworks in a single Astro project.

---

## Setup

Install integrations for each framework:

```bash
npx astro add react svelte vue solid
```

Each integration registers its compiler/transform. Order in `integrations` array matters -- Astro processes sequentially.

---

## Mixing Frameworks on One Page

Only `.astro` files can import components from multiple frameworks:

```astro
---
import ReactDataGrid from '../components/react/DataGrid.jsx';
import SvelteFilterPanel from '../components/svelte/FilterPanel.svelte';
import VueModal from '../components/vue/ConfirmModal.vue';
---
<aside>
  <SvelteFilterPanel client:load />
</aside>
<main>
  <ReactDataGrid client:visible initialData={products} />
</main>
<VueModal client:idle />
```

A `.jsx` file cannot import a `.svelte` component. Cross-framework composition happens at the `.astro` level.

---

## Sharing State Across Frameworks

Use nanostores -- a framework-agnostic reactive store:

```bash
npm install nanostores @nanostores/react @nanostores/vue @nanostores/svelte
```

### Define the Store

```typescript
// src/stores/cart.ts
import { atom, computed } from 'nanostores';

export const cartItems = atom<CartItem[]>([]);
export const cartCount = computed(cartItems, items => items.length);
```

### React Island

```jsx
import { useStore } from '@nanostores/react';
import { cartCount } from '../../stores/cart';

export default function CartBadge() {
  const count = useStore(cartCount);
  return <span className="badge">{count}</span>;
}
```

### Svelte Island

```svelte
<script>
  import { cartCount } from '../../stores/cart';
</script>
<span class="badge">{$cartCount}</span>
```

### Vue Island

```vue
<script setup>
import { useStore } from '@nanostores/vue';
import { cartCount } from '../../stores/cart';
const count = useStore(cartCount);
</script>
<template>
  <span class="badge">{{ count }}</span>
</template>
```

All three islands react to the same store. Adding an item in the Svelte filter panel updates the React badge.

---

## Avoiding JSX Pragma Conflicts

If React and Preact are both installed, their JSX transforms conflict. Scope them:

```javascript
// astro.config.mjs
integrations: [
  react({ include: ['**/react/**'] }),
  preact({ include: ['**/preact/**'] }),
]
```

Place React components in `src/components/react/` and Preact components in `src/components/preact/`.

---

## Framework Selection Guide

| Need | Recommended Framework | Why |
|---|---|---|
| Complex data tables, forms | React | Largest ecosystem, most libraries |
| Lightweight interactive widgets | Svelte | Smallest runtime, best perf |
| Team already knows Vue | Vue | Familiarity reduces errors |
| Maximum performance | Solid | No virtual DOM, finest reactivity |
| Simplest possible | Preact or web components | Tiny runtime, fast hydration |

---

## Key Rules

1. **Only `.astro` files cross framework boundaries.** A React component cannot import Svelte.
2. **Framework runtimes load once per page.** Two React islands share one React runtime.
3. **Islands are isolated.** React context in island A does not reach island B. Use nanostores.
4. **Props must be serializable.** No functions or class instances across the server/client boundary.
5. **Alpine.js is special.** It does not use `client:*` directives. Include via script or `@astrojs/alpinejs`.
