# Podman / Buildah / Skopeo — Deep Dive (RHEL 8/9/10)

> Research compiled for RHEL agent library. Covers the Podman container ecosystem
> including Buildah, Skopeo, Quadlet, and supporting components across RHEL 8, 9, and 10.

---

## Part 1: Architecture

### 1. Daemonless Architecture

Podman differs fundamentally from Docker by eliminating the central daemon process.

**Fork/exec model:**
- Each `podman` CLI invocation is a standalone process — no persistent daemon to contact
- The CLI forks an OCI runtime directly to start containers
- Containers are children of the user's shell (rootless) or of systemd (as a service)

**OCI Runtime:**
- RHEL 8: `runc` default (written in Go, established compatibility)
- RHEL 9+: `crun` default (written in C, faster startup, lower memory, supports newer cgroup features)
- Override per run: `podman run --runtime /usr/bin/runc ...`
- Check active runtime: `podman info --format '{{.Host.OCIRuntime.Name}}'`

**conmon (Container Monitor):**
- Lightweight C process spawned per container
- Sits between OCI runtime and Podman CLI
- Manages container stdin/stdout/stderr streams
- Reports container exit code back to Podman
- Survives if the Podman CLI exits (enables detached containers)
- Path: `/usr/bin/conmon`

**OCI Runtime Spec:**
- Containers defined by `config.json` (OCI Runtime Spec) in the container bundle
- Podman constructs this spec from image config + user flags
- Stored under: `/run/containers/storage/overlay-containers/<ID>/userdata/`

**No-daemon advantages:**
- No single point of failure
- No root daemon (rootless by design)
- Direct integration with systemd (container IS a systemd unit)
- Simpler auditing — container processes visible in normal process tree
- `ps aux` shows container processes directly under their parent

---

### 2. Rootless Containers

Rootless containers run entirely within a normal user's UID, with no root privileges required.

**User Namespaces:**
- Linux kernel feature mapping a range of host UIDs to UIDs inside the container
- A container running as UID 0 inside maps to a non-root UID on the host
- Requires kernel 3.8+ (all RHEL 8/9/10 kernels qualify)
- Check: `cat /proc/sys/kernel/unprivileged_userns_clone` (should be 1)

**subuid / subgid mapping:**

Files: `/etc/subuid` and `/etc/subgid`

Format: `username:start_uid:count`
```
chris:100000:65536
```

This grants user `chris` a subordinate UID range of 100000–165535.
Inside the container, UID 0 maps to host UID 100000.

Setup for new users:
```bash
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 chris
# Or edit /etc/subuid directly, then run:
podman system migrate
```

Verify mapping:
```bash
podman unshare cat /proc/self/uid_map
```

**Rootless Storage:**
- Default graph root: `~/.local/share/containers/storage`
- Run root (ephemeral): `/run/user/<UID>/containers`
- Config: `~/.config/containers/storage.conf`

**Rootless Networking — slirp4netns vs pasta:**
- RHEL 8/early RHEL 9: `slirp4netns` — userspace TCP/IP stack, works but slower
- RHEL 9.2+: `pasta` — uses `passt` backend, better performance, closer to native networking
- Check active mode: `podman info --format '{{.Host.NetworkBackend}}'` (rootless)
- Force pasta: Set `default_rootless_network_cmd = "pasta"` in `containers.conf`

**Rootless Limitations:**
- Cannot bind ports < 1024 without `net.ipv4.ip_unprivileged_port_start` sysctl or `CAP_NET_BIND_SERVICE`
  ```bash
  # Allow rootless bind to port 80:
  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80
  # Persist:
  echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-unprivileged-port.conf
  ```
- cgroup v1: no resource limits in rootless mode
- cgroup v2 (RHEL 9+): resource limits work with delegation enabled
  ```bash
  # Enable cgroup v2 delegation for user:
  sudo mkdir -p /etc/systemd/system/user@.service.d/
  cat | sudo tee /etc/systemd/system/user@.service.d/delegate.conf << 'EOF'
  [Service]
  Delegate=yes
  EOF
  sudo systemctl daemon-reload
  ```
- No MACVLAN networking in rootless mode
- Some kernel capabilities unavailable even with `--privileged` in rootless

---

### 3. Storage Architecture

**containers/storage library:**
- Shared Go library used by Podman, Buildah, and CRI-O
- Manages image layers and container filesystems
- Config: `/etc/containers/storage.conf` (system) or `~/.config/containers/storage.conf` (user)

**Storage Drivers:**

| Driver | Use Case | Requirements |
|--------|----------|--------------|
| `overlay` | Default, production | Linux kernel 4.0+, fuse-overlayfs for rootless |
| `vfs` | Compatibility fallback | Any kernel, slow (full copy per layer) |
| `btrfs` | Btrfs filesystems only | Btrfs mount |
| `devmapper` | Legacy RHEL 8 thin pools | Device Mapper, complex setup |

Check current driver:
```bash
podman info --format '{{.Store.GraphDriverName}}'
```

**Key storage paths:**
- Graph root (images/containers): `/var/lib/containers/storage` (root) or `~/.local/share/containers/storage` (rootless)
- Run root (ephemeral state): `/run/containers/storage` (root) or `/run/user/<UID>/containers` (rootless)
- Image layers: `<graph-root>/overlay/` (overlay driver)
- Container filesystems: `<graph-root>/overlay-containers/`

**storage.conf key settings:**
```ini
[storage]
driver = "overlay"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers/storage"

[storage.options.overlay]
mountopt = "nodev"
# For rootless on systems without native overlay:
mount_program = "/usr/bin/fuse-overlayfs"
```

**Image layer management:**
- Images are stored as read-only layers (copy-on-write)
- Each container gets a thin read-write layer on top
- Prune dangling images: `podman image prune`
- Prune all unused: `podman system prune -a`
- Disk usage report: `podman system df`

---

### 4. Networking

**CNI vs Netavark:**

| | RHEL 8 | RHEL 9+ |
|--|--------|---------|
| Backend | CNI (Container Network Interface) | Netavark |
| DNS | dnsmasq plugin | Aardvark-DNS |
| Config dir | `/etc/cni/net.d/` | Podman-managed |
| Performance | Adequate | Faster, more features |

**Netavark + Aardvark (RHEL 9+):**
- Netavark: Rust-based network setup tool replacing CNI plugins
- Aardvark-DNS: Authoritative DNS server for container name resolution
- Containers on same network resolve each other by name automatically
- Config stored in: `/run/containers/networks/` (ephemeral) and Podman DB

**Network types:**
```bash
# Bridge (default) — isolated L2 network with NAT
podman network create mynet

# MACVLAN — container appears as separate device on host network
podman network create --driver macvlan --opt parent=eth0 macvlan-net

# Host networking — shares host network namespace
podman run --network host ...

# No networking
podman run --network none ...

# Multiple networks
podman network connect mynet mycontainer
```

**Port mapping:**
```bash
# Map host port 8080 to container port 80
podman run -p 8080:80 nginx

# Bind to specific host IP
podman run -p 127.0.0.1:8080:80 nginx

# UDP port
podman run -p 5353:53/udp dns-server
```

**Network inspection:**
```bash
podman network ls
podman network inspect mynet
podman port mycontainer
```

