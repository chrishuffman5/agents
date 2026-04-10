// next.config.ts — Annotated Next.js 16 Configuration
// Reference: https://nextjs.org/docs/app/api-reference/config/next-config-js
//
// This file demonstrates all major configuration options for Next.js 16.
// Remove or modify sections based on your project requirements.

import type { NextConfig } from "next";

const nextConfig: NextConfig = {

  // ─── Turbopack ──────────────────────────────────────────────────────────────
  // Turbopack is the default bundler in v16 for both dev and production.
  // Previously configured under experimental.turbopack — now a top-level key.
  // To fall back to Webpack: next build --webpack / next dev --webpack
  turbopack: {
    // (beta) Persist compiler artifacts to disk between restarts.
    // Dramatically reduces startup time on unchanged code.
    cache: true,

    // Custom resolve aliases — replaces webpack.resolve.alias.
    // Use for path shortcuts not covered by tsconfig paths.
    resolveAlias: {
      "@utils": "./src/utils",
    },

    // File transform rules — replaces webpack loaders.
    // Only needed for non-standard file types (SVG-as-component, GraphQL, etc.).
    rules: {
      "*.svg": {
        loaders: ["@svgr/webpack"],
        as: "*.js",
      },
    },
  },

  // ─── React Compiler ─────────────────────────────────────────────────────────
  // Opt-in automatic memoization via the React Compiler (formerly "React Forget").
  // Eliminates the need for manual useMemo/useCallback/memo() in most cases.
  // Not enabled by default — assess compatibility before enabling.
  // Works with both Server Components and Client Components.
  reactCompiler: true,

  // ─── Cache Components ────────────────────────────────────────────────────────
  // Enables the "use cache" directive for fine-grained function/component caching.
  // Replaces experimental.dynamicIO and experimental.ppr from v15.
  // When enabled, no code is cached unless explicitly marked with "use cache".
  cacheComponents: true,

  // ─── Image Optimization ──────────────────────────────────────────────────────
  // Configure allowed remote image sources for next/image.
  // sharp is auto-detected in v15+ — no manual install needed.
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "cdn.example.com",
        pathname: "/images/**",
      },
      {
        protocol: "https",
        hostname: "avatars.githubusercontent.com",
      },
    ],
    // Uncomment for custom image loader (Cloudinary, Imgix, etc.)
    // loader: "custom",
    // loaderFile: "./lib/image-loader.ts",
  },

  // ─── Custom Cache Life Profiles ──────────────────────────────────────────────
  // Define named profiles used with cacheLife() inside "use cache" functions.
  // Built-in profiles: "seconds" | "minutes" | "hours" | "days" | "weeks"
  // Custom profiles extend this set.
  cacheLife: {
    // Product catalog: stale for 5 minutes, revalidate at 10 minutes, expire at 24 hours
    catalog: {
      stale: 300,        // seconds the cache entry can be served stale
      revalidate: 600,   // seconds before background revalidation triggers
      expire: 86400,     // seconds before hard expiration (entry removed)
    },
    // User profile: shorter cache, quicker revalidation
    profile: {
      stale: 60,
      revalidate: 120,
      expire: 3600,
    },
  },

  // ─── Standalone Output (Self-Hosting) ────────────────────────────────────────
  // Produces .next/standalone/ with a minimal Node.js server.
  // Copy public/ and .next/static/ alongside it for deployment.
  // output: "standalone",

  // ─── Custom Cache Handler (Self-Hosting ISR) ────────────────────────────────
  // Replace the default file-system ISR cache with Redis, S3, etc.
  // cacheHandler: require.resolve("./cache-handler.js"),
  // cacheMaxMemorySize: 0, // Disable in-memory cache when using external store

  // ─── ISR Expiration (Self-Hosting) ───────────────────────────────────────────
  // expireTime: 3600, // ISR pages expire after 1 hour (default: 1 year)

  // ─── Headers ─────────────────────────────────────────────────────────────────
  async headers() {
    return [
      {
        source: "/api/:path*",
        headers: [
          { key: "Cache-Control", value: "no-store" },
        ],
      },
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
        ],
      },
    ];
  },

  // ─── Redirects ───────────────────────────────────────────────────────────────
  async redirects() {
    return [
      {
        source: "/old-blog/:slug",
        destination: "/blog/:slug",
        permanent: true, // 308 redirect
      },
    ];
  },

  // ─── ESLint ──────────────────────────────────────────────────────────────────
  // v16 removed `next lint` — run ESLint or Biome directly.
  // This config controls whether ESLint errors fail the build.
  eslint: {
    ignoreDuringBuilds: false,
  },

  // ─── TypeScript ──────────────────────────────────────────────────────────────
  // Fail the build on TypeScript errors (recommended for production).
  typescript: {
    ignoreBuildErrors: false,
  },

  // ─── Build Adapters (Alpha) ──────────────────────────────────────────────────
  // Low-level API for custom deployment platforms (Cloudflare, Deno, etc.).
  // experimental: {
  //   buildAdapter: require("./my-platform-adapter"),
  // },

  // ─── Removed in v16 — do NOT use ────────────────────────────────────────────
  // experimental.turbopack     -> use top-level turbopack above
  // experimental.dynamicIO     -> use cacheComponents above
  // experimental.ppr           -> use cacheComponents above
  // serverRuntimeConfig        -> use .env files (.env.local, .env.production)
  // publicRuntimeConfig        -> use .env files
  // config.amp                 -> AMP removed entirely
  // next/legacy/image          -> use next/image
};

export default nextConfig;
