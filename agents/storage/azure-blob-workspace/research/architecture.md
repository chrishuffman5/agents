# Azure Blob Storage — Architecture

## Overview

Azure Blob Storage is Microsoft's cloud object storage service, optimized for storing massive amounts of unstructured data (text, binary, media, logs, backups). It is accessible globally via HTTP/HTTPS, REST API, Azure SDKs (.NET, Java, Python, Go, Node.js), PowerShell, and Azure CLI. The service underpins Azure Data Lake Storage Gen2, Azure static websites, Azure CDN origins, and many first-party Azure services.

---

## Resource Hierarchy

```
Azure Subscription
└── Storage Account  (unique namespace, e.g. https://myaccount.blob.core.windows.net)
    └── Container    (logical grouping, like a directory; unlimited per account)
        └── Blob     (individual object; unlimited per container)
```

- Container names: 3–63 lowercase alphanumeric/dash characters; must start with letter or number.
- Blob names: up to 1,024 characters; case-sensitive; path segments (virtual directories) delimited by `/`.
- A single storage account is the unit of billing, redundancy, authentication, and network policy.

---

## Storage Account Types

| Account Type | Performance | Supported Services | Redundancy Options | Best For |
|---|---|---|---|---|
| Standard general-purpose v2 (GPv2) | Standard (HDD) | Blob (incl. ADLS Gen2), Files, Queue, Table | LRS, ZRS, GRS, RA-GRS, GZRS, RA-GZRS | Most scenarios; recommended default |
| Premium block blobs | Premium (SSD) | Block blobs and append blobs | LRS, ZRS | High transaction rates, low latency, small objects |
| Premium page blobs | Premium (SSD) | Page blobs only | LRS, ZRS | VM disks, random I/O workloads |
| Premium file shares | Premium (SSD) | Azure Files only | LRS, ZRS | Enterprise file shares (SMB + NFS) |

> GPv1 and legacy Blob Storage accounts are retired/retiring. Migrate to GPv2.
> Classic (ASM) storage accounts were retired August 31, 2024.

**Account limits (GPv2, standard):**
- Default max capacity: 5 PiB (increase available via support)
- Max request rate: 40,000 req/s (major regions) / 20,000 req/s (other regions)
- Max ingress: 60 Gbps (major regions) / 25 Gbps (other regions)
- Max egress: 200 Gbps (major regions) / 50 Gbps (other regions)
- Max private endpoints per account: 200
- Max IP rules: 400; max VNet rules: 400

---

## Blob Types

### Block Blobs
- General-purpose object storage for text and binary data.
- Composed of up to 50,000 blocks; each block up to 4,000 MiB (REST API version 2019-12-12+).
- Maximum blob size: ~190.7 TiB.
- Single-write upload (Put Blob) supports up to 5,000 MiB.
- Supports all access tiers (Hot, Cool, Cold, Archive) and lifecycle management.
- Only blob type eligible for object replication.
- Primary type for ADLS Gen2, analytics, backups, media, AI/ML datasets.

### Append Blobs
- Optimized for sequential append operations; new data is always added to the end.
- Up to 50,000 blocks of 4 MiB each; maximum size ~195 GiB.
- Ideal for log ingestion from VMs, IoT telemetry, and audit trails.
- Does not support random writes; cannot be moved to archive tier via lifecycle policies.

### Page Blobs
- Random-access storage organized as 512-byte pages; maximum size 8 TiB.
- Backing store for Azure VM managed disks and unmanaged VHD disks.
- Target request rate: up to 500 req/s; target throughput: up to 60 MiB/s.
- Not supported in accounts with hierarchical namespace (ADLS Gen2).
- Does not support access tiers or lifecycle management.

---

## Access Tiers

Access tiers apply only to block blobs. The tier can be set at the account level (default) or overridden per blob.

