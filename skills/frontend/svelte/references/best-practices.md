# Svelte/SvelteKit Best Practices Reference

> Covers runes patterns, data flow, deployment, and testing. Last updated: 2026-04.

---

## 1. Runes Patterns

### Canonical Component Structure

```svelte
<script lang="ts">
  // 1. Props first
  let { userId, editable = false }: { userId: string; editable?: boolean } = $props();

  // 2. State
  let name = $state('');
  let bio = $state('');
  let saving = $state(false);

  // 3. Derived values
  let charCount = $derived(bio.length);
  let charStatus = $derived.by(() =>
    charCount > 500 ? 'over' : charCount > 400 ? 'near' : 'ok'
  );

  // 4. Effects (side effects only)
  $effect(() => {
    fetch(`/api/users/${userId}`).then(r => r.json()).then(u => {
      name = u.name;
      bio = u.bio ?? '';
    });
  });

  // 5. Functions
  async function save() {
    saving = true;
    await fetch(`/api/users/${userId}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, bio })
    });
    saving = false;
  }
</script>
```

### Key Rules

- Use `$state` for mutable local state; prefer direct mutation on objects/arrays
- Use `$derived` for any value computable from other state -- never duplicate state
- Use `$effect` only for genuine side effects (fetch, timers, DOM APIs, analytics)
- Avoid reading and writing the same `$state` in one `$effect` -- causes infinite loops
- Use `$state.raw` for large immutable datasets that are replaced wholesale

### Shared State in .svelte.ts

```ts
// src/lib/cart.svelte.ts
let items = $state<CartItem[]>([]);
export let total = $derived(items.reduce((s, i) => s + i.price, 0));

export function addItem(item: CartItem) {
  items.push(item);
}

export function removeItem(id: string) {
  items.splice(items.findIndex(i => i.id === id), 1);
}

export { items };
```

Import and use in any component -- reactivity crosses file boundaries.

---

## 2. SvelteKit Data Flow

### Load to Page Data Flow

```
+layout.server.js load  --+
+page.server.js load      +-- merged into `data` prop in +page.svelte
+page.js load            --+
+page.server.js actions  ------ `form` prop in +page.svelte (after POST)
```

- Layout loads run first; page loads can call `await parent()` to access layout data
- Server load data is JSON-serialized; do not return class instances or functions
- `+server.js` endpoints: always return `json()`, `text()`, or `new Response()`

### Authentication Pattern

```js
// src/hooks.server.js
export async function handle({ event, resolve }) {
  const session = event.cookies.get('session');
  event.locals.user = session ? await validateSession(session) : null;
  return resolve(event);
}
```

```js
// src/routes/dashboard/+page.server.js
import { redirect } from '@sveltejs/kit';

export async function load({ locals }) {
  if (!locals.user) throw redirect(302, '/login');
  return { user: locals.user };
}
```

### API Endpoints

```js
// src/routes/api/items/+server.js
import { json, error } from '@sveltejs/kit';

export async function GET({ url }) {
  const page = Number(url.searchParams.get('page') ?? '1');
  const items = await db.items.findMany({ skip: (page - 1) * 20, take: 20 });
  return json(items);
}

export async function POST({ request, locals }) {
  if (!locals.user) throw error(401, 'Unauthorized');
  const body = await request.json();
  const item = await db.items.create({ data: body });
  return json(item, { status: 201 });
}
```

---

## 3. Performance

### Leverage the Compiler

Svelte's compiler eliminates overhead that other frameworks add at runtime:
- No virtual DOM diffing
- No component wrapper objects
- Direct DOM mutations with minimal allocations

### Minimize $effect Usage

`$effect` runs after every dependency change. Prefer `$derived` for computed values. Use `$effect` only for genuine side effects.

```svelte
<script>
  // BAD: effect for derived value
  let count = $state(0);
  let doubled = $state(0);
  $effect(() => { doubled = count * 2; });   // unnecessary effect

  // GOOD: derived value
  let doubled = $derived(count * 2);
</script>
```

### $state.raw for Large Data

```svelte
<script>
  // Deep proxy overhead on large datasets
  let data = $state(hugeArray);          // wraps every nested object

  // No proxy overhead -- must replace wholesale
  let data = $state.raw(hugeArray);      // only tracks reference change
  // data = newArray;  // triggers
  // data.push(item);  // does NOT trigger
</script>
```

### Prerendering

Prerender all non-personalized pages at build time:

```js
// +page.js
export const prerender = true;
```

---

## 4. Testing

### Setup

```bash
npm install -D vitest @testing-library/svelte @testing-library/jest-dom jsdom
```

```ts
// vitest.config.ts
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts']
  }
});
```

```ts
// src/test/setup.ts
import '@testing-library/jest-dom';
```

### Component Testing

```ts
import { render, screen } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import Counter from './Counter.svelte';

test('increments on click', async () => {
  const user = userEvent.setup();
  render(Counter, { props: { initial: 5 } });
  await user.click(screen.getByRole('button', { name: /increment/i }));
  expect(screen.getByText('6')).toBeInTheDocument();
});
```

### Load Function Testing

Load functions are plain async functions -- test without components:

```ts
import { load } from './+page.server.js';
import { vi } from 'vitest';

test('returns post for valid slug', async () => {
  const mockFetch = vi.fn().mockResolvedValue({
    ok: true, json: async () => ({ title: 'Hello' })
  });
  const result = await load({ params: { slug: 'hello' }, fetch: mockFetch } as any);
  expect(result.post.title).toBe('Hello');
});
```

### Form Action Testing

```ts
import { actions } from './+page.server.js';

test('returns 422 on empty form', async () => {
  const req = new Request('http://localhost/contact', {
    method: 'POST', body: new FormData()
  });
  const result = await actions.default({ request: req } as any);
  expect(result?.status).toBe(422);
});
```

### E2E Testing

Use Playwright for form submissions, navigation, and hydration:

```bash
npm create playwright
```

---

## 5. Accessibility

### Form Labels

```svelte
<script>
  let id = crypto.randomUUID();
</script>

<label for={id}>Email</label>
<input {id} type="email" name="email" />
```

### ARIA in Runes Components

```svelte
<script>
  let expanded = $state(false);
  let panelId = `panel-${crypto.randomUUID()}`;
</script>

<button aria-expanded={expanded} aria-controls={panelId}
  onclick={() => expanded = !expanded}>
  {expanded ? 'Close' : 'Open'}
</button>

{#if expanded}
  <div id={panelId} role="region">
    Panel content
  </div>
{/if}
```

---

## 6. Security

### CSRF Protection

SvelteKit validates `Origin` header on POST by default. In production, set `ORIGIN` env var:

```bash
ORIGIN=https://myapp.com PORT=3000 node build
```

### Server-Only Code

Keep secrets in `src/lib/server/`. Importing from this path in client code is a compile error:

```
src/lib/server/
  db.ts           <- DB client
  auth.ts         <- session validation
  secrets.ts      <- API keys
```

### Environment Variables

```ts
// Server-only (never exposed to client)
import { DATABASE_URL } from '$env/static/private';

// Client-safe (PUBLIC_ prefix required)
import { PUBLIC_API_URL } from '$env/static/public';
```
