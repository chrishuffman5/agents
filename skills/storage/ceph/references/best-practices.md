# Ceph Best Practices

## Cluster Sizing

### Minimum Viable Cluster

| Role | Minimum | Production |
|------|---------|------------|
| Monitors | 3 | 3 (small), 5 (large) |
| Managers | 1 active + 1 standby | 2 (active/standby) |
| OSDs | 3 | >= 10 per failure domain |
| MDS (CephFS) | 1 active + 1 standby | Active = desired throughput ranks |
| RGW | 1 | 2+ per zone for HA |

### Capacity Planning

- 3x replication: raw capacity x 0.33 = usable
- Erasure 4+2: raw capacity x 0.67 = usable
- Erasure 8+3: raw capacity x 0.73 = usable
- Never exceed 80% OSD utilization. Performance degrades 75-85%.

Thresholds:
```
mon_osd_nearfull_ratio = 0.75
mon_osd_full_ratio = 0.85
mon_osd_backfillfull_ratio = 0.80
```

### Hardware

**OSD nodes:** 1 core per 2 HDD OSDs, 2 cores per SSD, 4 cores per NVMe. RAM: `(num_osds x 4GB) + 16GB` minimum. 10 GbE minimum; 25-100 GbE for NVMe. Separate public and cluster networks.

**Monitor nodes:** Dedicated SSD for monitor data. 4 cores, 4 GB RAM minimum.

**MDS nodes:** High-RAM (8-64 GB). Fast CPU. Metadata pool on SSDs/NVMe.

## CRUSH Map Design

1. Model your actual physical topology (datacenter/rack/host/osd)
2. Start simple (root -> host -> osd), add rack depth when >= 3 racks with >= 3 nodes
3. Match failure domain to replication factor (3 replicas needs 3 buckets at failure domain level)
4. Use straw2 algorithm (default)
5. Set OSD weights proportional to device size (1.0 = 1 TB)

### Editing CRUSH

```bash
ceph osd getcrushmap -o /tmp/crushmap.bin
crushtool -d /tmp/crushmap.bin -o /tmp/crushmap.txt
# Edit, then compile and import:
crushtool -c /tmp/crushmap.txt -o /tmp/crushmap-new.bin
ceph osd setcrushmap -i /tmp/crushmap-new.bin
```

Or via CLI:
```bash
ceph osd crush add-bucket rack1 rack
ceph osd crush move rack1 root=default
ceph osd crush move node1 rack=rack1
```

### Stretch Cluster (Two-Site)

```bash
ceph mon set election_strategy connectivity
ceph mon set_location <mon_name> datacenter=dc1
ceph mon enable_stretch_mode <tiebreaker_mon> <crush_rule> datacenter
```

## Pool Configuration

### Replicated Pools

```bash
ceph osd pool create <pool> --pg-num-min 1
ceph osd pool set <pool> size 3
ceph osd pool set <pool> min_size 2
ceph osd pool set <pool> crush_rule <rule>
ceph osd pool application enable <pool> <app>
```

### Erasure-Coded Pools

```bash
ceph osd erasure-code-profile set ec-4-2 k=4 m=2 plugin=isa crush-failure-domain=host
ceph osd pool create <ec_pool> erasure ec-4-2
ceph osd pool set <ec_pool> allow_ec_overwrites true  # for RGW data
```

### Pool Compression

```bash
ceph osd pool set <pool> compression_mode aggressive
ceph osd pool set <pool> compression_algorithm zstd
```

Use for cold data, archival, object storage. Avoid for latency-sensitive block workloads.

## PG Tuning

### PG Autoscaler (Recommended)

```bash
ceph mgr module enable pg_autoscaler
ceph osd pool set <pool> pg_autoscale_mode on
ceph osd pool set <pool> target_size_bytes $((10 * 1024**4))  # 10 TB hint
```

### Manual Calculation

```
PG count = (num_OSDs x target_PGs_per_OSD) / replication_factor
Round to next power of 2. Target: 100 (HDD) to 200 (SSD/NVMe) PGs per OSD.
```

## BlueStore Optimization

### DB and WAL Separation (Most Impactful)

```bash
ceph-volume lvm create --data /dev/sda --block-db /dev/nvme0n1p1 --block-wal /dev/nvme0n1p2
```

Sizing: WAL 1-2 GB per OSD. DB 1-4% of data device (>= 4% for RGW omap-heavy).

### Cache Tuning

```bash
ceph config set osd bluestore_cache_size_hdd 1073741824   # 1 GB
ceph config set osd bluestore_cache_size_ssd 4294967296   # 4 GB
ceph config set osd bluestore_cache_autotune true
```

### OSD Memory and Threads

```bash
ceph config set osd osd_memory_target 4294967296           # 4 GB default
ceph config set osd osd_op_num_shards_ssd 8
```

### I/O Scheduler

SSDs/NVMe: noop or none. HDDs: mq-deadline.

## RBD for Kubernetes via Rook

### Key Practices

- Use Ceph CSI driver (not FlexVolume)
- Enable `pg_autoscaler` MGR module
- Use host networking for production latency-sensitive workloads
- Reserve OSD nodes exclusively for storage (taints/tolerations)
- Keep 10-15% free space headroom

### CephBlockPool

```yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
spec:
  failureDomain: host
  replicated:
    size: 3
    requireSafeReplicaSize: true
```

### Network Configuration

```yaml
spec:
  network:
    provider: host         # lowest latency
    # Or Multus for dedicated storage network:
    provider: multus
    selectors:
      public: rook-public
      cluster: rook-cluster
```

## CephFS Best Practices

### MDS Configuration

```bash
ceph fs set <fsname> standby_count_wanted 1
ceph fs set <fsname> allow_standby_replay true
ceph fs set <fsname> max_mds 2
```

Always place metadata pool on SSDs/NVMe. Pin hot directories to specific MDS ranks with `setfattr -n ceph.dir.pin`.

### Quotas

```bash
setfattr -n ceph.quota.max_bytes -v 10737418240 /mnt/cephfs/project  # 10 GB
setfattr -n ceph.quota.max_files -v 100000 /mnt/cephfs/project
```

Note: quotas are cooperative; kernel clients >= 4.17 enforce them.

### Client Capabilities

```bash
ceph fs authorize <fsname> client.readonly / r
ceph fs authorize <fsname> client.appuser /project rw
```

## Monitoring with Prometheus

### Built-in Endpoint

```bash
ceph mgr module enable prometheus
curl http://<mgr-host>:9283/metrics
```

### Key Alert Metrics

| Metric | Threshold | Meaning |
|--------|-----------|---------|
| `ceph_health_status` | != 0 | Not HEALTH_OK |
| `ceph_osd_in - ceph_osd_up` | > 0 | OSDs down but in |
| `ceph_pg_degraded` | > 0 | Missing replicas |
| `ceph_pg_inactive` | > 0 | I/O blocked (critical) |
| `ceph_osd_apply_latency_ms` | > 50ms HDD, > 5ms SSD | Slow writes |
| `ceph_pool_percent_used` | > 75% | Nearfull |
| `ceph_osd_slow_ops` | > 0 | Slow requests |

### Cephadm Monitoring Stack

```bash
ceph orch apply prometheus
ceph orch apply grafana
ceph orch apply alertmanager
ceph orch apply node-exporter
ceph orch apply mgmt-gateway  # Tentacle 20.2+
```
