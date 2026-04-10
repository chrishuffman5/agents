# Google Cloud Storage: Architecture

## Overview

Google Cloud Storage (GCS) is a globally unified, scalable object storage service. All data is organized into **buckets** containing **objects**, with projects as the top-level organizational unit. Buckets cannot be nested; hierarchy is simulated using `/` delimiters in object names or via Hierarchical Namespace (HNS).

---

## Buckets

A bucket is the fundamental container for objects. Key properties:

- **Global namespace**: Every bucket name is globally unique across all GCP customers.
- **Immutable creation location**: Location cannot be changed after creation.
- **No nesting**: Buckets cannot contain other buckets.
- **Project association**: Every bucket belongs to exactly one GCP project.
- **Metadata**: Includes default storage class, location, versioning state, lifecycle rules, IAM policy, labels, retention policy, and Pub/Sub notification configs.

### Bucket Creation Rate
Approximately one create/delete operation per two seconds per project. Plan bulk bucket creation accordingly.

### Hierarchical Namespace (HNS)
Enabling HNS on a bucket allows true directory semantics (rename, atomic move). HNS buckets also offer up to 8x higher initial QPS compared to flat-namespace buckets. Autoclass is supported on HNS buckets (as of 2025).

---

## Objects

An object consists of:
- **Object data**: The file content (up to 5 TiB per object).
- **Object metadata**: Key-value pairs stored with the object. System metadata (Content-Type, Cache-Control, etc.) and custom metadata (up to 8 KiB total).
- **Object name**: Up to 1,024 bytes in flat namespace; 512 bytes per path component in HNS.
- **Immutability**: Objects are immutable. Updates create new versions (or replace in-place if versioning is disabled).

### Object Contexts (GA April 2026)
Attach key-value pairs to objects for categorization, search, and batch operations. Distinct from object metadata.

### Compose Objects
Up to 32 existing objects in the same bucket can be combined into a new object via a single API call. The result is the byte-concatenation of component objects. No data re-upload is required.

- **JSON API**: `POST /storage/v1/b/{bucket}/o/{destinationObject}/compose`
- **XML API**: `PUT /{bucket}/{object}?compose`

Useful for parallel uploads: upload shards simultaneously, then compose into a final object.

---

## Storage Classes

Storage class is metadata on every object controlling pricing, availability SLA, minimum storage duration, and retrieval fees. Set at bucket level as a default; override per object.

### Rapid Storage (`RAPID`) — GA March 2026
- **Use case**: AI/ML training, data analytics, I/O-intensive workloads.
- **Architecture**: Zonal buckets only (single zone, lower latency, higher throughput).
- **Availability SLA**: 99.9% (zone-level).
- **Minimum storage duration**: None.
- **Retrieval fees**: None.
- **Storage quotas**: Subject to zonal storage size quotas (default 1 TB per project per zone, requestable).
- **Egress quota**: Up to 1 Tbps to Google services per project per zone.

### Standard Storage (`STANDARD`)
- **Use case**: Frequently accessed ("hot") data, streaming, web serving, real-time analytics.
- **Availability SLA**: 99.95% (multi-region/dual-region), 99.9% (regional).
- **Minimum storage duration**: None.
- **Retrieval fees**: None.
- **Default class** when no class is specified.

### Nearline Storage (`NEARLINE`)
- **Use case**: Data accessed roughly once per month. Backups, long-tail media.
- **Availability SLA**: 99.9% (multi-region/dual-region), 99.0% (regional).
- **Minimum storage duration**: 30 days (early deletion billed for remainder).
- **Retrieval fees**: Per-GB retrieval charge applies.

### Coldline Storage (`COLDLINE`)
- **Use case**: Disaster recovery data, accessed at most quarterly.
- **Availability SLA**: 99.9% (multi-region/dual-region), 99.0% (regional).
- **Minimum storage duration**: 90 days.
- **Retrieval fees**: Per-GB retrieval charge (higher than Nearline).

### Archive Storage (`ARCHIVE`)
- **Use case**: Legal/regulatory archives, long-term backups, accessed less than once per year.
- **Availability SLA**: 99.9% (multi-region/dual-region), 99.0% (regional).
- **Minimum storage duration**: 365 days.
- **Retrieval fees**: Per-GB retrieval charge (highest tier).
- **Access latency**: Milliseconds (no thaw delay, unlike some competitors).

### Durability (All Classes)
All storage classes provide 99.999999999% (eleven 9s) annual durability.

---

## Autoclass

Autoclass automatically transitions each object between storage classes based on its individual access pattern, eliminating the need to predict access frequency upfront.

