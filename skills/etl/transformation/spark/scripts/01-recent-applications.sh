#!/usr/bin/env bash
# Purpose:        List recent Spark applications with duration from the History Server - the entry point for any Spark job review
# Applies to:     Spark 3.x/4.x History Server REST API (also works against a live driver UI on port 4040)
# Read-only:      yes
# Inputs:         __HISTORY_URL__ - e.g. http://spark-history.example.com:18080
# Prereqs:        curl, jq
# Interpretation: duration outliers vs the same app's history = data growth or resource contention that day.
#                 completed=false rows on the History Server are apps that died without unregistering (OOM-killed
#                 driver, preempted) - investigate those first; they never wrote a clean end event.
# Next step:      02-app-failed-stages.sh with the suspect __APP_ID__

set -euo pipefail

HISTORY_URL="__HISTORY_URL__"

curl -sf "${HISTORY_URL}/api/v1/applications?limit=30" |
    jq -r '
        .[] |
        . as $app |
        .attempts[0] |
        [
            $app.id,
            ($app.name | .[0:60]),
            .startTime,
            ((.duration // 0) / 60000 | round | tostring) + "m",
            (.completed | tostring)
        ] | @tsv
    ' | column -t -s$'\t'
