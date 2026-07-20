// Annotated svelte.config.js for SvelteKit 2 + Svelte 5
// Production-ready configuration with common options explained

import adapter from "@sveltejs/adapter-auto";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: [
    vitePreprocess(), // enables TypeScript, PostCSS, SCSS in .svelte files
  ],

  kit: {
    // --- Adapter ---
    // auto-detects Vercel/Netlify/Cloudflare
    // Swap for adapter-node in Docker deployments:
    //   import adapter from '@sveltejs/adapter-node';
    //   adapter: adapter({ out: 'build' }),
    //
    // For fully static sites:
    //   import adapter from '@sveltejs/adapter-static';
    //   adapter: adapter({ fallback: '200.html' }),  // fallback for SPA routes
    adapter: adapter(),

    // --- Path Aliases ---
    alias: {
      $lib: "src/lib", // default; $lib already points here
      $components: "src/components", // custom alias
    },

    // --- Prerendering ---
    prerender: {
      crawl: true, // follow links to discover routes automatically
      handleHttpError: "warn", // 'warn' | 'fail' | custom function
      // entries: ['/', '/about'],  // explicit entry points (crawl discovers rest)
    },

    // --- CSRF Protection ---
    csrf: {
      checkOrigin: true, // validates Origin header on POST requests
      // Set to false ONLY in test environments
    },

    // --- Environment Variable Prefix ---
    // env: {
    //   publicPrefix: 'PUBLIC_',   // default prefix for client-safe env vars
    // },
  },

  // --- Compiler Options ---
  compilerOptions: {
    runes: true, // enforce runes mode globally (recommended for Svelte 5)
    // Set to false only if migrating incrementally from Svelte 4
  },
};

export default config;
