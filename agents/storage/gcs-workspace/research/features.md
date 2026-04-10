# Google Cloud Storage: Features & Capabilities

## Core Capabilities

| Capability | Detail |
|------------|--------|
| Max object size | 5 TiB |
| Max buckets per project | Soft limit; large counts may require quota increase |
| Durability | 99.999999999% (11 nines) annual |
| Access latency | Single-digit milliseconds for all storage classes |
| API types | JSON REST API, XML (S3-compatible) API |
| Auth methods | OAuth 2.0, service account keys, HMAC keys, workload identity |
| Encryption at rest | AES-256 by default; CMEK (Customer-Managed Encryption Keys) and CSEK (Customer-Supplied) available |

---

## Storage Classes

| Class | API Name | Min Duration | Retrieval Fee | Best For |
|-------|----------|-------------|---------------|----------|
| Rapid | `RAPID` | None | None | AI/ML, analytics (zonal buckets) |
| Standard | `STANDARD` | None | None | Hot data, streaming, web serving |
| Nearline | `NEARLINE` | 30 days | Yes | Monthly backups, long-tail media |
| Coldline | `COLDLINE` | 90 days | Yes (higher) | Quarterly DR archives |
| Archive | `ARCHIVE` | 365 days | Yes (highest) | Annual/compliance archives |

---

## Autoclass Automatic Tiering

Autoclass moves each object independently between storage classes based on access patterns. No per-object rules to configure.

- Objects start in Standard on upload.
- Cold path: 30d no access → Nearline; optionally continues to Coldline (90d) → Archive (365d).
- Warm path: Any `GET` read → immediately returns object to Standard.
- Objects under 128 KiB are permanently kept in Standard.
- No retrieval fees or early deletion fees within Autoclass.
- Supported on buckets with Hierarchical Namespace enabled (as of 2025).

---

## Hierarchical Namespace (HNS)

Enables true directory semantics on a GCS bucket:
- Atomic rename/move of directories and their contents.
- Up to 8x higher initial QPS compared to flat-namespace buckets.
- Compatible with Autoclass, lifecycle management, and IAM Conditions.
- Useful for data lake and analytics workloads where directory structure matters.

---

## Object Versioning

- Maintains a full history of all writes to each object name.
- Each version is identified by a unique generation number.
- Deleting a live object creates a noncurrent version (soft delete semantics at object name level).
- Use lifecycle rules with `numNewerVersions` or `isLive: false` to automatically purge old versions and control storage costs.

---

## Soft Delete

- When enabled, deleted objects are retained for a configurable period (default 7 days) before permanent removal.
- Objects can be restored within the retention window.
- Enhanced restoration (January 2026): restore soft-deleted objects based on their creation time.
- Provides a safety net against accidental deletion, scripting errors, and ransomware.

---

## Retention Policies and Object Holds

- **Retention policy**: Bucket-level; prevents deletion/modification of any object until the retention period (in seconds) expires.
- **Locked retention policy**: Cannot be reduced or removed; only extended. Required for WORM compliance (SEC Rule 17a-4, FINRA, HIPAA).
- **Event-based hold**: Individual object hold; must be released explicitly before the object can be deleted.
- **Temporary hold**: Individual object hold; released when no longer needed (e.g., during litigation).

---

## Lifecycle Management

Automated rules to transition or delete objects based on conditions:
- **Actions**: Delete, SetStorageClass, AbortIncompleteMultipartUpload.
- **Conditions**: age, createdBefore, isLive, numNewerVersions, matchesStorageClass, matchesPrefix/matchesSuffix.
- Age-0 condition behavior updated October 31, 2025: condition satisfied at midnight UTC after object creation (reduces unintended deletions).
- Up to 1,000 combined prefix/suffix filters across all rules in a bucket.

---

## Pub/Sub Notifications

