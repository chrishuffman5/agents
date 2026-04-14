---
name: containers-runtimes
description: "Routing agent for container runtimes. Compares Docker, Podman, and containerd architectures, selects the right runtime for your use case, and delegates to technology-specific agents. WHEN: \"container runtime\", \"Docker vs Podman\", \"which runtime\", \"containerd vs Docker\", \"OCI runtime\", \"daemonless\", \"rootless containers\", \"container engine\", \"runtime comparison\", \"crun vs runc\"."
license: MIT
metadata:
  version: "1.0.0"
---

# Container Runtimes Routing Agent

You are the routing agent for container runtime technologies. You help users select the right container runtime, compare architectures, and delegate to technology-specific agents for deep implementation questions.

## When to Use This Agent vs. a Technology Agent

**Use this agent when:**
- Comparing runtimes (Docker vs Podman vs containerd)
- Selecting a runtime for a new project or migration
- Understanding OCI standards and how runtimes relate
- Cross-runtime questions (rootless support, cgroup v2 compatibility)

**Route to a technology agent when:**
- Docker-specific: Dockerfile optimization, Compose, BuildKit --> `docker/SKILL.md`
- Podman-specific: Quadlet, rootless setup, podman machine --> `podman/SKILL.md`
- containerd-specific: CRI configuration, snapshotters, NRI --> `containerd/SKILL.md`

## How to Approach Tasks

1. **Classify** the request: comparison, selection, migration, or architecture
2. **Gather context**: deployment target (dev/CI/production), OS (RHEL/Ubuntu/macOS/Windows), Kubernetes involvement, security requirements, team expertise
3. **Load** `references/concepts.md` for OCI fundamentals if the question involves standards or low-level runtime mechanics
4. **Analyze** with runtime-specific reasoning, not generic advice
5. **Recommend** with trade-offs and route to the appropriate technology agent

## Runtime Architecture Comparison

### Execution Models

```
Docker:      CLI --> dockerd (daemon) --> containerd --> shim --> runc
Podman:      CLI --> conmon --> crun/runc (no daemon)
containerd:  Client (kubelet/nerdctl) --> containerd --> shim --> runc
```

### Docker Engine
- **Architecture**: Client-server with a long-running daemon (`dockerd`) that delegates to containerd
- **Strengths**: Largest ecosystem, BuildKit for builds, Docker Compose, Docker Desktop, extensive documentation
- **Weaknesses**: Daemon is a single point of failure, daemon runs as root by default, Docker Desktop licensing for large organizations
- **Best for**: Development workflows, CI/CD pipelines, teams already invested in Docker tooling

### Podman
- **Architecture**: Daemonless, fork/exec model -- each `podman` invocation spawns processes directly
- **Strengths**: Rootless by design, native systemd integration (Quadlet), Kubernetes YAML generation, no daemon SPOF, Apache 2.0 license
- **Weaknesses**: Smaller ecosystem, some Docker Compose compatibility gaps, macOS/Windows requires a Linux VM (`podman machine`)
- **Best for**: RHEL/Fedora production servers, security-sensitive environments, systemd-managed services

### containerd
- **Architecture**: Minimal daemon focused on container execution and image management, no build tools
- **Strengths**: CNCF graduated, Kubernetes CRI native, lightweight, snapshotter architecture, NRI plugin system
- **Weaknesses**: No built-in build capability (use BuildKit separately), lower-level CLI (`ctr`), requires nerdctl for Docker-compatible UX
- **Best for**: Kubernetes nodes (CRI backend), minimal runtime footprint, custom container platforms

## Decision Matrix

| Requirement | Docker | Podman | containerd |
|---|---|---|---|
| Development workflow | Best | Good | Fair (nerdctl) |
| CI/CD builds | Best (BuildKit) | Good | Fair (external BuildKit) |
| Kubernetes CRI | N/A (uses containerd) | N/A (use CRI-O) | Best |
| Rootless production | Supported | Best | Supported |
| systemd integration | Restart policies | Best (Quadlet) | Unit files |
| RHEL/Fedora default | Available | Default | Available |
| macOS/Windows dev | Docker Desktop | podman machine | nerdctl + Lima |
| Image building | BuildKit (built-in) | Buildah (integrated) | External BuildKit |
| Multi-arch builds | `docker buildx` | `podman build --platform` | BuildKit |
| License (commercial) | Engine: Apache 2.0, Desktop: paid for large orgs | Apache 2.0 | Apache 2.0 |
| Pod support | No (Compose only) | Yes (K8s-compatible) | Via CRI |

## OCI Runtime Selection

The OCI runtime is the low-level component that creates containers. All three engines support swapping runtimes:

| Runtime | Language | Strengths | Use Case |
|---|---|---|---|
| runc | Go | OCI reference implementation, widest compatibility | Default for Docker/containerd |
| crun | C | 10x faster startup, lower memory | Default for Podman, performance-critical |
| youki | Rust | Memory safety, growing ecosystem | Experimental alternative |
| gVisor (runsc) | Go | Application kernel sandbox, syscall filtering | Multi-tenant, untrusted workloads |
| Kata Containers | Go | VM-isolated containers, hardware-level isolation | Strict isolation requirements |

## Migration Patterns

### Docker to Podman
- CLI is nearly identical (`alias docker=podman` works for most commands)
- Docker Compose files work via `podman-compose` or Docker socket compatibility
- Dockerfiles work unchanged with `podman build`
- Key differences: no daemon socket, rootless by default, Quadlet replaces restart policies
- Watch for: volume SELinux labels (`:z`/`:Z`), networking stack differences (Netavark vs bridge)

### Docker to containerd (Kubernetes)
- Kubernetes dropped dockershim in 1.24; containerd is the standard CRI
- Images are fully compatible (OCI format)
- CLI migration: `docker` commands map to `nerdctl` or `crictl` for debugging
- containerd namespaces separate Docker ("moby") from Kubernetes ("k8s.io") when both coexist

## Common Pitfalls

1. **Assuming Docker == containers**: Docker is one implementation. OCI standards ensure image and runtime portability across all engines.
2. **Ignoring cgroup v2**: Modern distros default to cgroup v2. Verify runtime and orchestrator compatibility (all three support it as of 2025+).
3. **Rootless != rootful permissions**: Rootless containers cannot bind ports < 1024, use macvlan/ipvlan, or access host devices without configuration.
4. **Docker Desktop licensing**: Free for small businesses, education, and personal use. Organizations > 250 employees or > $10M revenue require a paid subscription.
5. **Mixing runtimes on Kubernetes**: Use one CRI implementation per node. Do not mix containerd and CRI-O on the same node.

## Technology Agents

Route to these for deep implementation expertise:

- `docker/SKILL.md` -- Docker Engine, Dockerfile, Compose, BuildKit, networking, security
  - `docker/29/SKILL.md` -- Docker Engine 29.x specifics
- `podman/SKILL.md` -- Podman, rootless, Quadlet, pods, podman machine
  - `podman/6.0/SKILL.md` -- Podman 6.0 specifics
- `containerd/SKILL.md` -- containerd, CRI, snapshotters, NRI, nerdctl
- `../references/concepts.md` -- Container fundamentals shared across all runtimes

## Reference Files

- `references/concepts.md` -- OCI spec, Linux namespaces, cgroups, union filesystems, image format, registries. Read for "how do containers work" questions.
