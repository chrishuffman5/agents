#!/usr/bin/env bash
# ============================================================================
# HA Extension - Fencing / STONITH Audit
#
# Purpose : STONITH configuration audit including SBD device status,
#           watchdog health, fence device inventory, fencing topology,
#           and recent fence actions from logs.
# Version : 1.0.0
# Targets : SLES 15+ with SUSE HA Extension
# Safety  : Read-only. No modifications to cluster configuration.
#
# Sections:
#   1. STONITH Cluster Property
#   2. Configured Fence Devices
#   3. SBD Status
#   4. Watchdog Status
#   5. Recent Fence Actions
#   6. Fencing Topology
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
echo "  Fencing / STONITH Audit - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# ── STONITH Property ────────────────────────────────────────────────────────
section "STONITH CLUSTER PROPERTY"

stonith_enabled=$(crm configure show 2>/dev/null \
    | grep 'stonith-enabled' | grep -oP 'stonith-enabled=\K\S+' || echo "not-set (default=true)")
echo "  stonith-enabled: ${stonith_enabled}"

stonith_timeout=$(crm configure show 2>/dev/null \
    | grep 'stonith-timeout' | grep -oP 'stonith-timeout=\K\S+' || echo "not-set (default=60s)")
echo "  stonith-timeout: ${stonith_timeout}"

# ── Configured Fence Devices ────────────────────────────────────────────────
section "CONFIGURED STONITH RESOURCES"

crm_mon -1 -r 2>/dev/null | grep -i "stonith\|fence\|sbd" \
    | sed 's/^/  /' || echo "  No STONITH resources in crm_mon output"

echo ""
echo "  From CIB configuration:"
crm configure show 2>/dev/null | grep -E "^primitive.*stonith:" \
    | sed 's/^/    /' || echo "    No STONITH primitives in CIB"

echo ""
if command -v stonith_admin &>/dev/null; then
    echo "  Known STONITH devices:"
    stonith_admin -I 2>/dev/null | sed 's/^/    /' || echo "    stonith_admin -I failed"
fi

# ── SBD Status ──────────────────────────────────────────────────────────────
section "SBD STATUS"

sbd_config="/etc/sysconfig/sbd"
if [ -f "$sbd_config" ]; then
    echo "  SBD configuration:"
    grep -E "^SBD_DEVICE|^SBD_WATCHDOG|^SBD_PACEMAKER|^SBD_STARTMODE|^SBD_DELAY_START" \
        "$sbd_config" | sed 's/^/    /'

    sbd_devices=$(grep "^SBD_DEVICE=" "$sbd_config" \
        | cut -d= -f2 | tr -d '"' | tr ';' ' ')

    for dev in $sbd_devices; do
        echo ""
        if [ -b "$dev" ]; then
            echo "  --- Device: $dev ---"
            sbd -d "$dev" dump 2>/dev/null | sed 's/^/    /' \
                || echo "    ERROR: Could not dump SBD device"
            echo ""
            echo "    Node slots:"
            sbd -d "$dev" list 2>/dev/null | sed 's/^/    /' \
                || echo "    ERROR: Could not list slots"
        else
            echo "  [WARN] SBD device $dev not found or not a block device"
        fi
    done
else
    echo "  /etc/sysconfig/sbd not found -- SBD may not be configured"
fi

# ── Watchdog Status ─────────────────────────────────────────────────────────
section "WATCHDOG STATUS"

watchdog_dev=$(grep "^SBD_WATCHDOG_DEV=" "$sbd_config" 2>/dev/null \
    | cut -d= -f2 | tr -d '"' || echo "/dev/watchdog")
echo "  Watchdog device: $watchdog_dev"
if [ -e "$watchdog_dev" ]; then
    echo "  Status: PRESENT"
    ls -l "$watchdog_dev" 2>/dev/null | sed 's/^/  /'
else
    echo "  Status: NOT FOUND -- SBD may not function correctly"
fi

echo ""
echo "  Loaded watchdog modules:"
lsmod 2>/dev/null | grep -iE "watchdog|wdt|softdog" | sed 's/^/    /' || echo "    None found"

# ── Recent Fence Actions ────────────────────────────────────────────────────
section "RECENT FENCE ACTIONS (from logs)"

log_file="/var/log/pacemaker/pacemaker.log"
if [ -f "$log_file" ]; then
    grep -i "fence\|stonith\|sbd.*poison\|sbd.*reset" "$log_file" \
        | tail -20 | sed 's/^/  /' \
        || echo "  No fence events found"
else
    echo "  $log_file not found -- checking journal"
    journalctl -u pacemaker --no-pager -n 50 2>/dev/null \
        | grep -i "fence\|stonith" | tail -10 | sed 's/^/  /' \
        || echo "  No fence events in journal"
fi

# ── Fencing Topology ────────────────────────────────────────────────────────
section "FENCING TOPOLOGY"

crm configure show 2>/dev/null | grep -i "fencing.topology" \
    | sed 's/^/  /' || echo "  No fencing topology configured (flat fencing)"

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
