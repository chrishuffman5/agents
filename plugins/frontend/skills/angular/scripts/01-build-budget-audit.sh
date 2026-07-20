#!/usr/bin/env bash
# Purpose:        Angular production build audit - bundle budgets, initial size, and version/dependency health
# Applies to:     Angular 19/20/21 (Angular CLI; run in the workspace root)
# Read-only:      yes (build writes dist/ only)
# Inputs:         run from the Angular workspace root
# Interpretation: Budget WARNINGS/ERRORS in the build output are Angular telling you the bundle exceeded the limits in
#                 angular.json - errors fail CI by design; do not just raise the budget, find what grew (a whole
#                 library imported for one function, missing lazy-loaded routes). Initial bundle over ~500KB hurts
#                 first paint. Angular 21 defaults to Vitest (not Karma) and removed HammerJS - build/test failures
#                 after an upgrade often name those. Check standalone vs NgModule if migrating.
# Next step:      Lazy-load feature routes; tree-shake heavy imports; fix budget errors before raising limits

set -euo pipefail

echo "== Angular version"
npx ng version 2>/dev/null | grep -E 'Angular CLI|Angular:' | head -2 ||
    node -e "console.log('@angular/core', require('./package.json').dependencies['@angular/core']||'?')"

echo
echo "== Production build (budgets and sizes)"
npx ng build --configuration production 2>&1 | grep -iE 'budget|warning|error|initial|lazy|Initial total|Estimated' | head -30

echo
echo "== Largest built bundles"
find dist -type f -name '*.js' 2>/dev/null | xargs du -h 2>/dev/null | sort -rh | head -10
