#!/usr/bin/env bash
# ============================================================================
# SLES - Btrfs Filesystem Health
#
# Purpose : Check Btrfs filesystem health including space usage, device
#           error counters, subvolume count, snapshot inventory, scrub
#           status, and metadata saturation warnings.
# Version : 1.0.0
# Targets : SLES 15 SP5+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Btrfs Mount Points
#   2. Per-Mount Filesystem Info
#   3. Device Error Counters
#   4. Subvolume and Snapshot Count
#   5. Snapper Snapshot Summary
#   6. Scrub Status
#   7. Maintenance Timer Status
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
echo "  SLES Btrfs Health Check - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"

# Collect all Btrfs mount points
BTRFS_MPS=$(findmnt -t btrfs -n -o TARGET 2>/dev/null | sort -u)

if [ -z "$BTRFS_MPS" ]; then
    echo "  No Btrfs filesystems found."
    exit 0
fi

for mp in $BTRFS_MPS; do
    section "MOUNT POINT: $mp"

    # ── Filesystem Info ──────────────────────────────────────────────────
    echo "  --- Filesystem Info ---"
    btrfs filesystem show "$mp" 2>/dev/null | sed 's/^/    /' || echo "    Unable to retrieve"
    echo ""

    # ── Space Usage ──────────────────────────────────────────────────────
    echo "  --- Block Group Allocation ---"
    btrfs filesystem df "$mp" 2>/dev/null | sed 's/^/    /' || true
    echo ""

    echo "  --- Detailed Usage ---"
    btrfs filesystem usage "$mp" 2>/dev/null | head -20 | sed 's/^/    /' || true
    echo ""

    # ── Metadata Saturation Check ────────────────────────────────────────
    META_USED=$(btrfs filesystem df "$mp" 2>/dev/null | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$3); print int($3)}')
    META_TOTAL=$(btrfs filesystem df "$mp" 2>/dev/null | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$4); print int($4)}')
    if [[ -n "${META_USED:-}" && -n "${META_TOTAL:-}" && "${META_TOTAL:-0}" -gt 0 ]]; then
        PCT=$(( META_USED * 100 / META_TOTAL ))
        if [[ "$PCT" -ge 90 ]]; then
            echo "  [ERROR] Metadata at ${PCT}% -- ENOSPC risk. Run: btrfs balance start -musage=50 $mp"
        elif [[ "$PCT" -ge 75 ]]; then
            echo "  [WARN]  Metadata at ${PCT}% -- monitor closely"
        else
            echo "  [OK]    Metadata at ${PCT}%"
        fi
    fi
    echo ""

    # ── Device Error Counters ────────────────────────────────────────────
    echo "  --- Device Error Counters ---"
    STATS_OUTPUT=$(btrfs device stats "$mp" 2>/dev/null)
    if [[ -n "$STATS_OUTPUT" ]]; then
        echo "$STATS_OUTPUT" | sed 's/^/    /'
        ERROR_COUNT=$(echo "$STATS_OUTPUT" | awk '{sum += $2} END {print sum}')
        if [[ "${ERROR_COUNT:-0}" -gt 0 ]]; then
            echo "  [ERROR] Non-zero device error counters -- investigate hardware"
        else
            echo "  [OK]    All device error counters are zero"
        fi
    fi
    echo ""

    # ── Subvolume Count ──────────────────────────────────────────────────
    SUBVOL_COUNT=$(btrfs subvolume list "$mp" 2>/dev/null | wc -l)
    echo "  --- Subvolumes: $SUBVOL_COUNT total ---"
    btrfs subvolume list "$mp" 2>/dev/null | head -20 | sed 's/^/    /'
    if [[ "$SUBVOL_COUNT" -gt 100 ]]; then
        echo "  [WARN]  $SUBVOL_COUNT subvolumes -- high count may impact performance"
    fi
    echo ""

    # ── Default Subvolume ────────────────────────────────────────────────
    echo "  --- Default Subvolume ---"
    btrfs subvolume get-default "$mp" 2>/dev/null | sed 's/^/    /'
    echo ""
done

# ── Snapper Snapshot Summary ────────────────────────────────────────────
section "SNAPPER SNAPSHOT SUMMARY"

if command -v snapper &>/dev/null; then
    snapper list 2>/dev/null | head -20 | sed 's/^/  /' || echo "  Unable to list snapshots"
    echo ""
    SNAP_TOTAL=$(snapper list 2>/dev/null | awk 'NR>2 && NF>1 {c++} END {print c+0}')
    echo "  Total Snapper snapshots: $SNAP_TOTAL"
    if [[ "$SNAP_TOTAL" -gt 100 ]]; then
        echo "  [WARN] High snapshot count -- run: snapper cleanup number"
    fi
else
    echo "  snapper not installed"
fi

# ── Scrub Status ────────────────────────────────────────────────────────
section "SCRUB STATUS"

for mp in $BTRFS_MPS; do
    echo "  $mp:"
    SCRUB=$(btrfs scrub status "$mp" 2>/dev/null)
    echo "$SCRUB" | sed 's/^/    /'
    if echo "$SCRUB" | grep -q "no errors found"; then
        echo "  [OK]    Last scrub: no errors"
    elif echo "$SCRUB" | grep -qE "error|corrupt"; then
        echo "  [ERROR] Scrub found errors on $mp"
    elif echo "$SCRUB" | grep -q "not yet run"; then
        echo "  [WARN]  Scrub has never been run -- schedule monthly scrubs"
    fi
    echo ""
done

# ── Maintenance Timer Status ────────────────────────────────────────────
section "MAINTENANCE TIMER STATUS"

for timer in btrfsmaintenance-scrub.timer btrfsmaintenance-balance.timer snapper-timeline.timer snapper-cleanup.timer; do
    status=$(systemctl is-active "$timer" 2>/dev/null || echo "not-found")
    enabled=$(systemctl is-enabled "$timer" 2>/dev/null || echo "not-found")
    printf "  %-42s active=%-12s enabled=%s\n" "$timer" "$status" "$enabled"
done

echo ""
echo "$SEP"
echo "  Btrfs Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
