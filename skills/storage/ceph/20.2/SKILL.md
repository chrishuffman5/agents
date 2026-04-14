---
name: storage-ceph-20-2
description: "Version-specific expert for Ceph Tentacle 20.2 (current stable). Covers FastEC erasure coding, mgmt-gateway, oauth2-proxy, certmgr, SMB Manager, instant RBD live migration, per-directory case insensitivity, and Crimson/SeaStore advancement. WHEN: \"Ceph Tentacle\", \"Ceph 20\", \"Tentacle 20.2\", \"latest Ceph\", \"Ceph current\"."
license: MIT
metadata:
  version: "1.0.0"
  author: christopher huffman
---

# Ceph Tentacle 20.2 Version Expert

You are a specialist in Ceph Tentacle 20.2, the current stable release (supported until ~November 2027). For foundational Ceph knowledge, refer to the parent technology agent. This agent focuses on what is new or changed in Tentacle.

## Key Features

### FastEC -- Erasure Coding Performance Overhaul

- **Parity delta write optimization:** For wide EC profiles (k+m >= 6), partial stripe writes compute only the delta to parity. Reduces write amplification significantly.
- **Partial reads:** Reads only the minimum data chunks needed, improving read performance and reducing drive utilization.
- **ISA-L as default plugin:** Intel Storage Acceleration Library replaces the unmaintained Jerasure for new pools. Existing pools retain their configured plugin.

### RADOS / BlueStore

- **Faster WAL implementation** reducing commit latency under write-heavy workloads.
- **Improved compression integration** with the new WAL.
- **Faster OMAP iteration interface** for RGW bucket listing and scrub operations.
- **Data Availability Score per pool:**
  ```bash
  ceph osd pool availability-status
  ```

### RBD

- **Instant live migration from external sources.** Images imported from another Ceph cluster or external formats (raw, qcow2, vmdk). Migration happens online; image accessible immediately with background data transfer.
- **Namespace remapping during mirroring** simplifying active-passive DR configurations.
- **Enhanced group and group snapshot commands.**
- **rbd device map defaults to msgr2** (with encryption support).

### CephFS

- **Case-insensitive and Unicode-normalized directories.** Individual directories configurable with `case_sensitive=false` for Windows/macOS compatibility.
- **Safer max_mds changes** require confirmation flag when cluster is unhealthy.
- **Snapshot path retrieval subcommand** to query path of a named snapshot.
- **cephfs-proxy daemon** improves scalability for SMB and NFS gateways.

### RGW

- **S3 GetObjectAttributes support** for backup tool compatibility.
- **LastModified timestamps truncated to seconds** for AWS S3 compatibility.
- **Bucket resharding pre-write optimization** dramatically reduces client-visible latency during resharding.
- **User Account model replaces tenant IAM** for new deployments.
- **PutObjectLockConfiguration on existing versioned buckets.**

### Integrated SMB Support

- **SMB Manager module** for automated Samba-backed SMB shares connected to CephFS.
- **Active Directory and standalone authentication.**
- **cephfs-proxy daemon** for SMB gateway scalability.

### Management and Orchestration

- **mgmt-gateway service:** Nginx-based reverse proxy providing single TLS-terminated HTTPS entry point for Dashboard, Prometheus, Grafana, Alertmanager. Supports HA active/standby.
  ```bash
  ceph orch apply mgmt-gateway
  ```
- **oauth2-proxy service:** Centralized SSO via OAuth 2.0 / OIDC identity providers.
- **certmgr subsystem:** Centralized certificate lifecycle management (tracking, renewal, distribution).
- **Always-on modules can be force-disabled** for troubleshooting.
- **Deprecated modules removed:** `mgr/restful` and `mgr/zabbix`.

### Crimson / SeaStore

SeaStore deployable alongside Crimson-OSD for test environments. Not yet production-ready.

## What Changed from Squid

| Area | Squid 19.2 | Tentacle 20.2 |
|------|-----------|---------------|
| EC plugin default | Jerasure | ISA-L |
| EC performance | Standard | FastEC (parity delta, partial reads) |
| RBD migration | Manual copy | Instant live migration |
| CephFS case sensitivity | Not configurable per-dir | Per-directory config |
| SMB support | External Samba only | Integrated SMB Manager |
| RGW IAM | New AWS-compatible APIs | Account model replaces tenant IAM |
| RGW resharding | Client-visible latency | Pre-write optimization |
| Management gateway | Manual TLS config | mgmt-gateway service (nginx, HA) |
| Authentication | No built-in SSO | oauth2-proxy + OIDC |
| Certificate management | Manual | certmgr centralized lifecycle |

## Upgrade from Squid

Rolling upgrade sequence: MON -> MGR -> OSD -> MDS -> RGW -> RBD Mirror. Each daemon type fully upgraded before the next. OSDs rolled one at a time with no downtime.

**Critical notes:**
- Downgrades from Tentacle to Squid are not supported
- If using ISA-L EC optimizations, verify CPU supports AVX2/AVX512
- Rook-managed clusters: update `spec.cephVersion.image` in CephCluster CR
