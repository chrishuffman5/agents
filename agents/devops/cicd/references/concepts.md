# CI/CD Platform Concepts

## Pipeline Building Blocks

### Triggers

| Trigger Type | When | Example |
|---|---|---|
| **Push** | Code pushed to a branch | Build on every push to `main` |
| **Pull Request** | PR opened, updated, or merged | Run tests before merge |
| **Schedule** | Cron-based timing | Nightly builds, security scans |
| **Manual** | Human clicks a button | Production deployment approval |
| **API / Webhook** | External event | Upstream dependency updated |
| **Tag** | Git tag created | Release build |

### Jobs and Steps

- **Step/Task** — A single command or action (run a script, call an API)
- **Job** — A collection of steps that run on the same runner/agent
- **Stage** — A group of jobs that run at the same pipeline phase (build, test, deploy)
- **Pipeline/Workflow** — The entire CI/CD process from trigger to completion

### Parallelism

- **Matrix builds** — Run the same job across multiple configurations (OS × language version × dependency version)
- **Parallel jobs** — Independent jobs within a stage run simultaneously
- **Fan-out / fan-in** — One job triggers many parallel jobs, then a downstream job waits for all to complete

```
        ┌── Test (Node 18) ──┐
Build ──┤── Test (Node 20) ──├── Deploy
        └── Test (Node 22) ──┘
```

## Artifact Management

### Build Artifacts

Artifacts are the outputs of a CI/CD pipeline:

| Artifact Type | Examples | Storage |
|---|---|---|
| **Container images** | Docker images | Container registry (ECR, ACR, GCR, Docker Hub, GitHub Packages) |
| **Packages** | npm, PyPI, NuGet, Maven | Package registry (GitHub Packages, Artifactory, Azure Artifacts) |
| **Binaries** | Go binaries, Rust binaries | Object storage (S3, GCS), release assets |
| **Reports** | Test results, coverage, SBOM | Pipeline artifacts, S3, dashboards |

### Artifact Versioning

- **Semantic versioning** — `MAJOR.MINOR.PATCH` for releases
- **Git SHA** — `sha-abc1234` for traceability
- **Build number** — `build-42` for CI ordering
- **Composite** — `v2.1.3-build42-abc1234` for complete provenance

**Never use `:latest`** — it's a moving target. Always pin to an immutable version.

## Caching Strategies

### What to Cache

| Cache Target | Impact | Example Key |
|---|---|---|
| **Dependencies** (node_modules, .pip, .m2) | High — saves minutes | `deps-{{ hashFiles('package-lock.json') }}` |
| **Build outputs** (compiled code, intermediate artifacts) | Medium | `build-{{ hashFiles('src/**') }}` |
| **Docker layers** | High for image builds | Registry cache or BuildKit cache mount |
| **Tool binaries** (Terraform, kubectl) | Low — fast to download | `tools-terraform-1.15` |

### Cache Invalidation

- **Hash-based keys** — Cache key includes hash of dependency lock file. New dependencies = new cache.
- **TTL-based** — Expire caches after N days to prevent staleness.
- **Branch-scoped** — Caches isolated per branch to prevent pollution.

## Security in CI/CD

### OIDC / Keyless Authentication

Modern CI/CD platforms support OIDC federation — the pipeline assumes a cloud role without static credentials:

```
CI/CD Platform ──(JWT token)──> Cloud IAM Provider
                                    │
                              Validates token
                              (issuer, audience, claims)
                                    │
                              Issues temporary credentials
                                    │
                              CI job uses temp credentials
```

**Benefits:** No static secrets to rotate. Credentials scoped to the specific workflow/project. Audit trail of which pipeline assumed which role.

### Supply Chain Security

| Practice | Implementation |
|---|---|
| **Pin dependencies** | Lock files, hash verification |
| **Pin actions/images** | Use SHA, not tags (`actions/checkout@abc123` not `@v4`) |
| **SBOM generation** | Syft, CycloneDX, SPDX in pipeline |
| **Image signing** | Cosign, Notary v2 |
| **Provenance** | SLSA, in-toto attestations |
| **Dependency scanning** | Dependabot, Renovate, Snyk, Trivy |

### Secret Management in Pipelines

| Level | Mechanism | Scope |
|---|---|---|
| **Repository** | Encrypted secrets in CI config | Single repo |
| **Organization** | Org-level secrets/variables | All repos in org |
| **Environment** | Environment-scoped secrets | Specific deployment target |
| **External** | Vault, AWS Secrets Manager, Azure Key Vault | Cross-platform |

**Principle**: Secrets should be injected at runtime, never baked into artifacts or cached.

## Runner / Agent Architecture

### Hosted vs Self-Hosted

| Dimension | Hosted (Platform-Provided) | Self-Hosted |
|---|---|---|
| **Maintenance** | Zero — platform manages | You manage OS, patching, scaling |
| **Cost** | Per-minute billing | Infrastructure cost (EC2, on-prem) |
| **Customization** | Limited (pre-installed tools) | Full control (GPU, custom tools) |
| **Security** | Ephemeral (clean environment each job) | Persistent (requires hardening) |
| **Network** | Public internet access | Private network access (VPC, on-prem) |
| **Speed** | Depends on platform load | Depends on your infrastructure |

### Autoscaling Runners

For self-hosted runners that scale based on demand:

| Platform | Autoscaling Solution |
|---|---|
| GitHub Actions | Actions Runner Controller (ARC) on K8s |
| GitLab CI | Fleeting plugin, Docker autoscaler, K8s executor |
| Azure DevOps | VMSS agents, container agents |
| Jenkins | Kubernetes plugin, EC2 plugin, Docker plugin |

## Monorepo CI/CD

### Path-Based Triggers

Only build what changed:

```yaml
# GitHub Actions
on:
  push:
    paths:
      - 'services/api/**'

# GitLab CI
rules:
  - changes:
      - services/api/**
```

### Monorepo Challenges

| Challenge | Solution |
|---|---|
| Build everything on every change | Path filters + dependency graph |
| Slow pipelines | Parallel jobs, affected-only testing |
| Shared dependencies | Internal packages, build caching |
| Independent deployments | Per-service pipelines with dependency tracking |
