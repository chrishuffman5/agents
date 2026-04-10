# GlusterFS Research Summary

## What GlusterFS Is

GlusterFS is a free and open-source, POSIX-compliant distributed filesystem that aggregates disk storage from multiple commodity servers into a single unified namespace. It was originally developed by Gluster, Inc. (acquired by Red Hat in 2011). Unlike Ceph or HDFS, GlusterFS has no central metadata server — all metadata is distributed via consistent hashing and extended attributes stored on the bricks themselves.

Key design properties:
- No metadata server (eliminates SPOF and bottleneck)
- Fully userspace (FUSE-based client, no kernel drivers required)
- Composable translator (xlator) architecture — the entire feature set is implemented as stackable modules
- Multiple access protocols: native FUSE, NFS (via NFS-Ganesha), SMB (via Samba + vfs_glusterfs)
- Synchronous replication and erasure coding for data durability
- Asynchronous geo-replication for DR/multi-site

---

## Architecture in Brief

The core components are:
1. **glusterd** — Management daemon on every node; maintains cluster membership (Trusted Storage Pool) and configuration.
2. **glusterfsd** — One per brick; exports local storage over GlusterFS RPC.
3. **glusterfs (client)** — Mounts volumes via FUSE; implements the full translator stack including DHT (distribution) and AFR (replication) in userspace.

Translators of note:
- **DHT** — Consistent hashing for file distribution across bricks; no central directory.
- **AFR** — Synchronous replication with per-file xattr change tracking; feeds the self-heal daemon.
- **EC** — Reed-Solomon erasure coding for dispersed volumes; SIMD-accelerated.
- **Performance xlators** — io-cache, write-behind, read-ahead, md-cache, io-threads.

Volume types in increasing complexity:
1. Distributed — capacity scaling, no HA
2. Replicated (prefer replica 3 or 2+1 arbiter) — HA with full copies
3. Distributed Replicated — HA + horizontal scale (most common production choice)
4. Dispersed — erasure coding for storage efficiency
5. Distributed Dispersed — scale + efficiency

---

## Current Project Status (April 2026)

**Version:** 11.2 (released July 2, 2024; latest available)

**Commercial support:** Red Hat Gluster Storage (RHGS) reached EOL December 31, 2024. Red Hat disbanded its dedicated engineering team.

**Community health:** Reduced but active:
- ~31 commits in 2024 (vs. 1000+/year at peak)
- Security patches still issued (openSUSE security advisory 2026)
- Fedora packages maintained by community volunteer
- Monitoring tooling (gluster-mixins) updated January 2025
- Debian 11.2 packages entered unstable January 6, 2026

**Honest assessment:** GlusterFS is in maintenance mode. It is stable and receives security fixes, but active feature development has largely stopped. For new projects with significant scale or Kubernetes requirements, evaluate Ceph (Rook-Ceph) as an alternative. For existing GlusterFS deployments, continued use is reasonable — the software is mature and operationally well-understood.

---

## Key Strengths

1. **Simplicity** — Easier to deploy and operate than Ceph for small-to-medium clusters.
2. **No metadata server** — Eliminates the MDS as a bottleneck and single point of failure.
3. **Flexible access protocols** — FUSE, NFS (NFSv3/4/4.1/pNFS), SMB — covers most client types.
4. **Mature geo-replication** — Changelog-based async replication is well-tested for DR use cases.
5. **POSIX compliance** — Applications can use GlusterFS like a local filesystem with minimal changes.
6. **Arbiter volumes** — Cost-effective HA (2× overhead instead of 3×) with split-brain prevention.
7. **Erasure coding** — Dispersed volumes provide configurable storage efficiency comparable to RAID 6.

---

## Key Weaknesses and Risks

1. **Small-file performance** — DHT hashing and FUSE overhead make small-file workloads significantly slower than local filesystem or object storage.
2. **Split-brain** — Even with replica 3 and arbiter configurations, split-brain can occur and may require manual resolution, which is operationally complex.
3. **No built-in object storage** — No S3-compatible endpoint; requires external gateway.
4. **No block storage** — Cannot serve block devices (unlike Ceph RBD).
5. **Reduced development momentum** — Minimal new features after Red Hat withdrawal; compatibility with newer kernel features may lag.
6. **Kubernetes integration gap** — Original Heketi/gluster-kubernetes deprecated in K8s 1.25; Kadalu is the successor but is also a community project with limited backing.
7. **Rebalance overhead** — Adding capacity requires a rebalance operation that can saturate storage network during execution.

---

## Decision Criteria for GlusterFS

Use GlusterFS when:
- You need a simple POSIX distributed filesystem with NFS or SMB access for file-sharing workloads.
- You have an existing GlusterFS cluster in production and want to continue with minimal disruption.
- Your cluster is 3-12 nodes and Ceph's operational complexity is not justified.
- You need `ReadWriteMany` Kubernetes PVs with the Kadalu operator.
- The workload is large files (video, backups, scientific data) where small-file weakness is not a concern.

