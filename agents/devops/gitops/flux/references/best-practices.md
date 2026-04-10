# Flux Best Practices

## Repository Structure

### Recommended Layout

```
fleet-config/
├── clusters/                    # Per-cluster entry points
│   ├── production/
│   │   ├── flux-system/         # Flux bootstrap output
│   │   │   ├── gotk-components.yaml
│   │   │   ├── gotk-sync.yaml
│   │   │   └── kustomization.yaml
│   │   ├── infrastructure.yaml  # Kustomization for infra
│   │   └── apps.yaml            # Kustomization for apps
│   └── staging/
│       ├── flux-system/
│       ├── infrastructure.yaml
│       └── apps.yaml
├── infrastructure/              # Cluster infrastructure
│   ├── controllers/             # Shared controllers
│   │   ├── cert-manager.yaml    # HelmRelease
│   │   ├── ingress-nginx.yaml   # HelmRelease
│   │   └── kustomization.yaml
│   ├── configs/                 # Shared configs
│   │   ├── cluster-issuer.yaml
│   │   └── kustomization.yaml
│   └── sources/                 # HelmRepository definitions
│       ├── bitnami.yaml
│       ├── jetstack.yaml
│       └── kustomization.yaml
└── apps/                        # Applications
    ├── base/
    │   ├── myapp/
    │   │   ├── deployment.yaml
    │   │   ├── service.yaml
    │   │   └── kustomization.yaml
    │   └── api/
    ├── staging/
    │   ├── myapp/
    │   │   ├── kustomization.yaml  # Patches for staging
    │   │   └── patch.yaml
    │   └── kustomization.yaml
    └── production/
        ├── myapp/
        │   ├── kustomization.yaml  # Patches for production
        │   └── patch.yaml
        └── kustomization.yaml
```

### Layered Kustomizations

```yaml
# clusters/production/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-sources
  namespace: flux-system
spec:
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure/sources
  prune: true

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-controllers
  namespace: flux-system
spec:
  interval: 1h
  dependsOn:
    - name: infrastructure-sources    # Sources must exist first
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure/controllers
  prune: true
  wait: true                          # Wait for controllers to be ready

---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-configs
  namespace: flux-system
spec:
  interval: 1h
  dependsOn:
    - name: infrastructure-controllers
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure/configs
  prune: true
```

## Helm Patterns

### HelmRelease with Values Management

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: myapp
spec:
  chart:
    spec:
      chart: myapp
      version: '>=1.0.0 <2.0.0'    # Accept any 1.x
      sourceRef:
        kind: HelmRepository
        name: myapp-repo
  # Base values
  values:
    replicaCount: 3
    image:
      repository: ghcr.io/org/myapp
  # Override from ConfigMap/Secret
  valuesFrom:
    - kind: ConfigMap
      name: myapp-env-values        # Environment-specific overrides
      valuesKey: values.yaml
    - kind: Secret
      name: myapp-secrets
      valuesKey: values.yaml
  # Upgrade strategy
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
    crds: CreateReplace
  # Rollback on failure
  rollback:
    cleanupOnFail: true
    recreate: false
```

### OCI Helm Charts

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: myapp-oci
spec:
  type: oci
  interval: 5m
  url: oci://ghcr.io/org/charts
  secretRef:
    name: ghcr-credentials
```

## Security

### Git Authentication

```bash
# SSH key (recommended)
flux create secret git git-credentials \
  --url=ssh://git@github.com/org/repo \
  --private-key-file=./id_ed25519

# GitHub token
flux create secret git git-credentials \
  --url=https://github.com/org/repo \
  --username=git \
  --password=${GITHUB_TOKEN}

# GitHub App
flux create secret git git-credentials \
  --url=https://github.com/org/repo \
  --github-app-id=${APP_ID} \
  --github-app-installation-id=${INSTALL_ID} \
  --github-app-private-key-file=./private-key.pem
```

### Secret Management

```yaml
# External Secrets Operator integration
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: external-secrets
spec:
  dependsOn:
    - name: infrastructure-controllers
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure/external-secrets
  decryption:
    provider: sops
    secretRef:
      name: sops-age    # Age key for SOPS decryption
```

### SOPS Integration

```yaml
# Kustomization with SOPS decryption
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
spec:
  decryption:
    provider: sops
    secretRef:
      name: sops-age    # Contains age private key
  # Flux will decrypt .sops.yaml files before applying
```

### Git Commit Verification

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: app-config
spec:
  verify:
    provider: cosign    # or 'gpg'
    secretRef:
      name: cosign-key
  # Only accept commits signed by trusted keys
```

## Multi-Cluster

### Same Repo, Different Paths

```
fleet-config/
├── clusters/
│   ├── cluster-a/
│   │   ├── flux-system/
│   │   ├── apps.yaml       # Points to apps/cluster-a/
│   │   └── infra.yaml
│   └── cluster-b/
│       ├── flux-system/
│       ├── apps.yaml       # Points to apps/cluster-b/
│       └── infra.yaml
├── apps/
│   ├── base/               # Shared base
│   ├── cluster-a/          # Cluster-specific overlays
│   └── cluster-b/
└── infrastructure/
    ├── base/
    ├── cluster-a/
    └── cluster-b/
```

Each cluster runs its own Flux instance, bootstrapped with a different `--path`.

### Variable Substitution for Cluster Config

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
spec:
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-config
    substitute:
      CLUSTER_NAME: production-us-east-1
      DOMAIN: us-east-1.example.com
```

```yaml
# In the applied manifests, ${CLUSTER_NAME} and ${DOMAIN} are replaced
apiVersion: networking.k8s.io/v1
kind: Ingress
spec:
  rules:
    - host: myapp.${DOMAIN}
```

## Performance

### Reconciliation Intervals

| Resource | Recommended Interval | Why |
|---|---|---|
| **GitRepository** | 5m | Reasonable polling frequency |
| **HelmRepository** | 24h | Charts don't change frequently |
| **Kustomization** (infra) | 1h | Infrastructure changes rarely |
| **Kustomization** (apps) | 10m | Applications change more often |
| **HelmRelease** | 30m | Catch up on chart/values changes |

With Git webhooks configured via Receiver, the interval becomes the fallback only.

### Webhook Receivers

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: github-webhook
  namespace: flux-system
spec:
  type: github
  events:
    - ping
    - push
  secretRef:
    name: webhook-token
  resources:
    - kind: GitRepository
      name: app-config
```

## Common Mistakes

1. **Confusing Flux Kustomization with Kustomize** — Flux's `Kustomization` CRD wraps `kustomize build` but is a different resource.
2. **Not using `dependsOn`** — Without dependencies, CRDs may apply before their controllers are ready.
3. **Not enabling `prune`** — Without pruning, removed resources persist in the cluster.
4. **Mixing `flux` CLI and direct `kubectl apply`** — Let Flux manage all resources. Manual `kubectl apply` causes drift.
5. **Not setting `wait: true`** — Without waiting, downstream Kustomizations may start before upstream resources are healthy.
6. **Large monolithic Kustomizations** — Break into smaller, independently reconcilable units for faster feedback and smaller blast radius.
