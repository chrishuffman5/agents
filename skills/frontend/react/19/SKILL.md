---
name: frontend-react-19
description: "Expert agent for React 19. Covers Actions (form actions, useActionState, useOptimistic, useFormStatus), React Compiler 1.0 (automatic memoization), use() hook, ref-as-prop (no forwardRef), document metadata hoisting, Context as Provider, custom elements support, improved error reporting, resource preloading APIs, static rendering, and removed/deprecated APIs. WHEN: \"React 19\", \"useActionState\", \"useOptimistic\", \"useFormStatus\", \"use hook\", \"React Compiler\", \"react compiler\", \"ref as prop\", \"document metadata\", \"form action\", \"Server Actions\", \"preinit\", \"preload\"."
license: MIT
metadata:
  version: "1.0.0"
---

# React 19 Specialist

You are a specialist in React 19 (current stable, 19.2.x as of April 2026). React 19 reduces boilerplate for async data flows, formalizes Server Components, and eliminates manual memoization via the Compiler. Every feature below is stable.

## Actions

Actions are async functions passed to `<form action={fn}>` or `<button formAction={fn}>`. React manages pending state, error boundaries, and form reset automatically.

### Form Actions

```tsx
<form action={asyncFn}>       {/* React calls fn with FormData on submit */}
  <input name="email" />
  <button type="submit">Submit</button>
</form>
```

On success, React automatically resets uncontrolled form fields. `<button formAction={fn}>` overrides the parent form's action for multi-action forms.

### Progressive Enhancement

When frameworks serialize Server Actions, forms work without JavaScript via native HTML form submission. With JS loaded, React intercepts for a smoother experience.

---

## New Hooks

### useActionState

```tsx
const [state, action, isPending] = useActionState(fn, initialState, permalink?);
```

Manages form action state. `fn(previousState, formData)` receives prior result and `FormData`. Returns current state, wrapped action for the form, and pending flag. Replaces deprecated `useFormState`.

```tsx
import { useActionState } from "react";

async function submitForm(prev: State, data: FormData): Promise<State> {
  const result = await saveToServer(data.get("email") as string);
  if (!result.ok) return { message: result.error };
  return null;
}

function ContactForm() {
  const [state, action, isPending] = useActionState(submitForm, null);
  return (
    <form action={action}>
      <input name="email" type="email" required />
      <button disabled={isPending}>{isPending ? "Saving..." : "Save"}</button>
      {state?.message && <p role="alert">{state.message}</p>}
    </form>
  );
}
```

### useOptimistic

```tsx
const [optimisticState, addOptimistic] = useOptimistic(state, updateFn?);
```

Shows an optimistic value while an async operation is pending. Automatically reverts to real state on completion or error.

```tsx
const [optimisticMessages, addOptimistic] = useOptimistic(
  messages,
  (state: Message[], newText: string) => [
    ...state,
    { id: crypto.randomUUID(), text: newText, sending: true },
  ]
);

async function sendMessage(formData: FormData) {
  addOptimistic(formData.get("message") as string);
  await postMessage(formData.get("message") as string);
}
```

### useFormStatus

```tsx
const { pending, data, method, action } = useFormStatus();
```

Must be called from a component **inside** a `<form>`. Reads the nearest ancestor form's pending state without prop drilling.

```tsx
import { useFormStatus } from "react-dom";

function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>
    {pending ? "Submitting..." : "Submit"}
  </button>;
}
```

### use() (Resource Hook)

```tsx
const value = use(promise | context);
```

Reads a resource during render. Unlike other hooks, `use` can be called conditionally and inside loops.

```tsx
// With a Promise (integrates with Suspense)
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspends until resolved
  return <h1>{user.name}</h1>;
}

// With Context (replaces useContext in conditional paths)
function ConditionalTheme({ showTheme }: { showTheme: boolean }) {
  if (showTheme) {
    const theme = use(ThemeContext);
    return <div style={{ color: theme.color }}>Themed</div>;
  }
  return <div>No theme</div>;
}
```

---

## React Compiler 1.0

The React Compiler (previously "React Forget") automatically memoizes components and values, replacing manual `useMemo`, `useCallback`, and `React.memo`.

### Installation

```bash
npm install -D babel-plugin-react-compiler eslint-plugin-react-compiler
```

### How It Works

The compiler analyzes component and hook code, identifies stable values, and inserts memoization. Code that follows the Rules of React is transformed; non-conforming code is skipped with a warning.

### Opt-In Strategies

```tsx
"use memo";           // opt in entire file
function MyComponent() {
  "use memo";         // opt in single component
}
function Problematic() {
  "use no memo";      // opt out (compiler misbehaves)
}
```

### ESLint Plugin

```json
{
  "plugins": ["react-compiler"],
  "rules": { "react-compiler/react-compiler": "error" }
}
```

### Incompatible Patterns

| Pattern | Issue |
|---|---|
| Mutating state during render | Breaks referential stability |
| Mutating props or context values | Same |
| Non-idiomatic hook calls (in loops without `use`) | Cannot be statically analyzed |
| Dynamic hook names | Cannot be tracked |

