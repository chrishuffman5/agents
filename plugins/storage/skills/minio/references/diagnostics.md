# MinIO Diagnostics

## mc admin Commands

### Cluster Health

```bash
mc admin info myminio                    # Drive states, versions, capacity
mc admin info myminio --json             # JSON for parsing
mc admin ping myminio                    # Alive check
```

### Service Management

```bash
mc admin service restart myminio         # Rolling restart
mc admin service stop myminio            # Graceful shutdown
mc admin service freeze/unfreeze myminio # Pause/resume I/O
```

### Configuration

```bash
mc admin config get myminio              # All config
mc admin config get myminio api          # Specific subsystem
mc admin config set myminio api requests_max=1000
mc admin config export myminio > config.env
mc admin service restart myminio         # Required after config changes
```

## Health Check Endpoints

| Endpoint | 200 Means |
|----------|-----------|
| `/minio/health/live` | Server process alive |
| `/minio/health/ready` | Ready for traffic |
| `/minio/health/cluster` | Write quorum available |
| `/minio/health/cluster?maintenance=true` | Safe to take node offline |

## Drive Failure Diagnostics

### Identifying Failed Drives

```bash
mc admin info myminio
mc admin info myminio --json | jq '.info.servers[].drives[] | select(.state != "ok")'
```

States: `ok`, `offline`, `healing`, `unformatted`, `missing`.

### Drive Replacement

1. Identify failed drive via `mc admin info`
2. Hot-swap physical drive
3. Format with XFS: `mkfs.xfs -f /dev/sdX && mount /dev/sdX /mnt/diskN`
4. MinIO auto-detects and begins healing
5. Monitor: `mc admin heal myminio --verbose`

## Healing

### Automatic

Triggers on: drive replacement, node rejoin, bitrot detection. Prioritized by urgency (fewest surviving shards first).

### Manual

```bash
mc admin heal myminio --recursive             # Full cluster scan
mc admin heal myminio/mybucket --recursive    # Specific bucket
mc admin heal myminio --dry-run --recursive   # Preview only
```

If `objectsFailed > 0`, those objects have permanent data loss.

## Performance Diagnostics

### Built-in Tests

```bash
mc support perf myminio                  # All tests
mc support perf myminio --throughput     # S3 GET/PUT throughput
mc support perf myminio --net            # Internode bandwidth
mc support perf myminio --storage        # Raw drive speed
```

### Warp Benchmark

```bash
warp put --host minio:9000 --tls --bucket bench --obj.size 64MiB --concurrent 16
warp get --host minio:9000 --tls --bucket bench --objects 100 --concurrent 10
warp mixed --host minio:9000 --tls --bucket bench --duration 5m
warp analyze warp-output.csv.zst
```

## Prometheus Metrics

Endpoint: `/minio/v2/metrics/cluster` (requires auth token from `mc admin prometheus generate myminio`).

| Metric | Alert When |
|--------|-----------|
| `minio_node_drive_offline_total` | > 0 |
| `minio_cluster_capacity_usable_free_bytes` | < 20% of total |
| `minio_s3_requests_errors_total` | Sudden spike |
| `minio_cluster_health_erasure_set_online_drives_count` | Below write quorum |

Grafana dashboards: 13502 (cluster), 15305 (replication).

## Network Diagnostics

```bash
mc support perf myminio --net            # Internode bandwidth
iperf3 -s  # target node
iperf3 -c <target-ip> -t 30 -P 4        # source node (expect ~12 GB/s on 100 GbE)
```

TLS verification:
```bash
openssl s_client -connect minio:9000 -servername minio </dev/null | openssl x509 -noout -text
```

## Logging

```bash
mc admin logs myminio                    # Live stream
mc admin logs myminio --type=all         # All components
mc admin logs myminio --last 100         # Last N lines
```

## Common Issues

### Write Quorum Lost (`XMinioStorageWriteQuorum`)

Too many drives offline. Identify offline drives with `mc admin info --json`. Resolve drive issue before adding pools.

### Drive Offline After Restart

Check mount points: `df -h /mnt/disk*`. Check filesystem: `dmesg | grep xfs`. Verify `/etc/fstab`. Run `xfs_repair` if needed.

### Slow Healing

Throttle healing I/O: `mc admin config set myminio heal max_sleep=2s && mc admin service restart myminio`.

### Replication Lag

Check: `mc admin replicate status myminio`. Verify credentials, NTP sync, network bandwidth between sites.

### Object Not Found After Write (404)

MinIO provides strong read-after-write consistency on XFS. If using ext4, migrate to XFS (ext4 violates POSIX semantics MinIO depends on).
