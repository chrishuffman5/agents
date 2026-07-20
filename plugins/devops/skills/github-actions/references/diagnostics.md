# GitHub Actions Diagnostics

## Workflow Not Triggering

### Symptoms

Workflow doesn't run after push, PR, or other expected event.

### Diagnosis

1. **Check event type and filters**:
   ```yaml
   # This won't trigger on pushes to feature branches
   on:
     push:
       branches: [main]    # Only main
   ```

2. **Check paths filter**: If `paths:` is set, only changes to those paths trigger the workflow

3. **Disabled workflows**: Check Settings > Actions > workflows list for disabled status

4. **Workflow file location**: Must be in `.github/workflows/` on the default branch (for schedule/workflow_dispatch) or the target branch (for push/PR)

5. **Syntax errors**: Invalid YAML prevents workflow registration. Check Actions tab for errors.

6. **Fork limitations**: Workflows in forks are disabled by default until the user enables them.

### Resolution

```bash
# Verify workflow file is valid YAML
python -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"

# Check if workflow is recognized
gh workflow list

# Manually trigger (if workflow_dispatch is configured)
gh workflow run ci.yml --ref main
```

## Job/Step Failures

### Permission Denied

```
Error: Resource not accessible by integration
```

**Cause**: `GITHUB_TOKEN` doesn't have required permissions.

**Resolution**: Add explicit permissions:
```yaml
permissions:
  contents: read
  packages: write
  pull-requests: write
```

### Action Version Not Found

```
Error: Unable to resolve action `actions/setup-node@v99`
```

**Resolution**: Check the action's releases page for valid versions. Pin to a SHA for stability.

### Container Action Failures

```
Error: Docker is not available on this runner
```

**Cause**: Docker container actions require Linux runners. Windows and macOS runners don't support Docker actions.

### Checkout Failures

```
Error: fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

**Cause**: Trying to access a private repository without proper authentication.

**Resolution**:
```yaml
- uses: actions/checkout@v4
  with:
    token: ${{ secrets.PAT }}    # Personal access token for private repo
    repository: org/private-repo
```

## Cache Issues

### Cache Miss

**Diagnosis**:
- Check cache key matches: `key: deps-${{ runner.os }}-${{ hashFiles('package-lock.json') }}`
- Keys are case-sensitive and exact-match
- `restore-keys` provides fallback prefix matching
- Caches are scoped to branch (PR caches can use base branch caches)

### Cache Size Limits

- Maximum cache size: 10 GB per repository
- Individual cache entry max: 10 GB
- Caches not accessed in 7 days are evicted
- When limit is exceeded, oldest caches are evicted first

## Runner Issues

### Self-Hosted Runner Offline

```bash
# Check runner status
gh api repos/{owner}/{repo}/actions/runners

# Restart runner service
sudo ./svc.sh status
sudo ./svc.sh stop
sudo ./svc.sh start

# Re-register runner (if token expired)
./config.sh remove --token <REMOVE_TOKEN>
./config.sh --url https://github.com/org/repo --token <REG_TOKEN>
```

### Runner Disk Full

**Symptoms**: `No space left on device` errors during checkout or build.

**Resolution**:
```yaml
# Free up disk space at the start of the job
- name: Free disk space
  run: |
    sudo rm -rf /usr/share/dotnet
    sudo rm -rf /usr/local/lib/android
    sudo rm -rf /opt/ghc
    df -h
```

## Secrets and Variables

### Secret Not Available

**Diagnosis**:
1. **Fork PR**: Secrets are not available to workflows triggered by fork PRs
2. **Environment scope**: Secret defined in an environment requires the job to use that environment
3. **Org vs repo**: Org secrets require the repository to be in the access policy

### Masked Output Issue

```yaml
# If a secret value appears in a multi-line output, mask each line
- run: |
    echo "::add-mask::${{ secrets.MY_SECRET }}"
```

## Debugging Techniques

### Enable Debug Logging

Set these secrets in the repository:
- `ACTIONS_RUNNER_DEBUG` = `true` — Verbose runner diagnostics
- `ACTIONS_STEP_DEBUG` = `true` — Verbose step output

### Re-run with Debug

Use the GitHub UI: "Re-run jobs" > "Enable debug logging" checkbox.

### Local Testing with act

```bash
# Install act (local GitHub Actions runner)
brew install act    # macOS
# or download from https://github.com/nektos/act

# Run a specific workflow
act push -W .github/workflows/ci.yml

# Run with secrets
act push --secret-file .env.secrets

# List available workflows and jobs
act -l
```

### Workflow Commands

```yaml
# Debug message (only visible with ACTIONS_STEP_DEBUG=true)
- run: echo "::debug::Variable value is $MY_VAR"

# Warning annotation
- run: echo "::warning file=app.js,line=1::Missing error handling"

# Error annotation
- run: echo "::error file=app.js,line=10::Syntax error"

# Group log lines
- run: |
    echo "::group::Install dependencies"
    npm ci
    echo "::endgroup::"

# Set output for subsequent steps
- id: my-step
  run: echo "result=success" >> "$GITHUB_OUTPUT"
- run: echo "${{ steps.my-step.outputs.result }}"

# Set environment variable for subsequent steps
- run: echo "MY_VAR=hello" >> "$GITHUB_ENV"
```
