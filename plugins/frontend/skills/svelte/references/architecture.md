# Svelte/SvelteKit Architecture Reference

> Covers Svelte 5 and SvelteKit 2. Last updated: 2026-04.

---

## 1. Compiler Model

Svelte is a **compiler**, not a runtime framework. There is no virtual DOM. `.svelte` files compile at build time into optimized vanilla JavaScript that surgically updates the DOM via fine-grained event listeners and direct DOM mutation calls -- no diffing, no reconciliation.

The compiler traces which reactive values flow into which DOM expressions and generates minimal update code per expression. A state variable used in three template locations produces three independent update paths; only affected DOM nodes are touched on change.

**Module modes:**
- `.svelte` -- component files compiled by `@sveltejs/vite-plugin-svelte`
- `.svelte.ts` / `.svelte.js` -- non-component modules that can use runes (shared reactive state)

**Compiler output targets:** `dom` (default, browser JS), `ssr` (server rendering), `css: 'injected'` (library builds)

---

## 2. Runes System (Svelte 5)

Runes are `$`-prefixed compiler directives that declare reactivity. They replace Svelte 4's implicit reactivity.

### $state -- Reactive State

```svelte
<script>
  let count = $state(0);
  let user = $state({ name: 'Alice', age: 30 });   // deep reactive proxy
  let items = $state([]);                            // array mutations tracked

  // Opt out of deep reactivity for large immutable data:
  let data = $state.raw(hugeArray);
</script>
```

Objects and arrays are wrapped in a deep reactive proxy -- nested mutations (`user.age = 31`, `items.push(x)`) are tracked automatically.

### $derived -- Computed Values

```svelte
<script>
  let count = $state(0);
  let doubled = $derived(count * 2);              // single expression
  let label = $derived.by(() => {                 // multi-line
    return count > 10 ? 'high' : 'low';
  });
</script>
```

Lazily computed and cached. Re-runs only when reactive dependencies change. Never cause side effects inside `$derived`.

### $effect -- Side Effects

```svelte
<script>
  $effect(() => {
    const controller = new AbortController();
    fetch(`/api/search?q=${query}`, { signal: controller.signal });
    return () => controller.abort();              // cleanup
  });
</script>
```

Runs **after** DOM update. Dependencies auto-tracked. `$effect.pre` runs before DOM update (like `useLayoutEffect`).

### $props -- Component Props

```svelte
<script lang="ts">
  let { name, age = 18, ...rest }: { name: string; age?: number } = $props();
</script>
```

Spread `...rest` captures forwarded attributes.

### $bindable -- Two-Way Bindable Props

```svelte
<!-- Child.svelte -->
<script>
  let { value = $bindable('') } = $props();
</script>
<input bind:value />

<!-- Parent: <Child bind:value={myVar} /> -->
```

Without `$bindable`, `bind:` on a prop throws a compile error.

### Other Runes

- **$inspect(value)** -- dev-only console logging when value changes (stripped in production)
- **$host()** -- accesses host element in custom element mode

---

## 3. Snippets

Svelte 5 replaces `<slot />` with snippets and `{@render}`:

```svelte
<!-- Child.svelte -->
<script>
  let { children, header }: {
    children: () => any;
    header?: () => any;
  } = $props();
</script>

{#if header}{@render header()}{/if}
<div class="content">
  {@render children()}
</div>
```

```svelte
<!-- Parent usage -->
<Child>
  {#snippet header()}<h1>Title</h1>{/snippet}
  <p>Default content (children)</p>
</Child>
```

Snippets are typed, composable, and can accept parameters.

---

## 4. SvelteKit Routing

Filesystem-based routing under `src/routes/`.

### Special Files

| File | Purpose |
|---|---|
| `+page.svelte` | Page UI component |
| `+page.js` | Universal load (server + client) |
| `+page.server.js` | Server-only load + form actions |
| `+layout.svelte` | Shared UI wrapper for child routes |
| `+layout.js` / `+layout.server.js` | Layout load functions |
| `+server.js` | API endpoint (GET, POST, PUT, DELETE) |
| `+error.svelte` | Error UI for this route segment |

### Route Syntax

```
src/routes/
  blog/[slug]/+page.svelte         -> /blog/any-slug        (params.slug)
  blog/[...rest]/+page.svelte      -> /blog/a/b/c           (params.rest = 'a/b/c')
  blog/[[optional]]/+page.svelte   -> /blog or /blog/value
  (group)/admin/+page.svelte       -> /admin                 (no URL segment)
```

