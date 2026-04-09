# Podman and containerd Deep Dive
*Research date: April 2026*

---

## Podman 5.x / 6.0

Podman (Pod Manager) is a daemonless container engine developed by Red Hat, distributed under Apache 2.0. It is the default container engine on RHEL 8+ and Fedora.

### Current Versions

| Version | Release | Key Features |
|---------|---------|--------------|
| 5.0     | Early 2025 | Rewritten networking (Netavark), Podman Desktop parity |
| 5.6     | Aug 2025 | Quadlet command suite, nested virtualization macOS M3+ |
| 5.8     | Late 2025 | Enhanced rootless, improved Quadlet multi-file support |
| 6.0     | Planned 2026 | Major API revision, further Quadlet enhancements |

---

## Daemonless Architecture

The fundamental difference from Docker is the absence of a central daemon:

```
Docker:   docker CLI → dockerd (root daemon) → containerd → runc
Podman:   podman CLI → OCI runtime (runc/crun) directly (or via conmon)
```

Each `podman` invocation is a direct fork/exec — no background service required. This means:
- No single point of failure
- No root-owned socket to protect
- Containers are **child processes of the user or systemd**, not of a daemon
- Better systemd integration (containers as first-class systemd units)
- Compatible with `sudo` or completely rootless (separate user namespaces)

### Architecture Components

| Component | Role |
|-----------|------|
| libpod | Core Podman library |
| conmon | Container monitor process; stays alive while container runs |
| Netavark | Network stack (replaced CNI in Podman 4+) |
| Aardvark-DNS | DNS resolution within Podman networks |
| crun / runc | OCI runtime (crun default; written in C, 10x faster startup) |
| containers/image | Image transport library (Docker registry, OCI, dir, etc.) |
| containers/storage | Layer storage management |

---

## Rootless Containers

Podman's flagship feature. Containers run as your UID — no root required:

```bash
# Run rootless container
podman run -d --name nginx -p 8080:80 nginx:latest

# Check process tree — owned by your user, not root
ps aux | grep nginx

# Storage location for rootless
~/.local/share/containers/storage/

# Run with specific UID mapping
podman run --userns=keep-id nginx:latest     # map current user into container
podman run --userns=auto nginx:latest        # automatically assign sub-UID range
```

**Rootless requirements:**
- Kernel 5.11+ (or older with `newuidmap`/`newgidmap`)
- `shadow-utils` with `subuid`/`subgid` entries for user
- `/proc/sys/kernel/unprivileged_userns_clone = 1` on some distros

**Rootless limitations:**
- No ports < 1024 (override: `net.ipv4.ip_unprivileged_port_start=0`)
- No macvlan/ipvlan network driver
- Network performance slightly lower (uses slirp4netns or pasta)

```bash
# Check sub-UID configuration
cat /etc/subuid   # username:100000:65536
cat /etc/subgid

# Verify rootless networking
podman network ls
podman info | grep -A5 rootless
```

---

## Pods (K8s-compatible)

Podman's pod concept directly mirrors Kubernetes Pods: a group of containers sharing a network namespace and (optionally) PID namespace.

```bash
# Create a pod
podman pod create --name myapp \
  -p 8080:80 \
  --hostname myapp

# Add containers to the pod
podman run -d --pod myapp --name nginx nginx:latest
podman run -d --pod myapp --name sidecar myapp-sidecar:latest

# Pod management
podman pod ls
podman pod inspect myapp
podman pod start/stop/restart myapp
podman pod rm myapp

# Generate Kubernetes YAML from running pod
podman generate kube myapp > pod.yaml

# Play Kubernetes YAML (creates pods from K8s Pod spec)
podman kube play pod.yaml
podman kube play deployment.yaml     # also supports Deployments, Services
podman kube down pod.yaml            # remove resources
```

The `infra container` (pause container) holds the network namespace for the pod, identical to Kubernetes behavior.

---

## podman-compose

Drop-in replacement for docker-compose using Docker Compose files:

```bash
# Install
pip3 install podman-compose

# Use (same syntax as docker compose)
podman-compose up -d
podman-compose down
podman-compose logs -f
podman-compose exec api bash
```

Podman also has native Docker Compose socket compatibility:
```bash
# Enable Docker API socket compatibility
systemctl --user enable --now podman.socket
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock

# Now docker-compose (Docker's version) works with Podman
docker-compose up -d
```

---

## Quadlet (systemd Integration)

Quadlet is Podman's system for generating systemd unit files from container/pod/network/volume definitions. It is the production-grade integration pattern for RHEL and Fedora systems.

### How Quadlet Works