Emit events to Cloud Pub/Sub topics on bucket changes:
- **Event types**: `OBJECT_FINALIZE`, `OBJECT_METADATA_UPDATE`, `OBJECT_DELETE`, `OBJECT_ARCHIVE`.
- Up to 100 notification configurations per bucket.
- Filter by object name prefix.
- Payload: full JSON API object metadata or event-type-only.
- **Object change notification** (legacy) deprecated January 30, 2026. Use Pub/Sub notifications instead.

---

## Compose Objects

Assemble up to 32 source objects into one destination object in a single atomic API call:
- No data re-upload; pure server-side concatenation.
- Useful for parallel uploads: split large files into shards, upload concurrently, compose into final object.
- Resulting object can itself be a component in further compose calls (up to 1,024 parts total via chained compose).
- Available in both JSON API (`compose` method) and XML API (`?compose` query parameter).

---

## Encryption Options

| Type | Description |
|------|-------------|
| Google-managed keys | Default AES-256; zero configuration needed |
| Customer-Managed Encryption Keys (CMEK) | Keys stored in Cloud KMS; you control key rotation and lifecycle |
| Customer-Supplied Encryption Keys (CSEK) | You provide the raw key with each request; Google never stores it |
| Dual-layer encryption | Adds a second layer of encryption at the data layer |
| Encryption type enforcement | As of April 2, 2026, admins can restrict which encryption types are allowed per bucket |

---

## Access Control Features

- **Uniform bucket-level access**: IAM-only, disables ACLs. Enables managed folders, IAM Conditions, VPC Service Controls.
- **Fine-grained access**: IAM + per-object ACLs (legacy; S3-compatible).
- **IAM Conditions**: Attribute-based conditions (prefix, time, IP, etc.).
- **Managed folders**: Apply IAM policies to a folder prefix; works with uniform access + HNS.
- **Public Access Prevention**: org/project policy blocks `allUsers`/`allAuthenticatedUsers`.
- **Bucket IP Filtering**: Restrict requests based on client IP.
- **VPC Service Controls**: Restrict GCS access to traffic from within a VPC Service Control perimeter.
- **Credential Access Boundaries**: Downscope OAuth tokens to specific buckets/objects.
- **Signed URLs**: Time-limited, pre-authenticated access for unauthenticated users.
- **Signed Policy Documents**: Control acceptable upload parameters (size, content type, metadata).

---

## Signed URLs

- V4 signing (recommended): HMAC-SHA256, max 7-day expiration.
- V2 signing (legacy): RSA-SHA256.
- Sign using service account private key or IAM `signBlob` API (no key download needed).
- Supports GET (read), PUT (upload), DELETE operations.
- Query parameter or header-based auth.

---

## HMAC Keys

- S3-compatible authentication for XML API.
- Associated with service accounts or user accounts.
- Access ID is public; Secret shown only at creation (store securely immediately).
- States: `ACTIVE`, `INACTIVE`. Must be `INACTIVE` before deletion.
- Org-level restriction via `constraints/storage.restrictAuthTypes`.

---

## Storage Transfer Service

Managed data transfer service for large-scale migrations and ongoing syncs:

### Sources Supported
- Amazon S3
- Azure Blob Storage / Azure Data Lake Storage Gen2
- HTTP/HTTPS URL lists
- On-premises / other cloud via Storage Transfer agents (software agents installed locally)
- Between GCS buckets (cross-project, cross-region)
- Google-managed sources (e.g., BigQuery exports)

### Key Features
- Scheduled or one-time transfer jobs.
- Filter by object prefix, creation time, last-modification time.
- Overwrite, delete-from-source, delete-from-destination options.
- Bandwidth throttling configuration.
- Transfer job splitting: split a job into multiple jobs to work around per-job QPS limits (relevant for many small files).
- Integrity verification: checksums validated end-to-end.
- Notifications via Pub/Sub on job completion.

---

## Batch Operations

Server-side batch processing on large object sets:
- Supported operations: delete, copy, rewrite storage class, replace ACL, replace metadata, restore soft-deleted objects, invoke a Cloud Function or Cloud Run function per object.
- **Dry run mode** (GA January 16, 2026): Simulate a batch operation without modifying data.
- Object Contexts support batch operations (GA April 6, 2026).

