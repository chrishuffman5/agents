# Next.js Architecture Reference

Cross-version reference covering Next.js 15 and 16.

---

## App Router Model

### Overview

The App Router (stable since Next.js 13.4, fully featured in v15/v16) is the primary routing system. All routes live under the `app/` directory. Each folder represents a route segment; a route is only publicly accessible when a `page.tsx` file exists in its folder.

### Special Files

| File | Purpose |
|---|---|
| `page.tsx` | Unique UI for a route; makes the segment publicly accessible |
| `layout.tsx` | Shared UI wrapping child segments; persists across navigations |
| `loading.tsx` | Instant loading state shown during segment load (wraps in Suspense) |
| `error.tsx` | Error boundary for a segment and its children (must be Client Component) |
| `not-found.tsx` | UI rendered when `notFound()` is thrown within a segment |
| `template.tsx` | Like layout but re-mounts on every navigation (no state persistence) |
| `default.tsx` | Fallback UI for parallel routes that have no active state |
| `route.ts` | API endpoint (Route Handler); cannot coexist with `page.tsx` in same folder |
| `middleware.ts` | Edge/Node middleware (project root or `src/`); not inside `app/` |

### Composition Order (Outermost to Innermost)

```
layout.tsx
  template.tsx (if present)
    error.tsx (Error Boundary)
      loading.tsx (Suspense)
        page.tsx (or nested layout)
```

### Nested Layouts

Layouts are hierarchical. A root layout (`app/layout.tsx`) must define `<html>` and `<body>`. Child layouts wrap only their descendant segments. Layouts do not re-render on navigation between sibling routes -- they persist.

```
app/
  layout.tsx          <- Root layout (wraps everything)
  page.tsx            <- Homepage
  dashboard/
    layout.tsx        <- Dashboard layout (wraps dashboard segments)
    page.tsx          <- /dashboard
    settings/
      page.tsx        <- /dashboard/settings
```

### Route Groups

Parentheses syntax `(groupName)` creates a logical group without affecting the URL path. Useful for organizing routes, applying shared layouts to a subset, and separating authenticated from public routes.

```
app/
  (marketing)/
    layout.tsx        <- Layout only for marketing pages
    about/page.tsx    <- /about
    blog/page.tsx     <- /blog
  (app)/
    layout.tsx        <- Layout only for app pages (requires auth)
    dashboard/page.tsx <- /dashboard
```

Multiple root layouts are possible by placing `layout.tsx` inside different route groups (both must include `<html>` and `<body>`).

### Parallel Routes

Named slots `@slotName` render multiple pages simultaneously within the same layout. Each slot is an independent navigation stream.

```
app/
  layout.tsx          <- Receives { children, modal, sidebar } props
  page.tsx
  @modal/
    page.tsx          <- Rendered in modal slot
  @sidebar/
    page.tsx          <- Rendered in sidebar slot
```

Parallel routes allow conditional rendering of slots, soft navigation within modals, independent loading/error states per slot, and independent sub-navigation.

### Intercepting Routes

Intercepting routes load a route in a different context (e.g., open a photo in a modal while keeping the feed as the background). Uses filesystem conventions relative to the current route segment:

| Convention | Intercepts |
|---|---|
| `(.)segment` | Same level |
| `(..)segment` | One level up |
| `(..)(..)segment` | Two levels up |
| `(...)segment` | From root |

Soft navigation triggers the interception; hard navigation (direct URL, refresh) bypasses it and renders the original full-page route.

---

## Rendering Pipeline

### Server Components (Default)

All components in `app/` are React Server Components (RSC) by default. They run on the server only and have no client-side JavaScript footprint.

Capabilities:
- Async/await at the component level
- Direct data fetching (no useEffect, no API layer needed)
- Access to server-only resources (databases, file systems, secrets)
- Reduced client bundle size

Limitations:
- No React hooks (`useState`, `useEffect`, `useContext`, etc.)
- No browser-only APIs
- No event handlers

### Client Components

Opt in with `"use client"` directive at the top of the file. This creates a boundary -- the component and all its imports are included in the client bundle.

```tsx
"use client";
import { useState } from "react";

export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

Server Components can import and render Client Components, but Client Components cannot import Server Components (they can receive them as props/children).

### RSC Payload and Hydration

The rendering pipeline for a page request:

1. **Server**: React renders Server Components -> produces RSC payload (compact streaming format)
2. **Server**: RSC payload + Client Component tree -> HTML string (SSR)
3. **Network**: HTML streams to browser (early bytes paint fast)
4. **Browser**: HTML renders immediately (no JS needed for initial paint)
5. **Browser**: React loads, reads RSC payload, hydrates Client Component boundaries

### Streaming with Suspense

Wrap slow data-fetching components in `<Suspense>` to stream content progressively. Next.js maps `loading.tsx` to an automatic Suspense boundary for the entire segment.

```tsx
import { Suspense } from "react";