1. Create a `.container`, `.pod`, `.network`, or `.volume` file in a watched directory
2. The Quadlet generator (`/usr/lib/systemd/system-generators/podman-user-generator`) converts them to systemd `.service` units
3. systemd manages the container lifecycle (start, stop, restart, dependencies)

### File Locations

| Scope | Directory |
|-------|-----------|
| System (root) | `/etc/containers/systemd/` |
| User (rootless) | `~/.config/containers/systemd/` |
| User (XDG) | `$XDG_CONFIG_HOME/containers/systemd/` |
| Distribution | `/usr/share/containers/systemd/` |

### .container File

```ini
# ~/.config/containers/systemd/myapp.container
[Unit]
Description=My Application
After=network-online.target

[Container]
Image=registry.example.com/myapp:v2.0
ContainerName=myapp
PublishPort=8080:8080
Environment=DATABASE_URL=postgresql://db:5432/myapp
EnvironmentFile=/etc/myapp/env
Secret=db-password,type=env,target=DB_PASSWORD
Volume=myapp-data:/app/data:z
Network=myapp-net.network
Label=app=myapp
Label=version=v2.0
HealthCmd=curl -f http://localhost:8080/health
HealthInterval=30s
HealthRetries=3
ReadOnly=true
RunInit=true
AutoUpdate=registry        # auto-update when new image pushed
AppArmor=my-profile        # Podman 5.8+ feature

[Service]
Restart=on-failure
RestartSec=5s
TimeoutStartSec=60

[Install]
WantedBy=default.target
```

```bash
# Activate Quadlet unit
systemctl --user daemon-reload
systemctl --user enable --now myapp
systemctl --user status myapp
journalctl --user -u myapp -f
```

### .pod File

```ini
# ~/.config/containers/systemd/webapp.pod
[Pod]
PodName=webapp
PublishPort=8080:80
Network=webapp-net.network

# Container files reference the pod
# webapp-nginx.container:
[Container]
Pod=webapp.pod
Image=nginx:latest
```

### .network and .volume Files

```ini
# myapp-net.network
[Network]
Driver=bridge
Subnet=172.20.0.0/16
Gateway=172.20.0.1
DNS=true

# myapp-data.volume
[Volume]
Driver=local
Label=app=myapp
```

### Multi-File Quadlet (Podman 5.8+)

```bash
# Install a Quadlet bundle (multiple units separated by ---)
podman quadlet install bundle.quadlet

# Format of bundle.quadlet:
# # FileName=myapp.container
# [Container]
# Image=...
# ---
# # FileName=myapp-net.network
# [Network]
# ...
```

### Auto-Update

```bash
# Enable auto-update timer
systemctl --user enable --now podman-auto-update.timer

# Manual update check
podman auto-update

# Check update policy per container
podman inspect myapp | grep -i autoupdate
```

---

## Podman Desktop

GUI application for managing containers, pods, images, and registries. Available for macOS, Windows, Linux.

- Equivalent to Docker Desktop but free and open source
- Manages Podman Machine (see below)
- Extension system: Kubernetes, OpenShift, Compose, Docker Desktop migration
- Image scanning via Trivy integration
- Kubernetes: can connect to existing clusters or run local Kind/Minikube
- Podman Desktop extensions available from catalog

---

## podman machine (macOS and Windows)

On macOS and Windows, Podman runs containers inside a Linux VM (since containers require a Linux kernel):

```bash
# Initialize a VM
podman machine init \
  --cpus 4 \
  --memory 8192 \
  --disk-size 100 \
  --image-path next \
  podman-machine-default

# Start/stop
podman machine start
podman machine stop

# SSH into the VM
podman machine ssh

# List machines
podman machine ls

# Inspect
podman machine inspect

# Set rootful (needed for some operations)
podman machine set --rootful
```

**macOS VMs**: uses Apple Virtualization Framework (VZ) on macOS 12.5+ / M-series. M3+ chips with Podman 5.6+ enable nested virtualization by default.

**Windows**: uses WSL2 (Windows Subsystem for Linux 2).

---

## Differences from Docker CLI

| Feature | Docker | Podman |
|---------|--------|--------|
| Architecture | Daemon (dockerd) | Daemonless |
| Root requirement | Yes (daemon runs as root) | No (rootless) |
| systemd integration | Via restart policies | Native (Quadlet) |
| Pod support | No (docker-compose only) | Yes (K8s-compatible) |
| K8s YAML | No | `podman generate kube` / `podman kube play` |
| Fork/exec model | No | Yes |
| Socket | `/var/run/docker.sock` | `/run/podman/podman.sock` (or user socket) |
| Compose | Docker Compose plugin | podman-compose or Docker socket compat |
| Image trust | `docker trust` | `skopeo` + sigstore |
| Multi-arch | `docker buildx` | `podman build --platform` |
| Default runtime | containerd+runc | crun |
| Auto-update | No (external tools) | Built-in (Quadlet + timer) |

