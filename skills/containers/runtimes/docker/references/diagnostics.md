# Docker Diagnostics and Troubleshooting

## Container Inspection

### Logs

```bash
# Follow logs with tail
docker logs -f --tail 100 <container>

# Logs since a specific time
docker logs --since 2024-01-01T00:00:00Z <container>
docker logs --since 30m <container>

# Show timestamps
docker logs -t <container>

# Logs from a dead container (still works if not removed)
docker logs <dead-container-id>
```

**Note**: `docker logs` only works with `json-file` and `journald` logging drivers. If using fluentd, syslog, or other drivers, query the backend directly.

### Inspect

```bash
# Full JSON metadata
docker inspect <container>

# Extract specific fields with Go templates
docker inspect --format '{{.State.Status}}' <container>
docker inspect --format '{{.NetworkSettings.IPAddress}}' <container>
docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' <container>
docker inspect --format '{{json .Mounts}}' <container> | jq .
docker inspect --format '{{.Config.Healthcheck}}' <container>

# Check exit code
docker inspect --format '{{.State.ExitCode}}' <container>
# 0 = normal, 1 = app error, 137 = SIGKILL (OOM or docker stop timeout), 139 = SIGSEGV, 143 = SIGTERM

# Check OOM killed
docker inspect --format '{{.State.OOMKilled}}' <container>

# Check restart count
docker inspect --format '{{.RestartCount}}' <container>
```

### Stats (Live Resource Usage)

```bash
# Live resource usage (all containers)
docker stats

# Specific containers, no streaming
docker stats --no-stream <container1> <container2>

# Format output
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
```

Key metrics:
- **CPU %**: May exceed 100% on multi-core (200% = 2 cores fully used)
- **MEM USAGE / LIMIT**: Current RSS / cgroup memory limit
- **NET I/O**: Network bytes received / sent
- **BLOCK I/O**: Disk bytes read / written
- **PIDs**: Number of processes in the container

### Events

```bash
# Stream real-time events
docker events

# Filter by container
docker events --filter container=<name>

# Filter by event type
docker events --filter event=die
docker events --filter event=oom
docker events --filter event=health_status

# Filter by time range
docker events --since 1h --until 30m

# JSON output for parsing
docker events --format '{{json .}}'
```

Event types: `create`, `start`, `stop`, `die`, `kill`, `oom`, `pause`, `unpause`, `health_status`, `exec_create`, `exec_start`, `attach`, `detach`, `resize`.

### Top (Process List)

```bash
# Show processes inside container
docker top <container>

# With custom ps options
docker top <container> -eo pid,ppid,user,stat,args
```

### Diff (Filesystem Changes)

```bash
# Show files changed in container's writable layer
docker diff <container>
# A = added, C = changed, D = deleted
```

## System-Level Diagnostics

### System Info

```bash
# Comprehensive daemon info
docker info

# Key fields to check:
# - Server Version
# - Storage Driver (overlay2, fuse-overlayfs)
# - Logging Driver
# - Cgroup Driver (systemd vs cgroupfs)
# - Cgroup Version (1 vs 2)
# - Kernel Version
# - Operating System
# - Security Options (seccomp, apparmor, rootless)
# - Runtimes (runc, plus any alternatives)
# - containerd version
# - runc version
```

### Disk Usage

```bash
# Summary of disk usage
docker system df

# Detailed breakdown
docker system df -v

# Shows:
# - Images: total size, shared layers, reclaimable
# - Containers: writable layer size, log size
# - Volumes: size, whether in use
# - Build Cache: BuildKit cache size
```

### Cleanup

```bash
# Remove stopped containers, unused networks, dangling images, build cache
docker system prune

# Also remove unused images (not just dangling) and volumes
docker system prune -a --volumes

# Targeted cleanup
docker container prune            # stopped containers
docker image prune -a             # all unused images
docker volume prune               # unused volumes
docker builder prune              # BuildKit cache
docker network prune              # unused networks

# Remove images older than 24 hours
docker image prune -a --filter "until=24h"
```

## Troubleshooting Workflows

### Container Won't Start

1. Check the exit code: `docker inspect --format '{{.State.ExitCode}}' <container>`
2. Read logs: `docker logs <container>`
3. Check events: `docker events --filter container=<name> --since 1h`
4. Inspect health check: `docker inspect --format '{{json .State.Health}}' <container> | jq .`
5. Try running interactively: `docker run -it --entrypoint /bin/sh <image>`
6. Check resource limits: `docker inspect --format '{{json .HostConfig.Resources}}' <container> | jq .`

### Container OOM Killed

