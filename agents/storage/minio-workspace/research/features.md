# MinIO Features

## Current State (April 2026)

MinIO's feature landscape changed significantly in early 2026. Understanding the current product split is essential before evaluating capabilities:

| Edition          | Status (April 2026)              | License       | Distribution                         |
|-----------------|----------------------------------|---------------|--------------------------------------|
| Community (OSS) | Archived Feb 13, 2026 (read-only)| AGPLv3        | Last release available on GitHub     |
| AIStor Free     | Active, supported                | Proprietary   | quay.io/minio/minio (AIStor builds)  |
| AIStor Enterprise| Active, supported               | Commercial    | Subscription (~$96K/year enterprise) |

The archived community repository remains available and functional for existing deployments, but receives no new features, security patches, or bug fixes from MinIO Inc.

---

## Timeline of Key Events

| Date          | Event                                                                            |
|---------------|----------------------------------------------------------------------------------|
| May 2021      | MinIO relicensed from Apache 2.0 to GNU AGPLv3                                   |
| May 2025      | Admin console (management GUI) removed from community edition                    |
| June 2025     | User administration, bucket management, policy config moved behind AIStor paywall|
| October 2025  | Binary and Docker distribution of community builds halted by MinIO Inc.          |
| December 2025 | Community repository entered maintenance mode                                    |
| February 12, 2026 | Repository marked "NO LONGER MAINTAINED"                                    |
| February 13, 2026 | `minio/minio` GitHub repository archived (read-only)                        |

---

## AGPL Licensing — What It Means

The AGPLv3 license (applied since May 2021) has specific network service implications that distinguish it from Apache 2.0:

- **AGPL network provision**: If you run modified MinIO as a network service, you must make your modified source code available to all users of that service.
- **Unmodified use**: Using unmodified MinIO as infrastructure (not distributing it as a product) generally does not trigger AGPL copyleft.
- **SaaS provider concern**: Cloud providers and SaaS companies building products on top of MinIO must carefully assess AGPL compliance; this was a key reason many moved to commercial licenses.
- **Fork rights**: The AGPLv3 code base remains forkable; community forks (e.g., from the archived repository) are being maintained by the open-source community.

---

## S3 API Compatibility

MinIO implements the Amazon S3 API with high fidelity, making it a drop-in replacement for workloads targeting AWS S3. Supported capabilities include:

### Core S3 Operations
- `CreateBucket`, `DeleteBucket`, `ListBuckets`, `HeadBucket`
- `PutObject`, `GetObject`, `HeadObject`, `DeleteObject`, `CopyObject`
- `ListObjectsV1`, `ListObjectsV2`, `ListObjectVersions`
- `CreateMultipartUpload`, `UploadPart`, `CompleteMultipartUpload`, `AbortMultipartUpload`

### Advanced S3 Features
- Presigned URLs (GET, PUT, DELETE with TTL)
- Server-side copy with metadata replacement
- Range requests (partial object retrieval)
- Conditional requests (If-Match, If-None-Match, If-Modified-Since)
- Object tagging
- Select (S3 Select subset — CSV/JSON/Parquet query pushdown)

---

## Object Versioning

Bucket versioning allows MinIO to retain multiple iterations of the same object. Once enabled on a bucket, it cannot be fully disabled — only suspended.

### Behavior

- Every write (PUT) creates a new version with a unique version ID (UUID).
- DELETE without a version ID creates a delete marker (logical deletion); all previous versions remain.
- DELETE with a specific version ID permanently removes that version.
- Listing with `ListObjectVersions` shows all versions and delete markers.

### Version States

| State     | Behavior                                                  |
|-----------|-----------------------------------------------------------|
| Enabled   | All writes create new versions                            |
| Suspended | New writes create `null` version; old versions preserved  |

### Storage Cost Consideration

All versions consume storage. Use ILM noncurrent-version expiration rules to automatically purge old versions:

```bash
mc ilm add myminio/mybucket \
  --noncurrentversion-expiration-days 30 \
  --newer-noncurrentversions 5
```

This keeps at most 5 non-current versions and expires any non-current version older than 30 days.

### Scanner Version Alerts

MinIO's background scanner emits events when a single object accumulates more than 100 versions (configurable threshold) or when version storage exceeds 1 TiB, alerting operators to runaway version accumulation.

---

## Object Locking and WORM

Object locking enforces Write-Once Read-Many (WORM) immutability. It must be enabled at bucket creation time and implicitly enables versioning.

### Retention Modes

| Mode       | Who Can Override                             | Use Case                          |
|------------|----------------------------------------------|-----------------------------------|
| COMPLIANCE | Nobody, including root — law enforcement use | SEC 17a-4, FINRA, HIPAA           |
| GOVERNANCE | Users with `s3:BypassGovernanceRetention`    | Internal policy, accidental delete|

### Retention Configuration

**Default bucket retention** — applied automatically to all new objects:
```bash
mc retention set --default COMPLIANCE "30d" myminio/mybucket
```

**Per-object retention** — set at upload time via headers:
```
x-amz-object-lock-mode: COMPLIANCE
x-amz-object-lock-retain-until-date: 2027-01-01T00:00:00Z
```

### Legal Hold

