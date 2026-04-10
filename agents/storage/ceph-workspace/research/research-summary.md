# Ceph Research Summary

## What Is Ceph

Ceph is an open-source software-defined storage platform that delivers object, block, and file storage from a single unified system. It is designed for commodity hardware, horizontal scalability from terabytes to exabytes, no single point of failure, and self-healing autonomic operation. Originally developed by Sage Weil at UC Santa Cruz, Ceph is now maintained by the Ceph Foundation and Red Hat, with releases managed by a community of vendors and contributors.

---

## Architecture in Brief

The entire stack rests on **RADOS** (Reliable Autonomic Distributed Object Store). RADOS is not a filesystem — it is a distributed object store that handles replication, consistency, recovery, and data placement without any centralized routing or lookup table.

On top of RADOS, Ceph provides three storage interfaces:
- **RBD** (RADOS Block Device): thin-provisioned block volumes for VMs and Kubernetes PVCs
- **CephFS**: POSIX-compliant distributed filesystem via a separate metadata server tier
- **RGW** (RADOS Gateway): S3 and Swift-compatible HTTP object storage

The four essential daemon types are:
- **MON** (Monitor): Maintains authoritative cluster state via Paxos consensus. Always deploy 3 or 5.
- **MGR** (Manager): Hosts Prometheus metrics, Dashboard, orchestration, and plugin modules.
- **OSD**: One per disk; stores data using BlueStore, handles replication, scrub, and recovery.
- **MDS**: Manages CephFS namespace (not needed for RBD or RGW-only deployments).

**CRUSH** is the algorithm every client and OSD uses to compute data placement without contacting a central broker. It uses a hierarchical bucket map (root → rack → host → osd) and configurable rules to achieve placement that respects failure domains.

**BlueStore** is the OSD storage engine. It bypasses the OS filesystem entirely, managing raw block devices directly. RocksDB (hosted on embedded BlueFS) stores all metadata; raw extents store object data. BlueStore checksums everything, supports inline compression, and enables copy-on-write snapshots through reference-counted extents.

**Placement Groups (PGs)** are the unit of data distribution. Objects map to PGs via a hash, and CRUSH maps PGs to OSDs. The PG abstraction allows data to be rebalanced by reassigning PGs without tracking individual objects. The PG autoscaler (default on) adjusts PG counts automatically based on pool data volume.

---

## Current Release Status (April 2026)

| Release | Version | Status |
|---------|---------|--------|
| Reef | 18.2.x | EOL |
| Squid | 19.2.x | Supported — EOL September 2026 |
| Tentacle | 20.2.x | **Current stable** — EOL ~November 2027 |

**Squid 19.2** (2024) focused on BlueStore performance for snapshot-heavy workloads (RocksDB LZ4 default), RBD diff-iterate local execution for faster backups, CephFS crash-consistent snapshots, and new RGW IAM APIs.

**Tentacle 20.2** (2025) is the current recommended release. Key additions:
- FastEC: dramatically faster erasure-coded pool writes and reads (parity delta, partial reads)
- ISA-L replaces Jerasure as the default EC plugin
- RBD instant live migration from external clusters and formats
- Integrated SMB Manager module (CephFS → Samba shares)
- `mgmt-gateway` service: single TLS-terminated entry point for all management endpoints
- `certmgr` subsystem for centralized certificate lifecycle
- OAuth2/OIDC SSO integration for Dashboard
- Per-directory case-insensitive filesystem configuration (CephFS)
- Pool availability score command: `ceph osd pool availability-status`
- SeaStore (next-gen object store) deployable alongside Crimson-OSD for testing

---

## Key Operational Concepts

### Sizing rules of thumb

- **3 monitors** minimum; **5** for large clusters or when geographic separation matters
- **4 GB RAM per OSD** minimum; 8 GB for NVMe; add 16 GB overhead per host
- **CPU:** 1 core per 2 HDD OSDs; 2 cores per SSD OSD; 4 cores per NVMe OSD
- **Networking:** 10 GbE minimum; 25–100 GbE for all-flash or high-throughput clusters
- **Capacity:** Never exceed 75% full on any OSD or pool
- **PG count:** 100–200 PGs per OSD across all pools combined (autoscaler handles this)

### CRUSH failure domains

The most important CRUSH decision is the failure domain. A 3-replica pool with `failure_domain = host` tolerates 2 complete host failures. With `failure_domain = rack`, it tolerates 2 complete rack failures. You need at least as many failure domain buckets as your replication factor.

### BlueStore performance hierarchy

