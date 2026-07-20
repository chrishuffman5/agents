#!/usr/bin/env bash
# Purpose:        Lint an OpenAPI spec for structural validity and REST-design smells before it ships to clients
# Applies to:     OpenAPI 3.0/3.1 specs (uses Redocly CLI via npx; falls back to a jq structural check)
# Read-only:      yes
# Inputs:         __SPEC__ - path or URL to the openapi.yaml/json
# Interpretation: Errors = the spec is invalid and codegen/clients will break on it. Warnings surface the design smells
#                 that bite later: operations missing operationId (breaks client SDK method names), missing response
#                 schemas (clients can't type responses), no 4xx/error responses defined (clients handle only the happy
#                 path), and missing descriptions. A spec that lints clean is the contract you can safely version -
#                 that is the whole point of contract-first.
# Next step:      Fix errors first (invalid spec), then the operationId/error-response warnings; wire this into CI

set -euo pipefail
SPEC="__SPEC__"

if npx --yes @redocly/cli@latest lint "$SPEC" 2>/dev/null; then
    echo "redocly lint completed above"
else
    echo "== Fallback structural check (install @redocly/cli for full lint)"
    if [[ "$SPEC" == http* ]]; then body=$(curl -sf "$SPEC"); else body=$(cat "$SPEC"); fi
    echo "$body" | jq -e '.openapi and .info.version and .paths' >/dev/null && echo "structure: has openapi/info.version/paths" || echo "INVALID: missing required top-level fields"
    echo "$body" | jq -r '[.paths[][] | select(type=="object") | select(.operationId==null)] | length' | xargs echo "operations missing operationId:"
fi
