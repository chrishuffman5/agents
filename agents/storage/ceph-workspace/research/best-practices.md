# Ceph Best Practices

## Cluster Sizing

### Minimum viable cluster

| Role | Minimum | Production recommended |
|------|---------|----------------------|
| Monitors | 3 | 3 (small), 5 (large) |
| Managers | 1 active + 1 standby | 2 (active/standby) |
| OSDs | 3 | ≥ 10 per failure domain |
| MDS (CephFS) | 1 active + 1 standby | Active = desired throughput ranks |
| RGW | 1 | 2+ per zone for HA |

### Replication factor and usable capacity

- **3x replication** (default): raw capacity × 0.33 = usable
- **Erasure 4+2**: raw capacity × 0.67 = usable (2.3% CPU overhead)
- **Erasure 8+3**: raw capacity × 0.73 = usable (higher CPU, better space efficiency)

Never allow any OSD or pool to exceed 80% full. Performance degrades significantly between 75–85% and the cluster risks entering a full or near-full state that blocks all writes.

Recommended thresholds:
```
mon_osd_nearfull_ratio = 0.75   # HEALTH_WARN issued
mon_osd_full_ratio = 0.85       # HEALTH_ERR, writes blocked
mon_osd_backfillfull_ratio = 0.80
```

### Hardware recommendations

**OSD nodes:**
- Minimum 4 OSDs per node; 8–24 OSDs per node is typical
- CPU: 1 core per 2 HDD OSDs; 2 cores per SSD OSD; 4 cores per NVMe OSD
- RAM: 4 GB per OSD (default `osd_memory_target`) + 16 GB OS overhead per node
  - Formula: `(num_osds × 4GB) + 16GB` minimum per node
  - NVMe: 8–16 GB per OSD for best cache hit rates
- Networking: 10 GbE minimum; 25 GbE or 100 GbE for NVMe-based clusters
  - Use separate public (client-facing) and cluster (replication) networks

**Monitor nodes:**
- Dedicated SSD for monitor data directory (monitor RocksDB is I/O sensitive)
- 4 CPU cores, 4 GB RAM minimum
- Low-latency network to peer monitors

**MDS nodes (CephFS):**
- High-RAM machines; 8–64 GB depending on filesystem size
- Fast CPU (single-threaded metadata operations are latency-sensitive)
- Metadata pool on SSDs or NVMe

---

## CRUSH Map Design

### Design principles

1. **Model your actual physical topology.** Match the CRUSH hierarchy to your real failure domains: datacenter, room, row, rack, chassis, host, osd. A rack-level failure domain ensures each replica lands on a different rack.

2. **Start simple, add depth as needed.** A small cluster needs only `root → host → osd`. Add rack-level buckets when you have ≥ 3 racks with ≥ 3 nodes each.

3. **Choose the right failure domain for your replication factor.** A 3-replica pool requires at least 3 usable buckets at the failure domain level. A rack-failure-domain pool needs at least 3 distinct racks.

4. **Use straw2 algorithm.** It is the default and provides proportional weight-based distribution with minimal rebalancing when devices are added or removed.

5. **Set OSD weights proportionally to device size.** Convention: 1.0 = 1 TB.
   ```
   # 4TB HDD:  weight 4.0
   # 2TB SSD:  weight 2.0
   # 1.6TB NVMe: weight 1.6
   ```

### Editing the CRUSH map

```bash
# Export current CRUSH map
ceph osd getcrushmap -o /tmp/crushmap.bin
crushtool -d /tmp/crushmap.bin -o /tmp/crushmap.txt

# Edit /tmp/crushmap.txt

# Compile and import
crushtool -c /tmp/crushmap.txt -o /tmp/crushmap-new.bin
ceph osd setcrushmap -i /tmp/crushmap-new.bin
```

With Cephadm and the MGR `crush` module, many operations can be done without manual map editing:
```bash
ceph osd crush add-bucket rack1 rack
ceph osd crush move rack1 root=default
ceph osd crush move node1 rack=rack1
```

### Crush rule for rack-level failure domain

```
rule replicated_rack {
    id 1
    type replicated
    min_size 1
    max_size 10
    step take default
    step chooseleaf firstn 0 type rack
    step emit
}
```

Apply to a pool:
```bash
ceph osd pool set <pool> crush_rule replicated_rack
```

### Stretch cluster (two-site)

Ceph Squid and Tentacle support stretch cluster mode for 2-site + tiebreaker monitor configurations. Data is written to both sites before acknowledging; tolerable site failure without data loss.