Most Docker CLI commands work unchanged with `podman`. Notable differences:
- `docker exec` → `podman exec` (same)
- `docker-compose` → `podman-compose` or Docker socket compat
- No `docker swarm` support (Podman is node-local or uses K8s)
- `podman machine` (no `docker machine` equivalent)

---

## containerd 2.x

containerd is a CNCF-graduated container runtime that serves as both Docker's execution backend and Kubernetes' default CRI implementation.

### Version History

| Version | Release | Key Changes |
|---------|---------|-------------|
| 1.7     | 2023    | Sandbox API (alpha), NRI v0.2, transfer service |
| 2.0     | Oct 2024 | Major: removed deprecated code, cgroup v2 default, config v3 |
| 2.1     | 2025    | Schema 1 image pull removal, stability improvements |
| 2.2     | 2025    | Mount manager service, extended NRI container status, containerd-shim updates |
| 2.2.2   | Mar 2026| Bundled in Docker Engine 29.3.1 |

---

## containerd Architecture

```
Client (dockerd, kubelet, nerdctl)
           ↓ gRPC (CRI or containerd API)
    containerd daemon
      ├── Content Store (OCI layers, compressed blobs)
      ├── Metadata (BoltDB: images, containers, leases)
      ├── Snapshotter (overlayfs, btrfs, native, etc.)
      ├── Runtime (shim v2 → runc, kata, gVisor)
      ├── Transfer Service (image import/export)
      ├── NRI (Node Resource Interface plugins)
      └── CRI Plugin (for Kubernetes kubelet)
           ↓
    containerd-shim-runc-v2
           ↓
         runc
           ↓
    Linux kernel (namespaces, cgroups, seccomp)
```

### Namespaces

containerd uses namespaces to isolate resources (not Linux kernel namespaces). This allows multiple clients to share one containerd instance:

```bash
# Docker uses the "moby" namespace
ctr --namespace moby containers ls

# Kubernetes uses the "k8s.io" namespace
ctr --namespace k8s.io containers ls

# Default namespace
ctr containers ls

# nerdctl uses "default" or "nerdctl"
```

### Content Store

The content store is a content-addressable store of immutable data (image layers, manifests, configs):

```bash
# List content
ctr content ls

# Fetch image layers to content store (no unpack)
ctr images fetch docker.io/library/nginx:latest

# List images
ctr images ls

# Delete content
ctr content rm sha256:...
```

### Snapshotter Architecture

Snapshotters manage the layered filesystem for containers:

| Snapshotter | Description | Use Case |
|-------------|-------------|----------|
| overlayfs | Default; uses OverlayFS kernel module | General purpose |
| native | Simple bind mounts; no OverlayFS | Older kernels |
| btrfs | Uses Btrfs subvolumes | Btrfs filesystems |
| zfs | Uses ZFS datasets | ZFS filesystems |
| devmapper | Device Mapper thin provisioning | Legacy |
| stargz | Remote, lazy-pulling snaphotter | Large images, K8s |
| nydus | RAFS v6 format, lazy pull | Large images, efficiency |
| erofs | Read-only, compressed; macOS (nerdbox) | macOS containers |
| aufs | Removed in containerd 2.0 | Deprecated |

```bash
# Check available snapshotters
ctr plugins ls | grep snapshotter

# Use specific snapshotter
ctr run --snapshotter stargz docker.io/library/nginx:latest mycontainer /bin/sh
```

### CRI Implementation

containerd's built-in CRI plugin implements the Kubernetes Container Runtime Interface:

```bash
# CRI configuration in containerd
cat /etc/containerd/config.toml
```

```toml
# /etc/containerd/config.toml (containerd 2.x uses version = 3)
version = 3

[plugins."io.containerd.grpc.v1.cri"]
  [plugins."io.containerd.grpc.v1.cri".containerd]
    snapshotter = "overlayfs"
    default_runtime_name = "runc"
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true     # required for cgroup v2
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
      runtime_type = "io.containerd.kata.v2"
  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["https://mirror.internal.example.com"]
```

### NRI (Node Resource Interface)

NRI is a framework for vendor/domain-specific plugins that can react to container lifecycle events without modifying containerd itself:

```
containerd → NRI broker → NRI plugins (OCI hooks, topology, resources, etc.)
```

