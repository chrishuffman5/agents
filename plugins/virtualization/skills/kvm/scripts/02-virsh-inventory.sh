#!/bin/bash
# ==============================================================================
# KVM/libvirt VM Inventory Report
# ==============================================================================
# Run on a KVM host with libvirt. Generates a detailed inventory of all VMs
# with state, CPU, memory, disk, and network configuration.
#
# Usage: bash 02-virsh-inventory.sh
# ==============================================================================

set -euo pipefail

DIVIDER="========================================================================"
SECTION="------------------------------------------------------------------------"

echo "$DIVIDER"
echo "KVM/libvirt VM Inventory Report"
echo "Generated: $(date)"
echo "Hostname:  $(hostname -f)"
echo "$DIVIDER"

# Check virsh is available
if ! command -v virsh >/dev/null 2>&1; then
    echo "ERROR: virsh not found. Is libvirt installed?"
    exit 1
fi

# --- Host Summary ---
echo ""
echo "1. HOST SUMMARY"
echo "$SECTION"
virsh nodeinfo 2>/dev/null
echo ""
echo "Kernel: $(uname -r)"
echo "QEMU Version: $(qemu-system-x86_64 --version 2>/dev/null | head -1 || echo 'N/A')"
echo "libvirt Version: $(virsh version --daemon 2>/dev/null | grep 'Running hypervisor' || echo 'N/A')"

# --- VM Inventory ---
echo ""
echo "2. VIRTUAL MACHINE INVENTORY"
echo "$SECTION"

vm_list=$(virsh list --all --name 2>/dev/null | grep '.')
if [ -z "$vm_list" ]; then
    echo "No virtual machines found."
else
    total=0
    running=0
    shutoff=0

    echo ""
    while IFS= read -r vm; do
        [ -z "$vm" ] && continue
        total=$((total + 1))

        echo "--- $vm ---"

        # Get basic info
        state=$(virsh domstate "$vm" 2>/dev/null || echo "unknown")
        case "$state" in
            "running") running=$((running + 1)) ;;
            "shut off") shutoff=$((shutoff + 1)) ;;
        esac

        # Get domain info
        info=$(virsh dominfo "$vm" 2>/dev/null)
        uuid=$(echo "$info" | grep "UUID:" | awk '{print $2}')
        max_mem=$(echo "$info" | grep "Max memory:" | awk '{print $3, $4}')
        used_mem=$(echo "$info" | grep "Used memory:" | awk '{print $3, $4}')
        vcpus=$(echo "$info" | grep "CPU(s):" | awk '{print $2}')
        autostart=$(echo "$info" | grep "Autostart:" | awk '{print $2}')

        echo "  State:     $state"
        echo "  UUID:      $uuid"
        echo "  vCPUs:     $vcpus"
        echo "  Max Mem:   $max_mem"
        echo "  Used Mem:  $used_mem"
        echo "  Autostart: $autostart"

        # Get disk info
        echo "  Disks:"
        while IFS= read -r disk_line; do
            [ -z "$disk_line" ] && continue
            echo "$disk_line" | grep -q "Target" && continue
            echo "$disk_line" | grep -q "^---" && continue
            target=$(echo "$disk_line" | awk '{print $1}')
            source=$(echo "$disk_line" | awk '{print $2}')
            if [ -n "$target" ] && [ "$target" != "-" ]; then
                # Get disk size if file exists
                if [ -f "$source" ]; then
                    disk_info=$(qemu-img info "$source" 2>/dev/null)
                    virt_size=$(echo "$disk_info" | grep "virtual size" | head -1 | sed 's/virtual size: //')
                    disk_size=$(echo "$disk_info" | grep "disk size" | head -1 | sed 's/disk size: //')
                    format=$(echo "$disk_info" | grep "file format" | awk '{print $3}')
                    echo "    $target: $source ($format, virtual=$virt_size, actual=$disk_size)"
                else
                    echo "    $target: $source"
                fi
            fi
        done < <(virsh domblklist "$vm" 2>/dev/null)

        # Get network info
        echo "  Network:"
        while IFS= read -r net_line; do
            [ -z "$net_line" ] && continue
            echo "$net_line" | grep -q "Interface" && continue
            echo "$net_line" | grep -q "^---" && continue
            iface=$(echo "$net_line" | awk '{print $1}')
            ntype=$(echo "$net_line" | awk '{print $2}')
            source=$(echo "$net_line" | awk '{print $3}')
            model=$(echo "$net_line" | awk '{print $4}')
            mac=$(echo "$net_line" | awk '{print $5}')
            if [ -n "$iface" ] && [ "$iface" != "-" ]; then
                echo "    $iface: type=$ntype source=$source model=$model mac=$mac"
            fi
        done < <(virsh domiflist "$vm" 2>/dev/null)

        # Get snapshots
        snap_count=$(virsh snapshot-list "$vm" --name 2>/dev/null | grep -c '.' || echo 0)
        if [ "$snap_count" -gt 0 ]; then
            echo "  Snapshots: $snap_count"
            virsh snapshot-list "$vm" --name 2>/dev/null | while read -r snap; do
                [ -z "$snap" ] && continue
                echo "    - $snap"
            done
        fi

        echo ""
    done <<< "$vm_list"

    # --- Storage Pools ---
    echo ""
    echo "3. STORAGE POOLS"
    echo "$SECTION"
    virsh pool-list --all --details 2>/dev/null || virsh pool-list --all 2>/dev/null

    # --- Virtual Networks ---
    echo ""
    echo "4. VIRTUAL NETWORKS"
    echo "$SECTION"
    virsh net-list --all 2>/dev/null

    echo ""
    echo "DHCP Leases (default network):"
    virsh net-dhcp-leases default 2>/dev/null || echo "(No default network or no leases)"

    # --- Summary ---
    echo ""
    echo "$DIVIDER"
    echo "INVENTORY SUMMARY"
    echo "$DIVIDER"
    echo "  Total VMs:    $total"
    echo "  Running:      $running"
    echo "  Shut off:     $shutoff"
    echo "  Other:        $((total - running - shutoff))"
fi

echo ""
echo "Report complete: $(date)"
echo "$DIVIDER"
