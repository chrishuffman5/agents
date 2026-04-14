# Pages Router to App Router Migration

Step-by-step guide for incrementally migrating from the Next.js Pages Router to the App Router.

---

## Overview

The App Router and Pages Router coexist in the same project. `app/` takes priority over `pages/` for the same routes. Migration can be done incrementally -- one page at a time.

---

## Step 1: Create app/ Directory

Create `app/` alongside the existing `pages/` directory:

```
project/
  app/           <- new App Router routes
  pages/         <- existing Pages Router routes (still active)
  public/
  next.config.ts
```

Both routers work simultaneously. Routes in `app/` take precedence over the same routes in `pages/`.

---

## Step 2: Migrate the Root Layout

Create `app/layout.tsx` with the shell previously in `_app.tsx` and `_document.tsx`:

```tsx
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
```

This replaces both `_app.tsx` (application wrapper) and `_document.tsx` (HTML structure).

---

## Step 3: Migrate Pages One at a Time

For each page, create the equivalent in `app/` and delete the `pages/` version.

### Route Mapping

| Pages Router | App Router |
|---|---|
| `pages/index.tsx` | `app/page.tsx` |
| `pages/about.tsx` | `app/about/page.tsx` |
| `pages/blog/[slug].tsx` | `app/blog/[slug]/page.tsx` |
| `pages/blog/[...slug].tsx` | `app/blog/[...slug]/page.tsx` |
| `pages/api/users.ts` | `app/api/users/route.ts` |
| `pages/api/users/[id].ts` | `app/api/users/[id]/route.ts` |
| `pages/404.tsx` | `app/not-found.tsx` |
| `pages/500.tsx` | `app/error.tsx` or `app/global-error.tsx` |
| `pages/_error.tsx` | `app/error.tsx` |

---

## Step 4: Migrate Data Fetching

### Data Fetching Mapping

| Pages Router | App Router Equivalent |
|---|---|
| `getServerSideProps` | `async` Server Component (fetch data directly) |
| `getStaticProps` | `async` Server Component + `cache: "force-cache"` |
| `getStaticPaths` | `generateStaticParams` |
| `getInitialProps` | `async` Server Component or Server Action |

### getServerSideProps -> Server Component

```tsx
// BEFORE -- pages/dashboard.tsx
export async function getServerSideProps() {
  const data = await fetchDashboardData();
  return { props: { data } };
}

export default function Dashboard({ data }) {
  return <DashboardContent data={data} />;
}
```

```tsx
// AFTER -- app/dashboard/page.tsx
export default async function Dashboard() {
  const data = await fetchDashboardData(); // runs on every request
  return <DashboardContent data={data} />;
}
```

### getStaticProps -> Server Component with Caching

```tsx
// BEFORE -- pages/blog/[slug].tsx
export async function getStaticProps({ params }) {
  const post = await fetchPost(params.slug);
  return { props: { post }, revalidate: 60 };
}

export async function getStaticPaths() {
  const posts = await fetchAllPosts();
  return {
    paths: posts.map(p => ({ params: { slug: p.slug } })),
    fallback: "blocking",
  };
}
```

```tsx
// AFTER -- app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map((p) => ({ slug: p.slug }));
}

export const revalidate = 60; // ISR: revalidate every 60 seconds

export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await fetchPost(slug);
  return <article>{post.content}</article>;
}
```

---

## Step 5: Migrate API Routes

### Basic API Route

```tsx
// BEFORE -- pages/api/users.ts
export default function handler(req, res) {
  if (req.method === "GET") {
    const users = getUsers();
    res.json(users);
  } else if (req.method === "POST") {
    const user = createUser(req.body);
    res.status(201).json(user);
  }
}
```

```tsx
// AFTER -- app/api/users/route.ts
export async function GET() {
  const users = await getUsers();
  return Response.json(users);
}

export async function POST(request: Request) {
  const body = await request.json();
  const user = await createUser(body);
  return Response.json(user, { status: 201 });
}
```

### Key Differences