| Tier | Type | Availability | Min Retention | Retrieval Latency | Supported Redundancy |
|---|---|---|---|---|---|
| Hot | Online | 99.9% (99.99% RA-GRS) | None | Milliseconds | All |
| Cool | Online | 99% (99.9% RA-GRS) | 30 days (GPv2) | Milliseconds | All |
| Cold | Online | 99% (99.9% RA-GRS) | 90 days (GPv2) | Milliseconds | All |
| Archive | Offline | 99% | 180 days | Up to 15 hours | LRS, GRS, RA-GRS only |

**Cost direction:** Storage cost decreases Hot → Cool → Cold → Archive. Access/transaction cost increases in the same direction.

**Early deletion charges:** Moving or deleting a blob before its minimum retention period incurs a prorated early-deletion fee for the remaining days.

**Smart Tier:** An auto-tiering feature that automatically moves blobs between Hot, Cool, and Cold tiers based on observed access patterns.

**Archive rehydration:** Two priority options:
- Standard priority: up to 15 hours, lower cost.
- High priority: typically under 1 hour for blobs under 10 GB, higher cost.

**Changing tiers:**
- Warm-to-cool transitions: instantaneous.
- Cool/Cold-to-Hot: instantaneous.
- Any tier to/from Archive: requires rehydration (up to 15 hours).
- Lifecycle management policies cannot rehydrate archived blobs; use Copy Blob or Set Blob Tier instead.

---

## Redundancy Options

| Option | Copies | Scope | Reads from Secondary | Use Case |
|---|---|---|---|---|
| LRS (Locally Redundant Storage) | 3 | Single datacenter | No | Dev/test, non-critical |
| ZRS (Zone-Redundant Storage) | 3 | 3 availability zones, single region | No | High availability within region |
| GRS (Geo-Redundant Storage) | 6 (3+3) | Primary + paired region | No (read requires failover) | Regional DR |
| RA-GRS (Read-Access GRS) | 6 | Primary + paired region | Yes (secondary reads) | Global read distribution |
| GZRS (Geo-Zone-Redundant) | 6 | 3 zones primary + paired region | No | Highest durability + HA |
| RA-GZRS | 6 | 3 zones primary + paired region | Yes | Maximum resiliency + secondary reads |

> Archive tier only supports LRS, GRS, and RA-GRS — not ZRS, GZRS, or RA-GZRS.

---

## Azure Data Lake Storage Gen2 (ADLS Gen2)

ADLS Gen2 is a set of capabilities layered on top of Azure Blob Storage, enabled by activating the **hierarchical namespace (HNS)** on a GPv2 or premium block blob storage account.

### Hierarchical Namespace
- Organizes blobs into a true directory tree rather than a flat namespace with virtual path prefixes.
- Directory operations (rename, move, delete) are atomic and O(1) — a rename of a directory with millions of files is a single metadata operation.
- Enables POSIX-compliant ACLs (access control lists) at the file and directory level, separate from Azure RBAC.
- Uses the DFS endpoint: `https://<account>.dfs.core.windows.net`.
- Required for NFS 3.0 and SFTP protocol support.
- Supported by Azure Databricks, Azure Synapse Analytics, Azure HDInsight, Azure Data Factory, and most major analytics frameworks.

### HNS Restrictions
- Cannot be disabled after enabling without data migration.
- Object replication not supported for HNS accounts.
- Version-level WORM immutability policies not yet supported in HNS accounts.
- Page blobs not supported.
- Blob snapshots are not supported.

---

## NFS 3.0 Protocol Support

- Allows mounting Azure Blob Storage containers as a NFS 3.0 file system on Linux clients.
- Requires hierarchical namespace (HNS) to be enabled.
- Requires a premium block blob or standard GPv2 account.
- Requires disabling public network access and using private endpoints or VNet service endpoints (no public internet access supported).
- Optimized for high-throughput, large-scale, read-heavy sequential I/O.
- Not compatible with immutability policies, object replication, or blob snapshots.

---

## SFTP Support

