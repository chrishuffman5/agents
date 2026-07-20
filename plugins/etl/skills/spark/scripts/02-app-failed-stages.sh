#!/usr/bin/env bash
# Purpose:        Failed jobs and stages for one Spark application with failure reasons - what actually killed the run
# Applies to:     Spark 3.x/4.x History Server REST API
# Read-only:      yes
# Inputs:         __HISTORY_URL__ and __APP_ID__ (from 01-recent-applications.sh)
# Prereqs:        curl, jq
# Interpretation: failureReason containing OutOfMemoryError = executor memory or partition-size problem (see
#                 03-slow-stages.sh for skew); FetchFailedException = shuffle service/executor loss (node died, or
#                 shuffle blocks too large); ExecutorLostFailure on YARN/K8s = container killed - check the resource
#                 manager for OOM-kill vs preemption. Fix the FIRST failed stage; later failures cascade.
# Next step:      03-slow-stages.sh to check skew on the failed stage; 04-executor-usage.sh for memory/GC pressure

set -euo pipefail

HISTORY_URL="__HISTORY_URL__"
APP_ID="__APP_ID__"

echo "== Failed jobs"
curl -sf "${HISTORY_URL}/api/v1/applications/${APP_ID}/jobs?status=failed" |
    jq -r '.[] | [(.jobId|tostring), .name[0:80], (.numFailedTasks|tostring) + " failed tasks"] | @tsv'

echo
echo "== Failed stages (first failure first)"
curl -sf "${HISTORY_URL}/api/v1/applications/${APP_ID}/stages?status=failed" |
    jq -r 'sort_by(.submissionTime) | .[] | [(.stageId|tostring), .name[0:70], ((.failureReason // "") | .[0:200])] | @tsv'
