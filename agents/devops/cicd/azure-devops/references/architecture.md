# Azure DevOps Architecture

## Pipeline Processing

### Pipeline Execution Flow

```
Trigger (push, PR, schedule, manual)
        │
        ▼
┌──────────────────┐
│  Parse YAML      │  Resolve templates, extends, resources
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Evaluate        │  Process conditions, compile-time expressions ${{ }}
│  Expressions     │
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Queue Stages    │  Stages run sequentially (or parallel with dependsOn)
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Queue Jobs      │  Jobs within a stage run in parallel by default
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Agent Matching  │  Match job to agent pool, capabilities, demands
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Execute Steps   │  Steps run sequentially on the matched agent
└──────────────────┘
```

### Expression Types

| Syntax | When Evaluated | Scope |
|---|---|---|
| `${{ }}` | Compile time (YAML parsing) | Template parameters, conditional insertion |
| `$[ ]` | Runtime (before each step) | Conditions, variable references |
| `$(variableName)` | Runtime (macro expansion) | Inline variable substitution |

```yaml
# Compile-time: template parameter insertion
steps:
  - ${{ if eq(parameters.environment, 'prod') }}:
    - task: ManualValidation@0

# Runtime: condition evaluation
- script: deploy.sh
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))

# Macro: variable substitution
- script: echo $(buildConfiguration)
```

## Agent Architecture

### Microsoft-Hosted Agents

| Image | OS | Pre-installed |
|---|---|---|
| `ubuntu-latest` | Ubuntu 24.04 | Node, Python, .NET, Docker, kubectl, Terraform, az CLI |
| `windows-latest` | Windows Server 2022 | Visual Studio, .NET, Node, Python, PowerShell |
| `macos-latest` | macOS (Sequoia) | Xcode, Node, Python, Ruby, CocoaPods |

**Lifecycle**: Fresh VM provisioned → tools pre-installed → job runs → VM destroyed. No state persists between jobs.

### Self-Hosted Agent Architecture

```
Azure DevOps Service ◄──(HTTPS long-poll)──► Agent Listener
                                                    │
                                              ┌─────▼─────┐
                                              │   Worker   │
                                              │  Process   │
                                              └─────┬─────┘
                                                    │
                                              ┌─────▼─────┐
                                              │   Task     │
                                              │  Handler   │
                                              └───────────┘
```

**Agent capabilities**: Each agent advertises its capabilities (installed tools, environment variables). Jobs specify **demands** that must match agent capabilities.

```yaml
pool:
  name: 'MyPool'
  demands:
    - Agent.OS -equals Linux
    - docker
    - node
```

### VMSS Agents (Autoscaling)

Azure VM Scale Set agent pools provide elastic scaling:

1. Define a VMSS in Azure with a base image
2. Register the VMSS as an agent pool in Azure DevOps
3. Configure min/max agents, idle timeout, and scaling policies
4. Azure DevOps provisions VMs on demand and returns them when idle

## YAML Schema

### Full Pipeline Schema

```yaml
name: $(Date:yyyyMMdd)$(Rev:.r)    # Build number format

trigger: ...
pr: ...
schedules: ...

resources:
  repositories:           # External repos
    - repository: templates
      type: git
      name: org/templates-repo
  containers:             # Container resources
    - container: redis
      image: redis:8
  pipelines:              # Pipeline resources (artifacts from other pipelines)
    - pipeline: build
      source: Build-Pipeline
      trigger: true

pool: ...

variables:
  - group: my-var-group
  - name: myVar
    value: myValue
  - template: variables/common.yml

lockBehavior: sequential    # Queue runs instead of canceling

stages:
  - stage: Build
    displayName: 'Build Stage'
    dependsOn: []           # No dependencies (runs first)
    condition: succeeded()
    jobs:
      - job: ...
      - deployment: ...
```

### Variable Scoping

| Level | Scope | Example |
|---|---|---|
| **Pipeline** | All stages and jobs | `variables:` at root level |
| **Stage** | All jobs in that stage | `variables:` under a stage |
| **Job** | All steps in that job | `variables:` under a job |
| **Step** | That step only | `env:` on a step |

### Variable Precedence (Highest to Lowest)

1. Queue-time variables (manual run with override)
2. Pipeline YAML variables
3. Pipeline-level variable (UI settings)
4. Variable group variables
5. Template parameters

### Output Variables

```yaml
jobs:
  - job: BuildJob
    steps:
      - script: |
          echo "##vso[task.setvariable variable=version;isOutput=true]1.2.3"
        name: setVersion

  - job: DeployJob
    dependsOn: BuildJob
    variables:
      version: $[ dependencies.BuildJob.outputs['setVersion.version'] ]
    steps:
      - script: echo "Deploying version $(version)"
```

## Resource Management

### Service Connection Architecture

Service connections store authentication credentials for external services:

```
Pipeline Job
    │
    ├── Task: AzureWebApp@1
    │       │
    │       ▼
    │   Service Connection (Azure RM)
    │       │
    │       ├── Service Principal + Secret
    │       ├── Managed Identity
    │       └── Workload Identity Federation (OIDC)
    │               │
    │               ▼
    │          Azure Resource Manager API
    │
    └── Task: Docker@2
            │
            ▼
        Service Connection (Docker Registry)
                │
                ▼
           Container Registry
```

### Environment Architecture

Environments provide deployment tracking and protection:

| Feature | Description |
|---|---|
| **Deployment history** | Track what was deployed when and by whom |
| **Approvals** | Manual approval before deployment |
| **Gates** | Automated checks (Azure Monitor alerts, REST API) |
| **Branch control** | Restrict which branches can deploy |
| **Exclusive lock** | Only one deployment at a time |
| **Kubernetes resource** | Direct K8s namespace tracking |

### Pipeline Artifacts vs Build Artifacts

| Feature | Pipeline Artifacts | Build Artifacts (classic) |
|---|---|---|
| **Keyword** | `publish` / `download` | `PublishBuildArtifacts` / `DownloadBuildArtifacts` tasks |
| **Storage** | Azure DevOps (optimized) | Azure DevOps (legacy) |
| **Speed** | Faster (deduplication) | Slower |
| **Cross-pipeline** | Via `resources.pipelines` | Via build tags |
| **Retention** | Tied to pipeline run | Configurable |