**Firewall interaction (RHEL 9+):**
Netavark manages firewalld/nftables rules automatically.
If containers can't reach external networks:
```bash
# Check firewalld zone for container interface
firewall-cmd --get-active-zones
# Netavark creates "nm-shared" or custom zones
```

---

### 5. Pod Model

Pods group containers sharing network, IPC, and optionally PID namespaces — mirroring the Kubernetes pod concept.

**Infrastructure container:**
- Every pod contains an "infra" container (`pause` image by default, or `k8s.gcr.io/pause`)
- The infra container holds the shared namespaces
- Other containers join the infra container's network namespace
- Default infra image: `registry.access.redhat.com/ubi8/pause` or `localhost/podman-pause`

**Pod lifecycle:**
```bash
# Create pod with port mapping
podman pod create --name mypod -p 8080:80

# Add containers to pod
podman run -d --pod mypod nginx
podman run -d --pod mypod myapp

# Pod-level operations
podman pod start mypod
podman pod stop mypod
podman pod rm mypod
podman pod inspect mypod
podman pod stats mypod
podman pod logs mypod
```

**Kubernetes YAML compatibility:**
```bash
# Generate Kubernetes YAML from running pod
podman generate kube mypod > mypod.yaml

# Deploy from Kubernetes YAML
podman play kube mypod.yaml

# Play with specific network
podman play kube --network mynet mypod.yaml

# Tear down kube deployment
podman play kube --down mypod.yaml
```

Supported Kubernetes resource types: Pod, Deployment, DaemonSet, ConfigMap, Secret, PersistentVolumeClaim

---

### 6. Registry Configuration

**registries.conf:**
- System: `/etc/containers/registries.conf`
- User: `~/.config/containers/registries.conf`
- Format: TOML

**Key configuration:**
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

**Short-name aliases (RHEL 9+):**
File: `/etc/containers/registries.conf.d/shortnames.conf`
```toml
[aliases]
  "nginx" = "docker.io/library/nginx"
  "ubi8" = "registry.access.redhat.com/ubi8/ubi"
```

**Authentication:**
```bash
# Login (credentials stored in $XDG_RUNTIME_DIR/containers/auth.json or ~/.docker/config.json)
podman login registry.redhat.io

# Logout
podman logout registry.redhat.io

# Use specific auth file
podman pull --authfile /path/to/auth.json image:tag
```

**Signature verification:**
```bash
# Configure policy: /etc/containers/policy.json
# Require signatures from Red Hat
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

---

## Part 2: Best Practices

### 7. Quadlet (systemd Integration, RHEL 9+)

Quadlet replaces `podman generate systemd` (deprecated in Podman 4.4, removed in 5.0). It generates systemd units from declarative `.container`, `.volume`, `.network`, `.pod`, `.image`, and `.kube` files.

**Unit file locations:**
- System: `/etc/containers/systemd/` (requires root)
- User: `~/.config/containers/systemd/` (rootless)
- Also loaded from: `/usr/share/containers/systemd/` (packages)

**After adding/modifying unit files:**
```bash
systemctl daemon-reload          # system units
systemctl --user daemon-reload   # user units
```

**.container unit file:**
```ini
# /etc/containers/systemd/nginx.container
[Unit]
Description=Nginx Web Server
After=network-online.target

[Container]
Image=docker.io/library/nginx:latest
PublishPort=8080:80
Volume=/var/www/html:/usr/share/nginx/html:ro,Z
Environment=NGINX_HOST=example.com
Network=myapp.network
Label=io.containers.autoupdate=registry
User=nginx
ReadOnly=true
NoNewPrivileges=true

[Service]
Restart=always
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
```

Start: `systemctl start nginx`  (Quadlet auto-generates `nginx.service`)

**.volume unit file:**
```ini
# /etc/containers/systemd/myapp-data.volume
[Volume]
Driver=local
Label=app=myapp
```

**.network unit file:**
```ini
# /etc/containers/systemd/myapp.network
[Network]
Driver=bridge
Subnet=10.89.1.0/24
Gateway=10.89.1.1
Label=app=myapp
```

**.kube unit file:**
```ini
# /etc/containers/systemd/myapp.kube
[Unit]
Description=MyApp Kubernetes deployment

[Kube]
Yaml=/etc/containers/systemd/myapp-pod.yaml

[Install]
WantedBy=multi-user.target
```

**.image unit file:**
```ini
# /etc/containers/systemd/ubi9.image
[Image]
Image=registry.access.redhat.com/ubi9/ubi:latest
```

**Quadlet debugging:**
```bash
# Test unit generation without applying
/usr/lib/systemd/system-generators/podman-system-generator --dry-run

# Inspect generated unit
systemctl cat nginx.service

# Quadlet logs
journalctl -u nginx.service
```

---

### 8. Image Management

**Buildah — building images:**

Buildah can build from Containerfile/Dockerfile or interactively:

```bash
# Build from Containerfile
buildah bud -t myapp:latest -f Containerfile .

# Interactive build (no Dockerfile)
container=$(buildah from ubi9)
buildah run $container -- dnf install -y python3
buildah config --cmd "python3 /app/server.py" $container
buildah config --label "version=1.0" $container
buildah commit $container myapp:latest
buildah rm $container
```

**Multi-stage builds:**
```dockerfile
# Stage 1: Build
FROM registry.access.redhat.com/ubi9/ubi as builder
RUN dnf install -y gcc make
COPY . /src
WORKDIR /src
RUN make build

# Stage 2: Runtime
FROM registry.access.redhat.com/ubi9/ubi-minimal
COPY --from=builder /src/bin/myapp /usr/local/bin/
USER 1001
CMD ["/usr/local/bin/myapp"]
```

Build: `buildah bud --layers -t myapp:latest .`
The `--layers` flag caches intermediate layers (faster rebuilds).

**Skopeo — image inspection and copying:**

```bash
# Inspect without pulling
skopeo inspect docker://registry.access.redhat.com/ubi9/ubi:latest

# Inspect specific architecture
skopeo inspect --override-arch arm64 docker://docker.io/library/nginx:latest

# Copy between registries (no local daemon needed)
skopeo copy docker://docker.io/nginx:latest docker://myregistry.internal/nginx:latest

# Copy to local OCI directory
skopeo copy docker://nginx:latest oci:/tmp/nginx-oci

# Copy to local tarball
skopeo copy docker://nginx:latest docker-archive:/tmp/nginx.tar

# Sync entire repository
skopeo sync --src docker --dest dir docker.io/library/nginx /tmp/mirrors/

# Delete image from registry
skopeo delete docker://myregistry.internal/old-image:tag

# List available tags
skopeo list-tags docker://docker.io/library/nginx
```

**Image signing and verification:**
```bash
# Sign image with GPG key
podman push --sign-by admin@example.com myimage:latest docker://registry.example.com/myimage:latest

# Verify signature during pull (configured via policy.json)
podman pull registry.example.com/myimage:latest
```

---

### 9. Security Best Practices

**SELinux labels:**
```bash
# :Z — relabel volume for container (private, unshared)
podman run -v /host/path:/container/path:Z myimage

# :z — relabel volume (shared between multiple containers)
podman run -v /host/path:/container/path:z myimage

# Never use :Z on /home, /etc, /tmp — can break SELinux policy
# Use a dedicated directory for container volumes

# Check SELinux label
ls -Z /host/path