- SSH File Transfer Protocol (SFTP) support enables SFTP clients to connect directly to Blob Storage containers.
- Requires hierarchical namespace (HNS) enabled.
- Supports local users with password or SSH public key authentication.
- Each SFTP user is mapped to a specific container (home directory).
- Useful for migrating legacy SFTP workflows to cloud storage without application changes.
- Not compatible with immutability policies or object replication.

---

## Lifecycle Management

Lifecycle management policies automate data tiering and deletion using rule-based JSON policies applied to a storage account.

### Policy Structure
- A policy is a collection of rules (up to 100 rules per account).
- Each rule has:
  - **Filters:** prefix match (up to 10 prefixes/rule) and/or blob index tags (up to 10 conditions/rule). Filters use logical AND.
  - **Conditions:** based on Creation Time, Last Modified Time, or Last Accessed Time (requires access tracking enabled).
  - **Actions:** transition blob to cooler tier, or delete blob.

### Supported Actions by Blob Type
- Block blobs: transition to cool, cold, archive; delete current version, previous versions, snapshots.
- Append blobs: delete only.
- Page blobs: not supported.

### Key Behaviors
- Policy changes take up to 24 hours to go into effect.
- Policy runs process blobs periodically; run duration depends on blob count.
- Cannot rehydrate archived blobs via lifecycle policy (use Set Blob Tier or Copy Blob).
- Lifecycle policies do not affect system containers (`$logs`, `$web`).
- Delete action fails for blobs protected by immutability policies or in soft-deleted state.
- Azure Storage Actions (serverless framework) can run similar operations at scale across multiple accounts.

---

## Object Replication

Object replication asynchronously copies block blobs from a source account to one or two destination accounts, across the same or different regions and subscriptions.

### Prerequisites
- Blob versioning must be enabled on both source and destination accounts.
- Change feed must be enabled on the source account.
- Only block blobs are supported (not append or page blobs).
- Source and destination must be GPv2 or premium block blob accounts.
- Not supported on HNS (ADLS Gen2) accounts.

### Policy and Rules
- A replication policy is created on the destination account and associated with the source account via a policy ID.
- Each policy includes up to 1,000 rules; each rule maps one source container to one destination container.
- Rules can filter by blob name prefix (up to 5 prefix filters) and minimum creation time.
- Blob index tag replication (preview): index tags can optionally be copied alongside blobs.
- Source can replicate to at most 2 destination accounts; destination can receive from at most 2 source accounts.

### Behavior
- Replication is asynchronous; source and destination are not immediately in sync.
- All blob versions are replicated; snapshots are not replicated.
- Destination container becomes read-only for writes while a replication rule is active (write attempts return 409 Conflict).
- Tier changes in source do not propagate to destination.
- Archive-tiered blobs in source or destination block replication.

### Priority Replication
- When source and destination are within the same continent, priority replication guarantees 99% of objects replicate within 15 minutes (SLA-backed).

### Replication Metrics
- "Operations pending for replication" and "Bytes pending for replication" metrics available in Azure Monitor.
- Metrics include time-bucket breakdowns (0–5 min, 5–10 min, ..., >24 hrs).

### Cross-Tenant Replication
- Disabled by default for accounts created after December 15, 2023.
- Controlled by the `AllowCrossTenantReplication` property on the storage account.

---

## Immutability Policies (WORM)

Azure Blob Storage immutable storage stores data in Write Once, Read Many (WORM) format, preventing modification or deletion for a specified period.

### Policy Types

**Time-Based Retention Policy**
- Retains blobs in immutable state for a specified interval (1 day minimum to 146,000 days / 400 years maximum).
- Effective retention period = blob creation time + specified retention interval.
- Locking the policy makes it compliant with SEC 17a-4(f), CFTC 1.31(c)-(d), and FINRA 4511.
- Locked policies cannot be deleted; retention period can only be extended (max 5 increases for container-level locked policies; unlimited for version-level).

