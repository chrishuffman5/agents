# Remix v2 to React Router v7 Migration

Step-by-step guide for migrating from Remix v2 to React Router v7.

---

## Package Renames

| Old (`@remix-run/*`) | New |
|---|---|
| `@remix-run/react` | `react-router` |
| `@remix-run/node` | `@react-router/node` |
| `@remix-run/cloudflare` | `@react-router/cloudflare` |
| `@remix-run/express` | `@react-router/express` |
| `@remix-run/serve` | `@react-router/serve` |
| `@remix-run/dev` | `@react-router/dev` |

```typescript
// Before
import { useLoaderData, Form } from "@remix-run/react";
import type { LoaderFunctionArgs } from "@remix-run/node";

// After
import { useLoaderData, Form, type LoaderFunctionArgs } from "react-router";
```

---

## Configuration Changes

| Old | New |
|---|---|
| `remix.config.js` | `react-router.config.ts` |
| File routes by default | Explicit `routes.ts` (file routes opt-in) |
| `"dev": "remix dev"` | `"dev": "react-router dev"` |
| `"build": "remix build"` | `"build": "react-router build"` |

### Vite Config

```typescript
// Before
import { remix } from "@remix-run/dev";
export default defineConfig({ plugins: [remix()] });

// After
import { reactRouter } from "@react-router/dev/vite";
export default defineConfig({ plugins: [reactRouter()] });
```

---

## Route Configuration

### Option 1: Explicit routes.ts (Recommended)

Create `app/routes.ts` with explicit route definitions:

```typescript
import { type RouteConfig, route, index, layout, prefix } from "@react-router/dev/routes";

export default [
  index("routes/home.tsx"),
  route("about", "routes/about.tsx"),
  ...prefix("products", [
    index("routes/products.index.tsx"),
    route(":id", "routes/products.$id.tsx"),
  ]),
] satisfies RouteConfig;
```

### Option 2: File-System Convention (Compatibility)

```typescript
// app/routes.ts
import { flatRoutes } from "@react-router/fs-routes";
export default flatRoutes();
```

This preserves Remix v2 file naming conventions.

---

## Type Generation

React Router v7 adds per-route type generation:

```bash
npx react-router typegen        # one-time generation
npx react-router typegen --watch # watch mode
```

```typescript
// routes/products.$id.tsx
import type { Route } from "./+types/products.$id";

export async function loader({ params }: Route.LoaderArgs) {
  // params.id is typed as string
}

export default function Product({ loaderData }: Route.ComponentProps) {
  // loaderData is fully typed from loader return
}
```

---

## Quick Migration Checklist

- [ ] Replace `@remix-run/*` with `react-router` / `@react-router/*` in `package.json`
- [ ] Delete `node_modules` and reinstall
- [ ] Rename `remix.config.js` to `react-router.config.ts`
- [ ] Create `app/routes.ts` (or use `flatRoutes()` for file-convention compatibility)
- [ ] Update `vite.config.ts`: use `reactRouter()` from `@react-router/dev/vite`
- [ ] Find/replace all `@remix-run/react` imports with `react-router`
- [ ] Find/replace all `@remix-run/node` imports with `@react-router/node`
- [ ] Run `npx react-router typegen`; adopt `Route.*` types
- [ ] Update `package.json` scripts: `react-router dev` / `react-router build`
- [ ] Test all routes, loaders, actions, and error boundaries
- [ ] Verify production build: `react-router build && react-router-serve build/server/index.js`

---

## What Stays the Same

The core API is identical. These all work without changes:

`loader`, `action`, `clientLoader`, `clientAction`, `<Form>`, `useFetcher`, `useNavigation`, `useLoaderData`, `defer()`, `<Await>`, `ErrorBoundary`, `HydrateFallback`, `<Outlet>`, all Web standard APIs (`Request`, `Response`, `FormData`, `Headers`).
