# Ceph Release Features: Squid 19.2 and Tentacle 20.2

## Release Timeline

| Release | Version | Status | EOL |
|---------|---------|--------|-----|
| Reef | 18.2.x | EOL (early 2025) | Reached EOL |
| Squid | 19.2.x | Maintained | September 2026 |
| Tentacle | 20.2.x | Current stable | ~November 2027 |

Ceph follows a roughly annual stable release cycle. Squid (19.2) was released in 2024 and will remain supported until September 2026. Tentacle (20.2.0) was released in 2025 and is the current recommended production release.

---

## Ceph Squid 19.2 — Features

Squid is the 19th stable release of Ceph. Its major themes are BlueStore performance improvements, RBD backup tooling, RGW IAM, and CephFS snapshot reliability.

### RADOS / BlueStore

- **LZ4 compression in RocksDB enabled by default.** Reduces monitor DB and OSD metadata size; improves performance on snapshot-intensive workloads by shrinking the amount of data RocksDB must read and write during compaction.
- **Improved scrub scheduling.** Large clusters can now spread scrub load more evenly across OSDs, reducing latency spikes during scheduled scrub windows.
- **New CRUSH rule type for Erasure Coding.** More flexible EC configurations are supported, enabling better placement in heterogeneous hardware environments.
- **Enhanced snapshot-heavy workload performance.** BlueStore reference counting and blob sharing have been tuned to reduce write amplification when many snapshots exist.

### RBD

- **diff-iterate local execution.** The diff-iterate API can now run comparisons locally within the OSD, delivering dramatic performance improvements for QEMU live disk synchronization and backup workflows (e.g., QEMU backup plugins, Proxmox Backup Server).
- **Clone from non-user type snapshots.** OSDs can now clone from internal snapshot types, enabling new backup and DR workflows.
- **rbd-wnbd multiplex.** The Windows NBD driver can multiplex multiple image mappings over fewer TCP sessions, reducing connection overhead in Windows guest environments.
- **Crimson/SeaStore tech preview.** The Crimson OSD and SeaStore object store reached tech preview status supporting RBD workloads on replicated pools.

### CephFS

- **Crash-consistent snapshots across distributed applications.** New commands allow pausing I/O and metadata mutations across an entire filesystem or subtree before creating a snapshot, enabling application-consistent point-in-time copies.
- **Improved subvolume management.** New control commands for listing, resizing, and managing subvolumes and their groups.
- **OpTracker for MDS.** Added operation tracking to help diagnose slow MDS requests and deadlocks.

### RGW

- **New AWS-compatible IAM APIs.** Self-service user and access key management conforming to AWS IAM REST API. Users can manage their own credentials without admin intervention.
- **New S3 Bucket Notification data layout.** Each SNS Topic is stored as a separate RADOS object and bucket notification configuration is stored in bucket attributes. This layout supports multisite metadata sync and scales to thousands of topics.
- **Better replication handling for multipart uploads with encrypted objects.** Fixes gaps in multisite sync for SSE-KMS encrypted multipart objects.
- **radosgw-admin tools for versioned bucket index repair.** New subcommands identify and correct inconsistencies in versioned bucket indexes.

### Dashboard

- Overhauled UI/UX with improved navigation and simplified CephFS volume mounting workflows.

---

## Ceph Tentacle 20.2 — Features

Tentacle is the 20th stable release. Its major themes are erasure coding performance (FastEC), operational tooling (mgmt-gateway, certmgr), RBD live migration, SMB integration, and Crimson/SeaStore advancement.

### RADOS / BlueStore

- **FastEC — Erasure Coding Performance Overhaul.**
  - *Parity delta write optimization:* For wide EC profiles (k+m >= 6), partial stripe writes compute only the delta to parity rather than re-encoding the full stripe. Reduces write amplification significantly.
  - *Partial reads:* Reads only the minimum data chunks needed to serve a client request, improving read performance and reducing drive utilization.
  - *ISA-L as default plugin:* Intel Storage Acceleration Library (ISA-L) replaces the unmaintained Jerasure as the default erasure code plugin for new pools created on Tentacle. Existing pools retain their configured plugin.

- **BlueStore WAL improvements.** The write-ahead log implementation is faster, reducing commit latency under write-heavy workloads.

- **BlueStore compression improvements.** Better compression integration with the new WAL, reducing overhead for compressed pools.

- **Faster OMAP iteration interface.** All components that iterate RADOS object omap data (RGW bucket listing, scrub operations) have been switched to a new, faster interface. Reduces latency for large buckets and during scrubs.

- **Data Availability Score per pool.** New command `ceph osd pool availability-status` shows a per-pool availability score, helping operators assess fault tolerance headroom before adding or removing OSDs.

### RBD

- **Instant live migration from external sources.** RBD images can be instantly imported from another Ceph cluster (native RBD format via NBD stream) or from external formats (raw, qcow2, vmdk). Migration happens online; the image is accessible immediately and data is transferred in the background.
- **Namespace remapping during mirroring.** RBD mirroring now supports remapping namespaces between source and destination clusters, simplifying active-passive DR configurations where namespace layout differs.
- **Enhanced group and group snapshot commands.** Group management commands improved for consistency groups spanning multiple images.
- **rbd device map defaults to msgr2.** The newer msgr2 protocol (with encryption support) is now the default for kernel-level RBD mounts.
- **Python API timezone-aware timestamps.** The `rbd` Python bindings now return timezone-aware datetime objects for all timestamp fields.

### CephFS

