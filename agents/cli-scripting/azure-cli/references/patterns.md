# Azure CLI Scripting Patterns

Idempotent scripts, batch operations, infrastructure provisioning patterns.

---

## Idempotent Create Patterns

### Check-Before-Create

```bash
# Resource group
if ! az group show --name "$RG" &>/dev/null; then
  echo "Creating resource group: $RG"
  az group create --name "$RG" --location "$LOCATION"
else
  echo "Resource group $RG already exists"
fi

# Storage account
STORAGE_EXISTS=$(az storage account check-name --name "$STORAGE_ACCOUNT" --query "nameAvailable" -o tsv)
if [[ "$STORAGE_EXISTS" == "true" ]]; then
  az storage account create -n "$STORAGE_ACCOUNT" -g "$RG" -l "$LOCATION" --sku Standard_LRS
fi

# Generic resource check
resource_exists() {
  local rg="$1" type="$2" name="$3"
  az resource show -g "$rg" --resource-type "$type" -n "$name" &>/dev/null 2>&1
}

if ! resource_exists "$RG" "Microsoft.Network/virtualNetworks" "$VNET"; then
  az network vnet create -g "$RG" -n "$VNET" --address-prefix 10.0.0.0/16
fi
```

---

## Error Handling

```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Error on line $LINENO"; exit 1' ERR

# Suppress error output for existence checks
if az group show --name "$RG" 2>/dev/null; then
  echo "Group exists"
fi

# Check exit code without set -e stopping
if ! az vm show -g "$RG" -n "$VM" &>/dev/null; then
  echo "VM not found, creating..."
  az vm create -g "$RG" -n "$VM" --image Ubuntu2204 --size Standard_B2s \
    --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub
fi
```

---

## Async Operations (--no-wait)

```bash
# Start multiple VMs in parallel
az vm start -g my-rg -n vm-01 --no-wait
az vm start -g my-rg -n vm-02 --no-wait
az vm start -g my-rg -n vm-03 --no-wait

# Wait for completion
az vm wait -g my-rg -n vm-01 --updated --interval 10 --timeout 600
```

---

## Batch Operations with Loops

```bash
# Loop over TSV output
az vm list -g my-rg --query "[?powerState=='VM running'].{name:name, rg:resourceGroup}" -o tsv | \
while IFS=$'\t' read -r name rg; do
  echo "Stopping VM: $name in $rg"
  az vm deallocate -g "$rg" -n "$name" --no-wait
done

# Delete resources by tag
az resource list --tag env=dev --query "[].id" -o tsv | \
xargs -I {} az resource delete --ids {} --yes

# Parallel with xargs
az storage account list -g my-rg --query "[].name" -o tsv | \
xargs -P 4 -I {} sh -c \
  'az storage account update -n {} -g my-rg --allow-blob-public-access false'

# Parallel with GNU parallel
az vm list -g my-rg --query "[].name" -o tsv | \
  parallel -j 4 az vm restart -g my-rg -n {}

# Delete all stopped VMs
az vm list -g my-rg --show-details --query "[?powerState=='VM deallocated'].id" -o tsv | \
xargs -r az vm delete --ids --yes
```

---

## Cleanup with Trap

```bash
cleanup() {
  echo "Cleaning up resources..."
  az group delete --name "$RG" --yes --no-wait && echo "Deletion initiated for $RG"
}
trap cleanup EXIT SIGINT SIGTERM
```

---

## Complete Provisioning Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

RG="demo-rg"
LOCATION="eastus"
VNET="demo-vnet"
SUBNET="app-subnet"
NSG="app-nsg"
VM_NAME="app-vm-01"
VM_SIZE="Standard_B2s"
ADMIN="azureuser"
SSH_KEY="$HOME/.ssh/id_rsa.pub"
PIP="app-pip"
STORAGE="demostorage$(openssl rand -hex 4)"

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

# 1. Resource Group
if ! az group show -n "$RG" &>/dev/null; then
  log "Creating RG: $RG"
  az group create -n "$RG" -l "$LOCATION" --tags env=demo
else
  log "RG $RG exists"
fi

# 2. VNet + Subnet
if ! az resource show -g "$RG" --resource-type "Microsoft.Network/virtualNetworks" -n "$VNET" &>/dev/null 2>&1; then
  log "Creating VNet: $VNET"
  az network vnet create -g "$RG" -n "$VNET" --address-prefix 10.10.0.0/16 \
    --subnet-name "$SUBNET" --subnet-prefix 10.10.1.0/24
fi

# 3. NSG + Rules
if ! az resource show -g "$RG" --resource-type "Microsoft.Network/networkSecurityGroups" -n "$NSG" &>/dev/null 2>&1; then
  log "Creating NSG: $NSG"
  az network nsg create -g "$RG" -n "$NSG"
  az network nsg rule create -g "$RG" --nsg-name "$NSG" -n AllowSSH --priority 100 \
    --protocol Tcp --direction Inbound --destination-port-ranges 22 --access Allow
  az network nsg rule create -g "$RG" --nsg-name "$NSG" -n AllowHTTP --priority 110 \
    --protocol Tcp --direction Inbound --destination-port-ranges 80 443 --access Allow
  az network vnet subnet update -g "$RG" --vnet-name "$VNET" -n "$SUBNET" --network-security-group "$NSG"
fi

# 4. Public IP
if ! az resource show -g "$RG" --resource-type "Microsoft.Network/publicIPAddresses" -n "$PIP" &>/dev/null 2>&1; then
  log "Creating Public IP"
  az network public-ip create -g "$RG" -n "$PIP" --allocation-method Static --sku Standard
fi

# 5. VM
if ! az resource show -g "$RG" --resource-type "Microsoft.Compute/virtualMachines" -n "$VM_NAME" &>/dev/null 2>&1; then
  log "Creating VM: $VM_NAME"
  az vm create -g "$RG" -n "$VM_NAME" --image Ubuntu2204 --size "$VM_SIZE" \
    --admin-username "$ADMIN" --ssh-key-values "$SSH_KEY" \
    --vnet-name "$VNET" --subnet "$SUBNET" --nsg "$NSG" --public-ip-address "$PIP" \
    --tags env=demo role=app
fi

# 6. Storage
EXISTING_SA=$(az storage account list -g "$RG" --query "[?tags.env=='demo'] | [0].name" -o tsv)
if [[ -z "$EXISTING_SA" ]]; then
  log "Creating storage: $STORAGE"
  az storage account create -n "$STORAGE" -g "$RG" -l "$LOCATION" --sku Standard_LRS \
    --kind StorageV2 --allow-blob-public-access false --tags env=demo
else
  STORAGE="$EXISTING_SA"
fi

# Output
PUBLIC_IP=$(az network public-ip show -g "$RG" -n "$PIP" --query ipAddress -o tsv)
log "======================================="
log "VM Public IP:    $PUBLIC_IP"
log "SSH:             ssh $ADMIN@$PUBLIC_IP"
log "Storage:         $STORAGE"
log "Cleanup:         az group delete -n $RG --yes --no-wait"
log "======================================="
```
