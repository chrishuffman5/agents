#!/usr/bin/env bash
# ============================================================================
# Btrfs/Snapper - Maintenance Status and Recommendations
#
# Purpose : Check Btrfs maintenance status including scrub history,
#           balance need assessment, timer health, snapshot cleanup
#           status, and provide actionable recommendations.
# Version : 1.0.0
# Targets : SLES 15+ with Btrfs root filesystem
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Scrub History
#   2. Balance Assessment
#   3. Maintenance Timers
#   4. Snapshot Cleanup Status
#   5. Device Health
#   6. Recommendations
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
echo "  Btrfs Maintenance Status - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

BTRFS_MOUNTS=$(findmnt -t btrfs -n -o TARGET 2>/dev/null | sort -u)

if [[ -z "$BTRFS_MOUNTS" ]]; then
    echo "  [ERROR] No Btrfs filesystems found"
    exit 1
fi

RECS=()

# ── Scrub History ────────────────────────────────────────────────────────────
section "SCRUB HISTORY"

for mp in $BTRFS_MOUNTS; do
    echo "  $mp:"
    SCRUB=$(btrfs scrub status "$mp" 2>/dev/null)
    echo "$SCRUB" | sed 's/^/    /'

    if echo "$SCRUB" | grep -q "not yet run"; then
        echo "  [WARN] Scrub has NEVER been run on $mp"
        RECS+=("Run initial scrub: btrfs scrub start $mp")
    elif echo "$SCRUB" | grep -qE "error|corrupt"; then
        echo "  [ERROR] Last scrub found errors on $mp"
        RECS+=("Investigate scrub errors on $mp: btrfs device stats $mp")
    else
        echo "  [OK]   Last scrub completed without errors"
    fi
    echo ""
done

# ── Balance Assessment ───────────────────────────────────────────────────────
section "BALANCE ASSESSMENT"

for mp in $BTRFS_MOUNTS; do
    echo "  $mp:"

    # Check if balance is currently running
    BAL_STATUS=$(btrfs balance status "$mp" 2>/dev/null)
    if echo "$BAL_STATUS" | grep -q "No balance"; then
        echo "    No balance currently running"
    else
        echo "    Balance in progress:"
        echo "$BAL_STATUS" | sed 's/^/      /'
    fi

    # Check metadata saturation
    META_USED=$(btrfs filesystem df "$mp" 2>/dev/null \
        | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$3); print int($3)}')
    META_TOTAL=$(btrfs filesystem df "$mp" 2>/dev/null \
        | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$4); print int($4)}')
    if [[ -n "${META_USED:-}" && -n "${META_TOTAL:-}" && "${META_TOTAL:-0}" -gt 0 ]]; then
        PCT=$(( META_USED * 100 / META_TOTAL ))
        echo "    Metadata usage: ${PCT}%"
        if [[ "$PCT" -ge 80 ]]; then
            echo "    [WARN] Metadata near saturation"
            RECS+=("Balance metadata on $mp: btrfs balance start -musage=50 $mp")
        fi
    fi

    # Check unallocated space
    UNALLOC=$(btrfs filesystem usage "$mp" 2>/dev/null \
        | grep "Unallocated:" | head -1 | awk '{print $2}')
    if [[ -n "$UNALLOC" ]]; then
        echo "    Unallocated space: $UNALLOC"
    fi

    echo ""
done

# ── Maintenance Timers ───────────────────────────────────────────────────────
section "MAINTENANCE TIMERS"

for timer in btrfsmaintenance-scrub.timer btrfsmaintenance-balance.timer \
             btrfs-scrub@-.timer snapper-timeline.timer snapper-cleanup.timer; do
    status=$(systemctl is-active "$timer" 2>/dev/null || echo "not-found")
    enabled=$(systemctl is-enabled "$timer" 2>/dev/null || echo "not-found")
    if [[ "$status" == "active" ]]; then
        printf "  [OK]   %-42s active  enabled=%s\n" "$timer" "$enabled"
    elif [[ "$status" == "not-found" ]]; then
        printf "  [--]   %-42s not installed\n" "$timer"
    else
        printf "  [WARN] %-42s %s  enabled=%s\n" "$timer" "$status" "$enabled"
        RECS+=("Enable timer: systemctl enable --now $timer")
    fi
done

# Check btrfsmaintenance config
echo ""
if [[ -f /etc/sysconfig/btrfsmaintenance ]]; then
    echo "  Btrfsmaintenance configuration:"
    grep -E "^BTRFS_(SCRUB|BALANCE|DEFRAG)_" /etc/sysconfig/btrfsmaintenance 2>/dev/null \
        | sed 's/^/    /'
else
    echo "  /etc/sysconfig/btrfsmaintenance not found"
fi

# ── Snapshot Cleanup Status ──────────────────────────────────────────────────
section "SNAPSHOT CLEANUP STATUS"

if command -v snapper &>/dev/null; then
    SNAP_TOTAL=$(snapper list 2>/dev/null | awk 'NR>2 && NF>1 {c++} END {print c+0}')
    echo "  Total snapshots: $SNAP_TOTAL"

    if [[ "$SNAP_TOTAL" -gt 100 ]]; then
        echo "  [WARN] High snapshot count -- cleanup recommended"
        RECS+=("Run snapshot cleanup: snapper cleanup number && snapper cleanup timeline")
    elif [[ "$SNAP_TOTAL" -gt 50 ]]; then
        echo "  [INFO] Moderate snapshot count -- monitor disk space"
    else
        echo "  [OK]   Snapshot count within normal range"
    fi

    echo ""
    echo "  Last cleanup timer run:"
    journalctl -u snapper-cleanup.service --no-pager -n 3 2>/dev/null | sed 's/^/    /' \
        || echo "    No recent cleanup logs found"
else
    echo "  snapper not installed"
fi

# ── Device Health ────────────────────────────────────────────────────────────
section "DEVICE HEALTH SUMMARY"

for mp in $BTRFS_MOUNTS; do
    echo "  $mp:"
    STATS=$(btrfs device stats "$mp" 2>/dev/null)
    NON_ZERO=$(echo "$STATS" | grep -v " 0$" | grep -v "^$" || true)
    if [[ -n "$NON_ZERO" ]]; then
        echo "  [ERROR] Non-zero error counters:"
        echo "$NON_ZERO" | sed 's/^/    /'
        RECS+=("Investigate device errors on $mp: check dmesg and hardware logs")
    else
        echo "  [OK]   All device error counters are zero"
    fi
    echo ""
done

# ── Recommendations ──────────────────────────────────────────────────────────
section "MAINTENANCE RECOMMENDATIONS"

if [[ ${#RECS[@]} -eq 0 ]]; then
    echo "  No immediate maintenance actions required."
    echo "  System is in good maintenance health."
else
    echo "  ${#RECS[@]} recommendation(s):"
    echo ""
    for i in "${!RECS[@]}"; do
        echo "  $((i+1)). ${RECS[$i]}"
    done
fi

echo ""
echo "$SEP"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
