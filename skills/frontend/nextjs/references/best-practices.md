# Next.js Best Practices Reference

Optimization, project organization, and deployment guidance for Next.js 15 and 16.

---

## Image Optimization

### next/image Component

Automatic optimization without manual configuration:

```tsx
import Image from "next/image";
import heroImage from "@/public/hero.jpg";

// Static import -- dimensions inferred automatically
export function Hero() {
  return (
    <Image
      src={heroImage}
      alt="Hero image"
      priority          // Load eagerly (above the fold)
      placeholder="blur" // Show blurred version while loading
    />
  );
}

// Remote images -- requires config allowlist
export function Avatar({ src }: { src: string }) {
  return (
    <Image
      src={src}
      alt="User avatar"
      width={64}
      height={64}
      sizes="64px"
    />
  );
}
```

### Key Features

- **Lazy loading**: off-screen images deferred by default; use `priority` for LCP images
- **Responsive sizes**: `sizes` prop maps viewport widths to image sizes for srcset generation
- **Formats**: automatically serves AVIF (then WebP) when browser supports it
- **Blur placeholder**: `placeholder="blur"` shows low-quality image during load
- **CDN support**: works with any CDN via `loader` prop or `loaderFile` config

### Remote Image Configuration

```ts
// next.config.ts
images: {
  remotePatterns: [
    {
      protocol: "https",
      hostname: "images.example.com",
      port: "",
      pathname: "/uploads/**",
    },
  ],
}
```

### sharp for Self-Hosting

In v15+, `sharp` is automatically detected when available. For Docker images:

```dockerfile
RUN npm install --platform=linux --arch=x64 sharp
```

---

## Font Optimization

### next/font/google

Zero-layout-shift font loading. Fonts self-hosted at build time -- no external requests at runtime.

```tsx
// app/layout.tsx
import { Inter, Roboto_Mono } from "next/font/google";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",    // CSS variable for Tailwind
  display: "swap",
});

const robotoMono = Roboto_Mono({
  subsets: ["latin"],
  variable: "--font-roboto-mono",
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body>{children}</body>
    </html>
  );
}
```

### next/font/local

For custom or proprietary fonts:

```tsx
import localFont from "next/font/local";

const myFont = localFont({
  src: [
    { path: "./fonts/MyFont-Regular.woff2", weight: "400" },
    { path: "./fonts/MyFont-Bold.woff2", weight: "700" },
  ],
  variable: "--font-my-font",
});
```

### How It Works

1. At build time, Next.js downloads Google Fonts and bundles them into static output
2. Font CSS is inlined in `<head>` with `font-display: optional` or `swap`
3. Font files served from your own domain -- GDPR friendly, no Google tracking

### Variable Fonts

Single file, multiple weights/styles -- fully supported:

```tsx
const inter = Inter({ subsets: ["latin"] }); // Inter is a variable font -- all weights included
```

---

## Self-Hosting

### standalone Output

```ts
// next.config.ts
output: "standalone"
```

Produces `/.next/standalone/` -- a minimal Node.js server with only required dependencies. Copy `public/` and `.next/static/` alongside it.

### Docker Configuration

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY . .
RUN npm ci && npm run build

FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

### ISR with Custom Cache Handler

```ts
// next.config.ts
cacheHandler: require.resolve("./cache-handler.js"),
cacheMaxMemorySize: 0, // Disable in-memory caching (use Redis etc.)
```

### ISR expireTime (v15+)

```ts
// next.config.ts
expireTime: 3600, // ISR pages expire after 1 hour (default: 1 year)
```

### Cache-Control Headers

Next.js generates correct `Cache-Control` headers for ISR and static pages automatically when self-hosting. Use `headers()` config to override as needed.

---

## Project Structure

### Recommended Directory Layout

