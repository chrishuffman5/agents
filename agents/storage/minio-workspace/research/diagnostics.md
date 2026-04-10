# MinIO Diagnostics

## Overview

MinIO's diagnostic toolkit is built around the `mc` client (MinIO Client) and the `mc admin` subcommands. Many advanced diagnostics (SUBNET health reports, full cluster diag bundles) were moved to AIStor-only in 2025, but the core `mc admin` commands remain available in the archived community edition's last releases.

---

## mc admin Commands Reference

### Cluster Health and Status

```bash
# Overall cluster status: drive states, server versions, free space
mc admin info myminio

# Detailed server status (JSON for parsing)
mc admin info myminio --json

# Check if MinIO is alive (HTTP health endpoint equivalent)
mc admin ping myminio
```

The `mc admin info` output shows each server node, its drives (online/offline/healing), total/used capacity, and server version. This is the first command to run when investigating any cluster issue.

### Service Management

```bash
# Restart all nodes (rolling restart — one node at a time)
mc admin service restart myminio

# Stop all nodes (graceful shutdown)
mc admin service stop myminio

# Freeze cluster (pause all I/O for maintenance)
mc admin service freeze myminio

# Unfreeze cluster
mc admin service unfreeze myminio
```

Rolling restart is safe in a healthy cluster with write quorum available. Always verify cluster health with `mc admin info` before and after restarts.

### Configuration Management

```bash
# View all configuration keys and current values
mc admin config get myminio

# View a specific subsystem configuration
mc admin config get myminio api
mc admin config get myminio notify_kafka
mc admin config get myminio logger_webhook

# Set a configuration value
mc admin config set myminio api \
  requests_deadline=2m \
  requests_max=1000

# Reset a subsystem to defaults
mc admin config reset myminio api

# Export entire config to file (for backup)
mc admin config export myminio > minio-config.env

# Import config from file
mc admin config import myminio < minio-config.env
```

After changing configuration, restart is required for most settings:
```bash
mc admin service restart myminio
```

---

## Health Checks

### HTTP Health Endpoints

MinIO exposes health check endpoints consumable by load balancers and Kubernetes probes:

| Endpoint                       | Status Code | Meaning                                |
|-------------------------------|-------------|----------------------------------------|
| `/minio/health/live`          | 200         | Server process is alive                |
| `/minio/health/ready`         | 200         | Ready to serve traffic                 |
| `/minio/health/cluster`       | 200         | Cluster has write quorum               |
| `/minio/health/cluster?maintenance=true` | 200 | Safe to take this node offline  |

```bash
# Manual health check
curl -I https://minio.example.com/minio/health/live
curl -I https://minio.example.com/minio/health/cluster

# Check if node can be taken offline (maintenance mode check)
curl -I https://minio-node1.example.com/minio/health/cluster?maintenance=true
```

Kubernetes liveness and readiness probe configuration:
```yaml
livenessProbe:
  httpGet:
    path: /minio/health/live
    port: 9000
    scheme: HTTPS
  initialDelaySeconds: 30
  periodSeconds: 15
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /minio/health/ready
    port: 9000
    scheme: HTTPS
  initialDelaySeconds: 15
  periodSeconds: 10
```

### Performance Diagnostics

```bash
# Run all performance tests against the cluster
mc support perf myminio

# Test specific subsystems
mc support perf myminio --throughput    # S3 GET/PUT throughput
mc support perf myminio --net          # Network IO between nodes
mc support perf myminio --storage      # Drive read/write speed

# Run full diagnostic bundle (requires SUBNET/AIStor in newer versions)
mc support diag myminio

# Specific diagnostic checks
mc support diag myminio --check=sys.drive,sys.mem,sys.cpu
```

The `mc support perf` tests:
- PUT test: writes objects and measures aggregate write throughput.
- GET test: reads previously written objects and measures read throughput.
- Network test: measures inter-node bandwidth and latency.
- Storage test: measures raw disk read/write performance.

---

## Drive Failure Diagnostics

### Identifying Failed Drives

```bash
# View all drives and their states
mc admin info myminio

# JSON output for scripting
mc admin info myminio --json | jq '.info.servers[].drives[] | select(.state != "ok")'
```

Drive states reported:
| State     | Meaning                                               |
|-----------|-------------------------------------------------------|
| `ok`      | Drive is healthy and operational                      |
| `offline` | Drive not accessible (failed, disconnected, or node down)|
| `healing` | Drive replaced and healing in progress                |
| `unformatted`| New drive detected, needs to be formatted by MinIO |
| `missing` | Drive slot expected but not found                     |

### Drive Replacement Procedure

1. Identify the failed drive using `mc admin info myminio`.
2. Replace the physical drive without shutting down the node (hot-swap if hardware supports it).
3. Format the new drive with XFS:
   ```bash
   mkfs.xfs -f /dev/sdX
   mount /dev/sdX /mnt/diskN
   ```
