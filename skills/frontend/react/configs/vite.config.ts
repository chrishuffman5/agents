// Annotated vite.config.ts for React 19 + React Compiler
// Production-ready configuration with common options explained

import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [
    react({
      // --- React Compiler Integration ---
      // The React Compiler (babel-plugin-react-compiler) automatically memoizes
      // components and values, replacing manual useMemo/useCallback/React.memo.
      //
      // Prerequisites:
      //   npm install -D babel-plugin-react-compiler eslint-plugin-react-compiler
      //
      // Remove this entire `babel` block to disable the compiler.
      babel: {
        plugins: [
          [
            "babel-plugin-react-compiler",
            {
              // "all"        = compile every file (recommended for new projects)
              // "annotation" = only compile files with "use memo" directive
              //                (recommended for incremental adoption)
              compilationMode: "all",

              // "none"  = report non-conforming code as warnings, skip it
              // "error" = fail the build on non-conforming code
              panicThreshold: "none",

              // Target React version for compatibility checks
              target: "19",
            },
          ],
        ],
      },

      // --- Alternative: SWC for faster builds (no Compiler) ---
      // If you don't need the React Compiler, use @vitejs/plugin-react-swc
      // for significantly faster dev server starts and HMR:
      //
      //   npm install -D @vitejs/plugin-react-swc
      //   import react from "@vitejs/plugin-react-swc";
      //   plugins: [react()],
    }),
  ],

  resolve: {
    alias: {
      // Path alias matching tsconfig.json "paths" configuration
      // Enables: import { Button } from "@/components/Button"
      "@": path.resolve(__dirname, "./src"),
    },
  },

  build: {
    // Minimum target supporting all React 19 features
    // ES2022 includes: top-level await, class fields, Error.cause
    target: "es2022",

    // Enable source maps in production builds
    // Set to false to reduce build size if not using error tracking
    sourcemap: true,

    // Rollup options for advanced chunking
    // rollupOptions: {
    //   output: {
    //     manualChunks: {
    //       react: ['react', 'react-dom'],
    //     },
    //   },
    // },
  },

  server: {
    // Open browser automatically on dev server start
    open: true,

    // Proxy API requests to backend during development
    // Avoids CORS issues without configuring backend headers
    proxy: {
      "/api": {
        target: "http://localhost:3001",
        changeOrigin: true,
      },
    },
  },
});
