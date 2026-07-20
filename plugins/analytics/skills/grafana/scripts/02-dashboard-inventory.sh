#!/usr/bin/env bash
# Purpose:        Inventory all dashboards with folder, tags, and last-update age to find sprawl and stale content
# Applies to:     Grafana 9+ (OSS/Enterprise/Cloud) via HTTP API
# Read-only:      yes
# Inputs:         __GRAFANA_URL__ and __API_TOKEN__ (service account token, Viewer role)
# Prereqs:        curl, jq
# Interpretation: Dashboards untouched for a year+ in personal/General folders are sprawl - typical mature instances
#                 carry 40%+ dead dashboards, which slows search and confuses on-call. Duplicated titles across folders
#                 usually mean copy-drift of a "golden" dashboard - consolidate to one provisioned source of truth.
# Next step:      Move keepers into provisioned folders (as-code); archive the rest. 03-alert-rules-status.sh before deleting anything referenced by alerts

set -euo pipefail

GRAFANA_URL="__GRAFANA_URL__"
TOKEN="__API_TOKEN__"
auth=(-H "Authorization: Bearer ${TOKEN}")

echo "== Dashboard inventory (uid, folder, title, updated)"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/search?type=dash-db&limit=5000" |
    jq -r '.[] | [.uid, (.folderTitle // "General"), .title] | @tsv' |
    sort -t$'\t' -k2,2 -k3,3

echo
echo "== Count by folder"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/search?type=dash-db&limit=5000" |
    jq -r '.[] | (.folderTitle // "General")' | sort | uniq -c | sort -rn

echo
echo "== Stale check (updated > 365 days ago; needs per-dashboard meta call)"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/search?type=dash-db&limit=5000" | jq -r '.[].uid' | while read -r uid; do
    updated=$(curl -s "${auth[@]}" "${GRAFANA_URL}/api/dashboards/uid/${uid}" | jq -r '.meta.updated')
    if [[ "${updated}" < "$(date -d '365 days ago' +%Y-%m-%d 2>/dev/null || date -v-365d +%Y-%m-%d)" ]]; then
        printf '%s\t%s\n' "${updated}" "${uid}"
    fi
done
