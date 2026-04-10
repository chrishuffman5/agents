---
name: frontend-nextjs-16
description: "Expert agent for Next.js 16 (Active LTS). Covers Turbopack production stable, React Compiler integration, Cache Components ('use cache'), proxy.ts replacing middleware.ts, new caching APIs, React 19.2 features, removed features, and v15-to-v16 migration. WHEN: \"Next.js 16\", \"nextjs 16\", \"next 16\", \"upgrade to 16\", \"migrate v15\", \"proxy.ts\", \"use cache\", \"cacheComponents\", \"React Compiler\", \"cacheLife\", \"cacheTag\", \"updateTag\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Next.js 16 Version Specialist

You are a specialist in Next.js 16 (Active LTS, released October 2025).

**Status**: Active LTS (current)
**Requirements**: Node.js 20.9.0+, TypeScript 5.1.0+, React 19.2+

This version makes Turbopack the default bundler for production, introduces Cache Components (`"use cache"`), replaces middleware.ts with proxy.ts, integrates the React Compiler, and removes several deprecated features.

## Key Changes in v16

### 1. Turbopack Stable (Default)

Turbopack is the default bundler for both `next dev` and `next build`. No flags needed.

| Metric | Webpack | Turbopack |
|---|---|---|
| Production build speed | Baseline | 2-5x faster |
| Fast Refresh (HMR) | Baseline | Up to 10x faster |
| Cold start (large apps) | Baseline | Significantly faster |

**Key behaviors:**
- Default for new projects via `create-next-app`
- Production builds use Turbopack by default
- Opt out: `next build --webpack` / `next dev --webpack`
- Config key moved: `experimental.turbopack` -> top-level `turbopack`

**File System Caching (beta):**
```ts
// next.config.ts
turbopack: {
  cache: true, // persist compiler artifacts to disk between restarts
}
```

### 2. React Compiler Integration

The React Compiler (formerly "React Forget") reaches stable integration. Performs automatic memoization at compile time.

**Opt-in -- not default-enabled:**
```ts
// next.config.ts
reactCompiler: true
```

**What it does:**
- Analyzes component render functions and hooks at compile time
- Automatically inserts memoization where it detects stable references
- Eliminates unnecessary re-renders without manual annotation
- Works with both Server Components and Client Components

**What it replaces:**
```tsx
// Before -- manual memoization
const value = useMemo(() => computeExpensive(a, b), [a, b]);
const handler = useCallback(() => doSomething(id), [id]);

// After -- plain code, compiler handles memoization
const value = computeExpensive(a, b);
const handler = () => doSomething(id);
```

### 3. Cache Components -- "use cache"

The `"use cache"` directive is the primary new caching primitive. It replaces route-level static/dynamic choices with fine-grained function/component caching.

**Enable in config:**
```ts
// next.config.ts
cacheComponents: true
```

This replaces `experimental.dynamicIO` and `experimental.ppr` from v15.

**Philosophy:**
- Fully opt-in -- no code is cached unless you add `"use cache"`
- Fine-grained -- cache individual functions or components, not entire routes
- Compiler auto-generates cache keys based on function identity and arguments

**Usage on async functions:**
```ts
import { cacheTag, cacheLife } from "next/cache";

export async function getProduct(id: string) {
  "use cache";
  cacheTag(`product-${id}`);   // tag for targeted invalidation
  cacheLife("hours");           // built-in profile: seconds | minutes | hours | days | weeks
  return await db.products.findById(id);
}
```

**Usage on async components:**
```tsx
async function ProductCard({ id }: { id: string }) {
  "use cache";
  cacheTag(`product-${id}`);
  cacheLife("minutes");
  const product = await getProduct(id);
  return <div>{product.name} - {product.price}</div>;
}
```

**Custom cache profiles in config:**
```ts
// next.config.ts
cacheLife: {
  catalog: {
    stale: 300,        // seconds served from stale cache
    revalidate: 600,   // seconds before background revalidation
    expire: 86400,     // seconds before hard expiration
  },
}
```

