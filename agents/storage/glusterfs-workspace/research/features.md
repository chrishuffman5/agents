# GlusterFS Features — Current State (11.x)

## Release Timeline

| Version | Release Date | Status |
|---|---|---|
| 11.0 | February 14, 2023 | Major release |
| 11.1 | 2023 (minor) | Bug fixes |
| 11.2 | July 2, 2024 | Latest stable |
| 10.3 | September 27, 2022 | Maintained (EOL TBD) |

Release policy: One major release per year; minor updates every two months for the most recent two major versions. At any time, two major versions are supported.

---

## GlusterFS 11.x Feature Set

### Performance Improvements

**rmdir performance (~36% improvement)**
GlusterFS 11.0 introduced significant speedup for directory removal operations, one of the historically expensive operations in distributed filesystems due to the need to remove entries across all bricks and clear GFID links. The improvement comes from optimized parallel execution across bricks.

**readdir / readdirp improvements**
Major cleanups to the directory listing code path. `readdirp` (readdir plus) operations that fetch stat alongside directory entries were optimized to reduce round trips, improving performance of tools like `ls -l`, `find`, and backup agents that enumerate directories.

**io-threads optimization**
Tuning and cleanup of the server-side IO thread pool to better handle concurrent requests without excessive context switching.

### Snapshot Support Expansion

**ZFS snapshot extension**
GlusterFS 11.0 extended snapshot support to include ZFS-backed bricks. Previously, the snapshot subsystem primarily targeted LVM thin provisioning. With ZFS support, operators can use ZFS datasets as brick backing stores and integrate GlusterFS volume snapshots with the ZFS snapshot mechanism.

Snapshot commands:
```bash
# Create a snapshot
gluster snapshot create snap1 myvol no-timestamp

# List snapshots
gluster snapshot list

# Activate a snapshot
gluster snapshot activate snap1

# Restore from snapshot
gluster snapshot restore snap1

# Clone a snapshot to a new volume
gluster snapshot clone newvol snap1

# Delete a snapshot
gluster snapshot delete snap1
```

Snapshot prerequisites for LVM bricks:
- Bricks on LVM thin provisioning (`lvcreate --thin`)
- `features.uss` (user-serviceable snapshots) enabled on the volume

### Quota System

**Namespace-based quota (GlusterFS 11)**
A new quota implementation based on the filesystem namespace was introduced to complement (and eventually replace) the older inode-based quota system. Namespace quota tracks usage at directory level without relying on XFS project quotas, enabling more flexible quota enforcement.

Commands:
```bash
# Enable quota on a volume
gluster volume quota myvol enable

# Set directory quota (hard limit)
gluster volume quota myvol limit-usage /projects/alpha 100GB

# Set quota with soft limit (warning threshold)
gluster volume quota myvol limit-usage /projects/beta 50GB 80%

# Check quota usage
gluster volume quota myvol list

# Disable quota
gluster volume quota myvol disable
```

### High Availability Features

**Arbiter volumes**
The 2+1 arbiter topology (2 full-data bricks + 1 metadata-only arbiter brick) provides split-brain prevention with ~2× storage overhead instead of 3×. The arbiter brick stores only filenames and extended attributes, not file data. Client quorum is automatically enforced: writes require 2 of 3 bricks to be online.

**Client-side quorum**
Configurable quorum enforcement prevents writes from succeeding when too few replicas are available, preventing split-brain conditions:
```bash
gluster volume set myvol cluster.quorum-type auto
gluster volume set myvol cluster.quorum-count 2
```

**Server-side quorum**
Prevents a partitioned node from continuing to serve IO when it cannot communicate with enough peers:
```bash
gluster volume set myvol cluster.server-quorum-type server
gluster volume set myvol cluster.server-quorum-ratio 51%
```

### Erasure Coding (Dispersed Volumes)

Dispersed volumes using Reed-Solomon erasure coding have been a stable feature since GlusterFS 3.6, continuously refined through the 11.x series. Key capabilities:
- Configurable data:redundancy ratios (e.g., 4+2, 8+2, 8+3)
- SIMD-accelerated encoding/decoding using XOR operations on 512-byte blocks
- Automatic repair of missing or corrupted fragments from surviving bricks
- Distributed dispersed volumes combining erasure coding with DHT-based distribution

### Geo-Replication

Asynchronous master-slave geo-replication using `gsync` daemons:
- Changelog-based change detection (efficient; only changed files are synced)
- SSH tunneling between sites with key-based authentication
- Per-session configuration (sync jobs, checkpoint, log level)
- Cascaded geo-replication (master → slave → slave-of-slave)
- Multiple slave sessions from a single master volume
- Bidirectional replication requires two separate sessions (one each direction)

### Access Protocol Support

**FUSE (native client)**
Primary access method. Runs entirely in userspace. Supports all volume types, all GlusterFS features. Recommended for Linux clients with direct control.

