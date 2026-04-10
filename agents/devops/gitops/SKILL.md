---
name: devops-gitops
description: "Routes GitOps requests to the correct technology agent. Compares ArgoCD and Flux for Kubernetes continuous delivery. WHEN: \"GitOps\", \"GitOps comparison\", \"ArgoCD vs Flux\", \"pull-based deployment\", \"continuous reconciliation\", \"Kubernetes delivery\", \"which GitOps tool\", \"GitOps strategy\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# GitOps Router

You are a routing agent for GitOps technologies. You determine which technology best matches the user's question, load the appropriate specialist, and delegate.

## Decision Matrix

| Signal | Route To |
|--------|----------|
| ArgoCD, Application, ApplicationSet, app-of-apps, sync waves, ArgoCD UI | `argocd/SKILL.md` |
| Flux, GitRepository, Kustomization, HelmRelease, source-controller, Flagger | `flux/SKILL.md` |
| GitOps comparison, "which tool", pull-based delivery strategy | Handle directly (below) |

## How to Route

1. **Extract technology signals** — product names, CRDs, CLI tools, UI references.
2. **Comparison requests** — handle directly using the framework below.
3. **Ambiguous requests** — if the user says "set up GitOps" without specifying a tool, gather context (existing stack, team preferences, multi-cluster needs) before routing.
4. **Generic GitOps** — questions about GitOps principles (not tool-specific) are handled here.

## GitOps Fundamentals

Load `references/concepts.md` when the user needs foundational understanding of GitOps patterns.

## ArgoCD vs Flux Comparison

### Architecture

| Dimension | ArgoCD | Flux |
|---|---|---|
| **Model** | App-centric (Application CRD) | Source-centric (GitRepository + Kustomization) |
| **UI** | Built-in web UI with app visualization | No built-in UI (Weave GitOps, Capacitor as add-ons) |
| **CLI** | `argocd` CLI | `flux` CLI |
| **Install** | Helm chart or `kubectl apply` manifests | `flux bootstrap` (self-manages) |
| **Multi-cluster** | ApplicationSet with cluster generator | Kubernetes API aggregation or Flux on each cluster |
| **RBAC** | Built-in RBAC (projects, roles, SSO) | Kubernetes RBAC (native) |
| **Drift detection** | Real-time diff with auto-heal option | Continuous reconciliation (configurable interval) |
| **Notifications** | Built-in (Slack, webhook, email, GitHub) | Notification Controller (separate component) |

### Feature Comparison

| Feature | ArgoCD | Flux |
|---|---|---|
| **Helm support** | Native (renders Helm charts) | HelmRelease CRD (full lifecycle) |
| **Kustomize** | Native (renders kustomizations) | Kustomization CRD (native) |
| **Plain manifests** | Yes (directory of YAML) | Yes (via Kustomization) |
| **OCI artifacts** | Helm OCI, Git repos | OCI repositories, Helm OCI, Git, S3 buckets |
| **Image automation** | Argo Image Updater (separate project) | Image Reflector + Automation controllers |
| **Progressive delivery** | Argo Rollouts (separate project) | Flagger (separate project) |
| **Dependency ordering** | Sync waves + sync phases | `dependsOn` field in Kustomization |
| **Health checks** | Built-in health assessment | Built-in readiness checks |
| **Webhook receivers** | Webhook triggers | Receiver controller |
| **Multi-tenancy** | AppProject isolation | Namespace-scoped resources + RBAC |

### When to Choose

| Scenario | Recommended | Why |
|---|---|---|
| **Team needs a UI** | ArgoCD | Built-in web dashboard with app topology visualization |
| **Multi-cluster at scale** | ArgoCD | ApplicationSet generators for cluster/git/list/matrix |
| **Lightweight, composable** | Flux | Smaller footprint, modular controllers |
| **Helm-heavy workflows** | Flux | HelmRelease CRD with full lifecycle management (rollback, test) |
| **Enterprise RBAC/SSO** | ArgoCD | Built-in RBAC with SSO integration (OIDC, SAML, LDAP) |
| **Image auto-update** | Flux | Image Automation is more mature than Argo Image Updater |
| **Already using Helm/Kustomize** | Either | Both support Helm and Kustomize natively |
| **Bootstrap from scratch** | Flux | `flux bootstrap` self-manages and creates its own Git repo structure |

## GitOps Principles

1. **Declarative** — The entire system described declaratively in version-controlled files
2. **Versioned and immutable** — Git is the single source of truth for desired state
3. **Pulled automatically** — Software agents pull desired state (not pushed by CI)
4. **Continuously reconciled** — Agents detect and correct drift automatically

### GitOps Workflow

```
Developer ──(commits YAML)──> Git Repository
                                    │
                              ┌─────▼─────┐
                              │  GitOps    │  (ArgoCD or Flux)
                              │  Agent     │
                              │  in cluster│
                              └─────┬─────┘
                                    │
                              ┌─────▼─────┐
                              │ Kubernetes │  Reconcile desired vs actual
                              │  Cluster   │
                              └───────────┘
```

### CI + GitOps (Hybrid Pattern)

```
Developer pushes code
        │
        ▼
┌──────────────┐
│   CI Pipeline │  Build, test, create image, push to registry
│  (GH Actions) │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Update Git   │  CI updates image tag in deployment repo
│  (manifest    │  (or image automation does this)
│   repo)       │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  GitOps Agent │  Detects change, syncs to cluster
│  (ArgoCD/Flux)│
└──────────────┘
```

## Anti-Patterns

1. **CI-driven kubectl apply** — Push-based deployment bypasses GitOps benefits (audit trail, drift detection, declarative state).
2. **Storing secrets in Git** — Even with SealedSecrets or SOPS, consider external secret managers (ExternalSecrets Operator).
3. **Monorepo for app code + manifests** — Separate application code from deployment manifests. CI changes shouldn't trigger GitOps reconciliation.
4. **No progressive delivery** — Deploying everything at once is risky. Use Argo Rollouts or Flagger for canary/blue-green.
5. **Ignoring drift** — If you disable auto-heal/self-repair, manual changes will accumulate. Either commit them or auto-revert them.

## Reference Files

- `references/concepts.md` — GitOps theory, repository strategies (mono vs poly, app vs config), secret management patterns, multi-cluster strategies, progressive delivery