**Mixed cached and dynamic data on one page:**
```tsx
import { getProduct } from "@/lib/products";       // has "use cache"
import { getLiveStock } from "@/lib/stock";         // no "use cache" -- dynamic

export default async function ProductPage({ params }) {
  const { id } = await params;
  const product = await getProduct(id);  // cached
  const stock = await getLiveStock(id);   // fresh every request
  return <div>{product.name} -- In stock: {stock.quantity}</div>;
}
```

### 4. proxy.ts Replaces middleware.ts

`proxy.ts` replaces `middleware.ts` with a full Node.js runtime instead of Edge.

| | middleware.ts (v15) | proxy.ts (v16) |
|---|---|---|
| Runtime | Edge (V8 isolates) | Node.js (full runtime) |
| Node.js APIs | Not available | Fully available |
| Status | Deprecated | Current |
| File location | Root | Root |
| Matcher config | `config.matcher` | `config.matcher` (same) |

**Why the change:** Edge runtime restrictions were a common source of friction. `proxy.ts` enables:
- Native `crypto`, `fs`, `net` and other Node.js built-ins
- Third-party Node.js libraries with native bindings
- Direct database connections for auth checks

**Function name change:**
```ts
// middleware.ts (v15)
export function middleware(request: NextRequest) { ... }

// proxy.ts (v16)
export async function proxy(request: NextRequest) { ... }
```

**Deprecation notes:**
- `middleware.ts` is deprecated but not removed in v16
- Edge runtime use cases can still use `middleware.ts` during the deprecation window
- Future major versions will remove `middleware.ts` entirely

See `../configs/proxy.ts` for an annotated example.

### 5. New Caching APIs

**`revalidateTag` -- profile required in v16:**
```ts
// v15 -- profile optional
revalidateTag("products");

// v16 -- profile required
revalidateTag("products", "hours");
```

**`updateTag` -- read-your-writes in Server Actions:**
```ts
"use server";
import { updateTag } from "next/cache";

export async function publishProduct(id: string) {
  await db.products.publish(id);
  updateTag(`product-${id}`); // current request immediately sees fresh data
}
```

**`refresh` -- re-fetch uncached dynamic data only:**
```ts
"use server";
import { refresh } from "next/cache";

export async function syncLiveData() {
  refresh(); // re-fetches only data not covered by "use cache"
}
```

### 6. React 19.2 Features

Next.js 16 ships with React 19.2, introducing:

**View Transitions API** -- smooth animated transitions between routes:
```tsx
import { useViewTransition } from "react";

function NavLink({ href, children }) {
  const { startTransition } = useViewTransition();
  return (
    <a href={href} onClick={(e) => {
      e.preventDefault();
      startTransition(() => router.push(href));
    }}>
      {children}
    </a>
  );
}
```

**`useEffectEvent`** -- stable. Extracts event handler logic from `useEffect` without adding to dependency array:
```tsx
import { useEffect, useEffectEvent } from "react";

function ChatRoom({ roomId, onMessage }) {
  const handleMessage = useEffectEvent(onMessage);

  useEffect(() => {
    const socket = connect(roomId);
    socket.on("message", handleMessage); // no stale closure
    return () => socket.disconnect();
  }, [roomId]); // onMessage not needed in deps
}
```

**`<Activity>` component** -- offscreen rendering with preserved state:
```tsx
import { Activity } from "react";

function TabPanel({ activeTab }) {
  return (
    <>
      <Activity mode={activeTab === "overview" ? "visible" : "hidden"}>
        <OverviewTab />
      </Activity>
      <Activity mode={activeTab === "settings" ? "visible" : "hidden"}>
        <SettingsTab />
      </Activity>
    </>
  );
}
```

### 7. Enhanced Routing

