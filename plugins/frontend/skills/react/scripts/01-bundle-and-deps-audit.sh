#!/usr/bin/env bash
# Purpose:        React app bundle-size and dependency audit - production build size, largest chunks, and dep health
# Applies to:     React 18/19 apps (Vite or CRA/webpack; run in the project directory)
# Read-only:      yes (a build writes to dist/ but touches no source; audit/outdated read-only)
# Inputs:         run from the project directory with package.json
# Interpretation: Total JS over ~200-300KB gzipped hurts Core Web Vitals on mobile - the biggest chunks are your
#                 code-splitting targets (route-level React.lazy). A single huge vendor chunk = a heavy library
#                 (moment, lodash-with-no-tree-shaking, an icon set imported whole) - check the largest files against
#                 your imports. React 18 in package.json for a new build = you miss React 19's Actions/use()/compiler.
#                 npm audit criticals in a frontend dep = supply-chain risk shipped to every user's browser.
# Next step:      Route-split the largest chunks; replace/trim the heavy libraries; patch audit findings

set -euo pipefail

echo "== React version"
node -e "const d={...require('./package.json').dependencies}; console.log('react', d.react||'?', '| react-dom', d['react-dom']||'?')"

echo
echo "== Production build"
npm run build 2>&1 | tail -5

echo
echo "== Largest JS/CSS assets in the build output"
find dist build -type f \( -name '*.js' -o -name '*.css' \) 2>/dev/null |
    xargs du -h 2>/dev/null | sort -rh | head -12

echo
echo "== Dependency vulnerabilities (production)"
npm audit --omit=dev 2>/dev/null | grep -E 'vulnerabilit|critical|high' | head -8 || echo "clean or no lockfile"
