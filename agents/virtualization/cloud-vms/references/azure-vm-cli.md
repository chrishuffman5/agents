# Azure VM CLI Reference

Complete `az vm` CLI reference for instance lifecycle, images, disks, networking, monitoring, and Run Command.

---

## Instance Lifecycle

### Create VM

```bash
# Linux VM
az vm create \
  --resource-group myRG \
  --name myVM \
  --image Ubuntu2204 \
  --size Standard_D4s_v5 \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --vnet-name myVNet \
  --subnet mySubnet \
  --nsg myNSG \
  --public-ip-sku Standard \
  --os-disk-size-gb 128 \
  --os-disk-caching ReadWrite \
  --storage-sku Premium_LRS \
  --zone 1 \
  --custom-data @cloud-init.yaml \
  --tags env=production app=webserver team=infra \
  --output table

# Windows VM
az vm create \
  --resource-group myRG \
  --name myWinVM \
  --image Win2022Datacenter \
  --size Standard_D4s_v5 \
  --admin-username winadmin \
  --admin-password 'SecureP@ssw0rd!' \
  --nsg-rule RDP \
  --output json
```

### List VMs

```bash
# All VMs in subscription
az vm list --output table

# VMs in a resource group
az vm list --resource-group myRG --output table

# With power state and size
az vm list \
  --resource-group myRG \
  --show-details \
  --query "[].{Name:name, Location:location, State:powerState, Size:hardwareProfile.vmSize}" \
  --output table

# Filter by tag
az vm list \
  --query "[?tags.env=='production'].{Name:name, RG:resourceGroup}" \
  --output table
```

### Start / Stop / Deallocate / Restart / Delete

```bash
# Start a stopped/deallocated VM
az vm start --resource-group myRG --name myVM

# Stop (OS shutdown -- VM still allocated, billing continues)
az vm stop --resource-group myRG --name myVM

# Deallocate (release compute -- billing stops for compute)
az vm deallocate --resource-group myRG --name myVM

# Restart
az vm restart --resource-group myRG --name myVM

# Delete VM (does NOT delete disks/NICs by default)
az vm delete --resource-group myRG --name myVM --yes

# Delete VM and all associated resources
az vm delete --resource-group myRG --name myVM --yes
az network nic delete --resource-group myRG --name myVMNic
az network public-ip delete --resource-group myRG --name myVMPublicIP
az disk delete --resource-group myRG --name myVM_OsDisk --yes

# Bulk deallocate all VMs in resource group
az vm deallocate --ids $(az vm list --resource-group myRG --query "[].id" -o tsv)
```

**Important**: `az vm stop` halts the OS but keeps the VM allocated -- compute billing continues. Always use `az vm deallocate` to stop compute billing.

### Resize VM

```bash
# Check available sizes
az vm list-vm-resize-options \
  --resource-group myRG \
  --name myVM \
  --output table

# Resize (may require deallocation for cross-family resize)
az vm resize \
  --resource-group myRG \
  --name myVM \
  --size Standard_E8s_v5

# Resize with explicit deallocate
az vm deallocate --resource-group myRG --name myVM
az vm resize --resource-group myRG --name myVM --size Standard_F8s_v2
az vm start --resource-group myRG --name myVM
```

### Show VM Details

```bash
az vm show \
  --resource-group myRG \
  --name myVM \
  --output json

# Specific fields
az vm show \
  --resource-group myRG \
  --name myVM \
  --query "{Name:name, Size:hardwareProfile.vmSize, OS:storageProfile.imageReference.offer, Disks:storageProfile.dataDisks[].name}" \
  --output json
```

---

## Images

### Marketplace Images

```bash
# Common images (cached list)
az vm image list --output table

# Search by publisher
az vm image list-publishers --location eastus --output table | grep -i canonical

# List offers and SKUs
az vm image list-offers --location eastus --publisher Canonical --output table
az vm image list-skus --location eastus --publisher Canonical \
  --offer 0001-com-ubuntu-server-jammy --output table
```

### Custom Images

```bash
# Generalize VM (run waagent -deprovision inside Linux first)
az vm generalize --resource-group myRG --name mySourceVM

# Create image
az image create \
  --resource-group myRG \
  --name myCustomImage \
  --source mySourceVM \
  --os-type Linux \
  --location eastus

# Launch from custom image
az vm create \
  --resource-group myRG \
  --name myVMFromImage \
  --image myCustomImage \
  --size Standard_D4s_v5 \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/id_rsa.pub
```

### Azure Compute Gallery (Shared Image Gallery)

```bash
# Create gallery and image definition
az sig create --resource-group myRG --gallery-name myGallery --location eastus

az sig image-definition create \
  --resource-group myRG \
  --gallery-name myGallery \
  --gallery-image-definition myImageDef \
  --publisher myOrg --offer myApp --sku 1.0 \
  --os-type Linux --os-state Generalized

# Create image version with multi-region replication
az sig image-version create \
  --resource-group myRG \
  --gallery-name myGallery \
  --gallery-image-definition myImageDef \
  --gallery-image-version 1.0.0 \
  --managed-image /subscriptions/<sub>/resourceGroups/myRG/providers/Microsoft.Compute/images/myCustomImage \
  --target-regions eastus=2 westus=1
```

