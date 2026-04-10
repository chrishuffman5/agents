# MinIO Architecture

## Overview

MinIO is a high-performance, S3-compatible object storage system written in Go. It was originally open-sourced under the Apache 2.0 license, later relicensed to GNU AGPLv3, and as of February 2026 the community edition repository was archived. Active development continues under the commercial AIStor product line. The architectural principles described here apply to both the archived community edition (last maintained release) and AIStor.

MinIO's design centers on running at wire speed — the hardware bottleneck (NVMe drives, 100 GbE network) should be the limit, not the software. It achieves this through Go's concurrency model, Intel AVX-512 SIMD for erasure coding, and a lean HTTP-to-storage request pipeline.

---

## Storage Hierarchy: Pools → Erasure Sets → Drives

MinIO organizes storage in a strict three-tier hierarchy:

```
Server Pools
  └── Erasure Sets (fixed-size drive groups)
        └── Physical Drives (local NVMe or remote via REST)
```

### Server Pools

A server pool is a set of MinIO server nodes that form a single, independently addressable namespace. Key properties:

- Each pool manages its own erasure sets and does not share drives with other pools.
- Pools can be added online to expand total cluster capacity without rebalancing existing data in prior pools. New writes go to the pool with the most available capacity.
- A deployment must have at least one pool; adding a second pool requires all existing pool nodes to be online.
- Pool expansion is the only officially supported horizontal scale-out path.

### Erasure Sets

Within each pool, MinIO groups drives into erasure sets. Each erasure set is a fixed-size collection of 4 to 16 drives (default). With the `MINIO_ERASURE_SET_DRIVE_COUNT` environment variable, AIStor Server RELEASE.2026-02-02 or later supports up to 32 drives per set.

- Object placement is determined by consistent hashing: `hash(object key) → erasure set index`. This distributes objects evenly without a central metadata catalog.
- The erasure set size is computed automatically at startup based on the total drives in the pool; it cannot be changed after deployment without a rebuild.
- Reads and writes target a single erasure set; there is no stripe across sets for a single object.

### Drives

Individual storage units. MinIO strongly recommends direct-attached NVMe drives. Remote drives are accessed via an internal Storage REST API, allowing MinIO to treat local and remote storage uniformly through the same interface.

---

## Erasure Coding

MinIO implements Reed-Solomon erasure coding at the erasure-set level.

### How It Works

For each write, the object is:
1. Split into `K` data shards (equal portions of the object data).
2. Computed into `M` parity shards (mathematical representations allowing data reconstruction).
3. Written in parallel to `K + M` drives in the erasure set.

Default: `K = M = N/2` where `N` is drives per erasure set. With 16 drives: 8 data + 8 parity shards. The cluster can survive loss of up to `M` drives simultaneously and still read or write objects.

### Quorum Rules

| Operation | Minimum drives required |
|-----------|------------------------|
| Write     | (N/2) + 1              |
| Read      | N/2                    |

A 16-drive set needs 9 drives for writes and 8 for reads. This asymmetry means reads remain available longer under drive failures than writes.

### Block and Shard Sizes

- Default block size: 1 MiB per erasure operation.
- Shard size: `block_size / K` data shards.
- Large objects are processed in sequential 1 MiB blocks; each block is independently erasure coded.

### AVX-512 Acceleration

MinIO uses Intel AVX-512 SIMD instructions (and AVX2 fallback) to perform Galois Field arithmetic for Reed-Solomon computation in parallel, enabling near wire-speed erasure coding on modern CPUs.

### Inline Erasure Coding

There is no separate RAID layer. Erasure coding is performed inline in the write path — data never touches disk without being sharded and checksummed first.

---

## Bitrot Protection (Silent Corruption Detection)

Every shard written to disk is checksummed using HighwayHash-256 (a fast, hardware-accelerated hash function).

- The checksum is stored in the `xl.meta` metadata file alongside the shard.
- On every read, MinIO verifies the checksum of each shard before returning data.
- If a shard fails checksum verification (bitrot), MinIO reconstructs it from the remaining parity shards automatically and serves the correct data.
- Background healing (see below) also scans for and repairs corrupted shards proactively.