---

## Storage Insights

Inventory and analytics feature for large-scale bucket analysis:
- Snapshot-based inventory reports stored in BigQuery.
- New metadata fields added March 31, 2026: `encryption`, `retentionPeriod`, `encryptionType`, `retentionExpirationTime` — supporting security auditing and compliance monitoring.
- Use for identifying unused objects, analyzing storage class distribution, audit reporting.

---

## Monitoring and Observability

- **Cloud Monitoring**: Built-in metrics dashboard per bucket and project-wide.
- **Key metrics**: `storage.googleapis.com/api/request_count`, error rates (4xx, 5xx), data ingress/egress, storage usage.
- **Cloud Audit Logs**: Admin Activity logs (free) and Data Access logs (chargeable) capture all control plane and data plane operations.
- **RPO metrics**: For multi-region and dual-region buckets, track replication health and lag.
- **Cross-bucket replication monitoring**: Object replication rates and latency.

---

## CLI Tools

### gcloud storage (Recommended)
The modern GCS CLI, part of the Google Cloud SDK. Preferred over gsutil for new workflows.

```bash
# Create bucket
gcloud storage buckets create gs://my-bucket --location=us-central1 --default-storage-class=STANDARD

# Upload object
gcloud storage cp local-file.txt gs://my-bucket/

# Enable versioning
gcloud storage buckets update gs://my-bucket --versioning

# Enable Turbo Replication (dual-region)
gcloud storage buckets update gs://my-bucket --rpo=ASYNC_TURBO

# Enable Autoclass with Archive terminal class
gcloud storage buckets update gs://my-bucket --enable-autoclass --autoclass-terminal-storage-class=ARCHIVE

# List with verbose logging for debugging
gcloud storage ls gs://my-bucket --log-http --verbosity=debug

# Set regional endpoint
gcloud config set api_endpoint_overrides/storage https://storage.us-central1.rep.googleapis.com/
```

### gsutil (Legacy, Still Supported)
The original GCS CLI. Largely superseded by `gcloud storage` but still functional. Many existing scripts use gsutil.

```bash
# Upload
gsutil cp local-file.txt gs://my-bucket/

# Parallel composite upload (splits into components and uploads in parallel)
gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp large-file.zip gs://my-bucket/

# Set lifecycle policy from JSON file
gsutil lifecycle set lifecycle.json gs://my-bucket

# Sync directory
gsutil -m rsync -r local-dir/ gs://my-bucket/prefix/
```

### Key Differences
| Feature | gcloud storage | gsutil |
|---------|---------------|--------|
| Performance | Faster (Go-based) | Python-based |
| Maintenance | Actively developed | Maintenance mode |
| Parallel uploads | Default behavior | Requires flags |
| Recommended for | New workflows | Legacy scripts |

---

## Recent Features (2025–2026)

| Date | Feature | Notes |
|------|---------|-------|
| April 8, 2026 | Multi-object deletion (XML API) | Delete up to 1,000 objects per request; S3-compatible |
| April 6, 2026 | Object Contexts GA | Key-value pairs on objects; batch operations support |
| April 2, 2026 | Encryption type enforcement | Admins can restrict allowed encryption types per bucket |
| March 10, 2026 | Rapid storage class GA | Zonal buckets for AI/ML; high-throughput, low-latency |
| March 31, 2026 | Storage Insights new fields | encryption, retentionPeriod fields for compliance auditing |
| January 20, 2026 | Bangkok region | `asia-southeast3` added |
| January 16, 2026 | Batch Operations dry run | Simulate without modifying data |
| January 15, 2026 | Soft-delete restoration by creation time | Enhanced recovery options |
| January 30, 2026 | Object change notification deprecated | Migrate to Pub/Sub notifications |
| October 31, 2025 | Age-0 lifecycle behavior change | Condition satisfied at midnight UTC after creation |
| 2025 | Autoclass supports HNS buckets | Autoclass + hierarchical namespace now compatible |
