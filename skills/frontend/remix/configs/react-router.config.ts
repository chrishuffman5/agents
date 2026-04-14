// react-router.config.ts -- Annotated React Router v7 Configuration
import type { Config } from "@react-router/dev/config";

export default {
  // -- Server-Side Rendering --------------------------------------------------
  // true = SSR enabled (default). Pages render on server, hydrate on client.
  // false = SPA mode. No server rendering; client-only React app.
  ssr: true,

  // -- Source Directory -------------------------------------------------------
  // Where route files, root.tsx, and entry files live.
  // Default: "app"
  // appDirectory: "app",

  // -- Build Output -----------------------------------------------------------
  // Where the production build is written.
  // Default: "build"
  // buildDirectory: "build",

  // -- Base Path --------------------------------------------------------------
  // Set if the app is not served from "/".
  // Default: "/"
  // basename: "/my-app",

  // -- Future Flags -----------------------------------------------------------
  // Opt into upcoming breaking changes before they become defaults.
  // Check React Router changelog for available flags.
  future: {},
} satisfies Config;
