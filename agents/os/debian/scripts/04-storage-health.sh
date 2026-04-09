#!/usr/bin/env bash
# ============================================================================
# Debian - Storage Health
#
# Purpose : Block devices, mount points, disk space, inode usage, LVM,
#           SMART status, filesystem errors, large directories.
# Version : 1.0.0
# Targets : Debian 11+ (Bullseye and later)
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Block Devices
#   2. Mount Points
#   3. Disk Space Summary
#   4. Inode Usage
#   5. LVM
#   6. SMART Status
#   7. Filesystem Errors
#   8. Large Directories (/var)
# ============================================================================
set -euo pipefail

echo "=== STORAGE HEALTH ==="
echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo ""

echo "--- Block Devices ---"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL 2>/dev/null
echo ""

echo "--- Mount Points ---"
findmnt --real --output TARGET,SOURCE,FSTYPE,SIZE,AVAIL,USE% 2>/dev/null || mount | grep -v 'tmpfs\|devtmpfs'
echo ""

echo "--- Disk Space Summary ---"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=overlay \
   --exclude-type=squashfs 2>/dev/null | sort -k6 -rh || df -hT
echo ""

echo "--- Inode Usage ---"
df -i --exclude-type=tmpfs --exclude-type=devtmpfs 2>/dev/null | sort -k5 -rh | head -20
echo ""

echo "--- LVM ---"
if command -v pvs &>/dev/null; then
    echo "Physical Volumes:"
    pvs 2>/dev/null || echo "None"
    echo ""
    echo "Volume Groups:"
    vgs 2>/dev/null || echo "None"
    echo ""
    echo "Logical Volumes:"
    lvs 2>/dev/null || echo "None"
else
    echo "LVM not installed"
fi
echo ""

echo "--- SMART Status ---"
if command -v smartctl &>/dev/null; then
    for dev in /dev/sd? /dev/nvme?; do
        [ -b "$dev" ] || continue
        echo "=== $dev ==="
        smartctl -H "$dev" 2>/dev/null | grep -E 'SMART|Health|result' || echo "No data"
    done
else
    echo "smartmontools not installed (apt-get install smartmontools)"
fi
echo ""

echo "--- Filesystem Errors ---"
dmesg --since "24 hours ago" 2>/dev/null | grep -iE 'ext4|xfs|btrfs|error|corrupt|i/o error' | \
    tail -20 || journalctl -k --since "24 hours ago" --no-pager 2>/dev/null | \
    grep -iE 'ext4|xfs|btrfs|error|corrupt' | tail -20 || echo "None"
echo ""

echo "--- Large Directories (top 10 in /var) ---"
du -sh /var/* 2>/dev/null | sort -rh | head -10
echo ""

echo "--- Open Files Count ---"
lsof 2>/dev/null | wc -l | xargs echo "Open file handles:" || echo "lsof not available"
