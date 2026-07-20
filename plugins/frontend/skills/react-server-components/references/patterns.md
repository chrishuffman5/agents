# RSC Patterns Reference

Data fetching, composition patterns, "use client" placement strategy, and caching.

---

## Data Fetching in Server Components

Direct data access in render is the defining RSC capability. No `useEffect`, no client-side `fetch` for initial data.

### Direct Database Access

```tsx
import { db } from '@/lib/database';

export default async function DashboardPage() {
  const [user, stats] = await Promise.all([
    db.users.findOne({ id: currentUserId() }),
    db.analytics.getStats({ period: '30d' }),
  ]);

  return (
    <main>
      <UserHeader user={user} />
      <StatsPanel stats={stats} />
    </main>
  );
}
```

### Key Principles

- Data flows DOWN through props (no callbacks from parent to child)
- Sibling components fetch independently and in parallel
- Secret keys and connection strings never reach the client bundle
- No loading/error state boilerplate -- Suspense and error boundaries handle it

### Fetch Deduplication

React automatically deduplicates identical `fetch()` calls during a single render pass. Multiple components calling `fetch('https://api.example.com/user')` execute one request.

For custom DB clients, use `React.cache()` for request-scoped memoization:

```tsx
import { cache } from 'react';

export const getUser = cache(async (id: string) => {
  return db.users.findOne({ id });
});
// Multiple components calling getUser(id) with same id -> one DB query per request
```

---

## Composition Patterns

### Pattern 1: Data-Down (Most Common)

Server Component fetches data and passes it as props to a Client Component for interactivity.

```tsx
// Server Component: fetches and passes
export default async function ProductPage({ id }) {
  const product = await fetchProduct(id);
  return <AddToCartButton product={product} />;
}

// Client Component: receives data, handles interaction
// AddToCartButton.tsx ("use client")
export default function AddToCartButton({ product }) {
  const [added, setAdded] = useState(false);
  return <button onClick={() => setAdded(true)}>{product.name}</button>;
}
```

### Pattern 2: Slot (Server Component as Children)

Client Component wrapper receives Server Component content via `children` prop. Allows wrapping with context, animation, or layout without making content client-side.

```tsx
// Modal.tsx ("use client")
export default function Modal({ children }) {
  const [open, setOpen] = useState(true);
  return open ? <dialog>{children}</dialog> : null;
}

// page.tsx (Server Component)
export default async function Page() {
  const data = await fetchModalData();
  return <Modal><ServerContent data={data} /></Modal>;
}
```

### Pattern 3: Donut (Server -> Client -> Server via Children)

The "donut" or "hole" pattern enables Server Components deep inside Client Component subtrees. The Client Component acts as a shell with a hole filled by Server Component children.

```tsx
// layout.tsx (Server Component)
export default function RootLayout({ children }) {
  return (
    <html><body>
      <ClientThemeProvider>
        {children} {/* Filled by Server Components from the route */}
      </ClientThemeProvider>
    </body></html>
  );
}
```

### Pattern 4: Shared Components

Components without a directive render as Server or Client based on import context:
- Imported by Server Component -> Server Component
- Imported by Client Component -> Client Component

These must satisfy both environments: no hooks, no DB access, no browser APIs. Use sparingly for pure presentational components.

### Pattern 5: Server for Expensive Computation

Offload heavy parsing, formatting, or transformation to the server:

```tsx
import { marked } from 'marked'; // NOT shipped to client

export default function MarkdownContent({ raw }) {
  const html = marked.parse(raw);
  return <div dangerouslySetInnerHTML={{ __html: html }} />;
}
```

Libraries used only in Server Components are excluded from the client bundle.

---

## "use client" Placement Strategy

### Core Principle

Push `"use client"` as far DOWN the component tree as possible.

### Cost of "use client" Too High

- Every component in that subtree becomes a Client Component
- All code ships in the client JS bundle
- Data must be fetched client-side instead of server-side
- RSC benefits (direct DB access, zero bundle, streaming) are lost

### Audit Checklist

A component needs `"use client"` if it uses:
- `useState`, `useReducer`, `useContext`
- `useEffect`, `useLayoutEffect`, `useInsertionEffect`
- `useRef` for DOM manipulation
- Event handlers: `onClick`, `onChange`, `onSubmit`, etc.
- Browser APIs: `window`, `document`, `localStorage`
- Third-party libraries that use any of the above

### Refactoring: Extract the Interactive Leaf

```tsx
// WRONG: entire card marked "use client" for one button
// ProductCard.tsx ("use client")
export default function ProductCard({ product }) {
  const [liked, setLiked] = useState(false);
  return (
    <div>
      <img src={product.image} />
      <h2>{product.name}</h2>
      <p>{product.description}</p>
      <span>{product.price}</span>
      <button onClick={() => setLiked(!liked)}>Like</button>
    </div>
  );
}

// CORRECT: only the interactive button is a Client Component
// LikeButton.tsx ("use client")
export default function LikeButton() {
  const [liked, setLiked] = useState(false);
  return <button onClick={() => setLiked(!liked)}>Like</button>;
}

// ProductCard.tsx (Server Component)
import LikeButton from './LikeButton';
export default function ProductCard({ product }) {
  return (
    <div>
      <img src={product.image} />
      <h2>{product.name}</h2>
      <p>{product.description}</p>
      <span>{product.price}</span>
      <LikeButton />
    </div>
  );
}
```

### Common Mistake Locations

- `app/layout.tsx` -- making the root layout a Client Component cascades to every route
- `components/providers.tsx` -- Context providers often carry `"use client"` too high. Use the children slot pattern:

```tsx
// providers.tsx ("use client")
export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState('light');
  return <ThemeContext.Provider value={{ theme, setTheme }}>
    {children}
  </ThemeContext.Provider>;
}

// layout.tsx (Server Component)
import { ThemeProvider } from './providers';
export default function Layout({ children }) {
  return <ThemeProvider>{children}</ThemeProvider>;
  // children are still Server Components
}
```

### Decision Tree

```
Does the component use hooks, events, or browser APIs?
  -> YES: Can you extract ONLY the interactive part?
    -> YES: Extract. Keep the rest as Server Component.
    -> NO: Add "use client" to the whole component.
  -> NO: Keep as Server Component.
```

---

## Caching and Revalidation

### RSC Payload Caching

RSC payloads can be cached at the HTTP level (CDN) or in memory. Navigation between cached routes is near-instant.

### Next.js Revalidation

```tsx
// Time-based
export const revalidate = 60; // seconds

// On-demand in Server Actions
import { revalidatePath, revalidateTag } from 'next/cache';

async function updateProduct(id, data) {
  'use server';
  await db.products.update(id, data);
  revalidatePath('/products');
  revalidateTag('product-list');
}
```

### Fetch Cache Options (Next.js)

```tsx
await fetch(url, { cache: 'force-cache' });           // cache indefinitely
await fetch(url, { cache: 'no-store' });               // never cache
await fetch(url, { next: { revalidate: 3600 } });      // time-based
await fetch(url, { next: { tags: ['product-list'] } }); // tag for invalidation
```

### Cache Invalidation Strategy

- Tag fetches and revalidate tags on mutation (most predictable)
- Avoid time-based for data requiring immediate consistency
- Use `no-store` for personalized/user-specific content (avoid CDN caching)
