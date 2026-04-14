# Data Fetching Patterns

Comprehensive patterns for data fetching in Next.js 15 and 16 App Router.

---

## Server Components Fetch

The primary data fetching pattern. Server Components are async by default and can fetch data directly.

### Basic Fetch

```tsx
// app/products/page.tsx (Server Component by default)
export default async function ProductsPage() {
  // v15+ default: not cached (no-store)
  const products = await fetch("https://api.example.com/products").then(r => r.json());
  return <ProductList items={products} />;
}
```

### Fetch with Caching

```tsx
// Cache indefinitely until tag invalidation
const products = await fetch("https://api.example.com/products", {
  cache: "force-cache",
  next: { tags: ["products"] },
}).then(r => r.json());

// Cache with time-based revalidation (ISR)
const config = await fetch("https://api.example.com/config", {
  next: { revalidate: 3600 }, // 1 hour
}).then(r => r.json());

// Never cache (v15+ default, explicit for clarity)
const liveData = await fetch("https://api.example.com/live", {
  cache: "no-store",
}).then(r => r.json());
```

### Request Deduplication

Next.js automatically deduplicates `fetch()` calls with the same URL and options within a single render pass. Multiple Server Components calling the same endpoint share one network request.

```tsx
// Both components share one network request within the same render
async function Header() {
  const user = await fetch("/api/user").then(r => r.json());
  return <nav>{user.name}</nav>;
}

async function Sidebar() {
  const user = await fetch("/api/user").then(r => r.json()); // deduplicated
  return <aside>{user.avatar}</aside>;
}
```

### Per-Request Caching with React cache()

```tsx
import { cache } from "react";

export const getUserById = cache(async (id: string) => {
  const res = await fetch(`https://api.example.com/users/${id}`, {
    next: { tags: [`user-${id}`] },
  });
  return res.json();
});
```

### ORM / Database Access

Server Components can query databases directly -- no API layer needed:

```tsx
import { db } from "@/lib/db";

export default async function DashboardPage() {
  const [revenue, invoices] = await Promise.all([
    db.revenue.findMany(),
    db.invoices.findLatest(5),
  ]);
  return <Dashboard revenue={revenue} invoices={invoices} />;
}
```

---

## Server Actions

Async functions marked with `"use server"` for mutations and form handling.

### Definition in Server-Only File

```ts
// app/actions.ts
"use server";

import { revalidatePath, revalidateTag } from "next/cache";
import { redirect } from "next/navigation";

export async function createPost(formData: FormData) {
  const title = formData.get("title") as string;
  await db.posts.create({ data: { title } });
  revalidatePath("/posts");
  redirect("/posts");
}
```

### Form Action (Progressive Enhancement)

```tsx
// Works without JavaScript — browser submits native form POST
import { createPost } from "@/app/actions";

export default function NewPost() {
  return (
    <form action={createPost}>
      <input name="title" />
      <button type="submit">Create</button>
    </form>
  );
}
```

### Event Handler (Client Component)

```tsx
"use client";
import { createPost } from "@/app/actions";

export function CreateButton() {
  return (
    <button onClick={() => createPost(new FormData())}>
      Create
    </button>
  );
}
```

### Revalidation After Mutation

```ts
"use server";
import { revalidatePath, revalidateTag } from "next/cache";

export async function updateProduct(id: string, data: FormData) {
  await db.products.update(id, data);
  revalidateTag("products");           // invalidate tagged fetches
  revalidatePath("/products");         // invalidate the page cache
  revalidatePath("/products/[id]", "page"); // invalidate dynamic page
}
```

### Auth in Server Actions

```ts
"use server";
import { cookies } from "next/headers";

export async function deletePost(id: string) {
  const session = await verifySession(await cookies());
  if (!session) throw new Error("Unauthorized");
  await db.posts.delete({ where: { id } });
  revalidatePath("/posts");
}
```

---

## Cache Components (v16 "use cache")

Fine-grained, function-level caching replacing route-level static/dynamic choices. Requires `cacheComponents: true` in `next.config.ts`.

### Cached Data Fetch with Tag

```ts
import { cacheTag, cacheLife } from "next/cache";