1. Confirm OOM: `docker inspect --format '{{.State.OOMKilled}}' <container>` (true = OOM)
2. Check memory limit: `docker inspect --format '{{.HostConfig.Memory}}' <container>`
3. Check current usage: `docker stats --no-stream <container>`
4. Check kernel OOM events: `dmesg | grep -i oom`
5. Increase limit or optimize application memory usage
6. Exit code 137 without OOMKilled=true usually means `docker stop` timed out and sent SIGKILL

### Networking Issues

```bash
# Check container's network settings
docker inspect --format '{{json .NetworkSettings.Networks}}' <container> | jq .

# Check DNS resolution inside container
docker exec <container> nslookup <other-container-name>
docker exec <container> cat /etc/resolv.conf

# Check connectivity
docker exec <container> ping <target>
docker exec <container> wget -qO- http://<target>:<port>/

# Check published ports
docker port <container>

# Check bridge network
docker network inspect <network-name>

# Check iptables rules (host)
iptables -t nat -L DOCKER -n -v
iptables -L DOCKER-USER -n -v

# Verify embedded DNS is working (custom bridge only)
docker exec <container> cat /etc/resolv.conf
# Should show 127.0.0.11 for custom bridges
```

### Storage Issues

```bash
# Check which storage driver is in use
docker info | grep "Storage Driver"

# Check container's writable layer size
docker ps -s

# Check for large files in container
docker exec <container> du -sh /* 2>/dev/null | sort -rh | head -20

# Check volume mount
docker inspect --format '{{json .Mounts}}' <container> | jq .

# Verify overlay mount
mount | grep overlay

# Check if XFS has ftype=1 (required for overlay2)
xfs_info /var/lib/docker | grep ftype
```

### Build Issues

```bash
# Build with verbose output (no cache)
docker buildx build --no-cache --progress=plain .

# Debug a failed build step (use intermediate image)
docker run -it <last-successful-layer-sha> /bin/sh

# Check BuildKit cache
docker buildx du

# Prune build cache
docker builder prune -a

# Check build context size
tar -cf - . | wc -c    # should be small; check .dockerignore

# Multi-platform build debug
docker buildx build --platform linux/amd64 --load .   # load single-platform locally
```

### Daemon Issues

```bash
# Check daemon status
systemctl status docker

# Check daemon logs
journalctl -u docker.service -f
journalctl -u docker.service --since "1 hour ago"

# Validate daemon.json syntax
python3 -c "import json; json.load(open('/etc/docker/daemon.json'))"

# Check containerd status
systemctl status containerd

# Check containerd logs
journalctl -u containerd.service -f

# Test Docker socket
curl --unix-socket /var/run/docker.sock http://localhost/version
```

## Performance Analysis

### Container CPU Throttling

```bash
# Check if container is being throttled (cgroup v2)
cat /sys/fs/cgroup/docker/<container-id>/cpu.stat
# Look for nr_throttled and throttled_usec

# Check CPU quota and period
docker inspect --format '{{.HostConfig.NanoCpus}}' <container>  # --cpus
docker inspect --format '{{.HostConfig.CpuQuota}}' <container>  # --cpu-quota
docker inspect --format '{{.HostConfig.CpuPeriod}}' <container> # --cpu-period
```

### Network Performance

```bash
# Benchmark network throughput between containers
docker run --rm --network mynet nicolaka/netshoot iperf3 -c <target-container>

# Check MTU settings
docker exec <container> ip link show eth0

# Userland proxy overhead: disable for better performance
# daemon.json: "userland-proxy": false
```

### I/O Performance

```bash
# Check I/O limits
docker inspect --format '{{json .HostConfig.BlkioDeviceReadBps}}' <container>

# Monitor I/O in real-time
docker stats --format "{{.Name}}: {{.BlockIO}}"
```

## Health Check Debugging

```bash
# View health check configuration
docker inspect --format '{{json .Config.Healthcheck}}' <container> | jq .

# View health check history (last 5 results)
docker inspect --format '{{json .State.Health}}' <container> | jq .

# Health states: starting, healthy, unhealthy
# Check health status
docker inspect --format '{{.State.Health.Status}}' <container>

# Run health check manually
docker exec <container> curl -f http://localhost:8080/health
```

## Compose Diagnostics

```bash
# Show running services
docker compose ps

# Show logs for all services
docker compose logs -f

# Show logs for specific service
docker compose logs -f api

# Check resolved compose configuration (merged YAML)
docker compose config

# Show events
docker compose events

# Execute in a service container
docker compose exec api bash

# View compose project resource usage
docker compose top
```