**Route matchers:** `src/params/integer.js` exports `match(value)` function, used as `[id=integer]`.

---

## 5. Load Functions

### Universal Load (+page.js)

Runs on server and client:

```js
import { error } from '@sveltejs/kit';

export async function load({ params, fetch }) {
  const res = await fetch(`/api/posts/${params.slug}`);
  if (!res.ok) throw error(404, 'Post not found');
  return { post: await res.json() };
}
```

### Server Load (+page.server.js)

Has access to `cookies`, `locals`, `platform`, `request`:

```js
import { redirect } from '@sveltejs/kit';

export async function load({ locals }) {
  if (!locals.user) throw redirect(302, '/login');
  return { stats: await db.getUserStats(locals.user.id) };
}
```

### Data Flow and Types

```svelte
<!-- +page.svelte -->
<script lang="ts">
  import type { PageData } from './$types';
  let { data }: { data: PageData } = $props();
</script>
<h1>{data.post.title}</h1>
```

Layout loads run before page loads. Child pages access layout data via `await parent()`. Use `depends('app:tag')` + `invalidate('app:tag')` for fine-grained re-fetch.

### Streaming

Return un-awaited promises from load to enable streaming:

```js
export async function load({ fetch }) {
  const critical = await fetch('/api/fast').then(r => r.json());
  const slow = fetch('/api/slow').then(r => r.json());     // not awaited
  return { critical, slow };                                 // slow streamed
}
```

---

## 6. Form Actions

Server-side form handling with progressive enhancement:

```js
// +page.server.js
import { fail, redirect } from '@sveltejs/kit';

export const actions = {
  default: async ({ request }) => {
    const data = await request.formData();
    const email = data.get('email');
    if (!email) return fail(422, { missing: true });
    await sendEmail(email);
    throw redirect(303, '/success');
  },
  subscribe: async ({ request }) => {
    /* named action: <form action="?/subscribe"> */
  }
};
```

```svelte
<script>
  import { enhance } from '$app/forms';
  let { form } = $props();
  let submitting = $state(false);
</script>

<form method="POST" use:enhance={() => {
  submitting = true;
  return async ({ update }) => { submitting = false; await update(); };
}}>
  <input name="email" value={form?.email ?? ''} />
  <button disabled={submitting}>{submitting ? 'Sending...' : 'Send'}</button>
</form>
```

`use:enhance` intercepts submit, posts via `fetch`, updates page without full reload. Without JS: standard HTML POST.

---

## 7. SSR and Rendering Modes

SvelteKit defaults to SSR. Per-route config in `+page.js` or `+layout.js`:

```js
export const ssr = false;        // disable SSR -> SPA behavior
export const csr = false;        // no client JS -> static HTML only
export const prerender = true;   // render at build time
```

**Prerendering with dynamic routes:**
```js
export const prerender = true;
export function entries() {
  return [{ slug: 'hello' }, { slug: 'world' }];
}
```

---

## 8. Adapters

Set in `svelte.config.js`. Transforms the build for a specific deployment target.

| Adapter | Package | Use |
|---|---|---|
| `adapter-auto` | `@sveltejs/adapter-auto` | Auto-detect Vercel/Netlify/Cloudflare |
| `adapter-node` | `@sveltejs/adapter-node` | Node.js / Docker |
| `adapter-static` | `@sveltejs/adapter-static` | Fully static; all routes prerendered |
| `adapter-vercel` | `@sveltejs/adapter-vercel` | Vercel Edge + Serverless |
| `adapter-cloudflare` | `@sveltejs/adapter-cloudflare` | Cloudflare Pages + Workers |
| `adapter-netlify` | `@sveltejs/adapter-netlify` | Netlify Functions |

---

## 9. Hooks

### Server Hooks (hooks.server.js)

```js
export async function handle({ event, resolve }) {
  event.locals.user = await validateSession(event.cookies.get('session'));
  return resolve(event);
}

export function handleError({ error, event }) {
  console.error(error);
  return { message: 'Internal error' };
}
```

### Client Hooks (hooks.client.js)

```js
export function handleError({ error }) {
  console.error(error);
  return { message: 'Something went wrong' };
}
```

---

## 10. Environment Variables

| Module | Visible to browser | Build-time? |
|---|---|---|
| `$env/static/private` | No | Yes |
| `$env/static/public` | Yes | Yes (`PUBLIC_` prefix) |
| `$env/dynamic/private` | No | No (runtime) |
| `$env/dynamic/public` | Yes | No (runtime) |

Never import `$env/static/private` or `$env/dynamic/private` from client code -- compile error.
