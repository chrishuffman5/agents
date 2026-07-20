# Azure CLI Commands by Service

Complete command reference with all common flags and real examples.

---

## Resource Groups

```bash
az group create --name my-rg --location eastus --tags env=prod project=myapp
az group list --output table
az group list --query "[?location=='eastus'].name" --output tsv
az group list --query "[?tags.env=='prod'].{Name:name, Location:location}" --output table
az group show --name my-rg
az group show --name my-rg --query id --output tsv
az group exists --name my-rg
az group delete --name my-rg --yes --no-wait

# Tags
az group update --name my-rg --set tags.env=staging tags.version=2
az tag create --resource-id $(az group show -n my-rg --query id -o tsv) --tags env=prod project=myapp
az group update --name my-rg --remove tags.version

# Locks
az lock create --name no-delete -g my-rg --lock-type CanNotDelete --notes "Production"
az lock list -g my-rg --output table
az lock delete --name no-delete -g my-rg
```

---

## Virtual Machines

```bash
# List images
az vm image list --output table
az vm image list --publisher Canonical --offer 0001-com-ubuntu-server-jammy --sku 22_04-lts --all \
  --query "[-1].urn" --output tsv

# Create Linux VM
az vm create -g my-rg -n my-vm --image Ubuntu2204 --size Standard_B2s \
  --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub \
  --vnet-name my-vnet --subnet my-subnet --nsg my-nsg --public-ip-address my-pip --tags env=dev

# Create Windows VM
az vm create -g my-rg -n win-vm --image Win2022Datacenter --size Standard_D2s_v3 \
  --admin-username adminuser --admin-password "$WIN_PASSWORD"

# No public IP
az vm create -g my-rg -n priv-vm --image Ubuntu2204 --size Standard_B2s \
  --admin-username azureuser --ssh-key-values ~/.ssh/id_rsa.pub --public-ip-address ""

# List with power state
az vm list -g my-rg --show-details --query "[].{Name:name, State:powerState, IP:publicIps}" -o table

# Power operations
az vm start -g my-rg -n my-vm
az vm stop -g my-rg -n my-vm
az vm deallocate -g my-rg -n my-vm
az vm restart -g my-rg -n my-vm
az vm deallocate -g my-rg -n my-vm --no-wait

# Resize
az vm resize -g my-rg -n my-vm --size Standard_D4s_v3
az vm list-vm-resize-options -g my-rg -n my-vm --query "[].name" -o tsv

# Delete
az vm delete -g my-rg -n my-vm --yes

# Run command
az vm run-command invoke -g my-rg -n my-vm --command-id RunShellScript \
  --scripts "apt-get update && apt-get install -y nginx"

# Extensions
az vm extension set -g my-rg --vm-name my-vm --name CustomScript \
  --publisher Microsoft.Azure.Extensions \
  --settings '{"fileUris":["https://example.com/setup.sh"],"commandToExecute":"bash setup.sh"}'
az vm extension list -g my-rg --vm-name my-vm --output table
```

---

## Storage

