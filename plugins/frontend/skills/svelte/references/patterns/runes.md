# Svelte Runes Patterns

> $state/$derived/$effect patterns, shared state, Svelte 4 migration. Last updated: 2026-04.

---

## 1. Core Runes

### $state -- Reactive State

```svelte
<script lang="ts">
  // Primitives
  let count = $state(0);
  let name = $state('');

  // Objects -- deep reactive proxy (mutations tracked)
  let user = $state({ name: 'Alice', age: 30 });
  user.name = 'Bob';             // reactive!

  // Arrays -- mutations tracked
  let items = $state<string[]>([]);
  items.push('new item');        // reactive!

  // Opt out of deep reactivity for large data
  let data = $state.raw(hugeArray);
  // data = newArray;  // triggers
  // data.push(x);     // does NOT trigger
</script>
```

### $derived -- Computed Values

```svelte
<script>
  let count = $state(0);

  // Single expression
  let doubled = $derived(count * 2);

  // Multi-line with $derived.by
  let status = $derived.by(() => {
    if (count > 100) return 'high';
    if (count > 50) return 'medium';
    return 'low';
  });

  // Filtering/mapping
  let items = $state([1, 2, 3, 4, 5]);
  let evens = $derived(items.filter(n => n % 2 === 0));
</script>
```

**Rules:**
- Never cause side effects inside `$derived` (no fetch, no DOM manipulation)
- `$derived` is lazy -- only computes when read
- `$derived` caches -- only recomputes when dependencies change

### $effect -- Side Effects

```svelte
<script>
  let query = $state('');

  // Auto-tracked dependencies
  $effect(() => {
    console.log(`Query changed: ${query}`);
    // Dependencies: query
  });

  // With cleanup
  $effect(() => {
    const controller = new AbortController();
    fetch(`/api/search?q=${query}`, { signal: controller.signal })
      .then(r => r.json())
      .then(results => { data = results; });

    return () => controller.abort();   // cleanup before next run
  });

  // Pre-DOM effect (before DOM update)
  $effect.pre(() => {
    // Measure DOM before update
    const height = container.scrollHeight;
  });
</script>
```

**Rules:**
- `$effect` runs after DOM update
- `$effect.pre` runs before DOM update
- Never read and write the same `$state` in one effect (infinite loop)
- Use `$derived` for computed values, not `$effect` + assignment
- Effects auto-clean up when component is destroyed

---

## 2. Props Patterns

### Basic Props

```svelte
<script lang="ts">
  let { name, age = 18, ...rest }: {
    name: string;
    age?: number;
    [key: string]: unknown;
  } = $props();
</script>

<div {...rest}>
  <p>{name}, {age}</p>
</div>
```

### Bindable Props

```svelte
<!-- TextInput.svelte -->
<script lang="ts">
  let { value = $bindable(''), placeholder = '' }: {
    value?: string;
    placeholder?: string;
  } = $props();
</script>

<input bind:value {placeholder} />

<!-- Parent: <TextInput bind:value={searchQuery} /> -->
```

### Children (Snippets)

```svelte
<!-- Card.svelte -->
<script lang="ts">
  let { children, title }: {
    children: () => any;
    title?: string;
  } = $props();
</script>

<div class="card">
  {#if title}<h2>{title}</h2>{/if}
  {@render children()}
</div>

<!-- Parent: <Card title="Hello"><p>Content</p></Card> -->
```

### Parameterized Snippets

```svelte
<!-- List.svelte -->
<script lang="ts">
  let { items, row }: {
    items: any[];
    row: (item: any, index: number) => any;
  } = $props();
</script>

{#each items as item, i}
  {@render row(item, i)}
{/each}

<!-- Parent -->
<List {items}>
  {#snippet row(item, i)}
    <li>{i}: {item.name}</li>
  {/snippet}
</List>
```

---

## 3. Shared State

### Module-Level State (.svelte.ts)

```ts
// src/lib/auth.svelte.ts
interface User { id: string; name: string; email: string }

let user = $state<User | null>(null);
let isLoggedIn = $derived(!!user);

export async function login(email: string, password: string) {
  const res = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  if (res.ok) user = await res.json();
}

export function logout() {
  user = null;
}

export { user, isLoggedIn };
```

```svelte
<!-- Any component -->
<script>
  import { user, isLoggedIn, logout } from '$lib/auth.svelte';
</script>

{#if isLoggedIn}
  <p>Welcome, {user.name}</p>
  <button onclick={logout}>Logout</button>
{/if}
```

### When to Use Shared State vs Load Functions

| Use | When |
|---|---|
| `.svelte.ts` shared state | Client-side only state (cart, UI, form state) |
| Load functions | Server data (DB, auth, API calls) |
| Both | Load fetches initial data; shared state manages mutations |

---

## 4. Common Patterns

### Debounced Search

```svelte
<script>
  let query = $state('');
  let results = $state([]);
  let timer: ReturnType<typeof setTimeout>;

  $effect(() => {
    clearTimeout(timer);
    if (!query) { results = []; return; }
    timer = setTimeout(async () => {
      const res = await fetch(`/api/search?q=${query}`);
      results = await res.json();
    }, 300);
    return () => clearTimeout(timer);
  });
</script>

<input bind:value={query} placeholder="Search..." />
{#each results as result}
  <p>{result.title}</p>
{/each}
```

### Toggle with Derived

```svelte
<script>
  let isOpen = $state(false);
  let label = $derived(isOpen ? 'Close' : 'Open');
  let icon = $derived(isOpen ? 'chevron-up' : 'chevron-down');
</script>

<button onclick={() => isOpen = !isOpen}>
  {label}
</button>
```

### Form State

```svelte
<script lang="ts">
  let form = $state({ name: '', email: '', message: '' });
  let isValid = $derived(form.name.length > 0 && form.email.includes('@'));
  let submitting = $state(false);

  async function handleSubmit() {
    submitting = true;
    await fetch('/api/contact', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form)
    });
    submitting = false;
    form = { name: '', email: '', message: '' };
  }
</script>
```

---

## 5. Svelte 4 to 5 Migration

| Svelte 4 | Svelte 5 |
|---|---|
| `let count = 0` (reactive) | `let count = $state(0)` |
| `export let value` | `let { value } = $props()` |
| `$: doubled = count * 2` | `let doubled = $derived(count * 2)` |
| `$: { doEffect(count); }` | `$effect(() => { doEffect(count); })` |
| `<svelte:component this={C} />` | `<C />` (dynamic component) |
| `<slot />` | `{@render children()}` |
| `<slot name="header" />` | `{@render header()}` with snippet prop |
| `$$slots.header` | Check `header` prop truthy |
| `$$restProps` | `let { ...rest } = $props()` |
| Stores (`writable`, `$store`) | `.svelte.ts` module-level `$state` |
| `afterUpdate` | `$effect` |
| `beforeUpdate` | `$effect.pre` |

### Migration Steps

1. Enable runes: `compilerOptions: { runes: true }` in `svelte.config.js`
2. Convert `let` declarations to `$state` for reactive variables
3. Convert `export let` to `$props()` destructuring
4. Convert `$:` reactive declarations to `$derived`
5. Convert `$:` reactive statements to `$effect`
6. Convert `<slot />` to `{@render}` with snippet props
7. Convert stores to `.svelte.ts` module state (optional but recommended)