This provides defense against silent data corruption from aging drives, firmware bugs, or memory errors — without relying on the filesystem.

---

## On-Disk Object Layout

Each object version is stored as a directory on each drive in the erasure set:

```
<data-dir>/
  <bucket>/
    <object-key>/
      xl.meta          ← metadata (all versions, EC config, checksums)
      <version-id>/
        part.1         ← shard 1 (data or parity)
        part.2
        ...
        part.N
```

The `xl.meta` file is a self-describing binary file (MessagePack encoded) replicated on every drive in the erasure set. It contains:
- Object size, content type, ETag, last modified timestamp.
- Erasure configuration: number of data/parity blocks, drive distribution.
- Per-shard checksums for bitrot detection.
- Version history (when versioning is enabled).
- User-defined metadata and tags.

Reading `xl.meta` from a quorum of drives (N/2) allows the server to reconstruct which version is current and where shards live.

---

## Request Processing Pipeline

```
Client HTTP/S Request
  → TLS Termination
  → Authentication (IAM check)
  → Middleware (logging, metrics, rate limiting)
  → S3 API Handler (GetObject, PutObject, etc.) or Admin Handler
  → ObjectLayer interface (abstraction over storage backend)
  → ErasurePoolsObjects (multi-pool routing by consistent hash)
  → ErasureObjects (single set, parallel I/O)
  → Physical drives (local filesystem or Storage REST for remote)
```

The `ObjectLayer` interface allows MinIO to support multiple backends (single-node FS, single erasure set, distributed multi-pool) behind the same S3 API surface.

---

## Internode Communication

In a distributed deployment, MinIO nodes communicate over several internal protocols:

| Protocol     | Purpose                                              |
|-------------|------------------------------------------------------|
| Storage REST | Remote disk read/write/stat operations               |
| Peer REST    | Cluster config sync, lifecycle, IAM propagation      |
| Lock REST    | Distributed locking using the dsync protocol         |
| Grid RPC     | High-performance binary RPC for internal coordination|

All internode traffic can be encrypted using TLS. Distributed locking via dsync provides strong consistency for concurrent operations against the same object.

---

## Background Services

### Data Scanner

A background goroutine that periodically crawls all objects to:
- Verify shard checksums (bitrot detection).
- Update per-bucket usage metrics and quota enforcement.
- Enforce ILM expiration and transition rules.
- Detect objects needing healing and enqueue them.

Scan frequency and throttle are configurable to avoid impacting foreground I/O.

### Healing System

The `healingTracker` manages repair of degraded objects:
- Triggered automatically when a drive rejoins after failure.
- Reads surviving shards, recomputes missing/corrupted shards, writes repaired data.
- Runs with configurable concurrency to balance throughput vs. I/O impact.
- `mc admin heal` can trigger or monitor manual healing scans.

Healing is prioritized: objects with the fewest remaining valid shards (closest to read quorum loss) are healed first.

---

## MinIO Client (mc)

`mc` is the official command-line client for managing MinIO and S3-compatible deployments. It provides UNIX-style commands extended for object storage:

### Core Operations
```bash
mc alias set myminio https://minio.example.com ACCESS_KEY SECRET_KEY
mc ls myminio/mybucket
mc cp localfile.txt myminio/mybucket/
mc mirror ./local-dir myminio/mybucket
mc rm myminio/mybucket/object.txt
mc mb myminio/newbucket
```

### Admin Commands
```bash
mc admin info myminio               # Cluster and drive status
mc admin service restart myminio    # Rolling restart
mc admin config get myminio         # Dump server config
mc admin user list myminio          # List IAM users
mc admin policy list myminio        # List IAM policies
mc admin heal myminio               # Trigger healing scan
mc support perf myminio             # Performance diagnostics
mc support diag myminio             # Full diagnostics bundle
```

### Policy and Lifecycle
```bash
mc anonymous set download myminio/public-bucket
mc ilm add --expiry-days 30 myminio/mybucket
mc event add myminio/mybucket arn:... --event put,get,delete
```

---

## KES — Key Encryption Service

KES is MinIO's purpose-built key management microservice for managing encryption keys at scale in cloud-native environments.

### Role

