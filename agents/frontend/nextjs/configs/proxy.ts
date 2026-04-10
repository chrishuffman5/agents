// proxy.ts — Annotated Next.js 16 Proxy Configuration
//
// Replaces middleware.ts in Next.js 16.
// Location: project root (same location as middleware.ts was).
// Runtime: Node.js (NOT Edge) — full Node.js APIs available.
//
// Key difference from middleware.ts:
//   - middleware.ts ran on V8 isolate (Edge Runtime) — no Node.js APIs
//   - proxy.ts runs on Node.js — crypto, fs, net, etc. all available
//   - Third-party Node.js libraries with native bindings work here
//   - Longer timeout (no 30-second Edge limit)
//   - Runs at origin only (not globally distributed like Edge)
//
// Note: middleware.ts is deprecated in v16 but not yet removed.
// Edge-specific use cases can still use middleware.ts during the deprecation window.

import { NextRequest, NextResponse } from "next/server";
import { jwtVerify } from "jose"; // Node.js-native JWT library — works in proxy.ts

// ─── Matcher Config ───────────────────────────────────────────────────────────
// Same syntax as middleware.ts matcher — unchanged in v16.
// Defines which routes this proxy applies to.
// Exclusions prevent the proxy from running on static assets and internal routes.
export const config = {
  matcher: [
    // Apply to all routes except:
    //   - _next/static (static files)
    //   - _next/image (image optimization)
    //   - favicon.ico
    //   - api/public (public API endpoints)
    "/((?!_next/static|_next/image|favicon.ico|api/public).*)",
  ],
};

// ─── Main Handler ─────────────────────────────────────────────────────────────
// The function name MUST be "proxy" (not "middleware").
export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // ─── Public Routes — Allow Through ─────────────────────────────────────────
  // Define routes that do not require authentication.
  const publicPaths = ["/login", "/register", "/api/auth", "/api/public"];
  if (publicPaths.some((p) => pathname.startsWith(p))) {
    return NextResponse.next();
  }

  // ─── Auth Check ─────────────────────────────────────────────────────────────
  // In middleware.ts (Edge), jose had to be used carefully due to Edge constraints.
  // In proxy.ts (Node.js), any JWT library works without restriction:
  //   - jsonwebtoken (with native bindings)
  //   - jose (pure JS, also works)
  //   - passport (full Express-compatible auth)
  const token = request.cookies.get("session")?.value;

  if (!token) {
    // Redirect unauthenticated users to login with return URL
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("from", pathname);
    return NextResponse.redirect(loginUrl);
  }

  try {
    // Verify JWT — full Node.js crypto available
    const secret = new TextEncoder().encode(process.env.JWT_SECRET!);
    const { payload } = await jwtVerify(token, secret);

    // ─── Role-Based Access Control ──────────────────────────────────────────
    // Check user role for protected sections
    if (pathname.startsWith("/admin") && payload.role !== "admin") {
      return NextResponse.redirect(new URL("/unauthorized", request.url));
    }

    // ─── Inject User Context into Request Headers ───────────────────────────
    // Pass verified user info to downstream route handlers and Server Components.
    // This avoids re-verifying the JWT in every route.
    const requestHeaders = new Headers(request.headers);
    requestHeaders.set("x-user-id", payload.sub as string);
    requestHeaders.set("x-user-role", payload.role as string);

    return NextResponse.next({
      request: { headers: requestHeaders },
    });

  } catch {
    // Token invalid or expired — clear the session cookie and redirect to login
    const response = NextResponse.redirect(new URL("/login", request.url));
    response.cookies.delete("session");
    return response;
  }
}

// ─── Additional Patterns ──────────────────────────────────────────────────────
//
// Geolocation-based routing (works with Vercel headers or custom GeoIP):
//   const country = request.headers.get("x-vercel-ip-country") ?? "US";
//   if (country === "DE") return NextResponse.rewrite(new URL("/de" + pathname, request.url));
//
// A/B testing with cookies:
//   const bucket = request.cookies.get("ab-bucket")?.value ?? (Math.random() > 0.5 ? "a" : "b");
//   const response = NextResponse.next();
//   response.cookies.set("ab-bucket", bucket);
//   response.headers.set("x-ab-bucket", bucket);
//   return response;
//
// Rate limiting (possible in proxy.ts because Node.js APIs are available):
//   import { rateLimit } from "@/lib/rate-limit";
//   const limiter = rateLimit({ interval: 60_000, uniqueTokenPerInterval: 500 });
//   try {
//     await limiter.check(10, request.ip ?? "anonymous");
//   } catch {
//     return new NextResponse("Too Many Requests", { status: 429 });
//   }