```bash
ceph mon set election_strategy connectivity
ceph mon set_location <mon_name> datacenter=dc1
ceph osd set-allow-crimson yes  # if using Crimson
ceph osd set-require-min-compat-client squid
ceph mon enable_stretch_mode <tiebreaker_mon> <crush_rule> datacenter
```

---

## Pool Configuration

### Replicated pools

```bash
# Create a replicated pool with autoscaling
ceph osd pool create <pool_name> --pg-num-min 1
ceph osd pool set <pool_name> size 3                    # total copies
ceph osd pool set <pool_name> min_size 2                # minimum for I/O
ceph osd pool set <pool_name> crush_rule <rule>
ceph osd pool application enable <pool_name> <app>      # rbd, cephfs, rgw
```

### Erasure-coded pools

```bash
# Create EC profile
ceph osd erasure-code-profile set ec-4-2 \
    k=4 m=2 plugin=isa crush-failure-domain=host

# Create pool with EC profile
ceph osd pool create <ec_pool> erasure ec-4-2

# EC pools for RGW data (pair with replicated index pool)
ceph osd pool create .rgw.buckets.data erasure ec-4-2
ceph osd pool set .rgw.buckets.data allow_ec_overwrites true
```

### Pool quotas

```bash
ceph osd pool set-quota <pool> max_bytes $((100 * 1024**3))   # 100 GB
ceph osd pool set-quota <pool> max_objects 1000000
```

### Pool compression

```bash
ceph osd pool set <pool> compression_mode aggressive
ceph osd pool set <pool> compression_algorithm zstd
ceph osd pool set <pool> compression_min_blob_size 131072     # 128 KB
ceph osd pool set <pool> compression_max_blob_size 524288     # 512 KB
ceph osd pool set <pool> compression_required_ratio 0.875
```

Use compression for cold data, archival, or object storage. Avoid for latency-sensitive block storage workloads unless throughput savings are needed.

---

## PG Tuning

### PG autoscaler (recommended for most deployments)

The PG autoscaler (enabled by default in Nautilus+) calculates optimal `pg_num` per pool based on the pool's proportion of total cluster data.

```bash
# Verify autoscaler is enabled
ceph mgr module enable pg_autoscaler

# Set autoscale mode per pool
ceph osd pool set <pool> pg_autoscale_mode on     # automatic adjustment
ceph osd pool set <pool> pg_autoscale_mode warn   # suggest but don't change
ceph osd pool set <pool> pg_autoscale_mode off    # manual control

# Set a target size hint for a pool
ceph osd pool set <pool> target_size_bytes $((10 * 1024**4))  # 10 TB expected
```

### Manual PG calculation

When not using the autoscaler, calculate PGs manually:

```
Target PGs per OSD = 100 (HDD) to 200 (SSD/NVMe)
PG count = (num_OSDs × target_PGs_per_OSD) / replication_factor

Round up to next power of 2.
```

Example: 30 OSDs, 3-replica, 100 PG/OSD target:
```
(30 × 100) / 3 = 1000 → round to 1024
```

For multiple pools, divide proportionally by expected data share:
```
Pool A (60% of data): 1024 × 0.6 = ~640
Pool B (40% of data): 1024 × 0.4 = ~410
```

### Target PG per OSD tuning

```bash
ceph config set global mon_target_pg_per_osd 100    # default
# For BlueStore with SSDs/NVMe, Red Hat recommends 200-250:
ceph config set global mon_target_pg_per_osd 200
ceph config set global mon_max_pg_per_osd 500
```

### Changing PG count (live)

```bash
ceph osd pool set <pool> pg_num <new_count>
# Wait for cluster to rebalance, then:
ceph osd pool set <pool> pgp_num <new_count>
```

PG splits can cause temporary I/O latency. Increase gradually (double at a time).

---

## BlueStore Optimization

### DB and WAL device separation (most impactful optimization)

Place RocksDB on a faster device than the data device. Required layout: one NVMe partition shared across multiple HDDs, partitioned as:

```bash
# Partition a 1TB NVMe for 8 HDD OSDs:
# 8× 2GB WAL partitions = 16 GB
# 8× 40GB DB partitions = 320 GB
# Remaining for data OSD or OS

# Create OSD with separated DB and WAL
ceph-volume lvm create \
    --data /dev/sda \
    --block-db /dev/nvme0n1p1 \
    --block-wal /dev/nvme0n1p2
```

Sizing:
- WAL: 1–2 GB per OSD (larger is not more beneficial once it fits the write burst)
- DB: 1–4% of data device size for general workloads
- DB: ≥ 4% of data device for RGW (omap-heavy workload)

