# Container Runtime Fundamentals

## OCI Specifications

The Open Container Initiative (OCI) defines three specifications that ensure portability across container runtimes:

### Runtime Specification (runtime-spec)
Defines how to run a container from an unpacked filesystem bundle:
- **config.json**: Process to run, environment variables, working directory, user/group, capabilities, rlimits
- **Linux namespaces**: Which namespaces to create (pid, net, mnt, uts, ipc, user, cgroup)
- **Mounts**: Filesystem mount points (bind, tmpfs, proc, sysfs, devpts)
- **Cgroups**: Resource limits (CPU, memory, I/O, PIDs)
- **Seccomp**: Syscall filtering profile
- **Hooks**: Prestart, createRuntime, createContainer, startContainer, poststart, poststop

### Image Specification (image-spec)
Defines the container image format:
- **Image manifest**: References the config and layer descriptors
- **Image index** (fat manifest): References multiple manifests for multi-platform images (linux/amd64, linux/arm64)
- **Image config**: Default runtime parameters (Env, Cmd, Entrypoint, ExposedPorts, Volumes, Labels)
- **Layers**: Ordered set of filesystem changesets (tarballs), each with a content-addressable digest (sha256)
- **Media types**: `application/vnd.oci.image.manifest.v1+json`, `application/vnd.oci.image.layer.v1.tar+gzip`

### Distribution Specification (distribution-spec)
Defines how registries store and distribute images:
- **Pull**: `GET /v2/<name>/manifests/<reference>` and `GET /v2/<name>/blobs/<digest>`
- **Push**: `POST /v2/<name>/blobs/uploads/` then `PUT` with content, then `PUT /v2/<name>/manifests/<reference>`
- **Tags listing**: `GET /v2/<name>/tags/list`
- **Content negotiation**: Client specifies accepted media types to select OCI vs Docker manifest formats
- **Referrers API**: Links artifacts (signatures, SBOMs, attestations) to an image via `subject` field

## Linux Namespaces

Namespaces provide process-level isolation. Each container typically gets its own set:

| Namespace | Flag | Isolates |
|---|---|---|
| PID | `CLONE_NEWPID` | Process IDs -- PID 1 inside container is not PID 1 on host |
| Network | `CLONE_NEWNET` | Network interfaces, routing tables, iptables rules, sockets |
| Mount | `CLONE_NEWNS` | Filesystem mount points -- container sees its own root filesystem |
| UTS | `CLONE_NEWUTS` | Hostname and NIS domain name |
| IPC | `CLONE_NEWIPC` | System V IPC, POSIX message queues, shared memory |
| User | `CLONE_NEWUSER` | UID/GID mapping -- root (0) inside maps to unprivileged UID outside |
| Cgroup | `CLONE_NEWCGROUP` | Cgroup root view -- container sees only its own cgroup hierarchy |
| Time | `CLONE_NEWTIME` | System clocks (CLOCK_MONOTONIC, CLOCK_BOOTTIME) -- kernel 5.6+ |

**User namespaces** are the foundation of rootless containers. They allow a process to have UID 0 inside the namespace while running as an unprivileged user on the host. Sub-UID/GID mappings (`/etc/subuid`, `/etc/subgid`) define the range of host UIDs available for mapping.

## Control Groups (cgroups)

Cgroups limit, account for, and isolate resource usage of process groups.

### cgroup v1 vs v2

| Aspect | cgroup v1 | cgroup v2 |
|---|---|---|
| Hierarchy | Multiple hierarchies (one per controller) | Single unified hierarchy |
| Controllers | CPU, memory, blkio, devices, freezer, etc. as separate trees | All controllers in one tree |
| Memory tracking | Per-cgroup only | Per-cgroup with PSI (Pressure Stall Information) |
| eBPF | Limited | Full eBPF device controller support |
| Delegation | Complex (requires multiple mount points) | Simple (single subtree delegation) |
| Default (2026) | Legacy distros | RHEL 9+, Ubuntu 22.04+, Fedora 31+, Debian 12+ |

### Key Controllers

- **cpu**: CPU time allocation (`cpu.max`, `cpu.weight`). Maps to `--cpus` and `--cpu-shares`
- **memory**: Memory limits (`memory.max`, `memory.high`, `memory.swap.max`). Maps to `--memory`, `--memory-swap`
- **io**: Block I/O limits (`io.max`, `io.weight`). Maps to `--device-read-bps`, `--device-write-bps`
- **pids**: Maximum number of processes (`pids.max`). Maps to `--pids-limit`
- **cpuset**: Pin to specific CPUs/memory nodes. Maps to `--cpuset-cpus`

### Resource Limit Best Practices

- Always set memory limits to prevent OOM kills of other workloads
- Set CPU limits for multi-tenant environments; use CPU shares for priority-based scheduling
- PID limits prevent fork bombs (`--pids-limit 256` is a reasonable default)
- In Kubernetes, `requests` map to cpu.weight/memory.min (guaranteed), `limits` map to cpu.max/memory.max (ceiling)

## Union Filesystems and Layers

Container images use a layered filesystem model where each instruction in a Dockerfile creates a new layer.

### How Layers Work

1. **Base layer**: The root filesystem from the base image (e.g., `FROM debian:bookworm-slim`)
2. **Intermediate layers**: Each `RUN`, `COPY`, `ADD` instruction creates a new layer containing filesystem changes (added, modified, deleted files)
3. **Container layer**: A thin writable layer created when the container starts. All runtime writes go here.
4. **Content-addressable**: Each layer is identified by a SHA-256 digest of its content. Identical layers are stored and transferred once.

