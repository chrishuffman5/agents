#!/usr/bin/env bash
# Purpose:        Extract failed and warning data-quality tests from the last dbt build/test with failure counts
# Applies to:     dbt-core 1.x (any adapter)
# Read-only:      yes
# Inputs:         __PROJECT_DIR__ - path to the dbt project
# Prereqs:        jq
# Interpretation: failures = number of rows violating the assertion. A unique/not_null failure on a staging model means
#                 the SOURCE shipped bad data - quarantine upstream, don't patch the mart. Warnings trending up run over
#                 run are failures waiting to happen; treat the warn threshold as an early-warning budget.
# Next step:      For source-caused failures, add/tighten a source freshness + contract check; re-run dbt test to confirm

set -euo pipefail

RESULTS="__PROJECT_DIR__/target/run_results.json"
[[ -f "$RESULTS" ]] || { echo "No run_results.json at $RESULTS - run dbt first." >&2; exit 1; }

echo "== Failed tests"
jq -r '
    .results[]
    | select(.unique_id | startswith("test."))
    | select(.status == "fail" or .status == "error")
    | [.status, ((.failures // 0) | tostring) + " rows", .unique_id]
    | @tsv
' "$RESULTS"

echo
echo "== Warnings"
jq -r '
    .results[]
    | select(.unique_id | startswith("test."))
    | select(.status == "warn")
    | [((.failures // 0) | tostring) + " rows", .unique_id]
    | @tsv
' "$RESULTS"