export default function Page() {
  return (
    <main>
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />
      </Suspense>
      <Suspense fallback={<InvoicesSkeleton />}>
        <LatestInvoices />
      </Suspense>
    </main>
  );
}
```

Each Suspense boundary streams independently -- fast components appear while slow ones still load.

### Static vs Dynamic Rendering

**Static rendering** (default for most routes): Pages rendered at build time and cached. Best for content that does not change per request.

**Dynamic rendering**: Pages rendered per request. Triggered automatically when a component uses:
- `cookies()`, `headers()` -- reading request data
- `searchParams` -- reading URL query string
- `noStore()` -- explicit opt-out
- Uncached data fetches

**Route segment config overrides:**

```ts
export const dynamic = "force-static";    // always render at build time
export const dynamic = "force-dynamic";   // always render at request time
export const revalidate = 3600;           // ISR with revalidation interval
```

---

## Caching Model

### Layer 1: Request Memoization

**Scope**: Single request lifecycle.
**Purpose**: Deduplicates identical `fetch()` calls within one render tree.
**Behavior**: If two Server Components in the same request fetch the same URL with the same options, only one network request is made. React memoizes the result for the duration of that request.
**Opt out**: Automatic, no configuration needed.

### Layer 2: Data Cache

**Scope**: Persistent across requests and deployments.
**Purpose**: Caches `fetch()` responses server-side.
**Storage**: File system (self-hosted) or Vercel shared cache.
**Control**:

```ts
fetch(url, { cache: "force-cache" });          // cache indefinitely
fetch(url, { cache: "no-store" });             // never cache
fetch(url, { next: { revalidate: 3600 } });    // time-based revalidation
fetch(url, { next: { tags: ["products"] } });  // tag-based invalidation
```

### Layer 3: Full Route Cache

**Scope**: Persistent, build-time or revalidation-time.
**Purpose**: Caches the complete HTML + RSC payload for statically rendered routes.
**Invalidation**: Triggered by `revalidatePath()`, `revalidateTag()`, or time-based `revalidate` config.

### Layer 4: Router Cache (Client-Side)

**Scope**: Browser session memory.
**Purpose**: Caches visited and prefetched route segments client-side.
**Behavior**: Prevents redundant server requests when navigating back/forward or to previously visited routes.

### Version Differences

| Behavior | v14 | v15+ |
|---|---|---|
| `fetch()` default | `force-cache` | `no-store` |
| GET Route Handlers | Cached | Not cached |
| Client Router Cache (dynamic) | 30s staleness | 0s (always revalidates) |
| Client Router Cache (static) | 5min staleness | 0s (always revalidates) |

### On-Demand Revalidation

```ts
import { revalidateTag, revalidatePath } from "next/cache";

export async function POST(request: Request) {
  const { tag, path } = await request.json();
  if (tag) revalidateTag(tag);
  if (path) revalidatePath(path);
  return Response.json({ revalidated: true });
}
```

### Cache Components (v16)

The `"use cache"` directive provides fine-grained, function-level caching:

```ts
import { cacheTag, cacheLife } from "next/cache";

export async function getProduct(id: string) {
  "use cache";
  cacheTag(`product-${id}`);
  cacheLife("hours");
  return await db.products.findById(id);
}
```

Replaces route-level static/dynamic choice with per-function/per-component caching. Enabled via `cacheComponents: true` in `next.config.ts`.

---

## Server Actions

### Overview

Server Actions are async functions marked with `"use server"` that execute on the server. They are invoked from Client Components and are the primary mutation pattern in the App Router.

Under the hood, Server Actions become POST requests. Next.js generates unguessable action IDs to reference them -- the function body is never exposed to the client.

### Defining Server Actions

**In a server-only file (recommended for reuse):**

```ts
// app/actions.ts
"use server";

export async function createInvoice(formData: FormData) {
  const amount = formData.get("amount");
  await db.invoices.create({ data: { amount } });
  revalidatePath("/dashboard/invoices");
}
```

**Inline in a Server Component:**

```tsx
export default function Page() {
  async function create(formData: FormData) {
    "use server";
    // mutation logic
  }
  return <form action={create}>...</form>;
}
```

### Progressive Enhancement

When `<form action={serverAction}>` is used, forms work without JavaScript. The browser submits a native form POST. Once JS loads, React intercepts and enhances with client-side handling.

### Triggering Revalidation

```ts
"use server";
import { revalidatePath, revalidateTag } from "next/cache";
import { redirect } from "next/navigation";

export async function updateProduct(id: string, data: FormData) {
  await db.products.update(id, data);
  revalidateTag("products");
  revalidatePath("/products");
  redirect("/products");
}
```

### Security Considerations

- Server Actions are POST endpoints -- validate and authenticate inputs
- Use `server-only` package to ensure action files are never bundled for client
- Action IDs are cryptographically unpredictable but actions are still publicly callable -- always authorize within the action body
- v15+ uses dead code elimination: unused Server Actions are removed from the client bundle entirely

---

## Middleware and Proxy

### Overview

Middleware runs before route matching and before the cache is checked. Use for authentication, redirects, header injection, A/B testing, geolocation.

### v15 vs v16 Runtime

| Version | Runtime | File |
|---|---|---|
| v15 | Edge Runtime (V8 isolates) | `middleware.ts` (project root or `src/`) |
| v16 | Node.js Runtime | `proxy.ts` (project root) |

Edge Runtime: runs in V8 isolates globally distributed; 30s timeout; no Node.js APIs.
Node.js Runtime (v16): full Node.js API access; longer timeout; runs at origin only.

### Matcher Configuration

```ts
export const config = {
  matcher: [
    "/dashboard/:path*",
    "/((?!_next/static|_next/image|favicon.ico|api/health).*)",
  ],
};
```

### Common Operations

```ts
// Rewrite (internal, URL unchanged in browser)
return NextResponse.rewrite(new URL("/new-path", request.url));

