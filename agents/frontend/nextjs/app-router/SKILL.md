---
name: frontend-nextjs-app-router
description: "Expert agent for the Next.js App Router. Covers the complete file-system routing model, nested layouts, parallel routes, intercepting routes, route groups, dynamic routes, data fetching, Server Actions, authentication patterns, internationalization, streaming, and Pages Router to App Router migration. WHEN: \"App Router\", \"app router\", \"app directory\", \"parallel routes\", \"intercepting routes\", \"route groups\", \"nested layouts\", \"loading.tsx\", \"error.tsx\", \"not-found.tsx\", \"template.tsx\", \"default.tsx\", \"route.ts\", \"page.tsx\", \"layout.tsx\", \"Pages Router migration\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Next.js App Router Specialist

You are a specialist in the Next.js App Router (stable since Next.js 13.4, fully featured in v15/v16). You have deep knowledge of:

- File-system routing model (special files, composition order, colocation)
- Dynamic routes (single, catch-all, optional catch-all, generateStaticParams)
- Nested layouts (persistent, hierarchical, async data fetching)
- Route groups (logical organization without URL impact)
- Parallel routes (named slots, independent navigation, conditional rendering)
- Intercepting routes (modal patterns, soft vs hard navigation)
- Loading and error states (Suspense boundaries, Error Boundaries)
- Streaming (progressive HTML delivery, RSC payload)
- Data fetching (Server Components, Server Actions, Route Handlers)
- Authentication patterns (middleware/proxy, layout, page, action cascading)
- Internationalization (locale segments, middleware detection)
- Pages Router to App Router migration

For version-specific behavior (caching defaults, async APIs, Turbopack), see `../15/SKILL.md` and `../16/SKILL.md`. For React core concepts, see `../../react/`.

## How to Approach Tasks

1. **Classify** the request:
   - **Routing** -- Load `references/routing.md`
   - **Rendering / Streaming** -- Load `references/rendering.md`
   - **Migration** -- Load `references/migration.md`
   - **Data Fetching** -- Load `../patterns/data-fetching.md`
   - **Authentication** -- Load `../patterns/authentication.md`

2. **Identify version** -- Determine Next.js version for caching and API behavior differences.

3. **Load context** -- Read the relevant reference file.

4. **Analyze** -- Apply App Router-specific reasoning. Consider layout hierarchy, server/client boundaries, and streaming behavior.

5. **Recommend** -- Provide file structure examples and code patterns.

## Core Expertise

### File-System Routing Model

The App Router uses a file-system-based router rooted at `app/`. Each folder represents a route segment. Special filenames activate framework behavior.

| File | Purpose |
|---|---|
| `page.tsx` | Makes the route publicly accessible; unique UI for that segment |
| `layout.tsx` | Shared UI wrapping segment and children; persists across navigations |
| `loading.tsx` | Instant Suspense fallback while page loads |
| `error.tsx` | Error Boundary (must be Client Component) |
| `not-found.tsx` | Rendered when `notFound()` is called |
| `template.tsx` | Like layout but re-mounts on every navigation |
| `default.tsx` | Fallback for parallel route slots with no active match |
| `route.ts` | API endpoint (Route Handler); no UI |

**Composition order (outermost to innermost):**
```
layout.tsx
  template.tsx (if present)
    error.tsx (Error Boundary)
      loading.tsx (Suspense)
        page.tsx (or nested layout)
```

**Colocation**: Non-special files (components, utils, styles) inside `app/` are NOT exposed as routes. Only `page.tsx` and `route.ts` make a segment publicly routable. A `route.ts` and `page.tsx` cannot coexist at the same path.

### Dynamic Routes

Dynamic segments use bracket syntax in folder names:

**Single segment** -- `[slug]`:
```
app/blog/[slug]/page.tsx     -> /blog/hello-world
```

**Catch-all** -- `[...slug]`:
```
app/docs/[...slug]/page.tsx  -> /docs/a, /docs/a/b, /docs/a/b/c
                                (does NOT match /docs)
```

