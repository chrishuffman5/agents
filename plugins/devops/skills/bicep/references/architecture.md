# Bicep / ARM Architecture

## Compilation Model

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  .bicep file │────▶│  Bicep       │────▶│  ARM JSON    │
│  (DSL)       │     │  Compiler    │     │  template    │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                           ┌──────▼───────┐
                                           │  Azure       │
                                           │  Resource    │
                                           │  Manager     │
                                           │  (deployment │
                                           │   engine)    │
                                           └──────────────┘
```

Bicep is a **transpiler** — it compiles `.bicep` files to ARM JSON templates. The deployment engine is always ARM.

### Bicep vs ARM JSON

| Aspect | Bicep | ARM JSON |
|---|---|---|
| Syntax | Concise DSL | Verbose JSON |
| Type safety | Compile-time validation | Runtime validation |
| Intellisense | Full VS Code support | Limited |
| Modules | Native `module` keyword | Nested deployments (verbose) |
| Comments | `//` and `/* */` | Not supported in JSON |
| String interpolation | `'${var}'` | `[concat()]` or `[format()]` |
| Output | Transpiles to ARM JSON | Direct |

## ARM Deployment Engine

### Deployment Modes

| Mode | Behavior |
|---|---|
| **Incremental** (default) | Add/update resources, leave existing resources untouched |
| **Complete** | Add/update resources, **delete** resources not in template |

**Warning**: Complete mode deletes resources not in the template. Use with extreme caution.

### Deployment Processing

1. **Template validation** — Check syntax, parameter types, resource types
2. **What-if evaluation** — Preview changes (optional, recommended)
3. **Dependency resolution** — Build resource graph from `dependsOn` and implicit references
4. **Parallel provisioning** — Independent resources deployed simultaneously
5. **Resource provider calls** — ARM calls each resource provider's API
6. **State recording** — ARM tracks deployed resources in the resource group

### Deployment Scopes

```
Tenant
  └── Management Group
       └── Subscription
            └── Resource Group
                 └── Resources
```

Each scope has different deployable resource types:
- **Tenant**: Management groups
- **Management Group**: Policies, role assignments, subscriptions
- **Subscription**: Resource groups, policies, role assignments
- **Resource Group**: All Azure resources

## Template Specs and Registry

### Template Specs

Version-controlled ARM templates stored in Azure:

```bash
# Create template spec
az ts create \
  --name my-template \
  --version 1.0 \
  --resource-group templates-rg \
  --template-file main.bicep

# Deploy from template spec
az deployment group create \
  --template-spec "/subscriptions/.../templateSpecs/my-template/versions/1.0"
```

### Bicep Registry (ACR)

Bicep modules published to Azure Container Registry:

```bash
# Publish module
az bicep publish \
  --file modules/storage.bicep \
  --target br:myregistry.azurecr.io/bicep/modules/storage:v1.0

# Consume in Bicep
module storage 'br:myregistry.azurecr.io/bicep/modules/storage:v1.0' = {
  name: 'storageDeployment'
  params: { ... }
}
```

### Azure Verified Modules (AVM)

Microsoft-maintained, tested, and supported Bicep modules:

```bicep
// Public registry module
module storageAccount 'br/public:avm/res/storage/storage-account:0.8.0' = {
  name: 'storageDeployment'
  params: {
    name: 'myappstorage'
    location: location
  }
}
```

## Deployment Stacks

Deployment stacks (GA) provide lifecycle management:

- **Track managed resources** — know exactly what the stack owns
- **Deny settings** — prevent manual modification of managed resources
- **Unmanage behavior** — control what happens to resources removed from the template
- **Cross-scope** — stacks can span resource groups and subscriptions

```bash
az stack group create \
  --name my-stack \
  --resource-group my-rg \
  --template-file main.bicep \
  --deny-settings-mode denyDelete \          # Prevent deletion
  --deny-settings-excluded-principals <id> \ # Exclude specific users
  --action-on-unmanage deleteAll             # Delete removed resources
```