### How It Works
1. All objects entering the bucket start in Standard storage (regardless of upload-specified class).
2. If an object is not accessed for 30 days, it transitions to Nearline.
3. With Archive as the terminal class, transitions continue: 90 days → Coldline, 365 days → Archive.
4. Any `GET` object read returns the object to Standard storage.

### Key Constraints
- Objects smaller than 128 KiB stay permanently in Standard.
- No retrieval fees or early deletion fees within Autoclass (except as part of enablement charges).
- A per-object management fee applies.
- Operations billed at Standard rates.
- No Class A charge when Autoclass moves an object from Nearline back to Standard.

### Terminal Storage Class Options
| Terminal Class | Transition Path |
|---------------|-----------------|
| `NEARLINE` (default) | Standard → Nearline (30 days) |
| `ARCHIVE` | Standard → Nearline (30d) → Coldline (90d) → Archive (365d) |

Changing from Archive to Nearline immediately promotes Archive/Coldline objects to Nearline.

### When to Use Autoclass
- Data with unpredictable or variable access patterns.
- Mixed "hot/cold" object datasets in a single bucket.
- When you want cost optimization without manual lifecycle rule management.

### When Not to Use Autoclass
- Buckets scanned regularly by services (e.g., Sensitive Data Protection) — every scan resets the countdown to Standard.
- Known uniform access patterns where a fixed storage class is more cost-effective.

---

## Bucket Locations

### Regional
- Single geographic region (e.g., `us-central1`, `europe-west1`).
- Data stored redundantly across multiple zones within the region.
- Best for: workloads in a specific region, lowest latency for co-located compute.

### Dual-Region
- Two specific paired regions (e.g., `nam4` = us-central1 + us-east1).
- **Default replication RPO**: 1 hour for 99.9% of objects, 12 hours for 100%.
- **Turbo Replication** (premium): SLA-backed 15-minute RPO for 100% of newly written objects. Enabled via `--rpo=ASYNC_TURBO`.
- Best for: compliance, business continuity across two regions.

### Multi-Region
- Broad geographic area (e.g., `US`, `EU`, `ASIA`).
- Automatic geo-redundancy; Google chooses which regions store data.
- 99.95% availability SLA.
- Best for: globally distributed applications, CDN-like access patterns.

### Bangkok Region (January 2026)
Cloud Storage expanded availability to `asia-southeast3` (Bangkok, Thailand).

---

## Lifecycle Management

Object Lifecycle Management (OLM) applies rules to automatically change or delete objects meeting specified conditions.

### Rule Structure
Each rule has:
- **One action**: `Delete`, `SetStorageClass`, or `AbortIncompleteMultipartUpload`.
- **One or more conditions**: All conditions must match for the action to trigger.

### Conditions
| Condition | Description |
|-----------|-------------|
| `age` | Days since object creation. Age 0 = satisfied at midnight UTC after creation (as of Oct 31, 2025). |
| `createdBefore` | Objects created before a UTC date. |
| `isLive` | Targets live (`true`) or noncurrent (`false`) versions. |
| `numNewerVersions` | Keep only N newer versions of noncurrent objects. |
| `matchesStorageClass` | Matches objects in specific storage classes. |
| `matchesPrefix` / `matchesSuffix` | Up to 1,000 combined prefix/suffix conditions across all rules. |

### Actions
- **Delete**: Removes objects (soft-delete retains for 7 days by default if enabled). Respects retention policies.
- **SetStorageClass**: Transitions to a colder class without re-uploading or incurring retrieval fees.
- **AbortIncompleteMultipartUpload**: Cleans up stale uploads. Supports `age`, `matchesPrefix`, `matchesSuffix` only.

### Important Behavior
- Actions execute asynchronously — do not rely on exact timing.
- In versioned buckets, `Delete` on a live object creates a noncurrent version; only explicit noncurrent deletion removes data.
- Lifecycle rules and retention policies interact: the later deadline wins.

---

## Object Versioning

When enabled on a bucket, each write to an existing object name preserves the previous version as a **noncurrent** version with a unique generation number.

- **Live object**: Current version, addressed by name alone.
- **Noncurrent object**: Addressed by name + generation number.
- Deleting a live object without specifying a generation inserts a **delete marker**, making the previous version the live version.
- Storage costs accrue for all versions; use lifecycle rules with `numNewerVersions` or `isLive: false` to manage noncurrent version accumulation.

---

## Retention Policies

A retention policy on a bucket prevents object deletion or replacement until the retention period expires. Used for regulatory compliance and data governance.

