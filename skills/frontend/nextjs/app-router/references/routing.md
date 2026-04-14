# App Router Routing Reference

Complete reference for file-system routing in the Next.js App Router.

---

## File Conventions

### Special Files

| File | Purpose | Component Type |
|---|---|---|
| `page.tsx` | Unique UI for a route; makes segment publicly accessible | Server (default) |
| `layout.tsx` | Shared UI wrapping segment and children; persists across navigations | Server (default) |
| `loading.tsx` | Instant Suspense fallback during page load | Server (default) |
| `error.tsx` | Error Boundary for segment and children | **Client** (required) |
| `not-found.tsx` | UI for `notFound()` calls or unmatched URLs | Server (default) |
| `template.tsx` | Like layout but re-mounts on every navigation | Server (default) |
| `default.tsx` | Fallback for parallel route slots with no match | Server (default) |
| `route.ts` | API endpoint (Route Handler); no UI | Server only |

### Composition Order

Components wrap in this order (outermost to innermost):

```
layout.tsx
  template.tsx (if present)
    error.tsx (Error Boundary)
      loading.tsx (Suspense boundary)
        page.tsx (or nested layout)
```

### Colocation Rules

- Non-special files (components, utils, styles, tests) inside `app/` are NOT exposed as routes
- Only `page.tsx` and `route.ts` make a segment publicly routable
- `route.ts` and `page.tsx` cannot coexist at the same path -- choose one
- `middleware.ts` / `proxy.ts` lives at the project root, NOT inside `app/`

---

## Dynamic Routes

### Single Dynamic Segment -- `[param]`

```
app/blog/[slug]/page.tsx     -> /blog/hello-world, /blog/nextjs-tips
```

```tsx
// Props: { params: Promise<{ slug: string }> } (v15+: must await)
export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await fetchPost(slug);
  return <article>{post.content}</article>;
}
```

### Catch-All Segment -- `[...param]`

```
app/docs/[...slug]/page.tsx  -> /docs/a, /docs/a/b, /docs/a/b/c
```

- Does NOT match `/docs` itself
- Props: `{ params: Promise<{ slug: string[] }> }`

### Optional Catch-All -- `[[...param]]`

```
app/docs/[[...slug]]/page.tsx -> /docs, /docs/a, /docs/a/b
```

- Matches `/docs` (slug = undefined), `/docs/a`, `/docs/a/b`
- Props: `{ params: Promise<{ slug?: string[] }> }`

### Multiple Dynamic Segments

```
app/[category]/[slug]/page.tsx -> /electronics/laptop, /books/nextjs
```

Props: `{ params: Promise<{ category: string; slug: string }> }`

### generateStaticParams

Pre-render dynamic routes at build time:

```tsx
export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}
```

- Called once at build time; returns array of param objects
- `dynamicParams = true` (default): unlisted params generated on-demand and cached
- `dynamicParams = false`: unlisted params return 404
- Nested dynamic routes: parent `generateStaticParams` can feed child params

### Segment Validation

- Segments are strings by default; validate/transform in the component
- Use `notFound()` from `next/navigation` for invalid slugs
- TypeScript types enforce param shape at the component level

---

## Route Groups

Parentheses syntax `(groupName)` -- logical organization without URL impact.

```
app/
  (marketing)/
    layout.tsx        <- marketing layout
    page.tsx          <- / (homepage)
    about/page.tsx    <- /about
    blog/page.tsx     <- /blog
  (app)/
    layout.tsx        <- authenticated app layout
    dashboard/page.tsx <- /dashboard
    settings/page.tsx  <- /settings
```

### Use Cases

**Per-section layouts:**
Each group can have its own `layout.tsx` without affecting the URL.

**Auth/unauth split:**
```
app/
  (public)/
    layout.tsx        <- public layout (no auth)
    login/page.tsx
    register/page.tsx
  (authenticated)/
    layout.tsx        <- auth-checking layout
    dashboard/page.tsx
    profile/page.tsx
```

**Multiple root layouts:**
```
app/
  (marketing)/
    layout.tsx        <- must include <html> and <body>
    page.tsx
  (app)/
    layout.tsx        <- must include <html> and <body>
    dashboard/page.tsx
```

Both groups have full root layouts. Navigating between groups causes a full page load.

### Constraints

