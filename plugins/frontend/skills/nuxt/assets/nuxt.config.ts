// Annotated nuxt.config.ts for Nuxt 4
// Production-ready configuration with all major options explained

export default defineNuxtConfig({
  // --- Nuxt 4 Compatibility ---
  // Enable v4 behavior in Nuxt 3.x for early migration
  future: { compatibilityVersion: 4 },
  compatibilityDate: "2025-01-01", // lock behavior to specific release

  // --- Source Layout (v4 defaults) ---
  srcDir: "app/", // application code lives in app/
  serverDir: "server/", // server code stays at root level

  // --- Rendering ---
  ssr: true, // false = SPA mode (client-only rendering)

  // --- Hybrid Rendering per Route ---
  // Mix SSR, SSG, ISR, and SPA per route pattern
  routeRules: {
    "/": { prerender: true }, // SSG at build time
    "/blog/**": { isr: 3600 }, // ISR: revalidate every hour
    "/dashboard/**": { ssr: true }, // always server-rendered
    "/admin/**": {
      ssr: true,
      headers: { "X-Frame-Options": "DENY" },
    },
    "/account/**": { ssr: false }, // SPA (client-only)
    "/api/**": {
      cors: true,
      headers: { "cache-control": "s-maxage=60" },
    },
  },

  // --- Modules ---
  // Order matters: modules are loaded sequentially
  modules: [
    "@nuxt/ui",
    "@nuxt/image",
    "@nuxt/content",
    "@pinia/nuxt",
    "@nuxtjs/i18n",
  ],

  // --- Auto-Imports ---
  // Extend default scan paths (components/, composables/, utils/)
  imports: {
    dirs: ["stores/**", "utils/**"],
  },

  // --- Runtime Config ---
  // Server-only values are never exposed to client bundle
  // Override at runtime with NUXT_* environment variables
  runtimeConfig: {
    databaseUrl: process.env.DATABASE_URL, // server-only
    jwtSecret: process.env.JWT_SECRET, // server-only
    public: {
      // exposed to client
      apiBase: process.env.NUXT_PUBLIC_API_BASE || "/api",
      appTitle: "My App",
    },
  },

  // --- Nitro Server Engine ---
  nitro: {
    // Deployment target: 'node' | 'vercel' | 'cloudflare-pages' | etc.
    preset: process.env.NITRO_PRESET || "node",

    // Compress public assets (gzip/brotli)
    compressPublicAssets: true,

    // Minify server bundle
    minify: true,

    // Key-value storage configuration
    storage: {
      cache: {
        driver: "redis",
        url: process.env.REDIS_URL,
      },
    },
  },

  // --- TypeScript ---
  typescript: {
    strict: true, // enable strict type checking
    typeCheck: false, // set true to type-check during build (slower)
  },

  // --- DevTools ---
  devtools: { enabled: true },

  // --- App Metadata ---
  app: {
    head: {
      title: "My App",
      meta: [
        { name: "viewport", content: "width=device-width, initial-scale=1" },
      ],
    },
    // Page and layout transitions
    pageTransition: { name: "page", mode: "out-in" },
    layoutTransition: { name: "layout", mode: "out-in" },
  },
});
