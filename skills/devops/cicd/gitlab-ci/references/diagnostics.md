# GitLab CI Diagnostics

## Pipeline Not Running

### No Pipeline Created

**Diagnosis:**
1. Check `.gitlab-ci.yml` exists in the repository root
2. Validate YAML: CI/CD > Pipelines > CI Lint (or API: `POST /api/v4/ci/lint`)
3. Check `rules:` — all jobs may evaluate to `when: never`
4. Check project CI/CD settings: Settings > CI/CD > General pipelines

**Resolution:**
```bash
# Validate YAML locally
gitlab-ci-lint .gitlab-ci.yml

# API validation
curl --header "PRIVATE-TOKEN: $TOKEN" \
  --data @.gitlab-ci.yml \
  "https://gitlab.example.com/api/v4/ci/lint"
```

### Pipeline Created but Jobs Skipped

```
This job has been skipped because the rules evaluated to false
```

**Diagnosis:** Check `rules:` conditions against the actual trigger context:
- `$CI_COMMIT_BRANCH` is not set for tag pipelines
- `$CI_COMMIT_TAG` is not set for branch pipelines
- `$CI_PIPELINE_SOURCE` differs between push, MR, API, schedule

### Duplicate Pipelines

**Symptom**: Two pipelines run for the same commit (one for push, one for MR).

**Resolution**: Use `workflow:rules` to prevent duplicates:

```yaml
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never    # Don't run branch pipeline if MR exists
    - if: $CI_COMMIT_BRANCH
```

## Job Failures

### Runner Not Available

```
This job is stuck because the project doesn't have any runners online assigned to it
```

**Diagnosis:**
1. Check runner status: Settings > CI/CD > Runners
2. Check runner tags match job tags
3. Check runner is not paused
4. For shared runners: check instance-level runner availability

**Resolution:**
```bash
# Check runner on the host
gitlab-runner list
gitlab-runner verify
gitlab-runner status

# Re-register if needed
gitlab-runner register
```

### Docker Image Pull Failures

```
ERROR: Job failed (system failure): Error response from daemon: pull access denied
```

**Resolution:**
1. Check image name and tag are correct
2. For private registries, configure credentials:
   ```toml
   # config.toml
   [[runners]]
     [runners.docker]
       allowed_pull_policies = ["if-not-present", "always"]
     [[runners.docker.credentials]]
       host = "registry.example.com"
       username = "user"
       password = "token"
   ```
3. Use `$CI_REGISTRY` for GitLab's built-in registry

### Script Errors

```
$ npm test
npm ERR! code ELIFECYCLE
ERROR: Job failed: exit code 1
```

**Diagnosis:**
1. The script itself failed — read the error output
2. Check if dependencies are installed (`npm ci` before `npm test`)
3. Check environment variables are set
4. Check service containers are ready (database may not be up yet)

**Database service not ready:**
```yaml
test:
  services:
    - postgres:16
  variables:
    POSTGRES_DB: test
    POSTGRES_USER: runner
    POSTGRES_PASSWORD: secret
  before_script:
    # Wait for postgres to be ready
    - apt-get update && apt-get install -y postgresql-client
    - until pg_isready -h postgres -U runner; do sleep 1; done
```

## Cache Issues

### Cache Not Restoring

**Diagnosis:**
1. Check cache key matches between jobs
2. Check cache path is correct
3. Check runner has access to cache storage
4. Check cache is not scoped to a different branch

**Resolution:**
```yaml
# Add fallback keys
cache:
  key:
    files: [package-lock.json]
    prefix: ${CI_COMMIT_REF_SLUG}
  paths: [node_modules/]
  fallback_keys:
    - ${CI_DEFAULT_BRANCH}-${CI_COMMIT_REF_SLUG}
    - ${CI_DEFAULT_BRANCH}
```

### Cache Too Large

**Symptom**: Cache upload/download takes longer than the actual job.

**Resolution:**
- Only cache what matters (dependency directories, not build outputs)
- Use hash-based keys to avoid caching stale data
- Configure distributed cache (S3/GCS) for shared runners
- Consider if the caching actually saves time

## Artifact Issues

### Artifact Upload Failed

```
WARNING: Uploading artifacts as "archive" to coordinator... too large archive
```

**Resolution:**
- Reduce artifact size (exclude unnecessary files)
- Increase maximum artifact size: Admin > Settings > CI/CD
- Use `expire_in` to control retention

### Artifacts Not Available in Downstream Job

**Diagnosis:**
1. Check the producing job succeeded
2. Check `needs:` includes the producing job (or jobs are in consecutive stages)
3. Check artifact paths match

```yaml
# Explicit artifact dependency
test:
  needs:
    - job: build
      artifacts: true    # Default is true, but be explicit
```

## YAML Validation

### Common YAML Errors

```yaml
# ERROR: Unknown key (typo)
scrpt:       # Should be 'script'
  - npm test

# ERROR: Invalid indentation
job:
script:      # Should be indented under job
  - npm test

# ERROR: Using tabs (YAML requires spaces)
job:
	script:    # Tab character — use spaces

# ERROR: Unquoted special characters
variables:
  MSG: This has a : colon  # Needs quoting: "This has a : colon"
```

### CI Lint Tools

```bash
# GitLab CI Lint API
curl --header "PRIVATE-TOKEN: $TOKEN" \
  --header "Content-Type: application/json" \
  --data '{"content": "'"$(cat .gitlab-ci.yml)"'"}' \
  "https://gitlab.example.com/api/v4/projects/$PROJECT_ID/ci/lint"

# Local validation (if available)
gitlab-ci-lint .gitlab-ci.yml
```

## Debugging Techniques

### Enable Debug Logging

Add `CI_DEBUG_TRACE: "true"` to variables (shows all commands and variables — **includes secrets, use cautiously**):

```yaml
test:
  variables:
    CI_DEBUG_TRACE: "true"
  script:
    - npm test
```

### Interactive Web Terminal

For debugging jobs in real-time (GitLab Premium):
1. Navigate to the running job
2. Click "Debug" button
3. Get a terminal session in the job's container

### Local Pipeline Simulation

```bash
# Use gitlab-runner exec to run a job locally
gitlab-runner exec docker test:unit \
  --docker-image node:22 \
  --env CI_COMMIT_SHA=$(git rev-parse HEAD)
```
