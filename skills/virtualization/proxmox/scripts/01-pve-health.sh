#!/bin/bash
# ==============================================================================
# Proxmox VE Cluster Health Check
# ==============================================================================
# Run on any PVE cluster node. Checks cluster status, node health, storage,
# Ceph status (if installed), and VM/container counts.
#
# Usage: bash 01-pve-health.sh
# ==============================================================================

set -euo pipefail

DIVIDER="========================================================================"
SECTION="------------------------------------------------------------------------"

echo "$DIVIDER"
echo "Proxmox VE Health Check Report"
echo "Generated: $(date)"
echo "Hostname:  $(hostname -f)"
echo "PVE Version: $(pveversion 2>/dev/null || echo 'unknown')"
echo "$DIVIDER"

WARNINGS=()

# --- Node Information ---
echo ""
echo "1. NODE INFORMATION"
echo "$SECTION"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo ""
echo "CPU:"
echo "  Model:  $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)"
echo "  Cores:  $(nproc)"
echo "  Load:   $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo ""
echo "Memory:"
free -h | grep -E "Mem|Swap"
echo ""

# Check memory usage percentage
mem_total=$(free | awk '/Mem/ {print $2}')
mem_used=$(free | awk '/Mem/ {print $3}')
mem_pct=$((mem_used * 100 / mem_total))
if [ "$mem_pct" -gt 90 ]; then
    WARNINGS+=("[WARN] Node memory usage at ${mem_pct}%")
fi

# --- Cluster Status ---
echo ""
echo "2. CLUSTER STATUS"
echo "$SECTION"
if pvecm status >/dev/null 2>&1; then
    pvecm status
    echo ""
    echo "Cluster Nodes:"
    pvecm nodes 2>/dev/null || echo "(Could not list nodes)"

    # Check quorum
    quorate=$(pvecm status 2>/dev/null | grep -i "quorate" | awk '{print $NF}')
    if [ "$quorate" != "Yes" ]; then
        WARNINGS+=("[CRIT] Cluster is NOT quorate!")
    fi
else
    echo "Not part of a cluster (standalone node)."
fi

# --- HA Status ---
echo ""
echo "3. HA MANAGER STATUS"
echo "$SECTION"
if command -v ha-manager >/dev/null 2>&1; then
    ha_status=$(ha-manager status 2>/dev/null)
    if [ -n "$ha_status" ]; then
        echo "$ha_status"
        # Check for error states
        ha_errors=$(echo "$ha_status" | grep -c "error" || true)
        if [ "$ha_errors" -gt 0 ]; then
            WARNINGS+=("[CRIT] $ha_errors HA resource(s) in error state")
        fi
    else
        echo "No HA resources configured."
    fi
else
    echo "HA Manager not available."
fi

# --- Storage Status ---
echo ""
echo "4. STORAGE STATUS"
echo "$SECTION"
pvesm status 2>/dev/null | column -t || echo "(Could not retrieve storage status)"

echo ""
echo "Local Disk Usage:"
df -h / /var/lib/vz 2>/dev/null | sort -u

# Check for storage over 80%
while IFS= read -r line; do
    usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')
    if [ -n "$usage" ] && [ "$usage" -gt 80 ] 2>/dev/null; then
        WARNINGS+=("[WARN] Filesystem $mount at ${usage}% capacity")
    fi
done < <(df -h 2>/dev/null | tail -n +2)

# --- ZFS Status (if present) ---
echo ""
echo "5. ZFS STATUS"
echo "$SECTION"
if command -v zpool >/dev/null 2>&1; then
    zpool_list=$(zpool list 2>/dev/null)
    if [ -n "$zpool_list" ]; then
        echo "$zpool_list"
        echo ""
        echo "ZFS Pool Status:"
        zpool status -x 2>/dev/null
        echo ""
        echo "ARC Stats:"
        arc_size=$(awk '/^size/ {printf "%.1f GB", $3/1073741824}' /proc/spl/kvm/arcstats 2>/dev/null)
        arc_max=$(awk '/^c_max/ {printf "%.1f GB", $3/1073741824}' /proc/spl/kvm/arcstats 2>/dev/null)
        echo "  ARC Size: $arc_size  ARC Max: $arc_max"

        # Check for degraded pools
        degraded=$(zpool status 2>/dev/null | grep -c "DEGRADED" || true)
        if [ "$degraded" -gt 0 ]; then
            WARNINGS+=("[CRIT] ZFS pool(s) in DEGRADED state")
        fi
    else
        echo "No ZFS pools found."
    fi
else
    echo "ZFS not installed."
fi

# --- Ceph Status (if present) ---
echo ""
echo "6. CEPH STATUS"
echo "$SECTION"
if command -v ceph >/dev/null 2>&1; then
    ceph_health=$(ceph health 2>/dev/null)
    if [ -n "$ceph_health" ]; then
        echo "Health: $ceph_health"
        echo ""
        ceph status 2>/dev/null
        echo ""
        echo "OSD Disk Usage:"
        ceph osd df tree 2>/dev/null | head -30

        if echo "$ceph_health" | grep -q "HEALTH_ERR"; then
            WARNINGS+=("[CRIT] Ceph cluster health is HEALTH_ERR")
        elif echo "$ceph_health" | grep -q "HEALTH_WARN"; then
            WARNINGS+=("[WARN] Ceph cluster health is HEALTH_WARN")
        fi
    else
        echo "Ceph not configured or not responding."
    fi
else
    echo "Ceph not installed."
fi

# --- VM and Container Counts ---
echo ""
echo "7. VM AND CONTAINER SUMMARY"
echo "$SECTION"
vm_total=$(qm list 2>/dev/null | tail -n +2 | wc -l)
vm_running=$(qm list 2>/dev/null | tail -n +2 | grep -c "running" || true)
vm_stopped=$(qm list 2>/dev/null | tail -n +2 | grep -c "stopped" || true)

ct_total=$(pct list 2>/dev/null | tail -n +2 | wc -l)
ct_running=$(pct list 2>/dev/null | tail -n +2 | grep -c "running" || true)
ct_stopped=$(pct list 2>/dev/null | tail -n +2 | grep -c "stopped" || true)

echo "Virtual Machines: $vm_total total ($vm_running running, $vm_stopped stopped)"
echo "Containers:       $ct_total total ($ct_running running, $ct_stopped stopped)"

# --- Services Status ---
echo ""
echo "8. CRITICAL SERVICES"
echo "$SECTION"
for svc in pvedaemon pveproxy pvestatd corosync pve-ha-lrm pve-ha-crm pve-firewall; do
    status=$(systemctl is-active "$svc" 2>/dev/null || echo "not-found")
    if [ "$status" = "active" ]; then
        echo "  $svc: ACTIVE"
    elif [ "$status" = "not-found" ]; then
        echo "  $svc: not installed"
    else
        echo "  $svc: $status"
        WARNINGS+=("[WARN] Service $svc is $status")
    fi
done

# --- Summary ---
echo ""
echo "$DIVIDER"
echo "HEALTH CHECK SUMMARY"
echo "$DIVIDER"

if [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "[OK] No critical warnings detected."
else
    echo "Issues found: ${#WARNINGS[@]}"
    echo ""
    for w in "${WARNINGS[@]}"; do
        echo "  $w"
    done
fi

echo ""
echo "Report complete: $(date)"
echo "$DIVIDER"
