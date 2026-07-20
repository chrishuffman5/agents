#!/usr/bin/env bash
# Purpose:        Vault health, seal status, and HA leadership - the first checks when "Vault is down / apps can't get secrets"
# Applies to:     HashiCorp Vault 1.15+ (vault CLI or curl; read-only status endpoints need no auth)
# Read-only:      yes
# Inputs:         VAULT_ADDR in the environment (https://vault.example.com:8200)
# Interpretation: sealed=true = Vault is CLOSED - no secrets served until unsealed (auto-unseal via KMS should prevent
#                 this; manual unseal needs the key-holder quorum). standby with no active leader = HA cluster lost
#                 quorum (Raft: check peer set). ha_enabled true with a leader_address is healthy. Version drift across
#                 nodes = a stuck rolling upgrade. This endpoint is unauthenticated by design - safe to poll.
# Next step:      02-token-and-lease-audit.sh once healthy; if sealed, follow the auto-unseal/KMS path, not manual keys, if configured

set -euo pipefail
: "${VAULT_ADDR:?set VAULT_ADDR}"

echo "== Seal status"
curl -sf "${VAULT_ADDR}/v1/sys/seal-status" | jq '{sealed, initialized, version, t: .t, n: .n, progress}'

echo
echo "== HA status"
curl -sf "${VAULT_ADDR}/v1/sys/ha-status" 2>/dev/null | jq '.Nodes[] | {node: .hostname, active_node: .active_node, last_echo: .last_echo}' 2>/dev/null ||
    curl -sf "${VAULT_ADDR}/v1/sys/leader" | jq '{ha_enabled, is_self, leader_address}'

echo
echo "== Health (200 active, 429 standby, 503 sealed)"
curl -s -o /dev/null -w 'HTTP %{http_code}\n' "${VAULT_ADDR}/v1/sys/health"