# Troubleshoot SELinux denials
ausearch -m avc -ts recent
sealert -a /var/log/audit/audit.log
```

**Capability management:**
```bash
# Drop all capabilities, add only what's needed
podman run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx

# Run without any extra capabilities
podman run --cap-drop=ALL myapp

# View default capabilities
podman run --rm docker.io/library/alpine:latest grep Cap /proc/self/status | \
  xargs -I{} capsh --decode={}
```

**Read-only rootfs:**
```bash
# Mount rootfs read-only, provide writable tmpfs for needed paths
podman run \
  --read-only \
  --tmpfs /tmp:rw,size=100m,mode=1777 \
  --tmpfs /run:rw,size=50m \
  myapp
```

**no-new-privileges:**
```bash
# Prevent setuid binaries from gaining privileges
podman run --security-opt no-new-privileges myapp
```

**Seccomp profiles:**
```bash
# Use custom seccomp profile
podman run --security-opt seccomp=/etc/containers/seccomp.json myapp

# Disable seccomp (development only)
podman run --security-opt seccomp=unconfined myapp

# Default profile blocks ~300 syscalls
podman info --format '{{.Host.SecurityOptions}}'
```

**User namespace isolation:**
```bash
# Run container with isolated user namespace (even in rootful mode)
podman run --userns=auto myapp

# Map to specific UID range
podman run --uidmap 0:100000:65536 myapp
```

**Secrets management:**
```bash
# Create secret
printf "mysecretpassword" | podman secret create db-password -

# Use secret in container (mounted at /run/secrets/<name>)
podman run --secret db-password myapp

# Use secret as environment variable (less secure)
podman run --secret db-password,type=env,target=DB_PASSWORD myapp

# List/inspect secrets
podman secret ls
podman secret inspect db-password
```

**Recommended security flags for production:**
```bash
podman run \
  --read-only \
  --cap-drop=ALL \
  --security-opt no-new-privileges \
  --security-opt seccomp=/etc/containers/seccomp.json \
  --user 1001:1001 \
  -v /data:/data:ro,Z \
  myapp:latest
```

---

### 10. Auto-Update

Quadlet + auto-update enables automated container image updates with rollback.

**Label-based policy:**
```ini
# In .container unit file:
Label=io.containers.autoupdate=registry   # check registry for newer image
Label=io.containers.autoupdate=local      # only update if local image changed
```

**Manual trigger:**
```bash
# Update all containers with autoupdate label
podman auto-update

# Dry run (show what would update)
podman auto-update --dry-run

# Update and generate CSV report
podman auto-update --format json
```

**Systemd timer (auto-update runs daily by default):**
```bash
# Enable the built-in timer
systemctl enable --now podman-auto-update.timer

# Check timer status
systemctl status podman-auto-update.timer

# Rootless user timer
systemctl --user enable --now podman-auto-update.timer
```

**Rollback on failure:**
Quadlet + auto-update uses systemd's restart mechanism. If the new image fails health checks or the container exits non-zero, systemd restarts with the previous image. Configure with:
```ini
[Service]
Restart=on-failure
RestartSec=10
StartLimitBurst=3
```

---

### 11. Resource Management

**CPU limits:**
```bash
# Limit to 1.5 CPUs
podman run --cpus=1.5 myapp

# CPU shares (relative weight, default 1024)
podman run --cpu-shares=512 myapp

# Pin to specific CPUs
podman run --cpuset-cpus=0,1 myapp
```

**Memory limits:**
```bash
# Hard memory limit (container killed if exceeded)
podman run --memory=512m myapp

# Memory + swap total
podman run --memory=512m --memory-swap=1g myapp

# Soft limit (advisory, container not killed)
podman run --memory-reservation=256m myapp

# Disable OOM killer for this container
podman run --oom-kill-disable myapp
```

**cgroup v2 integration (RHEL 9+):**
- cgroup v2 is default on RHEL 9+
- Provides unified hierarchy for all resource controls
- Required for rootless resource limits (with delegation)
- Better CPU/memory accounting and throttling

Verify cgroup version:
```bash
stat -fc %T /sys/fs/cgroup/
# cgroup2fs = v2, tmpfs = v1
```

**Systemd slice assignment (Quadlet):**
```ini
[Service]
# Assign to a resource-limited slice
Slice=container.slice
CPUQuota=150%
MemoryMax=512M
```

**Block I/O limits:**
```bash
# Limit read rate on device
podman run --device-read-bps /dev/sda:10mb myapp

# Limit write IOPS
podman run --device-write-iops /dev/sda:100 myapp
```

**Live monitoring:**
```bash
# Real-time resource usage
podman stats

# Single snapshot
podman stats --no-stream

# Specific containers
podman stats container1 container2

# JSON output for automation
podman stats --no-stream --format json
```

---

### 12. Podman Machine (Development)

Podman Machine creates a lightweight VM for running Podman on macOS and Windows, where Linux containers require a Linux kernel.

**Initialize and start:**
```bash
# Initialize with default settings
podman machine init

# Custom VM (more resources)
podman machine init --cpus 4 --memory 8192 --disk-size 100

# Start the VM
podman machine start

# Stop the VM
podman machine stop

# SSH into VM
podman machine ssh

# List machines
podman machine list

# Remove machine
podman machine rm
```

**VM backends:**
- macOS: QEMU (Intel), Apple Hypervisor Framework (Apple Silicon), or Virtualization.framework
- Windows: WSL2 (Windows Subsystem for Linux 2) — default on Windows
- Fedora CoreOS base image used for the VM

**podman-remote:**
The local `podman` CLI connects to the VM via a REST API socket:
```bash
# Connection managed automatically after podman machine start
# Manual connection setup:
podman system connection add myvm ssh://core@127.0.0.1:<port>/run/user/1000/podman/podman.sock

# List connections
podman system connection list

# Switch active connection
podman system connection default myvm
```

**RHEL development workflow:**
```bash
# Initialize machine with RHEL-based image (requires subscription)
podman machine init --image-path /path/to/rhel9.qcow2

# Use for local development matching production RHEL environment
podman machine start
podman build -t myapp:dev .
podman run -p 8080:8080 myapp:dev
```

---

## Part 3: Diagnostics

### 13. Container Troubleshooting

**Logs:**
```bash
# Follow logs
podman logs -f mycontainer

# Last 50 lines
podman logs --tail 50 mycontainer

# With timestamps
podman logs -t mycontainer

# Since a time
podman logs --since 30m mycontainer

# Pod logs (all containers)
podman pod logs mypod
```

**Inspect:**
```bash
# Full container metadata
podman inspect mycontainer

# Specific field
podman inspect --format '{{.State.Status}}' mycontainer
podman inspect --format '{{.NetworkSettings.IPAddress}}' mycontainer
podman inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' mycontainer

# Image inspection
podman image inspect myimage:tag
```

**Process and resource inspection:**
```bash
# Container process list (like top)
podman top mycontainer

# Extended format
podman top mycontainer pid,ppid,user,comm,args,pcpu,pmem

# Real-time stats
podman stats mycontainer

# Health check status
podman inspect --format '{{.State.Healthcheck}}' mycontainer
podman healthcheck run mycontainer
```

**Events:**
```bash
# Stream all events
podman events

# Filter by container
podman events --filter container=mycontainer

# Filter by event type
podman events --filter event=die

