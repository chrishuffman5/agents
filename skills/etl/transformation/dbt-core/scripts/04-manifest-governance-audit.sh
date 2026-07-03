#!/usr/bin/env bash
# Purpose:        Audit target/manifest.json for models missing tests or descriptions - the dbt governance gap list
# Applies to:     dbt-core 1.x (any adapter); run after dbt compile/run/build (manifest must be fresh)
# Read-only:      yes
# Inputs:         __PROJECT_DIR__ - path to the dbt project
# Prereqs:        jq
# Interpretation: Untested models in the mart layer are silent-corruption risk - prioritize unique + not_null on their
#                 keys. Missing descriptions block dbt docs from being useful. Fix marts first, staging second;
#                 intermediate models can stay lean. Gate future drift with CI (e.g. require tests on changed models).
# Next step:      Add schema.yml entries for the listed models; re-run to confirm the list shrinks

set -euo pipefail

MANIFEST="__PROJECT_DIR__/target/manifest.json"
[[ -f "$MANIFEST" ]] || { echo "No manifest.json at $MANIFEST - run dbt compile first." >&2; exit 1; }

echo "== Models with NO tests attached"
jq -r '
    .child_map as $children
    | .nodes | to_entries[]
    | select(.value.resource_type == "model")
    | select ([ ($children[.key] // [])[] | select(startswith("test.")) ] | length == 0)
    | .key
' "$MANIFEST" | sort

echo
echo "== Models with no description"
jq -r '
    .nodes | to_entries[]
    | select(.value.resource_type == "model")
    | select ((.value.description // "") == "")
    | .key
' "$MANIFEST" | sort
