#!/usr/bin/env bash
# ============================================================================
# Nutanix AHV - Cluster Health Dashboard
#
# Purpose : Comprehensive cluster health overview including cluster identity,
#           host inventory, storage container status, VM summary,
#           protection domain status, and CVM service health.
# Version : 1.0.0
# Targets : Nutanix AOS 5.x+ / AHV
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Cluster Identity
#   2. Host Inventory
#   3. Storage Container Status
#   4. VM Inventory
#   5. Protection Domain Status
#   6. CVM Service Health
#   7. Active Alerts
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# ── Section 1: Cluster Identity ────────────────────────────────────────────
section "SECTION 1 - Cluster Identity"

ncli cluster info 2>/dev/null | grep -E "Cluster Name|Cluster Id|External IP|NOS Version|Number of Nodes" | sed 's/^/  /' || echo "  [ERROR] Unable to query cluster info"

# ── Section 2: Host Inventory ──────────────────────────────────────────────
section "SECTION 2 - Host Inventory"

ncli host list 2>/dev/null | grep -E "Name|Id|Hypervisor Address|CVM Address|State" | sed 's/^/  /' || echo "  [ERROR] Unable to list hosts"

echo ""
host_count=$(ncli host list 2>/dev/null | grep -c "^    Id" || echo "0")
echo "  Total hosts: $host_count"

# ── Section 3: Storage Container Status ────────────────────────────────────
section "SECTION 3 - Storage Container Status"

ncli container list 2>/dev/null | grep -E "Name|Id|Replication Factor|Compression|Max Capacity|Used Capacity" | sed 's/^/  /' || echo "  [ERROR] Unable to list containers"

echo ""
echo "  Cluster Storage Summary:"
ncli cluster get-storage-info 2>/dev/null | grep -E "Total|Used|Free" | sed 's/^/    /' || echo "    [ERROR] Unable to query storage info"

# ── Section 4: VM Inventory ────────────────────────────────────────────────
section "SECTION 4 - VM Inventory"

total_vms=$(acli vm.list 2>/dev/null | grep -c "^[^ ]" || echo "0")
running_vms=$(acli vm.list power_state=on 2>/dev/null | grep -c "^[^ ]" || echo "0")
stopped_vms=$(acli vm.list power_state=off 2>/dev/null | grep -c "^[^ ]" || echo "0")

echo "  Running : $running_vms"
echo "  Stopped : $stopped_vms"
echo "  Total   : $total_vms"

# ── Section 5: Protection Domain Status ────────────────────────────────────
section "SECTION 5 - Protection Domain Status"

pd_count=$(ncli protection-domain list 2>/dev/null | grep -c "^    Name" || echo "0")
echo "  Protection Domains: $pd_count"

if [[ "$pd_count" -gt 0 ]]; then
    echo ""
    ncli protection-domain list 2>/dev/null | grep -E "Name|Active|Type" | sed 's/^/  /' || true
fi

echo ""
echo "  Remote Sites:"
ncli remote-site list 2>/dev/null | grep -E "Name|Remote Address|Status" | sed 's/^/    /' || echo "    (none configured)"

# ── Section 6: CVM Service Health ──────────────────────────────────────────
section "SECTION 6 - CVM Service Health"

echo "  Local CVM Services:"
genesis status 2>/dev/null | sed 's/^/    /' || echo "    [ERROR] Unable to query genesis status"

# ── Section 7: Active Alerts ──────────────────────────────────────────────
section "SECTION 7 - Active Alerts"

alert_count=$(ncli alert list 2>/dev/null | grep -c "^    Id" || echo "0")
echo "  Active alerts: $alert_count"

if [[ "$alert_count" -gt 0 ]]; then
    echo ""
    ncli alert list 2>/dev/null | grep -E "Title|Severity|Created" | head -30 | sed 's/^/  /' || true
fi

echo ""
echo "$SEP"
echo "  Nutanix Cluster Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
