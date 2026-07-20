# Remix / React Router v7 Best Practices Reference

Guidelines for data flow, form handling, error boundaries, and deployment.

---

## Data Flow

### Loaders for All Data Fetching

Never fetch data in `useEffect`. Use loaders for all server data. Loaders run on the server, have direct database/API access, and execute in parallel across the route tree.

```typescript
// GOOD: loader fetches data server-side
export async function loader({ params }: LoaderFunctionArgs) {
  const [user, posts] = await Promise.all([
    getUser(params.id),
    getPosts(params.id),
  ]);
  return { user, posts };
}

// BAD: useEffect fetches client-side (waterfall, loading spinner)
```

### Parallel Fetching in Loaders

Use `Promise.all` for independent data sources. Avoid sequential awaits:

```typescript
// GOOD
const [user, posts] = await Promise.all([getUser(id), getPosts(id)]);

// BAD -- sequential, slower
const user = await getUser(id);
const posts = await getPosts(id);
```

### useFetcher for Non-Navigation Mutations

Use `useFetcher` when a mutation should not change the URL or trigger navigation:

```tsx
function LikeButton({ postId }: { postId: string }) {
  const fetcher = useFetcher();
  return (
    <fetcher.Form method="post" action={`/posts/${postId}/like`}>
      <button>{fetcher.state !== "idle" ? "Saving..." : "Like"}</button>
    </fetcher.Form>
  );
}
```

### Optimistic UI

```tsx
function TodoItem({ todo }: { todo: Todo }) {
  const fetcher = useFetcher();
  const isDeleting = fetcher.formMethod === "DELETE";
  return (
    <li style={{ opacity: isDeleting ? 0.5 : 1 }}>
      {todo.title}
      <fetcher.Form method="delete" action={`/todos/${todo.id}`}>
        <button>Delete</button>
      </fetcher.Form>
    </li>
  );
}
```

---

## Form Handling

### Always Redirect After Mutation

Return `redirect()` from successful actions to prevent double-submission:

```typescript
export async function action({ request }: ActionFunctionArgs) {
  const data = await request.formData();
  await createItem(data);
  return redirect("/items");  // PRG pattern
}
```

### Validation with Zod

```typescript
const Schema = z.object({
  name: z.string().min(1),
  price: z.coerce.number().positive(),
});

export async function action({ request }: ActionFunctionArgs) {
  const result = Schema.safeParse(Object.fromEntries(await request.formData()));
  if (!result.success) {
    return data({ errors: result.error.flatten().fieldErrors }, { status: 422 });
  }
  await db.product.create({ data: result.data });
  return redirect("/products");
}
```

### Pending UI

```tsx
const { state } = useNavigation();
<button disabled={state === "submitting"}>
  {state === "submitting" ? "Saving..." : "Save"}
</button>
```

---

## Error Boundaries

### Every Route Should Have an ErrorBoundary

Error boundaries isolate failures. A broken child route does not take down the parent layout.

### Root ErrorBoundary Must Render Full HTML

```tsx
// root.tsx
export function ErrorBoundary() {
  const error = useRouteError();
  return (
    <html><body>
      <h1>{isRouteErrorResponse(error) ? `${error.status}` : "Error"}</h1>
      <a href="/">Home</a>
    </body></html>
  );
}
```

### Re-Throw Unknown Errors

```tsx
export function ErrorBoundary() {
  const error = useRouteError();
  if (isRouteErrorResponse(error) && error.status === 404) {
    return <NotFoundPage />;
  }
  throw error;  // let parent handle
}
```

---

## Deployment

### Choose the Right Adapter

- **Node.js** (`@react-router/node`): most flexible, works with any Node hosting.
- **Cloudflare** (`@react-router/cloudflare`): edge deployment, fast cold starts.
- **Express** (`@react-router/express`): integrate into existing Express apps.
- **`@react-router/serve`**: zero-config production server for simple deployments.

### Environment Variables

Access via `process.env` in loaders/actions (server-only). Never expose secrets to client code. Use `clientLoader` for client-side environment values.

### Static Assets

Place in `public/` directory. Vite handles fingerprinting and caching automatically.