**Legal Hold Policy**
- Indefinite WORM state; remains in effect until explicitly cleared.
- Must be associated with one or more alphanumeric tag strings (case ID, event name, etc.).
- Used for litigation holds, event-based retention, and regulatory investigation.

### Scope Options

| Feature | Container-Level WORM | Version-Level WORM |
|---|---|---|
| Granularity | Container only | Account, container, or individual blob version |
| Policy types | Time-based + legal hold at container | Time-based at account/container; both types at blob version |
| Versioning required | No | Yes |
| ADLS Gen2 support | Yes | Not yet supported |
| Max containers | 10,000 per account | Unlimited (account-level policy) |

### Audit Logging
- Each container with an immutability policy provides a policy audit log retaining up to 7 time-based retention commands.
- Audit log retained for policy lifetime per SEC 17a-4(f).
- Azure Activity Log provides comprehensive management-plane audit trail.

### Compatibility
- Supported for all access tiers and all redundancy configurations.
- Not supported on accounts with NFS 3.0 or SFTP enabled.
- Incompatible with point-in-time restore and last access time tracking.
- The `Allow protected append blob writes` option enables append-only operations (e.g., log appends) within an immutable container.

---

## Private Endpoints

Azure Private Endpoint creates a network interface (NIC) inside a VNet subnet with a private IP address, routing storage traffic over the Azure backbone rather than the public internet.

- A separate private endpoint is required for each sub-resource type: `blob`, `dfs` (ADLS Gen2), `file`, `queue`, `table`, `web` (static website).
- Up to 200 private endpoints per storage account.
- When a private endpoint is configured, the storage firewall's public endpoint rules do not apply to private endpoint traffic.
- DNS must resolve the storage account FQDN to the private IP; use Private DNS Zones for automatic resolution.
- Public network access can be completely disabled when using private endpoints only.
- Compatible with Azure Network Security Perimeter (NSP) for perimeter-based governance of PaaS services.

---

## Storage Account Endpoints

| Service | Standard Endpoint | DNS Zone Endpoint (preview) |
|---|---|---|
| Blob Storage | `https://<account>.blob.core.windows.net` | `https://<account>.z[00-50].blob.storage.azure.net` |
| Data Lake Storage | `https://<account>.dfs.core.windows.net` | `https://<account>.z[00-50].dfs.storage.azure.net` |

- Azure DNS Zone endpoints (preview) allow up to 5,000 storage accounts per region per subscription (vs. 250/500 for standard endpoints).
- DNS zone endpoints are assigned dynamically at account creation.
- Custom domain mapping is supported for Blob Storage endpoints.

---

## Scalability Targets (Block Blobs)

| Resource | Limit |
|---|---|
| Max block blob size | ~190.7 TiB (50,000 blocks x 4,000 MiB) |
| Max append blob size | ~195 GiB (50,000 blocks x 4 MiB) |
| Max page blob size | 8 TiB |
| Max blocks per blob | 50,000 |
| Max block size (REST 2019-12-12+) | 4,000 MiB |
| Single-write upload size (Put Blob) | 5,000 MiB |
| Per-page-blob target request rate | 500 req/s |
| Per-page-blob target throughput | 60 MiB/s |
| Per-block-blob throughput | Up to account ingress/egress limits |

Exceeding partition limits returns HTTP 503 (Server Busy) or 500 (Operation Timeout). Apply exponential backoff retry logic.

---

## References
- [Introduction to Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)
- [Storage Account Overview](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview)
- [Access Tiers Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/access-tiers-overview)
- [ADLS Gen2 Hierarchical Namespace](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-namespace)
- [NFS 3.0 Protocol Support](https://learn.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support)
- [Lifecycle Management Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/lifecycle-management-overview)
- [Object Replication Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/object-replication-overview)
- [Immutable Storage Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview)
- [Scalability and Performance Targets](https://learn.microsoft.com/en-us/azure/storage/blobs/scalability-targets)
- [Private Endpoints for Azure Storage](https://learn.microsoft.com/en-us/azure/storage/common/storage-private-endpoints)
