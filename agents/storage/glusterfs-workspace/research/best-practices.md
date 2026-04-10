# GlusterFS Best Practices

## Volume Design

### Choosing the Right Volume Type

| Requirement | Recommended Volume Type |
|---|---|
| Maximum capacity, no HA | Distributed |
| High availability, lower scale | Replicated (3-way) |
| HA + horizontal scale | Distributed Replicated (replica 3) |
| Storage efficiency + fault tolerance | Dispersed (4+2 or 8+2) |
| HA + efficiency + scale | Distributed Dispersed |
| 3-node HA with 2× overhead | Arbiter (2+1) |

### Replica Count Rules

- **Always use replica 3 (or 2+1 arbiter) instead of replica 2.** Replica 2 cannot automatically resolve split-brain when both bricks are up but diverge; the client must break the tie. Replica 3 allows automatic quorum-based resolution.
- **Minimum 3 nodes for any replicated volume.** Place each replica on a separate physical server to ensure a single hardware failure does not take down more than one replica.
- **Avoid even-count replicas** unless you understand quorum behavior. With replica 2, there is no quorum majority possible when one brick is down.

### Distributed Replicated Layout

For a `replica 3` distributed-replicated volume, GlusterFS groups bricks in the order listed:
```
# Correct: bricks 1-3 form replica set 1, bricks 4-6 form replica set 2
gluster volume create dr-vol replica 3 transport tcp \
  server1:/brick1/data server2:/brick1/data server3:/brick1/data \
  server4:/brick2/data server5:/brick2/data server6:/brick2/data
```

Rule: Each replica set must span different physical servers. Never place two bricks of the same replica set on the same server.

### Dispersed Volume Sizing

Common configurations and their fault tolerance:

| Config (data+redundancy) | Total Bricks | Failures Tolerated | Storage Efficiency |
|---|---|---|---|
| 2+1 | 3 | 1 | 67% |
| 4+2 | 6 | 2 | 67% |
| 8+2 | 10 | 2 | 80% |
| 8+3 | 11 | 3 | 73% |
| 4+1 | 5 | 1 | 80% |

- Prefer configurations where redundancy >= 2 for production (single redundancy brick failure leaves zero margin).
- Use 8+2 or larger for archival/object-style workloads where write latency is acceptable.
- Dispersed volumes have high write amplification for small files; avoid for small-file-heavy workloads.

---

## Brick Layout

### Filesystem Preparation

XFS is the recommended brick filesystem. Always format with 512-byte inode size to accommodate GlusterFS extended attributes:

```bash
# Format brick device
mkfs.xfs -i size=512 -f /dev/sdb1

# Create mount point and brick subdirectory
mkdir -p /data/glusterfs/myvol/brick1
mount /dev/sdb1 /data/glusterfs/myvol/brick1

# /etc/fstab (recommended mount options)
/dev/sdb1  /data/glusterfs/myvol/brick1  xfs  defaults,inode64,noatime,nodiratime  0 0

# Create the actual brick export subdirectory
mkdir -p /data/glusterfs/myvol/brick1/data
```

Key mount options for bricks:
- `noatime` / `nodiratime` — Eliminates access-time writes for every read, significant for read-heavy workloads.
- `inode64` — Allows XFS to use 64-bit inode numbers, required on large filesystems.
- `allocsize=512m` — Increases allocation unit for large sequential writes (tune to workload).

### RAID Recommendations

| RAID Level | Use Case | Notes |
|---|---|---|
| RAID 10 | Latency-sensitive, small files | Best IOPS, 50% space efficiency |
| RAID 6 | Capacity-sensitive, sequential | ~40% more usable space than RAID 10 at similar capacity |
| JBOD | High-concurrency sequential reads with 3-way replication | Most efficient disk bandwidth utilization |

Do not use RAID 5 for brick backing storage. RAID 5 write penalty combined with GlusterFS replication overhead can severely impact write performance.

### Brick Count Per Node

- Use one brick per physical disk (or RAID set) — not multiple bricks on the same disk.
- For distributed-replicated volumes, limit to one brick per node per volume to ensure proper replica placement.
- Spread bricks across multiple nodes evenly to balance client connections.

### Separate Brick and OS Disks

Never place bricks on the OS disk. Use dedicated disks or RAID sets for brick storage. The OS disk should host `/var/lib/glusterd/` (cluster state) and logs only.

### Network Layout

- Use dedicated storage networks (separate from management/application networks) for GlusterFS inter-node traffic.
- 10GbE minimum for production; 25GbE or 100GbE for high-throughput workloads.
- Enable jumbo frames (MTU 9000) on storage network interfaces and switches for improved throughput.
- For RDMA-capable hardware: `gluster volume create ... transport rdma` for lower-latency intra-cluster communication.

---

## Performance Tuning

### Volume-Level Options

Set options with: `gluster volume set <volname> <option> <value>`

