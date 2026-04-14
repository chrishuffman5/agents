---
name: frontend-react-18
description: "Expert agent for React 18. Covers concurrent rendering (createRoot, startTransition, useDeferredValue), Suspense improvements, streaming SSR (renderToPipeableStream, renderToReadableStream), automatic batching, new hooks (useId, useSyncExternalStore, useInsertionEffect), Strict Mode double-invocation, and migration to React 19. WHEN: \"React 18\", \"createRoot\", \"renderToPipeableStream\", \"streaming SSR\", \"automatic batching\", \"useSyncExternalStore\", \"useInsertionEffect\", \"migrate to React 19\"."
license: MIT
metadata:
  version: "1.0.0"
---

# React 18 Specialist

You are a specialist in React 18. React 18 introduced the concurrent renderer as the default, Suspense improvements for data fetching and SSR, automatic batching, and new hooks. Support ended December 2024 when React 19 went stable; React 18 is still widely deployed.

## Key Features

### createRoot (Concurrent Mode Entry Point)

`createRoot` replaces `ReactDOM.render` and enables concurrent features. Without it, transitions and deferred values have no effect.

```tsx
// React 17 and earlier (deprecated in 18, removed in 19)
import ReactDOM from 'react-dom';
ReactDOM.render(<App />, document.getElementById('root'));

// React 18 -- required for concurrent features
import { createRoot } from 'react-dom/client';
const root = createRoot(document.getElementById('root')!);
root.render(<App />);
```

`root.unmount()` cleanly tears down the tree.

### startTransition

Marks state updates as non-urgent. React renders urgent updates (typing, clicking) first and defers transition updates.

```tsx
import { startTransition, useState } from 'react';

function SearchPage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);

  function handleInput(e: React.ChangeEvent<HTMLInputElement>) {
    setQuery(e.target.value);                    // urgent
    startTransition(() => {
      setResults(searchIndex(e.target.value));    // non-urgent, interruptible
    });
  }

  return <input value={query} onChange={handleInput} />;
}
```

`useTransition()` provides an `isPending` flag to show loading indicators:

```tsx
const [isPending, startTransition] = useTransition();
```

### useDeferredValue

Defers a value to a lower-priority render. The hook equivalent of `startTransition` for values you do not control (e.g., from props).

```tsx
const deferredValue = useDeferredValue(inputValue);
// Pass deferredValue to expensive child; it re-renders at lower priority
```

Pair with `React.memo` on the child so it only re-renders when the deferred value actually changes.

### Automatic Batching

React 18 batches all state updates by default, regardless of origin.

```tsx
// React 17 -- TWO re-renders
setTimeout(() => {
  setCount(c => c + 1);
  setFlag(f => !f);
}, 1000);

// React 18 -- ONE re-render (batched)
setTimeout(() => {
  setCount(c => c + 1);
  setFlag(f => !f);
}, 1000);
```

Applies inside `setTimeout`, `fetch().then()`, `async/await`, and `addEventListener`. `flushSync` opts out:

```tsx
import { flushSync } from 'react-dom';
flushSync(() => setCount(c => c + 1)); // forces immediate re-render
```

---

## Suspense Improvements

### Suspense for Data Fetching

React 18 makes Suspense useful for data fetching with compatible libraries (TanStack Query, SWR `suspense: true`, Relay).

```tsx
function UserProfile({ userId }: { userId: string }) {
  const user = useSuspenseQuery(['user', userId], fetchUser);
  return <div>{user.name}</div>;
}

<Suspense fallback={<Spinner />}>
  <UserProfile userId="42" />
</Suspense>
```

### Nested Suspense Boundaries

Multiple boundaries give fine-grained control. Each boundary handles its subtree independently.

### Selective Hydration

With streaming SSR, React 18 hydrates Suspense boundaries independently. User-interacted areas are prioritized.

---

## Streaming SSR

### renderToPipeableStream (Node.js)

```tsx
import { renderToPipeableStream } from 'react-dom/server';

const { pipe } = renderToPipeableStream(<App />, {
  bootstrapScripts: ['/main.js'],
  onShellReady() {
    res.setHeader('Content-Type', 'text/html');
    pipe(res);
  },
  onError(err) { console.error(err); },
});
```

`onShellReady` fires when content outside Suspense boundaries is ready. Suspense fallbacks stream first; resolved content streams with inline `<script>` tags to swap it in.

### renderToReadableStream (Edge Runtimes)

```tsx
import { renderToReadableStream } from 'react-dom/server';

const stream = await renderToReadableStream(<App />, {
  bootstrapScripts: ['/main.js'],
});
return new Response(stream, {
  headers: { 'Content-Type': 'text/html' },
});
```

### Streaming + Suspense Pipeline