- **Retention period**: Specified in seconds. Applies to all current and future objects.
- **Locked retention policy**: A locked policy cannot be removed or shortened (only extended). Use to enforce immutability for compliance (e.g., SEC 17a-4, FINRA).
- **Interaction with lifecycle rules**: The object is not deleted until both the lifecycle age condition AND the retention period are satisfied.
- **Object holds**: Individual objects can be placed under an event-based hold or temporary hold, preventing deletion/modification regardless of retention policy.

---

## Signed URLs

Signed URLs grant time-limited read or write access to a specific object via a URL, without requiring the requester to have a Google account.

- **Signing methods**: Service account key (V4 signing recommended), or use IAM's `signBlob` API.
- **Expiration**: Maximum 7 days for V4 signed URLs.
- **Use cases**: Allowing end-users to upload directly to GCS, sharing private objects temporarily.
- **Security risk**: Anyone who has the URL can access the resource until expiration or key rotation. Mitigate with short expiry windows.
- **Organization policy**: `constraints/storage.restrictAuthTypes` can restrict or block HMAC-signed requests at org/project level.

---

## IAM and ACLs

### IAM (Recommended)
GCS integrates with Cloud IAM for access control. IAM grants can be at project level or bucket level.

Key predefined roles:
| Role | Capabilities |
|------|-------------|
| `roles/storage.admin` | Full control of buckets and objects. |
| `roles/storage.objectAdmin` | Full control of objects only. |
| `roles/storage.objectCreator` | Create objects (no read/list). |
| `roles/storage.objectViewer` | Read objects and metadata. |
| `roles/storage.legacyBucketOwner` | Read/write bucket metadata + objects. |

**Uniform bucket-level access**: Disables ACLs; enforces IAM-only. Recommended. Enables IAM Conditions, managed folders, VPC Service Controls. Irreversible after 90 days.

IAM Conditions allow attribute-based access control (e.g., restrict to specific object prefixes, time-of-day, IP ranges).

### ACLs (Legacy)
Per-object permission system inherited from S3 compatibility. Only used with fine-grained access mode.
- Max 100 ACL entries per object.
- Predefined ACLs: `publicRead`, `private`, `projectPrivate`, `bucketOwnerRead`, `bucketOwnerFullControl`, `authenticatedRead`.
- Avoid for new designs; prefer uniform bucket-level access + IAM.

### Public Access Prevention
Organization policy `constraints/storage.publicAccessPrevention` blocks `allUsers` and `allAuthenticatedUsers` ACL/IAM grants, preventing accidental public exposure.

### IAM Principal Limits
Maximum 1,500 IAM principals per bucket across all roles.

---

## HMAC Keys

Hash-based Message Authentication Code (HMAC) keys allow S3-compatible authentication with GCS via the XML API or S3-compatible tools.

- Associated with **service accounts** (recommended) or user accounts.
- Each HMAC key has an **Access ID** (public) and a **Secret** (shown once at creation; cannot be retrieved later).
- State: `ACTIVE` or `INACTIVE`. Keys can be deactivated before deletion.
- Use `constraints/storage.restrictAuthTypes` to restrict or ban HMAC key usage at org level.
- Rotate keys regularly; deactivate and delete unused keys promptly.

---

## Pub/Sub Notifications

GCS can publish messages to a Cloud Pub/Sub topic when specified bucket events occur.

- **Event types**: `OBJECT_FINALIZE`, `OBJECT_METADATA_UPDATE`, `OBJECT_DELETE`, `OBJECT_ARCHIVE`.
- Up to 100 Pub/Sub notification configurations per bucket.
- Filter by object name prefix.
- Payload options: `JSON_API_V1` (full object metadata) or `NONE` (event type only).
- **Object change notification** (legacy XML-push) was deprecated January 30, 2026. Migrate to Pub/Sub notifications.

---

## JSON and XML APIs

GCS exposes two REST APIs:

### JSON API
- RESTful; uses JSON request/response bodies.
- Full feature support; preferred for new integrations.
- Base URL: `https://storage.googleapis.com/storage/v1/`
- Upload URL: `https://storage.googleapis.com/upload/storage/v1/`
- Supports resumable uploads, multipart, single-part.

### XML API
- S3-compatible interface; supports S3 SDKs and tools.
- Required for: HMAC key auth, XML multipart uploads, Compose via `?compose`.
- Base URL: `https://storage.googleapis.com/`
- Multi-object Delete (up to 1,000 per request): GA as of April 8, 2026 (XML API).

### Regional Endpoints
Use regional endpoints to enforce data locality and reduce latency:
`https://storage.{region}.rep.googleapis.com/`

Configure via gcloud:
```bash
gcloud config set api_endpoint_overrides/storage https://storage.us-central1.rep.googleapis.com/
```
