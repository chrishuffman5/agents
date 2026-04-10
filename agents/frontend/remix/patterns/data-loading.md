# Remix / React Router v7 Data Loading Patterns

Patterns for loaders, defer, and clientLoader.

---

## Server Loader

The primary data-fetching mechanism. Runs on the server for every GET request to the route.

```typescript
import { type LoaderFunctionArgs } from "react-router";

export async function loader({ params, request }: LoaderFunctionArgs) {
  const url = new URL(request.url);
  const query = url.searchParams.get("q") ?? "";

  const product = await db.product.findUnique({ where: { id: params.id } });
  if (!product) throw new Response("Not Found", { status: 404 });

  return { product, query };
}

export default function ProductPage() {
  const { product, query } = useLoaderData<typeof loader>();
  return <h1>{product.name}</h1>;
}
```

### Parallel Fetching

Loaders across the route tree execute in parallel. Within a single loader, use `Promise.all`:

```typescript
export async function loader({ params }: LoaderFunctionArgs) {
  const [user, posts, followers] = await Promise.all([
    getUser(params.id),
    getPosts(params.id),
    getFollowers(params.id),
  ]);
  return { user, posts, followers };
}
```

---

## Streaming with defer()

Send fast data immediately; stream slow data as it resolves:

```typescript
import { defer } from "react-router";

export async function loader() {
  const fastData = await getFastData();       // awaited -- in initial HTML
  const slowPromise = getSlowData();          // NOT awaited -- streamed later
  return defer({ fastData, slowPromise });
}
```

```tsx
import { Suspense } from "react";
import { Await, useLoaderData } from "react-router";

export default function Page() {
  const { fastData, slowPromise } = useLoaderData<typeof loader>();
  return (
    <>
      <h1>{fastData.title}</h1>
      <Suspense fallback={<p>Loading reviews...</p>}>
        <Await resolve={slowPromise} errorElement={<p>Failed to load.</p>}>
          {(data) => <ReviewList reviews={data} />}
        </Await>
      </Suspense>
    </>
  );
}
```

### When to Use defer

- The page has both fast and slow data sources.
- The fast data is critical for initial paint (above-the-fold content).
- The slow data can appear progressively (below-the-fold, secondary panels).

---

## Client Loader

Intercepts before or instead of the server loader. Use for caching, offline support, or client-side data augmentation.

```typescript
export async function clientLoader({ serverLoader }: ClientLoaderFunctionArgs) {
  const cached = sessionStorage.getItem("product");
  if (cached) return JSON.parse(cached);

  const data = await serverLoader();       // fall through to server
  sessionStorage.setItem("product", JSON.stringify(data));
  return data;
}
clientLoader.hydrate = true;               // also run on initial SSR hydration

export function HydrateFallback() {
  return <div className="skeleton">Loading...</div>;
}
```

### clientLoader.hydrate

When `true`, the client loader runs during initial hydration (after SSR). Export `HydrateFallback` to show UI while the client loader runs.

---

## Accessing Parent Data

```tsx
// In a child route
import { useRouteLoaderData } from "react-router";

export default function ProductReviews() {
  const parentData = useRouteLoaderData("routes/products.$id");
  return <h2>Reviews for {parentData?.product.name}</h2>;
}
```

---

## useFetcher for Background Loading

Load data without navigating:

```tsx
function SearchSuggestions() {
  const fetcher = useFetcher();

  useEffect(() => {
    fetcher.load("/api/suggestions?q=react");
  }, []);

  return fetcher.data ? (
    <ul>{fetcher.data.map(s => <li key={s}>{s}</li>)}</ul>
  ) : null;
}
```
