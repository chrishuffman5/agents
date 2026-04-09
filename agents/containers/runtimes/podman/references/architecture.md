# Podman Architecture

## Daemonless Execution Model

### Process Lifecycle

```
User invokes: podman run myimage
  |
  podman (CLI process)
  |-- resolves image (containers/image library)
  |-- creates container spec (OCI runtime spec)
  |-- creates conmon process
  |     |
  |     conmon (container monitor)
  |     |-- creates crun/runc process
  |     |     |
  |     |     crun --> sets up namespaces, cgroups, seccomp --> exec container process
  |     |
  |     |-- monitors container stdout/stderr
  |     |-- captures exit code
  |     |-- stays alive for container lifetime
  |
  podman CLI exits (container continues running via conmon)
```

**Key insight**: After `podman run -d`, the `podman` CLI process exits. The container runs under `conmon`, which is a small C program that monitors the container process. This is fundamentally different from Docker, where the container runs under the daemon.

### conmon (Container Monitor)

conmon is a minimal C program (~1 MB) that:
- Forks the OCI runtime (crun/runc) to create the container
- Holds the container's terminal pty (if applicable)
- Captures stdout/stderr to log files
- Monitors the container process and records exit status
- Handles `podman attach` and `podman logs` by reading log files
- Stays alive as long as the container runs
- Allows `podman` CLI to exit without affecting the container

### crun vs runc

| Aspect | crun | runc |
|---|---|---|
| Language | C | Go |
| Startup time | ~50ms | ~500ms |
| Memory usage | ~1 MB | ~10 MB |
| cgroup v2 | First-class | Supported |
| User namespace | Full support | Full support |
| Default in | Podman, CRI-O | Docker, containerd |
| OCI compliant | Yes | Yes (reference implementation) |

crun is the default runtime for Podman because of its significantly faster container startup and lower resource usage.

## Networking: Netavark + Aardvark-DNS

### Netavark Architecture

Netavark replaced CNI plugins in Podman 4.0. It is a Rust-based network stack purpose-built for Podman:

```
podman --> Netavark (network setup)
             |-- Creates bridge networks (Linux bridge + veth pairs)
             |-- Configures iptables/nftables rules for port mapping
             |-- Manages macvlan/ipvlan networks
             |-- Handles firewall rules per container
             |
             +-- Aardvark-DNS (DNS resolution)
                  |-- Per-network DNS server
                  |-- Resolves container names to IPs
                  |-- Supports aliases and network-scoped DNS
```

### Network Types

```bash
# Default bridge (automatic)
podman network create mynet

# Bridge with custom subnet
podman network create \
  --subnet 172.20.0.0/16 \
  --gateway 172.20.0.1 \
  mynet

# Macvlan (rootful only)
podman network create -d macvlan \
  --subnet 192.168.1.0/24 \
  --gateway 192.168.1.1 \
  -o parent=eth0 \
  macvlan-net
```

### Rootless Networking

In rootless mode, Podman cannot modify host iptables or create veth pairs directly. It uses pasta (or legacy slirp4netns):

```
Rootless: podman --> pasta --> container network namespace
                      |
                  Translates between host and container
                  using unprivileged network namespace operations
```

**pasta** (Podman 5.x+ default): Uses Linux network namespaces for better performance than slirp4netns. Supports TCP, UDP, and ICMP passthrough.

**slirp4netns** (legacy): Userspace TCP/IP stack. Higher latency, but works on older kernels.

## Storage Architecture

### containers/storage Library

Podman uses the `containers/storage` library for layered image and container storage:

```
Storage root:
  Rootful: /var/lib/containers/storage/
  Rootless: ~/.local/share/containers/storage/

Directory structure:
  overlay-images/       <-- image metadata (manifests, configs)
  overlay-layers/       <-- layer metadata
  overlay/              <-- actual layer filesystems
    <layer-id>/
      diff/             <-- layer content
      merged/           <-- union mount (when container running)
      upper/            <-- writable layer (container)
      work/             <-- overlayfs work directory
  volumes/              <-- named volumes
```