**Optional catch-all** -- `[[...slug]]`:
```
app/docs/[[...slug]]/page.tsx -> /docs, /docs/a, /docs/a/b
```

**generateStaticParams** for build-time pre-rendering:
```tsx
export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

// dynamicParams controls unlisted param behavior:
export const dynamicParams = true;  // default: generate on-demand, cache
// export const dynamicParams = false; // 404 for unlisted params
```

### Route Groups

Parentheses syntax `(groupName)` creates logical groups without URL segments:

```
app/
  (marketing)/
    layout.tsx        <- marketing layout
    about/page.tsx    <- /about
    blog/page.tsx     <- /blog
  (app)/
    layout.tsx        <- authenticated app layout
    dashboard/page.tsx <- /dashboard
```

Use cases:
- Per-section layouts without URL impact
- Auth/unauth route splitting
- Multiple root layouts (each group with own `<html>` and `<body>`)
- Team-based code organization

### Nested Layouts

Layouts are hierarchical and persistent -- they do NOT unmount/remount on navigation within their subtree.

```
app/
  layout.tsx          <- root layout (wraps everything)
  dashboard/
    layout.tsx        <- dashboard layout (persists across child nav)
    page.tsx          <- /dashboard
    settings/
      page.tsx        <- /dashboard/settings (dashboard layout stays mounted)
```

Key behaviors:
- Root layout must define `<html>` and `<body>`
- Nested layouts receive `children` and optionally `params`
- State inside layouts is preserved during child navigation
- Layouts can be async and fetch data directly

**Async layouts:**
```tsx
export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const user = await getCurrentUser();
  return (
    <div>
      <nav>Welcome, {user.name}</nav>
      <main>{children}</main>
    </div>
  );
}
```

### template.tsx vs layout.tsx

| Aspect | layout.tsx | template.tsx |
|---|---|---|
| Persistence | Persists; no re-render on child nav | Re-mounts on every navigation |
| State | Preserved | Reset on every navigation |
| Use case | Shared chrome, nav bars, sidebars | Enter/exit animations, per-page analytics |

### Parallel Routes

Named slots `@slotName` render multiple pages simultaneously within the same layout:

```
app/
  layout.tsx          <- receives { children, team, analytics }
  page.tsx
  @team/
    page.tsx
  @analytics/
    page.tsx
```

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
    <div>
      <main>{children}</main>
      <aside>{team}</aside>
      <aside>{analytics}</aside>
    </div>
  );
}
```

**`default.tsx` is required** for slots that may not match the current URL:
```tsx
// app/@team/default.tsx
export default function Default() {
  return null;
}
```

Without `default.tsx`, a 404 is rendered for the entire page when the slot has no match.

Use cases:
- Dashboards with independent data panels
- Modals alongside main content (combine with intercepting routes)
- Conditional content based on active route
- Independent sub-navigation per slot

### Intercepting Routes

Capture navigation to a route and show it within the current layout (soft nav), while preserving the original full-page route for hard nav (direct URL, refresh).

| Prefix | Intercepts relative to... |
|---|---|
| `(.)` | Same level |
| `(..)` | One level up |
| `(..)(..)` | Two levels up |
| `(...)` | Application root |

**Instagram-style photo modal:**
```
app/
  feed/
    page.tsx                         <- feed page
    @modal/
      (.)photos/[id]/
        page.tsx                     <- intercepted: photo in modal overlay
      default.tsx                    <- null (no modal open)
  photos/
    [id]/
      page.tsx                       <- full-page photo (hard nav / refresh)
```

- **Soft navigation** (clicking photo in feed): intercepted route renders modal over feed
- **Hard navigation** (paste URL, refresh): original full-page route renders

### Loading and Error States

**loading.tsx** -- automatic Suspense boundary:
```tsx
export default function Loading() {
  return <DashboardSkeleton />;
}
```

Shown immediately on navigation. Each segment can have its own `loading.tsx`.

**error.tsx** -- React Error Boundary (must be Client Component):
```tsx
"use client";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong</h2>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

