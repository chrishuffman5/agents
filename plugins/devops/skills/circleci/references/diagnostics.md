# CircleCI Diagnostics

## Config Errors

### Validation Failures

```bash
# Validate locally
circleci config validate

# Process and see expanded config
circleci config process .circleci/config.yml > processed.yml
```

### Orb Resolution Failures

```
Error: Could not find orb 'circleci/node@99.0'
```

**Resolution:** Check orb versions at `https://circleci.com/developer/orbs/orb/circleci/node`

### Config Too Large

```
Error: config file is too large
```

**Resolution:** Extract reusable config into private orbs or use config splitting with `setup` workflows.

## Job Failures

### Out of Memory

```
Killed (exit code 137)
```

**Cause:** Container exceeded memory limit.

**Resolution:** Upgrade `resource_class` or reduce memory usage.

### Docker Pull Failures

```
Error response from daemon: pull access denied
```

**Resolution:**
```yaml
jobs:
  build:
    docker:
      - image: private-registry.com/myimage:latest
        auth:
          username: $DOCKER_USER
          password: $DOCKER_PASS
```

### No Space on Device

**Resolution:** Clean up or use a larger resource class. For Docker builds, prune unused images.

## Cache Issues

### Cache Not Restoring

- Check key matches (case-sensitive, exact match for primary key)
- Caches expire after 15 days
- Caches are branch-scoped (with fallback to default branch)
- Version your cache keys (`v2-deps-`) to bust stale caches

### Cache Too Slow

For very large caches, the upload/download time may exceed the time saved:
- Only cache what truly takes time to regenerate
- Use workspace (same workflow) instead of cache (cross-workflow) where appropriate

## SSH Debugging

```bash
# Rerun with SSH (via CircleCI UI)
# SSH into the running container to debug interactively
ssh -p 64535 <ip>

# Available for 2 hours after job completes
# Not available for self-hosted runners
```

## API Debugging

```bash
# Trigger pipeline
curl -X POST "https://circleci.com/api/v2/project/gh/org/repo/pipeline" \
  -H "Circle-Token: $CIRCLECI_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"branch": "main"}'

# Get pipeline status
curl "https://circleci.com/api/v2/pipeline/<id>/workflow" \
  -H "Circle-Token: $CIRCLECI_TOKEN"

# Get job artifacts
curl "https://circleci.com/api/v2/project/gh/org/repo/<job-num>/artifacts" \
  -H "Circle-Token: $CIRCLECI_TOKEN"
```
