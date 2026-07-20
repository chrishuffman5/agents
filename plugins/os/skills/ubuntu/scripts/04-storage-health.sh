#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Storage Health
#
# Purpose : Storage subsystem assessment including filesystem usage, LVM,
#           ZFS pools, SMART disk health, and snap disk consumption.
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Filesystem and Mount Points
#   2. LVM Status
#   3. ZFS Status
#   4. Disk SMART Status
#   5. Snap Disk Usage
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# -- Section 1: Mount Points -----------------------------------------------
section "SECTION 1 - Filesystem and Mount Points"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=squashfs \
    2>/dev/null | sed 's/^/  /'
echo ""
echo "  Mounts at/above 80% usage:"
df -hT --exclude-type=tmpfs --exclude-type=squashfs 2>/dev/null \
    | awk 'NR>1 && int($6)>=80 {print "  [WARN] "$0}'

# -- Section 2: LVM --------------------------------------------------------
section "SECTION 2 - LVM Status"
if command -v pvs &>/dev/null; then
    echo "  Physical Volumes:"
    pvs 2>/dev/null | sed 's/^/  /' || echo "  No PVs found"
    echo ""
    echo "  Volume Groups:"
    vgs 2>/dev/null | sed 's/^/  /' || echo "  No VGs found"
    echo ""
    echo "  Logical Volumes:"
    lvs 2>/dev/null | sed 's/^/  /' || echo "  No LVs found"
    echo ""
    echo "  LVM snapshots:"
    lvs -o name,lv_attr,origin,snap_percent 2>/dev/null \
        | grep -E '^.{4}s' | sed 's/^/  /' || echo "  No snapshots active"
else
    echo "  [INFO] LVM tools not installed or no LVM configured"
fi

# -- Section 3: ZFS --------------------------------------------------------
section "SECTION 3 - ZFS Status"
if command -v zpool &>/dev/null && zpool list &>/dev/null 2>&1; then
    echo "  Pools:"
    zpool list | sed 's/^/  /'
    echo ""
    echo "  Pool health:"
    zpool status 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  ZFS datasets:"
    zfs list 2>/dev/null | sed 's/^/  /'
else
    echo "  [INFO] ZFS not in use on this system"
fi

# -- Section 4: SMART Disk Health -------------------------------------------
section "SECTION 4 - Disk SMART Status"
if command -v smartctl &>/dev/null; then
    for dev in /dev/sd? /dev/nvme?; do
        [[ -b "$dev" ]] || continue
        echo "  Disk: $dev"
        smartctl -H "$dev" 2>/dev/null | grep -E 'SMART|result|overall' \
            | sed 's/^/    /' || echo "    Unable to read SMART data"
    done
else
    echo "  [INFO] smartmontools not installed"
    echo "  Install: apt install smartmontools"
fi

# -- Section 5: Snap Disk Usage --------------------------------------------
section "SECTION 5 - Snap Disk Usage"
if command -v snap &>/dev/null; then
    echo "  Snap package storage:"
    du -sh /var/lib/snapd/snaps/ 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Disabled (old) snap revisions:"
    snap list --all 2>/dev/null | awk '/disabled/{print "  "$0}' \
        || echo "  Unable to list snap revisions"
else
    echo "  [INFO] snapd not installed"
fi

echo ""
echo "$SEP"
echo "  Storage Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