export async function getProduct(id: string) {
  "use cache";
  cacheTag(`product-${id}`);   // tag for targeted invalidation
  cacheLife("hours");           // cache for up to 1 hour
  const res = await fetch(`https://api.example.com/products/${id}`);
  return res.json();
}
```

### Cached Server Component

```tsx
import { cacheTag, cacheLife } from "next/cache";

async function ProductCard({ id }: { id: string }) {
  "use cache";
  cacheTag(`product-${id}`);
  cacheLife("minutes");
  const product = await getProduct(id);
  return (
    <div className="card">
      <h2>{product.name}</h2>
      <p>{product.price}</p>
    </div>
  );
}
```

### Invalidation via Server Action

```ts
"use server";
import { revalidateTag } from "next/cache";

export async function updateProduct(id: string, data: Partial<Product>) {
  await db.products.update(id, data);
  revalidateTag(`product-${id}`, "hours"); // v16: profile argument required
}
```

### Read-Your-Writes with updateTag

```ts
"use server";
import { updateTag } from "next/cache";

export async function publishProduct(id: string) {
  await db.products.publish(id);
  updateTag(`product-${id}`); // current request immediately sees fresh data
}
```

### Custom Cache Profile

```ts
import { cacheLife } from "next/cache";

export async function getInventory(sku: string) {
  "use cache";
  cacheLife("catalog"); // uses custom profile from next.config.ts
  return await db.inventory.findBySku(sku);
}
```

### Mixed Cached and Dynamic Data

```tsx
import { getProduct } from "@/lib/products";       // has "use cache"
import { getLiveStock } from "@/lib/stock";         // no "use cache" — dynamic

export default async function ProductPage({ params }) {
  const { id } = await params;
  const product = await getProduct(id);  // cached: fast
  const stock = await getLiveStock(id);   // dynamic: fresh every request
  return (
    <div>
      <h1>{product.name}</h1>
      <p>In stock: {stock.quantity}</p>
    </div>
  );
}
```

---

## ISR (Incremental Static Regeneration)

### Time-Based ISR

```ts
// app/blog/[slug]/page.tsx
export const revalidate = 3600; // regenerate every hour

export default async function BlogPost({ params }) {
  const { slug } = await params;
  const post = await fetch(`/api/posts/${slug}`).then(r => r.json());
  return <article>{post.content}</article>;
}
```

### On-Demand ISR

```ts
// app/api/revalidate/route.ts
import { revalidateTag, revalidatePath } from "next/cache";

export async function POST(request: Request) {
  const { tag, path, secret } = await request.json();

  if (secret !== process.env.REVALIDATION_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  if (tag) revalidateTag(tag);
  if (path) revalidatePath(path);

  return Response.json({ revalidated: true, now: Date.now() });
}
```

### generateStaticParams (SSG)

Pre-render dynamic routes at build time:

```tsx
// app/blog/[slug]/page.tsx
export async function generateStaticParams() {
  const posts = await fetchAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

// dynamicParams controls behavior for unlisted params:
export const dynamicParams = true;  // default: generate on-demand, then cache
// export const dynamicParams = false; // return 404 for unlisted params
```

---

## Route Handlers

Replace Pages Router API routes. Live in `app/` as `route.ts` files.

### HTTP Methods

```ts
// app/api/products/route.ts
import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const category = searchParams.get("category");
  const products = await db.products.findMany({ where: { category } });
  return NextResponse.json(products);
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const product = await db.products.create({ data: body });
  return NextResponse.json(product, { status: 201 });
}
```

### Dynamic Route Handlers

```ts
// app/api/products/[id]/route.ts
export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> } // v15+: params is async
) {
  const { id } = await params;
  const product = await db.products.findUnique({ where: { id } });
  if (!product) return new Response("Not found", { status: 404 });
  return NextResponse.json(product);
}
```

### Caching Route Handlers

```ts
// v15+: GET Route Handlers are NOT cached by default
// Opt in to caching:
export const dynamic = "force-static";
export const revalidate = 3600; // or time-based

export async function GET() {
  const data = await fetchFromDB();
  return Response.json(data);
}
```

Supported exports: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.