### Cache size tuning

```bash
# HDD-backed OSDs (default 1 GB)
ceph config set osd bluestore_cache_size_hdd 1073741824     # 1 GB

# SSD-backed OSDs (default 3 GB)
ceph config set osd bluestore_cache_size_ssd 4294967296     # 4 GB

# NVMe-backed (high-memory nodes)
ceph config set osd bluestore_cache_size_ssd 8589934592     # 8 GB

# Enable autotuning (recommended)
ceph config set osd bluestore_cache_autotune true
```

Cache ratio profiles:

| Workload | kv_ratio | meta_ratio | data_ratio |
|----------|----------|------------|------------|
| Metadata-heavy (CephFS, RGW) | 0.40 | 0.40 | 0.20 |
| Data-heavy (RBD, large objects) | 0.20 | 0.30 | 0.50 |
| Balanced | 0.40 | 0.40 | 0.20 |

```bash
ceph config set osd bluestore_cache_kv_ratio 0.40
ceph config set osd bluestore_cache_meta_ratio 0.40
```

### OSD memory target

```bash
# Set per OSD (4 GB default minimum)
ceph config set osd osd_memory_target 4294967296   # 4 GB
# For NVMe OSDs with many PGs:
ceph config set osd osd_memory_target 8589934592   # 8 GB
```

### I/O scheduler

```bash
# For SSDs and NVMe — use noop or none
echo noop > /sys/block/nvme0n1/queue/scheduler

# For HDDs — use deadline (mq-deadline)
echo mq-deadline > /sys/block/sda/queue/scheduler
```

### NVMe multi-queue threading

```bash
ceph config set osd osd_op_num_shards_ssd 8       # baseline; scale with CPU cores
ceph config set osd osd_recovery_max_active_ssd 10
```

---

## RBD for Kubernetes via Rook

### Rook operator architecture

Rook is a Kubernetes operator that manages Ceph lifecycle inside Kubernetes. It:
- Deploys Ceph daemons as pods with appropriate node affinity and tolerations
- Creates and manages CephBlockPool, CephFilesystem, and CephObjectStore CRDs
- Provisions PersistentVolumes via the Ceph CSI driver

### Node labeling and placement

```yaml
# Label storage nodes
kubectl label node storage-node-1 ceph-osd=true
kubectl label node storage-node-1 topology.rook.io/rack=rack1

# Cluster CR storage section
spec:
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
      - name: "storage-node-1"
        devices:
          - name: "sda"
          - name: "nvme0n1"
        config:
          osdsPerDevice: "1"
```

### Resource limits

```yaml
# Monitor resource requirements
resources:
  mon:
    requests:
      cpu: "2"
      memory: "2Gi"
    limits:
      cpu: "4"
      memory: "4Gi"
  osd:
    requests:
      cpu: "1"
      memory: "4Gi"
    limits:
      cpu: "4"
      memory: "8Gi"
```

### CephBlockPool for RBD

```yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  failureDomain: host
  replicated:
    size: 3
    requireSafeReplicaSize: true
  parameters:
    compression_mode: none
```

### StorageClass

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering,exclusive-lock,object-map,fast-diff,deep-flatten
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
reclaimPolicy: Delete
allowVolumeExpansion: true
```

### Key Rook operational settings

- Use the Ceph CSI driver (not FlexVolume, which is deprecated)
- Enable `removeOSDsIfOutAndSafeToRemove: true` for automated OSD cleanup
- Enable the `pg_autoscaler` MGR module
- Use host networking for production latency-sensitive workloads (exits Kubernetes network policy boundary — evaluate security implications)
- Reserve OSD nodes exclusively for storage (use taints/tolerations)
- Keep 10–15% free space headroom; Ceph slows significantly above 80% full

### Network configuration

```yaml
spec:
  network:
    provider: host         # host networking for lowest latency
    # Or use Multus for dedicated storage network:
    provider: multus
    selectors:
      public: rook-public
      cluster: rook-cluster
```

---

## CephFS Best Practices

### MDS configuration

```bash
# Set standby MDS count (always keep at least 1 standby per active rank)
ceph fs set <fsname> standby_count_wanted 1

# Standby-replay (faster failover; uses more resources)
ceph fs set <fsname> allow_standby_replay true

# Set max active MDS ranks (scale for metadata throughput)
ceph fs set <fsname> max_mds 2   # confirm with --yes-i-really-mean-it if unhealthy