# Historical events
podman events --since 1h
```

**Entering containers:**
```bash
# Interactive shell
podman exec -it mycontainer /bin/bash

# Run command
podman exec mycontainer ls /app

# As specific user
podman exec -u root mycontainer id

# With environment variable
podman exec -e DEBUG=1 mycontainer /app/debug-tool
```

**Debugging failed starts:**
```bash
# Check exit code
podman inspect --format '{{.State.ExitCode}}' mycontainer

# Check last error
podman inspect --format '{{.State.Error}}' mycontainer

# View OCI runtime log
journalctl -u podman-<container-name>.service

# Run interactively to catch startup errors
podman run -it --entrypoint /bin/sh myimage

# Override entrypoint and inspect filesystem
podman run -it --entrypoint /bin/sh --rm myimage -c "ls -la /app && cat /app/config.yaml"
```

---

### 14. Rootless Troubleshooting

**subuid/subgid misconfiguration:**
```bash
# Check entries exist
grep $USER /etc/subuid /etc/subgid

# No entry = rootless containers fail with "user namespaces not enabled"
# Fix:
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate  # migrate existing containers to new ranges

# Check mapping is active
podman unshare cat /proc/self/uid_map
# Expected: 0 100000 65536
```

**Namespace issues:**
```bash
# Check if user namespaces are enabled
cat /proc/sys/user/max_user_namespaces
# 0 = disabled. Fix:
sudo sysctl -w user.max_user_namespaces=15000

# Check namespace limits
cat /proc/sys/kernel/unprivileged_userns_clone  # Debian/Ubuntu
# On RHEL 8+, user namespaces enabled by default

# Verify namespace creation works
podman unshare id
# Should show: uid=0(root) gid=0(root)
```

**Storage permission problems:**
```bash
# Reset rootless storage
podman system reset  # WARNING: removes all containers and images

# Fix permissions on rootless storage
ls -la ~/.local/share/containers/

# Check if overlay works
podman info 2>&1 | grep -i driver

# Fuse-overlayfs not installed (needed on some RHEL 8 configs)
sudo dnf install -y fuse-overlayfs

# Force VFS driver (compatibility fallback)
# In ~/.config/containers/storage.conf:
# driver = "vfs"
```

**Networking issues (rootless):**
```bash
# slirp4netns not found
sudo dnf install -y slirp4netns

# pasta/passt not found (RHEL 9+)
sudo dnf install -y passt

# Check which networking is active
podman info | grep -i networkbackend

# DNS not resolving inside rootless container
# Check /etc/resolv.conf inside container
podman run --rm alpine cat /etc/resolv.conf

# Override DNS
podman run --dns=8.8.8.8 myimage
```

**SELinux denials:**
```bash
# Check for denials
ausearch -m avc -ts recent | grep podman

# Common fix — relabel volume with :Z
podman run -v /mydata:/data:Z myimage

# Generate permissive policy for testing
audit2allow -a -M podman-custom
semodule -i podman-custom.pp

# Check container SELinux label
podman inspect --format '{{.ProcessLabel}}' mycontainer
```

---

### 15. Common Issues

**Image pull failures:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| `unauthorized: authentication required` | Not logged in | `podman login registry.redhat.io` |
| `name unknown: repository not found` | Wrong image name | Verify with `skopeo inspect` |
| `connection refused` / timeout | DNS or firewall | Check `/etc/resolv.conf`, firewalld |
| `short-name resolution` prompt | Unqualified image name | Use fully-qualified name or configure aliases |
| `toomanyrequests` | Docker Hub rate limit | Login to Docker Hub or use mirror |

```bash
# Debug pull
podman pull --log-level=debug nginx:latest 2>&1 | head -50

# Test registry connectivity
curl -v https://registry.access.redhat.com/v2/

# Check search registries
podman info | grep registries -A 10
```

**Container networking issues:**

```bash
# Port conflict
ss -tlnp | grep 8080
# Kill conflicting process or use different host port

# Container can't reach host service
# Use host.containers.internal (Netavark, RHEL 9+)
podman run --add-host=host.containers.internal:host-gateway myapp

# DNS not working inside container
podman run --rm alpine nslookup google.com
# If failing, check network's dns configuration:
podman network inspect mynet | grep dns

# Firewall blocking container traffic
sudo firewall-cmd --list-all
# Netavark creates rules in nftables; verify:
sudo nft list ruleset | grep podman
```

**Storage issues:**

```bash
# Check disk space
podman system df
df -h /var/lib/containers

# Clean up
podman image prune -a       # remove unused images
podman container prune      # remove stopped containers
podman volume prune         # remove unused volumes
podman system prune -a -f   # full cleanup (WARNING: removes everything unused)

# Overlay driver requirements not met (requires kernel 4.0+)
uname -r
# Check kernel supports overlay:
grep -E 'overlay|overlay2' /proc/filesystems

# Dangling images
podman images -f dangling=true
podman image prune
```

**Permission denied:**

```bash
# Volume mount: SELinux
# Check denial: ausearch -m avc -ts recent
# Fix: use :Z flag or set correct SELinux context on host dir
chcon -Rt svirt_sandbox_file_t /mydata

# Volume mount: file ownership mismatch (rootless)
# Container UID 0 = host UID 100000 (from subuid)
# Host files must be owned by the mapped UID
ls -la /mydata
# If owned by a different UID, either:
podman unshare chown -R 0:0 /mydata  # chown inside user namespace
# Or use podman volume instead of bind mount

# Socket permission
# Access to /var/run/docker.sock — Podman doesn't use this
# Podman socket: /run/user/<UID>/podman/podman.sock (rootless)
#                /run/podman/podman.sock (rootful)
```

---

## Part 4: Diagnostic Scripts

### Script 01 — Podman Health Check

```bash
#!/usr/bin/env bash
# ============================================================================
# Podman - System Health Check
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

header "PODMAN VERSION & RUNTIME"

if ! command -v podman &>/dev/null; then
  fail "Podman not found in PATH. Install: dnf install -y podman"
  exit 1
fi

PODMAN_VERSION=$(podman --version)
pass "Podman installed: $PODMAN_VERSION"

# OCI Runtime
RUNTIME=$(podman info --format '{{.Host.OCIRuntime.Name}}' 2>/dev/null || echo "unknown")
RUNTIME_PATH=$(podman info --format '{{.Host.OCIRuntime.Path}}' 2>/dev/null || echo "unknown")
info "OCI Runtime: $RUNTIME ($RUNTIME_PATH)"

case "$RUNTIME" in
  crun) pass "Using crun (recommended for RHEL 9+)" ;;
  runc) info "Using runc (default for RHEL 8, acceptable)" ;;
  *)    warn "Unknown OCI runtime: $RUNTIME" ;;
esac

# conmon
CONMON=$(podman info --format '{{.Host.Conmon.Path}}' 2>/dev/null || echo "not found")
info "conmon path: $CONMON"
if [[ "$CONMON" != "not found" ]] && [[ -x "$CONMON" ]]; then
  pass "conmon is present and executable"
else
  fail "conmon not found or not executable"
fi

header "STORAGE CONFIGURATION"

GRAPH_DRIVER=$(podman info --format '{{.Store.GraphDriverName}}' 2>/dev/null || echo "unknown")
GRAPH_ROOT=$(podman info --format '{{.Store.GraphRoot}}' 2>/dev/null || echo "unknown")
RUN_ROOT=$(podman info --format '{{.Store.RunRoot}}' 2>/dev/null || echo "unknown")

