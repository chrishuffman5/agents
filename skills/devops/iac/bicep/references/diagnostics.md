# Bicep / ARM Diagnostics

## Deployment Failures

### Resource Provider Errors

```
{"code":"ResourceGroupNotFound","message":"Resource group 'my-rg' could not be found."}
```

**Resolution:** Create the resource group first or use subscription-scoped deployment.

### API Version Errors

```
No registered resource provider found for location 'eastus' and API version '2025-01-01'
```

**Resolution:** Check available API versions:
```bash
az provider show --namespace Microsoft.Storage --query "resourceTypes[?resourceType=='storageAccounts'].apiVersions" --output table
```

### Quota Exceeded

```
{"code":"QuotaExceeded","message":"Operation could not be completed as it results in exceeding approved Total Regional Cores quota."}
```

**Resolution:**
```bash
az vm list-usage --location eastus --output table
# Request quota increase via Azure Portal
```

## What-If Analysis

```bash
# Preview ALL changes before deploying
az deployment group what-if \
  --resource-group my-rg \
  --template-file main.bicep \
  --parameters @params.json

# Output shows:
# + Create (green)
# ~ Modify (purple) 
# - Delete (red, complete mode only)
# = NoChange (gray)
# * Ignore (properties ARM can't evaluate)
```

## Bicep Compilation Errors

```bash
# Build to see errors
az bicep build --file main.bicep

# Common errors:
# BCP035: Expected value of type 'string' but got 'int'
# BCP036: Expected value of type 'string[]' but got 'string'
# BCP037: Not a valid property for this resource type
# BCP062: Referenced symbol is not defined
```

## ARM to Bicep Migration

```bash
# Decompile ARM JSON to Bicep
az bicep decompile --file template.json

# Export existing resources as ARM JSON
az group export --name my-rg --resource-group my-rg > exported.json

# Decompile exported template
az bicep decompile --file exported.json
```

**Note:** Decompilation is best-effort. Review and refactor the output — it won't be idiomatic Bicep.

## Debugging

```bash
# Verbose deployment output
az deployment group create \
  --resource-group my-rg \
  --template-file main.bicep \
  --debug

# Check deployment operations (find the failing resource)
az deployment operation group list \
  --resource-group my-rg \
  --name deploymentName \
  --query "[?properties.provisioningState=='Failed']"

# View deployment history
az deployment group list --resource-group my-rg --output table
```
