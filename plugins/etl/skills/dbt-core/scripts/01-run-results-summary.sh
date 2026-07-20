#!/usr/bin/env bash
# Purpose:        Summarize the last dbt invocation from target/run_results.json - status mix, failures, slowest models
# Applies to:     dbt-core 1.x (any adapter); run from the dbt project root after any dbt run/build/test
# Read-only:      yes
# Inputs:         __PROJECT_DIR__ - path to the dbt project (contains target/run_results.json)
# Prereqs:        jq
# Interpretation: error status = model/test failed to execute (SQL error, permissions); fail = a test's assertion failed
#                 (data quality). skipped after an error = downstream blast radius of that one failure. The slowest-model
#                 list is the incremental-strategy review queue.
# Next step:      02-model-timing.sh for the timing deep-dive; 03-test-failures.sh for what the data quality tests caught

set -euo pipefail

RESULTS="__PROJECT_DIR__/target/run_results.json"
[[ -f "$RESULTS" ]] || { echo "No run_results.json at $RESULTS - run dbt first." >&2; exit 1; }

echo "== Invocation"
jq -r '"dbt \(.metadata.dbt_version)  generated \(.metadata.generated_at)  elapsed \(.elapsed_time | round)s"' "$RESULTS"

echo "== Status mix"
jq -r '.results | group_by(.status) | .[] | "\(length)\t\(.[0].status)"' "$RESULTS"

echo "== Errors and failures"
jq -r '.results[] | select(.status == "error" or .status == "fail") | [.status, .unique_id, (.message // "" | .[0:160])] | @tsv' "$RESULTS"

echo "== 10 slowest"
jq -r '.results | sort_by(-.execution_time) | .[0:10][] | [(.execution_time | round | tostring) + "s", .unique_id] | @tsv' "$RESULTS"
