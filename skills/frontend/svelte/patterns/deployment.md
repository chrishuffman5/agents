# SvelteKit Deployment Patterns

> Adapter selection, environment variables, prerendering strategies. Last updated: 2026-04.

---

## 1. Adapter Selection

| Adapter | Package | When to Use |
|---|---|---|
| `adapter-auto` | `@sveltejs/adapter-auto` | Default; auto-detects Vercel/Netlify/Cloudflare |
| `adapter-node` | `@sveltejs/adapter-node` | Node.js server, Docker, VPS, Railway |
| `adapter-static` | `@sveltejs/adapter-static` | Fully static site, all routes prerendered |
| `adapter-vercel` | `@sveltejs/adapter-vercel` | Vercel with Edge/Serverless fine control |
| `adapter-cloudflare` | `@sveltejs/adapter-cloudflare` | Cloudflare Pages + Workers |
| `adapter-netlify` | `@sveltejs/adapter-netlify` | Netlify Functions |

### Node.js / Docker

```js
// svelte.config.js
import adapter from '@sveltejs/adapter-node';

const config = {
  kit: {
    adapter: adapter({
      out: 'build',          // output directory
      precompress: true,     // generate .gz and .br files
    })
  }
};
```

```bash
# Production start
ORIGIN=https://myapp.com PORT=3000 node build
```

### Docker

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=build /app/build build/
COPY --from=build /app/package.json .
COPY --from=build /app/node_modules node_modules/
ENV PORT=3000
ENV ORIGIN=https://myapp.com
EXPOSE 3000
CMD ["node", "build"]
```

### Static Site

```js
import adapter from '@sveltejs/adapter-static';

const config = {
  kit: {
    adapter: adapter({
      pages: 'build',
      assets: 'build',
      fallback: '200.html',  // for SPA-style client routing
      precompress: true,
    })
  }
};
```

All routes must be prerenderable or have `export const prerender = false` with a fallback page.

---

## 2. Environment Variables

### Module Types

| Module | Visible to browser | When resolved |
|---|---|---|
| `$env/static/private` | No | Build time |
| `$env/static/public` | Yes | Build time (`PUBLIC_` prefix) |
| `$env/dynamic/private` | No | Runtime |
| `$env/dynamic/public` | Yes | Runtime (`PUBLIC_` prefix) |

### Usage

```ts
// Server-only (hooks.server.js, +page.server.js, +server.js)
import { DATABASE_URL, JWT_SECRET } from '$env/static/private';
import { DATABASE_URL as RUNTIME_DB } from '$env/dynamic/private';

// Client-safe (any file)
import { PUBLIC_API_URL } from '$env/static/public';
import { env } from '$env/dynamic/public';
const apiUrl = env.PUBLIC_API_URL;
```

### ORIGIN Variable

SvelteKit validates `Origin` header on POST requests for CSRF protection. In production, set `ORIGIN`:

```bash
ORIGIN=https://myapp.com node build
```

Without `ORIGIN`, form submissions and fetch POST requests from the browser may be rejected with a 403.

---

## 3. Prerendering Strategies

### Per-Route Prerendering

```js
// src/routes/about/+page.js
export const prerender = true;    // prerender at build time
```

```js
// src/routes/dashboard/+page.js
export const prerender = false;   // always server-rendered
```

### Dynamic Route Prerendering

```js
// src/routes/blog/[slug]/+page.js
export const prerender = true;

// Provide entries for dynamic params
export function entries() {
  return [
    { slug: 'first-post' },
    { slug: 'second-post' },
    { slug: 'third-post' }
  ];
}
```

### Crawler-Based Discovery

```js
// svelte.config.js
const config = {
  kit: {
    prerender: {
      crawl: true,              // follow <a> links to discover pages
      entries: ['/', '/sitemap.xml'],  // starting points
      handleHttpError: 'warn',  // don't fail build on 404 links
    }
  }
};
```

### Layout-Level Prerendering

```js
// src/routes/(marketing)/+layout.js
export const prerender = true;   // all pages in (marketing) group are prerendered
```

---

## 4. Rendering Mode Reference

| Config | Effect |
|---|---|
| `export const ssr = true` | Server-render then hydrate (default) |
| `export const ssr = false` | Client-only rendering (SPA) |
| `export const csr = false` | No client JS (static HTML only) |
| `export const prerender = true` | Build-time rendering (SSG) |
| `ssr: false` + `csr: true` | Pure SPA |
| `ssr: true` + `csr: false` | Server-only, no hydration |

### Mixed Rendering

```js
// Marketing pages: prerendered
// src/routes/(marketing)/+layout.js
export const prerender = true;

// App pages: SSR with hydration
// src/routes/(app)/+layout.js
export const ssr = true;
export const prerender = false;

// Admin: client-only SPA
// src/routes/admin/+layout.js
export const ssr = false;
```

---

## 5. Platform-Specific Configuration

### Vercel

```js
// svelte.config.js
import adapter from '@sveltejs/adapter-vercel';

const config = {
  kit: {
    adapter: adapter({
      runtime: 'nodejs20.x',   // or 'edge'
    })
  }
};
```

Per-route edge:
```js
// src/routes/fast/+page.server.js
export const config = { runtime: 'edge' };
```

### Cloudflare

```js
import adapter from '@sveltejs/adapter-cloudflare';

const config = {
  kit: {
    adapter: adapter({
      routes: {
        include: ['/*'],
        exclude: ['<all>']     // exclude static assets
      }
    })
  }
};
```

Access `platform.env` bindings in server load:
```js
export async function load({ platform }) {
  const kv = platform.env.MY_KV;
  const value = await kv.get('key');
  return { value };
}
```

---

## 6. Production Checklist

1. Set `ORIGIN` environment variable for CSRF protection
2. Choose appropriate adapter for your deployment target
3. Enable `precompress: true` for gzip/brotli static assets
4. Prerender all static pages (marketing, docs, blog)
5. Set `export const ssr = false` for client-only sections
6. Keep secrets in `$env/static/private` or `$env/dynamic/private`
7. Test with `npm run preview` before deploying
8. Configure error pages (`+error.svelte`) for production
9. Set up `handleError` hook for error logging