Prefer an alternative when:
- You need S3 object storage or iSCSI block storage.
- Your workload is millions of small files.
- You need active development of new features and long-term vendor support.
- You are starting fresh with Kubernetes-native storage (consider Rook-Ceph instead).

---

## File Index

| File | Contents |
|---|---|
| `architecture.md` | Trusted Storage Pool, bricks, all volume types with commands, translator stack (DHT/AFR/EC), FUSE mount, NFS-Ganesha, Samba/SMB, geo-replication, self-heal daemon |
| `features.md` | GlusterFS 11.x feature set (snapshots, quota, arbiter, dispersed, geo-rep, monitoring), project status and community health assessment |
| `best-practices.md` | Volume design guidelines, brick layout (XFS formatting, RAID selection, network layout), performance tuning (volume options, mount options, OS tuning), monitoring stack, geo-rep setup, Kubernetes/Kadalu integration |
| `diagnostics.md` | Log file reference, volume heal commands, split-brain detection and all resolution methods, brick failure and replacement procedures, performance troubleshooting, `gluster volume info/status` output interpretation |
| `research-summary.md` | This file — executive overview, current project status, strengths/weaknesses, and decision criteria |

---

## Quick Reference: Most-Used Commands

```bash
# Cluster
gluster peer probe <node>
gluster peer status
gluster pool list

# Volumes
gluster volume create <name> replica 3 <brick1> <brick2> <brick3>
gluster volume start <name>
gluster volume stop <name>
gluster volume delete <name>
gluster volume info
gluster volume status <name>

# Tune
gluster volume set <name> performance.cache-size 1GB
gluster volume set <name> performance.write-behind-window-size 64MB

# Health check
gluster volume heal <name> info summary
gluster volume heal <name> info split-brain
gluster volume heal <name>

# Mount
mount -t glusterfs -o log-level=WARNING,_netdev server1:<name> /mnt/gluster

# Profile
gluster volume profile <name> start
gluster volume profile <name> info
gluster volume profile <name> stop

# Geo-replication
gluster volume geo-replication <master> <slave-host>::<slave-vol> create push-pem
gluster volume geo-replication <master> <slave-host>::<slave-vol> start
gluster volume geo-replication <master> <slave-host>::<slave-vol> status
```

---

## Sources

- [GlusterFS Architecture Documentation](https://docs.gluster.org/en/main/Quick-Start-Guide/Architecture/)
- [GlusterFS Translators Overview](https://glusterdocs-beta.readthedocs.io/en/latest/overview-concepts/translators.html)
- [Setting Up GlusterFS Volumes](https://docs.gluster.org/en/main/Administrator-Guide/Setting-Up-Volumes/)
- [GlusterFS Performance Tuning](https://docs.gluster.org/en/main/Administrator-Guide/Performance-Tuning/)
- [Troubleshooting Split-Brains](https://docs.gluster.org/en/main/Troubleshooting/resolving-splitbrain/)
- [Heal Info and Split-Brain Resolution](https://glusterdocs.readthedocs.io/en/latest/Troubleshooting/heal-info-and-split-brain-resolution/)
- [Arbiter Volumes and Quorum](https://docs.gluster.org/en/main/Administrator-Guide/arbiter-volumes-and-quorum/)
- [Geo Replication](https://docs.gluster.org/en/v3/Administrator%20Guide/Geo%20Replication/)
- [GlusterFS Release Schedule](https://www.gluster.org/release-schedule/)
- [GlusterFS GitHub Releases](https://github.com/gluster/glusterfs/releases)
- [GlusterFS Future Discussion](https://github.com/gluster/glusterfs/discussions/4231)
- [GlusterFS Project Status Discussion](https://github.com/gluster/glusterfs/issues/4298)
- [Kadalu Kubernetes Storage Operator](https://github.com/kadalu/kadalu)
- [NFS-Ganesha GlusterFS Integration](https://docs.gluster.org/en/main/Administrator-Guide/NFS-Ganesha-GlusterFS-Integration/)
- [GlusterFS Samba Integration](https://wiki.samba.org/index.php/GlusterFS)
- [Gluster Prometheus Exporter](https://github.com/gluster/gluster-prometheus)
- [Gluster Mixins (Grafana/Prometheus)](https://github.com/gluster/gluster-mixins)
- [AFR (Automatic File Replication) Internals](https://gluster-documentations.readthedocs.io/en/latest/Features/afr-v1/)
- [EC Implementation Details](https://github.com/gluster/glusterfs/blob/master/doc/developer-guide/ec-implementation.md)
- [Replace Failed Brick Procedure](https://oneuptime.com/blog/post/2026-03-04-replace-failed-brick-glusterfs-rhel-9/view)
- [Oracle Linux Gluster Best Practices](https://www.oracle.com/a/ocom/docs/linux/gluster-storage-linux-best-practices.pdf)
- [Red Hat Gluster Storage Life Cycle](https://access.redhat.com/support/policy/updates/rhs)
- [Phoronix: Fedora GlusterFS Retirement Discussion](https://www.phoronix.com/news/Fedora-Maybe-Retire-GlusterFS)