---

## Disks

### Create and Manage

```bash
# Create managed disk
az disk create \
  --resource-group myRG \
  --name myDataDisk \
  --size-gb 512 \
  --sku Premium_LRS \
  --zone 1 \
  --location eastus

# List disks
az disk list --resource-group myRG --output table

# Resize (no downtime for data disks)
az disk update --resource-group myRG --name myDataDisk --size-gb 1024

# Change SKU
az disk update --resource-group myRG --name myDataDisk --sku UltraSSD_LRS
```

### Attach and Detach

```bash
# Attach existing disk
az vm disk attach \
  --resource-group myRG \
  --vm-name myVM \
  --name myDataDisk \
  --caching None

# Create and attach new disk in one command
az vm disk attach \
  --resource-group myRG \
  --vm-name myVM \
  --name myNewDisk \
  --new --size-gb 256 --sku Premium_LRS

# Detach
az vm disk detach --resource-group myRG --vm-name myVM --name myDataDisk
```

### Snapshots

```bash
# Get OS disk ID
DISK_ID=$(az vm show --resource-group myRG --name myVM \
  --query "storageProfile.osDisk.managedDisk.id" -o tsv)

# Create snapshot
az snapshot create \
  --resource-group myRG \
  --name mySnapshot-$(date +%Y%m%d) \
  --source "$DISK_ID" \
  --location eastus \
  --sku Standard_LRS

# Create disk from snapshot
az disk create \
  --resource-group myRG \
  --name myRestoredDisk \
  --source mySnapshot-20240101 \
  --sku Premium_LRS
```

---

## Networking

### VNet and Subnet

```bash
az network vnet create \
  --resource-group myRG --name myVNet \
  --address-prefix 10.0.0.0/16 --location eastus

az network subnet create \
  --resource-group myRG --vnet-name myVNet \
  --name mySubnet --address-prefix 10.0.1.0/24
```

### NSG and Rules

```bash
az network nsg create --resource-group myRG --name myNSG --location eastus

az network nsg rule create \
  --resource-group myRG --nsg-name myNSG \
  --name AllowSSH --priority 1000 \
  --protocol Tcp --direction Inbound \
  --source-address-prefixes '*' --source-port-ranges '*' \
  --destination-port-ranges 22 --access Allow

az network nsg rule create \
  --resource-group myRG --nsg-name myNSG \
  --name AllowHTTPS --priority 1010 \
  --protocol Tcp --direction Inbound \
  --source-address-prefixes '*' --source-port-ranges '*' \
  --destination-port-ranges 443 --access Allow
```

### Public IP and NIC

```bash
az network public-ip create \
  --resource-group myRG --name myPublicIP \
  --sku Standard --allocation-method Static --zone 1

az network nic create \
  --resource-group myRG --name myNIC \
  --vnet-name myVNet --subnet mySubnet \
  --network-security-group myNSG \
  --public-ip-address myPublicIP
```

---

## Monitoring

### Instance View

```bash
az vm get-instance-view \
  --resource-group myRG --name myVM \
  --query "{PowerState:instanceView.statuses[1].displayStatus, ProvisioningState:provisioningState}" \
  --output table
```

### Metrics

```bash
az monitor metrics list \
  --resource /subscriptions/<sub>/resourceGroups/myRG/providers/Microsoft.Compute/virtualMachines/myVM \
  --metric "Percentage CPU" \
  --interval PT1M \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%MZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%MZ) \
  --output table
```

Common metrics: `Percentage CPU`, `Network In Total`, `Network Out Total`, `Disk Read Bytes`, `Disk Write Bytes`, `Disk Read Operations/Sec`.

### Boot Diagnostics

```bash
az vm boot-diagnostics get-boot-log --resource-group myRG --name myVM
az vm boot-diagnostics get-boot-log-uris --resource-group myRG --name myVM --output json
az serial-console connect --resource-group myRG --name myVM
```

---

## Run Command (Remote Script Execution)

```bash
# Run shell script on Linux VM (no SSH needed)
az vm run-command invoke \
  --resource-group myRG --name myVM \
  --command-id RunShellScript \
  --scripts "apt-get update && apt-get install -y nginx"

# Run inline commands
az vm run-command invoke \
  --resource-group myRG --name myVM \
  --command-id RunShellScript \
  --scripts "echo 'Hello' >> /tmp/output.txt && cat /tmp/output.txt"

# Run PowerShell on Windows VM
az vm run-command invoke \
  --resource-group myRG --name myWinVM \
  --command-id RunPowerShellScript \
  --scripts "Get-Service | Where-Object {$_.Status -eq 'Running'}"

# List available run commands
az vm run-command list --location eastus --output table
```