// Redirect (301/302, URL changes in browser)
return NextResponse.redirect(new URL("/login", request.url), 302);

// Add response headers
const response = NextResponse.next();
response.headers.set("X-Custom-Header", "value");
return response;
```

---

## Data Fetching Patterns

### fetch() in Server Components

The primary data fetching method, extended by Next.js with caching controls:

```tsx
export default async function ProductsPage() {
  // v15+ default: not cached
  const products = await fetch("https://api.example.com/products").then(r => r.json());

  // Explicit caching with tags
  const config = await fetch("https://api.example.com/config", {
    cache: "force-cache",
    next: { tags: ["config"] },
  }).then(r => r.json());

  return <ProductList products={products} />;
}
```

### generateStaticParams (SSG)

Pre-render dynamic routes at build time:

```tsx
export async function generateStaticParams() {
  const posts = await fetch("https://api.example.com/posts").then(r => r.json());
  return posts.map((post: { slug: string }) => ({ slug: post.slug }));
}
```

### ISR (Incremental Static Regeneration)

```ts
export const revalidate = 3600;       // time-based: every hour
export const revalidate = false;      // on-demand only via revalidateTag/revalidatePath
```

### Route Handlers

```ts
// app/api/products/route.ts
export async function GET(request: Request) {
  const products = await db.products.findMany();
  return NextResponse.json(products);
}

export async function POST(request: Request) {
  const body = await request.json();
  const product = await db.products.create({ data: body });
  return NextResponse.json(product, { status: 201 });
}
```

### ORM / Database Access

Server Components can query databases directly -- no API layer needed:

```tsx
import { db } from "@/lib/db";

export default async function DashboardPage() {
  const [revenue, invoices] = await Promise.all([
    db.revenue.findMany(),
    db.invoices.findLatest(5),
  ]);
  return <Dashboard revenue={revenue} invoices={invoices} />;
}
```

---

## Turbopack

### Overview

Rust-based incremental bundler embedded in Next.js as the successor to webpack.

| Version | Dev | Production |
|---|---|---|
| Next.js 15 | Stable (`--turbo` flag) | Alpha |
| Next.js 16 | Stable (default) | Stable (default) |

### Performance

- Cold start: significantly faster than webpack for large projects (often 10x+)
- HMR: near-instant updates -- only changed modules recompiled
- Incremental computation: work cached and reused across builds
- File System Caching (v16 beta): persists to disk across dev server restarts

### Webpack Compatibility

- Does not run webpack plugins or loaders directly
- Most common use cases covered by built-in transforms
- `webpack()` customizations in next.config.js may need migration to `turbopack` config section

```ts
// next.config.ts -- Turbopack-specific config
turbopack: {
  rules: {
    "*.svg": {
      loaders: ["@svgr/webpack"],
      as: "*.js",
    },
  },
  resolveAlias: {
    "@/lib": "./src/lib",
  },
}
```

### Babel Detection

Turbopack auto-detects `babel.config.js` / `.babelrc` and applies Babel transforms when present. This adds overhead -- prefer SWC transforms where possible.

---

## Metadata API

### Static Metadata

```tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "My Blog",
  description: "Articles about web development",
  openGraph: {
    title: "My Blog",
    images: [{ url: "/og-image.png", width: 1200, height: 630 }],
  },
};
```

### Dynamic Metadata

```tsx
export async function generateMetadata(
  { params }: { params: { slug: string } },
  parent: ResolvingMetadata
): Promise<Metadata> {
  const post = await fetch(`https://api.example.com/posts/${params.slug}`).then(r => r.json());
  return {
    title: post.title,
    description: post.excerpt,
  };
}
```

### Metadata Inheritance

Metadata merges from root layout down to the page. Child values override parent values for the same key. Use `title.template` for site-wide title patterns:

```tsx
// app/layout.tsx
export const metadata: Metadata = {
  title: { template: "%s | My Site", default: "My Site" },
};

// app/about/page.tsx
export const metadata: Metadata = {
  title: "About",  // Renders as "About | My Site"
};
```

### Sitemap and Robots

```ts
// app/sitemap.ts
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: "https://example.com", lastModified: new Date() },
    { url: "https://example.com/about", lastModified: new Date() },
  ];
}

// app/robots.ts
export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: "*", allow: "/", disallow: "/private/" },
    sitemap: "https://example.com/sitemap.xml",
  };
}
```
