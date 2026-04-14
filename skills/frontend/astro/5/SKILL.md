---
name: frontend-astro-5
description: "Expert agent for Astro 5 (current stable). Covers Server Islands (server:defer for on-demand rendering in cached pages), Content Layer API (unified loader-based collections replacing legacy type system), astro:env for type-safe environment variables, ClientRouter (renamed from ViewTransitions), Actions for type-safe server mutations, per-page prerender overrides, and performance improvements (5x faster Markdown, 2x faster MDX, 25-50% less memory). WHEN: \"Astro 5\", \"astro 5\", \"astro v5\", \"server:defer\", \"Content Layer API\", \"astro:env\", \"ClientRouter\", \"Astro actions\", \"content.config.ts\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Astro 5 Specialist

You are a specialist in Astro 5 (current stable). Astro 5 is the most significant release since the framework's launch, introducing Server Islands, the Content Layer API, type-safe environment variables, and Actions.

## Server Islands

Server Islands solve the CDN caching problem: cache the page at the edge while rendering personalized parts on-demand per request.

### How They Work

1. The page serves immediately from cache (static shell + fallback placeholder).
2. The browser fires a GET request for each `server:defer` component, with props as an encrypted query parameter.
3. The server renders the component on-demand and streams HTML back.
4. The placeholder is replaced with real content.

Because retrieval uses GET requests, responses are individually HTTP-cacheable.

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

### Encrypted Props

Props are serialized and encrypted using a key generated at build time. For multi-region or rolling deployments, set a stable key:

```bash
astro generate-key
ASTRO_KEY=<generated-value>
```

### Server Island vs Client Island

- **Server Island**: personalized but not interactive (user name, cart count, recommendations).
- **Client Island**: interactive UI needing client-side state (forms, charts, search).
- **Combined**: Server island providing data wrapping a client island for interactivity.

---

## Content Layer API

Replaced the legacy `type: 'content'` / `type: 'data'` collection system. All collections now use a `loader`. Performance: 5x faster Markdown builds, 2x faster MDX, 25-50% less memory.

### Config File Location Change

Astro 5: `src/content.config.ts` (no longer inside `src/content/`).

```typescript
import { defineCollection, z } from 'astro:content';
import { glob, file } from 'astro/loaders';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.{md,mdx}', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    publishDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
```

### Built-in Loaders

| Loader | Source | Use Case |
|---|---|---|
| `glob()` | Markdown/MDX files | Content-heavy sites |
| `file()` | JSON/YAML files | Structured data |

### Custom Loaders

For CMS, REST, or GraphQL sources. Support incremental sync via `meta` for efficient rebuilds.

### Cross-Collection References

```typescript
schema: z.object({
  author: reference('authors'),
})
```

---

## astro:env

Type-safe environment variables declared in `astro.config.mjs`:

```typescript
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

Accessing a secret from `astro:env/client` is a build-time error. Missing required variables fail at build, not at runtime.

---

## ClientRouter (Renamed)

`ViewTransitions` component renamed to `ClientRouter` in Astro 5:

```astro
---
import { ClientRouter } from 'astro:transitions';
---
<head>
  <ClientRouter />
</head>
```

Enables SPA-like page transitions using the View Transition API with fallback for unsupported browsers.

Directives: `transition:animate`, `transition:name`, `transition:persist`.

---

## Actions

Type-safe server-side mutations defined in `src/actions/index.ts`:

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
      return { success: true, userId: result.id };
    },
  }),

  contactForm: defineAction({
    accept: 'form',
    input: z.object({
      name: z.string().min(1),
      message: z.string().min(10),
    }),
    handler: async ({ name, message }) => {
      await sendEmail({ name, message });
      return { sent: true };
    },
  }),
};
```

**Calling from React:**
```jsx
import { actions } from 'astro:actions';
const { data, error } = await actions.subscribe({ email, plan: 'pro' });
```

**Calling from Astro (progressive enhancement):**
```astro
---
const result = Astro.getActionResult(actions.contactForm);
---
<form method="POST" action={actions.contactForm}>
  <input name="name" />
  <textarea name="message"></textarea>
  <button type="submit">Send</button>
</form>
{result?.data?.sent && <p>Message sent!</p>}
```

---

## Per-Page Prerender Overrides

```astro
---
// In a server-rendered site, opt specific pages into static generation
export const prerender = true;
---
```

```astro
---
// In a static site, opt specific pages into on-demand rendering
export const prerender = false;
---
```

---

## Migration from Astro 4

Key changes when upgrading:

- Move content config from `src/content/config.ts` to `src/content.config.ts`.
- Replace `type: 'content'` / `type: 'data'` with `loader: glob()` / `loader: file()`.
- Rename `<ViewTransitions />` to `<ClientRouter />`.
- Replace `import.meta.env` patterns with `astro:env` schema.
- Adopt Actions for server-side mutations (replaces manual API routes).
- `hybrid` output mode is now an alias for `static` -- no changes needed.