info "Storage driver:  $GRAPH_DRIVER"
info "Graph root:      $GRAPH_ROOT"
info "Run root:        $RUN_ROOT"

case "$GRAPH_DRIVER" in
  overlay)   pass "Overlay storage driver in use (recommended)" ;;
  vfs)       warn "VFS storage driver in use — slow, not recommended for production" ;;
  devmapper) warn "DevMapper storage driver — legacy, consider migration to overlay" ;;
  *)         warn "Unrecognized storage driver: $GRAPH_DRIVER" ;;
esac

# Check graph root free space
if [[ -d "$GRAPH_ROOT" ]]; then
  FREE_PCT=$(df --output=pcent "$GRAPH_ROOT" | tail -1 | tr -d ' %')
  USED_PCT=$FREE_PCT
  if (( USED_PCT < 70 )); then
    pass "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used"
  elif (( USED_PCT < 85 )); then
    warn "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used — consider pruning"
  else
    fail "Storage usage on $GRAPH_ROOT: ${USED_PCT}% used — critically high"
  fi
fi

header "REGISTRY CONFIGURATION"

REG_FILE="/etc/containers/registries.conf"
USER_REG_FILE="${HOME}/.config/containers/registries.conf"

if [[ -f "$REG_FILE" ]]; then
  pass "System registries.conf present: $REG_FILE"
  SEARCH_REGS=$(grep 'unqualified-search-registries' "$REG_FILE" 2>/dev/null || echo "not set")
  info "Unqualified search: $SEARCH_REGS"
else
  warn "No system registries.conf found at $REG_FILE"
fi

if [[ -f "$USER_REG_FILE" ]]; then
  info "User registries.conf present: $USER_REG_FILE"
fi

# Policy file
POLICY_FILE="/etc/containers/policy.json"
if [[ -f "$POLICY_FILE" ]]; then
  pass "Image policy.json present: $POLICY_FILE"
else
  warn "No image policy.json found — image signature verification may not be configured"
fi

header "PODMAN SYSTEM INFO"

podman system info 2>/dev/null | grep -E \
  'version|arch|os|kernel|hostname|cgroupVersion|cgroupManager|eventLogger' \
  || warn "Could not retrieve full system info"

header "DISK USAGE (podman system df)"

podman system df 2>/dev/null || warn "Could not retrieve disk usage"

header "CGROUP DETECTION"

CGROUP_TYPE=$(stat -fc %T /sys/fs/cgroup/ 2>/dev/null || echo "unknown")
case "$CGROUP_TYPE" in
  cgroup2fs) pass "cgroup v2 active (full resource control available)" ;;
  tmpfs)     warn "cgroup v1 active — rootless resource limits not available" ;;
  *)         warn "Could not determine cgroup version: $CGROUP_TYPE" ;;
esac

CGROUP_MGR=$(podman info --format '{{.Host.CgroupManager}}' 2>/dev/null || echo "unknown")
info "cgroup manager: $CGROUP_MGR"

header "BUILDAH & SKOPEO"

if command -v buildah &>/dev/null; then
  pass "Buildah: $(buildah --version)"
else
  warn "Buildah not installed (dnf install -y buildah)"
fi

if command -v skopeo &>/dev/null; then
  pass "Skopeo: $(skopeo --version)"
else
  warn "Skopeo not installed (dnf install -y skopeo)"
fi

echo -e "\n${BOLD}Health check complete.${NC}"
```

---

### Script 02 — Container Inventory

```bash
#!/usr/bin/env bash
# ============================================================================
# Podman - Container Inventory
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

BOLD='\033[1m'; CYAN='\033[0;36m'; NC='\033[0m'
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }
info()   { echo -e "${CYAN}[INFO]${NC} $*"; }

header "RUNNING CONTAINERS"

RUNNING=$(podman ps --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
if [[ -n "$RUNNING" ]]; then
  echo "$RUNNING"
else
  info "No running containers"
fi

header "ALL CONTAINERS (including stopped)"

ALL=$(podman ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Created}}" 2>/dev/null)
if [[ -n "$ALL" ]]; then
  echo "$ALL"
else
  info "No containers found"
fi

TOTAL=$(podman ps -a -q 2>/dev/null | wc -l)
RUNNING_COUNT=$(podman ps -q 2>/dev/null | wc -l)
STOPPED_COUNT=$(( TOTAL - RUNNING_COUNT ))
info "Summary: ${RUNNING_COUNT} running, ${STOPPED_COUNT} stopped, ${TOTAL} total"

header "PODS"

PODS=$(podman pod ps --format "table {{.Id}}\t{{.Name}}\t{{.Status}}\t{{.NumContainers}}\t{{.InfraId}}" 2>/dev/null)
if [[ -n "$PODS" && "$PODS" != "ID"* ]]; then
  echo "$PODS"
else
  POD_COUNT=$(podman pod ps -q 2>/dev/null | wc -l)
  if (( POD_COUNT == 0 )); then
    info "No pods defined"
  else
    echo "$PODS"
  fi
fi

header "IMAGES"

podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.Created}}" 2>/dev/null

IMAGE_COUNT=$(podman images -q 2>/dev/null | wc -l)
DANGLING=$(podman images -f dangling=true -q 2>/dev/null | wc -l)
info "Total images: ${IMAGE_COUNT} (${DANGLING} dangling)"

header "VOLUMES"

VOL_OUTPUT=$(podman volume ls 2>/dev/null)
if echo "$VOL_OUTPUT" | grep -q .; then
  echo "$VOL_OUTPUT"
else
  info "No volumes defined"
fi

VOL_COUNT=$(podman volume ls -q 2>/dev/null | wc -l)
info "Total volumes: $VOL_COUNT"

header "NETWORKS"

podman network ls 2>/dev/null

header "PORT MAPPINGS"

CONTAINERS_WITH_PORTS=$(podman ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null | awk -F'\t' '$2 != ""')
if [[ -n "$CONTAINERS_WITH_PORTS" ]]; then
  echo -e "CONTAINER\t\t\tPORTS"
  echo "$CONTAINERS_WITH_PORTS"
else
  info "No containers with exposed ports"
fi

header "RESOURCE USAGE (snapshot)"

RUNNING_IDS=$(podman ps -q 2>/dev/null)
if [[ -n "$RUNNING_IDS" ]]; then
  podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null \
    || info "Could not retrieve stats (requires running containers)"
else
  info "No running containers — skipping resource stats"
fi

header "SYSTEM DISK USAGE"

podman system df 2>/dev/null

echo -e "\n${BOLD}Inventory complete. Run 'podman system prune' to clean unused resources.${NC}"
```

---

### Script 03 — Rootless Audit

```bash
#!/usr/bin/env bash
# ============================================================================
# Podman - Rootless Configuration Audit
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

CURRENT_USER="${SUDO_USER:-$USER}"
CURRENT_UID=$(id -u "$CURRENT_USER")

header "CURRENT USER"
info "User: $CURRENT_USER (UID: $CURRENT_UID)"
if (( CURRENT_UID == 0 )); then
  warn "Running as root — this script is designed for rootless Podman audit"
  warn "Re-run as the target non-root user for accurate rootless checks"
