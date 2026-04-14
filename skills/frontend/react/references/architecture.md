# React Architecture Reference

Cross-version fundamentals covering the component model, virtual DOM, Fiber, hooks, concurrent features, Context, error boundaries, and rendering environments.

---

## Component Model

### Function Components

Function components are the standard in modern React. A function component accepts a `props` object and returns React elements (JSX).

```jsx
function Greeting({ name, children }) {
  return (
    <div>
      <h1>Hello, {name}</h1>
      {children}
    </div>
  );
}
```

**Key characteristics:**
- Props are read-only -- components must never mutate their own props
- Return value is a React element tree (or `null` to render nothing)
- State and side effects are managed entirely through hooks
- No `this` binding complexity; closures capture values at render time

### Class Components (Legacy)

Class components extend `React.Component` and implement a `render()` method. Still supported but only recommended for error boundaries (the only class-only API). Lifecycle methods: `componentDidMount`, `componentDidUpdate`, `componentWillUnmount`, `shouldComponentUpdate`, `getDerivedStateFromProps`.

### JSX Compilation

JSX is syntactic sugar compiled by Babel/SWC. The automatic JSX transform (React 17+) imports `jsx()` from `react/jsx-runtime` and does not require `import React` in every file.

```jsx
// Source
const el = <Button color="blue">Click</Button>;

// Compiled (automatic runtime)
import { jsx as _jsx } from 'react/jsx-runtime';
const el = _jsx(Button, { color: "blue", children: "Click" });
```

### Props, Children, and Keys

- **Props:** Plain object passed by parent. `children` is a special prop containing nested content.
- **Key:** String/number hint for the reconciler on list items. Keys must be stable, unique among siblings, and not derived from array index when the list can reorder. Keys are not passed as a prop to the component.
- **Children API:** `React.Children.map`, `React.cloneElement` -- rarely needed in modern code; prefer explicit props or context.

### Pure Rendering Model

React assumes purity: same props and state produce the same output. React Compiler (React 19) enforces this automatically. Violating purity (mutating external variables during render, generating random values in render) causes bugs in concurrent mode because React may render multiple times before committing.

**StrictMode** double-invokes render functions in development to surface purity violations.

### Composition Over Inheritance

Components compose by nesting, passing components as props, or using render props. Inheritance is not a React pattern. Custom hooks replace the mixin pattern.

---

## Virtual DOM and Reconciliation

### React Element Tree

A React element is a plain JavaScript object:

```js
{
  type: 'div',        // string for DOM, function/class for components
  props: { className: 'container', children: [...] },
  key: null,
  ref: null
}
```

Elements are cheap to create. The element tree describes what should exist; the reconciler determines what needs to change.

### Diffing Algorithm (O(n) Heuristic)

1. **Same type = update in place.** If the type matches, React reconciles props/children on the existing instance.
2. **Different type = tear down and remount.** Old subtree unmounted, new one mounted.
3. **Keys stabilize list children.** React matches old/new elements by `key` regardless of position.

**Pitfalls:**
- Never define a component function inside another component's render -- new type reference every render causes full remount.
- Unstable keys (`Math.random()`, array index on reorderable lists) degrade reconciliation correctness.

### Why Virtual DOM

- **Batched DOM mutations:** All changes from a render cycle applied in one pass, reducing layout thrashing.
- **Cross-platform rendering:** Element tree is renderer-agnostic (React DOM, React Native, react-three-fiber, ink).
- **Diffing before committing:** React can defer, interrupt, and reprioritize work before touching the real DOM (Fiber).

---

## Fiber Architecture

Fiber (React 16) replaced the synchronous recursive reconciler with an incremental, interruptible engine.

### Fiber Nodes

Each component instance or DOM element is a fiber node -- a mutable JS object holding:
- Component type and key
- Props and state
- References to parent, child, and sibling fibers (linked list, not tree)
- Effect tags (what DOM mutations to perform)
- Work-in-progress alternate

### Double Buffering

Two fiber trees:
- **Current tree:** Rendered on screen.
- **Work-in-progress (WIP) tree:** Being computed for the next render.

Each fiber has an `alternate` pointer to its counterpart. When the WIP tree is committed, it becomes the current tree. This allows React to abandon an in-progress render without affecting the visible UI.

### Interruptible Rendering

Rendering is broken into discrete units of work (one fiber at a time). Between units, React checks for higher-priority work and can pause. This enables concurrent features: start a low-priority render, get interrupted by a high-priority one, resume later.

### Priority Lanes

Updates are assigned lanes (bit-flag priority levels):
- **Sync/Blocking:** Discrete user input (click, keypress)
- **Default:** Normal state updates
- **Transition:** `startTransition` updates -- can be interrupted
- **Deferred:** `useDeferredValue` -- lowest priority
- **Idle/Offscreen:** Hidden Suspense content

---

## Hooks System

### Rules of Hooks

1. **Top level only** -- never inside loops, conditions, or nested functions. Hook call order must be identical every render.
2. **React functions only** -- function components or custom hooks (`use*`). Not event handlers, class methods, or plain JS.

ESLint plugin `eslint-plugin-react-hooks` enforces these rules.

### Core Hooks

