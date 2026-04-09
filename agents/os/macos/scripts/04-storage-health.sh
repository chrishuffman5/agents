#!/bin/bash
# ============================================================================
# macOS - Storage Health
# Version : 1.0.0
# Targets : macOS 14+ (Sonoma and later)
# Safety  : Read-only. No modifications to system configuration.
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
echo "  macOS STORAGE HEALTH"
echo "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "$SEP"

# -- Section 1: Disk Overview ------------------------------------------------
section "SECTION 1 - Disk Overview"

diskutil list 2>/dev/null | sed 's/^/  /' || echo "  Unable to list disks"

# -- Section 2: APFS Containers and Volumes ----------------------------------
section "SECTION 2 - APFS Containers and Volumes"

diskutil apfs list 2>/dev/null | sed 's/^/  /' || echo "  Unable to list APFS containers"

# -- Section 3: Boot Volume Info ---------------------------------------------
section "SECTION 3 - Boot Volume"

diskutil info / 2>/dev/null | awk -F':' '
    /Volume Name|File System|Disk Size|Volume Free|Volume Used|Encrypted|FileVault/{
        gsub(/^[ \t]+|[ \t]+$/, "", $2)
        printf "  %-28s: %s\n", $1, $2
    }' || echo "  Unable to query boot volume"

# -- Section 4: Disk Space Usage ---------------------------------------------
section "SECTION 4 - Disk Space Usage"

df -h / 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Volume usage (all mounted):"
df -h 2>/dev/null | grep -E "^/dev|Filesystem" | sed 's/^/    /'

# -- Section 5: FileVault Status ---------------------------------------------
section "SECTION 5 - FileVault Encryption"

FV_STATUS=$(fdesetup status 2>/dev/null || echo "Unable to query FileVault")
if echo "$FV_STATUS" | grep -q "On"; then
    echo "  [OK]   $FV_STATUS"
elif echo "$FV_STATUS" | grep -q "Off"; then
    echo "  [WARN] $FV_STATUS"
    echo "         Recommendation: Enable with 'sudo fdesetup enable'"
else
    echo "  $FV_STATUS"
fi

FV_USERS=$(fdesetup list 2>/dev/null || echo "")
if [[ -n "$FV_USERS" ]]; then
    echo ""
    echo "  FileVault-enabled users:"
    echo "$FV_USERS" | sed 's/^/    /'
fi

# -- Section 6: Time Machine -------------------------------------------------
section "SECTION 6 - Time Machine"

TM_DEST=$(tmutil destinationinfo 2>/dev/null || echo "")
if [[ -n "$TM_DEST" ]] && ! echo "$TM_DEST" | grep -q "No destinations"; then
    echo "  Destinations:"
    echo "$TM_DEST" | sed 's/^/    /'
else
    echo "  [INFO] No Time Machine destinations configured"
fi

echo ""
LATEST=$(tmutil latestbackup 2>/dev/null || echo "")
if [[ -n "$LATEST" ]]; then
    echo "  Latest backup: $LATEST"
else
    echo "  Latest backup: None found"
fi

echo ""
echo "  Local APFS snapshots:"
SNAPS=$(tmutil listlocalsnapshots / 2>/dev/null || echo "")
if [[ -n "$SNAPS" ]]; then
    SNAP_COUNT=$(echo "$SNAPS" | grep -c "com.apple" || echo "0")
    echo "    Count: $SNAP_COUNT"
    echo "$SNAPS" | tail -5 | sed 's/^/    /'
else
    echo "    No local snapshots found"
fi

# -- Section 7: SMART Status -------------------------------------------------
section "SECTION 7 - SMART / Storage Health"

SMART_STATUS=$(system_profiler SPStorageDataType 2>/dev/null | grep -i "SMART Status" || echo "")
if [[ -n "$SMART_STATUS" ]]; then
    echo "$SMART_STATUS" | sed 's/^/  /'
else
    echo "  SMART status not available via system_profiler"
fi

# Check if smartmontools is installed
if command -v smartctl &>/dev/null; then
    echo ""
    echo "  smartctl health check:"
    BOOT_DISK=$(diskutil info / 2>/dev/null | awk '/Part of Whole/{print $NF}')
    if [[ -n "$BOOT_DISK" ]]; then
        sudo smartctl -H "/dev/$BOOT_DISK" 2>/dev/null | grep -i "result\|status" | sed 's/^/    /' || echo "    Unable to check"
    fi
else
    echo "  [INFO] smartmontools not installed (brew install smartmontools for detailed SMART data)"
fi

# -- Section 8: Large Directories --------------------------------------------
section "SECTION 8 - Large Directories (top space consumers)"

echo "  ~/Library/Caches  : $(du -sh ~/Library/Caches 2>/dev/null | cut -f1 || echo 'unknown')"
echo "  ~/Downloads       : $(du -sh ~/Downloads 2>/dev/null | cut -f1 || echo 'unknown')"
echo "  ~/Library/Logs    : $(du -sh ~/Library/Logs 2>/dev/null | cut -f1 || echo 'unknown')"
echo "  Homebrew cache    : $(du -sh "$(brew --cache 2>/dev/null)" 2>/dev/null | cut -f1 || echo 'N/A')"

echo ""
echo "$SEP"
echo "  Storage health check complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