fi

header "SUBUID / SUBGID MAPPING"

SUBUID_ENTRY=$(grep "^${CURRENT_USER}:" /etc/subuid 2>/dev/null || echo "")
SUBGID_ENTRY=$(grep "^${CURRENT_USER}:" /etc/subgid 2>/dev/null || echo "")

if [[ -n "$SUBUID_ENTRY" ]]; then
  pass "subuid entry found: $SUBUID_ENTRY"
  SUBUID_COUNT=$(echo "$SUBUID_ENTRY" | cut -d: -f3)
  if (( SUBUID_COUNT >= 65536 )); then
    pass "subuid range is sufficient ($SUBUID_COUNT UIDs)"
  else
    warn "subuid range is small ($SUBUID_COUNT UIDs) — 65536+ recommended"
  fi
else
  fail "No subuid entry for '$CURRENT_USER' in /etc/subuid"
  echo "  Fix: sudo usermod --add-subuids 100000-165535 $CURRENT_USER"
fi

if [[ -n "$SUBGID_ENTRY" ]]; then
  pass "subgid entry found: $SUBGID_ENTRY"
else
  fail "No subgid entry for '$CURRENT_USER' in /etc/subgid"
  echo "  Fix: sudo usermod --add-subgids 100000-165535 $CURRENT_USER"
fi

header "USER NAMESPACE CONFIGURATION"

MAX_USERNS=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo "0")
info "max_user_namespaces: $MAX_USERNS"
if (( MAX_USERNS >= 15000 )); then
  pass "User namespace limit sufficient ($MAX_USERNS)"
elif (( MAX_USERNS > 0 )); then
  warn "User namespace limit low ($MAX_USERNS) — consider increasing to 15000+"
else
  fail "User namespaces disabled (max_user_namespaces=0)"
  echo "  Fix: sudo sysctl -w user.max_user_namespaces=15000"
fi

# Check uid_map (only works if not root or if we can test)
if (( CURRENT_UID != 0 )); then
  UID_MAP=$(podman unshare cat /proc/self/uid_map 2>/dev/null || echo "failed")
  if [[ "$UID_MAP" != "failed" ]]; then
    pass "User namespace creation works"
    info "UID map (inside unshare): $UID_MAP"
  else
    fail "Could not create user namespace — check subuid/subgid and kernel config"
  fi
fi

header "CGROUP CONFIGURATION"

CGROUP_TYPE=$(stat -fc %T /sys/fs/cgroup/ 2>/dev/null || echo "unknown")
case "$CGROUP_TYPE" in
  cgroup2fs)
    pass "cgroup v2 active — rootless resource limits supported"
    # Check delegation
    DELEGATE_FILE="/etc/systemd/system/user@.service.d/delegate.conf"
    if [[ -f "$DELEGATE_FILE" ]]; then
      if grep -q "Delegate=yes" "$DELEGATE_FILE"; then
        pass "cgroup delegation configured ($DELEGATE_FILE)"
      else
        warn "delegate.conf exists but Delegate=yes not found"
      fi
    else
      warn "cgroup delegation not configured — rootless resource limits may not work"
      echo "  Fix:"
      echo "    sudo mkdir -p /etc/systemd/system/user@.service.d/"
      echo "    echo '[Service]' | sudo tee $DELEGATE_FILE"
      echo "    echo 'Delegate=yes' | sudo tee -a $DELEGATE_FILE"
      echo "    sudo systemctl daemon-reload"
    fi
    ;;
  tmpfs)
    warn "cgroup v1 active — rootless resource limits NOT available"
    echo "  Consider enabling cgroup v2: add 'systemd.unified_cgroup_hierarchy=1' to kernel cmdline"
    ;;
  *)
    warn "Could not determine cgroup version: $CGROUP_TYPE"
    ;;
esac

header "XDG_RUNTIME_DIR"

info "XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
  fail "XDG_RUNTIME_DIR is not set — rootless Podman may fail"
  echo "  Expected: /run/user/${CURRENT_UID}"
  echo "  Fix: ensure user session is via loginctl or systemd --user"
else
  EXPECTED_RUNTIME="/run/user/${CURRENT_UID}"
  if [[ "$XDG_RUNTIME_DIR" == "$EXPECTED_RUNTIME" ]]; then
    pass "XDG_RUNTIME_DIR matches expected path ($XDG_RUNTIME_DIR)"
  else
    warn "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR (expected $EXPECTED_RUNTIME)"
  fi
  if [[ -d "$XDG_RUNTIME_DIR" ]]; then
    pass "XDG_RUNTIME_DIR directory exists"
  else
    fail "XDG_RUNTIME_DIR directory does not exist: $XDG_RUNTIME_DIR"
  fi
fi

header "ROOTLESS STORAGE"

ROOTLESS_STORAGE="${HOME}/.local/share/containers/storage"
info "Expected rootless storage: $ROOTLESS_STORAGE"
if [[ -d "$ROOTLESS_STORAGE" ]]; then
  pass "Rootless storage directory exists"
  STORAGE_USAGE=$(du -sh "$ROOTLESS_STORAGE" 2>/dev/null | cut -f1)
  info "Rootless storage usage: $STORAGE_USAGE"
else
  info "Rootless storage not yet initialized (will be created on first use)"
fi

# Check storage config
USER_STORAGE_CONF="${HOME}/.config/containers/storage.conf"
if [[ -f "$USER_STORAGE_CONF" ]]; then
  info "User storage.conf present: $USER_STORAGE_CONF"
  DRIVER=$(grep '^\s*driver' "$USER_STORAGE_CONF" | head -1 || echo "not set")
  info "User-configured driver: $DRIVER"
fi

header "ROOTLESS NETWORKING MODE"

# Check what networking tools are available
NETWORKING_MODE="unknown"

if command -v pasta &>/dev/null; then
  pass "pasta (passt) installed: $(pasta --version 2>/dev/null | head -1 || echo 'version unknown')"
  NETWORKING_MODE="pasta"
elif command -v passt &>/dev/null; then
  pass "passt installed"
  NETWORKING_MODE="pasta"
else
  info "pasta/passt not found"
fi

if command -v slirp4netns &>/dev/null; then
  pass "slirp4netns installed: $(slirp4netns --version 2>/dev/null | head -1 || echo 'version unknown')"
  [[ "$NETWORKING_MODE" == "unknown" ]] && NETWORKING_MODE="slirp4netns"
else
  info "slirp4netns not found"
fi

case "$NETWORKING_MODE" in
  pasta)     pass "Rootless networking: pasta (recommended for RHEL 9+)" ;;
  slirp4netns) info "Rootless networking: slirp4netns (standard for RHEL 8)" ;;
  unknown)
    fail "No rootless networking backend found"
    echo "  Fix (RHEL 8):  sudo dnf install -y slirp4netns"
    echo "  Fix (RHEL 9+): sudo dnf install -y passt"
    ;;
esac

# Check active networking backend via podman info
if (( CURRENT_UID != 0 )); then
  NET_BACKEND=$(podman info --format '{{.Host.NetworkBackend}}' 2>/dev/null || echo "unknown")
  info "Active network backend (podman info): $NET_BACKEND"
fi

header "PRIVILEGED PORT ACCESS"