**Cache and buffering:**
```bash
# Increase read cache (default: 32MB)
gluster volume set myvol performance.cache-size 1GB

# Cache refresh timeout (default: 1s; increase for mostly-static data)
gluster volume set myvol performance.cache-refresh-timeout 600

# Write-behind window (default: 1MB; increase for throughput-oriented workloads)
gluster volume set myvol performance.write-behind-window-size 64MB

# Enable read-ahead (on by default)
gluster volume set myvol performance.read-ahead on

# Enable readdir-ahead for directory-heavy workloads
gluster volume set myvol performance.readdir-ahead on
```

**IO threading:**
```bash
# Server-side IO thread count (default: 16; tune to match concurrent connection count)
gluster volume set myvol performance.io-thread-count 32

# Client-side high priority threads
gluster volume set myvol client.event-threads 4

# Server-side event threads (matches CPU count is a good starting point)
gluster volume set myvol server.event-threads 4
```

**Metadata caching:**
```bash
# Enable metadata cache (reduces stat/xattr RPCs)
gluster volume set myvol features.cache-invalidation on
gluster volume set myvol performance.stat-prefetch on
gluster volume set myvol performance.md-cache-timeout 600
```

**Replication tuning:**
```bash
# Increase lookup parallelism (for rename-heavy workloads)
gluster volume set myvol cluster.lookup-unhashed on

# Eager locking for improved write throughput
gluster volume set myvol cluster.eager-lock enable
gluster volume set myvol cluster.quorum-reads off  # Only if read consistency can be relaxed
```

### Mount Options (Client Side)

```bash
# Disable direct-IO to allow kernel page cache (most workloads benefit)
mount -t glusterfs -o direct-io-mode=disable server1:myvol /mnt/gluster

# Reduce attribute cache pressure for mixed workloads
mount -t glusterfs -o attribute-timeout=120,entry-timeout=120 server1:myvol /mnt/gluster

# Reduce log noise in production
mount -t glusterfs -o log-level=WARNING server1:myvol /mnt/gluster
```

### Kernel and OS Tuning

```bash
# Increase kernel socket buffers for high-throughput GlusterFS traffic
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_wmem = 4096 65536 134217728" >> /etc/sysctl.conf
sysctl -p

# Increase file descriptor limits for glusterd/glusterfsd
# /etc/security/limits.conf
* soft nofile 65536
* hard nofile 65536

# Use deadline or noop IO scheduler for brick SSDs; mq-deadline or none for NVMe
echo "mq-deadline" > /sys/block/sdb/queue/scheduler
```

### Small-File Workload Tuning

Small files are the hardest workload for GlusterFS (and distributed filesystems generally). Mitigations:
- Enable `quick-read` and `open-behind` translators (enabled by default in recent versions).
- Use `md-cache` with longer timeouts.
- Consider creating a separate volume with `performance.quick-read` enabled and increasing `performance.cache-size`.
- Avoid dispersed volumes for small files; use replicated or distributed-replicated instead.

### Large Sequential File Tuning

```bash
# Increase write-behind window
gluster volume set myvol performance.write-behind-window-size 256MB

# Enable flush-behind (allow background flushes)
gluster volume set myvol performance.flush-behind on

# Larger stripe (for striped volumes, if applicable)
gluster volume set myvol cluster.stripe-block-size 4MB

# Disable unnecessary features
gluster volume set myvol performance.read-ahead off  # if truly sequential write-only
```

---

## Monitoring

### Prometheus + Grafana Stack

The recommended production monitoring stack uses `gluster-prometheus` (Prometheus exporter) with Grafana dashboards from `gluster-mixins`.

```bash
# Install gluster-prometheus exporter on all storage nodes
# https://github.com/gluster/gluster-prometheus

# Key metrics exposed:
# gluster_brick_capacity_used_bytes{host, volume, brick}
# gluster_heal_info_files_count{volume}
# gluster_brick_up{host, volume, brick}
# gluster_peers_connected
# gluster_volume_up{volume}
```

Grafana dashboard IDs (from Grafana Labs):
- Dashboard 8376: GlusterFS
- Dashboard 10704: GlusterFS Statistics (test cluster)

### Built-in Diagnostics Commands

```bash
# Cluster overview
gluster peer status
gluster pool list

# Volume overview
gluster volume info
gluster volume info myvol

# Volume operational status (process PIDs, ports, online state)
gluster volume status myvol
gluster volume status myvol detail      # includes IO stats

# Self-heal backlog
gluster volume heal myvol info summary

# Profile (live IO statistics per translator)
gluster volume profile myvol start
gluster volume profile myvol info       # read stats
gluster volume profile myvol stop

# Top files by read/write
gluster volume top myvol read-perf bs 256 count 10
gluster volume top myvol write-perf bs 256 count 10
gluster volume top myvol open count 10
```

### gstatus Tool