# Pin directories to specific MDS ranks (manual subtree pinning)
setfattr -n ceph.dir.pin -v 1 /mnt/cephfs/hot-directory
```

### Pool layout

- Always place the metadata pool on SSDs or NVMe — MDS journal I/O is latency-sensitive
- The data pool can be on HDD for general workloads; use separate SSD pool for hot data via storage policies

```bash
# Create filesystem with separate fast metadata pool
ceph osd pool create cephfs_metadata 32
ceph osd pool create cephfs_data 128
ceph osd pool set cephfs_metadata crush_rule ssd_rule
ceph fs new cephfs cephfs_metadata cephfs_data
```

### Snapshots

Enable per-filesystem:
```bash
ceph fs set <fsname> allow_new_snaps true
```

Create snapshot by creating a directory in the `.snap` virtual directory:
```bash
mkdir /mnt/cephfs/project/.snap/backup-2026-04-09
```

For application-consistent snapshots (Squid+):
```bash
# Pause I/O across the filesystem before snapping
ceph fs quiesce <fsname> --include-subvolume /volumes/subvol1
```

### Quotas

```bash
# Set a byte quota on a directory
setfattr -n ceph.quota.max_bytes -v 10737418240 /mnt/cephfs/project   # 10 GB

# Set an inode quota
setfattr -n ceph.quota.max_files -v 100000 /mnt/cephfs/project

# Check quota
getfattr -n ceph.quota.max_bytes /mnt/cephfs/project
```

Note: CephFS quotas are cooperative — kernel clients >= 4.17 enforce them. An adversarial or modified client can bypass quotas.

### Client capabilities

Grant minimal required permissions:
```bash
# Read-only client
ceph fs authorize <fsname> client.readonly / r

# Read-write to a specific path only
ceph fs authorize <fsname> client.appuser /project rw
```

---

## Monitoring with Prometheus

### Built-in Prometheus endpoint

The Ceph MGR exposes Prometheus metrics natively on port 9283 of each MGR host. No external exporter needed for Ceph cluster metrics.

```bash
# Enable Prometheus module
ceph mgr module enable prometheus

# Verify endpoint
curl http://<mgr-host>:9283/metrics
```

### Prometheus scrape configuration

```yaml
scrape_configs:
  - job_name: 'ceph'
    static_configs:
      # Scrape all MGR daemons to avoid gaps during failover
      - targets:
          - 'mgr1:9283'
          - 'mgr2:9283'
    relabel_configs:
      - target_label: cluster
        replacement: prod-ceph

  - job_name: 'node'
    static_configs:
      - targets:
          - 'osd-node1:9100'
          - 'osd-node2:9100'
```

### Cephadm-managed monitoring stack

With Cephadm (Tentacle 20.2):
```bash
# Deploy the full monitoring stack
ceph orch apply prometheus
ceph orch apply grafana
ceph orch apply alertmanager
ceph orch apply node-exporter

# Deploy the new mgmt-gateway (Tentacle 20.2+)
ceph orch apply mgmt-gateway
```

The `mgmt-gateway` service provides a single TLS-terminated HTTPS entry point for all management endpoints.

### Key metrics to alert on

| Metric | Alert threshold | Meaning |
|--------|----------------|---------|
| `ceph_health_status` | != 0 | Cluster not HEALTH_OK |
| `ceph_osd_in` - `ceph_osd_up` | > 0 | OSDs down but still "in" |
| `ceph_pg_degraded` | > 0 | PGs with missing replicas |
| `ceph_pg_undersized` | > 0 | Fewer replicas than required |
| `ceph_pg_inactive` | > 0 | I/O blocked (critical) |
| `ceph_osd_apply_latency_ms` | > 50ms (HDD), > 5ms (SSD) | Slow OSD writes |
| `ceph_pool_percent_used` | > 75% | Nearfull threshold |
| `ceph_mon_quorum_status` | < 1 | Monitor quorum lost |
| `ceph_osd_slow_ops` | > 0 | Slow OSD requests |

### Grafana dashboards

Import pre-built dashboards from SUSE's `grafana-dashboards-ceph` repository or Grafana Labs dashboard IDs:
- **5086**: Ceph Cluster (official Ceph Prometheus plugin)
- **7056**: Ceph Cluster (community)
- **7050**: Ceph Clusters Overview

Cephadm automatically configures Grafana with the relevant dashboards when deployed via `ceph orch apply grafana`.

### Retention and storage

```bash
# Configure Prometheus retention (Cephadm)
ceph orch apply prometheus --retention-time 90d --retention-size 50GB
```

Default retention is 15 days. For long-term trending, use remote write to Thanos or Cortex.
