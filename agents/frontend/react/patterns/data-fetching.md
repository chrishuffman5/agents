# Data Fetching Patterns

Suspense integration, the `use()` hook, TanStack Query, and SWR.

---

## Suspense for Data Fetching

Suspense boundaries catch promises thrown by components and show fallback UI until the data resolves. This is the React-recommended approach for async rendering.

### With React.lazy (Code Splitting)

```tsx
const Dashboard = React.lazy(() => import('./Dashboard'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <Dashboard />
    </Suspense>
  );
}
```

### Nested Suspense Boundaries

Each boundary independently handles its subtree. Granular boundaries improve perceived performance.

```tsx
<Suspense fallback={<PageSkeleton />}>
  <Header />
  <Suspense fallback={<FeedSkeleton />}>
    <NewsFeed />
  </Suspense>
  <Suspense fallback={<SidebarSkeleton />}>
    <Sidebar />
  </Suspense>
</Suspense>
```

### Selective Hydration (SSR)

With streaming SSR (React 18+), Suspense boundaries hydrate independently. User-interacted areas are prioritized for hydration.

---

## use() Hook (React 19)

`use()` reads a resource during render. Unlike other hooks, it can be called conditionally and inside loops.

### Reading Promises

```tsx
import { use, Suspense } from "react";

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspends until resolved
  return <h1>{user.name}</h1>;
}

function App() {
  const userPromise = fetchUser(userId); // create outside component
  return (
    <Suspense fallback={<Spinner />}>
      <UserProfile userPromise={userPromise} />
    </Suspense>
  );
}
```

**Important:** Create the promise outside the component or in a parent. Creating it inside the component that calls `use()` would create a new promise on every render.

### Reading Context Conditionally

```tsx
function ConditionalTheme({ showTheme }: { showTheme: boolean }) {
  if (showTheme) {
    const theme = use(ThemeContext); // conditional use is allowed
    return <div style={{ color: theme.color }}>Themed</div>;
  }
  return <div>No theme</div>;
}
```

### Streaming Data from Server to Client Components

Server Components can pass promises as props. Client Components read them with `use()`.

```tsx
// Server Component
export default function Page() {
  const dataPromise = fetchUserData(); // Promise is serializable
  return <ClientDisplay dataPromise={dataPromise} />;
}

// Client Component ("use client")
export default function ClientDisplay({ dataPromise }) {
  const data = use(dataPromise); // suspends until resolved
  return <div>{data.name}</div>;
}
```

---

## TanStack Query (React Query)

The standard for server state management: fetching, caching, invalidation, background refetch, optimistic updates.

### Basic Query

```tsx
import { useQuery } from "@tanstack/react-query";

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ["user", userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000, // data is fresh for 5 minutes
  });

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  return <div>{user?.name}</div>;
}
```

### Suspense Mode

```tsx
import { useSuspenseQuery } from "@tanstack/react-query";

function UserProfile({ userId }: { userId: string }) {
  const { data: user } = useSuspenseQuery({
    queryKey: ["user", userId],
    queryFn: () => fetchUser(userId),
  });
  // No loading/error checks needed -- Suspense and ErrorBoundary handle them
  return <div>{user.name}</div>;
}
```

### Mutations with Cache Invalidation

```tsx
import { useMutation, useQueryClient } from "@tanstack/react-query";

function UpdateButton({ userId }: { userId: string }) {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: (updates: Partial<User>) => updateUser(userId, updates),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["user", userId] });
    },
  });

  return (
    <button onClick={() => mutation.mutate({ name: "New Name" })}>
      {mutation.isPending ? "Updating..." : "Update"}
    </button>
  );
}
```

### Provider Setup

```tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60 * 1000,    // 1 minute default staleness
      retry: 2,                 // retry failed requests twice
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <MyApp />
    </QueryClientProvider>
  );
}
```

---

## SWR

Lighter alternative to TanStack Query from Vercel. Stale-While-Revalidate strategy.

### Basic Usage

```tsx
import useSWR from "swr";

const fetcher = (url: string) => fetch(url).then(r => r.json());

function UserProfile({ userId }: { userId: string }) {
  const { data, error, isLoading } = useSWR(`/api/users/${userId}`, fetcher);

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  return <div>{data.name}</div>;
}
```

### Suspense Mode

```tsx
import useSWR from "swr";

function UserProfile({ userId }: { userId: string }) {
  const { data } = useSWR(`/api/users/${userId}`, fetcher, {
    suspense: true,
  });
  return <div>{data.name}</div>;
}
```

---

## Decision Guide

| Scenario | Recommended Approach |
|---|---|
| Server Component data | Direct `await` in component body |
| Client-side server state (CRUD, caching) | TanStack Query |
| Simple client-side fetching | SWR |
| Streaming data from Server to Client | `use()` with Promise prop |
| Code splitting | `React.lazy()` + Suspense |
| RSC framework (Next.js App Router) | Server Components + Server Actions |
