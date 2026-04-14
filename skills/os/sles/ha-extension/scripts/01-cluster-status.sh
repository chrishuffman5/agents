#!/usr/bin/env bash
# ============================================================================
# HA Extension - Cluster Status Overview
#
# Purpose : Comprehensive cluster health snapshot including service
#           status, quorum, Designated Controller, maintenance mode,
#           and node list.
# Version : 1.0.0
# Targets : SLES 15+ with SUSE HA Extension
# Safety  : Read-only. No modifications to cluster configuration.
#
# Sections:
#   1. Cluster Service Status
#   2. Quorum Status
#   3. Pacemaker Cluster Status
#   4. Designated Controller
#   5. Maintenance Mode
#   6. Node List
#   7. CIB Last Change
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

echo "$SEP"
echo "  HA Cluster Status Overview - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── Cluster Service Status ──────────────────────────────────────────────────
section "CLUSTER SERVICE STATUS"

for svc in corosync pacemaker sbd hawk; do
    status=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive/not-found")
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
    printf "  %-12s active=%-12s enabled=%s\n" "$svc" "$status" "$enabled"
done

# ── Quorum Status ───────────────────────────────────────────────────────────
section "QUORUM STATUS"

if command -v corosync-quorumtool &>/dev/null; then
    corosync-quorumtool -s 2>/dev/null | sed 's/^/  /' \
        || echo "  ERROR: corosync not running"
else
    echo "  corosync-quorumtool not found"
fi

# ── Pacemaker Cluster Status ────────────────────────────────────────────────
section "PACEMAKER CLUSTER STATUS"

if command -v crm_mon &>/dev/null; then
    crm_mon -1 -r -f 2>/dev/null | sed 's/^/  /' \
        || echo "  ERROR: pacemaker not running"
else
    echo "  crm_mon not found"
fi

# ── Designated Controller ───────────────────────────────────────────────────
section "DESIGNATED CONTROLLER"

dc=$(crm_mon -1 2>/dev/null | grep "Current DC" | head -1 || echo "Unknown")
echo "  $dc"

# ── Maintenance Mode ────────────────────────────────────────────────────────
section "MAINTENANCE MODE"

mm=$(cibadmin -Q --scope crm_config 2>/dev/null \
    | grep -o 'name="maintenance-mode" value="[^"]*"' \
    | grep -o 'value="[^"]*"' \
    | cut -d'"' -f2 || echo "false")
echo "  Cluster maintenance-mode: ${mm:-false}"

echo ""
echo "  Per-node standby status:"
crm node list 2>/dev/null | while read -r line; do
    node=$(echo "$line" | awk '{print $1}')
    [ -z "$node" ] && continue
    standby=$(crm_attribute --query -t nodes -N "$node" -n standby 2>/dev/null \
              | grep -o 'value=.*' | cut -d= -f2 || echo "off")
    printf "    %-20s standby=%s\n" "$node" "${standby:-off}"
done

# ── Node List ────────────────────────────────────────────────────────────────
section "NODE LIST"

crm node list 2>/dev/null | sed 's/^/  /' || echo "  Unable to retrieve"

# ── CIB Last Change ─────────────────────────────────────────────────────────
section "CIB LAST CHANGE"

cibadmin -Q 2>/dev/null | grep -E "cib-last-written|dc-uuid|have-quorum" | head -5 \
    | sed 's/^/  /' || echo "  Unable to query CIB"

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
