# GitLab CI Architecture

## Pipeline Processing

### Pipeline Creation Flow

```
Trigger (push, MR, API, schedule)
        │
        ▼
┌──────────────────┐
│  Parse YAML      │  Read .gitlab-ci.yml + includes
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Evaluate rules  │  Determine which jobs to create
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Build DAG       │  Resolve needs/dependencies
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Queue jobs      │  Assign to stages, mark pending
└──────┬───────────┘
       │
┌──────▼───────────┐
│  Runner picks up │  Runner polls for matching jobs
└──────────────────┘
```

### Job Matching

When a runner polls for work, GitLab matches based on:
1. **Tags** — Runner tags must include all tags specified in the job
2. **Scope** — Instance, group, or project runner
3. **Protected** — Protected runners only run on protected branches/tags
4. **Lock to project** — Runner locked to a specific project

## Runner Architecture

### Runner Components

```
┌─────────────────────────────────────┐
│           GitLab Runner             │
│                                     │
│  ┌──────────┐   ┌───────────────┐  │
│  │ Poller   │   │  Job Queue    │  │
│  │ (HTTP)   │──▶│               │  │
│  └──────────┘   └───────┬───────┘  │
│                         │          │
│  ┌──────────────────────▼────────┐ │
│  │     Executor                  │ │
│  │  ┌────────┐  ┌────────────┐  │ │
│  │  │ Prepare│  │   Build    │  │ │
│  │  │ (pull  │  │  (script)  │  │ │
│  │  │ image) │  │            │  │ │
│  │  └────────┘  └────────────┘  │ │
│  │  ┌────────┐  ┌────────────┐  │ │
│  │  │ Cache  │  │  Artifacts │  │ │
│  │  │ (S3/   │  │  (upload)  │  │ │
│  │  │  GCS)  │  │            │  │ │
│  │  └────────┘  └────────────┘  │ │
│  └───────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Executor Deep Dive

#### Docker Executor

- Creates a new container for each job
- Services (postgres, redis) run as linked containers
- Volumes: `/builds` (project), `/cache` (cache)
- Image pulled from registry (can be configured with pull policies)
- Container destroyed after job completes

```toml
# config.toml
[[runners]]
  executor = "docker"
  [runners.docker]
    image = "alpine:latest"
    privileged = false          # Set true for Docker-in-Docker
    volumes = ["/cache"]
    pull_policy = ["if-not-present"]
    allowed_images = ["ruby:*", "python:*", "node:*"]
```

#### Kubernetes Executor

- Creates a pod per job in a Kubernetes cluster
- Each job step runs in a separate container within the pod
- Services run as sidecar containers
- Auto-scales with cluster autoscaler

```toml
[[runners]]
  executor = "kubernetes"
  [runners.kubernetes]
    namespace = "gitlab-ci"
    image = "alpine:latest"
    cpu_request = "500m"
    memory_request = "256Mi"
    cpu_limit = "2"
    memory_limit = "2Gi"
    service_cpu_request = "250m"
    service_memory_request = "128Mi"
```

#### Instance (Fleeting) Executor

Replacement for Docker Machine autoscaling. Creates ephemeral VMs via cloud provider plugins:

- Supports AWS, GCP, Azure via fleeting plugins
- Each job gets a fresh VM
- VM destroyed after job completion
- Native cloud autoscaling integration

## CI/CD Variables

### Variable Hierarchy (Precedence)

From lowest to highest priority:

1. GitLab predefined variables (`CI_COMMIT_SHA`, `CI_PIPELINE_ID`)
2. Instance-level CI/CD variables
3. Group-level CI/CD variables
4. Project-level CI/CD variables
5. `.gitlab-ci.yml` `variables:` keyword
6. Job-level `variables:` keyword
7. Trigger/pipeline variables (API)
8. Manual pipeline variables (UI)

### Key Predefined Variables

| Variable | Value |
|---|---|
| `CI_COMMIT_SHA` | Full commit SHA |
| `CI_COMMIT_SHORT_SHA` | Short commit SHA (8 chars) |
| `CI_COMMIT_BRANCH` | Branch name (not set for tags) |
| `CI_COMMIT_TAG` | Tag name (not set for branches) |
| `CI_COMMIT_REF_SLUG` | Branch/tag name, slugified |
| `CI_PIPELINE_SOURCE` | How the pipeline was triggered |
| `CI_MERGE_REQUEST_IID` | MR internal ID |
| `CI_REGISTRY_IMAGE` | Container registry image path |
| `CI_JOB_TOKEN` | Auto-generated token for API access |
| `CI_PROJECT_DIR` | Full path to the project directory |

### Protected and Masked Variables

- **Protected**: Only available on protected branches/tags
- **Masked**: Hidden in job logs (must meet regex constraints)
- **File type**: Written to a temp file, variable contains the path

## Artifacts and Caching

### Artifacts vs Cache

| Aspect | Artifacts | Cache |
|---|---|---|
| **Purpose** | Pass files between jobs in a pipeline | Speed up jobs across pipeline runs |
| **Scope** | Within a pipeline | Across pipelines (same key) |
| **Upload** | Always (when job succeeds) | Best-effort |
| **Download** | Explicit (`needs:` or stage dependency) | Automatic (when key matches) |
| **Storage** | GitLab server or object storage | Runner local or object storage |
| **Retention** | Configurable (`expire_in:`) | Evicted when full |

### Cache Strategies

```yaml
# Per-branch cache with fallback
cache:
  key:
    files:
      - package-lock.json    # Cache key based on lock file hash
    prefix: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
  policy: pull-push           # pull: download only, push: upload only, pull-push: both
  fallback_keys:
    - ${CI_DEFAULT_BRANCH}    # Fall back to main branch cache
```

## Component Catalog

GitLab CI/CD components are reusable pipeline configurations published to the CI/CD Catalog:

```yaml
# component.yml (in a component project)
spec:
  inputs:
    stage:
      default: test
    image:
      default: node:22
---
"$[[ inputs.stage ]]":
  image: $[[ inputs.image ]]
  script:
    - npm ci
    - npm test
```

Components use `$[[ inputs.name ]]` interpolation (distinct from CI/CD variables `$VARIABLE`).