### Storage Drivers

| Driver | Mechanism | Notes |
|---|---|---|
| overlay | OverlayFS (kernel) | Default; requires kernel 4.0+ |
| fuse-overlayfs | FUSE OverlayFS | Required for rootless on kernel < 5.11 |
| btrfs | Btrfs subvolumes | Native CoW |
| zfs | ZFS datasets | Enterprise features |
| vfs | Simple copy | No CoW, slow, works everywhere |

### Configuration

```toml
# /etc/containers/storage.conf (rootful)
# ~/.config/containers/storage.conf (rootless)

[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"   # only needed for rootless on old kernels
mountopt = "nodev,metacopy=on"
```

## containers.conf Configuration

Global Podman configuration:

```toml
# /etc/containers/containers.conf (system)
# ~/.config/containers/containers.conf (user)

[containers]
default_capabilities = [
  "CHOWN", "DAC_OVERRIDE", "FOWNER", "FSETID",
  "KILL", "NET_BIND_SERVICE", "SETFCAP", "SETGID",
  "SETPCAP", "SETUID"
]
log_driver = "k8s-file"          # or journald
pids_limit = 2048
userns = "host"                   # or "auto" for rootless
ipcns = "private"
seccomp_profile = "/usr/share/containers/seccomp.json"

[engine]
runtime = "crun"                  # or "runc"
cgroup_manager = "systemd"        # or "cgroupfs"
events_logger = "journald"

[network]
network_backend = "netavark"      # or "cni" (legacy)
dns_bind_port = 53
```

## registries.conf Configuration

```toml
# /etc/containers/registries.conf

# Search registries (when no registry specified in image name)
unqualified-search-registries = ["docker.io", "quay.io"]

# Registry mirrors
[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry.mirror]]
location = "mirror.internal.example.com"

# Insecure registry (no TLS)
[[registry]]
location = "registry.internal:5000"
insecure = true

# Blocked registry
[[registry]]
location = "untrusted.registry.io"
blocked = true
```

## Podman Machine (macOS / Windows)

On macOS and Windows, containers require a Linux kernel. Podman runs a lightweight Linux VM:

```
macOS/Windows:
  podman CLI --> gRPC API --> podman machine VM (Fedora CoreOS)
                                |
                                podman (inside VM) --> crun --> containers
```

### VM Backends

| Platform | Backend | Notes |
|---|---|---|
| macOS (M-series) | Apple Virtualization.framework | Default since Podman 5.x, supports VirtioFS |
| macOS (Intel) | QEMU | Legacy backend |
| macOS (M3+) | VZ with nested virtualization | Podman 5.6+, enables running VMs inside containers |
| Windows | WSL2 | Windows Subsystem for Linux 2 |

### Machine Management

```bash
podman machine init --cpus 4 --memory 8192 --disk-size 100
podman machine start
podman machine stop
podman machine ssh                    # SSH into the VM
podman machine set --rootful          # enable rootful access
podman machine ls
podman machine inspect
```

### Volume Mounts

Volumes between host and VM use VirtioFS (macOS VZ) or 9p filesystem (QEMU/WSL2):
```bash
# Host paths are automatically available inside the VM
podman run -v /Users/myuser/data:/data myimage
```

## Podman API

Podman exposes a REST API compatible with Docker's API plus Podman-specific extensions:

```bash
# Enable API socket (rootless)
systemctl --user enable --now podman.socket
# Socket at: $XDG_RUNTIME_DIR/podman/podman.sock

# Enable API socket (rootful)
systemctl enable --now podman.socket
# Socket at: /run/podman/podman.sock

# Query API
curl --unix-socket $XDG_RUNTIME_DIR/podman/podman.sock \
  http://localhost/v5.0.0/libpod/containers/json
```

The API has two endpoint namespaces:
- `/v5.0.0/libpod/` -- Podman-native endpoints (pods, Quadlet, etc.)
- `/v5.0.0/` -- Docker-compatible endpoints (containers, images, networks)
