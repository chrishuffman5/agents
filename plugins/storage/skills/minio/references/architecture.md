# MinIO Architecture

## Storage Hierarchy: Pools, Erasure Sets, Drives

MinIO organizes storage in a strict three-tier hierarchy: Server Pools -> Erasure Sets -> Physical Drives.

**Server Pools:** A set of nodes forming a single namespace. Pools can be added online to expand capacity without rebalancing existing data. New writes go to the pool with most available capacity.

**Erasure Sets:** Within each pool, drives are grouped into fixed-size sets of 4-16 drives (up to 32 in AIStor 2026+). Object placement via consistent hashing. Erasure set size computed at startup; cannot change after deployment.

**Drives:** Direct-attached NVMe strongly recommended. Remote drives accessed via internal Storage REST API.

## Erasure Coding (Reed-Solomon)

For each write: split into K data shards, compute M parity shards, write K+M in parallel. Default: K = M = N/2.

Quorum: Write requires (N/2)+1 drives, Read requires N/2. Block size: 1 MiB per erasure operation. AVX-512 SIMD acceleration for Galois Field arithmetic.

## Bitrot Protection

Every shard checksummed with HighwayHash-256. On every read, checksums verified. Mismatches trigger automatic reconstruction from parity. Background healing scans proactively.

## On-Disk Layout

```
<data-dir>/<bucket>/<object-key>/
  xl.meta          <- metadata (MessagePack, all versions, EC config, checksums)
  <version-id>/
    part.1         <- shard (data or parity)
    part.N
```

## Request Pipeline

```
Client HTTP/S -> TLS -> Auth (IAM) -> Middleware (logging, metrics, rate limiting)
  -> S3 API Handler -> ObjectLayer -> ErasurePoolsObjects -> ErasureObjects -> Drives
```

## Internode Communication

| Protocol | Purpose |
|----------|---------|
| Storage REST | Remote disk read/write/stat |
| Peer REST | Config sync, lifecycle, IAM propagation |
| Lock REST | Distributed locking (dsync) |
| Grid RPC | High-performance binary RPC |

All internode traffic supports TLS encryption.

## Background Services

**Data Scanner:** Periodic crawl for bitrot detection, usage metrics, quota enforcement, ILM rule enforcement. Configurable throttle.

**Healing System:** Repairs degraded objects. Triggered on drive rejoin. Prioritized by shard health (fewest valid shards healed first). `mc admin heal` for manual triggers.

## KES -- Key Encryption Service

Stateless proxy between MinIO and external KMS (HashiCorp Vault, AWS KMS, Azure Key Vault, GCP KMS). Uses mTLS for authentication.

| Mode | Key Management | Use Case |
|------|----------------|----------|
| SSE-S3 | MinIO-managed, single key | Simple encryption |
| SSE-KMS | KES + external KMS, per-bucket/object | Compliance, rotation |
| SSE-C | Client-provided per request | Client controls keys |

## Site Replication

Active-active synchronization of multiple independent clusters: all bucket metadata, IAM configuration, object data, and notifications replicated bi-directionally.

```bash
mc admin replicate add site1/myminio site2/myminio site3/myminio
```

All sites must use the same identity provider. Site replication and bucket-level replication are mutually exclusive.

## ILM / Lifecycle

S3-compatible lifecycle API. Rules specify filter (prefix, tags, size), action (Expiration or Transition), and schedule (days from creation/modification).

Tiering: objects transitioned to warm/cold MinIO clusters or S3-compatible targets. Metadata remains on source.

## IAM and Policies

AWS IAM-compatible policy engine. Identity sources: built-in users, LDAP/AD, OIDC/JWT, STS. Service accounts with inline policies for least-privilege application access.

## Bucket Notifications

Targets: AMQP, Kafka, NATS, NSQ, MQTT, MySQL, PostgreSQL, Redis, Elasticsearch, Webhook. Async by default (100K queue); sync mode available. Persistent queue via `queue_dir`.

## Batch Operations

Server-side bulk operations via YAML: replicate (one-time migration), expire (bulk delete), keyrotate (rotate DEKs). `mc batch start/status/list`.

## MinIO Operator for Kubernetes

Tenant CRD for declarative MinIO cluster management. Auto-TLS via `certificates.k8s.io` API. Supports EKS, GKE, AKS, OpenShift.
