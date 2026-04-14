---
name: frontend-nextjs-15
description: "Expert agent for Next.js 15 (Maintenance LTS). Covers Turbopack dev stable, React 19 support, async request APIs (breaking), caching defaults reversed (breaking), Form component, instrumentation stable, Server Actions security, self-hosting improvements, and v14-to-v15 migration. WHEN: \"Next.js 15\", \"nextjs 15\", \"next 15\", \"upgrade to 15\", \"migrate v14\", \"async cookies\", \"async params\", \"caching defaults\", \"next dev --turbo\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Next.js 15 Version Specialist

You are a specialist in Next.js 15 (Maintenance LTS, released October 2024, EOL October 2026).

**Status**: Maintenance LTS
**Requirements**: Node.js 18.18.0+, React 19 RC (App Router) or React 18 (Pages Router)

This version introduced significant breaking changes: async request APIs, reversed caching defaults, and Turbopack dev as stable. Migrations from v14 require careful attention.

## Key Changes in v15

### 1. Turbopack Dev Stable

`next dev --turbo` is now stable. Turbopack Builds remain alpha only.

**Performance vs Webpack:**
- 76.7% faster local server startup
- 96.3% faster Fast Refresh (HMR)
- 45.8% faster initial route compilation

```bash
# Development (stable)
next dev --turbo

# Or set in package.json
{
  "scripts": {
    "dev": "next dev --turbo"
  }
}
```

**Turbopack Builds (alpha -- not production-ready):**
```bash
next build --turbo
```

Notes:
- Turbopack is the recommended dev bundler; Webpack remains available
- Some Webpack-specific plugins/loaders may not be compatible
- Check the Turbopack compatibility page for projects with custom webpack configs

### 2. React 19 Support

**App Router**: Runs on React 19 RC by default.
**Pages Router**: Backward compatible with React 18. React 19 is opt-in.

New React 19 capabilities in App Router:
- `use()` hook for reading promises and context
- Actions and `useActionState` for form handling
- `useOptimistic` for optimistic UI
- Native `<form>` action support
- Server Components improvements

```json
// App Router
{
  "react": "^19.0.0-rc",
  "react-dom": "^19.0.0-rc",
  "next": "^15.0.0"
}

// Pages Router (stay on React 18)
{
  "react": "^18.3.0",
  "react-dom": "^18.3.0",
  "next": "^15.0.0"
}
```

### 3. Async Request APIs (Breaking)

`cookies()`, `headers()`, `draftMode()`, route segment `params`, and page `searchParams` are now **async** and must be awaited. Synchronous access triggers deprecation warnings (errors in v16).

**Before (v14 -- synchronous):**
```tsx
import { cookies, headers } from "next/headers";

export default function Page({ params, searchParams }) {
  const cookieStore = cookies();
  const id = params.id;
  const query = searchParams.q;
}
```

**After (v15 -- async):**
```tsx
import { cookies, headers } from "next/headers";

export default async function Page({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ q: string }>;
}) {
  const cookieStore = await cookies();
  const headersList = await headers();
  const { id } = await params;
  const { q } = await searchParams;
}
```

**Automated codemod:**
```bash
npx @next/codemod@canary next-async-request-api .
```

The codemod handles most cases. Review generated code, especially where params/searchParams are passed as props down the tree.

**Middleware is unchanged** -- `request.cookies` and `request.headers` remain synchronous in middleware.

### 4. Caching Defaults Reversed (Breaking)

Everything that was cached by default is now uncached by default -- opt-in to caching explicitly.

| Behavior | v14 Default | v15 Default |
|---|---|---|
| GET Route Handlers | Cached | Not cached |
| `fetch()` requests | `force-cache` | `no-store` |
| Client Router Cache (`staleTime`) | 30 seconds | 0 seconds |

**GET Route Handlers:**
```ts
// v15 -- NOT cached by default. Opt in:
export const dynamic = "force-static";

export async function GET() {
  const data = await fetchFromDB();
  return Response.json(data);
}
```

**fetch() Requests:**
```ts
// v15 -- not cached by default. Explicit caching:
const data = await fetch("https://api.example.com/data", {
  cache: "force-cache",
});

// Time-based revalidation
const data = await fetch("https://api.example.com/data", {
  next: { revalidate: 3600 },
});

// Tag-based revalidation
const data = await fetch("https://api.example.com/data", {
  next: { tags: ["products"] },
});
```

**Client Router Cache -- restore v14 behavior:**
```ts
// next.config.ts
experimental: {
  staleTimes: {
    dynamic: 30,   // seconds (was 30s in v14)
    static: 300,   // seconds (was 5min in v14)
  },
}
```

### 5. Form Component (`next/form`)

Extends native HTML `<form>` with prefetching, client-side navigation, and progressive enhancement:

```tsx
import Form from "next/form";

// Search form -- navigates to /search?q=... via client-side nav
export default function SearchBar() {
  return (
    <Form action="/search">
      <input name="q" placeholder="Search products..." />
      <button type="submit">Search</button>
    </Form>
  );
}
```

**vs native `<form>`:**
- `<form action="/search">` -- full page reload
- `<Form action="/search">` -- client-side navigation, prefetch on hover

### 6. Instrumentation Stable

`instrumentation.ts` is now stable (previously experimental). Provides server lifecycle observability.

```ts
// instrumentation.ts (project root)
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./lib/monitoring");
  }
}

export async function onRequestError(
  error: { digest: string } & Error,
  request: { path: string; method: string },
  context: { routeType: "render" | "route" | "action" | "middleware" }
) {
  await fetch("https://errors.example.com/report", {
    method: "POST",
    body: JSON.stringify({
      message: error.message,
      path: request.path,
      routeType: context.routeType,
    }),
  });
}
```

### 7. Server Actions Security

**Dead code elimination**: Unused Server Actions are removed from the client bundle entirely.

**Non-deterministic action IDs**: Action endpoint IDs are now cryptographically random and change between builds. Prevents ID enumeration attacks.

Best practice -- always validate authorization:
```ts
export async function deletePost(id: string) {
  "use server";
  const session = await auth();
  if (!session?.user) throw new Error("Unauthorized");
  await db.posts.delete({ where: { id } });
}
```

### 8. Self-Hosting Improvements

**Configurable ISR expireTime:**
```ts
expireTime: 3600, // ISR pages expire after 1 hour (default: 1 year)
```

**Automatic sharp**: Auto-detects and uses `sharp` for image optimization. No manual install required.

**Cache-Control headers**: Generates correct headers for ISR and static pages automatically when self-hosting.

### 9. TypeScript Config Support

`next.config.ts` is now supported with full type checking:

```ts
import type { NextConfig } from "next";

const config: NextConfig = {
  reactStrictMode: true,
  // ... full autocomplete and type checking
};

export default config;
```

### 10. Other Changes

**Node.js minimum**: 18.18.0 required.

**ESLint 9 support**: Flat config (`eslint.config.mjs`) supported.

**`unstable_after`** (experimental): Run code after response is sent:
```ts
import { unstable_after as after } from "next/server";

export async function POST(request: Request) {
  const result = await processRequest(request);
  after(async () => {
    await analytics.track("processed", { id: result.id });
  });
  return Response.json(result);
}
```

**`bundlePagesRouterDependencies`**: Aligns Pages Router bundling with App Router:
```ts
bundlePagesRouterDependencies: true,
serverExternalPackages: ["some-native-package"],
```

---

## Migration: v14 to v15

### Step 1 -- Update Dependencies

```bash
npm install next@15 react@19.0.0-rc react-dom@19.0.0-rc
# Pages Router staying on React 18:
npm install next@15 react@18 react-dom@18
```

### Step 2 -- Run Async APIs Codemod

```bash
npx @next/codemod@canary next-async-request-api .
```

Review: components using `cookies()`, `headers()`, `draftMode()`, Route Handlers using `params`, pages using `searchParams`.

### Step 3 -- Audit Caching Behavior

```
Checklist:
[ ] GET Route Handlers -- add `export const dynamic = 'force-static'` if caching needed
[ ] fetch() calls -- add cache: 'force-cache' or next: { revalidate: N } where needed
[ ] Client navigation -- add staleTimes config if stale cache behavior required
[ ] ISR pages -- verify revalidate exports still work (they do)
```

### Step 4 -- Rename Config File

```bash
mv next.config.js next.config.ts
# Add: import type { NextConfig } from "next"
```

### Step 5 -- Update Node.js

Ensure CI, Docker, and hosting use Node.js >= 18.18.0.

### Step 6 -- Test Turbopack

```bash
next dev --turbo
```

Check for custom webpack loader compatibility issues.

### Step 7 -- Test Server Actions

- Action IDs changed (expected -- now non-deterministic)
- Confirm dead code elimination did not remove used actions
- Remove any hardcoded action endpoint references

### Common Migration Gotchas

| Issue | Cause | Fix |
|---|---|---|
| Data is stale after deploy | Relied on fetch cache | Add explicit `cache: "force-cache"` |
| Route handler returns fresh data unexpectedly | GET handlers no longer cached | Add `export const dynamic = "force-static"` |
| `params.id` is a Promise error | Async params breaking change | `await params` before destructuring |
| `cookies()` returns undefined | Missing await | `const store = await cookies()` |
| Pages reload on every navigation | staleTime now 0 | Add `staleTimes` config |
| Build fails on Node 16/17 | Min version now 18.18.0 | Upgrade Node.js |
