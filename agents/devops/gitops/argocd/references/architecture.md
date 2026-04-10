# ArgoCD Architecture

## Components

```
┌─────────────────────────────────────────────────────────┐
│                    ArgoCD Namespace                      │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │  API Server   │  │  Repo Server │  │  Application  │ │
│  │  (argocd-     │  │  (argocd-    │  │  Controller   │ │
│  │   server)     │  │   repo-      │  │  (argocd-     │ │
│  │              │  │   server)    │  │   application-│ │
│  │  - Web UI    │  │              │  │   controller) │ │
│  │  - gRPC API  │  │  - Git clone │  │              │ │
│  │  - REST API  │  │  - Helm      │  │  - Reconcile │ │
│  │  - Auth/RBAC │  │    template  │  │  - Health    │ │
│  │  - Webhook   │  │  - Kustomize │  │    checks    │ │
│  │    handler   │  │    build     │  │  - Sync ops  │ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘ │
│         │                 │                  │          │
│  ┌──────▼─────────────────▼──────────────────▼───────┐ │
│  │                    Redis                           │ │
│  │  (Cache: manifests, app state, repo state)         │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────┐  ┌──────────────────────────────┐  │
│  │  Dex (OIDC)    │  │  ApplicationSet Controller   │  │
│  │  SSO provider  │  │  (generates Applications     │  │
│  │                │  │   from templates)             │  │
│  └────────────────┘  └──────────────────────────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Notifications Controller                         │  │
│  │  (Slack, email, webhook, GitHub notifications)    │  │
│  └──────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

### API Server

The user-facing component:

- **Web UI**: React-based dashboard showing application topology, sync status, health
- **gRPC API**: Used by the `argocd` CLI and web UI
- **REST API**: HTTP gateway for the gRPC API
- **Authentication**: Local users, SSO (OIDC via Dex or direct OIDC), GitHub/GitLab/SAML
- **Authorization**: RBAC policies (Casbin) with project-level isolation
- **Webhook handler**: Receives Git webhooks to trigger immediate reconciliation

### Repo Server

Generates Kubernetes manifests from source:

- **Git operations**: Clone, fetch, checkout specific revisions
- **Manifest generation**:
  - Kustomize: `kustomize build`
  - Helm: `helm template` (never `helm install` — ArgoCD manages resources directly)
  - Plain YAML: Direct file listing
  - Jsonnet: `jsonnet` evaluation
  - Custom plugins: Config Management Plugins (CMP)
- **Caching**: Generated manifests cached in Redis (keyed by repo + revision + path)
- **Stateless**: Can be horizontally scaled for performance

### Application Controller

The brain of ArgoCD:

- **Reconciliation loop**: Continuously compares desired state (from repo server) against live state (from Kubernetes API)
- **Health assessment**: Evaluates resource health using built-in and custom health checks
- **Sync operations**: Creates, updates, and deletes Kubernetes resources
- **Pruning**: Removes resources that exist in the cluster but not in Git
- **Self-healing**: Reverts manual changes when `selfHeal: true`

### Reconciliation Flow

```
┌─────────────┐
│  Poll/Webhook│  Every 3 min (default) or on Git webhook
└──────┬──────┘
       │
┌──────▼──────┐
│  Repo Server │  Generate manifests from Git source
└──────┬──────┘
       │
┌──────▼──────┐
│  Compare     │  Diff desired (Git) vs live (K8s API)
└──────┬──────┘
       │
┌──────▼──────┐
│  Status      │  OutOfSync? Degraded? Progressing?
└──────┬──────┘
       │
   ┌───▼───┐
   │ Auto? │  Is automated sync enabled?
   └───┬───┘
       │
   Yes ▼        No ▼
┌──────────┐  ┌──────────┐
│  Sync    │  │  Notify  │  Wait for manual sync
│  (apply) │  │  (alert) │
└──────────┘  └──────────┘
```

## Multi-Cluster Architecture

### Cluster Registration

ArgoCD manages remote clusters by storing their credentials as Kubernetes Secrets:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: production-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: production
  server: https://production-api.example.com
  config: |
    {
      "bearerToken": "...",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "..."
      }
    }
```

### Scalability Considerations

| Component | Scaling Strategy |
|---|---|
| **API Server** | Horizontal (multiple replicas behind LB) |
| **Repo Server** | Horizontal (stateless, scales with Git operations) |
| **Application Controller** | Vertical primarily (one active controller per shard) |
| **Redis** | Vertical (or Redis Sentinel/Cluster for HA) |

### Sharding (Large Scale)

For 100+ applications, the Application Controller can be sharded:

```yaml
# Controller shard 0: manages apps with hash(name) % 2 == 0
# Controller shard 1: manages apps with hash(name) % 2 == 1
```

## Manifest Generation

### Config Management Plugins (CMP)

For custom manifest generation tools (Cue, Dhall, etc.):

```yaml
# Sidecar CMP plugin
apiVersion: v1
kind: ConfigMap
metadata:
  name: cmp-plugin
data:
  plugin.yaml: |
    apiVersion: argoproj.io/v1alpha1
    kind: ConfigManagementPlugin
    metadata:
      name: my-plugin
    spec:
      generate:
        command: [sh, -c, 'my-tool generate']
      discover:
        find:
          glob: "**/my-tool.yaml"
```

CMP runs as a sidecar container to the repo-server, communicating via Unix socket.

## Notification System

Built-in notification controller supports:

| Channel | Configuration |
|---|---|
| **Slack** | Bot token, channel |
| **Email** | SMTP server |
| **Webhook** | HTTP endpoint |
| **GitHub** | Check/commit status |
| **Teams** | Incoming webhook |

```yaml
# Notification trigger
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: my-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: alerts-channel
```
