# Azure DevOps Diagnostics

## Pipeline Failures

### Pipeline Not Triggering

**Diagnosis:**
1. Check trigger configuration in YAML matches the branch/path
2. Check CI triggers are not disabled: Pipeline settings > "Override YAML CI trigger"
3. Check PR triggers: `pr:` section in YAML
4. For scheduled triggers: verify cron expression and timezone

```yaml
# Common mistake: trigger and pr blocks are separate
trigger:
  branches:
    include: [main]
# This is NOT a PR trigger — it's a CI trigger for pushes to main

pr:
  branches:
    include: [main]
# THIS is the PR trigger
```

### "No hosted parallelism has been purchased or granted"

**Cause**: Free-tier Azure DevOps organization needs to request free parallelism for Microsoft-hosted agents.

**Resolution**: Submit a request at https://aka.ms/azpipelines-parallelism-request (Azure DevOps > Organization Settings > Parallel jobs)

### Agent Not Available

```
All eligible agents are disabled or offline
```

**Diagnosis:**
1. Check agent pool: Organization Settings > Agent pools
2. Check agent status (online, offline, disabled)
3. Check job demands vs agent capabilities
4. Check agent version (must be within 2 major versions of service)

**Resolution:**
```bash
# On the agent machine
./config.sh --help    # Linux/macOS
.\config.cmd --help   # Windows

# Check agent status
./run.sh              # Interactive mode for debugging
```

## Task Failures

### Task Version Issues

```
##[error]The task 'AzureWebApp' version 1.x.x is not supported. Please update to a newer version.
```

**Resolution**: Update task version in YAML:
```yaml
# Pin to latest major version
- task: AzureWebApp@1    # v1.x.x (latest minor/patch)
```

### Service Connection Errors

```
##[error]Could not find a service connection with name 'my-azure-connection'
```

**Diagnosis:**
1. Service connection name matches exactly (case-sensitive)
2. Pipeline has been authorized to use the service connection
3. Service connection credentials haven't expired

**Resolution:**
- Project Settings > Service connections > verify name
- Click the service connection > Pipeline permissions > authorize the pipeline
- For expired credentials: edit the service connection and re-authenticate

### Azure Authentication Failures

```
##[error]AADSTS7000215: Invalid client secret provided
```

**Resolution:**
1. Service connection secret may have expired
2. Edit the service connection in Azure DevOps
3. Re-enter credentials or switch to workload identity federation (OIDC)

```yaml
# Verify connection in pipeline
- task: AzureCLI@2
  inputs:
    azureSubscription: 'my-connection'
    scriptType: bash
    scriptLocation: inlineScript
    inlineScript: |
      az account show
      az group list --output table
```

## Variable Issues

### Variable Not Expanding

**Common causes:**
1. Wrong syntax: `${{ }}` vs `$()` vs `$[ ]`
2. Variable defined in a different scope
3. Secret variables can't be used in templates (compile-time)

```yaml
# Compile-time (template parameters only)
${{ variables.myVar }}     # Available at YAML parsing time

# Runtime macro (most common)
$(myVar)                    # Expanded before step runs

# Runtime expression (conditions)
$[variables.myVar]         # Evaluated at runtime
```

### Output Variables Not Passed

```yaml
# Producer job must use logging command format
- script: echo "##vso[task.setvariable variable=myOutput;isOutput=true]value"
  name: stepName    # MUST have a name

# Consumer job must use dependencies syntax
variables:
  myVar: $[ dependencies.ProducerJob.outputs['stepName.myOutput'] ]

# Cross-stage: use stageDependencies
variables:
  myVar: $[ stageDependencies.BuildStage.ProducerJob.outputs['stepName.myOutput'] ]
```

## Template Issues

### Template Not Found

```
##[error]Could not find template 'templates/build.yml'
```

**Diagnosis:**
1. Path is relative to the repository root
2. For external repos: `resources.repositories` must be defined
3. File must exist on the branch being built

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: MyOrg/pipeline-templates
      ref: main    # Specify the branch

# Reference with repository alias
- template: build-template.yml@templates
```

### Template Parameter Type Errors

```
##[error]Expected a 'string' type but got a 'mapping' type
```

**Resolution**: Check parameter types match:
```yaml
# Template definition
parameters:
  - name: steps
    type: stepList    # Not string, not object
    default: []

# Correct usage
steps:
  - template: my-template.yml
    parameters:
      steps:
        - script: echo hello
```

## Debugging Techniques

### Enable System Diagnostics

```yaml
# Add to pipeline variables
variables:
  System.Debug: true    # Verbose logging for all tasks
```

Or: Run pipeline > "Enable system diagnostics" checkbox in the UI.

### Logging Commands

```yaml
- script: |
    echo "##vso[task.logissue type=warning]This is a warning"
    echo "##vso[task.logissue type=error]This is an error"
    echo "##vso[task.debug]Debug message"
    echo "##vso[task.setvariable variable=myVar]myValue"
    echo "##vso[task.uploadfile]$(System.DefaultWorkingDirectory)/logfile.txt"
    echo "##vso[build.addbuildtag]my-tag"
```

### Predefined Variables Reference

| Variable | Value |
|---|---|
| `Build.SourceBranch` | `refs/heads/main` or `refs/pull/123/merge` |
| `Build.SourceBranchName` | `main` |
| `Build.SourceVersion` | Commit SHA |
| `Build.BuildId` | Unique build ID |
| `Build.Reason` | `IndividualCI`, `PullRequest`, `Schedule`, `Manual` |
| `System.DefaultWorkingDirectory` | Agent working directory |
| `Pipeline.Workspace` | Pipeline workspace directory |
| `Agent.OS` | `Linux`, `Windows_NT`, `Darwin` |
| `Agent.TempDirectory` | Temp directory (cleaned after each job) |

### REST API Debugging

```bash
# Get pipeline runs
az pipelines runs list --org https://dev.azure.com/myorg --project myproject

# Get run logs
az pipelines runs show --id 123 --org https://dev.azure.com/myorg --project myproject

# Trigger a run
az pipelines run --name "My Pipeline" --branch main
```
