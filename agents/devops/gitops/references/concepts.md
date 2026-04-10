# GitOps Concepts

## Repository Strategies

### App Repo vs Config Repo

| Strategy | Structure | Pros | Cons |
|---|---|---|---|
| **Monorepo** | App code + K8s manifests in same repo | Simple, atomic changes | CI commits trigger GitOps reconciliation |
| **Separate repos** | App code in one repo, manifests in another | Clean separation, CI doesn't trigger deploy | Extra repo to manage, cross-repo coordination |

**Recommendation**: Use separate repos. The app repo is for developers (code changes). The config repo is for ops (deployment state). CI builds the image and updates the config repo.

### Config Repo Structure

```
# Environment-per-directory (recommended)
config-repo/
├── base/                    # Shared base manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── production/
│       ├── kustomization.yaml
│       └── patches/
└── clusters/                # Cluster-level config
    ├── cluster-a/
    │   └── flux-system/     # or argocd apps
    └── cluster-b/
```

### Branch Strategy for GitOps

| Strategy | How | When |
|---|---|---|
| **Single branch + directories** | All envs in one branch, different directories | Simplest, recommended for most |
| **Branch per environment** | dev, staging, prod branches | Legacy, avoid (merge conflicts) |
| **Tag-based promotion** | Tag a commit to promote to next env | Release-oriented products |

**Recommendation**: Single branch with directory-based environment separation. Promotion = update the image tag in the next environment's overlay.

## Secret Management in GitOps

Secrets are the hardest part of GitOps — you can't store plaintext secrets in Git.

### Options

| Approach | How | Pros | Cons |
|---|---|---|---|
| **SealedSecrets** | Encrypt with cluster public key, store in Git | Simple, Git-native | Cluster-specific encryption, key rotation complexity |
| **SOPS** (Mozilla) | Encrypt with KMS/PGP/age, store in Git | Multi-provider KMS, partial encryption | Must decrypt before apply, key management |
| **External Secrets Operator** | CRD syncs secrets from Vault/AWS/Azure/GCP | Centralized, auto-rotation, multi-cluster | Additional operator, external dependency |
| **Vault Agent Injector** | Vault sidecar injects secrets at runtime | Dynamic secrets, centralized audit | Vault dependency, sidecar overhead |

**Recommendation**: External Secrets Operator for most production setups. SealedSecrets for simple/small deployments.

```yaml
# ExternalSecret example
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: /production/database
        property: password
```

## Multi-Cluster Strategies

### Hub-and-Spoke (ArgoCD)

```
                ┌───────────────┐
                │  Management   │
                │  Cluster      │
                │  (ArgoCD hub) │
                └───────┬───────┘
                        │
          ┌─────────────┼─────────────┐
          │             │             │
    ┌─────▼─────┐ ┌────▼────┐ ┌─────▼─────┐
    │ Cluster A │ │Cluster B│ │ Cluster C │
    │  (spoke)  │ │ (spoke) │ │  (spoke)  │
    └───────────┘ └─────────┘ └───────────┘
```

ArgoCD runs on the management cluster and deploys to spoke clusters via their API servers.

### Per-Cluster (Flux)

```
    ┌───────────┐ ┌─────────┐ ┌───────────┐
    │ Cluster A │ │Cluster B│ │ Cluster C │
    │  (Flux)   │ │ (Flux)  │ │  (Flux)   │
    └─────┬─────┘ └────┬────┘ └─────┬─────┘
          │            │            │
          └────────────┼────────────┘
                       │
                 ┌─────▼─────┐
                 │ Git Repo  │
                 │ (shared)  │
                 └───────────┘
```

Each cluster runs its own Flux instance, all pointing to the same Git repo with cluster-specific paths.

### Comparison

| Aspect | Hub-and-Spoke | Per-Cluster |
|---|---|---|
| **Single pane of glass** | Yes (ArgoCD UI) | No (per-cluster views) |
| **Blast radius** | Hub failure affects all | Each cluster independent |
| **Network requirements** | Hub needs API access to all clusters | Each cluster needs Git access only |
| **Scaling** | Centralized management | Scales independently |

## Progressive Delivery

### Argo Rollouts (with ArgoCD)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 10      # 10% traffic to canary
        - pause: { duration: 5m }
        - setWeight: 30
        - pause: { duration: 5m }
        - setWeight: 60
        - pause: { duration: 5m }
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable
```

### Flagger (with Flux)

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  progressDeadlineSeconds: 60
  service:
    port: 80
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
```

## Drift Detection and Remediation

### Drift Types

| Type | Description | Example |
|---|---|---|
| **Config drift** | Manual change to a resource | Someone scaled a deployment via `kubectl scale` |
| **State drift** | Resource state diverges from desired | Pod crashlooping, PVC pending |
| **Schema drift** | CRD or API version changes | K8s upgrade deprecates an API version |

### Remediation Strategies

| Strategy | How | Risk |
|---|---|---|
| **Auto-heal (self-repair)** | Agent reverts manual changes automatically | Reverts intentional emergency changes |
| **Detect and alert** | Agent detects drift, notifies human | Drift persists until human acts |
| **Hybrid** | Auto-heal for config, alert for state | More complex configuration |

**Best practice**: Enable auto-heal for configuration drift. Use alerts for state drift (crashloops, resource exhaustion).
