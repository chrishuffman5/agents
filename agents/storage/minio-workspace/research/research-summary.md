# MinIO Research Summary

## Research Date
April 9, 2026

## Status: Community Edition Archived

The most critical context for any new MinIO evaluation: the `minio/minio` GitHub repository was officially archived (read-only) on **February 13, 2026**. MinIO Inc. has transitioned all active development to **AIStor**, its commercial product. The community edition received no further features or security patches after that date.

This research covers both the archived community edition (for teams maintaining existing deployments) and the AIStor product line (for new deployments).

---

## What MinIO Is

MinIO is a **high-performance, S3-compatible object storage system** written in Go. Its primary strengths are:

- True wire-speed throughput (benchmarked at ~10 GB/s GET, ~5 GB/s PUT per node on NVMe + 100 GbE).
- Native Kubernetes operability via the MinIO Operator and Tenant CRD.
- Drop-in S3 API compatibility, making it the de facto standard for on-premises S3 replacement.
- Strong data durability via Reed-Solomon erasure coding with AVX-512 acceleration and HighwayHash bitrot detection.

---

## Architecture at a Glance

MinIO uses a three-tier storage hierarchy: **Server Pools → Erasure Sets → Drives**.

- **Server Pools** are independently addressable groups of nodes. Pools can be added online to grow capacity without rebalancing existing data.
- **Erasure Sets** are fixed-size drive groups (4–32 drives) within a pool. Objects are placed in erasure sets via consistent hashing. Reed-Solomon erasure coding is applied inline — data is never written to disk without being sharded and checksummed.
- **Drives** are typically direct-attached NVMe. Remote drives are accessed via the internal Storage REST API.

Write quorum is (N/2)+1; read quorum is N/2. Default parity is EC:N/2 — a 16-drive set tolerates up to 8 simultaneous drive failures for reads.

All metadata lives in `xl.meta` files replicated across every drive in the erasure set. There is no external metadata database.

---

## Key Features

| Feature             | Details                                                                                    |
|---------------------|-------------------------------------------------------------------------------------------|
| S3 API compatibility| High-fidelity S3 API; drop-in for AWS S3 workloads                                       |
| Erasure coding      | Reed-Solomon, inline, AVX-512 accelerated. Default EC:N/2. Configurable up to EC:N/2 max  |
| Bitrot protection   | HighwayHash-256 checksums on every shard, verified on every read                          |
| Versioning          | Full S3 versioning model; enable per-bucket; suspend but not disable after enabling        |
| Object locking/WORM | COMPLIANCE and GOVERNANCE modes; legal hold; requires versioning                          |
| Bucket notifications| AMQP, Kafka, NATS, NSQ, MQTT, Elasticsearch, MySQL, PostgreSQL, Redis, Webhook            |
| ILM/Lifecycle       | Expiration, transition (tiering), noncurrent-version management; S3 lifecycle API compat  |
| IAM                 | AWS IAM policy syntax; built-in users, LDAP, OIDC, STS temp credentials                  |
| Encryption          | SSE-S3, SSE-KMS (via KES + external KMS), SSE-C                                           |
| Site replication    | Active-active multi-site; replicates IAM + data + bucket config; mutually exclusive with bucket replication |
| Batch operations    | Server-side bulk replicate, expire, keyrotate via YAML job definitions                    |
| Kubernetes Operator | `Tenant` CRD; auto-TLS; hybrid cloud support; Helm deployment                             |

---

## The Licensing and Community Edition Situation

| Date           | Event                                                                               |
|----------------|-------------------------------------------------------------------------------------|
| May 2021       | Relicensed from Apache 2.0 to GNU AGPLv3                                           |
| May 2025       | Admin console removed from community edition                                        |
| October 2025   | Binary and Docker distribution of community builds halted by MinIO Inc.             |
| December 2025  | Maintenance mode declared                                                           |
| February 2026  | Repository archived. Community edition end of life.                                 |

**AGPLv3 implications**: Running modified MinIO as a network service requires making modified source available to users. Unmodified internal use is generally acceptable without compliance concern, but SaaS providers and cloud vendors face significant AGPL exposure.

**AIStor Free tier** exists but is proprietary-licensed with MinIO controlling distribution. Enterprise tier is approximately $96,000/year.

