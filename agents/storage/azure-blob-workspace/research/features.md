# Azure Blob Storage — Features

## Core Capabilities

### Object Storage at Scale
- Stores unlimited objects of any size up to ~190.7 TiB per block blob.
- Single storage account capacity up to 5 PiB (expandable).
- No limit on number of containers or blobs per account.
- Global HTTP/HTTPS access via REST API, SDKs, CLI, and PowerShell.
- 99.9% availability SLA (Hot tier); 99% availability SLA (Cool, Cold, Archive).

### Multi-Protocol Access
| Protocol | Use Case | Requirements |
|---|---|---|
| HTTPS / REST | All object operations | None |
| NFS 3.0 | POSIX-like Linux mount | HNS enabled; VNet/private access only |
| SFTP | Legacy SFTP client access | HNS enabled; local user accounts |
| BlobFuse2 | Linux file system virtual driver | Open source; NFS alternative for compatibility |

---

## Azure Data Lake Storage Gen2 (ADLS Gen2) Integration

ADLS Gen2 is not a separate service but a capability set activated by enabling the hierarchical namespace on an Azure Blob Storage account.

### Key ADLS Gen2 Features

**Hierarchical Namespace (HNS)**
- Organizes objects in a true directory tree, enabling atomic rename/delete of directories.
- Rename a directory with millions of files as a single O(1) metadata operation.
- Reduces compute cost for analytics workloads that frequently reorganize data.

**POSIX-Compliant ACLs**
- File and directory level access control lists using POSIX ACL semantics.
- Supports owner, owning group, named user, named group, and mask entries.
- Enforced by both the Blob REST API and DFS REST API.
- Separate from Azure RBAC (role assignments at account/container level).

**Dual-Endpoint Access**
- Blob endpoint (`blob.core.windows.net`) for standard blob operations.
- DFS endpoint (`dfs.core.windows.net`) for directory-aware analytics operations.
- Most analytics frameworks prefer DFS endpoint for optimal performance.

**Native Analytics Integration**
- First-class support in Azure Synapse Analytics, Azure Databricks, Azure HDInsight, Azure Data Factory, Azure Machine Learning.
- Compatible with the Apache Hadoop FileSystem API and Delta Lake format.
- Supports columnar formats: Parquet, ORC, Avro, Delta, CSV, JSON.

**Performance at Scale**
- Designed for high-throughput analytics workloads.
- Sequential read/write performance scales with compute parallelism.
- Preferred architecture: raw → curated → aggregated zone pattern (medallion/lakehouse).

**Cost Tiers**
- All four access tiers (Hot, Cool, Cold, Archive) available on HNS accounts.
- Lifecycle management policies supported for automated tiering.

### ADLS Gen2 Limitations
- Object replication not supported.
- Version-level WORM immutability not yet supported.
- Page blobs not supported.
- Blob snapshots not supported.
- NFS 3.0 and SFTP require disabling public access.

---

## NFS 3.0 Protocol Support

- Mount Azure Blob Storage containers as an NFS v3 network file system on Linux VMs or on-premises Linux systems (via ExpressRoute or VPN).
- Enables migration of HPC, media processing, and legacy Linux workloads without application changes.
- Optimized for high-throughput, read-heavy, sequential I/O patterns.
- Supports large-file workloads (genomics, seismic, video transcoding).
- **Requirements:** HNS enabled; premium block blob or standard GPv2 account; VNet integration or private endpoint (no public internet).
- **Limitations:** No immutability policies; no object replication; no blob snapshots; no access tier support in NFS session.

---

## SFTP (SSH File Transfer Protocol) Support

- Enables SFTP clients to connect to Blob Storage for file upload/download operations.
- Easiest migration path for SFTP-based data pipelines moving to cloud storage.
- **Authentication:** password-based or SSH public key per local user.
- **Permissions:** each local user is assigned a home directory (container) with specific read/write/delete/list/create permissions per container path.
- **Requirement:** HNS must be enabled on the storage account.
- **Limitations:** SFTP and immutability policies are incompatible; object replication not supported; NFS 3.0 must be disabled during SFTP migration.
- SFTP cannot be used simultaneously with NFS 3.0 on the same account during migration windows.

---

## Blob Versioning

