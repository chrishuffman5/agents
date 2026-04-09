# Podman Best Practices

## Rootless Setup Guide

### Prerequisites Checklist

```bash
# 1. Verify kernel supports user namespaces
cat /proc/sys/kernel/unprivileged_userns_clone   # should be 1
# If 0: sysctl -w kernel.unprivileged_userns_clone=1 (persist in /etc/sysctl.d/)

# 2. Check sub-UID/GID configuration
cat /etc/subuid    # username:100000:65536
cat /etc/subgid    # username:100000:65536
# If missing: usermod --add-subuids 100000-165535 --add-subgids 100000-165535 username

# 3. Verify cgroup v2 with user delegation
cat /sys/fs/cgroup/cgroup.controllers     # should list cpu, memory, io, pids
ls /sys/fs/cgroup/user.slice/             # should exist

# 4. Enable lingering (keeps user systemd running after logout)
loginctl enable-linger $USER

# 5. Verify Podman rootless info
podman info --format '{{.Host.Security.Rootless}}'   # should be true
```

### Rootless Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `ERRO[0000] cannot find UID/GID for user` | Missing sub-UID/GID | `usermod --add-subuids 100000-165535 username` |
| `ERRO cannot setup namespace` | Kernel rejects user namespace | Set `kernel.unprivileged_userns_clone=1` |
| Container exits with permission denied | SELinux or file ownership | Use `:z`/`:Z` volume label or `--userns=keep-id` |
| Cannot bind port 80/443 | Privileged port | Set `net.ipv4.ip_unprivileged_port_start=0` |
| Slow networking | Using slirp4netns | Switch to pasta (default in Podman 5+) |
| `XDG_RUNTIME_DIR not set` | No systemd user session | `loginctl enable-linger $USER` and re-login |

### Rootless Volume Permissions

```bash
# Problem: Container runs as root (UID 0) but maps to host UID 100000
# Host files owned by your UID (1000) are inaccessible

# Solution 1: keep-id (maps host UID into container)
podman run --userns=keep-id -v /home/user/data:/data myimage

# Solution 2: Change ownership inside container
podman unshare chown -R 0:0 /home/user/data

# Solution 3: Use named volumes (Podman manages permissions)
podman volume create mydata
podman run -v mydata:/data myimage
```

## Quadlet Patterns

### Single Service

```ini
# ~/.config/containers/systemd/webapp.container
[Unit]
Description=Web Application
After=network-online.target

[Container]
Image=registry.example.com/webapp:v3.0
ContainerName=webapp
PublishPort=8080:8080
Environment=NODE_ENV=production
Volume=webapp-data.volume:/app/data:z
Network=webapp.network
HealthCmd=curl -f http://localhost:8080/health
HealthInterval=30s
HealthRetries=3
ReadOnly=true
RunInit=true
AutoUpdate=registry
UserNS=keep-id

[Service]
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

### Multi-Container Application (Pod)

```ini
# webapp.pod
[Pod]
PodName=webapp
PublishPort=8080:80
PublishPort=5432:5432
Network=webapp.network

# webapp-nginx.container
[Unit]
Description=Nginx Frontend
After=webapp-api.service

[Container]
Pod=webapp.pod
Image=nginx:1.27-alpine
ContainerName=webapp-nginx
Volume=./nginx.conf:/etc/nginx/nginx.conf:ro,z

[Service]
Restart=on-failure

# webapp-api.container
[Unit]
Description=API Backend
After=webapp-db.service

[Container]
Pod=webapp.pod
Image=registry.example.com/api:v2.0
ContainerName=webapp-api
Environment=DATABASE_URL=postgresql://localhost:5432/myapp
HealthCmd=wget -qO- http://localhost:3000/health
HealthInterval=15s

[Service]
Restart=on-failure

# webapp-db.container
[Container]
Pod=webapp.pod
Image=postgres:16-alpine
ContainerName=webapp-db
Environment=POSTGRES_DB=myapp
EnvironmentFile=%h/.config/webapp/db.env
Volume=webapp-pgdata.volume:/var/lib/postgresql/data:Z

[Service]
Restart=on-failure
```

### Supporting Resources

```ini
# webapp.network
[Network]
Driver=bridge
Subnet=172.20.0.0/16
Gateway=172.20.0.1
DNS=true

# webapp-data.volume
[Volume]
Driver=local
Label=app=webapp

# webapp-pgdata.volume
[Volume]
Driver=local
Label=app=webapp
Label=component=database
```

### Quadlet Lifecycle Commands

```bash
# After creating or modifying Quadlet files:
systemctl --user daemon-reload

# Enable and start
systemctl --user enable --now webapp-nginx
systemctl --user enable --now webapp-api
systemctl --user enable --now webapp-db