```
project/
  app/
    (auth)/             <- Route group: unauthenticated routes
      login/page.tsx
      register/page.tsx
    (dashboard)/        <- Route group: authenticated routes
      layout.tsx        <- Auth check layout
      dashboard/page.tsx
      settings/page.tsx
    api/
      products/route.ts
    layout.tsx          <- Root layout
    page.tsx            <- Homepage
  components/
    ui/                 <- Generic UI primitives (Button, Input, etc.)
    features/           <- Feature-specific components
  lib/
    db.ts               <- Database client
    auth.ts             <- Auth utilities
    utils.ts            <- General utilities
  actions/              <- Server Actions (can also colocate in app/)
  types/                <- TypeScript type definitions
  public/               <- Static assets
```

### Co-location

Components, hooks, and utilities used only within a single route can be placed directly in that route folder:

```
app/
  dashboard/
    components/         <- Only used by dashboard routes
      revenue-chart.tsx
    hooks/
      use-dashboard.ts
    page.tsx
```

### Server-Only Enforcement

Prevent server-only modules from being accidentally imported in client code:

```ts
// lib/db.ts
import "server-only";  // Throws build error if imported in a Client Component

export const db = createDatabaseClient();
```

Similarly, `client-only` prevents client code from being imported in Server Components.

---

## Performance Optimization

### Minimize "use client" Boundaries

Push `"use client"` as far down the component tree as possible. Extract interactive islands from otherwise-static layouts. Pass Server Component output as children/props into Client Components.

```tsx
// app/page.tsx (Server Component)
import { AddToCart } from "./add-to-cart"; // Client Component

export default async function ProductPage() {
  const product = await getProduct(); // Server-side fetch
  return (
    <div>
      <h1>{product.name}</h1>       {/* Static -- no JS */}
      <AddToCart id={product.id} /> {/* Interactive island */}
    </div>
  );
}
```

### Suspense for Streaming

Use granular Suspense boundaries so fast content appears immediately while slow content loads:

```tsx
export default function Page() {
  return (
    <>
      <StaticHeader />          {/* Renders immediately */}
      <Suspense fallback={<Skeleton />}>
        <SlowDataComponent />   {/* Streams in when ready */}
      </Suspense>
    </>
  );
}
```

### Route Segment Config

```ts
export const dynamic = "force-static";  // or "force-dynamic", "auto", "error"
export const revalidate = 3600;          // ISR interval in seconds
export const fetchCache = "force-cache"; // Override fetch cache defaults
export const runtime = "edge";           // "nodejs" (default) or "edge"
export const preferredRegion = "auto";   // Vercel region selection
```

### Instrumentation and Monitoring

```ts
// instrumentation.ts (project root)
export async function register() {
  if (process.env.NEXT_RUNTIME === "nodejs") {
    await import("./lib/otel"); // OpenTelemetry setup
  }
}
```

Web Vitals reporting:

```tsx
"use client";
import { useReportWebVitals } from "next/web-vitals";

export function WebVitals() {
  useReportWebVitals((metric) => {
    fetch("/api/vitals", { method: "POST", body: JSON.stringify(metric) });
  });
  return null;
}
```

### Core Web Vitals

| Metric | Description | Next.js Lever |
|---|---|---|
| LCP | Largest Contentful Paint | `priority` on hero image, reduce TTFB with static rendering |
| CLS | Cumulative Layout Shift | `next/image` with dimensions, `next/font` |
| INP | Interaction to Next Paint | Minimize client JS, defer non-critical scripts |
| TTFB | Time to First Byte | Static rendering, CDN, edge deployment |

---

## Build Output Analysis

`next build` prints route sizes and First Load JS. Targets:
- Green: < 130 kB First Load JS
- Yellow: 130-200 kB
- Red: > 200 kB (investigate with bundle analyzer)

### Bundle Analyzer

```bash
npm install @next/bundle-analyzer
```

```ts
// next.config.ts
const withBundleAnalyzer = require("@next/bundle-analyzer")({
  enabled: process.env.ANALYZE === "true",
});
module.exports = withBundleAnalyzer({ /* next config */ });
```

```bash
ANALYZE=true npm run build
```

Opens interactive treemap of client bundle. Look for unexpectedly large dependencies or server-only modules in the client bundle.

### ISR Build Verification

After `next build`, `.next/server/app/` contains pre-rendered HTML files. Verify expected routes are statically generated vs dynamically rendered in the build output table.
