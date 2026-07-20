// Annotated vite.config.ts for SvelteKit 2
// Production-ready configuration with test setup

import { sveltekit } from "@sveltejs/kit/vite";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    sveltekit(), // handles .svelte compilation, HMR, SSR build, routing
  ],

  server: {
    // Dev server port
    port: 5173,

    // Expose on LAN for mobile testing
    host: true,

    // Proxy external APIs in dev to avoid CORS
    proxy: {
      "/api/external": {
        target: "https://api.example.com",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/external/, ""),
      },
    },
  },

  build: {
    // Minimum target supporting modern JS features
    // ES2022 includes: top-level await, class fields, Error.cause
    target: "es2022",

    // Enable source maps in production builds
    // Set to false if bundle size matters more than debuggability
    sourcemap: true,
  },

  // --- Vitest Configuration ---
  // Co-located here for SvelteKit projects
  test: {
    include: ["src/**/*.{test,spec}.{js,ts}"],
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
  },
});
