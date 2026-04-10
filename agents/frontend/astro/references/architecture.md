# Astro Architecture Reference

Deep reference for islands architecture, Server Islands, Content Layer, multi-framework support, and rendering modes.

---

## Islands Architecture

Astro renders every page as static HTML by default. Zero JavaScript ships to the browser unless a component is explicitly marked for hydration with a `client:*` directive. Each hydrated component becomes an independent island -- it loads, hydrates, and runs in isolation.

### Client Directives

| Directive | When Hydration Runs | Use Case |
|---|---|---|
| `client:load` | Immediately on page load | Above-the-fold interactive UI |
| `client:idle` | When browser is idle (`requestIdleCallback`) | Non-critical interactive widgets |
| `client:visible` | When component enters viewport (`IntersectionObserver`) | Below-fold components, carousels |
| `client:media="(query)"` | When CSS media query matches | Responsive-only components |
| `client:only="framework"` | Client-only, skips SSR entirely | Components that cannot run server-side |

```astro
---
import ReactChart from './ReactChart.jsx';
import SvelteMenu from './SvelteMenu.svelte';
---
<ReactChart client:load data={stats} />
<SvelteMenu client:visible />
<HeavyD3Widget client:only="react" />
```

Key rules:
- Without `client:*`, the component renders as static HTML only -- no event handlers, no state.
- If two islands use the same framework, that runtime is sent once per page.
- Islands are isolated: React state in island A does not affect island B without shared external state.

---

## Server Islands (v5)

Solve the CDN caching problem: cache the page at the edge while rendering personalized parts on-demand.

How they work:
1. The page serves immediately from cache (static shell + fallback placeholder).
2. The browser fires a GET request for each `server:defer` component.
3. The server renders that component on-demand and streams HTML back.
4. The placeholder is replaced with real content.

```astro
---
import UserGreeting from './UserGreeting.astro';
import CartBadge from './CartBadge.astro';
---
<header>
  <UserGreeting server:defer>
    <span slot="fallback">Welcome!</span>
  </UserGreeting>
  <CartBadge server:defer>
    <span slot="fallback">Cart</span>
  </CartBadge>
</header>
```

**Encrypted props:** Props passed to `server:defer` components are serialized and encrypted. For rolling deployments, set a stable key:

```bash
astro generate-key
ASTRO_KEY=<generated-value>
```

**When to use Server Islands vs Client Islands:**
- Server Island: personalized but not interactive (user name, cart count, recommendations).
- Client Island: interactive UI that needs hydration (forms, charts, search).

---

## Content Layer API (v5)

Replaced the legacy `type: 'content'`/`type: 'data'` system. All collections use a `loader`. Config in `src/content.config.ts` (v5 change from `src/content/config.ts`).

```typescript
import { defineCollection, z } from 'astro:content';
import { glob, file } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    publishDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

const authors = defineCollection({
  loader: file('./src/data/authors.json'),
  schema: z.object({
    name: z.string(),
    bio: z.string(),
    avatar: z.string(),
  }),
});

export const collections = { blog, authors };
```

**Querying collections:**

```astro
---
import { getCollection, getEntry, render } from 'astro:content';

const posts = (await getCollection('blog', ({ data }) => !data.draft))
  .sort((a, b) => b.data.publishDate.valueOf() - a.data.publishDate.valueOf());

const post = await getEntry('blog', 'my-first-post');
const { Content, headings } = await render(post);
---
<Content />
```

**Cross-collection references:**

```typescript
import { defineCollection, reference, z } from 'astro:content';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    author: reference('authors'),
  }),
});
```

**Custom loaders** for CMS, REST, or GraphQL sources. Support incremental sync via `meta` for tracking last-fetched timestamps.

---

## Multi-Framework Support

Multiple UI frameworks on the same page. Each island can use a different framework. Framework runtimes loaded once per page.

```bash
npx astro add react svelte vue solid
```

```astro
---
import ReactSearchBar from '../components/SearchBar.jsx';
import SvelteToast from '../components/Toast.svelte';
import VueAccordion from '../components/Accordion.vue';
---
<ReactSearchBar client:load />
<SvelteToast client:visible />
<VueAccordion client:idle />
```

**Constraint:** Only `.astro` files can contain components from multiple frameworks. A `.jsx` file cannot import a `.svelte` component.

---

## Rendering Modes

| `output` Setting | Default Behavior | Override With |
|---|---|---|
| `'static'` (default) | All pages pre-rendered at build | `export const prerender = false` |
| `'server'` | All pages SSR on-demand | `export const prerender = true` |
| `'hybrid'` | Alias for `'static'` since v5 | Same as static |

```astro
---
export const prerender = false;
---
```

SSR requires an adapter:
```bash
npx astro add node        # Self-hosted Node.js
npx astro add vercel      # Vercel
npx astro add cloudflare  # Cloudflare Workers/Pages
npx astro add netlify     # Netlify
```

---

## View Transitions

```astro
---
import { ClientRouter } from 'astro:transitions';
---
<head>
  <ClientRouter />
</head>
```

Directives: `transition:animate="slide"` (fade, slide, none), `transition:name="hero"` (persist element across pages), `transition:persist` (keep DOM node and state).

Native CSS alternative: `@view-transition { navigation: auto; }` for browsers with native support.

---

## Actions

Type-safe server-side mutations in `src/actions/index.ts`:

```typescript
import { defineAction, ActionError } from 'astro:actions';
import { z } from 'astro/zod';

export const server = {
  subscribe: defineAction({
    accept: 'json',
    input: z.object({
      email: z.string().email(),
      plan: z.enum(['free', 'pro']),
    }),
    handler: async ({ email, plan }) => {
      const result = await db.users.create({ email, plan });
      if (!result.ok) throw new ActionError({ code: 'INTERNAL_SERVER_ERROR' });
      return { success: true };
    },
  }),
};
```

Call from React: `const { data, error } = await actions.subscribe({ email, plan: 'pro' })`.

Call from Astro form (progressive enhancement): `<form method="POST" action={actions.contactForm}>`.

---

## astro:env

Type-safe environment variables with client/server/secret segmentation:

```typescript
// astro.config.mjs
env: {
  schema: {
    PUBLIC_SITE_URL: envField.string({ context: 'client', access: 'public' }),
    DATABASE_URL: envField.string({ context: 'server', access: 'secret' }),
    MAX_UPLOAD_MB: envField.number({ context: 'server', access: 'public', default: 10 }),
  },
},
```

```typescript
import { DATABASE_URL } from 'astro:env/server';
import { PUBLIC_SITE_URL } from 'astro:env/client';
```

Accessing a secret from `astro:env/client` is a build-time error.