UNPRIV_PORT=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || echo "1024")
info "ip_unprivileged_port_start: $UNPRIV_PORT"
if (( UNPRIV_PORT <= 80 )); then
  pass "Rootless containers can bind to port 80 (start=$UNPRIV_PORT)"
elif (( UNPRIV_PORT <= 443 )); then
  warn "Rootless containers cannot bind to port 80 (start=$UNPRIV_PORT)"
  info "  Allow: sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80"
else
  info "Rootless containers cannot bind to ports < $UNPRIV_PORT"
  info "  Default (1024) prevents binding to privileged ports in rootless mode"
fi

echo -e "\n${BOLD}Rootless audit complete.${NC}"
```

---

### Script 04 — Quadlet Status

```bash
#!/usr/bin/env bash
# ============================================================================
# Podman - Quadlet Unit Status
# Version : 1.0.0
# Targets : RHEL 8+ with Podman installed
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

# Determine if running as root or user
IS_ROOT=false
(( EUID == 0 )) && IS_ROOT=true

SYSTEMCTL_OPTS=""
$IS_ROOT || SYSTEMCTL_OPTS="--user"

header "QUADLET AVAILABILITY"

GENERATOR="/usr/lib/systemd/system-generators/podman-system-generator"
USER_GENERATOR="/usr/lib/systemd/user-generators/podman-user-generator"

if [[ -x "$GENERATOR" ]]; then
  pass "Quadlet system generator present: $GENERATOR"
else
  warn "Quadlet system generator not found at $GENERATOR"
  info "  Quadlet requires Podman 4.4+ (RHEL 9.2+) or Podman 5.x (RHEL 10)"
fi

if [[ -x "$USER_GENERATOR" ]]; then
  pass "Quadlet user generator present: $USER_GENERATOR"
fi

# Check Podman version for Quadlet support
PODMAN_VER=$(podman --version 2>/dev/null | grep -oP '\d+\.\d+' | head -1 || echo "0.0")
MAJOR=$(echo "$PODMAN_VER" | cut -d. -f1)
MINOR=$(echo "$PODMAN_VER" | cut -d. -f2)
if (( MAJOR > 4 || (MAJOR == 4 && MINOR >= 4) )); then
  pass "Podman version supports Quadlet ($PODMAN_VER)"
else
  warn "Podman $PODMAN_VER — Quadlet requires 4.4+. Consider upgrading."
fi

header "QUADLET UNIT FILE INVENTORY"

SYSTEM_QUADLET_DIRS=(
  "/etc/containers/systemd"
  "/usr/share/containers/systemd"
  "/usr/lib/containers/systemd"
)
USER_QUADLET_DIR="${HOME}/.config/containers/systemd"

EXTENSIONS=("container" "volume" "network" "pod" "image" "kube")
TOTAL_FILES=0

for DIR in "${SYSTEM_QUADLET_DIRS[@]}"; do
  if [[ -d "$DIR" ]]; then
    info "Scanning system Quadlet directory: $DIR"
    for EXT in "${EXTENSIONS[@]}"; do
      FILES=$(find "$DIR" -name "*.${EXT}" 2>/dev/null | sort)
      if [[ -n "$FILES" ]]; then
        while IFS= read -r f; do
          echo "  [.${EXT}] $f"
          (( TOTAL_FILES++ ))
        done <<< "$FILES"
      fi
    done
  fi
done

if [[ -d "$USER_QUADLET_DIR" ]]; then
  info "Scanning user Quadlet directory: $USER_QUADLET_DIR"
  for EXT in "${EXTENSIONS[@]}"; do
    FILES=$(find "$USER_QUADLET_DIR" -name "*.${EXT}" 2>/dev/null | sort)
    if [[ -n "$FILES" ]]; then
      while IFS= read -r f; do
        echo "  [.${EXT}] $f"
        (( TOTAL_FILES++ ))
      done <<< "$FILES"
    fi
  done
fi

if (( TOTAL_FILES == 0 )); then
  info "No Quadlet unit files found in standard locations"
  info "Create .container files in /etc/containers/systemd/ (system) or"
  info "~/.config/containers/systemd/ (user) then run: systemctl daemon-reload"
else
  info "Total Quadlet unit files: $TOTAL_FILES"
fi

header "SYSTEMD UNITS FROM QUADLET"

info "Container-related systemd units:"
systemctl $SYSTEMCTL_OPTS list-units --type=service \
  --state=active,failed,activating,deactivating \
  2>/dev/null | grep -iE '(container|podman|\.service)' | grep -v '^$' \
  || info "No active container-related systemd units found"

echo ""
info "All container service units (any state):"
systemctl $SYSTEMCTL_OPTS list-unit-files --type=service \
  2>/dev/null | grep -iE '(container|podman)' | grep -v '^$' \
  || info "No container-related unit files found"

header "UNIT STATUS DETAILS"

# Find generated units (from Quadlet) and show status
GENERATED_UNITS=$(systemctl $SYSTEMCTL_OPTS list-unit-files --type=service 2>/dev/null \
  | awk '/\.service/ {print $1}' | xargs -I{} sh -c \
  "systemctl $SYSTEMCTL_OPTS cat {} 2>/dev/null | grep -l 'X-Podman' && echo {}" \
  2>/dev/null || true)

if [[ -n "$GENERATED_UNITS" ]]; then
  while IFS= read -r UNIT; do
    [[ -z "$UNIT" ]] && continue
    STATE=$(systemctl $SYSTEMCTL_OPTS is-active "$UNIT" 2>/dev/null || echo "unknown")
    case "$STATE" in
      active)   pass "$UNIT — $STATE" ;;
      failed)   fail "$UNIT — $STATE" ;;
      inactive) warn "$UNIT — $STATE" ;;
      *)        info "$UNIT — $STATE" ;;
    esac
  done <<< "$GENERATED_UNITS"
else
  info "Could not enumerate Quadlet-generated units via X-Podman header"
fi

header "AUTO-UPDATE LABEL CHECK"

info "Checking containers for io.containers.autoupdate label:"
AUTOUPDATE_CONTAINERS=$(podman ps -a --format '{{.Names}}' 2>/dev/null | while read -r NAME; do
  LABEL=$(podman inspect --format '{{index .Config.Labels "io.containers.autoupdate"}}' "$NAME" 2>/dev/null || echo "")
  [[ -n "$LABEL" ]] && echo "  $NAME: autoupdate=$LABEL"
done)

if [[ -n "$AUTOUPDATE_CONTAINERS" ]]; then
  pass "Containers with auto-update configured:"
  echo "$AUTOUPDATE_CONTAINERS"
else
  info "No containers have io.containers.autoupdate label set"
  info "Add label in .container Quadlet file: Label=io.containers.autoupdate=registry"
fi

header "AUTO-UPDATE TIMER"

for SCOPE in "" "--user"; do
  TIMER_STATUS=$(systemctl $SCOPE is-active podman-auto-update.timer 2>/dev/null || echo "not-found")
  ENABLED_STATUS=$(systemctl $SCOPE is-enabled podman-auto-update.timer 2>/dev/null || echo "not-found")
  if [[ "$SCOPE" == "--user" ]]; then
    SCOPE_LABEL="user"
  else
    SCOPE_LABEL="system"
  fi
  info "podman-auto-update.timer ($SCOPE_LABEL): active=$TIMER_STATUS, enabled=$ENABLED_STATUS"
  if [[ "$TIMER_STATUS" == "active" ]]; then
    pass "Auto-update timer is active ($SCOPE_LABEL)"
  elif [[ "$TIMER_STATUS" == "inactive" ]]; then
    warn "Auto-update timer exists but is not active ($SCOPE_LABEL)"
    echo "  Enable: systemctl $SCOPE enable --now podman-auto-update.timer"
  fi
