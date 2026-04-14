# SvelteKit Routing Patterns

> +page, +layout, +server, load functions, form actions, hooks. Last updated: 2026-04.

---

## 1. File Structure

```
src/routes/
  +page.svelte              -> / (home page)
  +page.server.js           -> server load + form actions for /
  +layout.svelte            -> root layout (wraps all pages)
  +layout.server.js         -> root layout server load
  +error.svelte             -> root error page
  about/
    +page.svelte            -> /about
  blog/
    +page.svelte            -> /blog (listing)
    +page.server.js         -> blog listing server load
    [slug]/
      +page.svelte          -> /blog/:slug
      +page.server.js       -> individual post load + actions
  api/
    posts/
      +server.js            -> GET/POST /api/posts
      [id]/
        +server.js          -> GET/PUT/DELETE /api/posts/:id
  (auth)/                   -> route group (no URL segment)
    login/+page.svelte      -> /login
    register/+page.svelte   -> /register
  dashboard/
    +layout.svelte          -> dashboard layout
    +layout.server.js       -> auth guard for all dashboard pages
    +page.svelte            -> /dashboard
    settings/+page.svelte   -> /dashboard/settings
```

---

## 2. Load Functions

### Universal Load (+page.js)

Runs on server and client. Use for public data with `fetch`:

```js
// src/routes/blog/[slug]/+page.js
import { error } from '@sveltejs/kit';

export async function load({ params, fetch }) {
  const res = await fetch(`/api/posts/${params.slug}`);
  if (!res.ok) throw error(404, 'Post not found');
  const post = await res.json();
  return { post };
}
```

### Server Load (+page.server.js)

Has access to `cookies`, `locals`, `platform`. Use for DB queries and auth:

```js
// src/routes/dashboard/+page.server.js
import { redirect } from '@sveltejs/kit';

export async function load({ locals, depends }) {
  if (!locals.user) throw redirect(302, '/login');

  depends('app:dashboard');   // tag for selective invalidation

  const [stats, notifications] = await Promise.all([
    db.stats.get(locals.user.id),
    db.notifications.recent(locals.user.id)
  ]);

  return { stats, notifications };
}
```

### Layout Load (+layout.server.js)

Runs for all child routes. Use for shared data (auth, navigation):

```js
// src/routes/+layout.server.js
export async function load({ locals }) {
  return {
    user: locals.user ?? null,
    navigation: await db.navigation.getMenu()
  };
}
```

### Accessing Layout Data

```js
// src/routes/dashboard/+page.server.js
export async function load({ parent }) {
  const { user } = await parent();   // data from layout load
  return { settings: await db.settings.get(user.id) };
}
```

### Streaming

Return un-awaited promises for non-critical data:

```js
export async function load({ fetch }) {
  const critical = await fetch('/api/fast').then(r => r.json());
  const comments = fetch('/api/comments').then(r => r.json());   // streamed
  return { critical, comments };
}
```

```svelte
<script>
  let { data } = $props();
</script>

<h1>{data.critical.title}</h1>

{#await data.comments}
  <p>Loading comments...</p>
{:then comments}
  {#each comments as comment}
    <p>{comment.text}</p>
  {/each}
{/await}
```

---

## 3. Form Actions

### Basic Action

```js
// src/routes/contact/+page.server.js
import { fail, redirect } from '@sveltejs/kit';

export const actions = {
  default: async ({ request }) => {
    const data = await request.formData();
    const email = String(data.get('email') ?? '');
    const message = String(data.get('message') ?? '');

    if (!email) return fail(422, { errors: { email: 'Required' }, email, message });
    if (!message) return fail(422, { errors: { message: 'Required' }, email, message });

    await sendEmail(email, message);
    throw redirect(303, '/contact/success');
  }
};
```

### Named Actions

```js
export const actions = {
  login: async ({ request, cookies }) => {
    const data = await request.formData();
    // ... authenticate
    cookies.set('session', token, { path: '/', httpOnly: true });
    throw redirect(303, '/dashboard');
  },
  register: async ({ request }) => {
    // ... create account
  }
};
```

```svelte
<!-- Named action forms -->
<form method="POST" action="?/login">...</form>
<form method="POST" action="?/register">...</form>
```

### Progressive Enhancement

```svelte
<script>
  import { enhance } from '$app/forms';
  let { form } = $props();
  let submitting = $state(false);
</script>

<form method="POST" use:enhance={() => {
  submitting = true;
  return async ({ update, result }) => {
    submitting = false;
    if (result.type === 'success') {
      // Custom success handling
    }
    await update();   // default behavior: update form prop
  };
}}>
  <input name="email" value={form?.email ?? ''}
    aria-invalid={!!form?.errors?.email} />
  {#if form?.errors?.email}
    <span class="error">{form.errors.email}</span>
  {/if}
  <button disabled={submitting}>
    {submitting ? 'Sending...' : 'Send'}
  </button>
</form>
```

---

## 4. API Endpoints (+server.js)

```js
// src/routes/api/items/+server.js
import { json, error } from '@sveltejs/kit';

export async function GET({ url, locals }) {
  const page = Number(url.searchParams.get('page') ?? '1');
  const items = await db.items.findMany({
    skip: (page - 1) * 20, take: 20
  });
  return json(items);
}

export async function POST({ request, locals }) {
  if (!locals.user) throw error(401, 'Unauthorized');
  const body = await request.json();
  const item = await db.items.create({ data: body });
  return json(item, { status: 201 });
}

export async function DELETE({ params, locals }) {
  if (!locals.user) throw error(401);
  await db.items.delete({ where: { id: params.id } });
  return new Response(null, { status: 204 });
}
```

---

## 5. Hooks

### Server Hook (hooks.server.js)

```js
export async function handle({ event, resolve }) {
  // Auth middleware
  const session = event.cookies.get('session');
  event.locals.user = session ? await validateSession(session) : null;

  // Protected routes
  if (event.url.pathname.startsWith('/dashboard') && !event.locals.user) {
    return new Response('Redirect', {
      status: 302,
      headers: { Location: '/login' }
    });
  }

  return resolve(event);
}

export function handleError({ error, event }) {
  console.error(error);
  // Return safe error for client
  return { message: 'Internal server error' };
}
```

### Sequence Multiple Hooks

```js
import { sequence } from '@sveltejs/kit/hooks';

export const handle = sequence(
  authHook,
  loggingHook,
  corsHook
);
```

---

## 6. Invalidation and Re-fetching

### Manual Invalidation

```svelte
<script>
  import { invalidate, invalidateAll } from '$app/navigation';

  async function refresh() {
    await invalidate('app:dashboard');   // re-run loads with depends('app:dashboard')
  }

  async function refreshAll() {
    await invalidateAll();               // re-run all load functions
  }
</script>
```

### depends() in Load Functions

```js
export async function load({ depends }) {
  depends('app:notifications');
  const notifications = await db.notifications.getAll();
  return { notifications };
}
```

### Programmatic Navigation

```svelte
<script>
  import { goto } from '$app/navigation';

  async function navigate() {
    await goto('/dashboard', { replaceState: true });
  }
</script>
```
