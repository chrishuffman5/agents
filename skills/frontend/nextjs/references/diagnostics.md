# Next.js Diagnostics Reference

Troubleshooting guide for build errors, caching issues, hydration problems, and performance analysis.

---

## Common Build Errors

### "Module not found: Can't resolve '@/components/...'"

- Verify `tsconfig.json` has `paths` configured: `"@/*": ["./src/*"]` or `"@/*": ["./*"]`
- Ensure `next.config.ts` does not override module resolution without re-adding the alias
- When using Turbopack, add resolve aliases in the `turbopack.resolveAlias` config section

### "You're importing a component that needs X. It only works in a Client Component"

- Add `"use client"` to the component using hooks or browser APIs
- Or extract only the hook-using part into a separate Client Component
- Common triggers: `useState`, `useEffect`, `useContext`, `useRouter`, `onClick` handlers

### Hydration Mismatch Errors

**Cause**: Server-rendered HTML differs from client render output.

**Common triggers**:
- Dynamic values (`Date.now()`, `Math.random()`, `crypto.randomUUID()`)
- Browser-only state (`window.innerWidth`, `localStorage`)
- Conditional rendering based on `typeof window !== "undefined"`
- Third-party scripts injecting DOM elements

**Fixes**:
- Use `suppressHydrationWarning` on specific elements (sparingly)
- Wrap browser-only content in `useEffect` for client-side initialization
- Use `dynamic(() => import("./Component"), { ssr: false })` to skip SSR for problematic components
- Ensure Server and Client Components render the same initial output

### Middleware Timeout (Edge Runtime, v15)

- Edge Runtime has a 30-second timeout maximum; actual limits vary by platform
- Offload heavy computation to Route Handlers (Node.js runtime)
- In v16: use `proxy.ts` (Node.js runtime) for complex logic that needs full Node.js APIs

### Async API Errors (v15/v16)

**Symptom**: `params.id is a Promise` or `cookies() returns undefined`

**Cause**: v15 made `cookies()`, `headers()`, `params`, and `searchParams` async. v16 removed synchronous access entirely.

**Fix**:
```tsx
// v15/v16 -- must await
export default async function Page({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const cookieStore = await cookies();
  const headersList = await headers();
}
```

Run the codemod: `npx @next/codemod@canary next-async-request-api .`

---

## Caching Gotchas

### Stale Data from Data Cache

**Symptom**: Data updates in database but page shows old data.
**Cause**: `fetch()` response cached with `force-cache` or `revalidate`.
**Fix**: Call `revalidateTag(tag)` or `revalidatePath(path)` after mutations, or set shorter `revalidate` interval.

### Router Cache Showing Old Pages

**Symptom**: After a mutation, navigating back shows pre-mutation state.
**Cause**: Client-side Router Cache holding stale RSC payload.
**Fix**: `router.refresh()` in Client Component, or use `revalidatePath` in Server Action (automatically busts Router Cache for affected paths).

### v14 to v15 Migration: Unexpected Cache Misses

**Symptom**: Data that was cached automatically in v14 now fetches on every request.
**Cause**: v15 removed implicit `force-cache` default for `fetch()`.
**Fix**: Audit all `fetch()` calls and add explicit `cache: "force-cache"` or `next: { revalidate }` where caching is desired.

### revalidateTag Not Working

- Ensure the `fetch()` call uses the same tag string: `next: { tags: ["products"] }`
- Tags must match exactly (case-sensitive string)
- `revalidateTag` only works in Server Actions and Route Handlers -- not in Client Components
- In v16, `revalidateTag` requires a second argument (cache profile): `revalidateTag("products", "hours")`

### "use cache" Not Caching (v16)

- Ensure `cacheComponents: true` is set in `next.config.ts`
- The `"use cache"` directive must be at the top of the function body or file
- Verify the function is async -- `"use cache"` only works on async functions/components
- Check that `cacheLife()` is called to specify a cache duration profile

---

## Performance Diagnostics

### Bundle Analyzer

```bash
npm install @next/bundle-analyzer
```

```ts
const withBundleAnalyzer = require("@next/bundle-analyzer")({
  enabled: process.env.ANALYZE === "true",
});
module.exports = withBundleAnalyzer({ /* config */ });
```

```bash
ANALYZE=true npm run build
```

Opens interactive treemap. Look for:
- Unexpectedly large dependencies in client bundle
- Server-only modules accidentally included in client bundle
- Duplicate dependencies

### Build Output Analysis

`next build` prints route sizes and First Load JS per route:
- **Green**: < 130 kB First Load JS
- **Yellow**: 130-200 kB
- **Red**: > 200 kB -- investigate with bundle analyzer

After build, `.next/server/app/` contains pre-rendered HTML. Verify expected routes are statically generated (circle icon) vs dynamically rendered (lambda icon) in the build output table.

### Core Web Vitals

| Metric | Description | Next.js Fix |
|---|---|---|
| LCP | Largest Contentful Paint | `priority` on hero image, reduce TTFB with static rendering |
| CLS | Cumulative Layout Shift | `next/image` with dimensions, `next/font` for zero-shift fonts |
| INP | Interaction to Next Paint | Minimize client JS, defer non-critical scripts |
| TTFB | Time to First Byte | Static rendering, CDN, edge deployment |

### Web Vitals Reporting

```tsx
"use client";
import { useReportWebVitals } from "next/web-vitals";

export function WebVitals() {
  useReportWebVitals((metric) => {
    fetch("/api/vitals", { method: "POST", body: JSON.stringify(metric) });
  });
  return null;
}
```

---

## Routing Diagnostics

### Unexpected Full Page Reload on Navigation

**Causes**:
- Layout changed between routes -- shared layouts should be at the common ancestor
- Destination route is still in `pages/` -- pages/ routes always cause full reloads from App Router
- Server Component using browser-only API without `"use client"` -- causes render errors falling back to full reload

### Parallel Route Slot Not Rendering

**Symptom**: `@slotName` shows nothing or the page 404s.
**Fix**: Add `default.tsx` to the slot directory returning `null`.

### Intercepting Route Shows Full Page Instead of Modal

**Expected**: Intercepting routes only apply to soft (client-side) navigation. Direct URL visit or refresh always renders the original route.
**Check**: Verify the interception prefix matches the relative depth (`(.)` = same level, `(..)` = one level up). Ensure the modal slot has `default.tsx`.

### Layout Re-rendering Unnecessarily

**Cause**: Using `template.tsx` instead of `layout.tsx`. Templates re-mount on every navigation by design.
**Fix**: Rename `template.tsx` to `layout.tsx` for persistence.

---

## Server Action Diagnostics

### "use client" Boundary Issues

**Symptom**: Server Component imported into Client Component tree loses server-only capabilities.
**Fix**: Pass Server Components as `children` props into Client Components.

```tsx
// Correct pattern -- Server Component passed as children
<ClientSidebar>
  <ServerFeed />   {/* Still rendered on server */}
</ClientSidebar>
```

### cookies() or headers() Called Outside Request Context

**Symptom**: `cookies() was called outside a request scope`.
**Cause**: Called inside a cached function or at module level.
**Fix**: Call directly inside Server Components, Server Actions, or Route Handlers -- not inside cached helpers or module initialization.

### redirect() Swallowed by try/catch

**Symptom**: `redirect()` does not navigate.
**Cause**: `redirect()` throws internally; wrapping in try/catch catches the redirect error.
**Fix**: Call `redirect()` outside try/catch, or re-throw if the redirect error is caught.