# Or for pods, start the pod service:
systemctl --user start webapp-pod

# Check generated unit files
systemctl --user cat webapp-nginx.service

# Verify Quadlet generation
/usr/lib/systemd/user-generators/podman-user-generator /tmp/quadlet-test
ls /tmp/quadlet-test/
```

## Docker Migration Guide

### Phase 1: CLI Migration

```bash
# Test compatibility with alias
alias docker=podman

# Verify basic operations work
podman pull nginx:latest
podman run -d --name test -p 8080:80 nginx:latest
podman logs test
podman exec -it test bash
podman stop test && podman rm test
```

### Phase 2: Compose Migration

```bash
# Option A: Use podman-compose
pip3 install podman-compose
podman-compose up -d

# Option B: Use Docker Compose with Podman socket (better compatibility)
systemctl --user enable --now podman.socket
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock
docker compose up -d
```

### Phase 3: Production Migration (Quadlet)

Convert Docker Compose services to Quadlet files for production:

```yaml
# Docker Compose (before)
services:
  api:
    image: myapp/api:v2.0
    ports: ["8080:8080"]
    environment:
      DATABASE_URL: postgresql://db:5432/myapp
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
```

```ini
# Quadlet (after)
# api.container
[Unit]
Description=API Service
After=db.service

[Container]
Image=myapp/api:v2.0
PublishPort=8080:8080
Environment=DATABASE_URL=postgresql://db:5432/myapp
Network=myapp.network
HealthCmd=curl -f http://localhost:8080/health
HealthInterval=30s
AutoUpdate=registry

[Service]
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

### Key Differences to Address During Migration

| Docker Pattern | Podman Equivalent |
|---|---|
| `restart: unless-stopped` | `[Service] Restart=on-failure` in Quadlet |
| `docker.sock` mount (CI/CD tools) | `podman.sock` or rootless socket |
| `--privileged` | Avoid; use specific capabilities instead |
| Named volumes (Docker default) | Named volumes work; add `:z` for SELinux |
| Build context with `.dockerignore` | Same (Podman uses `.containerignore` or `.dockerignore`) |
| Docker Hub default registry | Configure in `/etc/containers/registries.conf` |
| `docker-compose` CLI | `podman-compose` or socket emulation |

## systemd Integration Best Practices

### Enable Lingering

```bash
loginctl enable-linger $USER
```

Without lingering, all user systemd services (including Quadlet containers) stop when the user logs out.

### Auto-Update Pattern

```ini
# In .container file:
[Container]
AutoUpdate=registry        # Check for new image tags
# or
AutoUpdate=local           # Use locally built images

# Enable the timer:
systemctl --user enable --now podman-auto-update.timer

# Timer runs daily by default. Customize:
systemctl --user edit podman-auto-update.timer
# [Timer]
# OnCalendar=*-*-* 03:00:00     # run at 3 AM daily
```

### Logging

```bash
# Quadlet containers log to journald by default
journalctl --user -u myapp -f

# Or check container logs directly
podman logs -f myapp

# Configure log driver per container
[Container]
LogDriver=journald
```

### Health Check Integration

systemd can use container health status for dependency management:

```ini
[Container]
HealthCmd=curl -f http://localhost:8080/health
HealthInterval=10s
HealthRetries=3
HealthStartPeriod=30s

[Service]
# systemd will track unhealthy containers and can trigger restarts
Restart=on-failure
```

## Security Best Practices

### Rootless Hardening

```bash
# Run with minimal capabilities
podman run --cap-drop ALL --cap-add NET_BIND_SERVICE myimage

# Read-only rootfs
podman run --read-only --tmpfs /tmp myimage

# No new privileges
podman run --security-opt no-new-privileges myimage

# Seccomp profile
podman run --security-opt seccomp=/path/to/profile.json myimage
```

### Image Trust and Verification

```bash
# Configure signature verification
# /etc/containers/policy.json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "registry.example.com": [{"type": "sigstoreSigned", "keyPath": "/etc/pki/rpm-gpg/RPM-GPG-KEY-myorg"}],
      "docker.io/library": [{"type": "insecureAcceptAnything"}]
    }
  }
}

# Inspect images without pulling
skopeo inspect docker://registry.example.com/myapp:v2.0
```

### Resource Limits

```bash
# CPU limit
podman run --cpus 1.5 myimage

# Memory limit
podman run --memory 512m --memory-swap 1g myimage

# PID limit (prevent fork bombs)
podman run --pids-limit 256 myimage

# In Quadlet:
[Container]
PodmanArgs=--cpus 1.5 --memory 512m --pids-limit 256
```
