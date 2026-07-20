#!/usr/bin/env bash
# ============================================================================
# Azure VM - Instance Health Dashboard
#
# Purpose : Comprehensive Azure VM health report including instance inventory
#           with power state, disk health, NSG audit, unattached resources,
#           and resource group summary.
# Version : 1.0.0
# Targets : Azure CLI (az) with authenticated session
# Safety  : Read-only. No modifications to Azure resources.
#
# Sections:
#   1. Subscription and Identity
#   2. VM Inventory with Power State
#   3. Managed Disk Health
#   4. Unattached Disks
#   5. NSG Audit
#   6. Public IP Usage
#   7. Resource Group Summary
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# ── Section 1: Subscription and Identity ───────────────────────────────────
section "SECTION 1 - Subscription and Identity"

SUB_NAME=$(az account show --query 'name' -o tsv 2>/dev/null || echo "unknown")
SUB_ID=$(az account show --query 'id' -o tsv 2>/dev/null || echo "unknown")
USER_NAME=$(az account show --query 'user.name' -o tsv 2>/dev/null || echo "unknown")

echo "  Subscription : $SUB_NAME"
echo "  Sub ID       : $SUB_ID"
echo "  Identity     : $USER_NAME"

# ── Section 2: VM Inventory with Power State ───────────────────────────────
section "SECTION 2 - VM Inventory with Power State"

echo "  Name                          | Resource Group       | Size               | Power State"
echo "  ------------------------------|----------------------|--------------------|--------------------"

az vm list --show-details \
  --query "[].{Name:name, RG:resourceGroup, Size:hardwareProfile.vmSize, State:powerState}" \
  -o tsv 2>/dev/null | \
  while IFS=$'\t' read -r name rg size state; do
    printf "  %-31s | %-20s | %-18s | %s\n" "$name" "$rg" "$size" "$state"
  done || echo "  [ERROR] Unable to list VMs"

echo ""
running=$(az vm list --show-details --query "[?powerState=='VM running'] | length(@)" -o tsv 2>/dev/null || echo "0")
deallocated=$(az vm list --show-details --query "[?powerState=='VM deallocated'] | length(@)" -o tsv 2>/dev/null || echo "0")
stopped=$(az vm list --show-details --query "[?powerState=='VM stopped'] | length(@)" -o tsv 2>/dev/null || echo "0")
echo "  Running: $running | Deallocated: $deallocated | Stopped (allocated): $stopped"

if [[ "$stopped" -gt 0 ]]; then
    echo "  [WARN] $stopped VM(s) stopped but still allocated -- compute billing continues"
    echo "         Use 'az vm deallocate' to stop billing"
fi

# ── Section 3: Managed Disk Health ─────────────────────────────────────────
section "SECTION 3 - Managed Disk Health"

az disk list \
  --query "[].{Name:name, RG:resourceGroup, Size:diskSizeGb, SKU:sku.name, State:diskState}" \
  -o tsv 2>/dev/null | \
  while IFS=$'\t' read -r name rg size sku state; do
    printf "  %-30s | %-20s | %5s GB | %-14s | %s\n" "$name" "$rg" "$size" "$sku" "$state"
  done || echo "  [ERROR] Unable to list disks"

# ── Section 4: Unattached Disks ────────────────────────────────────────────
section "SECTION 4 - Unattached Disks (Cost Review)"

unattached=$(az disk list \
  --query "[?diskState=='Unattached'].{Name:name, RG:resourceGroup, Size:diskSizeGb, SKU:sku.name}" \
  -o tsv 2>/dev/null)

if [[ -n "$unattached" ]]; then
    echo "$unattached" | while IFS=$'\t' read -r name rg size sku; do
        printf "  [WARN] %-30s | %-20s | %5s GB | %s\n" "$name" "$rg" "$size" "$sku"
    done
else
    echo "  [OK] No unattached disks found"
fi

# ── Section 5: NSG Audit ──────────────────────────────────────────────────
section "SECTION 5 - NSGs with Open Inbound Rules"

az network nsg list --query "[].{Name:name, RG:resourceGroup}" -o tsv 2>/dev/null | \
  while IFS=$'\t' read -r nsg_name nsg_rg; do
    open_rules=$(az network nsg rule list \
      --resource-group "$nsg_rg" --nsg-name "$nsg_name" \
      --query "[?direction=='Inbound' && access=='Allow' && (sourceAddressPrefix=='*' || sourceAddressPrefix=='0.0.0.0/0' || sourceAddressPrefix=='Internet')].{Name:name, Port:destinationPortRange, Priority:priority}" \
      -o tsv 2>/dev/null)
    if [[ -n "$open_rules" ]]; then
        echo "  [REVIEW] NSG: $nsg_name (RG: $nsg_rg)"
        echo "$open_rules" | while IFS=$'\t' read -r rule_name port priority; do
            echo "           Rule: $rule_name | Port: $port | Priority: $priority"
        done
    fi
  done || echo "  [OK] No NSGs with open inbound rules found"

# ── Section 6: Public IP Usage ─────────────────────────────────────────────
section "SECTION 6 - Public IP Usage"

az network public-ip list \
  --query "[].{Name:name, RG:resourceGroup, IP:ipAddress, Method:publicIpAllocationMethod, Associated:ipConfiguration.id}" \
  -o tsv 2>/dev/null | \
  while IFS=$'\t' read -r name rg ip method assoc; do
    status="associated"
    [[ -z "$assoc" || "$assoc" == "None" ]] && status="UNASSOCIATED"
    printf "  %-25s | %-15s | %-8s | %s\n" "$name" "${ip:-pending}" "$method" "$status"
  done || echo "  [INFO] No public IPs found"

# ── Section 7: Resource Group Summary ──────────────────────────────────────
section "SECTION 7 - Resource Group Summary"

az group list \
  --query "[].{Name:name, Location:location}" \
  -o tsv 2>/dev/null | \
  while IFS=$'\t' read -r name location; do
    count=$(az resource list --resource-group "$name" --query "length(@)" -o tsv 2>/dev/null || echo "?")
    printf "  %-30s | %-15s | %s resources\n" "$name" "$location" "$count"
  done || echo "  [ERROR] Unable to list resource groups"

echo ""
echo "$SEP"
echo "  Azure VM Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