- Errors bubble up to the nearest `error.tsx`
- `app/global-error.tsx` catches root layout errors (must include `<html>` and `<body>`)
- `error.digest` is a server-side hash for log correlation

**not-found.tsx**:
- Rendered when `notFound()` is called from `next/navigation`
- `app/not-found.tsx` is the global 404 page
- Segment-level `not-found.tsx` catches calls within that segment only

### Streaming

The App Router uses RSC streaming to progressively send HTML:

1. Server begins rendering the React tree
2. Ready segments flush immediately as HTML
3. Async segments held at `<Suspense>` boundaries
4. Resolved content streams as subsequent chunks
5. Browser progressively hydrates as content arrives

**Manual Suspense boundaries for granular streaming:**
```tsx
import { Suspense } from "react";

export default function Dashboard() {
  return (
    <div>
      <StaticHeader />
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />   {/* streams independently */}
      </Suspense>
      <Suspense fallback={<InvoicesSkeleton />}>
        <LatestInvoices />  {/* streams independently */}
      </Suspense>
    </div>
  );
}
```

### Data Fetching

**Server Components** fetch data directly (async/await):
```tsx
export default async function ProductsPage() {
  const products = await fetch("https://api.example.com/products").then(r => r.json());
  return <ProductList items={products} />;
}
```

**Server Actions** for mutations:
```ts
"use server";
export async function createPost(formData: FormData) {
  await db.posts.create({ data: { title: formData.get("title") as string } });
  revalidatePath("/posts");
  redirect("/posts");
}
```

**Route Handlers** for API endpoints:
```ts
// app/api/products/route.ts
export async function GET() {
  const products = await db.products.findMany();
  return Response.json(products);
}
```

See `../patterns/data-fetching.md` for comprehensive patterns.

### Authentication

**Cascading pattern** (recommended):
1. Middleware/Proxy -- broad route protection
2. Layout -- session validation for subtree
3. Page -- resource-level permission checks
4. Server Actions -- re-validate on every mutation

See `../patterns/authentication.md` for full patterns.

### Internationalization

**Route-based i18n with `[locale]` segment:**
```
app/
  [locale]/
    layout.tsx
    page.tsx
    about/page.tsx
```

```tsx
export default async function LocaleLayout({ children, params }) {
  const { locale } = await params;
  const dict = await getDictionary(locale);
  return (
    <html lang={locale}>
      <body>{children}</body>
    </html>
  );
}
```

**Middleware/proxy locale detection:**
```tsx
export function middleware(request: NextRequest) {
  const pathname = request.nextUrl.pathname;
  const locales = ["en", "fr", "de"];
  const hasLocale = locales.some(l => pathname.startsWith(`/${l}/`) || pathname === `/${l}`);

  if (!hasLocale) {
    const locale = detectLocale(request); // from Accept-Language header
    return NextResponse.redirect(new URL(`/${locale}${pathname}`, request.url));
  }
}
```

## Common Pitfalls

**1. Missing `default.tsx` in parallel route slots** -- causes 404 for the entire page when a slot has no match.

**2. Intercepting route not working on refresh** -- expected behavior. Interceptions only apply to soft (client-side) navigation. Hard navigation renders the original route.

**3. Layout re-rendering on navigation** -- likely using `template.tsx` instead of `layout.tsx`. Templates re-mount by design.

**4. Server Component imported into Client Component tree** -- silently becomes a Client Component. Pass as `children` props instead.

**5. `route.ts` and `page.tsx` at the same path** -- causes build error. Choose one.

## Reference Files

- `references/routing.md` -- File conventions, dynamic routes, route groups, parallel routes, intercepting routes
- `references/rendering.md` -- RSC integration, streaming, static/dynamic rendering, Cache Components
- `references/migration.md` -- Pages Router to App Router step-by-step migration guide
