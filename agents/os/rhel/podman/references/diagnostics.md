# Podman Diagnostics Reference

## Container Troubleshooting

### Logs

```bash
# Follow logs
podman logs -f mycontainer

# Last 50 lines
podman logs --tail 50 mycontainer

# With timestamps
podman logs -t mycontainer

# Since a specific time
podman logs --since 30m mycontainer

# Pod logs (all containers)
podman pod logs mypod
```

### Inspect

```bash
# Full container metadata
podman inspect mycontainer

# Specific fields
podman inspect --format '{{.State.Status}}' mycontainer
podman inspect --format '{{.NetworkSettings.IPAddress}}' mycontainer
podman inspect --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}' mycontainer

# Image inspection
podman image inspect myimage:tag
```

### Process and Resource Inspection

```bash
# Container process list
podman top mycontainer
podman top mycontainer pid,ppid,user,comm,args,pcpu,pmem

# Real-time stats
podman stats mycontainer

# Health check status
podman inspect --format '{{.State.Healthcheck}}' mycontainer
podman healthcheck run mycontainer
```

### Events

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

### Entering Containers

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

### Debugging Failed Starts

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

## Rootless Troubleshooting

### subuid/subgid Misconfiguration

```bash
# Check entries exist
grep $USER /etc/subuid /etc/subgid

# No entry = rootless containers fail with "user namespaces not enabled"
# Fix:
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER
podman system migrate

# Check mapping is active
podman unshare cat /proc/self/uid_map
# Expected output: 0 100000 65536
```

### Namespace Issues

```bash
# Check if user namespaces are enabled
cat /proc/sys/user/max_user_namespaces
# 0 = disabled. Fix:
sudo sysctl -w user.max_user_namespaces=15000

# Verify namespace creation works
podman unshare id
# Should show: uid=0(root) gid=0(root)
```

### Storage Permission Problems

```bash
# Reset rootless storage (WARNING: removes all containers and images)
podman system reset

# Check permissions
ls -la ~/.local/share/containers/

# Check if overlay works
podman info 2>&1 | grep -i driver

# Fuse-overlayfs not installed (needed on some RHEL 8 configs)
sudo dnf install -y fuse-overlayfs
```

### Networking Issues (Rootless)

```bash
# slirp4netns not found (RHEL 8)
sudo dnf install -y slirp4netns

# pasta/passt not found (RHEL 9+)
sudo dnf install -y passt

# Check which backend is active
podman info | grep -i networkbackend

# DNS not resolving inside container
podman run --rm alpine cat /etc/resolv.conf

# Override DNS
podman run --dns=8.8.8.8 myimage
```

### SELinux Denials (Rootless)

```bash
# Check for denials
ausearch -m avc -ts recent | grep podman

# Common fix -- relabel volume with :Z
podman run -v /mydata:/data:Z myimage

# Check container SELinux label
podman inspect --format '{{.ProcessLabel}}' mycontainer
```

---

## Common Issues and Fixes

### Image Pull Failures

| Symptom | Cause | Fix |
|---|---|---|
| `unauthorized: authentication required` | Not logged in | `podman login registry.redhat.io` |
| `name unknown: repository not found` | Wrong image name | Verify with `skopeo inspect` |
| `connection refused` / timeout | DNS or firewall | Check `/etc/resolv.conf`, firewalld |
| `short-name resolution` prompt | Unqualified name | Use fully-qualified name or configure aliases |
| `toomanyrequests` | Docker Hub rate limit | Login to Docker Hub or use mirror |

```bash
# Debug pull
podman pull --log-level=debug nginx:latest 2>&1 | head -50

# Test registry connectivity
curl -v https://registry.access.redhat.com/v2/

# Check search registries
podman info | grep registries -A 10
```

### Container Networking Issues

```bash
# Port conflict
ss -tlnp | grep 8080

# Container cannot reach host service (RHEL 9+ Netavark)
podman run --add-host=host.containers.internal:host-gateway myapp

# DNS not working inside container
podman run --rm alpine nslookup google.com
podman network inspect mynet | grep dns

# Firewall blocking
sudo firewall-cmd --list-all
sudo nft list ruleset | grep podman
```

### Storage Issues

```bash
# Check disk space
podman system df
df -h /var/lib/containers

# Clean up
podman image prune -a         # Remove unused images
podman container prune        # Remove stopped containers
podman volume prune           # Remove unused volumes
podman system prune -a -f     # Full cleanup (removes everything unused)

# Dangling images
podman images -f dangling=true
podman image prune
```

### Permission Denied

```bash
# Volume mount: SELinux denial
ausearch -m avc -ts recent
# Fix: use :Z flag
podman run -v /mydata:/data:Z myimage

# Volume mount: file ownership mismatch (rootless)
# Container UID 0 = host UID 100000 (from subuid)
podman unshare chown -R 0:0 /mydata

# Podman socket location
# Rootless: /run/user/<UID>/podman/podman.sock
# Rootful:  /run/podman/podman.sock
```

### cgroup Resource Limit Issues

```bash
# Verify cgroup version
stat -fc %T /sys/fs/cgroup/
# cgroup2fs = v2 (resource limits work rootless)
# tmpfs = v1 (resource limits only rootful)

# Check cgroup delegation (required for rootless limits on cgroup v2)
cat /etc/systemd/system/user@.service.d/delegate.conf
# Should contain: Delegate=yes
```

---

## Key Diagnostic Commands

```bash
# System info
podman info
podman version
podman system df

# Container inspection
podman ps -a
podman inspect mycontainer
podman logs mycontainer
podman top mycontainer
podman stats --no-stream

# Network inspection
podman network ls
podman network inspect mynet
podman port mycontainer

# Storage inspection
podman images
podman volume ls
podman system df -v

# Events
podman events --since 1h

# Rootless checks
podman unshare id
podman info --format '{{.Host.NetworkBackend}}'
podman info --format '{{.Store.GraphDriverName}}'

# Debug mode
podman --log-level=debug run myimage
```
