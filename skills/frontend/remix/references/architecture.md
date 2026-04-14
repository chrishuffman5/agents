# Remix / React Router v7 Architecture Reference

Deep reference for nested routes, loaders, actions, progressive enhancement, and the data flow model.

---

## Nested Routes

React Router v7 builds a route tree from `app/routes.ts` (or file system convention). Every route module can export `loader`, `action`, `ErrorBoundary`, `HydrateFallback`, and a default component.

Parent layouts render `<Outlet />` to inject matched children.

```
app/
  root.tsx                    -- root route; wraps every page, owns <html>
  routes/
    _layout.tsx               -- layout route (no URL segment)
    _layout.dashboard.tsx     -- /dashboard
    products.$id.tsx          -- /products/:id
    products.$id.edit.tsx     -- /products/:id/edit
```

### Key Behaviors

- Each route owns its own data, error, and loading state. A child error does not unmount siblings.
- **Parallel loader execution** -- all loaders on the matched branch fire simultaneously on navigation.
- **Code splitting** -- each route is a separate Vite chunk. No `React.lazy()` needed.
- **Error isolation** -- an ErrorBoundary on a child route catches errors without affecting parent or sibling routes.

---

## Loaders and Actions

### Server Loader (GET)

```typescript
import { type LoaderFunctionArgs } from "react-router";

export async function loader({ params, request }: LoaderFunctionArgs) {
  const product = await db.product.findUnique({ where: { id: params.id } });
  if (!product) throw new Response("Not Found", { status: 404 });
  return { product };
}

export default function ProductPage() {
  const { product } = useLoaderData<typeof loader>();
  return <h1>{product.name}</h1>;
}
```

- `params` -- dynamic segments (`$id` maps to `params.id`)
- `request` -- full Web `Request`; get search params via `new URL(request.url).searchParams`
- Throw a `Response` to trigger the nearest `ErrorBoundary`

### Server Action (POST/PUT/DELETE)

```typescript
import { type ActionFunctionArgs, redirect } from "react-router";

export async function action({ request, params }: ActionFunctionArgs) {
  const formData = await request.formData();
  const name = String(formData.get("name"));
  await db.product.update({ where: { id: params.id }, data: { name } });
  return redirect(`/products/${params.id}`);
}
```

### clientLoader / clientAction

```typescript
export async function clientLoader({ serverLoader }: ClientLoaderFunctionArgs) {
  const cached = sessionStorage.getItem("product");
  if (cached) return JSON.parse(cached);
  const data = await serverLoader();
  sessionStorage.setItem("product", JSON.stringify(data));
  return data;
}
clientLoader.hydrate = true;

export function HydrateFallback() { return <Spinner />; }
```

### Data Flow Reference

| Need | Hook |
|---|---|
| This route's loader data | `useLoaderData()` |
| Parent route's loader data | `useRouteLoaderData("routes/parent")` |
| Action response | `useActionData()` |
| Non-navigation fetch | `useFetcher()` |
| Navigation state | `useNavigation()` |

---

## Progressive Enhancement

### `<Form>` Works Without JavaScript

```tsx
import { Form } from "react-router";

export default function ContactPage() {
  return (
    <Form method="post">
      <input name="email" type="email" />
      <button type="submit">Subscribe</button>
    </Form>
  );
}
```

Without JS: plain HTML form POST, full page reload. With JS: fetch-based, no full reload. Same URL, same action handler.

### Streaming with defer()

```typescript
export async function loader() {
  const fastData = await getFastData();
  const slowPromise = getSlowData();
  return defer({ fastData, slowPromise });
}
```

```tsx
<Suspense fallback={<p>Loading...</p>}>
  <Await resolve={slowPromise} errorElement={<p>Failed.</p>}>
    {(data) => <ReviewList reviews={data} />}
  </Await>
</Suspense>
```

---

## Error Boundaries

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error)) {
    return <h1>{error.status} -- {error.data}</h1>;
  }
  if (error instanceof Error) return <p>{error.message}</p>;
  throw error;
}
```

Recovery rules:
- Always provide a navigation link (do not rely on browser back).
- Re-throw errors the boundary does not understand.
- Root `ErrorBoundary` renders a complete `<html>` document.

---

## Vite Integration

```typescript
// vite.config.ts
import { reactRouter } from "@react-router/dev/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [reactRouter()],
});
```

The `reactRouter()` plugin generates route manifests, per-route type declarations, and enables React Fast Refresh. Webpack is not supported -- Vite is the only bundler.

---

## Deployment Adapters

| Adapter | Package | Use Case |
|---|---|---|
| Node.js | `@react-router/node` | Express, Fastify, bare Node |
| Cloudflare Workers | `@react-router/cloudflare` | Edge, Pages Functions |
| Express | `@react-router/express` | Existing Express apps |
| Zero-config server | `@react-router/serve` | Standalone Node |
| Deno | `@react-router/deno` | Deno Deploy |
