#!/usr/bin/env bash
# Purpose:        Executor memory, GC, and task-failure profile for one application - resourcing vs code problem discriminator
# Applies to:     Spark 3.x/4.x History Server REST API
# Read-only:      yes
# Inputs:         __HISTORY_URL__ and __APP_ID__
# Prereqs:        curl, jq
# Interpretation: totalGCTime > ~10% of totalDuration on many executors = memory pressure - raise executor memory or
#                 lower spark.memory.fraction pressure by reducing partition size; a FEW executors with failedTasks
#                 while the rest are clean = bad node or skew (cross-check 03-slow-stages.sh). memoryUsed near
#                 maxMemory across the board = caching too much; revisit persist() choices.
# Next step:      Adjust executor sizing/partitioning; re-run the job and diff this output

set -euo pipefail

HISTORY_URL="__HISTORY_URL__"
APP_ID="__APP_ID__"

curl -sf "${HISTORY_URL}/api/v1/applications/${APP_ID}/allexecutors" |
    jq -r '
        .[] |
        [
            .id,
            (.isActive|tostring),
            ((.memoryUsed // 0) / 1048576 | round | tostring) + "/" + ((.maxMemory // 0) / 1048576 | round | tostring) + "MB",
            ((.totalGCTime // 0) / 1000 | round | tostring) + "s-GC",
            ((.totalDuration // 0) / 1000 | round | tostring) + "s-task",
            (.failedTasks|tostring) + " failed",
            (.completedTasks|tostring) + " ok"
        ] | @tsv
    ' | column -t -s$'\t'
