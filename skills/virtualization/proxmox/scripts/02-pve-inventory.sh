#!/bin/bash
# ==============================================================================
# Proxmox VE Inventory Report
# ==============================================================================
# Run on any PVE cluster node. Generates a full inventory of VMs, containers,
# storage, nodes, and networking configuration.
#
# Usage: bash 02-pve-inventory.sh
# ==============================================================================

set -euo pipefail

DIVIDER="========================================================================"
SECTION="------------------------------------------------------------------------"

echo "$DIVIDER"
echo "Proxmox VE Inventory Report"
echo "Generated: $(date)"
echo "Hostname:  $(hostname -f)"
echo "PVE Version: $(pveversion 2>/dev/null || echo 'unknown')"
echo "$DIVIDER"

# --- Cluster Nodes ---
echo ""
echo "1. CLUSTER NODES"
echo "$SECTION"
if pvecm status >/dev/null 2>&1; then
    cluster_name=$(pvecm status 2>/dev/null | grep "Cluster name" | awk '{print $NF}')
    echo "Cluster: $cluster_name"
    echo ""
    pvesh get /nodes --output-format text 2>/dev/null || pvecm nodes 2>/dev/null
    echo ""
    echo "Node Resources:"
    printf "%-20s %-8s %-12s %-12s %-8s\n" "NODE" "STATUS" "CPU" "MEMORY" "VMs"
    echo "$SECTION"
    for node_info in $(pvesh get /nodes --output-format json 2>/dev/null | python3 -c "
import sys,json
for n in json.load(sys.stdin):
    print(f\"{n.get('node','?')}|{n.get('status','?')}|{n.get('cpu',0):.1%}|{n.get('mem',0)}/{n.get('maxmem',1)}|{n.get('uptime',0)}\")
" 2>/dev/null); do
        node=$(echo "$node_info" | cut -d'|' -f1)
        status=$(echo "$node_info" | cut -d'|' -f2)
        cpu=$(echo "$node_info" | cut -d'|' -f3)
        mem=$(echo "$node_info" | cut -d'|' -f4)
        printf "%-20s %-8s %-12s %-12s\n" "$node" "$status" "$cpu" "$mem"
    done 2>/dev/null || echo "(Could not parse node details)"
else
    echo "Standalone node (not clustered)."
    echo "Node: $(hostname)"
fi

# --- Virtual Machines ---
echo ""
echo "2. VIRTUAL MACHINES"
echo "$SECTION"
echo ""
printf "%-8s %-30s %-10s %-6s %-8s %-12s\n" "VMID" "NAME" "STATUS" "CPU" "MEM(MB)" "DISK"
echo "$SECTION"

while IFS= read -r line; do
    # Skip header line
    echo "$line" | grep -q "VMID" && continue
    vmid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $2}')
    status=$(echo "$line" | awk '{print $3}')
    mem=$(echo "$line" | awk '{print $4}')
    disk=$(echo "$line" | awk '{print $6}')

    # Get CPU count from config
    cpus=$(qm config "$vmid" 2>/dev/null | grep "^cores:" | awk '{print $2}')
    [ -z "$cpus" ] && cpus="-"

    printf "%-8s %-30s %-10s %-6s %-8s %-12s\n" "$vmid" "$name" "$status" "$cpus" "$mem" "$disk"
done < <(qm list 2>/dev/null)

vm_count=$(qm list 2>/dev/null | tail -n +2 | wc -l)
echo ""
echo "Total VMs: $vm_count"

# --- Containers ---
echo ""
echo "3. LXC CONTAINERS"
echo "$SECTION"
echo ""
printf "%-8s %-30s %-10s %-6s %-8s %-12s\n" "CTID" "NAME" "STATUS" "CPU" "MEM(MB)" "DISK"
echo "$SECTION"

while IFS= read -r line; do
    echo "$line" | grep -q "VMID" && continue
    ctid=$(echo "$line" | awk '{print $1}')
    name=$(echo "$line" | awk '{print $3}')
    status=$(echo "$line" | awk '{print $2}')
    mem=$(echo "$line" | awk '{print $4}')
    disk=$(echo "$line" | awk '{print $6}')

    cpus=$(pct config "$ctid" 2>/dev/null | grep "^cores:" | awk '{print $2}')
    [ -z "$cpus" ] && cpus="-"

    printf "%-8s %-30s %-10s %-6s %-8s %-12s\n" "$ctid" "$name" "$status" "$cpus" "$mem" "$disk"
done < <(pct list 2>/dev/null)

ct_count=$(pct list 2>/dev/null | tail -n +2 | wc -l)
echo ""
echo "Total Containers: $ct_count"

# --- Storage ---
echo ""
echo "4. STORAGE"
echo "$SECTION"
echo ""
pvesm status 2>/dev/null | column -t

echo ""
echo "Storage Content Types:"
pvesh get /storage --output-format text 2>/dev/null | head -30 || \
    cat /etc/pve/storage.cfg 2>/dev/null

# --- Networking ---
echo ""
echo "5. NETWORKING"
echo "$SECTION"
echo ""
echo "Bridges:"
brctl show 2>/dev/null || echo "(brctl not available)"

echo ""
echo "Network Interfaces:"
ip -br link show 2>/dev/null || ip link show

echo ""
echo "IP Addresses:"
ip -br addr show 2>/dev/null || ip addr show | grep "inet "

echo ""
echo "Bonding (if configured):"
for bond in /proc/net/bonding/*; do
    if [ -f "$bond" ]; then
        echo "Bond: $(basename "$bond")"
        grep -E "Mode|Slave Interface|MII Status" "$bond" | head -10
        echo ""
    fi
done 2>/dev/null || echo "No bonds configured."

# --- Backup Schedule ---
echo ""
echo "6. BACKUP JOBS"
echo "$SECTION"
pvesh get /cluster/backup --output-format text 2>/dev/null || echo "No backup jobs configured."

# --- HA Resources ---
echo ""
echo "7. HA RESOURCES"
echo "$SECTION"
ha-manager status 2>/dev/null || echo "No HA resources configured."

# --- Summary ---
echo ""
echo "$DIVIDER"
echo "INVENTORY SUMMARY"
echo "$DIVIDER"
echo "  Virtual Machines: $vm_count"
echo "  Containers:       $ct_count"
echo "  Total Guests:     $((vm_count + ct_count))"
echo ""
echo "Report complete: $(date)"
echo "$DIVIDER"
