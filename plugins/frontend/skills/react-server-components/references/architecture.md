# RSC Architecture Reference

Rendering pipeline, boundary rules, serialization, and framework integration for React Server Components.

---

## Rendering Model

React Server Components split the component tree across two environments: server and client.

### Server Components

- Render exclusively on the server -- zero JavaScript shipped to the client
- Can be `async` functions with direct `await` in the component body
- Have access to server-only resources: databases, file system, environment secrets, internal APIs
- Output is an RSC payload (serializable React tree format), not HTML
- Cannot use stateful hooks (`useState`, `useReducer`), lifecycle hooks (`useEffect`), or browser APIs

### Client Components

- Render on BOTH server (SSR for initial HTML) and client (hydration + interactivity)
- "Client" refers to where JS executes interactively, not where initial render happens
- Can use all React hooks, event handlers, and browser APIs
- Their JavaScript is included in the client bundle

### RSC Payload

- Not HTML -- a special serialized format describing the React component tree
- Contains component types, props, children in wire-safe representation
- Streamed to the client over the HTTP connection
- React client runtime merges RSC payload with client-rendered subtrees
- Enables re-requesting RSC payloads for navigation without full page reloads

### Rendering Pipeline

```
Server:
  1. React renders Server Components -> RSC payload
  2. RSC payload + Client Component SSR HTML -> full initial response

Client:
  1. Browser receives and displays HTML (fast first paint)
  2. React hydrates Client Components (attaches event listeners, state)
  3. RSC payload arrives (streamed), React reconciles with existing DOM
```

---

## Client/Server Boundary

### Directives

**`"use client"`** -- placed at the top of a file (before imports):
- Makes the file and ALL exported components Client Components
- Everything imported by that file in the component graph is also client-side
- It is a module boundary, not a component boundary

**Default is Server** -- any file without a directive is a Server Component in RSC-aware frameworks.

### Boundary Rules

```
Server Component -> can import and render Server Components (default)
Server Component -> can import and render Client Components (allowed)
Client Component -> CANNOT import Server Components (build error)
Client Component -> CAN receive Server Components as children/props (composition)
```

**Why no import of Server Components into Client Components:**
- Client modules are bundled for the browser
- Server Components may contain server-only code (DB queries, secrets)
- The bundler statically enforces this at build time

**Composition escape hatch:**
```tsx
// WRONG: direct import
// ClientWrapper.tsx ("use client")
import ServerChild from './ServerChild'; // Build error

// CORRECT: passed as children
// page.tsx (Server Component)
import ClientWrapper from './ClientWrapper';
import ServerChild from './ServerChild';
export default function Page() {
  return <ClientWrapper><ServerChild /></ClientWrapper>;
}
```

### Shared Components

Components with neither directive render as Server or Client depending on import context:
- Imported by Server Component -> Server Component
- Imported by Client Component -> Client Component
- Must satisfy constraints of both environments (no hooks, no DB access)

---

## Serialization Constraints

Props crossing the Server->Client boundary must be wire-safe.

### Serializable (can cross)

- Primitives: `string`, `number`, `boolean`, `null`, `undefined`
- `Date` objects
- `TypedArray` (`Uint8Array`, `Int32Array`, etc.)
- `Map` and `Set`
- Plain objects (no class instances, no prototype chains)
- Arrays
- React elements (JSX)
- `Promise` -- enables streaming; Client Components can `use(promise)`

### Not Serializable (cannot cross)

- Functions / closures (except Server Actions)
- Class instances (custom classes with methods)
- Symbols
- Circular references
- `RegExp`
- DOM nodes

### Design Implications

Cannot pass callback functions from Server to Client as props. Instead:
- Use **Server Actions** for mutations
- Move handler logic into the Client Component
- Pass only primitive data and reconstruct logic client-side

```tsx
// WRONG: function prop
<ClientButton onClick={() => db.delete(id)} />

// CORRECT: Server Action
async function deleteItem() {
  'use server';
  await db.delete(id);
}
<ClientButton onDelete={deleteItem} />
```

---

## Streaming and Suspense

### Progressive Rendering

1. Server renders the shell (layout, static content) immediately
2. Async Server Components in Suspense boundaries show fallbacks
3. As each component resolves, its RSC payload chunk streams to the client
4. React replaces fallback with resolved content -- no full re-render

### Parallel Data Fetching

Sibling async Server Components fetch in parallel automatically. No `Promise.all` needed at the top level. Waterfalls only occur when a child depends on parent data.

### Suspense Boundary Placement

- Wrap each independently-loading section in its own Suspense boundary
- Never wrap the entire page in one boundary (defeats streaming)
- Granular boundaries = faster perceived performance

### use() for Streaming Data

Server Components can pass Promises to Client Components. The `use()` hook reads them:

```tsx
// Server Component
export default function Page() {
  const dataPromise = fetchData(); // Promise is serializable
  return <ClientDisplay dataPromise={dataPromise} />;
}

// Client Component ("use client")
export default function ClientDisplay({ dataPromise }) {
  const data = use(dataPromise); // suspends until resolved
  return <div>{data.name}</div>;
}
```

---

## Server Actions

### Declaration

```tsx
// Option 1: inline in Server Component
async function submitForm(formData: FormData) {
  'use server';
  await db.insert({ name: formData.get('name') });
}

// Option 2: separate file
// actions.ts
'use server';
export async function updateUser(id: string, data: FormData) {
  await db.update('users', id, Object.fromEntries(data));
}
```

### Internal Mechanism

- Bundler assigns each action a hashed action ID
- Client sends POST with action ID + serialized arguments
- Server looks up, executes, returns result
- Unused actions are tree-shaken from the server bundle

### Progressive Enhancement

`<form action={serverAction}>` works without JavaScript (native form POST). With JS loaded, React intercepts for smooth UX.

### Security Model

- Server Actions are public HTTP endpoints
- Always validate session/authentication at the top of every action
- Authorize the specific resource being mutated
- Validate all `FormData` with Zod or similar
- Return minimal data
- Rate-limit mutation actions

---

## Framework Integration

### Next.js App Router

Primary production RSC implementation (Next.js 13.4+).

**Directory conventions:**
```
app/
  layout.tsx      -> Server Component (wraps all pages)
  page.tsx        -> Server Component (route page)
  loading.tsx     -> Suspense fallback
  error.tsx       -> Error boundary (must be "use client")
  not-found.tsx   -> 404 UI
  route.ts        -> API route handler
```

**Caching layers:**

| Cache | Stores | Invalidated By |
|---|---|---|
| Request Memoization | `fetch` deduplication | Request ends |
| Data Cache | `fetch` responses | `revalidateTag`, `no-store` |
| Full Route Cache | RSC payload + HTML | Revalidation, redeploy |
| Router Cache | Client-side RSC payload | Navigation, `router.refresh()` |

**Metadata:**
```tsx
export async function generateMetadata({ params }) {
  const post = await fetchPost(params.slug);
  return { title: post.title, description: post.excerpt };
}
```

### React Router v7 / Remix

Loaders and actions serve a similar role. Full RSC support is in active development.

### Waku

Lightweight RSC framework closer to React primitives. Suitable for learning.

### Bundler Requirements

Any RSC implementation needs:
1. Bundler that understands `"use client"` / `"use server"` directives
2. Separate server and client build graphs
3. Server runtime for streaming RSC payloads
4. Client runtime (`react-server-dom-*` packages)