done

header "QUADLET GENERATION TEST"

if [[ -x "$GENERATOR" ]]; then
  TMPDIR_TEST=$(mktemp -d)
  if $IS_ROOT; then
    "$GENERATOR" "$TMPDIR_TEST" "$TMPDIR_TEST" "$TMPDIR_TEST" 2>/dev/null && \
      GENERATED_COUNT=$(find "$TMPDIR_TEST" -name '*.service' | wc -l) || GENERATED_COUNT=0
    if (( GENERATED_COUNT > 0 )); then
      pass "Quadlet generator produced $GENERATED_COUNT service unit(s)"
      find "$TMPDIR_TEST" -name '*.service' -exec basename {} \; | while read -r SVC; do
        info "  Generated: $SVC"
      done
    else
      info "Quadlet generator ran but produced no units (no .container files configured?)"
    fi
  else
    info "Skipping generator test (requires root or user generator path)"
  fi
  rm -rf "$TMPDIR_TEST"
fi

header "PODMAN GENERATE SYSTEMD (deprecated)"

PODMAN_VER_FULL=$(podman --version | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
MAJOR_VER=$(echo "$PODMAN_VER_FULL" | cut -d. -f1)
if (( MAJOR_VER >= 5 )); then
  warn "Podman $PODMAN_VER_FULL: 'podman generate systemd' has been removed — use Quadlet"
elif (( MAJOR_VER == 4 )); then
  warn "Podman $PODMAN_VER_FULL: 'podman generate systemd' is deprecated — migrate to Quadlet"
else
  info "Podman $PODMAN_VER_FULL: 'podman generate systemd' available (consider Quadlet migration)"
fi

echo -e "\n${BOLD}Quadlet status check complete.${NC}"
```

---

## Part 5: Version-Specific Changes

### RHEL 8 — Podman 4.x

**Installation:**
```bash
# Module streams for Podman
dnf module list podman
dnf module enable container-tools:rhel8
dnf install -y podman buildah skopeo

# Check installed version
podman version
```

**Key characteristics:**
- Default OCI runtime: `runc`
- Container networking: CNI (Container Network Interface)
- DNS: `dnsmasq` CNI plugin
- Rootless networking: `slirp4netns`
- Cgroup version: cgroup v1 default (v2 available with kernel params)
- `podman generate systemd` — primary systemd integration method (not yet deprecated)
- No Quadlet support

**Notable RHEL 8 limitations:**
- No rootless resource limits (cgroup v1)
- Slower networking (slirp4netns vs pasta)
- CNI plugins require separate packages (`containernetworking-plugins`)
- `fuse-overlayfs` required for rootless overlay: `dnf install -y fuse-overlayfs`

**RHEL 8 specific configs:**
```bash
# Confirm CNI is active
podman info | grep networkBackend
# Output: networkBackend: cni

# CNI network configs stored at:
ls /etc/cni/net.d/
```

---

### RHEL 9 — Podman 4.x / 4.4+

**Installation:**
```bash
dnf install -y podman buildah skopeo

# Quadlet also requires:
# (included with podman 4.4+ package)
```

**Key changes from RHEL 8:**
- Default OCI runtime: `crun` (faster, lower memory)
- Container networking: Netavark (replaces CNI)
- DNS: Aardvark-DNS (replaces dnsmasq plugin)
- Rootless networking: `pasta` (replaces slirp4netns in 9.2+)
- Cgroup version: cgroup v2 default
- **Quadlet introduced** in Podman 4.4 (RHEL 9.2)
- `podman generate systemd` deprecated (still functional but discouraged)
- Rootless resource limits now work with cgroup v2 delegation

**RHEL 9 migration from RHEL 8:**
```bash
# If upgrading from RHEL 8, CNI configs need migration
podman network ls  # Networks migrated automatically in most cases

# Verify Netavark is active
podman info | grep networkBackend
# Output: networkBackend: netavark

# Verify aardvark-dns
rpm -q aardvark-dns
```

**Pasta networking setup:**
```bash
dnf install -y passt
# Set as default in containers.conf:
# [network]
# default_rootless_network_cmd = "pasta"
```

---

### RHEL 10 — Podman 5.x

**Key changes:**
- Podman 5.x — major version with breaking changes from 4.x
- `podman generate systemd` **removed** (Quadlet is now the only systemd integration)
- Enhanced Kubernetes YAML support (Deployment, DaemonSet resources)
- Improved Quadlet features (dependency ordering between units, pod-level Quadlet)
- Compose v2 support via `podman compose` (based on podman-compose or Docker Compose v2)
- Pasta networking default for all rootless containers
- Further SELinux policy improvements

**New in Podman 5.x:**
```bash
# podman compose (v2 support)
dnf install -y podman-compose
podman compose up -d

# Enhanced kube play
podman play kube --start deployment.yaml

# Improved network inspection
podman network inspect --format json mynet | jq .

# Health check improvements
podman healthcheck run --timeout 10s mycontainer
```

**RHEL 10 storage defaults:**
- Default driver: `overlay` with native kernel overlay (no fuse-overlayfs needed for rootless in most cases)
- Improved layer deduplication
- Better integration with container image garbage collection

---

## Quick Reference: Key File Locations

| File | Purpose |
|------|---------|
| `/etc/containers/storage.conf` | System storage configuration |
| `~/.config/containers/storage.conf` | User storage configuration |
| `/etc/containers/registries.conf` | Registry search, mirrors, blocks |
| `/etc/containers/registries.conf.d/` | Drop-in registry configs |
| `/etc/containers/policy.json` | Image signature policy |
| `/etc/containers/containers.conf` | System container defaults |
| `~/.config/containers/containers.conf` | User container defaults |
| `/etc/containers/systemd/` | System Quadlet unit files |
| `~/.config/containers/systemd/` | User Quadlet unit files |
| `/etc/subuid` | Rootless UID subordinate ranges |
| `/etc/subgid` | Rootless GID subordinate ranges |
| `/etc/cni/net.d/` | CNI network configs (RHEL 8) |
| `~/.local/share/containers/storage` | Rootless image/container storage |
| `/var/lib/containers/storage` | Root image/container storage |
| `/run/user/<UID>/podman/podman.sock` | Rootless Podman API socket |
| `/run/podman/podman.sock` | Rootful Podman API socket |

## Quick Reference: Essential Commands

```bash
# System health
podman system info
podman system df
podman version

# Container lifecycle
podman run -d --name web -p 8080:80 nginx
podman start|stop|restart|rm web
podman exec -it web /bin/bash

# Image management
podman pull registry.access.redhat.com/ubi9/ubi
podman images
podman image prune -a
skopeo inspect docker://nginx:latest
buildah bud -t myapp:latest .

# Quadlet workflow
# 1. Create /etc/containers/systemd/myapp.container
# 2. systemctl daemon-reload
# 3. systemctl start myapp
# 4. systemctl status myapp

# Cleanup
podman system prune -a -f
```
