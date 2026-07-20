---
name: overview
description: "Top-level entry point for all container and orchestration technologies -- containerization, Kubernetes, service mesh, container security, and cloud-native architecture -- for cross-platform or architectural questions. Use for \"container\", \"Docker\", \"Kubernetes\", \"K8s\", \"pod\", \"Helm chart\", \"container orchestration\", \"service mesh\", \"Istio\", \"container image\", \"Dockerfile\", \"kubectl\", \"deployment\", \"statefulset\" when no specific technology is named or the question spans multiple technologies. Do NOT use for technology-specific implementation questions -- use the matching technology skill (e.g. `kubernetes`, `docker`, `istio`) or the `orchestration`/`runtimes`/`service-mesh` skill for platform comparisons."
license: MIT
---

# Containers & Orchestration Domain Agent

This skill is the top-level entry point for all container and orchestration technologies, covering containerization, Kubernetes, service mesh, container security, and cloud-native architecture. It points to the technology-specific skills for deep implementation details.

## When to Use This Skill vs. a Technology Skill

**Use this skill when the question is cross-platform or architectural:**
- "Should I use Docker or Podman?"
- "Design a container platform for our organization"
- "Compare managed Kubernetes services (EKS vs AKS vs GKE)"
- "Do I need a service mesh?"
- "Container security strategy"
- "Migration from VMs to containers"

**Read the matching technology skill when the question is technology-specific:**
- "Optimize my Dockerfile" --> the `docker` skill
- "Kubernetes deployment not rolling out" --> the `kubernetes` skill
- "Helm chart dependency management" --> the `helm` skill
- "Istio traffic routing" --> the `istio` skill
- "Podman rootless networking" --> the `podman` skill
- "EKS Karpenter autoscaling" --> the `eks` skill

## How to Approach Tasks

1. **Classify** the request:
   - **Architecture / Platform design** -- See the concepts references in the `orchestration`, `runtimes`, and `service-mesh` skills
   - **Container runtime** -- Read the `docker`, `podman`, or `containerd` skill
   - **Orchestration** -- Read the `kubernetes`, `helm`, or matching managed-K8s skill
   - **Service mesh** -- Read the `istio`, `linkerd`, or `consul` skill
   - **Security** -- Cross-reference with the security domain's container-security skill

2. **Gather context** -- Scale, team expertise, cloud vs on-prem, compliance, existing infrastructure

3. **Analyze** -- Apply cloud-native principles (12-factor, immutable infrastructure, declarative config)

4. **Recommend** -- Actionable guidance with trade-offs

## Container Architecture Decision Framework

### When to Containerize

| Workload | Containerize? | Why |
|---|---|---|
| Stateless web services | Yes | Natural fit — horizontal scaling, fast deployment |
| Microservices | Yes | Isolation, independent deployment, polyglot |
| CI/CD pipelines | Yes | Reproducible builds, ephemeral environments |
| Batch jobs | Yes | Resource efficiency, scheduling via K8s Jobs |
| Stateful databases | Maybe | Operators help (CloudNativePG, Percona), but adds complexity |
| Legacy monoliths | Maybe | Lift-and-shift works but misses cloud-native benefits |
| GUI applications | Rarely | Desktop apps need display server; consider containers for backend only |
| Kernel-dependent workloads | No | Containers share the host kernel |

### Runtime Selection

| Runtime | Best For | Trade-offs |
|---|---|---|
| Docker Engine | Development, CI/CD, single-host | Daemon-based, Docker-specific features |
| Podman | RHEL/Fedora, rootless, systemd integration | Smaller ecosystem, some Docker compat gaps |
| containerd | Kubernetes CRI, minimal runtime | No build tools (use BuildKit separately) |
| CRI-O | OpenShift, minimal K8s-only runtime | K8s-only, no standalone use |

### Orchestration Selection

| Platform | Best For | Trade-offs |
|---|---|---|
| Kubernetes (self-managed) | Full control, multi-cloud, hybrid | Operational complexity, requires expertise |
| EKS | AWS-native, Karpenter, Fargate | AWS lock-in, control plane cost |
| AKS | Azure-native, free control plane | Azure lock-in, networking complexity (CNI choices) |
| GKE Autopilot | Minimal ops, Google SRE management | Less control, pod-level billing |
| OpenShift | Enterprise, regulated industries, Operators | Expensive, opinionated, heavier footprint |
| K3s/RKE2 | Edge, IoT, lightweight clusters | Fewer features, smaller community |
| Docker Compose | Single-host, development, small projects | No HA, no scaling, not production-grade |

## Subcategory Routing

| Request Pattern | Skill |
|---|---|
| **Container Runtimes** | |
| Docker, Dockerfile, docker-compose, BuildKit | `docker` |
| Podman, rootless, Quadlet, podman-compose | `podman` |
| containerd, nerdctl, CRI, snapshotter | `containerd` |
| **Orchestration** | |
| Kubernetes, kubectl, pods, deployments, services | `kubernetes` |
| Helm, charts, values, releases, Helmfile | `helm` |
| Amazon EKS, Karpenter, Fargate, EKS Anywhere | `eks` |
| Azure AKS, node pools, workload identity | `aks` |
| Google GKE, Autopilot, Config Sync | `gke` |
| OpenShift, OCP, Operators, Routes, SCC | `openshift` |
| Rancher, RKE2, K3s, Fleet | `rancher` |
| **Service Mesh** | |
| Istio, VirtualService, ambient mesh, Envoy sidecar | `istio` |
| Linkerd, linkerd2-proxy, service profiles | `linkerd` |
| Consul Connect, intentions, Consul on K8s | `consul` |

## Cloud-Native Principles

1. **Immutable infrastructure** -- Never patch running containers. Build new images, deploy, replace.
2. **Declarative configuration** -- Define desired state in YAML/HCL. Let controllers reconcile.
3. **12-factor app design** -- Config via env vars, stateless processes, disposable, dev/prod parity.
4. **Observability** -- Logs (stdout/stderr), metrics (Prometheus), traces (OpenTelemetry).
5. **Security by default** -- Non-root, read-only filesystem, minimal base images, no secrets in images.

## Anti-Patterns

1. **"Containers as VMs"** -- Don't SSH into containers, install packages at runtime, or store state locally.
2. **"Latest tag in production"** -- Always pin image versions. `:latest` is not a version, it's a moving target.
3. **"One big container"** -- Don't run multiple services in one container. Use sidecar/init patterns instead.
4. **"Kubernetes for everything"** -- Docker Compose is fine for small projects. K8s adds operational cost.
5. **"No resource limits"** -- Containers without limits can starve other workloads. Always set requests and limits.
6. **"Privileged containers"** -- Almost never needed. Use specific capabilities instead of `--privileged`.

## Reference Files

Container fundamentals (OCI spec, namespaces, cgroups, layers, registries), orchestration concepts (desired state, reconciliation, operators), and cloud-native patterns live in the `references/concepts.md` file of the `orchestration`, `runtimes`, and `service-mesh` skills. Read those for architecture and comparison questions.
