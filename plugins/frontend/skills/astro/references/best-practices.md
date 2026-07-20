# Astro Best Practices Reference

Guidelines for content collections, island strategy, SSR adapters, and image optimization.

---

## Content Collections

### Schema Design

- Use `z.coerce.date()` for dates -- handles both string and Date inputs from frontmatter.
- Use `.default()` for optional fields with sensible fallbacks rather than `.optional()` everywhere.
- Use `reference()` for relationships between collections instead of storing IDs as strings.
- Use discriminated unions (`z.discriminatedUnion`) for entries with different shapes.

### Loader Selection

| Source | Loader | Notes |
|---|---|---|
| Markdown/MDX files | `glob()` | Default for content-heavy sites |
| JSON/YAML files | `file()` | Best for structured data (authors, products) |
| CMS (Contentful, Sanity) | Custom loader | Fetch at build time; add `store.clear()` for full refresh |
| REST/GraphQL API | Custom loader | Use `store.set()` per entry; support incremental sync |

Custom loaders can use `meta` to track last-fetched timestamps for incremental updates, reducing build times on large collections.

---

## Island Strategy

### Decision Tree

1. Does the component need user interaction? If no --> render as static Astro component, no `client:*`.
2. Is interaction needed immediately on load? --> `client:load`.
3. Is it non-critical or below the fold? --> `client:visible` (most common for performance).
4. Is it a background widget (analytics, chat)? --> `client:idle`.
5. Does it only make sense on certain screen sizes? --> `client:media`.
6. Does it use browser-only APIs and cannot SSR? --> `client:only="framework"`.

### Minimize Island Surface Area

Islands should be small and focused. Wrap only the interactive part in a client island, not entire page sections:

```astro
<!-- GOOD: small interactive island -->
<article>
  <h1>{post.title}</h1>
  <p>{post.body}</p>
  <LikeButton client:visible postId={post.id} />
</article>

<!-- BAD: entire article hydrated for one button -->
<ArticleCard client:load post={post} />
```

### Framework Choice per Island

Pick the smallest runtime for simple islands. A toggle button does not need React. Reserve heavier frameworks for complex stateful UIs. Consider web components or vanilla JS for trivial interactions.

---

## SSR Adapters

### When to Use Static vs Server

**Use static (`output: 'static'`) when:**
- Content does not change per user or per request.
- Maximum CDN cacheability required.
- Use Server Islands for personalization pockets.

**Use server (`output: 'server'`) when:**
- Most pages are personalized (dashboards, user-specific content).
- Database access or session cookies needed on every route.
- Real-time data required on initial render.

### Adapter Notes

- **Node:** `mode: 'standalone'` for Docker; `mode: 'middleware'` to embed in Express/Fastify.
- **Vercel:** Automatically uses Edge Functions for Astro middleware; supports ISR.
- **Cloudflare:** Workers runtime -- no Node.js APIs. Use `cloudflare:env` for bindings (KV, D1, R2). Set `platformProxy: { enabled: true }` for local dev.
- **Netlify:** Supports edge functions and background functions.

---

## Image Optimization

Use the built-in `astro:assets` module (`@astrojs/image` is deprecated):

```astro
---
import { Image, Picture } from 'astro:assets';
import heroImg from '../assets/hero.jpg';
---
<Image src={heroImg} alt="Hero" width={1200} height={600} />

<Picture
  src={heroImg}
  alt="Hero"
  widths={[400, 800, 1200]}
  sizes="(max-width: 600px) 400px, (max-width: 1200px) 800px, 1200px"
  formats={['avif', 'webp', 'jpeg']}
/>
```

**Remote images** require domain authorization:

```javascript
image: {
  domains: ['cdn.example.com'],
  remotePatterns: [{ protocol: 'https', hostname: '**.cloudfront.net' }],
}
```

---

## Performance Guidelines

1. **Default to zero JS** -- Use `.astro` components for all static content. Only add `client:*` when interactivity is needed.
2. **Prefer `client:visible`** -- Most interactive components do not need immediate hydration.
3. **Use Server Islands** for personalization instead of making the whole page dynamic.
4. **Leverage Content Layer caching** -- Collections are cached between builds in `.astro/`.
5. **Scope framework integrations** -- Set `include` patterns when using multiple React-like frameworks to avoid JSX conflicts.