---

## ref as Regular Prop

`forwardRef` is no longer needed. Function components accept `ref` directly.

```tsx
// React 19
function Input({ label, ref }: { label: string; ref?: React.Ref<HTMLInputElement> }) {
  return <input ref={ref} aria-label={label} />;
}

const inputRef = useRef<HTMLInputElement>(null);
<Input label="Name" ref={inputRef} />
```

### Ref Cleanup Functions

Ref callbacks can return a cleanup function:

```tsx
<div ref={(node) => {
  if (!node) return;
  const observer = new ResizeObserver(() => {
    console.log(node.getBoundingClientRect());
  });
  observer.observe(node);
  return () => observer.disconnect(); // cleanup on unmount
}} />
```

---

## Document Metadata

Tags placed anywhere in the component tree are automatically hoisted to `<head>`.

```tsx
function BlogPost({ title, description }) {
  return (
    <article>
      <title>{title}</title>
      <meta name="description" content={description} />
      <link rel="canonical" href={`https://example.com/posts/${slug}`} />
      <h1>{title}</h1>
    </article>
  );
}
```

### Stylesheet Precedence

```tsx
<link rel="stylesheet" href="/base.css" precedence="default" />
<link rel="stylesheet" href="/theme.css" precedence="high" />
// React deduplicates: same href inserted only once
```

### Resource Preloading

```tsx
import { prefetchDNS, preconnect, preload, preinit } from "react-dom";

prefetchDNS("https://fonts.googleapis.com");
preconnect("https://cdn.example.com");
preload("https://cdn.example.com/hero.jpg", { as: "image" });
preinit("https://cdn.example.com/analytics.js", { as: "script" });
```

| API | Effect |
|---|---|
| `prefetchDNS` | DNS prefetch only |
| `preconnect` | DNS + TCP + TLS |
| `preload` | Fetch and cache resource |
| `preinit` | Fetch, cache, and execute/apply |

---

## Context as Provider

The `.Provider` wrapper is no longer required:

```tsx
// React 19
const ThemeContext = createContext("light");

function App() {
  return (
    <ThemeContext value="dark">
      <Page />
    </ThemeContext>
  );
}
```

`<Context.Provider>` still works but is deprecated.

---

## Improved Error Reporting

### Hydration Error Diffs

React 19 shows a diff between server and client output:
```
  <div>
-   Server content
+   Client content
  </div>
```

### Error Handler Options

```tsx
const root = createRoot(document.getElementById("root")!, {
  onRecoverableError(error, errorInfo) {
    console.warn("Recovered:", error, errorInfo.componentStack);
  },
  onUncaughtError(error, errorInfo) {
    reportToErrorService(error, errorInfo.componentStack);
  },
});
```

---

## Custom Elements

React 19 sets properties (not just attributes) on custom elements, matching browser behavior:

```tsx
<my-chart
  data={chartData}               // set as property
  onDataUpdate={handleUpdate}    // event listener attached correctly
/>
```

---

## Removed and Deprecated APIs

| API | Status | Migration |
|---|---|---|
| `forwardRef` | Deprecated | Pass `ref` as a regular prop |
| `<Context.Provider>` | Deprecated | Use `<Context value={...}>` |
| `useFormState` (react-dom) | Removed | Use `useActionState` (react) |
| `defaultProps` on function components | Removed | ES6 destructure defaults |
| `propTypes` | Removed | Use TypeScript |
| String refs | Removed | Use `useRef` or callback refs |
| Legacy context (`contextTypes`) | Removed | Use `createContext`/`useContext` |
| `act` from `react-dom/test-utils` | Removed | Import from `react` |
| `ReactDOMTestUtils` | Removed | Use `@testing-library/react` |

---

## Server Components (Stable)

Server Components are stable in React 19. They render on the server with direct access to databases and APIs, shipping zero JavaScript to the client.

Key directives:
- `"use server"` -- marks Server Actions (callable from client)
- `"use client"` -- marks client boundary (interactivity required)

For deep coverage, see `server-components/SKILL.md`.

---

## Static Rendering

`prerender` and `prerenderToNodeStream` in `react-dom/static` wait for all data before generating HTML. Used by frameworks for static site generation.

---

## Quick Reference

### React 19 Hooks

| Hook | Purpose |
|---|---|
| `useActionState` | Form action state + pending |
| `useOptimistic` | Optimistic UI during async ops |
| `useFormStatus` | Read nearest form's pending/data |
| `use` | Read promise or context conditionally |

### Key New APIs

| API | Purpose |
|---|---|
| `<form action={fn}>` | Form actions with automatic pending/reset |
| `<Context value={...}>` | Provider without `.Provider` wrapper |
| `ref` as prop | No `forwardRef` needed |
| `prefetchDNS/preconnect/preload/preinit` | Resource preloading |
| `prerender` / `prerenderToNodeStream` | Static HTML generation |
| React Compiler | Automatic memoization |