**NFS via NFS-Ganesha**
- NFSv3, NFSv4, NFSv4.1 support
- pNFS (parallel NFS) for direct-to-brick access
- HA NFS via Pacemaker virtual IPs
- `libgfapi` integration bypasses FUSE for lower latency

**SMB via Samba + vfs_glusterfs**
- Windows and CIFS client access
- `vfs_glusterfs` module for direct libgfapi access
- Ctdb for clustered lock management in HA Samba configurations
- ACL support

**libgfapi**
A C library allowing applications to access GlusterFS volumes directly without mounting. Used internally by NFS-Ganesha and Samba VFS modules. Also used by QEMU for VM image storage and by some backup tools.

### Observability and Monitoring

**gluster-prometheus exporter**
The `gluster/gluster-prometheus` project provides a Prometheus exporter exposing metrics for:
- Volume utilization (used/free/total per volume and per brick)
- Heal backlog count
- Brick online/offline status
- Peer connection state

**gluster-mixins**
`gluster/gluster-mixins` provides pre-built Grafana dashboards and Prometheus alerting rules for GlusterFS clusters. Updated as recently as January 2025.

**gstatus**
`gluster/gstatus` is a single-command cluster health overview tool that aggregates `gluster peer status`, `gluster volume status`, and heal information into a human-readable report.

**Built-in diagnostics**
```bash
gluster volume status myvol detail       # per-brick stats with IO counters
gluster volume profile myvol start       # enable per-translator profiling
gluster volume profile myvol info        # read profiling stats
gluster volume top myvol read-perf       # top files by read performance
```

### Container and Kubernetes Integration

**Kadalu (recommended path for K8s)**
The `kadalu/kadalu` project is the community-maintained Kubernetes operator for GlusterFS-backed persistent storage. It provides a CSI driver that accepts raw devices from Kubernetes nodes and provisions PersistentVolumes backed by GlusterFS volumes.

Key Kadalu capabilities:
- Operator-managed lifecycle for Gluster server pods
- Dynamic PV provisioning via CSI
- Support for internal (operator-managed) and external (pre-existing) GlusterFS clusters
- Disperse storage type support
- PV resize support
- StorageClass management

Note: The original `gluster-kubernetes` / Heketi integration was deprecated when GlusterFS was removed from Kubernetes in-tree in v1.25. Kadalu is the actively maintained successor.

**External GlusterFS with Kubernetes**
GlusterFS volumes can be used as Kubernetes PersistentVolumes via the `glusterfs` volume type (deprecated but functional) or more commonly via static PV definitions pointing to a GlusterFS endpoint.

---

## Project Status and Community Health (2025-2026)

### Red Hat Withdrawal

Red Hat commercially supported GlusterFS as "Red Hat Gluster Storage" (RHGS) through version 3.5. RHGS reached end-of-life on **December 31, 2024**. Red Hat disbanded its dedicated GlusterFS engineering team, significantly reducing contribution volume:

- Pre-2020: 1000+ commits/year
- 2023: ~78 commits
- 2024: ~31 commits

### Community-Maintained Status

Despite reduced corporate backing, GlusterFS remains open source and is maintained by community contributors:

- GlusterFS 11.2 was released July 2, 2024 — the project has not been abandoned.
- Benson Muite maintains Fedora packages "while there is activity upstream."
- The `gluster-mixins` monitoring project was updated in January 2025.
- Kadalu (Kubernetes integration) continues active development.
- Security updates are still being issued (e.g., openSUSE 2026-0099-1 security advisory in 2026).

### Debian / Distribution Packaging

GlusterFS 11.2 entered Debian unstable (sid) on January 6, 2026. It is also available in Fedora and RHEL/CentOS repositories via community maintainers.

### Fedora Retirement Discussion

Fedora stakeholders debated retiring GlusterFS packages due to reduced upstream activity. As of early 2026, the packages remain in Fedora while upstream shows activity.

### Practical Assessment

GlusterFS is in **maintenance mode** rather than active feature development. For new deployments:
- Consider whether Ceph (more actively developed, backed by IBM/Red Hat) or a cloud-native solution better fits requirements.
- For existing GlusterFS deployments: the software is stable, functional, and receiving security fixes.
- For Kubernetes storage: Kadalu is the recommended path; it is more actively maintained than core GlusterFS.
- The Proxmox community has advocated keeping GlusterFS support, indicating continued usage in production environments.

### Feature Comparison vs. Ceph (Context)

| Aspect | GlusterFS | Ceph |
|---|---|---|
| Metadata server | Distributed (no MDS) | CephFS has MDS |
| Complexity | Simpler to set up | More complex |
| Object storage | No | Yes (RGW/S3) |
| Block storage | No | Yes (RBD) |
| NFS | Via Ganesha | Via Ganesha |
| SMB | Via Samba | Via Samba |
| Corporate backing | Minimal (2025+) | Active (IBM/Red Hat) |
| Kubernetes CSI | Kadalu | Rook-Ceph |
| Erasure coding | Dispersed volumes | CRUSH with EC |
