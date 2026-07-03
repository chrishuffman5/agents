#!/usr/bin/env bash
# Purpose:        Next.js build audit - per-route bundle sizes, rendering strategy, and version/config sanity
# Applies to:     Next.js 15/16 (App Router or Pages; run in the project directory)
# Read-only:      yes (build writes .next/ but no source changes)
# Inputs:         run from the project directory
# Interpretation: The build's per-route table is the goldmine: the "First Load JS" per route is what users download -
#                 routes far above the shared baseline pull heavy client components (push them to Server Components or
#                 lazy-load). The rendering legend (○ static, ƒ dynamic, ● SSG) shows what you THINK is static vs what
#                 actually is - an accidental dynamic route (a stray cookies()/headers() call) kills caching. Next 15+
#                 defaults fetch to no-store; code relying on v14 implicit caching silently refetches. Next 16 wants
#                 proxy.ts, not middleware.ts.
# Next step:      Convert accidentally-dynamic routes back to static; move heavy client JS to Server Components

set -euo pipefail

echo "== Next.js version"
node -e "const d={...require('./package.json').dependencies}; console.log('next', d.next||'?', '| react', d.react||'?')"

echo
echo "== Production build (per-route sizes and render types)"
npm run build 2>&1 | grep -E 'Route|First Load|○|ƒ|●|λ|Size|─' | head -40

echo
echo "== middleware/proxy file check (v16 uses proxy.ts)"
ls middleware.* proxy.* src/middleware.* src/proxy.* 2>/dev/null || echo "no middleware/proxy file"
