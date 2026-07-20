#!/usr/bin/env bash
# Purpose:        Recent CrowdStrike Falcon detections summarized by severity and tactic - the SOC morning triage
# Applies to:     CrowdStrike Falcon (Detects API via OAuth2; read-only 'Detections: READ' scope)
# Read-only:      yes
# Inputs:         __FALCON_CLOUD__ (e.g. api.crowdstrike.com), __CLIENT_ID__, __CLIENT_SECRET__ (read-only API client)
# Prereqs:        curl, jq
# Interpretation: New Criticals/Highs are the work queue - triage newest first. A cluster of the same tactic
#                 (technique) across many hosts = a campaign, not isolated events (escalate as one incident). Status
#                 'new' piling up = triage backlog; 'in_progress' stale for days = dropped investigations. Repeated
#                 detections on one host = either an active foothold or a noisy false positive needing an exclusion -
#                 confirm which before suppressing.
# Next step:      Pivot on the top host/tactic in the Falcon console; this is read-only triage, not response

set -euo pipefail
CLOUD="__FALCON_CLOUD__"; CID="__CLIENT_ID__"; SECRET="__CLIENT_SECRET__"

TOKEN=$(curl -sf -X POST "https://${CLOUD}/oauth2/token" \
    -d "client_id=${CID}&client_secret=${SECRET}" | jq -r '.access_token')
AUTH=(-H "Authorization: Bearer ${TOKEN}")

# Last 24h, most severe first
ids=$(curl -sf "${AUTH[@]}" "https://${CLOUD}/detects/queries/detects/v1?filter=created_timestamp%3A%3E'now-24h'&sort=max_severity.desc&limit=200" | jq -r '.resources | join("\",\"")')
[[ -z "$ids" ]] && { echo "No detections in the last 24h."; exit 0; }

curl -sf "${AUTH[@]}" -X POST "https://${CLOUD}/detects/entities/summaries/GET/v1" \
    -H 'Content-Type: application/json' -d "{\"ids\":[\"${ids}\"]}" |
    jq -r '.resources[] | [.max_severity_displayname, .status, (.behaviors[0].tactic // "-"), (.device.hostname // "-")] | @tsv' |
    sort | uniq -c | sort -rn | head -30
