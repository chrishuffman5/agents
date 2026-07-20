---
name: orchestration
description: "Compares container orchestration platforms -- Kubernetes, managed Kubernetes (EKS, AKS, GKE), OpenShift, Rancher, and Helm -- to help pick or evaluate a platform. Use for \"orchestration\", \"Kubernetes vs\", \"which orchestrator\", \"managed Kubernetes\", \"container platform\", \"EKS or AKS or GKE\", \"cluster management\", \"orchestration comparison\", \"pick a platform\", \"container scheduling\". Do NOT use for implementation questions about a specific platform -- use the `kubernetes`, `helm`, `eks`, `aks`, `gke`, `openshift`, or `rancher` skill."
license: MIT
---

# Container Orchestration Overview

This skill covers container orchestration technology selection. Use it to determine which technology best matches a question, then read the matching skill below for implementation depth.

## Decision Matrix

| Signal | Skill |
|--------|----------|
| Kubernetes core (pods, deployments, services, RBAC, scheduling, networking) | `kubernetes` |
| Helm charts, templates, values, Helmfile, helm-secrets | `helm` |
| Amazon EKS, Karpenter on AWS, IRSA, Fargate, VPC CNI, EKS Anywhere | `eks` |
| Azure AKS, workload identity (Azure), Azure CNI, AKS Automatic | `aks` |
| Google GKE, Autopilot, Config Sync, Policy Controller, GKE Enterprise | `gke` |
| OpenShift, OCP, OKD, Routes, SCC, BuildConfigs, OLM, ImageStreams | `openshift` |
| Rancher, RKE2, K3s, Fleet GitOps, Harvester, multi-cluster at scale | `rancher` |

## How to Route

1. **Extract technology signals** from the user's question -- product names, CLI tools, API resources, cloud provider context.
2. **Check for version specifics** -- if a Kubernetes version is mentioned (1.34, 1.35), read the `kubernetes` skill, which further points to the version-specific reference under its Version-specific guidance section.
3. **Comparison requests** -- if the user is comparing platforms, handle directly using the comparison framework below; no need to read a technology skill.
4. **Ambiguous requests** -- if the user says "Kubernetes" but the context is clearly EKS/AKS/GKE-specific (mentions AWS resources, Azure networking, GCP billing), read the matching managed-provider skill.

## Orchestration Fundamentals

Load `references/concepts.md` when the user needs foundational understanding of orchestration patterns that apply across all platforms.

## Platform Comparison Framework

Use this when users ask "which platform should I use" or "X vs Y":

### Self-Managed Kubernetes

**When to choose**: Full control over control plane. Air-gapped or highly regulated environments. Avoidance of cloud vendor lock-in. Custom control plane configurations (non-standard admission controllers, custom schedulers).

**Trade-offs**: You own upgrades, etcd backups, HA, certificate rotation. Significant operational burden. Requires dedicated platform team.

**Distributions**: kubeadm (upstream), RKE2 (CIS-hardened), K3s (lightweight/edge).

### Managed Kubernetes (EKS, AKS, GKE)

**When to choose**: Cloud-native workloads. Desire to offload control plane operations. Integration with cloud provider IAM, networking, storage, and observability. Team prefers to focus on applications over infrastructure.

| Dimension | EKS | AKS | GKE |
|-----------|-----|-----|-----|
| Control plane SLA | 99.95% (uptime) | 99.95% (free tier: 99.5%) | 99.95% (regional) |
| Node autoscaling | Karpenter (recommended) or CA | Karpenter (NAP, GA 2026) or CA | NAP (CA-based) or CA |
| Serverless pods | Fargate | Virtual Nodes (ACI) | Autopilot mode |
| IAM integration | IRSA / Pod Identity | Workload Identity | Workload Identity Federation |
| Default CNI | VPC CNI (pod IPs from VPC) | Azure CNI / kubenet | GKE CNI (VPC-native) |
| GitOps built-in | Flux (add-on) | Flux (add-on) | Config Sync (Enterprise) |
| Policy engine | OPA/Gatekeeper (add-on) | Azure Policy (built-in) | Policy Controller (Enterprise) |
| Cost model | Per-cluster ($0.10/hr) + nodes | Free control plane + nodes | Per-cluster ($0.10/hr) + nodes; Autopilot: per-pod |
| Best for | AWS-heavy orgs, Karpenter-first | Azure/hybrid orgs, .NET workloads | GCP orgs, ML/AI, Autopilot simplicity |