KES sits between MinIO (client) and an external KMS (HashiCorp Vault, AWS KMS, Azure Key Vault, GCP KMS, Thales, etc.), acting as a stateless, horizontally scalable proxy for key operations:

```
MinIO Server → KES (stateless, replicated) → External KMS
```

### Authentication

KES uses mutual TLS (mTLS) for all client-server communication. Both MinIO and KES present x.509 certificates; the identity is derived from the certificate fingerprint. There are no passwords or shared secrets.

### Key Operations

- `CreateKey` — generates a new data encryption key (DEK) under a named key in the KMS.
- `GenerateKey` — returns a plaintext DEK + ciphertext (DEK encrypted with master key in KMS). MinIO stores only the ciphertext; the KMS holds master keys.
- `DecryptKey` — decrypts a stored ciphertext DEK using the KMS master key for read operations.

### Server-Side Encryption Modes

| Mode    | Key Management                         | Use Case                          |
|---------|----------------------------------------|-----------------------------------|
| SSE-S3  | MinIO-managed, single cluster key      | Simple encryption at rest         |
| SSE-KMS | KES + external KMS, per-bucket/object  | Compliance, key rotation, audits  |
| SSE-C   | Client-provided key per request        | Client controls all keys          |

Note: The community KES repository was deprecated and archived in March 2025. AIStor KES continues as the maintained version.

---

## Bucket Notifications

MinIO can publish events for object operations to external messaging and database systems.

### Supported Targets

- **Message queues**: AMQP (RabbitMQ), Apache Kafka, NATS, NSQ, MQTT
- **Databases**: MySQL, PostgreSQL, Redis
- **Search**: Elasticsearch
- **HTTP**: Webhook (any HTTP endpoint)

### Event Types

- Object lifecycle: `s3:ObjectCreated:*`, `s3:ObjectRemoved:*`, `s3:ObjectAccessed:*`
- Replication: `s3:Replication:OperationCompletedReplication`, `s3:Replication:OperationFailedReplication`
- ILM/lifecycle: `s3:LifecycleExpiration:*`, `s3:ObjectTransition:*`
- Scanner alerts: excessive versions, large prefix subfolder counts

### Configuration Pattern

```bash
# 1. Configure the notification target on the server
mc admin config set myminio notify_kafka:1 \
  brokers="kafka:9092" topic="minio-events" tls=off

# 2. Restart to apply
mc admin service restart myminio

# 3. Subscribe bucket events to the target
mc event add myminio/mybucket \
  arn:minio:sqs::1:kafka \
  --event put,delete --prefix images/ --suffix .jpg
```

### Delivery Semantics

- Default mode: **asynchronous** — events are queued (up to 100,000 per target) and sent without blocking object operations.
- Synchronous mode: enabled via `MINIO_API_SYNC_EVENTS=on`. MinIO waits for event delivery acknowledgment before returning success to the client.
- Persistent queue via `queue_dir` backs up events to disk if the target is offline; events are replayed on reconnect.

---

## Information Lifecycle Management (ILM) / Lifecycle Policies

ILM automates data management through expiration and tiering rules, compatible with the S3 lifecycle API.

### Rule Components

Each lifecycle rule specifies:
- **Filter**: prefix, object tags, or size range to scope the rule.
- **Action**: `Expiration` (delete after N days) or `Transition` (move to a tiered target).
- **Schedule**: expressed in days from object creation or last modified date.

### Expiration

```bash
# Expire objects in prefix "logs/" older than 90 days
mc ilm add myminio/mybucket \
  --prefix "logs/" \
  --expiry-days 90

# Expire non-current versions after 30 days (versioned buckets)
mc ilm add myminio/mybucket \
  --noncurrentversion-expiration-days 30
```

### Tiering / Transition

Objects can be transitioned to a "warm" or "cold" tier — another MinIO cluster or S3-compatible target — to reduce primary storage costs. The object metadata remains on the source; retrieval triggers a restore from the tier.

```bash
mc ilm tier add minio WARM-TIER \
  --endpoint https://warm.storage.example.com \
  --access-key ... --secret-key ... --bucket archive-bucket

mc ilm add myminio/mybucket \
  --transition-days 60 --transition-tier WARM-TIER
```

### Data Scanner Integration