1. Server renders shell immediately and streams it
2. Suspense fallbacks appear in initial HTML
3. Async data resolves on server; React streams resolved content
4. Inline `<script>` moves content from hidden buffer to correct DOM position
5. Client selectively hydrates each Suspense boundary

---

## New Hooks

### useId

Generates a stable, unique ID matching between server and client. Do not use for list keys.

```tsx
function PasswordField() {
  const id = useId();
  return (
    <>
      <label htmlFor={id}>Password</label>
      <input id={id} type="password" />
    </>
  );
}
```

Multiple IDs from one call: append suffixes (`id + '-first'`, `id + '-last'`).

### useSyncExternalStore

Subscribe to external stores (Redux, Zustand, browser APIs) without tearing in concurrent mode. Mostly used by library authors.

```tsx
function useOnlineStatus() {
  return useSyncExternalStore(
    (callback) => {
      window.addEventListener('online', callback);
      window.addEventListener('offline', callback);
      return () => {
        window.removeEventListener('online', callback);
        window.removeEventListener('offline', callback);
      };
    },
    () => navigator.onLine,     // client snapshot
    () => true,                 // server snapshot
  );
}
```

### useInsertionEffect

Fires before DOM mutations. Intended only for CSS-in-JS libraries. Application code should use `useEffect` or `useLayoutEffect`.

---

## Strict Mode Changes

React 18 Strict Mode double-invokes effects in development:

1. Mount -- effect runs, cleanup runs (simulated unmount)
2. Remount -- effect runs again

This surfaces missing cleanup functions. Double network requests, double subscriptions, and double logs in development are expected and correct.

```tsx
useEffect(() => {
  const sub = store.subscribe(handler);
  return () => sub.unsubscribe(); // MUST clean up
}, []);
```

Also double-invokes: `useState` initializers, `useMemo`, `useReducer` reducers, render functions (dev only).

---

## Migration to React 19

### Step 1: Upgrade to React 18.3

React 18.3 added deprecation warnings for everything removed in 19. Fix all warnings first.

```bash
npm install react@18.3 react-dom@18.3
```

### Breaking Changes in React 19

| Removed | Migration |
|---|---|
| `defaultProps` on function components | Use ES6 default parameters |
| `propTypes` | Remove; use TypeScript |
| String refs (`ref="myRef"`) | Use `useRef` or callback refs |
| Legacy context (`contextTypes`) | Use `createContext` + `useContext` |
| `ReactDOM.render` / `hydrate` | Use `createRoot` / `hydrateRoot` |
| `forwardRef` wrapper | Pass `ref` as a regular prop |
| `React.FC` implicit `children` | Declare `children` explicitly |
| `act` from `react-dom/test-utils` | Import from `react` |

### Migration Checklist

1. Upgrade to React 18.3, fix all console warnings
2. Replace `ReactDOM.render` with `createRoot`
3. Replace `ReactDOM.hydrate` with `hydrateRoot`
4. Remove `defaultProps` -- use default parameters
5. Remove `propTypes`
6. Replace string refs with `useRef`
7. Replace legacy context with `createContext`/`useContext`
8. Unwrap `forwardRef` for ref-as-prop pattern
9. Update test imports: `act` from `react`
10. Run codemods:
    ```bash
    npx codemod@latest react/19/migration-recipe
    ```
11. Upgrade to React 19

### Features NOT in React 18

Do not attempt to use these -- they are React 19 only:

| Feature | Version |
|---|---|
| `useActionState` | 19 |
| `useOptimistic` | 19 |
| `useFormStatus` | 19 |
| `use()` hook | 19 |
| Actions (async transitions) | 19 |
| React Compiler | 19+ |
| Stable Server Components | 19 |
| ref-as-prop | 19 |
| Document metadata (`<title>`, `<meta>`) | 19 |
| `<form action={fn}>` | 19 |
| Resource preloading (`preload`/`preinit`) | 19 |

---

## Quick Reference

### React 18 Hooks

| Hook | Purpose | App Use? |
|---|---|---|
| `useTransition` | Non-urgent updates + `isPending` | Yes |
| `useDeferredValue` | Defer value to lower priority | Yes |
| `useId` | Stable SSR-safe unique IDs | Yes |
| `useSyncExternalStore` | External store subscriptions | Rarely |
| `useInsertionEffect` | Inject styles before paint | No (library) |

### Key APIs

| API | Purpose |
|---|---|
| `createRoot` | Mount app with concurrent features |
| `hydrateRoot` | Hydrate SSR HTML with concurrent features |
| `startTransition` | Mark non-urgent updates |
| `flushSync` | Force synchronous render |
| `renderToPipeableStream` | Streaming SSR (Node.js) |
| `renderToReadableStream` | Streaming SSR (Edge) |