From most to least impactful:
1. Separate DB/WAL onto NVMe for HDD OSDs (eliminates metadata bottleneck)
2. Set `osd_memory_target` appropriately (cache size directly impacts read performance)
3. Enable cache autotuning (`bluestore_cache_autotune`)
4. Configure I/O scheduler: `noop` for SSDs/NVMe, `mq-deadline` for HDDs
5. Tune recovery throttling to balance client I/O with data safety

### Rook for Kubernetes

Rook is the standard way to run Ceph on Kubernetes. It deploys all Ceph daemons as pods managed by a Kubernetes operator. Key points:
- Label storage nodes with `ceph-osd=true` and topology labels for correct CRUSH topology
- Use Ceph CSI driver (FlexVolume is deprecated)
- Host networking gives lowest latency but exits Kubernetes network policy domain
- Keep 10–15% storage headroom; Ceph performance degrades sharply above 80% utilization

---

## Diagnostics Quick Reference

| Symptom | First command | Then |
|---------|--------------|------|
| Cluster not HEALTH_OK | `ceph health detail` | Identify codes; see reference table |
| OSDs down | `ceph osd tree` | `systemctl status ceph-osd@<id>` |
| PGs stuck inactive | `ceph pg dump_stuck inactive` | `ceph pg <id> query` → identify blocking OSDs |
| Slow requests | `ceph health detail` → `ceph daemon osd.<id> dump_ops_in_flight` | `ceph osd perf` for latency |
| Recovery blocked | `ceph status` (check flags) | `ceph osd unset noout nobackfill norecover` |
| Clock skew | `ceph health detail` | `chronyc tracking` on all monitors |
| Network partition | `ceph quorum_status` | Fix network, then monitor re-peering |
| Disk near full | `ceph df` | Rebalance weights or add capacity |

The `ceph tell osd.* config set <key> <value>` pattern allows runtime configuration changes without restarting daemons. Changes via `ceph tell` are ephemeral; use `ceph config set` for persistence.

---

## Files in This Workspace

| File | Contents |
|------|----------|
| `architecture.md` | RADOS, OSD, MON, MGR, MDS, CRUSH algorithm, BlueStore internals, RBD, CephFS, RGW, PGs, failure domains, data flow, Cephadm |
| `features.md` | Squid 19.2 features, Tentacle 20.2 features, Squid-vs-Tentacle comparison table, upgrade paths |
| `best-practices.md` | Cluster sizing, CRUSH map design, pool configuration, PG tuning, BlueStore optimization, RBD for Kubernetes via Rook, CephFS configuration, Prometheus monitoring |
| `diagnostics.md` | `ceph health` check codes, OSD failure procedures, slow request analysis, PG state reference, recovery/backfill throttling, clock skew, network partitions, `ceph tell` commands, log analysis |

---

## Sources

- Ceph official documentation: https://docs.ceph.com/en/latest/
- Ceph v20.2.0 Tentacle release announcement: https://ceph.io/en/news/blog/2025/v20-2-0-tentacle-released/
- Ceph v20.2.1 Tentacle release: https://ceph.io/en/news/blog/2026/v20-2-1-tentacle-released/
- Tentacle release notes: https://docs.ceph.com/en/latest/releases/tentacle/
- Ceph Squid release notes: https://docs.ceph.com/en/latest/releases/squid/
- Ceph architecture deep dive (DeepWiki): https://deepwiki.com/ceph/ceph
- BlueStore optimization guide: https://oneuptime.com/blog/post/2026-01-30-ceph-bluestore-optimization/view
- OSD troubleshooting: https://oneuptime.com/blog/post/2026-01-07-ceph-osd-troubleshooting-recovery/view
- PG stuck inactive diagnostics: https://cr0x.net/en/proxmox-ceph-pg-stuck-inactive/
- Rook on Kubernetes best practices: https://documentation.suse.com/sbp/storage/html/SBP-rook-ceph-kubernetes/index.html
- Rook documentation: https://rook.io/docs/rook/latest-release/
- Ceph commands cheatsheet: https://github.com/TheJJ/ceph-cheatsheet
- CRUSH map documentation: https://docs.ceph.com/en/reef/rados/operations/crush-map/
- Ceph releases index: https://docs.ceph.com/en/latest/releases/
- FastEC performance updates: https://ceph.io/en/news/blog/2025/tentacle-fastec-performance-updates/
- 42on Tentacle overview: https://42on.com/new-ceph-release-ceph-tentacle/
- NVMe performance optimization: https://oneuptime.com/blog/post/2026-01-07-ceph-nvme-performance-optimization/view
