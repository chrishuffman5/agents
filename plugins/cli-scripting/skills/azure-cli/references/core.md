# Azure CLI Core Reference

Authentication, output formats, JMESPath queries, configuration, extensions, and global flags.

---

## Authentication

### Interactive Login (Browser)
```bash
az login                                    # opens browser
az login --use-device-code                  # headless/SSH — prints code for browser
```

### Service Principal
```bash
# Password-based
az login --service-principal --username "http://my-sp" --password "$SP_PASSWORD" --tenant "$TENANT_ID"

# Certificate-based
az login --service-principal --username "$APP_ID" --certificate /path/to/cert.pem --tenant "$TENANT_ID"
```

### Managed Identity
```bash
az login --identity                          # system-assigned
az login --identity --username "$CLIENT_ID"  # user-assigned
```

### Create Service Principal
```bash
# Contributor on subscription
az ad sp create-for-rbac --name "deploy-sp" --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" --sdk-auth

# Scoped to resource group
az ad sp create-for-rbac --name "rg-sp" --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/my-rg"
```

### Subscription Management
```bash
az account list --output table
az account list --query "[].{Name:name, ID:id, State:state}" --output table
az account set --subscription "My Subscription"
az account set --subscription "$SUBSCRIPTION_ID"
az account show --query "{Sub:id, Tenant:tenantId}" --output json
```

### Token Management
```bash
az account get-access-token                                       # default resource
az account get-access-token --resource https://storage.azure.com
az account get-access-token --query accessToken --output tsv      # raw token
az logout
```

### Config Location
```
~/.azure/           — token cache, config, profile
~/.azure/config     — CLI settings (ini format)
AZURE_CONFIG_DIR    — override config directory
```

---

## Output Formats and JMESPath

### Output Flags
```bash
az vm list --output json      # default — full JSON
az vm list --output jsonc     # colorized JSON
az vm list --output table     # human-readable
az vm list --output tsv       # tab-separated, no headers (scripting)
az vm list --output yaml      # YAML
az vm list --output none      # suppress output (side-effect commands)
```

### JMESPath Basics
```bash
# Single field
az account show --query id --output tsv

# Nested field
az vm show -g my-rg -n my-vm --query "storageProfile.osDisk.diskSizeGb"

# Multi-select hash (rename fields)
az vm list --query "[].{Name:name, RG:resourceGroup, Location:location}" --output table

# Filter array
az vm list --query "[?location=='eastus']" --output table
az vm list --query "[?powerState=='VM running']" --output table

# Filter + project
az vm list --query "[?location=='eastus'].{Name:name, Size:hardwareProfile.vmSize}" --output table

# Count
az vm list --query "length(@)" --output tsv

# First item
az vm list --query "[0].name" --output tsv

# starts_with / contains
az resource list --query "[?starts_with(name,'prod-')].[name,type]" --output table

# sort_by
az vm list --query "sort_by(@, &name)[].{Name:name, Location:location}" --output table

# Flatten nested array
az aks list --query "[].agentPoolProfiles[].{Pool:name, Count:count, VM:vmSize}" --output table

# Combine filter + slice
az vm list --query "[?location=='eastus'][:3].name" --output tsv
```

### Scripting: Capture Values
```bash
RG_ID=$(az group show --name my-rg --query id --output tsv)

VM_IP=$(az vm list-ip-addresses -g my-rg -n my-vm \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)

# TSV for while-read loops
az storage account list --query "[].{Name:name, RG:resourceGroup}" --output tsv
```

---

## Configuration and Extensions

### Set Defaults
```bash
az configure                             # interactive wizard
az config set defaults.location=eastus
az config set defaults.group=my-default-rg
az config set core.output=table
az config set core.only_show_errors=true
az config get
az config unset defaults.group
```

### Environment Variables
```bash
export AZURE_DEFAULTS_GROUP=my-rg
export AZURE_DEFAULTS_LOCATION=eastus
export AZURE_CORE_NO_COLOR=true
export AZURE_CORE_ONLY_SHOW_ERRORS=true
export AZURE_CORE_DISABLE_CONFIRM_PROMPT=true
```

### Extensions
```bash
az extension list --output table
az extension add --name aks-preview
az extension add --name azure-devops
az extension update --name aks-preview
az extension remove --name aks-preview
az extension list-available --query "[?contains(name,'container')]" --output table
```

### Global Flags (All Commands)
```bash
--subscription          # override active subscription
--resource-group / -g   # target resource group
--location / -l         # Azure region
--output / -o           # output format
--query                 # JMESPath query
--verbose               # show HTTP requests
--debug                 # full debug output
--no-wait               # return immediately (async)
--only-show-errors      # suppress warnings
--help / -h             # help text
```