**Community alternatives** for teams that cannot or will not move to AIStor:
- **Garage** — lightweight, edge-optimized, actively maintained open source
- **SeaweedFS** — high-speed, multi-protocol (S3, HDFS, FUSE, NFS)
- **Ceph RGW** — enterprise-grade, highly scalable, full S3 + Swift compatibility
- **Apache Ozone** — optimized for Hadoop/big data ecosystems

---

## Best Practices Summary

**Hardware**: Homogeneous nodes, direct-attached NVMe, XFS filesystem, 100 GbE networking, no hardware RAID, no ext4.

**Erasure Coding**: Use MinIO defaults (EC:N/2). Only deviate after using the Erasure Code Calculator and understanding the availability/efficiency tradeoff.

**Security**: TLS everywhere, ECDSA/EdDSA certificates, service accounts with least-privilege inline policies, SSE-KMS with external key management for regulated workloads, audit logging to SIEM.

**Kubernetes**: Use the Operator with local NVMe StorageClass, pod anti-affinity across physical nodes, pinned image digests, dedicated namespace with NetworkPolicies.

**Backup**: Layer erasure coding (hardware HA) + site replication (geographic HA/DR) + versioned bucket replication to a separate account (logical backup). Test restores regularly.

---

## Diagnostics Quick Reference

| Goal                       | Command                                        |
|----------------------------|------------------------------------------------|
| Cluster overview           | `mc admin info myminio`                        |
| Drive status               | `mc admin info myminio --json \| jq ...`       |
| Start healing scan         | `mc admin heal myminio --recursive`            |
| Performance test           | `mc support perf myminio`                      |
| S3 benchmark               | `warp put/get/mixed ...`                       |
| Live logs                  | `mc admin logs myminio`                        |
| Config export              | `mc admin config export myminio`               |
| Replication status         | `mc admin replicate status myminio`            |
| Health endpoint            | `curl https://minio:9000/minio/health/cluster` |
| Prometheus metrics token   | `mc admin prometheus generate myminio`         |

---

## Decision Framework for New Deployments

**Use AIStor (Free or Enterprise) if:**
- You need active security patches and bug fixes.
- You require the full admin console and management features.
- You want official support and SLA guarantees.
- Your compliance requirements need SUBNET health diagnostics.

**Use last community release (archived) if:**
- You have existing deployments you want to stabilize before migrating.
- You can accept no future security patches.
- Your use case is well within the capability of the stable last release.
- You have internal Go expertise to apply patches from the fork community.

**Consider alternatives (Garage, Ceph, SeaweedFS) if:**
- AGPLv3 or AIStor pricing is a blocker.
- You want a fully open-source, community-maintained S3-compatible store.
- Your workload fits the strengths of an alternative (e.g., Ceph for scale, Garage for edge).

---

## Files in This Research Package

| File                  | Content                                                                          |
|-----------------------|----------------------------------------------------------------------------------|
| `architecture.md`     | Server pools, erasure coding, bitrot, mc client, KES, notifications, ILM, IAM, site replication, K8s Operator |
| `features.md`         | Current capabilities, AGPL/AIStor transition, versioning, object locking, batch ops, SSE |
| `best-practices.md`   | Hardware sizing, EC selection, bucket design, security hardening, K8s deployment, performance tuning, backup strategy |
| `diagnostics.md`      | mc admin commands, health checks, drive failure procedures, healing, benchmarking, network diagnostics, common issues |
| `research-summary.md` | This file — synthesis, key decisions, quick references                           |

---

## Sources Consulted

- MinIO AIStor Documentation: docs.min.io/enterprise/aistor-object-store/
- MinIO Blog: blog.min.io (erasure coding, replication best practices, batch framework, KES)
- MinIO GitHub Repository: github.com/minio/minio (archived Feb 2026)
- MinIO Operator GitHub: github.com/minio/operator
- DeepWiki MinIO Architecture Analysis: deepwiki.com/minio/minio
- Calmops MinIO Internals and Trends: calmops.com/database/minio/
- The Cloud Support Engineer — Community Edition Archival: thecloudsupportengineer.com
- OneUptime Blog — Erasure Coding, Bucket Notifications, Replication: oneuptime.com/blog
- Intel MinIO Benchmark Methods: intel.com/content/www/us/en/developer/articles/technical/minio-cluster-benchmark-methods-and-tools.html
- MinIO Warp S3 Benchmark Tool: github.com/minio/warp
