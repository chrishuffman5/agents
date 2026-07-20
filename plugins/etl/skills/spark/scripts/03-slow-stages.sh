#!/usr/bin/env bash
# Purpose:        Rank stages by duration and expose task-time skew (max vs median) for one application - the skew detector
# Applies to:     Spark 3.x/4.x History Server REST API
# Read-only:      yes
# Inputs:         __HISTORY_URL__ and __APP_ID__
# Prereqs:        curl, jq
# Interpretation: In the skew section, max task time >= 5-10x the median on a big stage = data skew (one hot key doing
#                 all the work). Fixes: salt the key, enable AQE skew-join handling (spark.sql.adaptive.skewJoin,
#                 default on since 3.2), or isolate the hot key. Large shuffle write on the slow stage = consider
#                 broadcast join or repartitioning strategy instead.
# Next step:      Apply the skew fix and re-run; 04-executor-usage.sh if slowness is uniform (resourcing, not skew)

set -euo pipefail

HISTORY_URL="__HISTORY_URL__"
APP_ID="__APP_ID__"

echo "== Slowest completed stages"
stages=$(curl -sf "${HISTORY_URL}/api/v1/applications/${APP_ID}/stages?status=complete")
echo "${stages}" |
    jq -r '
        sort_by(-(.executorRunTime // 0)) | .[0:10][] |
        [
            (.stageId|tostring),
            ((.executorRunTime // 0) / 60000 | round | tostring) + "m-cpu",
            ((.shuffleReadBytes // 0) / 1048576 | round | tostring) + "MB-shufR",
            ((.shuffleWriteBytes // 0) / 1048576 | round | tostring) + "MB-shufW",
            (.numCompleteTasks|tostring) + " tasks",
            .name[0:60]
        ] | @tsv
    ' | column -t -s$'\t'

echo
echo "== Task-time quantiles for the top stage (skew check: compare max vs median)"
top_stage=$(echo "${stages}" | jq -r 'sort_by(-(.executorRunTime // 0)) | .[0].stageId')
curl -sf "${HISTORY_URL}/api/v1/applications/${APP_ID}/stages/${top_stage}/0/taskSummary?quantiles=0.05,0.5,0.95,1.0" |
    jq '{quantiles, duration_ms: .executorRunTime, shuffle_read_bytes: .shuffleReadMetrics.readBytes}'
