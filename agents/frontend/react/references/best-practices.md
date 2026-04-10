# React Best Practices Reference

Component patterns, performance optimization, accessibility, and testing guidance.

---

## Component Patterns

### Custom Hooks for Logic Reuse

Extract stateful logic into `use*` functions. Custom hooks can call other hooks, compose effects, and return any values.

```jsx
function useLocalStorage(key, initialValue) {
  const [value, setValue] = useState(() => {
    try { return JSON.parse(localStorage.getItem(key)) ?? initialValue; }
    catch { return initialValue; }
  });

  const setStoredValue = useCallback((newValue) => {
    setValue(newValue);
    localStorage.setItem(key, JSON.stringify(newValue));
  }, [key]);

  return [value, setStoredValue];
}
```

### Compound Components

Export a parent component alongside related child components that share state via context. Used by design systems for composable UI (e.g., `<Select>/<Select.Option>`, `<Tabs>/<Tabs.Tab>`).

### Controlled vs Uncontrolled Components

- **Controlled:** React state is the source of truth. Parent manages value + `onChange`. Enables validation and derived state.
- **Uncontrolled:** DOM holds state; access via `ref`. Simpler for one-off forms, file inputs.

Prefer controlled components for forms requiring validation or cross-field interaction. React 19 Actions default to uncontrolled inputs with `FormData`.

### Co-locating State

Keep state as close as possible to where it is used. When siblings need shared state, lift to the closest common ancestor. This limits re-renders to the smallest subtree.

### Container/Presentational (Historical)

Before hooks, "container" components held logic and "presentational" components were stateless. Hooks replaced this: logic lives in custom hooks. The mental model still applies for separating concerns.

### Higher-Order Components and Render Props (Legacy)

HOCs and render props were pre-hooks patterns. Still encountered in older codebases. Replace with hooks in new code.

---

## Performance

### React.memo

Wraps a function component to skip re-rendering when props are shallowly equal.

```jsx
const ExpensiveList = React.memo(function ExpensiveList({ items }) {
  return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>;
});
```

Use only when profiling confirms unnecessary re-renders cause measurable slowness. With React Compiler (19), manual `memo` is rarely needed.

### Code Splitting with React.lazy

```jsx
const Dashboard = React.lazy(() => import('./Dashboard'));

<Suspense fallback={<Spinner />}>
  <Dashboard />
</Suspense>
```

Each dynamic import creates a separate JS chunk. Split at route boundaries for maximum impact.

### Virtualization

For lists of hundreds or thousands of items, render only visible rows:
- **react-window:** Lightweight, fixed and variable size lists/grids
- **TanStack Virtual:** Headless, flexible, dynamic measurement

### Avoiding Prop Drilling

When props pass through 3+ layers without being used by intermediate components:
- Context (infrequent updates)
- External state manager (frequent updates)
- Component composition (restructure the tree)

### Profiling

Use React DevTools Profiler to record interactions and inspect render durations. The `<Profiler>` API provides programmatic access:

```jsx
<Profiler id="Nav" onRender={(id, phase, actualDuration) => {
  console.log(id, phase, actualDuration);
}}>
  <Navigation />
</Profiler>
```

A component taking >16ms per render (one frame at 60fps) is a candidate for optimization.

### Patterns That Cause Unnecessary Re-renders

- Object/array literals in JSX props (new reference each render)
- Inline arrow functions as props (new function each render)
- Context value not memoized (all consumers re-render)
- Parent re-renders without state change guard (add `React.memo`)

---

## Accessibility

### ARIA in JSX

All ARIA attributes use their hyphenated form in JSX (`aria-label`, `aria-expanded`, `data-testid`). Common patterns:
- `aria-label` / `aria-labelledby` -- name form inputs without visible labels
- `aria-describedby` -- link error messages to inputs
- `aria-live` -- announce dynamic updates to screen readers
- `role` -- when semantic HTML is not sufficient

### Focus Management

After modal open, move focus inside. After close, return focus to trigger. Libraries like `@radix-ui/react-dialog` and `react-aria` handle focus trapping automatically.

### Keyboard Navigation

All interactive elements reachable by Tab. Enter/Space activate buttons. Escape closes modals. Arrow keys navigate within compound widgets. Use native `<button>` and `<a>` elements for built-in keyboard support.

### Semantic HTML

Prefer `<nav>`, `<main>`, `<section>`, `<header>`, `<footer>`, `<article>`, `<aside>` over generic `<div>`. Maintain heading hierarchy (`h1`-`h6`) without skipping levels.

### Testing for Accessibility

- `eslint-plugin-jsx-a11y` -- static linting for common ARIA mistakes
- `axe-core` / `jest-axe` -- automated accessibility rule checking in tests
- Screen reader testing: NVDA + Firefox (Windows), VoiceOver + Safari (macOS)

---

## Testing

### React Testing Library Philosophy

Test behavior from the user's perspective, not implementation details. Query the DOM by role, label, text -- not by CSS class or component internals.

```jsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

test('shows error on empty submit', async () => {
  const user = userEvent.setup();
  render(<LoginForm />);
  await user.click(screen.getByRole('button', { name: /submit/i }));
  expect(screen.getByRole('alert')).toHaveTextContent('Email is required');
});
```

### Query Priority

1. `getByRole` -- most accessible, catches ARIA issues
2. `getByLabelText` -- form inputs
3. `getByPlaceholderText` -- avoid if possible
4. `getByText` -- static content
5. `getByTestId` -- last resort

**Variants:** `getBy*` (throws), `queryBy*` (null if absent), `findBy*` (async).

### userEvent vs fireEvent

Prefer `userEvent` (v14+) over `fireEvent`. `userEvent` simulates complete browser event sequences. `fireEvent` dispatches a single event.

### Testing Hooks with renderHook

```jsx
import { renderHook, act } from '@testing-library/react';

test('useCounter increments', () => {
  const { result } = renderHook(() => useCounter(0));
  act(() => result.current.increment());
  expect(result.current.count).toBe(1);
});
```

### API Mocking with MSW

Mock Service Worker intercepts requests at the Service Worker (browser) or Node.js level. Avoids mocking `fetch`/`axios` directly.

```js
import { http, HttpResponse } from 'msw';
export const handlers = [
  http.get('/api/users', () => HttpResponse.json([{ id: 1, name: 'Alice' }])),
];
```

### Test Runners

- **Vitest:** Fast, ESM-native, Jest-compatible API. Recommended for Vite projects.
- **Jest:** Mature ecosystem. Requires configuration for ESM and JSX.

Both integrate with RTL via `@testing-library/jest-dom` matchers.
