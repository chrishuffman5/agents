# React Diagnostics Reference

Hydration errors, performance debugging, and build/runtime issue resolution.

---

## Hydration Errors

### Hydration Mismatch

**Error:** `Warning: Text content did not match. Server: "..." Client: "..."`

React 19 improves this with a diff view:
```
Hydration failed because the server rendered HTML didn't match the client.
  <div>
-   Server content
+   Client content
  </div>
```

**Common causes:**
- Date/time rendered during SSR differs from client render time
- Random values (`Math.random()`, `crypto.randomUUID()`) called during render
- Browser extensions modifying DOM before React hydrates
- Locale-dependent formatting (`toLocaleString()`)
- CSS-in-JS libraries generating different class names per environment
- Reading from `localStorage`/`sessionStorage` on initial render

**Fixes:**

```jsx
// For intentional mismatches (timestamps, browser extensions)
<time suppressHydrationWarning>{new Date().toLocaleString()}</time>

// React 19: data-allow-mismatch attribute
<span data-allow-mismatch>{clientOnlyValue}</span>

// Client-only rendering pattern
function ClientOnlyDate() {
  const [date, setDate] = useState(null);
  useEffect(() => setDate(new Date().toLocaleDateString()), []);
  return <span>{date}</span>;
}
```

### "Cannot update a component while rendering a different component"

**Cause:** Calling a state setter during the render phase of another component. Usually a parent calls `setState` in response to a child's render side effect.

**Fix:** Move the state update to `useEffect` or an event handler.

### Infinite useEffect Loop

**Cause:** Effect updates a value in the dependency array, triggering re-render, re-running the effect.

```jsx
// Bug
useEffect(() => {
  setData(processData(data)); // updates data -> re-runs
}, [data]);

// Fix: derived value during render
const processedData = useMemo(() => processData(data), [data]);
```

### Stale Closure in useCallback/useMemo

**Cause:** Callback captures state at creation time; dependency array incomplete.

**Fix:** Add all referenced variables to deps. Use `react-hooks/exhaustive-deps` ESLint rule.

---

## Performance Debugging

### React DevTools Profiler

1. Open DevTools, Profiler tab
2. Click Record, interact, click Stop
3. Inspect commits (each bar = one batch of state updates)
4. Flame chart: gray = didn't render, colored = rendered (width = time)
5. Check "Why did this render?" for each component

### why-did-you-render Library

Monkey-patches React to log excessive re-renders with component name and changed props/state/context.

```js
// src/wdyr.js (import before React in entry point)
import React from 'react';
import whyDidYouRender from '@welldone-software/why-did-you-render';
whyDidYouRender(React, { trackAllPureComponents: true });
```

### Chrome DevTools Performance Tab

1. Record a performance trace during interaction
2. Look at the "Main" thread flame chart
3. Yellow bars = JavaScript execution
4. Long tasks (>50ms) cause frame drops
5. Filter to "Scripting" to isolate React render work

### Identifying Unnecessary Re-renders

Patterns that trigger unnecessary re-renders:
- Object/array literals in JSX props: new reference every render
- Inline arrow functions as props: new function every render
- Context value not memoized: all consumers re-render
- Parent re-renders without `React.memo` on stable children

### Finding Expensive Renders

Use `<Profiler>` API in performance-sensitive paths. Sort DevTools Ranked chart by duration. >16ms per render (one frame at 60fps) is a candidate for optimization.

---

## Build and Runtime Issues

### "Invalid Hook Call" Error

**Most common cause:** Multiple copies of React in the bundle. Happens in monorepos, when a library bundles its own React, or peer dependencies are not deduplicated.

**Diagnosis:**
```bash
npm ls react       # check for duplicate React installations
```

**Fix:** Configure bundler to alias React to a single instance:
```js
// vite.config.ts
resolve: { dedupe: ['react', 'react-dom'] }

// webpack
resolve: { alias: { react: path.resolve('./node_modules/react') } }
```

**Other causes:**
- Hooks called conditionally or in a loop
- Hooks called from a class component or plain function
- React and ReactDOM version mismatch

### StrictMode Double-Rendering

In development, `<React.StrictMode>` mounts, unmounts, and remounts every component. `useEffect` runs: effect, cleanup, effect. This is intentional and does not happen in production.

**If effects cause problems on double-invocation:** The effect has a cleanup bug. Write a cleanup function and ensure idempotency.

```jsx
useEffect(() => {
  const sub = api.subscribe(id);
  return () => sub.unsubscribe(); // cleanup makes double-invoke safe
}, [id]);
```

### React Version Conflicts in Monorepos

Libraries should list React as `peerDependency`, not `dependency`. The workspace root provides the single resolved version.

```json
{
  "peerDependencies": { "react": ">=18.0.0" },
  "devDependencies": { "react": "^19.0.0" }
}
```

Use `pnpm` `peerDependencyRules` or yarn `resolutions` to force a single version.

### Module Resolution Issues

- **ESM/CJS mismatch:** React 19 ships as ESM. Older toolchains may need CJS interop.
- **`exports` field conflicts:** Library `package.json` `exports` maps may not include the condition your bundler uses. Check for `module`, `browser`, `import`, `require`.
- **TypeScript type mismatches:** React 19 ships its own types. Remove `@types/react` or ensure versions align. `@types/react` is needed for React 18.
