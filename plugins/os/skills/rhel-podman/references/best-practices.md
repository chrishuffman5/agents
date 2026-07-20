# Podman Best Practices Reference

## Quadlet (systemd Integration, RHEL 9.2+)

Quadlet generates systemd units from declarative files. It replaces `podman generate systemd` (deprecated in Podman 4.4, removed in 5.0).

### Unit File Locations

- System: `/etc/containers/systemd/` (requires root)
- User: `~/.config/containers/systemd/` (rootless)
- Packages: `/usr/share/containers/systemd/`

After adding or modifying files:
```bash
systemctl daemon-reload          # system units
systemctl --user daemon-reload   # user units
```

### .container Unit File

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

Start: `systemctl start nginx` (Quadlet generates `nginx.service` automatically).

### .volume Unit File

```ini
# /etc/containers/systemd/myapp-data.volume
[Volume]
Driver=local
Label=app=myapp
```

### .network Unit File

```ini
# /etc/containers/systemd/myapp.network
[Network]
Driver=bridge
Subnet=10.89.1.0/24
Gateway=10.89.1.1
Label=app=myapp
```

### .kube Unit File

```ini
# /etc/containers/systemd/myapp.kube
[Unit]
Description=MyApp Kubernetes deployment

[Kube]
Yaml=/etc/containers/systemd/myapp-pod.yaml

[Install]
WantedBy=multi-user.target
```

### Quadlet Debugging

```bash
# Test unit generation without applying
/usr/lib/systemd/system-generators/podman-system-generator --dry-run

# Inspect generated unit
systemctl cat nginx.service

# View logs
journalctl -u nginx.service
```

---

## Image Management

### Buildah -- Building Images

```bash
# Build from Containerfile
buildah bud -t myapp:latest -f Containerfile .

# Build with layer caching
buildah bud --layers -t myapp:latest .

# Interactive build (no Dockerfile)
container=$(buildah from ubi9)
buildah run $container -- dnf install -y python3
buildah config --cmd "python3 /app/server.py" $container
buildah config --label "version=1.0" $container
buildah commit $container myapp:latest
buildah rm $container
```

### Multi-Stage Builds

```dockerfile
# Stage 1: Build
FROM registry.access.redhat.com/ubi9/ubi as builder
RUN dnf install -y gcc make
COPY . /src
WORKDIR /src
RUN make build

# Stage 2: Runtime (minimal image)
FROM registry.access.redhat.com/ubi9/ubi-minimal
COPY --from=builder /src/bin/myapp /usr/local/bin/
USER 1001
CMD ["/usr/local/bin/myapp"]
```

### Skopeo -- Image Operations

```bash
# Inspect without pulling
skopeo inspect docker://registry.access.redhat.com/ubi9/ubi:latest

# Copy between registries
skopeo copy docker://docker.io/nginx:latest docker://myregistry.internal/nginx:latest

# Copy to local OCI directory
skopeo copy docker://nginx:latest oci:/tmp/nginx-oci

# Sync entire repository
skopeo sync --src docker --dest dir docker.io/library/nginx /tmp/mirrors/

# List available tags
skopeo list-tags docker://docker.io/library/nginx

# Delete image from registry
skopeo delete docker://myregistry.internal/old-image:tag
```

---

## Security Best Practices

### SELinux Volume Labels

```bash
# :Z -- private label (only this container)
podman run -v /host/path:/container/path:Z myimage

# :z -- shared label (multiple containers)
podman run -v /host/path:/container/path:z myimage

# Never use :Z on /home, /etc, /tmp, /var
# Use dedicated directories for container volumes
```

### Capability Management

```bash
# Drop all capabilities, add only what is needed
podman run --cap-drop=ALL --cap-add=NET_BIND_SERVICE nginx

# Run with zero extra capabilities
podman run --cap-drop=ALL myapp
```

### Read-Only Root Filesystem

```bash
podman run \
  --read-only \
  --tmpfs /tmp:rw,size=100m,mode=1777 \
  --tmpfs /run:rw,size=50m \
  myapp
```

### No-New-Privileges

```bash
# Prevent setuid binaries from gaining privileges
podman run --security-opt no-new-privileges myapp
```

### Seccomp Profiles

```bash
# Custom seccomp profile
podman run --security-opt seccomp=/etc/containers/seccomp.json myapp

# Default profile blocks ~300 syscalls
podman info --format '{{.Host.SecurityOptions}}'
```

### User Namespace Isolation

```bash
# Isolated user namespace even in rootful mode
podman run --userns=auto myapp

# Map to specific UID range
podman run --uidmap 0:100000:65536 myapp
```

### Secrets Management

```bash
# Create secret
printf "mysecretpassword" | podman secret create db-password -

# Use secret in container (mounted at /run/secrets/<name>)
podman run --secret db-password myapp

# Use as environment variable
podman run --secret db-password,type=env,target=DB_PASSWORD myapp

# List and inspect
podman secret ls
podman secret inspect db-password
```

### Recommended Production Flags

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

## Auto-Update

### Label-Based Policy

```ini
# In .container Quadlet file:
Label=io.containers.autoupdate=registry    # check registry for newer image
Label=io.containers.autoupdate=local       # only update if local image changed
```

### Manual Trigger

```bash
podman auto-update               # Update all labeled containers
podman auto-update --dry-run     # Preview what would update
podman auto-update --format json # JSON report
```

### Systemd Timer

```bash
systemctl enable --now podman-auto-update.timer         # system
systemctl --user enable --now podman-auto-update.timer   # rootless
systemctl status podman-auto-update.timer
```

### Rollback on Failure

Quadlet + auto-update uses systemd restart. If the new image fails health checks, systemd restarts with the previous image:
```ini
[Service]
Restart=on-failure
RestartSec=10
StartLimitBurst=3
```

---

## Resource Management

### CPU Limits

```bash
podman run --cpus=1.5 myapp              # Limit to 1.5 CPUs
podman run --cpu-shares=512 myapp        # Relative weight (default 1024)
podman run --cpuset-cpus=0,1 myapp       # Pin to specific CPUs
```

### Memory Limits

```bash
podman run --memory=512m myapp                    # Hard limit
podman run --memory=512m --memory-swap=1g myapp   # Memory + swap
podman run --memory-reservation=256m myapp        # Soft limit
```

### cgroup v2 (RHEL 9+)

```bash
# Verify cgroup version
stat -fc %T /sys/fs/cgroup/
# cgroup2fs = v2, tmpfs = v1
```

### Systemd Slice Assignment (Quadlet)

```ini
[Service]
Slice=container.slice
CPUQuota=150%
MemoryMax=512M
```

### Block I/O Limits

```bash
podman run --device-read-bps /dev/sda:10mb myapp
podman run --device-write-iops /dev/sda:100 myapp
```

### Live Monitoring

```bash
podman stats                          # Real-time usage
podman stats --no-stream              # Single snapshot
podman stats --no-stream --format json # Automation-friendly
```

---

## Podman Machine (Development)

Podman Machine creates a lightweight VM for running Linux containers on macOS and Windows.

```bash
podman machine init                                    # Default settings
podman machine init --cpus 4 --memory 8192 --disk-size 100  # Custom
podman machine start
podman machine stop
podman machine ssh
podman machine list
```

VM backends:
- macOS: QEMU, Apple Hypervisor Framework, or Virtualization.framework
- Windows: WSL2

The local `podman` CLI connects to the VM via a REST API socket:
```bash
podman system connection list
podman system connection default myvm
```
