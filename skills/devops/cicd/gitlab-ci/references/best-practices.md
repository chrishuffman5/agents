# GitLab CI Best Practices

## Pipeline Design

### Use Rules, Not only/except

```yaml
# GOOD: rules keyword (flexible, clear)
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      when: manual
    - when: never

# BAD: only/except (deprecated, limited)
deploy:
  only:
    - main
```

### Use needs for DAG Pipelines

```yaml
# Without needs: test waits for ALL build jobs
# With needs: test:api starts as soon as build:api finishes
test:api:
  needs: [build:api]
  script: npm run test:api

test:web:
  needs: [build:web]
  script: npm run test:web
```

### Use extends for DRY Configuration

```yaml
.docker-build:
  image: docker:latest
  services:
    - docker:dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY

build:api:
  extends: .docker-build
  script:
    - docker build -t $CI_REGISTRY_IMAGE/api:$CI_COMMIT_SHA ./api
    - docker push $CI_REGISTRY_IMAGE/api:$CI_COMMIT_SHA
```

## Caching

### Effective Cache Keys

```yaml
# Hash-based key (invalidates when dependencies change)
cache:
  key:
    files:
      - Gemfile.lock
  paths:
    - vendor/ruby

# Branch-scoped (each branch has its own cache)
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - .cache/

# Combine both
cache:
  key:
    files: [package-lock.json]
    prefix: ${CI_COMMIT_REF_SLUG}
  paths: [node_modules/]
```

### Cache vs Artifacts Strategy

```yaml
# Cache: dependencies (reused across pipeline runs)
build:
  cache:
    key:
      files: [package-lock.json]
    paths: [node_modules/]
  script:
    - npm ci
    - npm run build
  # Artifacts: build output (passed to test/deploy jobs)
  artifacts:
    paths: [dist/]
    expire_in: 1 hour
```

## Security

### Protect Secrets

```yaml
# Use CI/CD variables (Settings > CI/CD > Variables), not .gitlab-ci.yml
# Mark as Protected (only on protected branches) and Masked (hidden in logs)

# For external secrets, use integration:
deploy:
  id_tokens:
    VAULT_TOKEN:
      aud: https://vault.example.com
  script:
    - export VAULT_ADDR=https://vault.example.com
    - vault kv get -field=password secret/database
```

### Minimize Docker-in-Docker Risks

```yaml
# Prefer Kaniko over DinD for building images (no privileged mode needed)
build:
  image:
    name: gcr.io/kaniko-project/executor:latest
    entrypoint: [""]
  script:
    - /kaniko/executor
      --context $CI_PROJECT_DIR
      --dockerfile Dockerfile
      --destination $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

### Compliance Pipelines

For regulated environments, use compliance pipelines to enforce jobs that project maintainers cannot remove:

```yaml
# Group-level compliance pipeline
include:
  - project: 'compliance/ci-templates'
    file: '/security-scans.yml'
    # These jobs run regardless of project .gitlab-ci.yml content
```

## Performance

### Reduce Pipeline Duration

1. **Use DAG (`needs:`)** — Skip stage boundaries for independent jobs
2. **Cache dependencies** — Hash-based keys with fallback
3. **Parallelize tests** — `parallel:` keyword splits test suites

```yaml
test:
  parallel: 4    # Creates test 1/4, test 2/4, test 3/4, test 4/4
  script:
    - npm run test -- --shard=$CI_NODE_INDEX/$CI_NODE_TOTAL
```

4. **Interruptible jobs** — Cancel redundant pipelines

```yaml
test:
  interruptible: true    # Cancel this job if a newer pipeline starts
```

5. **Resource groups** — Limit concurrent deployments

```yaml
deploy:
  resource_group: production    # Only one deploy:production runs at a time
```

### Optimize Docker Builds

```yaml
build:
  variables:
    DOCKER_BUILDKIT: 1
  script:
    # Use registry as cache source
    - docker build
      --cache-from $CI_REGISTRY_IMAGE:latest
      --tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
      --tag $CI_REGISTRY_IMAGE:latest
      --build-arg BUILDKIT_INLINE_CACHE=1
      .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
    - docker push $CI_REGISTRY_IMAGE:latest
```

## Monorepo Patterns

### Path-Based Rules

```yaml
build:api:
  rules:
    - changes:
        - services/api/**
        - libs/shared/**
  script: cd services/api && make build

build:web:
  rules:
    - changes:
        - services/web/**
        - libs/shared/**
  script: cd services/web && make build
```

### Parent-Child Pipelines

```yaml
# Root .gitlab-ci.yml
trigger:api:
  trigger:
    include: services/api/.gitlab-ci.yml
    strategy: depend
  rules:
    - changes: [services/api/**]

trigger:web:
  trigger:
    include: services/web/.gitlab-ci.yml
    strategy: depend
  rules:
    - changes: [services/web/**]
```

## Common Mistakes

1. **Using `only/except` instead of `rules`** — `rules:` is more powerful and less surprising
2. **Missing `expire_in` on artifacts** — Artifacts without expiry consume storage indefinitely
3. **Cache as artifact substitute** — Caches are best-effort and may be evicted. Don't rely on them for inter-job data.
4. **DinD without TLS** — Always set `DOCKER_TLS_CERTDIR: "/certs"` with Docker-in-Docker
5. **Not using `interruptible: true`** — Without it, old pipelines continue running even when newer commits are pushed
