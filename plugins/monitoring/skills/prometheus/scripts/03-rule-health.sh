#!/usr/bin/env bash
# Purpose:        Recording/alerting rule health - failing rules, evaluation latency, and currently firing alerts
# Applies to:     Prometheus 2.x/3.x HTTP API
# Read-only:      yes
# Inputs:         __PROM_URL__
# Prereqs:        curl, jq
# Interpretation: lastError on a rule = that alert/recording silently stopped working (renamed metric after an exporter
#                 upgrade is the classic). evaluationTime approaching the group interval = the group falls behind and
#                 alerts arrive late - split the group or optimize the expressions. Firing alerts nobody is acting on
#                 belong in the alert-fatigue review, not in silence purgatory.
# Next step:      Fix broken expressions first (a dead monitor is worse than a noisy one); then tune the slow groups

set -euo pipefail
PROM="__PROM_URL__"

RULES=$(curl -sf "${PROM}/api/v1/rules")

echo "== Rules with errors"
echo "$RULES" | jq -r '.data.groups[].rules[] | select(.lastError != null and .lastError != "") | [.name, .lastError[0:120]] | @tsv'

echo
echo "== Slowest rule groups (evaluation seconds vs interval)"
echo "$RULES" | jq -r '.data.groups[] | [(.evaluationTime | tostring), (.interval | tostring), .file + ":" + .name] | @tsv' | sort -rn | head -10

echo
echo "== Currently firing"
curl -sf "${PROM}/api/v1/alerts" | jq -r '.data.alerts[] | select(.state == "firing") | [.labels.alertname, (.labels.severity // "-"), .activeAt] | @tsv' | head -20
