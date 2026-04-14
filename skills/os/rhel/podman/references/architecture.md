# Podman Architecture Reference

## Daemonless Architecture

Podman eliminates the central daemon process that Docker requires.

### Fork/Exec Model

- Each `podman` CLI invocation is a standalone process -- no persistent daemon to contact
- The CLI forks an OCI runtime directly to start containers
- Containers are children of the user's shell (rootless) or systemd (as a service)
- `ps aux` shows container processes directly under their parent

### OCI Runtime

| Runtime | RHEL Version | Language | Notes |
|---|---|---|---|
| `runc` | RHEL 8 default | Go | Established compatibility |
| `crun` | RHEL 9+ default | C | Faster startup, lower memory, newer cgroup features |

```bash
# Check active runtime
podman info --format '{{.Host.OCIRuntime.Name}}'

# Override per run
podman run --runtime /usr/bin/runc ...
```

### conmon (Container Monitor)

Lightweight C process spawned per container:
- Manages container stdin/stdout/stderr streams
- Reports container exit code back to Podman
- Survives if the Podman CLI exits (enables detached containers)
- Path: `/usr/bin/conmon`

### OCI Runtime Spec

Containers are defined by `config.json` (OCI Runtime Spec) in the container bundle. Podman constructs this spec from image config plus user flags. Stored under `/run/containers/storage/overlay-containers/<ID>/userdata/`.

### Advantages Over Daemon Model

- No single point of failure
- No root daemon requirement (rootless by design)
- Direct integration with systemd (container IS a systemd unit)
- Simpler auditing -- container processes visible in normal process tree

---

## Rootless Containers

Rootless containers run entirely within a normal user's UID, with no root privileges required.

### User Namespaces

Linux kernel feature mapping a range of host UIDs to UIDs inside the container. A container running as UID 0 inside maps to a non-root UID on the host. All RHEL 8/9/10 kernels support this.

### subuid / subgid Mapping

Files: `/etc/subuid` and `/etc/subgid`

Format: `username:start_uid:count`
```
chris:100000:65536
```

This grants user `chris` a subordinate UID range of 100000-165535. Inside the container, UID 0 maps to host UID 100000.

```bash
# Setup for new users
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 chris
podman system migrate

# Verify mapping
podman unshare cat /proc/self/uid_map
```

### Rootless Storage

- Graph root: `~/.local/share/containers/storage`
- Run root (ephemeral): `/run/user/<UID>/containers`
- Config: `~/.config/containers/storage.conf`

### Rootless Networking

| Backend | RHEL Version | Mechanism |
|---|---|---|
| `slirp4netns` | RHEL 8 / early RHEL 9 | Userspace TCP/IP stack |
| `pasta` (passt) | RHEL 9.2+ | Native performance, passt backend |

```bash
# Check active mode
podman info --format '{{.Host.NetworkBackend}}'

# Force pasta in containers.conf
# [network]
# default_rootless_network_cmd = "pasta"
```

### Rootless Limitations

- Cannot bind ports < 1024 without `net.ipv4.ip_unprivileged_port_start` sysctl
- cgroup v1 (RHEL 8): no resource limits in rootless mode
- cgroup v2 (RHEL 9+): resource limits work with delegation enabled
- No MACVLAN networking
- Some kernel capabilities unavailable even with `--privileged`

Enable privileged port binding:
```bash
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-unprivileged-port.conf
```

Enable cgroup v2 delegation for rootless resource limits:
```bash
sudo mkdir -p /etc/systemd/system/user@.service.d/
cat | sudo tee /etc/systemd/system/user@.service.d/delegate.conf << 'EOF'
[Service]
Delegate=yes
EOF
sudo systemctl daemon-reload
```

---

## Storage Architecture

### containers/storage Library

Shared Go library used by Podman, Buildah, and CRI-O. Manages image layers and container filesystems.

Config files:
- System: `/etc/containers/storage.conf`
- User: `~/.config/containers/storage.conf`

### Storage Drivers

| Driver | Use Case | Requirements |
|---|---|---|
| `overlay` | Default, production | Linux kernel 4.0+; fuse-overlayfs for rootless on RHEL 8 |
| `vfs` | Compatibility fallback | Any kernel; slow (full copy per layer) |
| `btrfs` | Btrfs filesystems | Btrfs mount |
| `devmapper` | Legacy RHEL 8 | Device Mapper; complex setup |

```bash
podman info --format '{{.Store.GraphDriverName}}'
```

### Key Storage Paths

