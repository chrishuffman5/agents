# Remix / React Router v7 Diagnostics Reference

Troubleshooting guide for route errors, hydration issues, and migration problems.

---

## Loader / Action Errors

| Symptom | Likely Cause | Fix |
|---|---|---|
| `ErrorBoundary` never renders | Missing `export function ErrorBoundary` | Add the export |
| 405 Method Not Allowed | Form `method="post"` but no `action` export | Add `export async function action` |
| Action receives empty FormData | Missing `name` attributes on inputs | Add `name` to every input |
| `useLoaderData` returns `undefined` | Reading wrong route's data | Use `useRouteLoaderData("route-id")` |
| `defer` values never resolve | Missing `<Suspense>` + `<Await>` | Wrap deferred value with `<Await>` |
| Stale data after mutation | No redirect after action | `return redirect(...)` after success |
| Double form submission | No redirect (PRG pattern missing) | Always redirect after successful action |

---

## Hydration Issues

| Symptom | Cause | Fix |
|---|---|---|
| Text content mismatch | Server/client render differ | Avoid `Date.now()`, `Math.random()` in render |
| Flash of loading state | `clientLoader.hydrate = true` without fallback | Export `HydrateFallback` component |
| Stale data after mutation | No redirect after action | `return redirect(...)` after success |
| Console warning: "Hydration failed" | Dynamic content differs between SSR and CSR | Use `useEffect` for client-only values |

---

## Route Configuration Errors

| Symptom | Cause | Fix |
|---|---|---|
| Route not found (404) | Route not registered in `routes.ts` | Add the route entry |
| Params undefined | Dynamic segment name mismatch | Verify `$id` in filename matches `params.id` |
| Layout not wrapping children | Missing `<Outlet />` in layout | Add `<Outlet />` to the layout component |
| Nested route not rendering | Parent route missing `<Outlet />` | Ensure parent renders `<Outlet />` |

---

## Migration Issues (Remix v2 to React Router v7)

| Symptom | Cause | Fix |
|---|---|---|
| Import errors after migration | Old `@remix-run/*` packages | Replace with `react-router` / `@react-router/*` |
| Config not found | `remix.config.js` still present | Rename to `react-router.config.ts` |
| Routes not loading | File routes not registered | Create `routes.ts` or use `flatRoutes()` |
| Type errors | Missing generated types | Run `npx react-router typegen` |
| Build fails | Remix dev plugin in vite.config | Replace with `reactRouter()` from `@react-router/dev/vite` |

---

## Debugging Tips

### Network Tab

All loader and action requests appear in the browser Network tab. Look for:
- `?_data=routes/...` query parameter (data requests)
- Response headers for redirect chains
- 4xx/5xx status codes from loaders/actions

### useNavigation State

```tsx
const navigation = useNavigation();
console.log(navigation.state);      // "idle" | "submitting" | "loading"
console.log(navigation.formMethod); // "GET" | "POST" | etc.
console.log(navigation.location);   // destination URL
```

### ErrorBoundary Testing

Throw errors intentionally in loaders to verify ErrorBoundary behavior:

```typescript
export async function loader() {
  throw new Response("Test Error", { status: 500 });
}
```
