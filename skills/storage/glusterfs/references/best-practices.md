# GlusterFS Best Practices

## Volume Design

- Always use replica 3 or arbiter 2+1 (not replica 2) for automatic split-brain resolution
- Minimum 3 nodes for replicated volumes; each replica on a separate server
- For distributed-replicated, bricks grouped sequentially into replica sets (order matters)
- Prefer dispersed 4+2 or 8+2 for archival/large-file workloads (avoid for small files)

## Brick Layout

### Filesystem Preparation

```bash
mkfs.xfs -i size=512 -f /dev/sdb1
mkdir -p /data/glusterfs/myvol/brick1
mount /dev/sdb1 /data/glusterfs/myvol/brick1
# /etc/fstab:
/dev/sdb1  /data/glusterfs/myvol/brick1  xfs  defaults,inode64,noatime,nodiratime  0 0
mkdir -p /data/glusterfs/myvol/brick1/data  # actual export subdirectory
```

### RAID Recommendations

RAID 10 for latency-sensitive small files. RAID 6 for capacity-sensitive sequential. JBOD with 3-way replication for maximum bandwidth. Never use RAID 5.

### Layout Rules

- One brick per physical disk (not multiple bricks on same disk)
- Separate brick and OS disks
- Dedicated storage networks (10 GbE minimum, jumbo frames MTU 9000)
- For RDMA: `transport rdma`

## Performance Tuning

### Cache and Buffering

```bash
gluster volume set myvol performance.cache-size 1GB
gluster volume set myvol performance.write-behind-window-size 64MB
gluster volume set myvol performance.readdir-ahead on
```

### IO Threading

```bash
gluster volume set myvol performance.io-thread-count 32
gluster volume set myvol client.event-threads 4
gluster volume set myvol server.event-threads 4
```

### Metadata Caching

```bash
gluster volume set myvol features.cache-invalidation on
gluster volume set myvol performance.stat-prefetch on
gluster volume set myvol performance.md-cache-timeout 600
```

### Small-File Workloads

Enable quick-read and open-behind. Use md-cache with longer timeouts. Avoid dispersed volumes. Use replicated or distributed-replicated.

### Large Sequential Files

Increase write-behind window to 256MB. Enable flush-behind. Disable read-ahead if write-only.

### Kernel Tuning

Increase socket buffers (`net.core.rmem_max = 134217728`). Increase file descriptor limits to 65536. Use mq-deadline/noop scheduler for SSDs.

## Monitoring

### Prometheus + Grafana

Use `gluster-prometheus` exporter. Key metrics: `gluster_brick_capacity_used_bytes`, `gluster_heal_info_files_count`, `gluster_brick_up`, `gluster_peers_connected`, `gluster_volume_up`.

Grafana dashboard IDs: 8376, 10704.

### Built-in Diagnostics

```bash
gluster volume status myvol detail
gluster volume profile myvol start/info/stop
gluster volume top myvol read-perf/write-perf/open
```

### Alert On

- `gluster_brick_up == 0`
- `gluster_heal_info_files_count > 0` sustained > 30 minutes
- Brick filesystem > 80% utilization
- `gluster_volume_up == 0`

## Geo-Replication Setup

Prerequisites: same GlusterFS major version, slave not a peer of master, passwordless SSH, slave volume exists, changelog enabled.

```bash
gluster volume geo-replication master-vol slave-server1::slave-vol create push-pem
gluster volume geo-replication master-vol slave-server1::slave-vol start
gluster volume geo-replication master-vol slave::slave-vol config sync-jobs 8
gluster volume geo-replication master-vol slave::slave-vol config checkpoint now
```

Best practices: dedicated network interface, use checkpoints before maintenance, monitor `Files Remaining`.

## Kubernetes Integration

### Kadalu Operator (Recommended)

```bash
kubectl create namespace kadalu
kubectl apply -f https://github.com/kadalu/kadalu/releases/latest/download/operator.yaml
```

Supports internal (operator-managed) and external (pre-existing) GlusterFS clusters. CSI driver with dynamic PV provisioning. PV resize support.

### External GlusterFS

Define endpoints and static PVs. GlusterFS `ReadWriteMany` (RWX) access mode well-suited for shared storage.

### Considerations

- Prefer external GlusterFS clusters for production
- Do not run brick pods on storage-intensive app nodes
- The original gluster-kubernetes/Heketi was deprecated (removed in K8s 1.25)
