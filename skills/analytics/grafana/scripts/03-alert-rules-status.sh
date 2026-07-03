#!/usr/bin/env bash
# Purpose:        List provisioned alert rules and currently firing alerts - verify alerting actually works before you need it
# Applies to:     Grafana 9+ unified alerting via HTTP API
# Read-only:      yes
# Inputs:         __GRAFANA_URL__ and __API_TOKEN__ (service account token; Editor role needed for provisioning API)
# Prereqs:        curl, jq
# Interpretation: Rules in "error" or "nodata" health are silently broken monitors - a datasource change or label drift
#                 usually caused it. Firing alerts nobody acknowledged = notification-policy routing gap. Zero rules on a
#                 production instance is itself a finding.
# Next step:      Fix error/nodata rules first (broken monitor > noisy monitor); test contact points via Grafana UI test button

set -euo pipefail

GRAFANA_URL="__GRAFANA_URL__"
TOKEN="__API_TOKEN__"
auth=(-H "Authorization: Bearer ${TOKEN}")

echo "== Alert rules (provisioning API)"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/v1/provisioning/alert-rules" |
    jq -r '.[] | [.uid, .folderUID, .title, .execErrState, .noDataState] | @tsv'

echo
echo "== Rule health (Prometheus-compatible API)"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/prometheus/grafana/api/v1/rules" |
    jq -r '.data.groups[].rules[] | [.state, .health, .name] | @tsv' | sort | uniq -c | sort -rn

echo
echo "== Currently firing"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/alertmanager/grafana/api/v2/alerts?active=true" |
    jq -r '.[] | [.startsAt, .labels.alertname, (.labels.severity // "-")] | @tsv'