| Path | Mode | Purpose |
|---|---|---|
| `/var/lib/containers/storage` | Root | Images and containers |
| `~/.local/share/containers/storage` | Rootless | Images and containers |
| `/run/containers/storage` | Root | Ephemeral state |
| `/run/user/<UID>/containers` | Rootless | Ephemeral state |
| `<graph-root>/overlay/` | Both | Image layers (overlay driver) |
| `<graph-root>/overlay-containers/` | Both | Container filesystems |

### storage.conf Key Settings

```ini
[storage]
driver = "overlay"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers/storage"

[storage.options.overlay]
mountopt = "nodev"
# For rootless on RHEL 8 without native overlay:
mount_program = "/usr/bin/fuse-overlayfs"
```

### Image Layer Management

- Images stored as read-only layers (copy-on-write)
- Each container gets a thin read-write layer on top
- Prune dangling images: `podman image prune`
- Prune all unused: `podman system prune -a`
- Disk usage report: `podman system df`

---

## Networking

### CNI vs Netavark

| Feature | CNI (RHEL 8) | Netavark (RHEL 9+) |
|---|---|---|
| Implementation | Plugin-based | Rust-based monolithic |
| DNS | dnsmasq plugin | Aardvark-DNS |
| Config location | `/etc/cni/net.d/` | Podman-managed |
| Performance | Adequate | Faster, more features |
| Container name resolution | Limited | Automatic on same network |

### Network Types

```bash
# Bridge (default) -- isolated L2 network with NAT
podman network create mynet

# MACVLAN -- container appears as separate device on host network
podman network create --driver macvlan --opt parent=eth0 macvlan-net

# Host networking -- shares host network namespace
podman run --network host ...

# No networking
podman run --network none ...

# Connect to multiple networks
podman network connect mynet mycontainer
```

### Port Mapping

```bash
podman run -p 8080:80 nginx                  # Host:container
podman run -p 127.0.0.1:8080:80 nginx        # Specific host IP
podman run -p 5353:53/udp dns-server          # UDP
```

### Network Inspection

```bash
podman network ls
podman network inspect mynet
podman port mycontainer
```

### Firewall Interaction (RHEL 9+)

Netavark manages firewalld/nftables rules automatically. If containers cannot reach external networks:
```bash
firewall-cmd --get-active-zones
sudo nft list ruleset | grep podman
```

---

## Pod Model

Pods group containers sharing network, IPC, and optionally PID namespaces -- mirroring the Kubernetes pod concept.

### Infrastructure Container

Every pod contains an "infra" container that holds shared namespaces. Other containers join the infra container's network namespace. Port mappings are defined at the pod level.

### Pod Lifecycle

```bash
podman pod create --name mypod -p 8080:80
podman run -d --pod mypod nginx
podman run -d --pod mypod myapp

podman pod start mypod
podman pod stop mypod
podman pod rm mypod
podman pod inspect mypod
podman pod stats mypod
podman pod logs mypod
```

### Kubernetes YAML Compatibility

```bash
# Generate YAML from running pod
podman generate kube mypod > mypod.yaml

# Deploy from YAML
podman play kube mypod.yaml

# Play with specific network
podman play kube --network mynet mypod.yaml

# Tear down
podman play kube --down mypod.yaml
```

Supported Kubernetes resource types: Pod, Deployment, DaemonSet, ConfigMap, Secret, PersistentVolumeClaim.

---

## Registry Configuration

### registries.conf

- System: `/etc/containers/registries.conf`
- User: `~/.config/containers/registries.conf`
- Format: TOML

```toml
# Unqualified image search order
unqualified-search-registries = ["registry.access.redhat.com", "registry.redhat.io", "docker.io"]

# Block a registry
[[registry]]
location = "untrusted-registry.example.com"
blocked = true

# Configure a mirror
[[registry]]
location = "docker.io"
  [[registry.mirror]]
  location = "mirror.internal.example.com"

# Allow insecure (HTTP) registry
[[registry]]
location = "dev-registry.internal:5000"
insecure = true
```

### Short-Name Aliases (RHEL 9+)

File: `/etc/containers/registries.conf.d/shortnames.conf`
```toml
[aliases]
  "nginx" = "docker.io/library/nginx"
  "ubi9" = "registry.access.redhat.com/ubi9/ubi"
```

### Authentication

```bash
podman login registry.redhat.io
podman logout registry.redhat.io

# Credentials stored in:
# $XDG_RUNTIME_DIR/containers/auth.json (rootless)
# /run/containers/0/auth.json (rootful)
```

### Signature Verification

Policy file: `/etc/containers/policy.json`
```json
{
  "default": [{"type": "insecureAcceptAnything"}],
  "transports": {
    "docker": {
      "registry.access.redhat.com": [{"type": "signedBy", "keyType": "GPGKeys",
        "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"}]
    }
  }
}
```