4. MinIO will automatically detect the new drive and begin healing.
5. Monitor healing progress:
   ```bash
   mc admin heal myminio --verbose
   ```

The `X-Minio-Healing-Drives` HTTP response header will be non-zero when healing is active, visible in response headers from any S3 API call.

---

## Healing

### Automatic Healing

MinIO heals objects automatically in the following scenarios:
- A drive fails and is replaced.
- A node rejoins the cluster after downtime.
- Bitrot (checksum mismatch) is detected during a read or background scan.

Healing is prioritized by urgency: objects with the fewest surviving shards (closest to data loss) are healed first.

### Manual Healing

```bash
# Start a healing scan on the entire cluster
mc admin heal myminio --recursive

# Heal a specific bucket
mc admin heal myminio/mybucket --recursive

# Heal a specific object
mc admin heal myminio/mybucket/path/to/object

# Dry-run mode (show what would be healed without making changes)
mc admin heal myminio --dry-run --recursive

# Verbose output showing per-object status
mc admin heal myminio --verbose --recursive
```

Important notes on healing:
- `mc admin heal` is resource intensive. Run during off-peak hours for large clusters.
- Manual healing is typically not required — the background data scanner handles routine healing automatically.
- Use manual healing after significant incidents (multi-drive failure, prolonged node downtime) to accelerate recovery.

### Healing Status Output

```bash
mc admin heal myminio
```

Output fields:
- `objectsHealed`: Objects successfully repaired.
- `objectsFailed`: Objects that could not be healed (below read quorum — data loss).
- `healthBeforeHeal`: Distribution of shard health before scan.
- `healthAfterHeal`: Distribution after healing completed.

If `objectsFailed > 0`, those objects have lost too many shards to reconstruct and represent permanent data loss. Document affected objects for incident reporting.

---

## Performance Benchmarking

### Built-in Performance Test (mc support perf)

```bash
# Run comprehensive performance test
mc support perf myminio

# Save results to file
mc support perf myminio --json > perf-results.json
```

This tests:
- S3 API GET/PUT throughput (end-to-end with erasure coding).
- Network bandwidth between cluster nodes.
- Raw drive read/write speeds (bypassing MinIO).

### Warp — S3 Benchmarking Tool

Warp (`github.com/minio/warp`) is MinIO's dedicated S3 benchmark tool for more detailed workload simulation:

```bash
# Install warp
go install github.com/minio/warp@latest

# GET benchmark (100 objects, 10 concurrent workers)
warp get --host minio.example.com:9000 \
  --access-key ACCESS_KEY \
  --secret-key SECRET_KEY \
  --tls --bucket warp-benchmark \
  --objects 100 --concurrent 10

# PUT benchmark
warp put --host minio.example.com:9000 \
  --access-key ACCESS_KEY \
  --secret-key SECRET_KEY \
  --tls --bucket warp-benchmark \
  --obj.size 64MiB --concurrent 16

# Mixed workload (70% GET, 20% PUT, 10% DELETE)
warp mixed --host minio.example.com:9000 \
  --access-key ACCESS_KEY \
  --secret-key SECRET_KEY \
  --tls --bucket warp-benchmark \
  --get-distrib 70 --put-distrib 20 --delete-distrib 10 \
  --concurrent 20 --duration 5m

# Analyze results from a previous run
warp analyze warp-output.csv.zst
```

Warp output provides:
- Throughput (MB/s) percentiles (p50, p95, p99).
- Operations per second.
- Time-to-first-byte (TTFB) latency distribution.
- Error rates.

### Establishing Baselines

Run benchmarks immediately after deployment and store results. Compare against baselines when investigating performance regressions:

```bash
# Baseline PUT benchmark
warp put --host minio.example.com:9000 \
  --access-key $AK --secret-key $SK --tls \
  --bucket perf-baseline --obj.size 128MiB \
  --concurrent 16 --duration 2m 2>&1 | tee baseline-put-$(date +%Y%m%d).txt
```

---

## Network Diagnostics

### Inter-Node Connectivity

```bash
# Test network performance between nodes (runs from mc client)
mc support perf myminio --net

# Manually test bandwidth between nodes (run on each node)
iperf3 -s  # on target node
iperf3 -c <target-node-ip> -t 30 -P 4  # on source node
```

Expected: 100 GbE should yield ~11-12 GB/s with 4 parallel streams.

### DNS Resolution

```bash
# Verify all node hostnames resolve correctly
for node in minio-0 minio-1 minio-2 minio-3; do
  echo "$node: $(dig +short $node.minio-headless.minio-tenant.svc.cluster.local)"
done
```

DNS misconfigurations (nodes resolving to wrong IPs) cause distributed mode startup failures and intermittent healing failures.

