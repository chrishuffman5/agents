# Azure Blob Storage Architecture

## Storage Account Types

| Type | Performance | Services | Redundancy | Best For |
|---|---|---|---|---|
| Standard GPv2 | HDD | Blob, Files, Queue, Table | All | Most scenarios (recommended default) |
| Premium block blobs | SSD | Block + append blobs | LRS, ZRS | High transactions, low latency |
| Premium page blobs | SSD | Page blobs only | LRS, ZRS | VM disks |

Account limits (GPv2 standard): 5 PiB capacity, 40K req/s (major regions), 60 Gbps ingress, 200 Gbps egress, 200 private endpoints.

## Blob Types

**Block blobs:** General-purpose objects, up to ~190.7 TiB, all access tiers, lifecycle management, ADLS Gen2, object replication.

**Append blobs:** Sequential append only, up to ~195 GiB. Ideal for logs, telemetry. Cannot archive.

**Page blobs:** Random-access 512-byte pages, up to 8 TiB. VM disks. No tiers, no lifecycle.

## Access Tiers

| Tier | Availability | Min Retention | Retrieval | Redundancy |
|---|---|---|---|---|
| Hot | 99.9% (99.99% RA-GRS) | None | ms | All |
| Cool | 99% | 30 days | ms | All |
| Cold | 99% | 90 days | ms | All |
| Archive | 99% | 180 days | Up to 15h | LRS, GRS, RA-GRS only |

Smart Tier auto-moves blobs between Hot/Cool/Cold based on access patterns. Archive rehydration: Standard (up to 15h), High priority (typically under 1h for < 10 GB).

## Redundancy Options

LRS (3 copies, 1 datacenter), ZRS (3 copies, 3 AZs), GRS (6 copies, 2 regions), RA-GRS (+ secondary reads), GZRS (3 zones + paired), RA-GZRS (maximum resiliency).

## ADLS Gen2 (Hierarchical Namespace)

Enables true directory tree. Atomic O(1) directory rename/move/delete. POSIX ACLs at file/directory level. DFS endpoint: `https://<account>.dfs.core.windows.net`. Required for NFS 3.0 and SFTP.

HNS restrictions: cannot disable after enabling, no object replication, no version-level WORM (yet), no page blobs, no blob snapshots.

## NFS 3.0 Support

Mount containers as NFS filesystem on Linux. Requires HNS, VNet/private access only (no public internet). Optimized for high-throughput sequential I/O.

## SFTP Support

SSH File Transfer Protocol for legacy SFTP clients. Requires HNS. Local user accounts with password/SSH key auth. Each user mapped to a home container.

## Lifecycle Management

Up to 100 rules per account. Filters: prefix (10/rule), blob index tags (10/rule). Conditions: Creation Time, Last Modified, Last Accessed. Actions: transition tier, delete. Takes up to 24 hours to take effect.

Supported: block blob transitions (Hot->Cool->Cold->Archive) and deletion. Append blobs: delete only. Page blobs: not supported. Cannot rehydrate archived blobs via lifecycle.

## Object Replication

Async copy of block blobs from source to 1-2 destination accounts. Requires versioning (both) and change feed (source). Up to 1,000 rules per policy. Priority replication: 99% within 15 minutes (same continent).

Destination container read-only during active replication. Tier changes do not propagate. Archive blobs block replication. Cross-tenant disabled by default (post-Dec 2023).

## Immutability (WORM)

**Time-based retention:** Immutable for specified interval. Locked policies cannot be deleted or shortened; compliant with SEC 17a-4(f), CFTC, FINRA.

**Legal hold:** Indefinite immutability via alphanumeric tag strings. Cleared explicitly.

**Scope:** Container-level (simpler, no versioning needed) or version-level (finer granularity, requires versioning).

## Private Endpoints

NIC in VNet subnet with private IP. Separate endpoint per sub-resource (blob, dfs, file, queue, table, web). Up to 200 per account. DNS resolution via Private DNS Zones. Public access can be disabled entirely.

## Scalability Targets (Block Blobs)

Max blob: ~190.7 TiB. Max block: 4,000 MiB. Max blocks/blob: 50,000. Single-write (Put Blob): 5,000 MiB. Exceeding limits returns 503/500 -- use exponential backoff.
