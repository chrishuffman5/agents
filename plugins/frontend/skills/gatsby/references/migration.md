# Gatsby Migration Reference

Migration paths from Gatsby to Astro and Next.js.

---

## Migration Readiness Assessment

### Migrate Sooner

- Depends on Gatsby Cloud features (shut down)
- Active security CVEs with no upstream fix
- Build times over 30 minutes
- CMS source plugin broken due to upstream API change
- Node.js 20 required by host and builds are failing
- Need ISR, SSR, or API routes
- Plugin count over 20 (high conflict probability)

### Lower Urgency (maintain for now)

- Pure content/marketing site with infrequent updates
- Build times under 10 minutes
- All plugins stable on current Node.js version
- No new feature requirements
- No migration bandwidth available

### Effort Estimators

| Factor | Low Effort | High Effort |
|---|---|---|
| Page count | Under 50 | Over 500 |
| Data sources | Markdown/filesystem | Multiple CMS/API sources |
| Custom plugins | None | Several custom plugins |
| GraphQL complexity | Simple queries | Fragments, schema customization |
| React patterns | Functional components | Class components |
| Authentication | None | Auth-gated pages |

---

## Migrate to Astro

Preferred target for content-heavy sites. Islands architecture ships less JS than Gatsby's full React hydration.

### Conceptual Mapping

| Gatsby | Astro |
|---|---|
| `gatsby-source-*` plugins | `src/content/` collections or `fetch()` in frontmatter |
| Page query / `useStaticQuery` | `getCollection()` or top-of-file `fetch()` |
| `createPages` in gatsby-node.js | `getStaticPaths()` in `[slug].astro` |
| `gatsby-plugin-image` | `<Image />` from `astro:assets` |
| React components (full hydration) | Astro components (zero JS) + `client:load` for islands |
| Head API | Direct `<head>` in `.astro` layout |

See `patterns/migration-astro.md` for step-by-step instructions.

---

## Migrate to Next.js

Preferred when the site needs SSR, ISR, API routes, authentication, or heavy React interactivity.

### Conceptual Mapping

| Gatsby | Next.js |
|---|---|
| `gatsby-source-filesystem` + GraphQL | `fs` / `gray-matter` directly in Server Components |
| CMS source plugin | CMS SDK called in Server Components or `fetch()` |
| Page query | `async` Server Component with direct data fetching |
| `useStaticQuery` | Server Component passing props down, or `cache()` |
| `createPages` | File-based routing + `generateStaticParams()` |
| `gatsby-plugin-image` | `<Image />` from `next/image` |
| Head API | `export const metadata` or `generateMetadata()` |
| `gatsby-browser.js` wrapRootElement | `app/layout.tsx` |

### Next.js Migration Steps

1. **Replace source plugins:** Read files directly with `fs` + `gray-matter`. For CMS data, call the SDK directly in Server Components.

2. **Replace createPages + page queries:**
```tsx
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  return getAllPosts().map(post => ({ slug: post.slug }));
}
export default function BlogPost({ params }: { params: { slug: string } }) {
  const post = getPost(params.slug);
  return <article>...</article>;
}
```

3. **Replace Head API:**
```tsx
export async function generateMetadata({ params }) {
  const post = getPost(params.slug);
  return { title: post.title, description: post.excerpt };
}
```

4. **Replace gatsby-plugin-image** with `<Image />` from `next/image`.

5. **Move wrapRootElement** logic to `app/layout.tsx`.

---

## Maintain vs Migrate Decision

| Scenario | Recommendation |
|---|---|
| Content/docs site, minimal interactivity | Migrate to Astro |
| Need SSR/ISR/API routes, authentication | Migrate to Next.js |
| Low-change freeze mode, under 6 months lifespan | Stay on Gatsby |
| All plugins stable, no blocking issues | Stay on Gatsby (temporarily) |
| New project in 2025+ | Never use Gatsby |
