# Flux CD Architecture

## Controller Design

Flux is composed of specialized controllers, each responsible for a specific aspect of the GitOps pipeline:

```
┌────────────────────────────────────────────────────────────────┐
│                     Flux System Namespace                       │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────┐                  │
│  │ Source Controller │   │ Kustomize Ctrl   │                  │
│  │                  │   │                  │                  │
│  │ GitRepository    │──▶│ Kustomization    │──▶ K8s API       │
│  │ HelmRepository   │   │ (apply manifests)│                  │
│  │ OCIRepository    │   └──────────────────┘                  │
│  │ Bucket           │                                          │
│  └──────────────────┘   ┌──────────────────┐                  │
│           │              │ Helm Controller  │                  │
│           └─────────────▶│                  │──▶ K8s API       │
│                          │ HelmRelease      │                  │
│                          │ (helm upgrade)   │                  │
│                          └──────────────────┘                  │
│                                                                 │
│  ┌──────────────────┐   ┌──────────────────┐                  │
│  │ Notification Ctrl│   │ Image Reflector  │                  │
│  │                  │   │                  │                  │
│  │ Provider, Alert  │   │ ImageRepository  │                  │
│  │ Receiver         │   │ ImagePolicy      │                  │
│  └──────────────────┘   └────────┬─────────┘                  │
│                                   │                             │
│                          ┌────────▼─────────┐                  │
│                          │ Image Automation  │                  │
│                          │                  │──▶ Git Push      │
│                          │ ImageUpdate      │                  │
│                          │  Automation      │                  │
│                          └──────────────────┘                  │
└────────────────────────────────────────────────────────────────┘
```

### Controller Responsibilities

| Controller | Watches | Does |
|---|---|---|
| **Source** | GitRepository, HelmRepository, OCIRepository, Bucket | Fetches artifacts, stores locally, produces Artifact objects |
| **Kustomize** | Kustomization | Runs `kustomize build`, applies to cluster, prunes deleted resources |
| **Helm** | HelmRelease | Runs Helm install/upgrade/rollback, manages release lifecycle |
| **Notification** | Provider, Alert, Receiver | Dispatches events to external systems, receives webhooks |
| **Image Reflector** | ImageRepository, ImagePolicy | Scans container registries, resolves latest image tag |
| **Image Automation** | ImageUpdateAutomation | Updates image references in Git, commits and pushes |

## Reconciliation Loop

### Source Reconciliation

```
┌─────────────┐     ┌──────────────────┐     ┌──────────────┐
│ GitRepository│────▶│ Clone/Fetch repo │────▶│ Create       │
│ (spec)       │     │ at interval      │     │ Artifact     │
└─────────────┘     └──────────────────┘     │ (tarball)    │
                                              └──────┬───────┘
                                                     │
                                              ┌──────▼───────┐
                                              │ Store in     │
                                              │ /data/       │
                                              │ (local FS)   │
                                              └──────────────┘
```

### Kustomization Reconciliation

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│ Kustomization│────▶│ Download source  │────▶│ kustomize    │
│ (spec)       │     │ artifact         │     │ build        │
└──────────────┘     └──────────────────┘     └──────┬───────┘
                                                      │
                                              ┌───────▼──────┐
                                              │ Variable     │
                                              │ substitution │
                                              │ (postBuild)  │
                                              └───────┬──────┘
                                                      │
                                              ┌───────▼──────┐
                                              │ kubectl apply│
                                              │ (server-side │
                                              │  or client)  │
                                              └───────┬──────┘
                                                      │
                                              ┌───────▼──────┐
                                              │ Health check │
                                              │ (wait for    │
                                              │  readiness)  │
                                              └───────┬──────┘
                                                      │
                                              ┌───────▼──────┐
                                              │ Prune        │
                                              │ (delete      │
                                              │  removed)    │
                                              └──────────────┘
```

### HelmRelease Reconciliation

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│ HelmRelease  │────▶│ Download chart   │────▶│ Merge values │
│ (spec)       │     │ from source      │     │ (inline +    │
└──────────────┘     └──────────────────┘     │  valuesFrom) │
                                              └──────┬───────┘
                                                     │
                                              ┌──────▼───────┐
                                              │ helm upgrade │
                                              │ --install    │
                                              └──────┬───────┘
                                                     │
                                              ┌──────▼───────┐
                                              │ helm test    │
                                              │ (if enabled) │
                                              └──────┬───────┘
                                                     │
                                              ┌──────▼───────┐
                                              │ Remediation  │
                                              │ (rollback on │
                                              │  failure)    │
                                              └──────────────┘
```

## Source Types

### GitRepository

| Feature | Detail |
|---|---|
| **Protocols** | HTTPS, SSH, Git protocol |
| **Authentication** | SSH key, HTTP basic, token, GitHub/GitLab App |
| **Verification** | Git commit signature verification (GPG, Sigstore) |
| **Include** | Include files from other GitRepository sources |
| **Ignore** | `.sourceignore` file or `spec.ignore` |

### OCI Repository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: app-manifests
spec:
  interval: 5m
  url: oci://ghcr.io/org/manifests
  ref:
    tag: latest
    semver: '>=1.0.0'
```

OCI repositories allow storing Kubernetes manifests as OCI artifacts (like container images but for config).

### Bucket

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: Bucket
metadata:
  name: configs
spec:
  interval: 10m
  provider: aws    # or generic, gcp, azure
  bucketName: my-configs
  endpoint: s3.amazonaws.com
  region: us-east-1
```

## Multi-Tenancy Model

Flux's multi-tenancy is based on Kubernetes RBAC:

```yaml
# Tenant namespace with service account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-frontend
  namespace: frontend-apps

---
# Kustomization scoped to tenant
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: frontend-apps
  namespace: frontend-apps
spec:
  serviceAccountName: team-frontend    # Runs with tenant's permissions
  sourceRef:
    kind: GitRepository
    name: frontend-config
    namespace: flux-system    # Sources can be shared
  path: ./apps
  targetNamespace: frontend-apps
```

### Tenant Isolation

| Layer | Mechanism |
|---|---|
| **Namespace** | Each tenant gets their own namespace |
| **Service Account** | Kustomization/HelmRelease uses tenant SA |
| **RBAC** | SA bound to specific namespaces via RoleBinding |
| **Network Policy** | Restrict pod-to-pod communication |
| **Resource Quota** | Limit tenant resource consumption |

## Artifact Storage

Source controller stores fetched artifacts locally:

```
/data/
├── gitrepository/
│   └── flux-system/
│       └── app-config/
│           └── <sha>.tar.gz
├── helmrepository/
│   └── flux-system/
│       └── ingress-nginx/
│           └── index-<hash>.yaml
└── ocirepository/
    └── flux-system/
        └── app-manifests/
            └── <digest>.tar.gz
```

Artifacts are served via HTTP to other controllers within the cluster.