### TLS Certificate Verification

```bash
# Verify certificate validity and SANs
openssl s_client -connect minio.example.com:9000 \
  -servername minio.example.com </dev/null 2>/dev/null \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative"

# Check certificate expiry
mc admin info myminio --json | jq '.info.servers[].network'
```

---

## Logging and Monitoring

### Server Logs

```bash
# Stream live server logs
mc admin logs myminio

# Filter logs by component
mc admin logs myminio --type=all
mc admin logs myminio --type=minio

# View last N lines
mc admin logs myminio --last 100
```

### Prometheus Metrics

MinIO exposes Prometheus metrics at `/minio/v2/metrics/cluster` (requires authentication):

```bash
# Generate a Prometheus bearer token
mc admin prometheus generate myminio

# Test metrics endpoint
curl -H "Authorization: Bearer <token>" \
  https://minio.example.com/minio/v2/metrics/cluster
```

Key metrics to alert on:

| Metric                                | Alert Threshold       | Meaning                          |
|---------------------------------------|-----------------------|----------------------------------|
| `minio_node_drive_offline_total`      | > 0                   | One or more drives offline       |
| `minio_node_drive_healing_total`      | > 0 sustained         | Healing in progress              |
| `minio_cluster_capacity_usable_free_bytes` | < 20% of total   | Nearing storage capacity         |
| `minio_s3_requests_errors_total`      | Sudden spike          | API error rate increase          |
| `minio_node_scanner_objects_scanned`  | Stalled              | Data scanner stuck               |
| `minio_cluster_health_erasure_set_online_drives_count` | Below write quorum | Write unavailability risk |

### Grafana Dashboard

MinIO provides official Grafana dashboard IDs:
- Cluster metrics: Dashboard ID 13502
- Replication metrics: Dashboard ID 15305

Import via Grafana UI: Dashboards → Import → Enter ID.

---

## Common Issues and Resolution

### Issue: Drive Shows as Offline After Restart

**Symptoms**: `mc admin info` shows one or more drives as offline after a node restart.

**Investigation**:
```bash
# Check if the drive is mounted
ssh minio-node1 "df -h /mnt/disk1 /mnt/disk2 /mnt/disk3 /mnt/disk4"

# Check filesystem for errors
ssh minio-node1 "dmesg | grep -i xfs | tail -20"

# Check MinIO logs for drive errors
mc admin logs myminio | grep -i "drive\|disk\|EIO"
```

**Resolution**: Verify mount points are in `/etc/fstab` and mounted. If filesystem corruption, run `xfs_repair` on the unmounted filesystem.

### Issue: Write Quorum Lost

**Symptoms**: S3 PUT requests return `XMinioStorageWriteQuorum` errors.

**Investigation**:
```bash
mc admin info myminio --json | jq '.info.servers[].drives[] | {state, endpoint}'
```

**Resolution**: Identify how many drives are offline. If above the parity threshold (N/2), the cluster needs drives brought back online before writes resume. Do not add a new pool while below write quorum — resolve the drive issue first.

### Issue: Slow Healing / Healing Storm

**Symptoms**: Healing progress is extremely slow or CPU/IO is saturated by healing.

**Investigation**:
```bash
mc admin heal myminio --verbose 2>&1 | grep "healthBeforeHeal"
mc support perf myminio --storage  # check if raw drive speed is OK
```

**Resolution**:
```bash
# Throttle healing I/O (reduce worker concurrency via config)
mc admin config set myminio heal max_sleep=2s

# Restart to apply
mc admin service restart myminio
```

### Issue: Replication Lag

**Symptoms**: Objects written to site 1 do not appear on site 2 within expected time.

**Investigation**:
```bash
# Check replication status and lag metrics
mc admin replicate status myminio

# View replication-specific metrics
curl -H "Authorization: Bearer <token>" \
  https://minio.example.com/minio/v2/metrics/cluster \
  | grep replication
```

**Resolution**:
- Check network bandwidth between sites (`iperf3`).
- Verify credentials on both sites are valid.
- Check for clock skew between sites (NTP must be synchronized).
- Increase replication workers if bandwidth allows.

### Issue: Object Not Found After Write (Eventual Consistency Concern)

**Symptoms**: An object is written successfully (200 OK) but a subsequent GET returns 404.

**Note**: MinIO provides **strong read-after-write consistency** when using the recommended XFS filesystem. If you see this behavior:

**Investigation**:
```bash
# Verify filesystem is XFS, not ext4
ssh minio-node1 "df -T /mnt/disk1"

# Check for any split-brain or lock contention
mc admin logs myminio | grep "lock\|quorum"
```

**Resolution**: If ext4 is in use, migrating to XFS is the fix. ext4 does not honor POSIX semantics that MinIO relies on for consistency guarantees.
