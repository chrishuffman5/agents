// Annotated vite.config.ts for Vue 3.5
// Production-ready configuration with common options explained

import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { fileURLToPath, URL } from "node:url";

export default defineConfig({
  plugins: [
    vue({
      // --- Script Setup Options ---
      script: {
        // defineModel() -- stable in 3.4, on by default in 3.5
        defineModel: true,
        // Reactive props destructure -- stable in 3.5, on by default
        propsDestructure: true,
      },

      // --- Template Compiler Options ---
      template: {
        compilerOptions: {
          // Treat components starting with 'Ion' as custom elements (Ionic)
          // isCustomElement: (tag) => tag.startsWith('Ion'),
        },
      },
    }),
  ],

  resolve: {
    alias: {
      // @ maps to src/ -- matches tsconfig.json paths
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },

  build: {
    // Minimum target for Proxy support (Vue 3 requirement)
    target: "es2015",

    // Enable source maps in production builds
    // Set to false to reduce build size if not using error tracking
    sourcemap: true,

    // Rollup chunk splitting
    rollupOptions: {
      output: {
        manualChunks: {
          "vendor-vue": ["vue", "vue-router", "pinia"],
        },
      },
    },
  },

  server: {
    // Dev server port
    port: 5173,

    // Open browser automatically on dev server start
    open: true,

    // Proxy API requests to backend during development
    // Avoids CORS issues without configuring backend headers
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
    },
  },

  // CSS preprocessor options
  css: {
    preprocessorOptions: {
      scss: {
        // Inject global SCSS variables into every component
        additionalData: `@use "@/styles/variables" as *;`,
      },
    },
  },
});