NRI is **enabled by default in containerd 2.0** (was opt-in in 1.7). Plugins connect via a Unix socket.

Use cases:
- CPU affinity/pinning based on container annotations
- Memory NUMA topology
- GPU/accelerator allocation
- Custom network device assignment
- Injecting OCI hooks

```go
// NRI plugin interface (Go)
type Plugin interface {
    Configure(ctx context.Context, config, runtime, version string) ([]api.PodSandboxAdjustment, error)
    Synchronize(ctx context.Context, pods []*api.PodSandbox, containers []*api.Container) ([]api.ContainerAdjustment, error)
    RunPodSandbox(ctx context.Context, pod *api.PodSandbox) error
    StopPodSandbox(ctx context.Context, pod *api.PodSandbox) error
    CreateContainer(ctx context.Context, pod *api.PodSandbox, container *api.Container) (*api.ContainerAdjustment, []*api.ContainerUpdate, error)
    // ... more lifecycle hooks
}
```

containerd 2.2 passes extended container status to NRI plugins, enabling richer lifecycle-based decisions.

### Sandbox API

The Sandbox API provides explicit lifecycle management for Pod sandboxes (pause containers), separating sandbox creation from container creation:

```bash
# Sandbox API added Update endpoint in containerd 2.x
# /containerd.services.sandbox.v1.Controller/Update
# Allows modifying sandbox spec, runtime, extensions, and labels on running sandboxes

ctr sandboxes ls
```

This decoupling enables better support for VM-based runtimes (Kata Containers, Firecracker) where the sandbox IS the VM.

### Transfer Service

Introduced in containerd 1.7, stabilized in 2.x. Provides a unified API for moving content:

```bash
# Transfer image from registry to containerd
ctr transfer docker.io/library/nginx:latest localhost:5000/nginx:latest

# The transfer service handles:
# - Registry authentication
# - Parallel layer downloads
# - Verification
# - Decompression
# - Snapshotter integration
```

### containerd 2.x Breaking Changes from 1.x

| Area | Removed/Changed |
|------|----------------|
| Shims | `containerd-shim` and `containerd-shim-runc-v1` removed (use v2) |
| Storage | AUFS snapshotter removed |
| Images | Schema 1 image pull disabled (removed in 2.1) |
| Config | `/etc/containerd/config.toml` now expects `version = 3` header |
| API | Legacy v1 API surface removed |
| cgroup v1 | cgroup v2 strongly preferred; cgroup v1 support being phased out |
| Deprecations | All features deprecated since 1.4 (2020) and 1.5 (2021) removed |

### nerdctl (Docker-compatible CLI)

nerdctl is a Docker-compatible CLI for containerd. It implements the Docker CLI interface directly against containerd APIs (not CRI).

```bash
# Install nerdctl
# Bundled in nerdctl release packages with containerd + CNI plugins

# Docker-compatible commands
nerdctl run -d --name nginx nginx:latest
nerdctl ps
nerdctl images
nerdctl exec -it nginx bash
nerdctl logs nginx
nerdctl build -t myapp:latest .
nerdctl push registry.example.com/myapp:latest
nerdctl pull registry.example.com/myapp:latest

# Docker Compose compatible
nerdctl compose up -d
nerdctl compose down

# Rootless mode
nerdctl run --rootless -d nginx:latest

# Snapshotter selection
nerdctl run --snapshotter stargz -d nginx:latest

# Encryption (OCI image encryption)
nerdctl image encrypt --recipient jwe:public.pem myapp:latest myapp:encrypted

# P2P with IPFS
nerdctl run ipfs://QmHash...
```

nerdctl is the recommended CLI for containerd in non-Kubernetes contexts (e.g., development, CI/CD, edge computing with K3s).

---

## References

- [containerd Releases](https://containerd.io/releases/)
- [containerd 2.0 Migration Guide](https://github.com/containerd/containerd/blob/main/docs/containerd-2.0.md)
- [NRI - Node Resource Interface](https://github.com/containerd/nri)
- [nerdctl Releases](https://github.com/containerd/nerdctl/releases)
- [Podman Releases](https://github.com/containers/podman/releases)
- [Podman Quadlet systemd Integration](https://dev.to/lyraalishaikh/podman-quadlet-a-better-way-to-run-rootless-containers-with-systemd-3i3l)
- [Podman 5.6 Release Notes](https://alternativeto.net/news/2025/8/podman-5-6-released-with-improved-quadlet-management-remote-client-capabilities-and-more/)
- [Docker vs Podman 2026](https://dev.to/mechcloud_academy/docker-vs-podman-an-in-depth-comparison-2025-2eia)