Legal hold is indefinite retention that overrides any configured expiration period:
```bash
mc legalhold set myminio/mybucket/evidence.zip
mc legalhold clear myminio/mybucket/evidence.zip
```

Legal hold must be explicitly cleared before the object can be deleted, regardless of retention period.

### WORM Interaction with ILM

ILM expiration rules cannot delete objects under active COMPLIANCE retention or legal hold. GOVERNANCE-mode objects can be expired if the caller has `BypassGovernanceRetention` permissions.

---

## Batch Operations

The MinIO Batch Framework allows server-side bulk operations using YAML job definitions. Jobs run entirely on the cluster, removing the client-to-cluster network from the critical path.

### Batch Job Types

| Job Type    | Description                                                  |
|-------------|--------------------------------------------------------------|
| `replicate` | Bulk replicate objects between MinIO deployments             |
| `expire`    | Bulk expire (delete) objects matching filter criteria         |
| `keyrotate` | Rotate encryption keys across all objects in a bucket        |

### Batch Replication

The replicate job supports one-time bulk migration or backfill, complementing continuous replication:

```yaml
replicate:
  apiVersion: v2
  source:
    type: minio
    bucket: source-bucket
    prefix:
      - "archive/"
      - "backups/2024/"
    credentials:
      accessKey: SOURCE_ACCESS_KEY
      secretKey: SOURCE_SECRET_KEY
  target:
    type: minio
    bucket: target-bucket
    endpoint: https://target.minio.example.com
    credentials:
      accessKey: TARGET_ACCESS_KEY
      secretKey: TARGET_SECRET_KEY
  flags:
    filter:
      newerThan: "24h"
    notifyAfter: 1000
```

Run via:
```bash
mc batch start myminio replicate-job.yaml
mc batch status myminio JOB_ID
mc batch list myminio
```

### Batch Replication Optimizations

- Objects smaller than 5 MiB are automatically batched and compressed for efficient transfer (since RELEASE.2023-12-09).
- Parallel workers configurable via `MINIO_BATCH_REPLICATION_WORKERS` environment variable.
- `apiVersion: v2` supports multiple source prefixes in a single job.

### Batch Expiry

```yaml
expire:
  apiVersion: v1
  bucket: mybucket
  prefix: "logs/2023/"
  rules:
    - created:
        before: "2024-01-01T00:00:00Z"
```

### Key Rotation

Rotates DEKs (data encryption keys) across all objects using the configured KMS, without re-encrypting data (only the encrypted DEK stored in metadata is updated):

```bash
mc batch start myminio keyrotate-job.yaml
```

---

## Server-Side Encryption

Three SSE modes are available, each with different key custody:

### SSE-S3 (MinIO-managed)
- MinIO generates and manages the master key internally.
- Single key encrypts all objects on the cluster.
- Zero configuration required beyond enabling encryption.

### SSE-KMS (External KMS via KES)
- MinIO integrates with KES, which proxies to an external KMS.
- Master keys stored and managed in the external KMS (Vault, AWS KMS, etc.).
- Supports per-bucket default keys: different buckets can use different KMS keys.
- Required for FIPS 140-2 compliance scenarios.
- Enables key rotation without re-encrypting data.

### SSE-C (Client-provided keys)
- Client supplies the encryption key in each request header.
- MinIO never stores the key; it is discarded after use.
- Client is responsible for key storage and management.

---

## Bucket Quotas

MinIO supports hard quotas on individual buckets to prevent any single bucket from consuming the entire cluster:

```bash
mc quota set myminio/mybucket --size 10TiB
mc quota info myminio/mybucket
mc quota clear myminio/mybucket
```

Quota enforcement is handled by the data scanner, which updates usage metrics periodically. Writes that would exceed the quota are rejected with an error.

---

## Multi-Protocol Access

Beyond S3, MinIO supports additional access protocols:

### NFS Gateway (deprecated in community, available in AIStor)
Exposes MinIO buckets as NFS mounts, enabling legacy workloads to read/write object storage without S3 libraries.

### HDFS-compatible Interface
MinIO integrates with Hadoop-compatible filesystems, supporting Spark, Hive, and Presto workloads that expect HDFS access patterns. Iceberg and Hudi table formats work natively with MinIO as the backing store.

---

## Performance Characteristics

Based on benchmarks from MinIO engineering and community testing (NVMe + 100 GbE):

| Operation | Per-Node Throughput (NVMe + 100 GbE) |
|-----------|--------------------------------------|
| GET       | ~10 GB/s                             |
| PUT       | ~5 GB/s                              |

These figures reflect ideal conditions. Real throughput depends on object size (larger objects benefit more), erasure coding overhead (N/2 parity has higher CPU cost than EC:2), network saturation, and drive IOPS for small objects.

MinIO is optimized for large object throughput (video, ML model checkpoints, backups). For small object workloads at high IOPS, specialized tuning is required (see best-practices.md).

---

## Notable Missing Features (Community Edition)

As of the February 2026 archival, the following were already removed from or never part of the community edition:

- Full web-based admin console (UI) — moved to AIStor in May 2025.
- SUBNET health reporting and proactive support diagnostics.
- AIStor-specific KES (community KES deprecated March 2025).
- Official binary and Docker image distribution (halted October 2025).
- Active security patches and bug fixes.

These remain available in AIStor Free or AIStor Enterprise.