### Union Filesystem Drivers

| Driver | Mechanism | Performance | Notes |
|---|---|---|---|
| OverlayFS (overlay2) | Kernel-native (3.18+), upper/lower/merged dirs | Best for most workloads | Default for Docker, Podman, containerd |
| fuse-overlayfs | FUSE-based OverlayFS | Moderate | Required for rootless on kernels < 5.11 |
| Btrfs | Btrfs subvolumes per layer | Good with Btrfs | Copy-on-write at block level |
| ZFS | ZFS datasets per layer | Good with ZFS | Enterprise features (compression, dedup) |
| VirtioFS | Hypervisor filesystem passthrough | Good | Used by Docker Desktop, podman machine |

### OverlayFS Internals

```
Container view (merged):  /merged/
                           |
           +---------------+----------------+
           |                                |
    Upper (writable):  /upper/       Lower (read-only):  /lower1/:/lower2/
    - New files go here              - Image layers stacked
    - Modified files copy-up         - Immutable
    - Deleted files get whiteout     - Shared across containers
```

- **Copy-up**: When a file in a lower layer is modified, it is copied to the upper layer first. The entire file is copied, not just the changed blocks.
- **Whiteout files**: Deleting a file in a lower layer creates a character device (whiteout) in the upper layer to mask it.
- **Opaque directories**: Deleting a directory creates an opaque whiteout that hides all lower-layer contents.

## Image Format Details

### Manifest Structure

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:abc123...",
    "size": 1234
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:def456...",
      "size": 50000000
    }
  ]
}
```

### Multi-Platform Images (Image Index)

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:amd64digest...",
      "platform": { "architecture": "amd64", "os": "linux" }
    },
    {
      "mediaType": "application/vnd.oci.image.manifest.v1+json",
      "digest": "sha256:arm64digest...",
      "platform": { "architecture": "arm64", "os": "linux" }
    }
  ]
}
```

The runtime selects the manifest matching the host architecture automatically.

## Container Registries

Registries store and distribute OCI images. They implement the OCI Distribution Specification.

### Registry Types

| Registry | Type | Key Features |
|---|---|---|
| Docker Hub | Public/private | Default registry, rate-limited for free tier, official images |
| GitHub Container Registry (ghcr.io) | Public/private | GitHub Actions integration, free for public images |
| Amazon ECR | Private | IAM auth, cross-region replication, image scanning |
| Azure ACR | Private | AAD auth, geo-replication, ACR Tasks for builds |
| Google Artifact Registry | Private | IAM auth, multi-format (Docker, Maven, npm) |
| Harbor | Self-hosted | CNCF graduated, vulnerability scanning, RBAC, replication |
| Quay.io | Public/private | Red Hat, Clair scanning, geo-replication |
| Zot | Self-hosted | OCI-native, minimal, single binary |

### Image References

```
[registry/][namespace/]repository[:tag][@digest]

docker.io/library/nginx:1.27-alpine          # Docker Hub official
ghcr.io/myorg/myapp:v2.0                     # GitHub Container Registry
registry.example.com/team/api:v1.0@sha256:... # Private with digest pin
```

- **Tag**: Mutable pointer to a manifest. `:latest` is the default if omitted.
- **Digest**: Immutable content-addressable reference. Use in production for reproducibility.
- **Tag + digest**: Pin to exact content while retaining human-readable tag.

### Image Signing and Verification

- **cosign** (Sigstore): Keyless signing with OIDC identity, transparency log (Rekor)
- **Notary v2**: OCI-native signing, attached as referrer artifacts
- **Docker Content Trust**: Legacy, uses Notary v1, deprecated in favor of cosign

```bash
# Sign with cosign (keyless)
cosign sign --yes ghcr.io/myorg/myapp:v2.0

# Verify
cosign verify ghcr.io/myorg/myapp:v2.0 \
  --certificate-identity=user@example.com \
  --certificate-oidc-issuer=https://accounts.google.com
```

## Container Networking Fundamentals

### Network Namespace Mechanics

Each container gets its own network namespace with:
- Separate network interfaces, routing tables, and iptables/nftables rules
- A virtual ethernet pair (veth): one end in the container namespace, other end on a bridge or host
- Loopback interface (lo) isolated from host loopback

### Common Network Models

| Model | Mechanism | Use Case |
|---|---|---|
| Bridge | veth pairs connected to a Linux bridge (docker0 or custom) | Default for single-host |
| Host | Container shares host network namespace | Performance-sensitive, no isolation |
| Macvlan | Container gets own MAC/IP on physical network | Direct LAN access |
| IPvlan | Container shares host MAC, gets own IP (L2 or L3) | Similar to macvlan, no promiscuous mode |
| Overlay (VXLAN) | Encapsulated L2 over L3 between hosts | Multi-host (Swarm, K8s) |
| CNI plugins | Standardized networking for Kubernetes | Calico, Cilium, Flannel |

### DNS Resolution

- Docker: embedded DNS server at 127.0.0.11 for custom bridge networks
- Podman: Aardvark-DNS provides DNS for Podman networks
- Kubernetes: CoreDNS for service discovery (`<svc>.<ns>.svc.cluster.local`)