```bash
# Create account
az storage account create -n mystorageacct -g my-rg -l eastus --sku Standard_LRS \
  --kind StorageV2 --access-tier Hot --allow-blob-public-access false --tags env=prod

# List and show
az storage account list -o table
az storage account list -g my-rg --query "[].{Name:name, SKU:sku.name}" -o table

# Keys and connection string
CONN=$(az storage account show-connection-string -n mystorageacct -g my-rg -o tsv)
KEY=$(az storage account keys list --account-name mystorageacct -g my-rg --query "[0].value" -o tsv)

# Containers
az storage container create -n my-container --connection-string "$CONN" --public-access off
az storage container list --connection-string "$CONN" -o table
az storage container delete -n my-container --connection-string "$CONN"

# Blobs
az storage blob upload -c my-container -f ./report.csv -n reports/report.csv --connection-string "$CONN"
az storage blob upload-batch --destination my-container --source ./dist/ --connection-string "$CONN" --overwrite true
az storage blob download -c my-container -n reports/report.csv -f ./local/report.csv --connection-string "$CONN"
az storage blob download-batch --source my-container --destination ./backup/ --connection-string "$CONN"
az storage blob list -c my-container --connection-string "$CONN" --query "[].{Name:name, Size:properties.contentLength}" -o table
az storage blob list -c my-container --prefix "reports/2026/" --connection-string "$CONN" -o table
az storage blob delete -c my-container -n reports/old.csv --connection-string "$CONN"
az storage blob delete-batch --source my-container --pattern "temp/*" --connection-string "$CONN"

# SAS tokens
END=$(date -u -d "1 day" +%Y-%m-%dT%H:%MZ 2>/dev/null || date -u -v+1d +%Y-%m-%dT%H:%MZ)
az storage account generate-sas --account-name mystorageacct --services b --resource-types sco \
  --permissions rlw --expiry "$END" -o tsv
az storage blob generate-sas --account-name mystorageacct -c my-container -n report.csv \
  --permissions r --expiry "$END" --full-uri -o tsv
```

---

## Networking

```bash
# VNet and subnet
az network vnet create -g my-rg -n my-vnet --address-prefix 10.0.0.0/16 -l eastus
az network vnet subnet create -g my-rg --vnet-name my-vnet -n web-subnet --address-prefix 10.0.1.0/24
az network vnet subnet create -g my-rg --vnet-name my-vnet -n db-subnet --address-prefix 10.0.2.0/24
az network vnet list -o table
az network vnet subnet list -g my-rg --vnet-name my-vnet -o table

# NSG
az network nsg create -g my-rg -n web-nsg -l eastus
az network nsg rule create -g my-rg --nsg-name web-nsg -n AllowHTTP \
  --priority 100 --protocol Tcp --direction Inbound --destination-port-ranges 80 --access Allow
az network nsg rule create -g my-rg --nsg-name web-nsg -n AllowHTTPS \
  --priority 110 --protocol Tcp --direction Inbound --destination-port-ranges 443 --access Allow
az network nsg rule create -g my-rg --nsg-name web-nsg -n AllowSSH \
  --priority 200 --protocol Tcp --direction Inbound --source-address-prefixes 10.0.0.0/8 --destination-port-ranges 22 --access Allow
az network nsg rule list -g my-rg --nsg-name web-nsg -o table
az network vnet subnet update -g my-rg --vnet-name my-vnet -n web-subnet --network-security-group web-nsg

# Public IP
az network public-ip create -g my-rg -n my-pip --allocation-method Static --sku Standard -l eastus
az network public-ip show -g my-rg -n my-pip --query ipAddress -o tsv
az network public-ip list -g my-rg -o table

# Load balancer
az network lb create -g my-rg -n my-lb --sku Standard --public-ip-address my-pip \
  --frontend-ip-name web-fe --backend-pool-name web-be
az network lb probe create -g my-rg --lb-name my-lb -n http-probe --protocol Http --port 80 --path /health
az network lb rule create -g my-rg --lb-name my-lb -n http-rule --protocol Tcp --frontend-port 80 --backend-port 80 \
  --frontend-ip-name web-fe --backend-pool-name web-be --probe-name http-probe

# DNS
az network dns zone create -g my-rg -n mycompany.com
az network dns record-set a create -g my-rg --zone-name mycompany.com -n www --ttl 300
az network dns record-set a add-record -g my-rg --zone-name mycompany.com --record-set-name www --ipv4-address 1.2.3.4
az network dns record-set cname set-record -g my-rg --zone-name mycompany.com --record-set-name api --cname myapp.azurewebsites.net --ttl 300
az network dns record-set list -g my-rg --zone-name mycompany.com -o table
```

---

## Identity (Entra ID)