- **Case-insensitive and Unicode-normalized directories.** Individual directories can be configured with `case_sensitive=false` or a Unicode normalization form. Enables Windows and macOS compatibility without requiring filesystem-wide case folding.
- **Safer max_mds changes on unhealthy clusters.** The `ceph fs set max_mds` command now requires a confirmation flag when the cluster is not fully healthy, preventing accidental MDS rank additions during degraded states.
- **fallocate returns EOPNOTSUPP for default mode.** Aligns CephFS with standard POSIX behavior for the default `fallocate` mode (zero-reservation pre-allocation not supported).
- **Snapshot path retrieval subcommand.** Users can query the filesystem path of a named snapshot without knowing the internal snapshot ID.
- **Subvolume clone source tracking.** The `fs subvolume info` output now includes a `source` field identifying the snapshot the subvolume was cloned from.
- **Namespace pool naming updated.** Subvolume pool namespace naming changed to prevent collisions between subvolumes in the same volume.
- **cephfs-proxy daemon.** A new lightweight proxy daemon improves scalability for SMB and NFS gateways accessing CephFS.

### RGW

- **S3 GetObjectAttributes support.** Returns object metadata (checksum, size, part count) without retrieving the object body; commonly used by S3-compatible backup tools.
- **LastModified timestamps truncated to seconds.** Improves compatibility with AWS S3 behavior; some third-party tools were failing on sub-second precision.
- **Bucket resharding pre-write optimization.** The bucket resharding process now moves most heavy computation to a pre-write stage, dramatically reducing client-visible latency during resharding of large buckets.
- **User Account replaces tenant IAM.** Account-level IAM semantics replace the older tenant model for new deployments. Tenant-level IAM APIs are deprecated.
- **PutObjectLockConfiguration on existing versioned buckets.** Object Lock can now be enabled on a bucket that already has versioning enabled (previously required creating a new bucket).
- **x-amz-confirm-remove-self-bucket-access header support.** Safety mechanism for IAM policy operations that would remove the caller's own access.

### Integrated SMB Support

- **SMB Manager module.** A new `mgr` module functions analogously to the existing NFS module, enabling automated creation of Samba-backed SMB shares connected to CephFS subtrees.
- **Active Directory and standalone authentication.** The SMB module supports both AD-joined and standalone (local user) authentication configurations.
- **cephfs-proxy daemon.** Improves scalability and resilience for SMB gateway to CephFS traffic.

### Management and Orchestration

- **mgmt-gateway service (Cephadm).** A new nginx-based reverse proxy service providing a single TLS-terminated HTTPS entry point for Dashboard, Prometheus, Grafana, and Alertmanager. Supports high-availability active/standby configurations.
- **oauth2-proxy service (Cephadm).** Centralized authentication and SSO for all Ceph management endpoints. Integrates with OAuth 2.0 / OIDC identity providers.
- **certmgr subsystem.** Centralized certificate lifecycle management. Tracks certificate expiry, handles renewals, and distributes certificates to daemon services.
- **Always-on modules can be force-disabled.** Previously, always-on MGR modules could not be disabled; Tentacle allows force-disabling them for troubleshooting.
- **Deprecated modules removed.** `mgr/restful` and `mgr/zabbix` have been officially removed after deprecation in prior releases.

### Crimson / SeaStore

- **SeaStore deployable alongside Crimson-OSD.** SeaStore moves beyond the tech-preview stage; it can now be deployed in test environments alongside the Crimson OSD for early experimentation and developer validation. Not yet suitable for production.

---

## What Changed Between Squid and Tentacle

| Area | Squid 19.2 | Tentacle 20.2 |
|------|-----------|---------------|
| EC plugin default | Jerasure | ISA-L |
| EC performance | Standard | FastEC (parity delta, partial reads) |
| BlueStore WAL | Existing | Faster WAL implementation |
| RocksDB compression | LZ4 default | LZ4 + improved integration |
| OSD OMAP iteration | Standard | Faster iteration API |
| Pool monitoring | Basic stats | Availability score per pool |
| RBD migration | Manual copy | Instant live migration (internal + external) |
| RBD namespace mirroring | Standard | Namespace remapping support |
| CephFS case sensitivity | Not configurable per-dir | Per-directory case-insensitive config |
| CephFS snapshots | Crash-consistent pausing | Snapshot path retrieval added |
| SMB support | External Samba only | Integrated SMB Manager module + cephfs-proxy |
| RGW IAM | New AWS-compatible APIs | Account model replaces tenant IAM |
| RGW bucket resharding | Client-visible latency spike | Pre-write optimization |
| Management gateway | Manual TLS config | mgmt-gateway service (nginx, HA) |
| Authentication | No built-in SSO | oauth2-proxy + OIDC/OAuth2 |
| Certificate management | Manual | certmgr centralized lifecycle |
| Crimson/SeaStore | RBD tech preview | SeaStore + Crimson deployable for testing |
| Deprecated removals | — | mgr/restful and mgr/zabbix removed |

---

## Upgrade Path

### Squid to Tentacle

The standard rolling upgrade sequence for non-cephadm deployments:

```
MON → MGR → OSD → MDS → RGW → RBD Mirror
```

Each daemon type is upgraded fully before moving to the next. OSDs can be rolled one at a time with no downtime.

**Critical notes:**
- Downgrades from Tentacle to Squid are **not supported**
- Test in a staging environment before upgrading production
- If using ISA-L EC optimizations, verify your CPU supports AVX2/AVX512
- Proxmox VE has a dedicated migration guide (Ceph Squid to Tentacle wiki page)
- Rook-managed clusters follow a different path: update the CephCluster CR `spec.cephVersion.image`

### Reef to Squid / Tentacle

Reef (18.2) is EOL. If running Reef, upgrade to Squid first, validate, then proceed to Tentacle. Do not skip major versions.
