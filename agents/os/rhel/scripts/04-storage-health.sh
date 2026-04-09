#!/usr/bin/env bash
# ============================================================================
# RHEL - Storage Health
#
# Purpose : Assess storage subsystem health including LVM status, Stratis
#           pools, XFS health, disk SMART data, mount points, and space usage.
# Version : 1.0.0
# Targets : RHEL 8+
# Safety  : Read-only. No modifications to system configuration.
#
# Sections:
#   1. Block Device Overview
#   2. Filesystem Usage
#   3. LVM Status
#   4. Stratis Pools
#   5. XFS Health
#   6. SMART Disk Health
#   7. Mount Options Audit
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

echo "RHEL Storage Health Report"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "Hostname:  $(hostname -f 2>/dev/null || hostname)"

# ── Section 1: Block Device Overview ────────────────────────────────────────
section "1. Block Device Overview"

lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID 2>/dev/null | sed 's/^/  /'

# ── Section 2: Filesystem Usage ─────────────────────────────────────────────
section "2. Filesystem Usage"

df -hT 2>/dev/null | sed 's/^/  /'

echo ""
echo "  Inode usage:"
df -i 2>/dev/null | awk 'NR>1 && $5+0 > 0' | sed 's/^/    /'

# Alert on near-full filesystems
df -hT 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$6); if($6+0 >= 90) print "  [WARN] " $7 " is " $6 "% full"}' || true
df -i 2>/dev/null | awk 'NR>1 {gsub(/%/,"",$5); if($5+0 >= 90) print "  [WARN] " $6 " inodes " $5 "% used"}' || true

# ── Section 3: LVM Status ───────────────────────────────────────────────────
section "3. LVM Status"

if command -v pvs &>/dev/null; then
    echo "  Physical Volumes:"
    pvs 2>/dev/null | sed 's/^/    /'

    echo ""
    echo "  Volume Groups:"
    vgs 2>/dev/null | sed 's/^/    /'

    echo ""
    echo "  Logical Volumes:"
    lvs -o lv_name,vg_name,lv_size,lv_attr,data_percent,pool_lv 2>/dev/null | sed 's/^/    /'

    # Check for thin pools nearing capacity
    lvs -o lv_name,data_percent --noheadings 2>/dev/null | while read -r name pct; do
        if [[ -n "$pct" ]] && (( $(echo "$pct > 85" | bc -l 2>/dev/null || echo 0) )); then
            echo "  [WARN] Thin pool $name is ${pct}% full"
        fi
    done
else
    echo "  [INFO] LVM tools not installed"
fi

# ── Section 4: Stratis Pools ────────────────────────────────────────────────
section "4. Stratis Pools"

if command -v stratis &>/dev/null; then
    if systemctl is-active stratisd &>/dev/null; then
        echo "  Pools:"
        stratis pool list 2>/dev/null | sed 's/^/    /'

        echo ""
        echo "  Filesystems:"
        stratis filesystem list 2>/dev/null | sed 's/^/    /'

        echo ""
        echo "  Block Devices:"
        stratis blockdev list 2>/dev/null | sed 's/^/    /'
    else
        echo "  [INFO] stratisd is not running"
    fi
else
    echo "  [INFO] Stratis not installed"
fi

# ── Section 5: XFS Health ───────────────────────────────────────────────────
section "5. XFS Health"

xfs_mounts=$(mount -t xfs 2>/dev/null | awk '{print $1, $3}')
if [[ -n "$xfs_mounts" ]]; then
    echo "$xfs_mounts" | while read -r dev mnt; do
        echo "  Device: $dev  Mount: $mnt"
        xfs_info "$mnt" 2>/dev/null | grep -E "data|log|naming" | head -3 | sed 's/^/    /'
        echo ""
    done
else
    echo "  [INFO] No XFS filesystems mounted"
fi

# Check TRIM timer
if systemctl is-enabled fstrim.timer &>/dev/null 2>&1; then
    echo "  [OK]   fstrim.timer is enabled (weekly TRIM)"
else
    echo "  [INFO] fstrim.timer not enabled -- consider enabling for SSD/NVMe"
fi

# ── Section 6: SMART Disk Health ────────────────────────────────────────────
section "6. SMART Disk Health"

if command -v smartctl &>/dev/null; then
    for disk in /dev/sd? /dev/nvme?n1; do
        [[ -b "$disk" ]] || continue
        health=$(smartctl -H "$disk" 2>/dev/null | grep -i "overall\|result" || echo "unknown")
        echo "  $disk: $health"
    done
else
    echo "  [INFO] smartmontools not installed"
    echo "  Install: dnf install smartmontools"
fi

# ── Section 7: Mount Options Audit ──────────────────────────────────────────
section "7. Mount Options Audit"

echo "  Active mounts:"
mount | grep -E "^/dev" 2>/dev/null | sed 's/^/    /'

echo ""
echo "  fstab entries:"
grep -v "^#\|^$" /etc/fstab 2>/dev/null | sed 's/^/    /'

# Check for noexec/nosuid on /tmp
tmp_opts=$(mount 2>/dev/null | grep "on /tmp " | grep -oP '\(.*?\)')
if [[ -n "$tmp_opts" ]]; then
    if echo "$tmp_opts" | grep -q "noexec"; then
        echo ""
        echo "  [OK]   /tmp has noexec"
    else
        echo ""
        echo "  [INFO] /tmp does not have noexec mount option"
    fi
fi

echo ""
echo "$SEP"
echo "  Storage Health Report Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