```bash
# Users
az ad user list --query "[].{Name:displayName, UPN:userPrincipalName}" -o table
az ad user show --id user@example.com
az ad user create --display-name "Jane Doe" --user-principal-name jane@example.com --password "Temp@12345!" --force-change-password-next-sign-in true

# Groups
az ad group list -o table
az ad group create --display-name "DevOps Team" --mail-nickname "devops-team"
az ad group member add --group "DevOps Team" --member-id $(az ad user show --id jane@example.com --query id -o tsv)
az ad group member list --group "DevOps Team" -o table

# App registrations
az ad app create --display-name "My API App" --sign-in-audience AzureADMyOrg
az ad app list --query "[].{Name:displayName, AppId:appId}" -o table

# Role assignments
az role definition list --name "Contributor"
az role assignment create --assignee user@example.com --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/my-rg"
az role assignment create --assignee "$SP_APP_ID" --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/my-rg/providers/Microsoft.Storage/storageAccounts/mystorageacct"
az role assignment list --assignee user@example.com -o table
az role assignment list -g my-rg --query "[].{Principal:principalName, Role:roleDefinitionName}" -o table
```

---

## AKS

```bash
# Create
az aks create -g my-rg -n my-aks --node-count 3 --node-vm-size Standard_D2s_v3 --kubernetes-version 1.29 \
  --enable-managed-identity --generate-ssh-keys --network-plugin azure --enable-cluster-autoscaler \
  --min-count 2 --max-count 10 --tags env=prod

# Credentials
az aks get-credentials -g my-rg -n my-aks --overwrite-existing

# List and show
az aks list --query "[].{Name:name, K8s:kubernetesVersion, State:provisioningState}" -o table
az aks show -g my-rg -n my-aks --query "{Version:kubernetesVersion, FQDN:fqdn}"

# Scale
az aks scale -g my-rg -n my-aks --node-count 5 --nodepool-name nodepool1
az aks update -g my-rg -n my-aks --enable-cluster-autoscaler --min-count 2 --max-count 20

# Upgrade
az aks get-upgrades -g my-rg -n my-aks -o table
az aks upgrade -g my-rg -n my-aks --kubernetes-version 1.30 --yes

# Node pools
az aks nodepool add -g my-rg --cluster-name my-aks -n gpupool --node-count 2 --node-vm-size Standard_NC6 \
  --node-taints sku=gpu:NoSchedule --labels workload=gpu
az aks nodepool list -g my-rg --cluster-name my-aks -o table
az aks nodepool scale -g my-rg --cluster-name my-aks -n gpupool --node-count 4
az aks nodepool delete -g my-rg --cluster-name my-aks -n gpupool --yes

# Delete
az aks delete -g my-rg -n my-aks --yes --no-wait
```

---

## App Service and Functions

```bash
# Plan
az appservice plan create -n my-plan -g my-rg --sku B2 --is-linux -l eastus
az appservice plan list -g my-rg -o table

# Web app
az webapp create -n my-webapp -g my-rg --plan my-plan --runtime "NODE:20-lts"
az webapp list -g my-rg -o table
az webapp show -n my-webapp -g my-rg --query "{URL:defaultHostName, State:state}"

# Deploy
az webapp deploy -n my-webapp -g my-rg --src-path ./dist/app.zip --type zip

# Settings
az webapp config appsettings set -n my-webapp -g my-rg --settings NODE_ENV=production API_KEY="$API_KEY"
az webapp config appsettings list -n my-webapp -g my-rg -o table

# Slots
az webapp deployment slot create -n my-webapp -g my-rg --slot staging
az webapp deploy -n my-webapp -g my-rg --slot staging --src-path ./dist/app.zip --type zip
az webapp deployment slot swap -n my-webapp -g my-rg --slot staging --target-slot production

# Function app
az functionapp create -n my-func -g my-rg --storage-account mystorageacct --consumption-plan-location eastus \
  --runtime node --runtime-version 20 --functions-version 4 --os-type Linux
az functionapp deployment source config-zip -n my-func -g my-rg --src ./func.zip
az functionapp config appsettings set -n my-func -g my-rg --settings CUSTOM=value
```

---

## Databases

