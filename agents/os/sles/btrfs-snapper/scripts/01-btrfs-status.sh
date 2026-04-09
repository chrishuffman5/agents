#!/usr/bin/env bash
# ============================================================================
# Btrfs/Snapper - Filesystem Status Overview
#
# Purpose : Btrfs filesystem health per mount including device stats,
#           block group allocation, compression ratio, metadata
#           saturation warning, and scrub history.
# Version : 1.0.0
# Targets : SLES 15+ with Btrfs root filesystem
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Btrfs Mount Discovery
#   2. Per-Mount Filesystem Info
#   3. Device Error Counters
#   4. Metadata Saturation Check
#   5. Compression Ratio
#   6. Scrub Status
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
echo "  Btrfs Filesystem Status - $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"

# Discover Btrfs mount points
BTRFS_MOUNTS=$(awk '$3 == "btrfs" {print $2}' /proc/mounts 2>/dev/null | sort -u)

if [[ -z "$BTRFS_MOUNTS" ]]; then
    echo "  [ERROR] No Btrfs filesystems found mounted"
    exit 1
fi

for MOUNT in $BTRFS_MOUNTS; do
    section "MOUNT POINT: $MOUNT"

    # Filesystem info
    echo "  --- Filesystem Info ---"
    btrfs filesystem show "$MOUNT" 2>/dev/null | sed 's/^/    /' \
        || echo "    Could not get filesystem info"

    # Block group allocation
    echo ""
    echo "  --- Block Group Allocation ---"
    btrfs filesystem df "$MOUNT" 2>/dev/null | sed 's/^/    /' \
        || echo "    Could not get allocation info"

    # Detailed usage
    echo ""
    echo "  --- Detailed Usage ---"
    btrfs filesystem usage "$MOUNT" 2>/dev/null | head -30 | sed 's/^/    /' || true

    # Metadata saturation check
    echo ""
    META_USED=$(btrfs filesystem df "$MOUNT" 2>/dev/null \
        | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$3); print int($3)}')
    META_TOTAL=$(btrfs filesystem df "$MOUNT" 2>/dev/null \
        | awk '/^Metadata/ {gsub(/[^0-9.]/,"",$4); print int($4)}')
    if [[ -n "${META_USED:-}" && -n "${META_TOTAL:-}" && "${META_TOTAL:-0}" -gt 0 ]]; then
        PCT=$(( META_USED * 100 / META_TOTAL ))
        if [[ "$PCT" -ge 90 ]]; then
            echo "  [ERROR] Metadata at ${PCT}% -- ENOSPC risk"
            echo "          Run: btrfs balance start -musage=50 $MOUNT"
        elif [[ "$PCT" -ge 75 ]]; then
            echo "  [WARN]  Metadata at ${PCT}% -- monitor closely"
        else
            echo "  [OK]    Metadata at ${PCT}%"
        fi
    fi

    # Device error counters
    echo ""
    echo "  --- Device Error Counters ---"
    STATS=$(btrfs device stats "$MOUNT" 2>/dev/null)
    if [[ -n "$STATS" ]]; then
        echo "$STATS" | sed 's/^/    /'
        ERROR_SUM=$(echo "$STATS" | awk '{sum += $2} END {print sum}')
        if [[ "${ERROR_SUM:-0}" -gt 0 ]]; then
            echo "  [ERROR] Non-zero device error counters -- investigate hardware"
        else
            echo "  [OK]    All device error counters are zero"
        fi
    fi

    # Subvolume count
    echo ""
    SUBVOL_COUNT=$(btrfs subvolume list "$MOUNT" 2>/dev/null | wc -l)
    echo "  --- Subvolumes: $SUBVOL_COUNT ---"
    btrfs subvolume list "$MOUNT" 2>/dev/null | head -15 | sed 's/^/    /'
    if [[ "$SUBVOL_COUNT" -gt 100 ]]; then
        echo "  [WARN] High subvolume count may impact performance"
    fi

    # Default subvolume
    echo ""
    echo "  --- Default Subvolume ---"
    btrfs subvolume get-default "$MOUNT" 2>/dev/null | sed 's/^/    /'

    # Compression ratio
    echo ""
    if command -v compsize &>/dev/null; then
        echo "  --- Compression Ratio ---"
        compsize "$MOUNT" 2>/dev/null | tail -5 | sed 's/^/    /' || true
    else
        echo "  --- Compression Ratio ---"
        echo "    compsize not installed (install btrfs-compsize for stats)"
    fi

    echo ""
done

# Scrub status for all filesystems
section "SCRUB STATUS"
for MOUNT in $BTRFS_MOUNTS; do
    echo "  $MOUNT:"
    SCRUB=$(btrfs scrub status "$MOUNT" 2>/dev/null)
    echo "$SCRUB" | sed 's/^/    /'
    if echo "$SCRUB" | grep -q "no errors found"; then
        echo "  [OK]    Last scrub: no errors"
    elif echo "$SCRUB" | grep -qE "error|corrupt"; then
        echo "  [ERROR] Scrub found errors"
    elif echo "$SCRUB" | grep -q "not yet run"; then
        echo "  [WARN]  Scrub has never been run"
    fi
    echo ""
done

echo "$SEP"
echo "  Btrfs tools: $(btrfs --version 2>/dev/null | head -1)"
echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo "$SEP"
