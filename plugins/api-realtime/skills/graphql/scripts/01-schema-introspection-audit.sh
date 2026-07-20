#!/usr/bin/env bash
# Purpose:        Audit a live GraphQL endpoint - is introspection exposed, and what does the schema surface reveal?
# Applies to:     any GraphQL server over HTTP (curl + jq)
# Read-only:      yes (introspection query only; no mutations)
# Inputs:         __GRAPHQL_URL__ and optional __AUTH_HEADER__ (e.g. "Authorization: Bearer ...")
# Interpretation: Introspection ENABLED on a PUBLIC/production endpoint is a finding - it hands attackers the full API
#                 map (types, fields, deprecations, admin mutations). Disable it in production or gate it behind auth;
#                 keep it on internally. If it IS on, the type/mutation counts and any 'admin'/'internal'-named fields
#                 tell you what is exposed. No depth/complexity limit (test separately) plus introspection = easy DoS
#                 via deeply nested queries.
# Next step:      Disable introspection in prod (or auth-gate it); add query depth+complexity limits and persisted queries

set -euo pipefail
URL="__GRAPHQL_URL__"
HDR="${AUTH_HEADER:-X-None: none}"

Q='{"query":"query{__schema{queryType{name} mutationType{name} types{name kind}}}"}'
resp=$(curl -sf -X POST "$URL" -H 'Content-Type: application/json' -H "$HDR" -d "$Q" || echo '')

if echo "$resp" | jq -e '.data.__schema' >/dev/null 2>&1; then
    echo "INTROSPECTION: ENABLED  <<< finding if this endpoint is public/production"
    echo "$resp" | jq -r '.data.__schema | "query type: \(.queryType.name)   mutation type: \(.mutationType.name // "none")"'
    echo "$resp" | jq -r '.data.__schema.types | length' | xargs echo "types exposed:"
    echo "$resp" | jq -r '[.data.__schema.types[].name | select(test("(?i)admin|internal|debug"))] | join(", ")' | sed 's/^/sensitive-looking types: /'
else
    echo "INTROSPECTION: disabled or auth-required (good for a public production endpoint)"
    echo "$resp" | jq -r '.errors[0].message // "no schema returned"' 2>/dev/null | sed 's/^/server said: /'
fi
