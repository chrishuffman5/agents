# Cohesity Architecture Reference

## Cohesity Cluster Architecture

### Node Types

**All-Flash nodes (C2700):**
- NVMe SSDs for metadata and hot data
- High-capacity NVMe for backup data
- Optimized for latency-sensitive workloads

**Hybrid nodes (C3000/C5000):**
- SSDs for metadata cache
- High-density HDDs for backup data
- Most common deployment type

**Virtual Edition (VE):**
- Software-only deployment on existing VMware vSphere or KVM
- Lower performance than physical hardware
- Suitable for remote offices, small environments

### Cluster Scaling

- Minimum: 3 nodes
- Maximum: 16 nodes per cluster
- Scale-out: Add nodes online; data automatically rebalances across new nodes
- Geographic distribution: Multiple clusters linked via Helios (not stretched cluster)

### High Availability

- Data erasure-coded across nodes (N+2 by default; sustains 2 simultaneous node failures)
- Metadata replicated 3x
- No single master node; all nodes participate in metadata and data services
- Node failure: Cluster continues operating; degraded mode until node replaced or added

---

## SpanFS Distributed Filesystem

### Architecture Principles

SpanFS is designed for the write-once, read-many access pattern of backup data.

**Key characteristics:**
- **Distributed**: Data and metadata striped across all cluster nodes
- **Append-only writes**: New data always written to new locations; no in-place modification
- **Reference-counted objects**: Data blocks shared across snapshots via references (like APFS or Btrfs)
- **Lazy space reclamation**: Space freed only during garbage collection, not at deletion time
- **Atomic snapshots**: SpanFS creates consistent point-in-time snapshots of protected data

### Deduplication and Compression

**Inline deduplication:**
- Variable-length chunking (fingerprint-based)
- Global dedup across all protection groups (unlike per-job dedup in traditional tools)
- A chunk written once; all subsequent occurrences reference the original

**Compression:**
- LZ4 (default) or Snappy
- Applied after deduplication
- Compression ratios: 2-4x typical for VM data

**Overall space reduction:**
- Combined dedup + compression: 5-20x depending on data type
- VDI environments: up to 30x (highly similar VMs)
- Database backups: 3-5x typical

### Snapshot Mechanics

SpanFS snapshots are pointer-based (copy-on-write semantics):
- Creating a snapshot: O(1) operation (just locks the current state pointer)
- Snapshot storage: Only stores changes since previous snapshot (not a full copy)
- Restore from snapshot: Reads the exact data as it existed at that point in time

### DataLock (WORM) Implementation

DataLock is implemented at the SpanFS level:

1. When a snapshot is created under a DataLock policy, the snapshot object is flagged with:
   - `worm_locked = true`
   - `worm_expiry = [timestamp]`
2. SpanFS's delete/modify operations check `worm_locked` before proceeding
3. If `worm_locked = true` and current time < `worm_expiry`, the operation is rejected at the filesystem level
4. The `worm_locked` flag cannot be cleared by any software; only hardware end-of-life (cluster factory reset) would clear it, and Compliance mode requires additional hardware attestation

**Compliance mode vs. Enterprise mode:**

| Feature | Compliance | Enterprise |
|---|---|---|
| Admin can delete before expiry | No | Yes (with extra confirmation) |
| Audit log of attempted deletion | Yes | Yes |
| Regulatory compliance use | Yes (SEC 17a-4, etc.) | No |
| Ransomware protection | Strong | Moderate (admin account compromise = bypass) |

---

## FortKnox Technical Architecture

### Infrastructure

FortKnox is hosted on AWS infrastructure managed by Cohesity:
- Multi-region availability (customer selects preferred region)
- AWS S3 with Object Lock compliance mode for data storage
- Cohesity-managed encryption keys (or customer-managed via KMS integration)
- AWS VPC with no customer-accessible network paths

### Data Replication Protocol

FortKnox replication uses a Cohesity-proprietary protocol over HTTPS:
1. Source cluster compresses and encrypts data before transmission
2. Data transferred to Cohesity FortKnox ingest endpoint
3. Cohesity backend stores data in S3 with Object Lock
4. Source cluster receives confirmation; metadata catalog updated in Helios

**Network requirements:**
- Outbound HTTPS (port 443) from Cohesity cluster to Cohesity FortKnox endpoints
- No inbound connectivity required
- Bandwidth: Sized for daily change rate + initial seeding

### Isolated Recovery Environment (IRE)

When a FortKnox recovery is initiated to the IRE:
1. Cohesity provisions an isolated AWS VPC (customer-dedicated, ephemeral)
2. Selected VMs are restored to EC2 instances in the isolated VPC
3. VPC has no peering to customer's production AWS environment or on-premises
4. Customer accesses IRE via Cohesity-provided credentials (temporary, time-limited)
5. Customer performs forensics, validation, or clean-up operations
6. IRE can be torn down when recovery is complete

**IRE access:**
- Console access via Cohesity Helios portal
- SSH/RDP to recovered VMs via Cohesity-proxied connection
- No direct internet exposure of recovered VMs

---

## DataHawk Architecture

### Component Breakdown

**Anomaly Detection:**
- Runs on Helios (cloud-processed, not on-premises cluster)
- Data: Snapshot delta statistics pushed from cluster to Helios
- Algorithm: ML model combining time-series analysis and threshold detection
- Latency: Anomaly scores available within minutes of snapshot completion
- Model training: Cohesity-managed; updated via Helios

