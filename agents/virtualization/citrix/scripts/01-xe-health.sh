#!/usr/bin/env bash
# ============================================================================
# Citrix Hypervisor / XenServer - Health Dashboard
#
# Purpose : Comprehensive health overview including pool status, host
#           inventory, Storage Repository utilization, VM summary,
#           HA configuration, and dom0 resource usage.
# Version : 1.0.0
# Targets : XenServer 7.x+ / XCP-ng 7.x+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Pool Identity
#   2. Host Inventory
#   3. Storage Repository Status
#   4. VM Inventory
#   5. HA Configuration
#   6. dom0 Resource Usage
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# ── Section 1: Pool Identity ───────────────────────────────────────────────
section "SECTION 1 - Pool Identity"

pool_uuid=$(xe pool-list params=uuid --minimal 2>/dev/null || echo "unknown")
pool_name=$(xe pool-list params=name-label --minimal 2>/dev/null || echo "unknown")
pool_master=$(xe pool-list params=master --minimal 2>/dev/null || echo "unknown")
master_name=$(xe host-param-get uuid="$pool_master" param-name=name-label 2>/dev/null || echo "unknown")

echo "  Pool Name    : $pool_name"
echo "  Pool UUID    : $pool_uuid"
echo "  Pool Master  : $master_name ($pool_master)"

# ── Section 2: Host Inventory ──────────────────────────────────────────────
section "SECTION 2 - Host Inventory"

xe host-list params=name-label,uuid,enabled,address 2>/dev/null | sed 's/^/  /' || echo "  [ERROR] Unable to list hosts"

host_count=$(xe host-list --minimal 2>/dev/null | tr ',' '\n' | wc -l)
echo ""
echo "  Total hosts: $host_count"

# ── Section 3: Storage Repository Status ───────────────────────────────────
section "SECTION 3 - Storage Repository Status"

echo "  Name                          | Type       | Size         | Used         | %Used"
echo "  ------------------------------|------------|--------------|--------------|------"

xe sr-list params=name-label,type,physical-size,physical-utilisation 2>/dev/null | \
  awk -F': ' '
    /name-label/ { name=$2 }
    /^type/ { type=$2 }
    /physical-size/ { size=$2 }
    /physical-utilisation/ {
      used=$2
      if (size+0 > 0) {
        pct = (used / size) * 100
        printf "  %-31s | %-10s | %12s | %12s | %5.1f%%\n", name, type, size, used, pct
      }
    }
  ' || echo "  [ERROR] Unable to list SRs"

# ── Section 4: VM Inventory ────────────────────────────────────────────────
section "SECTION 4 - VM Inventory"

running=$(xe vm-list power-state=running is-control-domain=false --minimal 2>/dev/null | tr ',' '\n' | grep -c . || echo "0")
halted=$(xe vm-list power-state=halted is-control-domain=false --minimal 2>/dev/null | tr ',' '\n' | grep -c . || echo "0")
suspended=$(xe vm-list power-state=suspended is-control-domain=false --minimal 2>/dev/null | tr ',' '\n' | grep -c . || echo "0")

echo "  Running   : $running"
echo "  Halted    : $halted"
echo "  Suspended : $suspended"
echo "  Total     : $((running + halted + suspended))"

echo ""
echo "  Running VMs:"
xe vm-list power-state=running is-control-domain=false params=name-label,uuid 2>/dev/null | sed 's/^/    /' || echo "    (none)"

# ── Section 5: HA Configuration ────────────────────────────────────────────
section "SECTION 5 - HA Configuration"

ha_enabled=$(xe pool-list params=ha-enabled --minimal 2>/dev/null || echo "unknown")
echo "  HA Enabled                : $ha_enabled"

if [[ "$ha_enabled" == "true" ]]; then
    ha_tolerate=$(xe pool-list params=ha-host-failures-to-tolerate --minimal 2>/dev/null || echo "unknown")
    ha_plan=$(xe pool-ha-compute-hypothetical-max-host-failures-to-tolerate 2>/dev/null || echo "unknown")
    echo "  Failures to Tolerate      : $ha_tolerate"
    echo "  Max Computable Tolerance  : $ha_plan"
else
    echo "  [INFO] HA is not enabled on this pool"
fi

# ── Section 6: dom0 Resource Usage ─────────────────────────────────────────
section "SECTION 6 - dom0 Resource Usage"

echo "  Memory:"
free -m 2>/dev/null | sed 's/^/    /' || echo "    [ERROR] Unable to read memory"

echo ""
echo "  Uptime:"
uptime 2>/dev/null | sed 's/^/    /' || echo "    [ERROR] Unable to read uptime"

echo ""
echo "  Load Average:"
cat /proc/loadavg 2>/dev/null | sed 's/^/    /' || echo "    [ERROR] Unable to read load"

echo ""
echo "$SEP"
echo "  XenServer Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
