#!/bin/sh
# ==============================================================================
# ESXi Host Health Check via esxcli
# ==============================================================================
# Run directly on an ESXi host via SSH or ESXi Shell.
# Checks system info, hardware health, network status, storage health,
# NTP sync, and running VM inventory.
#
# Usage: sh 01-esxcli-health.sh
# ==============================================================================

DIVIDER="========================================================================"
SECTION="------------------------------------------------------------------------"

echo "$DIVIDER"
echo "ESXi Host Health Check Report"
echo "Generated: $(date)"
echo "Hostname:  $(esxcli system hostname get | grep 'Fully Qualified' | awk '{print $NF}')"
echo "$DIVIDER"

# --- System Information ---
echo ""
echo "1. SYSTEM INFORMATION"
echo "$SECTION"
echo "Version:"
esxcli system version get
echo ""
echo "Uptime:"
uptime
echo ""
echo "Maintenance Mode:"
esxcli system maintenanceMode get

# --- Hardware Health (CIM) ---
echo ""
echo "2. HARDWARE HEALTH"
echo "$SECTION"
echo "CPU:"
esxcli hardware cpu global get
echo ""
echo "Memory:"
esxcli hardware memory get
echo ""
echo "Platform:"
esxcli hardware platform get 2>/dev/null || echo "(Platform info not available)"

# --- NTP Status ---
echo ""
echo "3. NTP STATUS"
echo "$SECTION"
esxcli system ntp get 2>/dev/null
if [ $? -ne 0 ]; then
    echo "NTP not configured or not available via esxcli."
    echo "Check with: cat /etc/ntp.conf"
fi

# --- Syslog Configuration ---
echo ""
echo "4. SYSLOG CONFIGURATION"
echo "$SECTION"
esxcli system syslog config get

# --- Network Health ---
echo ""
echo "5. NETWORK - PHYSICAL NICS"
echo "$SECTION"
esxcli network nic list
echo ""
echo "NIC Link Status Check:"
for nic in $(esxcli network nic list | tail -n +3 | awk '{print $1}'); do
    link=$(esxcli network nic get -n "$nic" 2>/dev/null | grep "Link Status" | awk '{print $NF}')
    speed=$(esxcli network nic get -n "$nic" 2>/dev/null | grep "Speed" | awk '{print $NF}')
    driver=$(esxcli network nic get -n "$nic" 2>/dev/null | grep "Driver" | head -1 | awk '{print $NF}')
    echo "  $nic: Link=$link Speed=$speed Driver=$driver"
done

echo ""
echo "6. NETWORK - VMKERNEL INTERFACES"
echo "$SECTION"
esxcli network ip interface list
echo ""
echo "IPv4 Addresses:"
esxcli network ip interface ipv4 get

echo ""
echo "7. NETWORK - VIRTUAL SWITCHES"
echo "$SECTION"
esxcli network vswitch standard list 2>/dev/null
echo ""
echo "Distributed Switches:"
esxcli network vswitch dvs vmware list 2>/dev/null || echo "(No DVS on this host)"

echo ""
echo "8. NETWORK - DNS"
echo "$SECTION"
echo "DNS Servers:"
esxcli network ip dns server list
echo "Search Domains:"
esxcli network ip dns search list

echo ""
echo "9. NETWORK - FIREWALL"
echo "$SECTION"
echo "Enabled Rulesets:"
esxcli network firewall ruleset list | grep true

# --- Storage Health ---
echo ""
echo "10. STORAGE - ADAPTERS"
echo "$SECTION"
esxcli storage core adapter list

echo ""
echo "11. STORAGE - DATASTORES"
echo "$SECTION"
esxcli storage filesystem list | grep -E "^Mount|^----" -v | head -20
echo ""
echo "VMFS Volumes:"
esxcli storage vmfs extent list

echo ""
echo "12. STORAGE - DEVICES"
echo "$SECTION"
echo "Device count: $(esxcli storage core device list | grep -c 'Display Name')"
echo ""
echo "Device Summary:"
esxcli storage core device list | grep -E "Display Name|Status|Is SSD|Size" | head -40

echo ""
echo "13. STORAGE - MULTIPATH POLICY"
echo "$SECTION"
esxcli storage nmp device list | grep -E "Device Display|Storage Array|Path Selection" | head -30

# --- Software ---
echo ""
echo "14. SOFTWARE PROFILE"
echo "$SECTION"
esxcli software profile get 2>/dev/null || echo "(No profile-based install)"
echo ""
echo "VIB Count: $(esxcli software vib list | tail -n +2 | wc -l)"

# --- Running VMs ---
echo ""
echo "15. RUNNING VIRTUAL MACHINES"
echo "$SECTION"
vm_list=$(esxcli vm process list)
if [ -z "$vm_list" ]; then
    echo "No running VMs."
else
    echo "$vm_list"
    echo ""
    vm_count=$(esxcli vm process list | grep -c "Display Name")
    echo "Total running VMs: $vm_count"
fi

# --- Summary ---
echo ""
echo "$DIVIDER"
echo "HEALTH CHECK SUMMARY"
echo "$DIVIDER"

# Check for warnings
warnings=0

# Check NTP
ntp_enabled=$(esxcli system ntp get 2>/dev/null | grep -c "true")
if [ "$ntp_enabled" -eq 0 ]; then
    echo "[WARN] NTP is not enabled"
    warnings=$((warnings + 1))
fi

# Check for down NICs
down_nics=$(esxcli network nic list | tail -n +3 | grep -c "Down")
if [ "$down_nics" -gt 0 ]; then
    echo "[WARN] $down_nics NIC(s) are link-down"
    warnings=$((warnings + 1))
fi

# Check maintenance mode
maint=$(esxcli system maintenanceMode get | grep -c "Enabled")
if [ "$maint" -gt 0 ]; then
    echo "[INFO] Host is in Maintenance Mode"
fi

if [ "$warnings" -eq 0 ]; then
    echo "[OK] No critical warnings detected"
fi

echo ""
echo "Report complete: $(date)"
echo "$DIVIDER"
