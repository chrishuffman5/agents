# DevOps Foundational Concepts

## CI/CD Pipeline Theory

### Continuous Integration (CI)

CI ensures that code changes integrate cleanly and pass quality gates before merging:

1. **Source** -- Developer pushes to a branch or opens a pull request
2. **Build** -- Compile, transpile, or package the application
3. **Test** -- Unit tests, integration tests, static analysis, linting
4. **Report** -- Publish results (test coverage, build artifacts, status checks)

**Key principle**: The CI pipeline must be fast (under 10 minutes ideally). Slow pipelines reduce merge frequency and increase batch sizes, defeating the purpose of CI.

### Continuous Delivery (CD)

CD extends CI to ensure every successful build is deployable:

1. **Artifact** -- Immutable versioned artifact (container image, package, binary)
2. **Staging** -- Deploy to a pre-production environment and run acceptance tests
3. **Approval** -- Manual gate (continuous delivery) or automatic (continuous deployment)
4. **Production** -- Deploy using a safe strategy (canary, blue-green, rolling)
5. **Verify** -- Smoke tests, health checks, observability validation

**Continuous Delivery vs Continuous Deployment**: Delivery means every commit *can* go to production (manual gate). Deployment means every commit *does* go to production (automatic). Most organizations practice delivery, not deployment.

## Deployment Strategies

### Rolling Update

Replace instances one at a time. The default in Kubernetes (Deployment strategy).

- **Pros**: Zero downtime, gradual rollout, resource-efficient
- **Cons**: Multiple versions running simultaneously during rollout, rollback is another rolling update
- **Best for**: Stateless services with backward-compatible changes

### Blue-Green Deployment

Run two identical environments. Route traffic from blue (current) to green (new) atomically.

- **Pros**: Instant rollback (switch back to blue), full environment validation before switch
- **Cons**: Double infrastructure cost during deployment, database migrations complicate this
- **Best for**: Critical services where rollback speed matters

### Canary Deployment

Route a small percentage of traffic to the new version. Gradually increase if metrics are healthy.

- **Pros**: Minimal blast radius, real traffic validation, data-driven promotion
- **Cons**: Requires traffic splitting (service mesh or ingress), metrics infrastructure, longer rollout
- **Best for**: High-traffic services, risk-averse organizations

### Feature Flags

Deploy code but control feature visibility at runtime via configuration.

- **Pros**: Decouple deployment from release, instant kill switch, A/B testing
- **Cons**: Technical debt if not cleaned up, testing complexity, flag management overhead
- **Best for**: Product-driven organizations, gradual feature rollouts

## Environment Management

### Environment Hierarchy

| Environment | Purpose | Fidelity | Access |
|---|---|---|---|
| **Local/Dev** | Developer workstation | Low | Individual |
| **CI** | Automated testing | Medium | Pipeline |
| **Staging/Pre-prod** | Production mirror | High | Team |
| **Production** | Live traffic | N/A | Restricted |

### Environment Promotion

Code should flow in one direction: dev --> staging --> production. Never hotfix production directly. Even emergency fixes go through an expedited pipeline.

**Environment parity principle**: The closer staging mirrors production (same infra, same config, same data shape), the more confidence you have in deployments. Differences between environments are where bugs hide.

## Pipeline Design Patterns

### Trunk-Based Development

All developers merge to a single main branch (trunk). Short-lived feature branches (< 1 day ideally). Requires feature flags for incomplete work.

- **Pros**: Reduces merge conflicts, faster integration, simpler branching model
- **Cons**: Requires discipline, feature flags add complexity
- **Pair with**: CI that runs on every push, feature flags, automated testing

### GitFlow

Long-lived develop and release branches. Feature branches merge to develop, release branches cut from develop.

- **Pros**: Clear release process, parallel release maintenance
- **Cons**: Merge conflicts, delayed integration, complex branching
- **Pair with**: Release-oriented products, multiple supported versions

### Environment Branches

Separate branches per environment (dev, staging, main). Merge up to promote.

- **Pros**: Simple mental model, clear what's deployed where
- **Cons**: Merge conflicts, drift between environments, cherry-pick complexity
- **Pair with**: Simple applications, small teams

## Secret Management

### Principles

1. **Never store secrets in Git** -- Not in code, not in config files, not even encrypted (encrypted secrets in Git are still a single breach away)
2. **Inject at runtime** -- Secrets come from a secret manager at deployment time, not build time
3. **Rotate regularly** -- Automated rotation with zero-downtime key rollover
4. **Least privilege** -- Each service gets only the secrets it needs
5. **Audit access** -- Log who accessed which secret and when

### Common Patterns

| Pattern | How | When |
|---|---|---|
| **Environment variables** | CI injects secrets as env vars at runtime | Simple apps, twelve-factor |
| **Mounted files** | Secret manager syncs to a file/volume | Kubernetes (ExternalSecrets, CSI driver) |
| **API fetch** | App calls secret manager API at startup | Complex apps needing dynamic secrets |
| **OIDC federation** | Workload identity, no static credentials | Cloud-native (GitHub OIDC, K8s workload identity) |

## Infrastructure as Code Concepts

### State Management

IaC tools that maintain state (Terraform, Pulumi) need careful handling:

- **Remote state** -- Store state in a shared backend (S3, GCS, Azure Blob, Terraform Cloud)
- **State locking** -- Prevent concurrent modifications (DynamoDB for S3, native for cloud backends)
- **State isolation** -- Separate state per environment/component to limit blast radius
- **State drift** -- Infrastructure changes outside IaC cause drift. Detect with `terraform plan` / `pulumi preview`

### Idempotency

A core IaC principle: applying the same configuration multiple times produces the same result. Declarative tools (Terraform, CloudFormation) are idempotent by design. Procedural tools (Ansible) require careful task design to achieve idempotency.

### Immutable vs Mutable Infrastructure

| Approach | How | Pros | Cons |
|---|---|---|---|
| **Mutable** | Patch/update existing servers in-place | Faster for small changes, familiar | Configuration drift, snowflake servers |
| **Immutable** | Replace servers entirely on every change | Predictable, reproducible, no drift | Slower deploys, requires automation |

Modern practice favors immutable infrastructure: build a new AMI/image, deploy it, destroy the old one. Ansible bridges both worlds — it can configure mutable servers or build immutable images.

## GitOps Principles

1. **Declarative** -- The entire system described declaratively (YAML, HCL, Kustomize)
2. **Versioned and immutable** -- Desired state stored in Git. Git is the source of truth.
3. **Pulled automatically** -- Software agents (ArgoCD, Flux) automatically pull desired state and apply it
4. **Continuously reconciled** -- Agents continuously compare desired vs actual state and correct drift

### Push vs Pull Model

| Aspect | Push (CI-driven) | Pull (GitOps) |
|---|---|---|
| **Who deploys** | CI pipeline (external) | Agent in cluster (internal) |
| **Credential scope** | CI needs cluster credentials | Agent has in-cluster access only |
| **Drift detection** | Only on pipeline run | Continuous reconciliation |
| **Audit trail** | CI logs | Git history |
| **Rollback** | Re-run old pipeline or `git revert` | `git revert` (automatic) |
