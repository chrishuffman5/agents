#!/usr/bin/env bash
# Purpose:        Audit org users by role and last-seen age - find privilege creep and dormant accounts
# Applies to:     Grafana 9+ (OSS/Enterprise) via HTTP API
# Read-only:      yes
# Inputs:         __GRAFANA_URL__ and __API_TOKEN__ (service account token with Admin role for user listing)
# Prereqs:        curl, jq
# Interpretation: Admins who haven't logged in for 90+ days are standing risk - downgrade or remove. A high Admin:Viewer
#                 ratio (> ~1:10) means roles were handed out instead of designed; move to team-based folder permissions.
# Next step:      Downgrade dormant admins, then re-run. For SSO-managed instances, fix the role mapping at the IdP instead

set -euo pipefail

GRAFANA_URL="__GRAFANA_URL__"
TOKEN="__API_TOKEN__"
auth=(-H "Authorization: Bearer ${TOKEN}")

echo "== Users by role"
users=$(curl -sf "${auth[@]}" "${GRAFANA_URL}/api/org/users")
echo "${users}" | jq -r '.[] .role' | sort | uniq -c | sort -rn

echo
echo "== Users, last seen (oldest first)"
echo "${users}" |
    jq -r '.[] | [.lastSeenAtAge, .role, .login, .email] | @tsv' |
    sort -k1,1r

echo
echo "== Service accounts"
curl -sf "${auth[@]}" "${GRAFANA_URL}/api/serviceaccounts/search" |
    jq -r '.serviceAccounts[] | [.name, .role, (.isDisabled|tostring)] | @tsv'