| Hook | Purpose | Notes |
|---|---|---|
| `useState(init)` | Local state | `[value, setter]`. `init` can be lazy function. |
| `useReducer(reducer, init)` | Complex state logic | Dispatch actions. Like Redux at component scale. |
| `useEffect(fn, deps)` | Side effects after render | Cleanup returned from fn. Runs after paint. |
| `useLayoutEffect(fn, deps)` | DOM measurements before paint | Synchronous; blocks paint. Use sparingly. |
| `useContext(Context)` | Consume context | Re-renders when context value changes. |
| `useRef(init)` | Mutable ref / DOM ref | `.current` mutation does not trigger re-render. |
| `useMemo(fn, deps)` | Memoize computation | Re-runs when deps change. |
| `useCallback(fn, deps)` | Memoize function identity | Prevents child re-renders from new function refs. |
| `useImperativeHandle(ref, fn, deps)` | Customize exposed ref | Pair with `forwardRef` (18) or ref-as-prop (19). |
| `useSyncExternalStore(sub, snap)` | Concurrent-safe external store | Replaces ad-hoc Redux selectors in concurrent mode. |
| `useId()` | Stable unique ID | SSR-safe; never use for list keys. |
| `useTransition()` | Mark update as transition | Returns `[isPending, startTransition]`. React 18+. |
| `useDeferredValue(value)` | Defer re-rendering a value | Cooperative with scheduler. React 18+. |

### React 19 Hooks

| Hook | Purpose |
|---|---|
| `useActionState(fn, init)` | Form action state + pending flag |
| `useOptimistic(state, updateFn)` | Optimistic UI during async operations |
| `useFormStatus()` | Read nearest ancestor form's pending/data |
| `use(promise \| context)` | Read resources during render; can be called conditionally |

### Dependency Arrays and Stale Closures

Hooks with `deps` arrays re-run when any dependency changes (shallow `Object.is`). **Stale closure** is the most common React bug: a function captures a variable at creation time and the dep array is incomplete, so the function holds an old value.

```jsx
// Bug: count is stale
useEffect(() => {
  const id = setInterval(() => setCount(count + 1), 1000);
  return () => clearInterval(id);
}, []); // missing count

// Fix: functional updater
useEffect(() => {
  const id = setInterval(() => setCount(c => c + 1), 1000);
  return () => clearInterval(id);
}, []);
```

---

## Concurrent Features

React 18 introduced the concurrent renderer via `createRoot`. Concurrent features allow React to prepare multiple UI states simultaneously.

### startTransition

Marks a state update as non-urgent. React renders it in the background and can interrupt it for urgent updates. `useTransition()` provides an `isPending` flag.

### useDeferredValue

Keeps a stale copy of a value until React has time to compute with the new value. Useful for deferring re-renders of expensive children.

### Suspense

Catches promises thrown by components and shows fallback UI. Works with `React.lazy()`, data fetching libraries (TanStack Query, SWR, Relay), and Server Components.

### Automatic Batching

React 18 batches all state updates regardless of origin (setTimeout, promises, native events). Previously only React event handlers were batched. `flushSync` opts out.

---

## Context System

```jsx
const ThemeContext = createContext('light');

function App() {
  return (
    <ThemeContext value="dark">  {/* React 19 syntax */}
      <Page />
    </ThemeContext>
  );
}

function Button() {
  const theme = useContext(ThemeContext);
  return <button className={theme}>Click</button>;
}
```

### Performance Implications

When a Provider's `value` changes (new reference), every consumer re-renders. Mitigate with:
- **Split contexts** for frequently-changing vs stable values
- **Memoize the value** with `useMemo`
- **Context selectors** via third-party libraries (`use-context-selector`)
- **External state managers** (Zustand, Jotai, Redux Toolkit) for granular subscriptions

### When to Use Context vs External State

| Use Context For | Use External Manager For |
|---|---|
| Theme, locale, auth, feature flags | Frequently-updated shared state |
| Avoiding prop drilling | Complex state transitions at app scale |
| Low-frequency updates | Cross-component subscriptions without blanket re-renders |

---

## Error Boundaries

Class-only API that catches render errors in the subtree.

```jsx
class ErrorBoundary extends React.Component {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    logErrorToService(error, errorInfo.componentStack);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? <h2>Something went wrong.</h2>;
    }
    return this.props.children;
  }
}
```

**Limitations:** Does not catch event handler errors, async errors outside rendering, or errors in the boundary itself. Use `react-error-boundary` library for hooks-friendly wrapper.

---

## Rendering Environments

### Client Rendering

```jsx
import { createRoot } from 'react-dom/client';
const root = createRoot(document.getElementById('root'));
root.render(<App />);
```

`createRoot` enables concurrent mode. `root.unmount()` tears down the tree.

### Server Rendering (Streaming)

| API | Runtime | Output |
|---|---|---|
| `renderToPipeableStream` | Node.js | Pipe stream |
| `renderToReadableStream` | Edge (Deno, CF Workers, Bun) | Web stream |
| `renderToString` | Any | String (no streaming, legacy) |

Streaming SSR sends the HTML shell immediately. Suspense fallbacks appear first; resolved content streams in with inline `<script>` tags to swap it into position.

### Static Generation (React 19)

`prerender` and `prerenderToNodeStream` in `react-dom/static` wait for all data before generating HTML.

### Hydration

```jsx
import { hydrateRoot } from 'react-dom/client';
hydrateRoot(document.getElementById('root'), <App />);
```

Selective hydration (React 18+): Suspense boundaries hydrate independently; user-interacted areas are prioritized.

---

## React DevTools

### Component Tree

Full hierarchy inspector. Click a component for props, state, context, hooks values. Search by name. Jump to source definition.

### Profiler

- **Flame chart:** Width = render duration. Gray = didn't render. Colored = rendered.
- **Ranked chart:** Components sorted by render time, highest first.
- **Why did this render?** Toggle shows cause: props change, state change, context change, parent re-render.

### Highlight Updates

Flashes colored borders on re-rendering components. Intensity indicates frequency. Useful for spotting unexpected re-renders.