- Automatically maintains previous versions of a blob whenever it is modified or deleted.
- Each version is identified by a unique version ID (timestamp-based).
- Previous versions can be restored by copying a version to the current version.
- Required prerequisite for object replication and version-level WORM policies.
- Versions incur storage costs; use lifecycle management to delete old versions automatically.
- Not supported on HNS accounts (snapshots serve a similar purpose there).

---

## Blob Snapshots

- Point-in-time read-only copies of a blob taken manually or programmatically.
- Snapshots exist in the same storage account and container as the base blob.
- Identified by a `snapshot` query parameter (datetime) in the URI.
- Cheaper than full copies because snapshot blocks shared with base blob are not billed twice.
- Not supported on HNS accounts.
- Not replicated via object replication.

---

## Soft Delete

**Blob Soft Delete**
- Retains deleted blobs for a user-configurable retention period (1–365 days).
- Soft-deleted blobs are not visible in normal list operations but can be listed and restored.
- Compatible with versioning, immutability, and lifecycle management.
- Soft-deleted blobs are not subject to early deletion charges.

**Container Soft Delete**
- Retains deleted containers and their contents for a configurable period.
- Allows recovery of accidentally deleted containers before the retention period expires.

**Recommendation:** Enable both blob and container soft delete as a baseline data protection layer before configuring immutability policies.

---

## Point-in-Time Restore

- Restores block blobs to a prior state at a granular point in time.
- Requires blob versioning and change feed to be enabled.
- Useful for recovering from accidental bulk deletion or corruption.
- Restore range: from the earliest restore point to (now minus 1 second).
- Restore operations are billed at standard transaction rates.
- Incompatible with immutability policies.

---

## Change Feed

- Provides an ordered, durable log of all create, modify, and delete events on blobs in a storage account.
- Events stored as Avro-formatted blobs in the `$blobchangefeed` system container.
- Required for object replication (source account) and point-in-time restore.
- Change feed logs are generated with up to a few minutes of latency.
- Each change feed record includes: timestamp, operation type, blob URI, ETag, content length, and metadata changes.

---

## Blob Index Tags

- User-defined key-value metadata tags attached to individual blobs (up to 10 tags per blob).
- Tags are indexed by the storage service and support filter-based queries: `Find Blobs by Tags`.
- Use cases: classifying blobs by department, project, sensitivity, or processing status; querying across containers without iterating all blobs.
- Tags are searchable across all containers in a storage account via a single API call.
- Lifecycle management policies can filter by blob index tags to apply tier transitions or deletions to specific data sets.

---

## Static Website Hosting

- Serve static HTML, CSS, JavaScript, and image files directly from Blob Storage without a web server.
- Content served from a dedicated `$web` container.
- Custom domain and Azure CDN integration supported.
- Index document and 404 error page configurable.
- TLS termination provided by Azure CDN when paired with it.

---

## Azure Storage Actions (Storage Tasks)

- Serverless framework for executing bulk data operations across multiple storage accounts at scale.
- Executes operations based on user-defined conditions (if-then rules) applied to millions of objects.
- Use cases: bulk tier transitions, bulk tag updates, bulk deletion, large-scale immutability policy application.
- Complements lifecycle management (which operates within a single account).
- Generally available as of 2024.

---

## Encryption Features

### Encryption at Rest
- All data encrypted automatically using 256-bit AES encryption (SSE — Storage Service Encryption).
- Default: Microsoft-managed keys (MMK); fully transparent, no configuration needed.
- Customer-managed keys (CMK): bring your own keys stored in Azure Key Vault or Azure Key Vault Managed HSM.
  - Supports key rotation, key access revocation, and key audit logging.
  - Applies to all blob data, metadata, and access logs.
- Infrastructure-level encryption: optional second layer of AES-256 encryption at the hardware level (double encryption).
- Encryption scopes: per-container or per-blob encryption key scope; enables different CMKs for different data sets within one account.

### Encryption in Transit
- All REST API endpoints require HTTPS (minimum TLS 1.2 enforced per best practice).
- TLS 1.3 supported.
- Storage account can be configured to reject all HTTP (non-TLS) requests.

---

## Authentication and Authorization