- Group folder names are never part of the URL path
- Two groups resolving to the same URL path cause a build error
- Routes inside a group share only that group's layout, not layouts from other groups

---

## Parallel Routes

Named slots `@slotName` render multiple pages simultaneously.

### Definition

```
app/
  layout.tsx          <- receives { children, team, analytics }
  page.tsx            <- default children
  @team/
    page.tsx          <- team slot content
    default.tsx       <- fallback when no match
  @analytics/
    page.tsx          <- analytics slot content
    default.tsx       <- fallback when no match
```

### Layout Props

```tsx
export default function Layout({
  children,
  team,
  analytics,
}: {
  children: React.ReactNode;
  team: React.ReactNode;
  analytics: React.ReactNode;
}) {
  return (
    <div className="grid grid-cols-3">
      <main>{children}</main>
      <aside>{team}</aside>
      <aside>{analytics}</aside>
    </div>
  );
}
```

### default.tsx (Required)

When navigating to a route that has no match for a slot, Next.js renders `default.tsx`. Without it, a 404 is rendered for the entire page.

```tsx
// app/@team/default.tsx
export default function Default() {
  return null; // or a skeleton/placeholder
}
```

### Conditional Slot Rendering

Use `useSelectedLayoutSegment()` inside the layout to conditionally render:

```tsx
"use client";
import { useSelectedLayoutSegment } from "next/navigation";

export default function Layout({ children, modal }) {
  const segment = useSelectedLayoutSegment("modal");
  return (
    <div>
      {children}
      {segment && modal}
    </div>
  );
}
```

### Use Cases

- **Dashboards** -- independent data panels with own loading/error states
- **Modals** -- modal slot alongside main content (with intercepting routes)
- **Independent sub-navigation** -- each slot navigates independently
- **Conditional content** -- show/hide slots based on active route

### Independent Loading/Error States

Each slot can have its own `loading.tsx` and `error.tsx`:

```
app/
  @team/
    loading.tsx       <- loading state for team slot only
    error.tsx         <- error boundary for team slot only
    page.tsx
  @analytics/
    loading.tsx       <- loading state for analytics slot only
    page.tsx
```

---

## Intercepting Routes

Capture navigation to show a route within the current layout (soft nav), while preserving the original full-page route for hard nav.

### Convention

| Prefix | Intercepts relative to... |
|---|---|
| `(.)` | Same level |
| `(..)` | One level up |
| `(..)(..)` | Two levels up |
| `(...)` | Application root (`app/`) |

### Photo Modal Pattern

```
app/
  feed/
    page.tsx                         <- feed page with photo grid
    @modal/
      (.)photos/[id]/
        page.tsx                     <- intercepted: photo in modal overlay
      default.tsx                    <- null (no modal)
  photos/
    [id]/
      page.tsx                       <- full-page photo view
```

**Behavior:**
- Clicking a photo in the feed (soft nav): `(.)photos/[id]` matches -> modal renders over feed. URL updates to `/photos/123`.
- Direct URL visit or refresh (hard nav): interception bypassed -> `photos/[id]/page.tsx` renders as standalone page.
- Shareable URLs with context-preserving modal UX.

### How It Works

1. User clicks a link that triggers client-side navigation
2. Next.js checks if an intercepting route matches at the current position
3. If matched, the intercepting route renders in its slot (e.g., `@modal`)
4. The original route's URL is pushed to the browser history
5. On refresh or direct visit, the non-intercepted route renders normally

### Requirements

- Intercepting routes are typically combined with parallel routes (modal slot)
- The modal slot needs `default.tsx` (returns `null` when no modal is active)
- The intercepting folder must use the correct relative prefix

---

## Route Segment Config

Export these constants from `page.tsx`, `layout.tsx`, or `route.ts` to control rendering behavior:

```ts
// Static rendering -- always render at build time
export const dynamic = "force-static";

// Dynamic rendering -- always render at request time
export const dynamic = "force-dynamic";

// ISR -- revalidate on interval
export const revalidate = 3600; // seconds

// Control dynamicParams for generateStaticParams
export const dynamicParams = true;  // generate on-demand (default)
export const dynamicParams = false; // 404 for unlisted params

// Override fetch cache defaults
export const fetchCache = "force-cache";

// Set runtime
export const runtime = "edge";     // or "nodejs" (default)

// Vercel region selection
export const preferredRegion = "auto";
```