**Data Classification Engine:**
- Runs on the cluster (data does not leave the cluster for classification)
- Accesses snapshot data via internal SpanFS interface
- Classifier execution: Parallel processing across cluster nodes
- Results stored in Helios metadata database

**CyberScan:**
- Vulnerability database: CVE data updated via Helios (pulled by cluster)
- Malware signatures: Updated via Helios
- YARA rules: Customer-uploaded via Helios
- Execution: On-cluster; mounts snapshot read-only, runs scan

### DataHawk API

DataHawk operations accessible via Cohesity Helios REST API and Cohesity v2 API:

```
GET /v2/data-protect/security/anomalies -- List detected anomalies
GET /v2/data-protect/security/anomalies/{id} -- Anomaly details
POST /v2/data-protect/security/scans -- Create CyberScan job
GET /v2/data-protect/security/scans/{id}/results -- Scan results
GET /v2/data-protection/classifications -- Classification scan results
```

---

## Cohesity Helios SaaS Architecture

### Design

Helios is a multi-tenant SaaS platform:
- Hosted in AWS (multiple regions for data residency compliance)
- Each customer organization has isolated tenant space
- All cluster metadata synchronized to Helios (not raw backup data)
- Raw backup data stays on-premises or in FortKnox

### Helios ↔ Cluster Communication

- Cluster initiates outbound connection to Helios (HTTPS/WebSocket)
- Persistent connection maintained for real-time events
- Data pushed: Snapshot metadata, job results, anomaly scores, system health
- Commands pulled: Policy changes, protection group assignments, job triggers

**No inbound firewall rules required.** Only outbound HTTPS (443) from cluster.

### Authentication and Authorization

- SAML 2.0 SSO (Azure AD, Okta, PingFederate, OneLogin)
- Local accounts with MFA (TOTP or hardware key)
- Role-based access:
  - Cluster Admin: Full access to specific clusters
  - Super Admin: All clusters in organization
  - Viewer: Read-only, no operations
  - Recovery Admin: Can initiate restores; cannot modify policies or delete
  - DataHawk Analyst: Security dashboards only; no data operations

---

## Instant Mass Restore Architecture

### How It Works (Technical)

**Phase 1: Instant availability (seconds)**
1. User selects VMs to restore, selects target vSphere/compute
2. Cohesity registers VMs on ESXi/vSphere pointing to SpanFS-hosted virtual disks
3. VMs are immediately startable; disk I/O served by Cohesity cluster via NFS datastore
4. Time to first VM boot: ~10-30 seconds (VMware registration time)

**Phase 2: Background hydration (concurrent with VM use)**
5. Cohesity SnapTree service monitors I/O patterns on each recovered VM
6. Hot data (frequently accessed blocks) prioritized for migration to production storage
7. Cold data migrates in background without impacting VM performance
8. Migration rate: Limited by production storage bandwidth (not Cohesity)

**Phase 3: Completion**
8. When all blocks migrated to production storage, VM storage path updated
9. Cohesity NFS datastore mount released for the VM
10. VM now fully on production storage

**Scale limits:**
- VMware: Limited by vSphere registration time (~10-30 VMs/minute)
- Concurrent VMs running from Cohesity storage: Limited by cluster NFS throughput (cluster-specific)
- For mass ransomware recovery: 100+ VMs can be started within minutes, not hours

### Granular Recovery

In addition to VM-level recovery, Cohesity supports:
- **File-level recovery**: Single file restore from any snapshot (GUI or API)
- **Application-level recovery**: SQL Server database restore, Exchange mailbox restore
- **NAS-level recovery**: Restore specific file paths or entire share from NAS backup
- **Object-level recovery**: Individual objects from Microsoft 365 (SharePoint, OneDrive, Exchange)

---

## Cloud Integration Architecture

### AWS Integration

**VM protection:**
- AWS EC2 protection via Cohesity CloudAgent or snapshot-based (EBS snapshot integration)
- EBS snapshots managed by Cohesity policy (retention, DataLock)
- Cross-region copy for DR

**Cloud backup:**
- Cohesity cluster replicates to S3 (capacity extension)
- S3 Object Lock integration for immutable cloud copies
- Cross-account S3 for logical air gap

### Azure Integration

**AHV/Hyper-V:**
- Cohesity supports Azure Stack HCI for on-premises Azure workloads
- Azure Blob as archive target

### Google Cloud

- GCS as archive target
- Near-line/Coldline for cost-optimized long-term retention

---

## Network Architecture

### Required Ports

| Traffic Type | Protocol | Ports |
|---|---|---|
| Backup data (source to cluster) | TCP | 443, 2049 (NFS), custom agent ports |
| vSphere backup (VADP) | TCP | 902 (ESXi), 443 (vCenter) |
| Helios management | HTTPS | 443 outbound only |
| FortKnox replication | HTTPS | 443 outbound only |
| Admin UI | HTTPS | 443 |
| Cluster inter-node | TCP | 2000-2100 (internal) |

### Network Segmentation Recommendation

- Dedicated backup VLAN for Cohesity cluster
- Production → Backup: Allow backup agent traffic, VADP (902)
- Backup → Internet: Allow HTTPS to Helios/FortKnox endpoints only
- No inbound connections from internet
- Admin access to Helios UI via corporate proxy or VPN