### Methods (in order of preference)
1. **Microsoft Entra ID (Azure AD):** OAuth 2.0 tokens; recommended for all scenarios. Supports managed identities, service principals, user accounts.
2. **User Delegation SAS:** SAS tokens signed with Microsoft Entra credentials; scoped to a user's permissions; most secure SAS type.
3. **Service SAS:** SAS tokens signed with storage account key; scoped to specific resources and operations; set expiry <= 1 hour when not backed by a stored access policy.
4. **Account SAS:** Broadest SAS scope; grants access to multiple services; use sparingly.
5. **Shared Key (Account Key):** Full account access; recommended to disable via `AllowSharedKeyAccess = false` and enforce Entra ID only.

### Authorization Granularity
- Azure RBAC roles at subscription, resource group, storage account, or container level.
- POSIX ACLs at file/directory level (HNS accounts only).
- Stored access policies: server-side revocable policies associated with SAS tokens.
- Immutability policies: prevent modification/deletion regardless of authorization.

---

## Network Features

### Firewall and Virtual Network Rules
- Storage firewall can restrict access to specific IP ranges and Azure VNet subnets.
- VNet service endpoints route storage traffic over Azure backbone but do not provide private IP.
- Trusted Azure services bypass: allow specific Microsoft services (Azure Monitor, Azure Backup, etc.) through firewall.

### Private Endpoints
- Private IP from a VNet subnet; traffic never leaves Azure backbone.
- DNS automatically resolves storage FQDN to private IP via Azure Private DNS Zones.
- Separate endpoint per sub-resource (blob, dfs, file, queue, table, web).
- Maximum 200 private endpoints per storage account.

### Azure Network Security Perimeter (NSP)
- Group Azure resources (including storage accounts) into a perimeter with shared inbound/outbound rules.
- Enforces consistent network policy across PaaS services.
- Generally available as part of Azure networking governance toolset.

### Public Access Controls
- Disable anonymous blob access at the account level (prevents containers from being set to public read).
- Disable public network access entirely when private endpoints are used exclusively.

---

## Monitoring and Observability Features

- Azure Monitor platform metrics collected automatically (no configuration): Availability, Transactions, Ingress, Egress, SuccessServerLatency, SuccessE2ELatency, UsedCapacity.
- Resource logs (diagnostic logs) via diagnostic settings: routed to Log Analytics, Event Hubs, or another storage account.
- Azure Monitor Storage Insights: unified dashboard for storage health, performance, and capacity across accounts.
- Kusto Query Language (KQL) queries via Log Analytics for operational analysis.
- Azure Monitor Alerts: metric alerts, log alerts, and activity log alerts.
- Microsoft Defender for Storage: anomaly detection, threat intelligence, malware scanning.

---

## Recent Additions and Current Capabilities (2024–2026)

| Feature | Status | Notes |
|---|---|---|
| Cold access tier | GA | 90-day minimum; between Cool and Archive |
| Smart Tier | GA | Auto-tiering between Hot/Cool/Cold |
| Object Replication Priority Replication | GA | 99% of objects within 15 min (same continent, SLA-backed) |
| Blob index tag replication in object replication | Preview | Copies index tags to destination |
| Azure Storage Actions (Storage Tasks) | GA | Serverless bulk operations across accounts |
| Azure DNS Zone Endpoints | Preview | Up to 5,000 accounts/region/subscription |
| Network Security Perimeter (NSP) | GA | PaaS perimeter governance |
| SFTP support | GA | Requires HNS |
| NFS 3.0 support | GA | Requires HNS; VNet only |
| Version-level WORM | GA | Requires versioning; not yet on HNS |
| Microsoft Defender for Storage (malware scanning) | GA | Per-blob on-upload scanning |
| AllowCrossTenantReplication default to false | GA | For accounts created after Dec 15, 2023 |

---

## References
- [Introduction to Azure Blob Storage](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction)
- [ADLS Gen2 Introduction](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-introduction)
- [ADLS Gen2 Hierarchical Namespace](https://learn.microsoft.com/en-us/azure/storage/blobs/data-lake-storage-namespace)
- [NFS 3.0 Protocol Support](https://learn.microsoft.com/en-us/azure/storage/blobs/network-file-system-protocol-support)
- [Object Replication Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/object-replication-overview)
- [Object Replication Priority Replication](https://learn.microsoft.com/en-us/azure/storage/blobs/object-replication-priority-replication)
- [Immutable Storage Overview](https://learn.microsoft.com/en-us/azure/storage/blobs/immutable-storage-overview)
- [Azure Well-Architected Framework: Blob Storage](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-blob-storage)
