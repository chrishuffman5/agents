#!/usr/bin/env bash
# Purpose:        Rank all models by execution time from run_results.json - the incremental-strategy and warehouse-cost review list
# Applies to:     dbt-core 1.x (any adapter)
# Read-only:      yes
# Inputs:         __PROJECT_DIR__ - path to the dbt project
# Prereqs:        jq
# Interpretation: Slow table-materialized models over ~100M rows are delete+insert/merge strategy candidates (see
#                 skills/etl/transformation/dbt-core/SKILL.md incremental guidance). A view materialization appearing
#                 here means the cost was pushed to every downstream query instead - consider table. Sum of the top 5
#                 vs total elapsed tells you whether tuning models or parallelism (threads) pays more.
# Next step:      Change materialization/incremental strategy on the top offenders; re-run and diff this output

set -euo pipefail

RESULTS="__PROJECT_DIR__/target/run_results.json"
[[ -f "$RESULTS" ]] || { echo "No run_results.json at $RESULTS - run dbt first." >&2; exit 1; }

printf 'seconds\tstatus\tmodel\n'
jq -r '
    .results[]
    | select(.unique_id | startswith("model."))
    | [(.execution_time * 10 | round / 10 | tostring), .status, .unique_id]
    | @tsv
' "$RESULTS" | sort -t$'\t' -k1,1 -rn
