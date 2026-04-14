// app/routes.ts -- Annotated React Router v7 Route Configuration
import {
  type RouteConfig,
  route,     // route(path, file, children?) -- creates a URL segment
  index,     // index(file) -- matches parent path exactly (no extra segment)
  layout,    // layout(file, children) -- no URL segment, wraps children in shared UI
  prefix,    // prefix(path, children) -- groups routes without a layout wrapper
} from "@react-router/dev/routes";

export default [
  // -- Index route (/) --------------------------------------------------------
  index("routes/home.tsx"),

  // -- Simple route (/about) --------------------------------------------------
  route("about", "routes/about.tsx"),

  // -- Layout route (shared auth wrapper) -------------------------------------
  // /login and /register share the _auth.tsx layout (nav, background, etc.)
  // The layout does NOT add a URL segment -- just wraps children with <Outlet />
  layout("routes/_auth.tsx", [
    route("login", "routes/login.tsx"),       // GET /login
    route("register", "routes/register.tsx"), // GET /register
  ]),

  // -- Prefix (URL grouping without layout) -----------------------------------
  // All product routes share the /products prefix
  ...prefix("products", [
    index("routes/products.index.tsx"),              // GET /products
    route(":id", "routes/products.$id.tsx"),          // GET /products/:id
    route(":id/edit", "routes/products.$id.edit.tsx"),// GET /products/:id/edit
  ]),

  // -- Catch-all (404) --------------------------------------------------------
  route("*", "routes/404.tsx"),
] satisfies RouteConfig;


// -- Alternative: File-System Convention --------------------------------------
// Uncomment to use Remix-style filename scanning instead of explicit config.
// import { flatRoutes } from "@react-router/fs-routes";
// export default flatRoutes();
//
// File naming conventions:
//   products.$id.tsx       -> /products/:id
//   _layout.tsx            -> layout (no segment)
//   ($optional).tsx        -> optional segment
//   $.tsx                  -> splat/catch-all


// -- Alternative: Remix v1 Convention -----------------------------------------
// For migrating from Remix v1 file conventions:
// import { remixRoutesOptionAdapter } from "@remix-run/v1-route-convention";
// export default remixRoutesOptionAdapter({ ignoredRouteFiles: ["**/*.css"] });
