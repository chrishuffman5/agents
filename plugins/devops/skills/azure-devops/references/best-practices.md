# Azure DevOps Best Practices

## YAML Pipeline Design

### Use Templates for Reuse

```yaml
# templates/dotnet-build.yml
parameters:
  - name: project
    type: string
  - name: configuration
    type: string
    default: 'Release'

steps:
  - task: DotNetCoreCLI@2
    displayName: 'Restore'
    inputs:
      command: restore
      projects: '${{ parameters.project }}'
  - task: DotNetCoreCLI@2
    displayName: 'Build'
    inputs:
      command: build
      projects: '${{ parameters.project }}'
      arguments: '--configuration ${{ parameters.configuration }}'
  - task: DotNetCoreCLI@2
    displayName: 'Test'
    inputs:
      command: test
      projects: '${{ parameters.project }}'
      arguments: '--configuration ${{ parameters.configuration }} --collect:"XPlat Code Coverage"'
```

### Use extends for Organizational Standards

```yaml
# org-templates/standard-pipeline.yml
parameters:
  - name: buildSteps
    type: stepList
    default: []
  - name: testSteps
    type: stepList
    default: []

stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - checkout: self
          - ${{ parameters.buildSteps }}
  - stage: SecurityScan
    jobs:
      - job: Scan
        steps:
          - task: CredScan@3    # Required security scan
          - task: SdtReport@2

# Consumer pipeline
extends:
  template: standard-pipeline.yml@org-templates
  parameters:
    buildSteps:
      - script: npm run build
```

### Migrate from Classic to YAML

| Classic Feature | YAML Equivalent |
|---|---|
| Build definition | `azure-pipelines.yml` |
| Release definition | Multi-stage YAML with `deployment` jobs |
| Task groups | Template files |
| Variable groups | `variables: - group:` reference |
| Artifacts | `publish` / `download` keywords |
| Approval gates | Environment approvals and checks |
| Agent phases | Jobs with `pool:` |

## Security

### Service Connection Security

1. **Use workload identity federation** (OIDC) for Azure — no secrets to rotate
2. **Restrict service connection access** — per-pipeline approval, not blanket access
3. **Separate connections per environment** — dev, staging, prod each get their own
4. **Audit regularly** — Settings > Service connections > check usage

### Variable Security

```yaml
# Use variable groups linked to Azure Key Vault
variables:
  - group: prod-keyvault-vars    # Linked to Key Vault, auto-refreshed

# Mark inline variables as secret
variables:
  - name: mySecret
    value: $(secret-from-ui)    # Defined as secret in pipeline UI
```

### Pipeline Permissions

- **Project-level**: Which users can create/edit/run pipelines
- **Pipeline-level**: Which resources (service connections, variable groups, environments) the pipeline can access
- **Branch control**: Restrict which branches can access protected resources
- **Required templates**: Force all pipelines to extend from approved templates

## Performance

### Caching

```yaml
variables:
  NUGET_PACKAGES: $(Pipeline.Workspace)/.nuget/packages

steps:
  - task: Cache@2
    inputs:
      key: 'nuget | "$(Agent.OS)" | **/packages.lock.json'
      restoreKeys: |
        nuget | "$(Agent.OS)"
      path: $(NUGET_PACKAGES)
    displayName: 'Cache NuGet packages'
```

### Parallel Jobs

```yaml
# Matrix strategy
strategy:
  matrix:
    linux:
      imageName: 'ubuntu-latest'
    windows:
      imageName: 'windows-latest'
  maxParallel: 2

pool:
  vmImage: $(imageName)
```

### Conditional Stage Execution

```yaml
stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - script: npm run build

  - stage: Deploy
    dependsOn: Build
    condition: |
      and(
        succeeded(),
        eq(variables['Build.SourceBranch'], 'refs/heads/main'),
        ne(variables['Build.Reason'], 'PullRequest')
      )
```

## Multi-Stage Deployment

### Environment Promotion Pattern

```yaml
stages:
  - stage: Build
    jobs:
      - job: Build
        steps:
          - script: npm run build
          - publish: dist
            artifact: app

  - stage: DeployDev
    dependsOn: Build
    jobs:
      - deployment: Deploy
        environment: dev
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app
                - script: ./deploy.sh dev

  - stage: DeployStaging
    dependsOn: DeployDev
    jobs:
      - deployment: Deploy
        environment: staging    # May have approval gates
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app
                - script: ./deploy.sh staging

  - stage: DeployProd
    dependsOn: DeployStaging
    jobs:
      - deployment: Deploy
        environment: production    # Required approval + business hours gate
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: app
                - script: ./deploy.sh prod
```

## Common Mistakes

1. **Using classic releases for new pipelines** — Multi-stage YAML is the future. Classic releases are maintenance mode.
2. **Not using `extends` for governance** — Without it, teams can skip required security scans.
3. **Inline secrets in YAML** — Use variable groups linked to Key Vault instead.
4. **Ignoring conditions** — Without proper conditions, deploy stages run on every PR.
5. **Not using deployment jobs** — Regular jobs don't get environment tracking, approvals, or deployment history.
6. **Overusing `script` tasks** — Prefer built-in tasks (better logging, error handling, integration).