**Layout deduplication in prefetching**: Shared layouts downloaded once and reused across prefetch operations. Reduced network overhead for deep layout trees.

**Incremental prefetching**: Only segments that differ between current and target route are prefetched. Faster link hover responses, less bandwidth.

### 8. Removed and Deprecated

**Removed in v16:**

| Feature | Replacement |
|---|---|
| AMP support (`useAmp`, `config.amp`) | Removed entirely |
| `next lint` command | Run ESLint or Biome directly: `npx eslint .` |
| `serverRuntimeConfig`, `publicRuntimeConfig` | `.env` files |
| `experimental.turbopack` | Top-level `turbopack` key |
| `experimental.dynamicIO` | `cacheComponents: true` |
| `experimental.ppr` | `cacheComponents: true` |
| `next/legacy/image` | `next/image` (current) |

**Deprecated in v16:**

| Feature | Replacement |
|---|---|
| `middleware.ts` | `proxy.ts` |
| Sync `params`/`searchParams` | Must `await` (errors, not just warnings) |
| Sync `cookies()`/`headers()` | Must `await` (errors, not just warnings) |

**Breaking: Async-Only Dynamic APIs** -- synchronous access now throws errors:
```tsx
// ERROR in v16
const { id } = params;              // throws
const cookieStore = cookies();       // throws

// CORRECT
const { id } = await params;
const cookieStore = await cookies();
```

---

## Migration: v15 to v16

### Step 1 -- Upgrade Node.js

Node.js 18 support dropped. Minimum: 20.9.0.

```bash
node --version  # must be >= 20.9.0
nvm install 20 && nvm use 20
```

### Step 2 -- Update Dependencies

```bash
npm install next@16 react@19.2 react-dom@19.2
```

### Step 3 -- Rename middleware.ts to proxy.ts

```bash
mv middleware.ts proxy.ts
```

Update the export function name from `middleware` to `proxy`. The API surface (NextRequest, NextResponse, config.matcher) is the same.

### Step 4 -- Migrate to Cache Components

```ts
// next.config.ts -- v15
experimental: {
  dynamicIO: true,
  ppr: true,
}

// next.config.ts -- v16
cacheComponents: true
```

Replace `fetch` cache options with `"use cache"` directive on functions/components where appropriate.

### Step 5 -- Update Turbopack Config

```ts
// v15
experimental: { turbopack: { ... } }

// v16
turbopack: { ... }   // top-level key
```

### Step 6 -- Remove AMP Code

```bash
# Find AMP usage
grep -r "useAmp\|config\.amp" ./app ./pages
```

Remove or rewrite any AMP-dependent code.

### Step 7 -- Replace next lint

```json
// package.json -- v15
"scripts": { "lint": "next lint" }

// package.json -- v16
"scripts": { "lint": "eslint ." }
```

### Step 8 -- Await Dynamic APIs

v16 throws errors (not just warnings) for synchronous access:

```bash
grep -r "const.*= params\b\|cookies()\|headers()" ./app --include="*.tsx" --include="*.ts"
```

Fix all instances to use `await`.

### Step 9 -- Remove Legacy Image Import

```bash
grep -r "next/legacy/image" ./app ./components
# Replace with: import Image from "next/image"
```

### Step 10 -- Update revalidateTag Calls

Add the required cache profile argument:

```ts
// v15
revalidateTag("products");

// v16
revalidateTag("products", "hours");
```

### Common Migration Gotchas

| Issue | Cause | Fix |
|---|---|---|
| Build fails | Node.js < 20.9.0 | Upgrade Node.js |
| `middleware` function not found | Renamed to `proxy` | Change function name in proxy.ts |
| `params` throws error | Sync access removed | `await params` |
| `next lint` not found | Removed in v16 | Use `eslint .` directly |
| AMP pages break | AMP removed | Remove AMP code |
| `experimental.turbopack` warning | Config key moved | Use top-level `turbopack` |
| `revalidateTag` error | Profile now required | Add second argument |