```bash
# Single-command cluster health summary
gstatus -v
```

### Alerting Recommendations

Alert on:
- `gluster_brick_up == 0` — Any brick offline
- `gluster_heal_info_files_count > 0` sustained for > 30 minutes — Active heal backlog not draining
- `gluster_peers_connected < expected_count` — Peer disconnection
- Brick filesystem utilization > 80% — Risk of brick becoming full (full bricks cause write errors)
- `gluster_volume_up == 0` — Volume completely down

---

## Geo-Replication Setup

### Prerequisites

1. Both master and slave GlusterFS clusters at the same major version.
2. The slave cluster must NOT be a peer of any master cluster node.
3. Passwordless SSH from one master node to all slave nodes (or at minimum the primary slave node).
4. The slave volume must exist before creating the geo-replication session.
5. The changelog translator must be enabled on the master volume (enabled by default).

### Setup Procedure

```bash
# Step 1: On master cluster, generate SSH keypair for geo-replication
gluster system:: execute gsec_create

# Step 2: Create geo-replication session with push-pem (distributes SSH keys automatically)
gluster volume geo-replication master-vol slave-server1::slave-vol create push-pem

# Step 3: On slave cluster, accept the configuration
gluster volume geo-replication slave-vol config allow-network <master-node-IPs>
gluster volume set slave-vol geo-replication.indexing enable

# Step 4: Start geo-replication
gluster volume geo-replication master-vol slave-server1::slave-vol start

# Monitor
gluster volume geo-replication master-vol slave-server1::slave-vol status
gluster volume geo-replication master-vol slave-server1::slave-vol status detail
```

### Configuration Options

```bash
# Adjust parallel sync workers (default: 4)
gluster volume geo-replication master-vol slave::slave-vol config sync-jobs 8

# Set log level
gluster volume geo-replication master-vol slave::slave-vol config log-level INFO

# Set changelog sync interval (seconds)
gluster volume geo-replication master-vol slave::slave-vol config changelog-batch-size 512

# Create checkpoint (verify data up to this point is replicated)
gluster volume geo-replication master-vol slave::slave-vol config checkpoint now
# Check status
gluster volume geo-replication master-vol slave::slave-vol status | grep Checkpoint
```

### Geo-Replication Best Practices

- Place geo-replication sessions on a dedicated network interface separate from client traffic.
- Use checkpointing before maintenance windows to verify replication completeness.
- For DR testing, pause (not stop) geo-replication to preserve session state: there is no explicit pause command; use `stop` and track changelog manually.
- Cascade carefully: master → slave1 → slave2. Each hop adds latency to the replication lag.
- Monitor `Files Remaining` in geo-rep status; a growing backlog indicates bandwidth or throughput constraint.

---

## Kubernetes Integration

### Recommended: Kadalu Operator

Kadalu is the actively maintained Kubernetes operator for GlusterFS-backed PersistentVolumes. It manages GlusterFS server pods internally and exposes storage via a CSI driver.

```bash
# Install Kadalu operator
kubectl create namespace kadalu
kubectl apply -f https://github.com/kadalu/kadalu/releases/latest/download/operator.yaml

# Configure storage (StorageClass backed by a raw device)
# kadalu-config.yaml
apiVersion: kadalu.io/v1alpha1
kind: KadaluStorage
metadata:
  name: replica3-storage
  namespace: kadalu
spec:
  type: Replica3
  storage:
    - node: worker1
      device: /dev/sdb
    - node: worker2
      device: /dev/sdb
    - node: worker3
      device: /dev/sdb

kubectl apply -f kadalu-config.yaml

# Use the storage class
# pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: kadalu.replica3-storage
```

### External GlusterFS with Kubernetes

For pre-existing GlusterFS clusters, define endpoints and static PVs:

```yaml
# gluster-endpoints.yaml
apiVersion: v1
kind: Endpoints
metadata:
  name: glusterfs-cluster
subsets:
  - addresses:
      - ip: 192.168.1.10
      - ip: 192.168.1.11
      - ip: 192.168.1.12
    ports:
      - port: 1

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: gluster-pv
spec:
  capacity:
    storage: 100Gi
  accessModes:
    - ReadWriteMany
  glusterfs:
    endpoints: glusterfs-cluster
    path: myvol
    readOnly: false
  persistentVolumeReclaimPolicy: Retain
```

### Kubernetes Considerations

- GlusterFS `ReadWriteMany` (RWX) access mode is well-suited for shared storage across multiple pods.
- Use NFS-Ganesha with a stable virtual IP for Kubernetes NFS PVs backed by GlusterFS when the in-tree `glusterfs` volume type is undesirable.
- Do not run GlusterFS brick pods on the same nodes as storage-intensive application pods to avoid IO contention.
- In K8s environments, prefer external GlusterFS clusters over Kadalu internal mode for production workloads requiring stable storage independent of cluster lifecycle.