```bash
# Azure SQL
az sql server create -n my-sql -g my-rg -l eastus --admin-user sqladmin --admin-password "$SQL_PASS"
az sql server firewall-rule create -g my-rg --server my-sql -n AllowAzure --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql db create -g my-rg --server my-sql -n mydb --edition GeneralPurpose --family Gen5 --capacity 2 --max-size 32GB
az sql db list -g my-rg --server my-sql -o table
az sql db show-connection-string -n mydb --server my-sql --client ado.net

# Cosmos DB
az cosmosdb create -n my-cosmos -g my-rg --locations regionName=eastus --default-consistency-level Session
az cosmosdb sql database create --account-name my-cosmos -g my-rg -n mydb --throughput 400
az cosmosdb sql container create --account-name my-cosmos -g my-rg --database-name mydb -n items --partition-key-path /id
az cosmosdb keys list -n my-cosmos -g my-rg --type connection-strings --query "connectionStrings[0].connectionString" -o tsv

# PostgreSQL Flexible Server
az postgres flexible-server create -g my-rg -n my-pg -l eastus --admin-user pgadmin --admin-password "$DB_PASS" \
  --sku-name Standard_D2ds_v4 --tier GeneralPurpose --storage-size 128 --version 16
az postgres flexible-server db create -g my-rg --server-name my-pg --database-name myapp_db

# MySQL Flexible Server
az mysql flexible-server create -g my-rg -n my-mysql -l eastus --admin-user myadmin --admin-password "$DB_PASS" \
  --sku-name Standard_D2ds_v4 --storage-size 64 --version 8.0
```

---

## Key Vault

```bash
az keyvault create -n my-kv -g my-rg -l eastus --sku standard --enable-rbac-authorization true

# Secrets
az keyvault secret set --vault-name my-kv -n db-password --value "$DB_PASS"
az keyvault secret set --vault-name my-kv -n api-key --file ./secrets/api_key.txt
az keyvault secret show --vault-name my-kv -n db-password --query value -o tsv
az keyvault secret list --vault-name my-kv -o table
az keyvault secret delete --vault-name my-kv -n db-password
az keyvault secret recover --vault-name my-kv -n db-password

# Keys
az keyvault key create --vault-name my-kv -n my-key --kty RSA --size 4096 --ops encrypt decrypt wrapKey unwrapKey
az keyvault key list --vault-name my-kv -o table

# Certificates
az keyvault certificate create --vault-name my-kv -n my-cert --policy "$(az keyvault certificate get-default-policy)"
az keyvault certificate import --vault-name my-kv -n my-cert --file ./cert.pfx --password "$CERT_PASS"

# RBAC access
az role assignment create --assignee "$PRINCIPAL_ID" --role "Key Vault Secrets User" \
  --scope "$(az keyvault show -n my-kv -g my-rg --query id -o tsv)"
```

---

## Monitor and Alerting

```bash
# Metrics
az monitor metrics list --resource "$VM_RESOURCE_ID" --metric "Percentage CPU" \
  --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%MZ)" --end-time "$(date -u +%Y-%m-%dT%H:%MZ)" \
  --interval PT5M -o table

# Log Analytics
az monitor log-analytics workspace create -g my-rg -n my-workspace -l eastus --sku PerGB2018
az monitor log-analytics query --workspace "$WORKSPACE_ID" \
  --analytics-query "Heartbeat | summarize LastHeartbeat=max(TimeGenerated) by Computer | take 10" -o table

# Alerts
az monitor metrics alert create -n "High CPU" -g my-rg --scopes "$VM_RESOURCE_ID" \
  --condition "avg Percentage CPU > 80" --window-size 5m --evaluation-frequency 1m --severity 2
az monitor metrics alert list -g my-rg -o table

# Action groups
az monitor action-group create -g my-rg -n ops-email --short-name ops --action email ops ops@example.com

# Diagnostics
az monitor diagnostic-settings create --resource "$VM_RESOURCE_ID" -n vm-diag \
  --workspace "$WORKSPACE_RESOURCE_ID" --metrics '[{"category":"AllMetrics","enabled":true}]'
```
