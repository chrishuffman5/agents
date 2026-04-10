// astro.config.mjs -- Annotated Astro 5 Configuration
import { defineConfig, envField } from 'astro/config';
import react from '@astrojs/react';
import svelte from '@astrojs/svelte';
import node from '@astrojs/node';
import tailwind from '@astrojs/tailwind';

export default defineConfig({
  // -- Site metadata ---------------------------------------------------------
  site: 'https://example.com',        // Required for sitemap, canonical URLs
  base: '/',                          // Sub-path if deploying to /sub-path/

  // -- Output mode -----------------------------------------------------------
  // 'static': full SSG (default). Use 'server' for full SSR.
  // Per-page overrides via `export const prerender = true/false`.
  output: 'static',

  // -- Adapter (required for output: 'server') --------------------------------
  // 'standalone' for Docker deployments; 'middleware' for Express/Fastify
  adapter: node({ mode: 'standalone' }),

  // -- Integrations -----------------------------------------------------------
  integrations: [
    react({
      // Scope React JSX transform to specific directories
      // Prevents conflicts with Preact or other JSX frameworks
      include: ['**/react/**'],
    }),
    svelte(),
    tailwind({
      // Use Tailwind v4 CSS-first config
      applyBaseStyles: false,
    }),
  ],

  // -- Image optimization -----------------------------------------------------
  image: {
    // Allow remote images from these domains
    domains: ['images.unsplash.com', 'cdn.example.com'],
    remotePatterns: [{ protocol: 'https', hostname: '**.cloudfront.net' }],
    // CDN service override:
    // service: cloudinary({ cloudName: 'my-cloud' }),
  },

  // -- Type-safe environment variables ----------------------------------------
  env: {
    schema: {
      // Public: available in client and server bundles
      PUBLIC_SITE_URL:    envField.string({ context: 'client', access: 'public' }),
      PUBLIC_ANALYTICS:   envField.string({ context: 'client', access: 'public', optional: true }),

      // Server-only: not included in client bundle
      DATABASE_URL:       envField.string({ context: 'server', access: 'secret' }),
      CMS_API_KEY:        envField.string({ context: 'server', access: 'secret' }),
      MAX_ITEMS_PER_PAGE: envField.number({ context: 'server', access: 'public', default: 20 }),
    },
  },

  // -- Vite config passthrough ------------------------------------------------
  vite: {
    optimizeDeps: {
      exclude: ['some-esm-only-package'],
    },
  },

  // -- Dev server -------------------------------------------------------------
  server: {
    port: 4321,
    host: true,         // Expose to local network
  },

  // -- Markdown ---------------------------------------------------------------
  markdown: {
    shikiConfig: {
      theme: 'github-dark',
      wrap: true,
    },
    remarkPlugins: [],
    rehypePlugins: [],
  },
});
