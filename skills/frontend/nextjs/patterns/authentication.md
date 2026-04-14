# Authentication Patterns

Authentication and authorization patterns for Next.js App Router (v15 and v16).

---

## Cascading Auth Pattern

The most robust approach layers authentication at multiple levels:

1. **Middleware/Proxy** -- broad route protection (fast, no DB call)
2. **Layout** -- validate session for a subtree (can fetch user data)
3. **Page** -- permission checks (role-based, resource-based)
4. **Server Actions** -- re-validate on every mutation (never trust client)

---

## Middleware-Based Route Protection (v15)

```tsx
// middleware.ts (project root)
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { verifyToken } from "@/lib/auth";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("session")?.value;
  const isValid = token && verifyToken(token);

  if (!isValid && request.nextUrl.pathname.startsWith("/dashboard")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/dashboard/:path*", "/api/:path*"],
};
```

**Edge Runtime limitations**: No Node.js APIs. Use lightweight JWT libraries like `jose`. No database connections.

---

## Proxy-Based Route Protection (v16)

```tsx
// proxy.ts (project root)
import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose";

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico|api/public|login|register).*)"],
};

export async function proxy(request: NextRequest) {
  const token = request.cookies.get("session")?.value;

  if (!token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("from", request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  try {
    const secret = new TextEncoder().encode(process.env.JWT_SECRET!);
    const { payload } = await jwtVerify(token, secret);

    // Inject verified user context into request headers
    const requestHeaders = new Headers(request.headers);
    requestHeaders.set("x-user-id", payload.sub as string);
    requestHeaders.set("x-user-role", payload.role as string);

    return NextResponse.next({ request: { headers: requestHeaders } });
  } catch {
    const response = NextResponse.redirect(new URL("/login", request.url));
    response.cookies.delete("session");
    return response;
  }
}
```

**Node.js Runtime advantages**: Full Node.js APIs, third-party libraries with native bindings, longer timeout, direct database connections.

---

## Server Component Auth Check

```tsx
// app/dashboard/page.tsx
import { redirect } from "next/navigation";
import { getSession } from "@/lib/auth";

export default async function Dashboard() {
  const session = await getSession();
  if (!session) redirect("/login");
  return <DashboardContent user={session.user} />;
}
```

---

## Layout-Level Auth

Protect an entire route subtree:

```tsx
// app/(dashboard)/layout.tsx
import { auth } from "@/auth";
import { redirect } from "next/navigation";

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await auth();
  if (!session) redirect("/login");
  return (
    <div>
      <nav>Welcome, {session.user.name}</nav>
      <main>{children}</main>
    </div>
  );
}
```

---

## Server Action Auth

Always validate authorization in Server Actions -- they are publicly callable POST endpoints:

```tsx
"use server";
import { cookies } from "next/headers";
import { verifySession } from "@/lib/auth";

export async function deletePost(id: string) {
  const session = await verifySession(await cookies());
  if (!session) throw new Error("Unauthorized");

  // Role check
  const post = await db.posts.findUnique({ where: { id } });
  if (post.authorId !== session.user.id && session.user.role !== "admin") {
    throw new Error("Forbidden");
  }

  await db.posts.delete({ where: { id } });
  revalidatePath("/posts");
}
```

---

## Server Action Login/Logout

```tsx
"use server";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { createSession, destroySession } from "@/lib/auth";

export async function login(formData: FormData) {
  const credentials = {
    email: formData.get("email") as string,
    password: formData.get("password") as string,
  };

  const session = await createSession(credentials);
  if (!session) throw new Error("Invalid credentials");

  const cookieStore = await cookies();
  cookieStore.set("session", session.token, {
    httpOnly: true,
    secure: true,
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 7, // 1 week
  });

  redirect("/dashboard");
}

export async function logout() {
  const cookieStore = await cookies();
  cookieStore.delete("session");
  redirect("/login");
}
```

---

## NextAuth / Auth.js v5 Integration

Auth.js v5 is the standard for OAuth and session management:

### Route Handler

```tsx
// app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/auth";
export const { GET, POST } = handlers;
```

### Auth Configuration

```tsx
// auth.ts (project root)
import NextAuth from "next-auth";
import GitHub from "next-auth/providers/github";
import Google from "next-auth/providers/google";
import Credentials from "next-auth/providers/credentials";

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    GitHub,
    Google,
    Credentials({
      credentials: {
        email: { label: "Email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        const user = await validateCredentials(credentials);
        return user ?? null;
      },
    }),
  ],
  callbacks: {
    authorized({ auth, request }) {
      return !!auth?.user; // return true if authenticated
    },
  },
});
```

### Using in Layout

```tsx
// app/(dashboard)/layout.tsx
import { auth } from "@/auth";
import { redirect } from "next/navigation";

export default async function DashboardLayout({ children }) {
  const session = await auth();
  if (!session) redirect("/login");
  return <>{children}</>;
}
```

### Using in Server Actions

```tsx
"use server";
import { auth } from "@/auth";

export async function createPost(formData: FormData) {
  const session = await auth();
  if (!session?.user) throw new Error("Unauthorized");

  await db.posts.create({
    data: {
      title: formData.get("title") as string,
      authorId: session.user.id,
    },
  });
}
```

---

## Session Pattern Summary

| Pattern | Where | When |
|---|---|---|
| Middleware/Proxy | `middleware.ts` / `proxy.ts` | Broad route protection, redirects |
| Layout auth | `layout.tsx` | Subtree protection, user context |
| Page auth | `page.tsx` | Resource-specific permission checks |
| Server Action auth | `"use server"` functions | Every mutation -- never skip |
| NextAuth/Auth.js | `auth.ts` + route handler | OAuth, session management |
