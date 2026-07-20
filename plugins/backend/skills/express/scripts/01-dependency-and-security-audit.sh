#!/usr/bin/env bash
# Purpose:        Express/Node dependency and security audit - npm vulnerabilities, outdated deps, and common middleware gaps
# Applies to:     Express 5.x on Node 18+ (run in the project directory with package.json)
# Read-only:      yes (audit/outdated/ls do not modify anything; no 'npm audit fix')
# Inputs:         run from the directory containing package.json
# Interpretation: 'npm audit' Critical/High with a direct-dependency path = patch now; deep transitive-only advisories
#                 with no fix available are a monitor-and-wait (or override). Missing 'helmet' in the dependency list
#                 for a browser-facing app = no security headers (CSP, HSTS, X-Frame). Express pinned below 5 on a new
#                 build = you miss the automatic promise-rejection handling and the path-to-regexp v8 fixes. Outdated
#                 major on express/its middleware = review breaking-change notes before bumping.
# Next step:      npm audit fix for safe patches; add helmet + rate limiting if absent; plan major bumps deliberately

set -euo pipefail

echo "== Express version and key security middleware presence"
node -e "const p=require('./package.json'); const d={...p.dependencies,...p.devDependencies}; for (const m of ['express','helmet','express-rate-limit','cors','csurf']) console.log((d[m]?'present':'MISSING').padEnd(8), m, d[m]||'')"

echo
echo "== npm audit (production deps)"
npm audit --omit=dev 2>/dev/null | grep -E 'vulnerabilit|critical|high|moderate' | head -10 || echo "clean or no lockfile"

echo
echo "== Outdated direct dependencies"
npm outdated 2>/dev/null | head -20 || echo "all current"