The background data scanner enforces ILM rules by scanning objects for matching conditions and scheduling deletion or transition. Scan interval is configurable.

---

## IAM and Policies

MinIO implements an AWS IAM-compatible policy engine.

### Identity Sources

| Source          | Description                                       |
|----------------|---------------------------------------------------|
| Built-in users  | Access key + secret managed directly in MinIO     |
| LDAP/Active Directory | Group-based policy assignment              |
| OIDC/JWT       | Federated SSO (Okta, Keycloak, Dex, etc.)         |
| STS            | Temporary credentials via AssumeRole, WebIdentity |

### Policy Syntax

MinIO uses the same JSON policy syntax as AWS IAM:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject"],
    "Resource": ["arn:aws:s3:::mybucket/*"],
    "Condition": {
      "StringEquals": {"s3:prefix": ["data/"]}
    }
  }]
}
```

### Built-in Policies

- `readwrite` — full S3 operations on all buckets.
- `readonly` — read-only access to all buckets.
- `writeonly` — write-only access to all buckets.
- `consoleAdmin` — full admin access including console and config.
- `diagnostics` — read-only diagnostics and support operations.

### Service Accounts

Service accounts (access key pairs) are scoped credentials derived from a parent user, with an optional inline policy that further restricts permissions below the parent policy. Used for application-level least-privilege access.

---

## Site Replication

Site replication synchronizes multiple independent MinIO clusters so they behave as a single logical deployment from an IAM and data perspective.

### What Gets Replicated

- All bucket metadata: creation, deletion, versioning config, lifecycle rules, encryption config, quota settings.
- All IAM configuration: users, groups, policies, policy mappings, STS credentials (except root-owned access keys).
- All object data and versions (bi-directionally).
- Bucket notifications configuration.

### Consistency Model

Site replication is **active-active**: writes can go to any site, and changes propagate to all peers. This provides geographic load distribution and zero-RPO disaster recovery if replication is current.

### Setup

```bash
# Register all sites together (run once)
mc admin replicate add \
  site1/myminio-us-east \
  site2/myminio-us-west \
  site3/myminio-eu-central
```

All sites must use the same identity provider (built-in, LDAP, or OIDC). Site replication and bucket-level replication are mutually exclusive — choose one.

### Constraints

- All participating sites must be reachable and online during the initial setup.
- Removing a site from replication requires manual intervention and data reconciliation.
- Network bandwidth between sites must be sufficient to keep replication lag low; MinIO provides metrics for replication latency.

---

## MinIO Operator for Kubernetes

The MinIO Operator extends Kubernetes with a `Tenant` custom resource definition (CRD) for declarative management of MinIO clusters on Kubernetes.

### Components

| Component         | Role                                                    |
|------------------|---------------------------------------------------------|
| Operator Pod      | Watches `Tenant` CRDs, reconciles desired state         |
| Tenant            | A MinIO cluster instance (pools, drives, TLS, users)    |
| Console Service   | Kubernetes Service exposing the MinIO console           |
| MinIO Service     | Kubernetes Service exposing the S3 API                  |

### Tenant CRD Example (simplified)

```yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: myminio
  namespace: minio-tenant
spec:
  image: quay.io/minio/minio:latest
  pools:
    - name: pool-0
      servers: 4
      volumesPerServer: 4
      volumeClaimTemplate:
        spec:
          storageClassName: local-nvme
          resources:
            requests:
              storage: 1Ti
  requestAutoCert: true
  env:
    - name: MINIO_ROOT_USER
      valueFrom:
        secretKeyRef:
          name: myminio-creds
          key: rootUser
```

### TLS in Kubernetes

The Operator integrates with the Kubernetes `certificates.k8s.io` API to automatically generate and rotate TLS certificates for all MinIO Pods and Services, including correct Subject Alternative Names (SANs) for pod DNS names.

### Operator Helm Chart

```bash
helm repo add minio-operator https://operator.min.io
helm install minio-operator minio-operator/operator \
  --namespace minio-operator --create-namespace
```

### Hybrid and Multi-Cloud Support

The Operator supports deploying MinIO Tenants across private data centers, public cloud Kubernetes services (EKS, GKE, AKS), and OpenShift, enabling hybrid cloud object storage with a consistent management interface.
