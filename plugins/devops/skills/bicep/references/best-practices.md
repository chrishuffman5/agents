# Bicep Best Practices

## Module Design

### Use AVM (Azure Verified Modules)

Before writing a module from scratch, check AVM:
```bicep
// Use published, tested modules
module vnet 'br/public:avm/res/network/virtual-network:0.5.0' = {
  name: 'vnetDeployment'
  params: { ... }
}
```

### Custom Module Structure

```
infrastructure/
├── main.bicep                   # Entry point
├── main.bicepparam              # Parameter file
├── modules/
│   ├── networking/
│   │   ├── vnet.bicep
│   │   └── nsg.bicep
│   ├── compute/
│   │   ├── vm.bicep
│   │   └── appservice.bicep
│   └── data/
│       ├── sql.bicep
│       └── storage.bicep
└── bicepconfig.json             # Linter configuration
```

### Parameter Validation

```bicep
@minLength(3)
@maxLength(24)
@description('Storage account name (3-24 chars, lowercase and numbers only)')
param storageAccountName string

@minValue(1)
@maxValue(10)
param instanceCount int = 2

@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS'])
param storageSku string = 'Standard_LRS'

@secure()
@description('SQL admin password')
param sqlPassword string
```

## Naming Conventions

```bicep
// Use descriptive symbolic names (not deployed names)
resource webAppPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${prefix}-plan'    // Deployed name follows org convention
  // ...
}

// Reference by symbolic name
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${prefix}-web'
  properties: {
    serverFarmId: webAppPlan.id    // Clean reference
  }
}
```

## Linting

```json
// bicepconfig.json
{
  "analyzers": {
    "core": {
      "rules": {
        "no-unused-params": { "level": "warning" },
        "no-unused-vars": { "level": "warning" },
        "prefer-interpolation": { "level": "warning" },
        "secure-parameter-default": { "level": "error" },
        "use-recent-api-versions": { "level": "warning" }
      }
    }
  }
}
```

## CI/CD Integration

```yaml
# GitHub Actions
- name: Validate Bicep
  run: az bicep build --file main.bicep

- name: What-If
  run: |
    az deployment group what-if \
      --resource-group ${{ env.RG_NAME }} \
      --template-file main.bicep \
      --parameters environment=production

- name: Deploy
  if: github.ref == 'refs/heads/main'
  run: |
    az deployment group create \
      --resource-group ${{ env.RG_NAME }} \
      --template-file main.bicep \
      --parameters environment=production
```

## Common Mistakes

1. **Not using what-if** — Always preview changes before deploying to production
2. **Complete mode without understanding** — Complete mode deletes resources not in the template
3. **Hardcoded API versions** — Use `use-recent-api-versions` linter rule
4. **No `@secure()` on passwords** — Sensitive parameters must be marked `@secure()`
5. **Monolithic templates** — Break into modules by resource group and lifecycle