- Route Handlers use standard Web API `Request`/`Response` (not `req`/`res`)
- Each HTTP method is a separate named export
- No default export
- Use `NextRequest`/`NextResponse` for convenience helpers (cookies, headers, redirect)

---

## Step 6: Migrate Metadata

### Static Metadata

```tsx
// BEFORE -- pages/about.tsx
import Head from "next/head";

export default function About() {
  return (
    <>
      <Head>
        <title>About</title>
        <meta name="description" content="About our company" />
      </Head>
      <main>...</main>
    </>
  );
}
```

```tsx
// AFTER -- app/about/page.tsx
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "About",
  description: "About our company",
};

export default function About() {
  return <main>...</main>;
}
```

### Dynamic Metadata

```tsx
// AFTER -- app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const post = await fetchPost(slug);
  return {
    title: post.title,
    description: post.excerpt,
  };
}
```

### Title Template

```tsx
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    template: "%s | My Site",
    default: "My Site",
  },
};

// app/about/page.tsx
export const metadata: Metadata = {
  title: "About", // renders as "About | My Site"
};
```

---

## Step 7: Migrate Providers (_app.tsx)

Wrap context providers in a Client Component:

```tsx
// BEFORE -- pages/_app.tsx
import { ThemeProvider } from "next-themes";
import { SessionProvider } from "next-auth/react";

export default function App({ Component, pageProps }) {
  return (
    <SessionProvider session={pageProps.session}>
      <ThemeProvider>
        <Component {...pageProps} />
      </ThemeProvider>
    </SessionProvider>
  );
}
```

```tsx
// AFTER -- app/providers.tsx
"use client";
import { ThemeProvider } from "next-themes";
import { SessionProvider } from "next-auth/react";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider>
        {children}
      </ThemeProvider>
    </SessionProvider>
  );
}

// app/layout.tsx
import { Providers } from "./providers";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

---

## Step 8: Migrate Client-Side Navigation

```tsx
// BEFORE -- Pages Router
import Link from "next/link";
import { useRouter } from "next/router";

export default function Nav() {
  const router = useRouter();
  const handleClick = () => router.push("/dashboard");
  return <Link href="/about">About</Link>;
}
```

```tsx
// AFTER -- App Router
import Link from "next/link";
import { useRouter } from "next/navigation"; // note: next/navigation, not next/router

export default function Nav() {
  const router = useRouter();
  const handleClick = () => router.push("/dashboard");
  return <Link href="/about">About</Link>;
}
```

Key change: `useRouter` comes from `next/navigation` (not `next/router`). The API is similar but has differences (no `query` property; use `useSearchParams` instead).

---

## Migration Checklist

```
[ ] Create app/ directory alongside pages/
[ ] Create app/layout.tsx (root layout with <html> and <body>)
[ ] Migrate _app.tsx providers to a Client Component wrapper
[ ] Migrate pages one at a time (highest-traffic pages first)
[ ] Replace getServerSideProps with async Server Components
[ ] Replace getStaticProps/getStaticPaths with generateStaticParams + revalidate
[ ] Replace API routes (pages/api/) with Route Handlers (app/api/route.ts)
[ ] Replace <Head> with Metadata API
[ ] Replace useRouter (next/router) with useRouter (next/navigation)
[ ] Replace pages/404.tsx with app/not-found.tsx
[ ] Replace pages/500.tsx / pages/_error.tsx with app/error.tsx
[ ] Remove pages/ directory when migration is complete
[ ] Remove _app.tsx and _document.tsx (replaced by app/layout.tsx)
```

---

## Common Migration Issues

| Issue | Cause | Fix |
|---|---|---|
| Full page reload navigating from pages/ to app/ | Cross-router navigation | Move both routes to app/ |
| `useRouter` import error | Wrong import path | Use `next/navigation` (not `next/router`) |
| Context providers not working | Missing Client Component wrapper | Create `providers.tsx` with `"use client"` |
| `router.query` not available | API change in app router | Use `useSearchParams()` and `useParams()` |
| CSS modules not applying | Different loading behavior | Ensure styles are imported in the right component |
| `getServerSideProps` data not available | Not migrated to Server Component | Fetch data directly in the async component |
