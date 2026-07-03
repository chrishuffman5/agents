#!/usr/bin/env bash
# Purpose:        Audit enabled auth methods, mounts, and policies for over-broad access - the Vault least-privilege review
# Applies to:     HashiCorp Vault 1.15+ (vault CLI, authenticated with a policy-read token)
# Read-only:      yes
# Inputs:         VAULT_ADDR and a VAULT_TOKEN with read on sys/auth, sys/mounts, sys/policies
# Interpretation: Any policy granting 'sudo' or path "*" with broad capabilities is a blast-radius problem - scope to
#                 specific mount paths. Long or absent max_lease_ttl on auth mounts = long-lived credentials (shrink
#                 them; short leases limit stolen-token value). Auth methods you don't recognize = review who enabled
#                 them. The root token should NOT be in daily use - its existence in scripts/CI is a critical finding.
# Next step:      Tighten wildcard policies to explicit paths; shorten TTLs; confirm audit devices are enabled (03)

set -euo pipefail
: "${VAULT_ADDR:?}"; : "${VAULT_TOKEN:?set a policy-read token}"
export VAULT_ADDR VAULT_TOKEN

echo "== Auth methods"
vault auth list -format=json | jq -r 'to_entries[] | [.key, .value.type, (.value.config.max_lease_ttl|tostring)] | @tsv'

echo
echo "== Secret engine mounts"
vault secrets list -format=json | jq -r 'to_entries[] | [.key, .value.type] | @tsv'

echo
echo "== Policies containing sudo or wildcard paths"
for p in $(vault policy list); do
    body=$(vault policy read "$p" 2>/dev/null)
    if echo "$body" | grep -qE 'sudo|path\s+"\*"|path\s+".*\*"'; then
        echo "--- POLICY: $p (broad) ---"
        echo "$body" | grep -E 'path|capabilities|sudo' | head -12
    fi
done
