#!/usr/bin/env bash
# Purpose:        Check Grafana health and test every data source's connectivity - first stop when "dashboards show no data"
# Applies to:     Grafana 9+ (OSS/Enterprise/Cloud) via HTTP API
# Read-only:      yes
# Inputs:         __GRAFANA_URL__ (e.g. https://grafana.example.com) and __API_TOKEN__ (service account token, Viewer role suffices)
# Prereqs:        curl, jq
# Interpretation: /api/health database!="ok" = Grafana's own backing DB is the problem. Per-datasource status!="OK"
#                 names the broken source - the error message distinguishes auth (401/403), network (timeout), and
#                 query-service errors. One broken datasource explains all dashboards built on it.
# Next step:      02-dashboard-inventory.sh to see which dashboards depend on a broken source

set -euo pipefail

GRAFANA_URL="__GRAFANA_URL__"
TOKEN="__API_TOKEN__"
auth=(-H "Authorization: Bearer ${TOKEN}")

echo "== Instance health"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/health" | jq .

echo "== Data sources"
datasources=$(curl -sf "${auth[@]}" "${GRAFANA_URL}/api/datasources")
echo "${datasources}" | jq -r '.[] | [.uid, .type, .name] | @tsv'

echo "== Per-datasource health checks"
echo "${datasources}" | jq -r '.[].uid' | while read -r uid; do
    status=$(curl -s "${auth[@]}" "${GRAFANA_URL}/api/datasources/uid/${uid}/health" | jq -r '"\(.status // "N/A"): \(.message // "")"')
    printf '%-20s %s\n' "${uid}" "${status}"
done
