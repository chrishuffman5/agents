#!/usr/bin/env bash
# ============================================================================
# Azure CLI - Complete Environment Provisioning
#
# Purpose : Idempotent provisioning of Resource Group, VNet, NSG, VM,
#           Storage Account with full networking and security setup.
# Version : 1.0.0
# Targets : Azure CLI 2.x
# Safety  : Idempotent. Check-before-create for all resources.
#
# Usage:
#   ./01-azure-provision.sh                # provision environment
#   ./01-azure-provision.sh --cleanup      # delete everything
#
# Requirements:
#   - az CLI logged in (az login)
#   - SSH key at ~/.ssh/id_rsa.pub
#
# Sections:
#   1. Resource Group
#   2. VNet and Subnet
#   3. NSG and Rules
#   4. Public IP
#   5. Virtual Machine
#   6. Storage Account
#   7. Output Summary
# ============================================================================
set -euo pipefail

# -- Configuration -----------------------------------------------------------
RG="demo-rg"
LOCATION="eastus"
VNET="demo-vnet"
VNET_PREFIX="10.10.0.0/16"
SUBNET="app-subnet"
SUBNET_PREFIX="10.10.1.0/24"
NSG="app-nsg"
VM_NAME="app-vm-01"
VM_SIZE="Standard_B2s"
VM_IMAGE="Ubuntu2204"
ADMIN_USER="azureuser"
SSH_KEY="$HOME/.ssh/id_rsa.pub"
STORAGE_ACCOUNT="demostorage$(openssl rand -hex 4)"
PIP_NAME="app-pip"
# ----------------------------------------------------------------------------

log()     { echo "[$(date -u +%H:%M:%S)] $*"; }
res_ok()  { az resource show -g "$RG" --resource-type "$1" -n "$2" &>/dev/null 2>&1; }

cleanup() {
  log "Cleanup: deleting resource group $RG..."
  az group delete --name "$RG" --yes --no-wait
  log "Deletion initiated (async). Monitor: az group show -n $RG"
}

if [[ "${1:-}" == "--cleanup" ]]; then
  cleanup
  exit 0
fi

# -- Section 1: Resource Group -----------------------------------------------
if ! az group show --name "$RG" &>/dev/null; then
  log "Creating resource group: $RG in $LOCATION"
  az group create --name "$RG" --location "$LOCATION" \
    --tags env=demo provisioned-by=az-script
else
  log "Resource group $RG already exists -- skipping"
fi

# -- Section 2: VNet and Subnet ----------------------------------------------
if ! res_ok "Microsoft.Network/virtualNetworks" "$VNET"; then
  log "Creating VNet: $VNET ($VNET_PREFIX)"
  az network vnet create \
    --resource-group "$RG" \
    --name "$VNET" \
    --address-prefix "$VNET_PREFIX" \
    --subnet-name "$SUBNET" \
    --subnet-prefix "$SUBNET_PREFIX"
else
  log "VNet $VNET already exists -- skipping"
fi

# -- Section 3: NSG and Rules ------------------------------------------------
if ! res_ok "Microsoft.Network/networkSecurityGroups" "$NSG"; then
  log "Creating NSG: $NSG"
  az network nsg create --resource-group "$RG" --name "$NSG"

  log "Adding NSG rules"
  az network nsg rule create \
    --resource-group "$RG" --nsg-name "$NSG" \
    --name AllowSSH --priority 100 \
    --protocol Tcp --direction Inbound \
    --source-address-prefixes '*' \
    --destination-port-ranges 22 --access Allow

  az network nsg rule create \
    --resource-group "$RG" --nsg-name "$NSG" \
    --name AllowHTTP --priority 110 \
    --protocol Tcp --direction Inbound \
    --source-address-prefixes '*' \
    --destination-port-ranges 80 443 --access Allow

  az network vnet subnet update \
    --resource-group "$RG" --vnet-name "$VNET" --name "$SUBNET" \
    --network-security-group "$NSG"
else
  log "NSG $NSG already exists -- skipping"
fi

# -- Section 4: Public IP ----------------------------------------------------
if ! res_ok "Microsoft.Network/publicIPAddresses" "$PIP_NAME"; then
  log "Creating Public IP: $PIP_NAME"
  az network public-ip create \
    --resource-group "$RG" --name "$PIP_NAME" \
    --allocation-method Static --sku Standard
fi

# -- Section 5: Virtual Machine -----------------------------------------------
if ! res_ok "Microsoft.Compute/virtualMachines" "$VM_NAME"; then
  log "Creating VM: $VM_NAME ($VM_SIZE)"
  az vm create \
    --resource-group "$RG" \
    --name "$VM_NAME" \
    --image "$VM_IMAGE" \
    --size "$VM_SIZE" \
    --admin-username "$ADMIN_USER" \
    --ssh-key-values "$SSH_KEY" \
    --vnet-name "$VNET" \
    --subnet "$SUBNET" \
    --nsg "$NSG" \
    --public-ip-address "$PIP_NAME" \
    --tags env=demo role=app
else
  log "VM $VM_NAME already exists -- skipping"
fi

# -- Section 6: Storage Account -----------------------------------------------
EXISTING_SA=$(az storage account list \
  --resource-group "$RG" \
  --query "[?tags.env=='demo'] | [0].name" \
  --output tsv)

if [[ -z "$EXISTING_SA" ]]; then
  log "Creating storage account: $STORAGE_ACCOUNT"
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RG" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access false \
    --tags env=demo
else
  STORAGE_ACCOUNT="$EXISTING_SA"
  log "Storage account $STORAGE_ACCOUNT already exists -- skipping"
fi

# -- Section 7: Output Summary ------------------------------------------------
PUBLIC_IP=$(az network public-ip show \
  --resource-group "$RG" --name "$PIP_NAME" \
  --query ipAddress --output tsv)

SA_CONN=$(az storage account show-connection-string \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG" \
  --output tsv)

log "=========================================="
log "Provisioning complete!"
log "  Resource Group:   $RG"
log "  VM Public IP:     $PUBLIC_IP"
log "  SSH:              ssh $ADMIN_USER@$PUBLIC_IP"
log "  Storage Account:  $STORAGE_ACCOUNT"
log "  Cleanup:          $0 --cleanup"
log "=========================================="
