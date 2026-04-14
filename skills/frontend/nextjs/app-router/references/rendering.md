# App Router Rendering Reference

Server Components, Client Components, streaming, and the rendering pipeline in the Next.js App Router.

---

## Server Components (Default)

All components in `app/` are React Server Components (RSC) by default. They run on the server only.

### Capabilities

- Async/await at the component level
- Direct data fetching (no useEffect, no API layer needed)
- Access to server-only resources (databases, file systems, secrets, environment variables)
- Zero client-side JavaScript footprint
- Can import and render Client Components

### Limitations

- No React hooks (`useState`, `useEffect`, `useContext`, `useReducer`, etc.)
- No browser-only APIs (`window`, `document`, `localStorage`, etc.)
- No event handlers (`onClick`, `onChange`, etc.)
- Cannot be imported by Client Components (can be passed as children/props)

### Example

```tsx
// app/products/page.tsx (Server Component by default)
import { db } from "@/lib/db";

export default async function ProductsPage() {
  const products = await db.products.findMany();
  return (
    <ul>
      {products.map(p => <li key={p.id}>{p.name}</li>)}
    </ul>
  );
}
```

---

## Client Components

Opt in with `"use client"` directive at the top of the file.

### When to Use

- Interactive UI (click handlers, form inputs, toggles)
- React hooks (`useState`, `useEffect`, `useContext`, etc.)
- Browser APIs (`window`, `localStorage`, `IntersectionObserver`, etc.)
- Third-party libraries that use hooks or browser APIs

### Boundary Behavior

The `"use client"` directive creates a boundary. The component and all its imports are included in the client bundle. Server Components cannot be imported below this boundary.

```tsx
"use client";
import { useState } from "react";

export function Counter() {
  const [count, setCount] = useState(0);
  return <button onClick={() => setCount(c => c + 1)}>{count}</button>;
}
```

### Server Components as Children

Client Components CAN receive Server Components as children props:

```tsx
// app/layout.tsx (Server Component)
import { ClientSidebar } from "./Sidebar"; // Client Component
import { ServerFeed } from "./Feed";       // Server Component

export default function Layout({ children }) {
  return (
    <ClientSidebar>
      <ServerFeed />   {/* rendered on server, passed as children */}
    </ClientSidebar>
  );
}
```

### Best Practice: Push "use client" Down

Minimize client bundle by keeping `"use client"` as close to the leaves as possible:

```tsx
// app/page.tsx (Server Component)
import { AddToCart } from "./add-to-cart"; // small Client Component

export default async function ProductPage() {
  const product = await getProduct();
  return (
    <div>
      <h1>{product.name}</h1>           {/* Static -- no JS */}
      <p>{product.description}</p>      {/* Static -- no JS */}
      <AddToCart id={product.id} />     {/* Interactive island */}
    </div>
  );
}
```

---

## RSC Payload and Hydration

### Rendering Pipeline

1. **Server**: React renders Server Components -> RSC payload (compact streaming format)
2. **Server**: RSC payload + Client Component references -> HTML string (SSR)
3. **Network**: HTML streams to browser (early bytes paint fast)
4. **Browser**: HTML renders immediately (no JavaScript needed for initial paint)
5. **Browser**: React loads, reads RSC payload, hydrates Client Component boundaries

### RSC Payload

A compact binary-like format containing:
- Rendered Server Component output
- Placeholders for Client Component locations
- Props passed from Server to Client Components
- References to Client Component JavaScript bundles

Streamed in parallel with HTML for efficient hydration.

---

## Streaming

### How Streaming Works

1. Server begins rendering the React tree top-down
2. Segments that are ready (no async work) flush immediately as HTML
3. Segments behind async data fetches are held at `<Suspense>` boundaries
4. When async work resolves, content streams as subsequent HTML chunks
5. Browser progressively hydrates content as it arrives

### loading.tsx -- Automatic Suspense

`loading.tsx` wraps the segment's `page.tsx` in a `<Suspense>` boundary:

```tsx
// app/dashboard/loading.tsx
export default function Loading() {
  return <DashboardSkeleton />;
}
```

- Shown immediately on navigation
- No code needed -- Next.js inserts the Suspense boundary automatically
- Each segment can have its own `loading.tsx`

### Manual Suspense Boundaries

For granular streaming control within a page:

```tsx
import { Suspense } from "react";

export default function Dashboard() {
  return (
    <div>
      <StaticHeader />                    {/* flushes immediately */}
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />                   {/* streams when ready */}
      </Suspense>
      <Suspense fallback={<InvoicesSkeleton />}>
        <LatestInvoices />                 {/* streams independently */}
      </Suspense>
    </div>
  );
}
```

Each Suspense boundary streams independently -- whichever resolves first is sent first.

---

## Static vs Dynamic Rendering

### Static Rendering (Default)

Pages rendered at build time and cached. Best for content that does not change per request (marketing pages, blog posts, documentation).

Routes are static by default unless they use dynamic APIs.

### Dynamic Rendering

Pages rendered per request. Triggered automatically when a component uses:

- `cookies()`, `headers()` -- reading request-specific data
- `searchParams` -- reading URL query string
- `noStore()` -- explicit opt-out of caching
- Uncached data fetches

### Route Segment Config

```ts
// Force static
export const dynamic = "force-static";

// Force dynamic
export const dynamic = "force-dynamic";

// ISR with revalidation interval
export const revalidate = 3600;
```

### How Next.js Decides

1. Analyze the route for dynamic API usage
2. If any dynamic API is detected: dynamic rendering
3. If no dynamic APIs and all data is cached: static rendering
4. `force-static` / `force-dynamic` overrides automatic detection

---

## Cache Components (v16)

The `"use cache"` directive replaces route-level static/dynamic with function-level caching.

### Philosophy

- No code is cached unless marked with `"use cache"`
- Individual functions or components can be cached independently
- The same page can mix cached and uncached data

### Usage

```ts
import { cacheTag, cacheLife } from "next/cache";

export async function getProduct(id: string) {
  "use cache";
  cacheTag(`product-${id}`);
  cacheLife("hours");
  return await db.products.findById(id);
}
```

### On a Component

```tsx
async function ProductCard({ id }: { id: string }) {
  "use cache";
  cacheTag(`product-${id}`);
  cacheLife("minutes");
  const product = await getProduct(id);
  return <div>{product.name}</div>;
}
```

### Mixed Page

```tsx
export default async function Page({ params }) {
  const { id } = await params;
  const product = await getProduct(id);    // cached via "use cache"
  const stock = await getLiveStock(id);     // dynamic, fresh every request
  return <div>{product.name}: {stock.quantity} in stock</div>;
}
```

### Enable

```ts
// next.config.ts
cacheComponents: true
```

Replaces `experimental.dynamicIO` and `experimental.ppr` from v15.

---

## Error Boundaries

### error.tsx

Wraps the segment in a React Error Boundary. Must be a Client Component:

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
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}
```

### Behavior

- `reset()` re-renders the segment (re-attempts the failed render)
- `error.digest` is a server-side hash for log correlation (actual message not sent to client in production)
- Errors propagate up to the nearest `error.tsx`
- Root-level `app/error.tsx` catches everything not caught by nested boundaries
- `app/global-error.tsx` catches errors in the root layout itself

### not-found.tsx

- Triggered by `notFound()` from `next/navigation`
- Also rendered for URLs that match no route
- `app/not-found.tsx` is the global 404
- Segment-level `not-found.tsx` catches only within that segment