### OpenShift

**When to choose**: Enterprise requiring integrated CI/CD (S2I builds), operator marketplace, hardened-by-default security (SCC), integrated monitoring/logging stack, and Red Hat enterprise support. Common in financial services, government, and regulated industries.

**Trade-offs**: Higher licensing cost. Opinionated platform -- some upstream K8s patterns work differently (Routes vs Ingress, SCC vs PSS). Slower version adoption (typically 1-2 K8s versions behind upstream).

### Rancher

**When to choose**: Multi-cluster management across clouds and on-prem. Centralized RBAC and policy for dozens to hundreds of clusters. Edge deployments (K3s). Need to manage heterogeneous cluster types (EKS + AKS + on-prem RKE2) from a single pane.

**Trade-offs**: Rancher is a management layer, not a distribution itself (uses RKE2/K3s underneath). Fleet GitOps is powerful but adds complexity. Rancher server is a single point of management failure (deploy HA).

### Lightweight / Edge

**When to choose**: Edge locations, IoT gateways, CI/CD runners, development environments. Resource-constrained nodes (ARM, <2GB RAM).

| Distribution | Binary Size | Default Store | Target |
|-------------|-------------|---------------|--------|
| K3s | <100MB | SQLite | Edge, IoT, dev |
| MicroK8s | ~200MB | dqlite | Dev, single-node |
| Kind | N/A (Docker) | N/A | CI/CD testing |
| Minikube | ~300MB | etcd | Local dev |

## Disambiguation Patterns

- "I need to deploy containers" -- ask whether they have an existing cluster or need to choose a platform.
- "Kubernetes help" with no cloud context -- read the `kubernetes` skill.
- "Kubernetes on AWS" -- read the `eks` skill.
- "Deploy to my cluster" with Helm chart context -- read the `helm` skill.
- "Manage multiple clusters" -- explore Rancher vs cloud-native multi-cluster (GKE Enterprise, EKS with ArgoCD).
- "OpenShift or Kubernetes" -- handle as comparison using the framework above.

## Cross-Cutting Concerns

These topics span multiple orchestration technologies:

| Concern | Where Covered |
|---------|---------------|
| Service mesh (Istio, Linkerd, Consul) | the `service-mesh` skill |
| GitOps (ArgoCD, Flux) | devops domain; Fleet covered in the `rancher` skill |
| Container security scanning | security domain |
| Monitoring and observability | monitoring domain |
| Container images and registries | the `runtimes` skill |

## Reference Files

- `references/concepts.md` -- Orchestration fundamentals: desired state, reconciliation loops, operators, CRDs, admission control. Load when user needs conceptual understanding.

## Related Skills

- `kubernetes` -- Core Kubernetes (all versions). Architecture, workloads, networking, storage, security, scheduling.
- `helm` -- Helm package manager. Charts, templates, OCI registries, Helmfile, helm-secrets.
- `eks` -- Amazon EKS. Managed control plane, Karpenter, Fargate, IRSA, VPC CNI.
- `aks` -- Azure AKS. Node pools, workload identity, Azure CNI, AKS Automatic.
- `gke` -- Google GKE. Autopilot, Config Sync, Policy Controller, GKE Enterprise.
- `openshift` -- Red Hat OpenShift. OLM, Routes, SCC, BuildConfigs, ImageStreams.
- `rancher` -- SUSE Rancher. Multi-cluster, RKE2, K3s, Fleet GitOps, Harvester.
