#!/bin/bash
# ==============================================================================
# KVM/libvirt Host Health Check
# ==============================================================================
# Run on a KVM host with libvirt. Checks KVM module status, node resources,
# storage pools, virtual networks, domain status, and resource usage.
#
# Usage: bash 01-virsh-health.sh
# ==============================================================================

set -euo pipefail

DIVIDER="========================================================================"
SECTION="------------------------------------------------------------------------"

echo "$DIVIDER"
echo "KVM/libvirt Host Health Check Report"
echo "Generated: $(date)"
echo "Hostname:  $(hostname -f)"
echo "$DIVIDER"

WARNINGS=()

# --- KVM Module Status ---
echo ""
echo "1. KVM MODULE STATUS"
echo "$SECTION"
if lsmod | grep -q kvm; then
    echo "KVM modules loaded:"
    lsmod | grep kvm
    echo ""

    # Check hardware virtualization
    if grep -q vmx /proc/cpuinfo 2>/dev/null; then
        echo "CPU Virtualization: Intel VT-x (vmx)"
        ept=$(cat /sys/module/kvm_intel/parameters/ept 2>/dev/null || echo "N/A")
        nested=$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo "N/A")
        echo "  EPT: $ept  Nested: $nested"
    elif grep -q svm /proc/cpuinfo 2>/dev/null; then
        echo "CPU Virtualization: AMD-V (svm)"
        npt=$(cat /sys/module/kvm_amd/parameters/npt 2>/dev/null || echo "N/A")
        nested=$(cat /sys/module/kvm_amd/parameters/nested 2>/dev/null || echo "N/A")
        echo "  NPT: $npt  Nested: $nested"
    fi
else
    echo "[CRITICAL] KVM modules NOT loaded!"
    WARNINGS+=("[CRIT] KVM modules not loaded")
fi

# --- Node Information ---
echo ""
echo "2. NODE INFORMATION"
echo "$SECTION"
if command -v virsh >/dev/null 2>&1; then
    virsh nodeinfo 2>/dev/null || echo "(virsh nodeinfo failed)"
else
    echo "virsh not found. Is libvirt installed?"
    WARNINGS+=("[CRIT] virsh not found")
fi

echo ""
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"

echo ""
echo "Memory:"
free -h | grep -E "Mem|Swap"

mem_total=$(free | awk '/Mem/ {print $2}')
mem_used=$(free | awk '/Mem/ {print $3}')
mem_pct=$((mem_used * 100 / mem_total))
if [ "$mem_pct" -gt 90 ]; then
    WARNINGS+=("[WARN] Host memory usage at ${mem_pct}%")
fi

echo ""
echo "CPU Load: $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
echo "CPU Cores: $(nproc)"

# --- Hugepages ---
echo ""
echo "3. HUGEPAGES"
echo "$SECTION"
grep -i huge /proc/meminfo 2>/dev/null || echo "No hugepage info available."

# --- libvirt Service Status ---
echo ""
echo "4. LIBVIRT SERVICE STATUS"
echo "$SECTION"
for svc in libvirtd virtqemud virtstoraged virtnetworkd virtproxyd; do
    status=$(systemctl is-active "$svc" 2>/dev/null || echo "not-found")
    if [ "$status" = "active" ]; then
        echo "  $svc: ACTIVE"
    elif [ "$status" = "not-found" ]; then
        : # skip services that don't exist
    else
        echo "  $svc: $status"
        WARNINGS+=("[WARN] Service $svc is $status")
    fi
done

# --- Storage Pools ---
echo ""
echo "5. STORAGE POOLS"
echo "$SECTION"
if command -v virsh >/dev/null 2>&1; then
    virsh pool-list --all --details 2>/dev/null || virsh pool-list --all 2>/dev/null

    echo ""
    echo "Pool Usage:"
    while IFS= read -r pool; do
        [ -z "$pool" ] && continue
        pool_name=$(echo "$pool" | awk '{print $1}')
        info=$(virsh pool-info "$pool_name" 2>/dev/null)
        capacity=$(echo "$info" | grep "Capacity:" | awk '{print $2, $3}')
        available=$(echo "$info" | grep "Available:" | awk '{print $2, $3}')
        allocation=$(echo "$info" | grep "Allocation:" | awk '{print $2, $3}')
        echo "  $pool_name: Capacity=$capacity  Used=$allocation  Free=$available"
    done < <(virsh pool-list --name 2>/dev/null)
fi

# --- Virtual Networks ---
echo ""
echo "6. VIRTUAL NETWORKS"
echo "$SECTION"
if command -v virsh >/dev/null 2>&1; then
    virsh net-list --all 2>/dev/null

    echo ""
    echo "Network Details:"
    while IFS= read -r net; do
        [ -z "$net" ] && continue
        autostart=$(virsh net-info "$net" 2>/dev/null | grep "Autostart:" | awk '{print $2}')
        bridge=$(virsh net-info "$net" 2>/dev/null | grep "Bridge:" | awk '{print $2}')
        echo "  $net: Bridge=$bridge Autostart=$autostart"
    done < <(virsh net-list --name 2>/dev/null)
fi

# --- Domain (VM) Status ---
echo ""
echo "7. VIRTUAL MACHINES"
echo "$SECTION"
if command -v virsh >/dev/null 2>&1; then
    virsh list --all 2>/dev/null

    total=$(virsh list --all --name 2>/dev/null | grep -c '.' || echo 0)
    running=$(virsh list --state-running --name 2>/dev/null | grep -c '.' || echo 0)
    shutoff=$(virsh list --state-shutoff --name 2>/dev/null | grep -c '.' || echo 0)

    echo ""
    echo "Total: $total  Running: $running  Shut off: $shutoff"
fi

# --- IOMMU Status ---
echo ""
echo "8. IOMMU STATUS"
echo "$SECTION"
if [ -d /sys/kernel/iommu_groups ]; then
    group_count=$(ls -d /sys/kernel/iommu_groups/*/ 2>/dev/null | wc -l)
    echo "IOMMU enabled: $group_count groups"
else
    echo "IOMMU not enabled (no /sys/kernel/iommu_groups)"
fi

# --- Disk Space ---
echo ""
echo "9. DISK SPACE"
echo "$SECTION"
df -h /var/lib/libvirt 2>/dev/null || df -h /

# Check for low space on image directory
img_usage=$(df /var/lib/libvirt/images 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ -n "$img_usage" ] && [ "$img_usage" -gt 80 ] 2>/dev/null; then
    WARNINGS+=("[WARN] /var/lib/libvirt/images at ${img_usage}% capacity")
fi

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
