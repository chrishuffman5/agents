# Veeam Data Platform Architecture

## Component Overview

### Backup Server

The Veeam Backup Server is the central management component. All other components are orchestrated by it.

**Responsibilities:**
- Job scheduling and orchestration
- Configuration database (PostgreSQL in v12+; SQL Server in legacy deployments)
- Credential vault (encrypted storage of infrastructure credentials)
- REST API server (port 9419)
- Veeam console backend
- License management
- Configuration backup scheduler

**Database:**
- v12+: Bundled PostgreSQL instance (recommended) or external PostgreSQL/SQL Server
- v11 and earlier: SQL Server (local or remote)
- Configuration backup: Export of all Veeam settings to encrypted .bco file; schedule to external location

**Ports:**
- 9392: Veeam Backup Service (intra-component)
- 9401: Veeam Catalog Service
- 9419: REST API
- 9443: Veeam Enterprise Manager
- 2500-5000: Dynamic data transport range

**HA considerations:**
- Built-in HA: Not natively supported for the backup server itself (single instance)
- Workaround: VM with snapshot-based protection, or Windows Failover Cluster
- Veeam Recovery Orchestrator can automate VBR server recovery

### Backup Proxy

The backup proxy performs the actual data movement: reads from source, applies deduplication and compression, and writes to the backup repository.

**Proxy types by source:**

| Proxy Type | Source | Transport Modes |
|---|---|---|
| VMware Backup Proxy | vSphere VMs | Virtual Appliance (Hot-Add), Network (NBD/NBDSSL), Direct SAN |
| Hyper-V Off-Host Proxy | Hyper-V VMs | Direct SAN, SMB3, Network |
| Agent-Based (Windows) | Windows physical/VM | Network |
| Agent-Based (Linux) | Linux physical/VM | Network |
| NAS Backup Proxy | File shares (SMB/NFS) | Network |
| CDP Proxy | Continuous Data Protection | VMware VADP |

**Transport modes (VMware):**

1. **Virtual Appliance (Hot-Add)**: Proxy VM on same ESXi host. Veeam hot-adds source VM disks to proxy. Fast; no network saturation. Requires: proxy VM on vSphere, same datastore access.

2. **Network (NBD/NBDSSL)**: Reads VM data over VMware VDDK network transport. NBD = unencrypted; NBDSSL = encrypted (SSL). Slower; available for any proxy.

3. **Direct SAN Access**: Proxy connects directly to SAN LUN containing VM datastore. Fastest; requires: proxy has SAN access, FC/iSCSI HBA or iSCSI initiator.

**Proxy sizing:**
- 1 CPU core per concurrent task
- 2 GB RAM per concurrent task
- Network bandwidth: proxy must sustain throughput from source + to repository
- Scale horizontally: add more proxies to increase concurrent tasks

### Backup Repository

Storage target for Veeam backup files.

**Repository types:**

| Type | Use Case | Notes |
|---|---|---|
| Windows Server | SMB/local storage via Windows | Common; flexible |
| Linux Server | Direct-attached or NFS; hardened repo option | Best for immutability |
| SMB/NFS Share | Network share | Simpler; less control over immutability |
| Deduplication Appliance | HPE StoreOnce, Dell EMC DataDomain | Dedupe-first; limited immutability |
| Object Storage | S3, Azure Blob, GCS, etc. | Immutability via Object Lock; SOBR tier |
| Tape | LTO tape library | Offline, air-gapped |

**Backup file formats:**
- `.vbk`: Full backup file
- `.vib`: Forward incremental block (Incremental backup chain)
- `.vrb`: Reverse incremental block (Reverse incremental chain)
- `.vbm`: Backup metadata file
- `.vib` chain: Full + incrementals; restore requires full + all subsequent incrementals

**Backup chain modes:**
- **Forward incremental**: Full + forward incrementals. Space-efficient; restore needs full + chain.
- **Forever forward incremental**: Synthetic fulls created in repository; no periodic new fulls from source.
- **Reverse incremental**: Most recent is always a full; older points are reverse deltas. Fastest latest-point restore; slowest to write.

### Scale-Out Backup Repository (SOBR)

SOBR abstracts multiple repositories into a single logical entity with performance, capacity, and archive tiers.

**Architecture:**

```
SOBR (logical)
├── Performance Tier (one or more extents: disk repositories)
│   └── Receives all backup jobs
├── Capacity Tier (object storage repository)
│   └── Older backups offloaded from performance tier
└── Archive Tier (cold storage)
    └── Long-term retention; highest latency restore
```

**Extent selection policy:**
- Data locality: New backup chains go to the extent where previous chains exist
- Performance: Jobs distributed across extents based on available capacity
- Custom: Manual assignment of jobs to extents

**Capacity tier offload policies:**

| Policy | Behavior |
|---|---|
| Move offload | Moves backup files to capacity tier after threshold; removes from performance tier |
| Copy offload | Copies to capacity tier; retains on performance tier (redundancy) |

For ransomware resilience, use **Copy** mode. This maintains local fast-recovery copy + immutable cloud copy.

**Immutability on SOBR capacity tier:**
- Enable Object Lock on the S3 bucket before creating the SOBR
- Set immutability period in SOBR capacity tier settings
- Veeam sets the object lock retention tag on each backup object written

### WAN Accelerator

Reduces WAN bandwidth for backup copy jobs (data sent to remote Veeam repository over WAN).

**Technology:** Global deduplication across multiple VMs and multiple restore points using a global deduplication cache.

**Components:**
- Source WAN accelerator: Co-located with source backups
- Target WAN accelerator: Co-located with target repository

**When to use:**
- Links < 100 Mbps between backup sites
- High deduplication potential (many similar VMs, e.g., VDI environments)

**When NOT to use:**
- High-bandwidth links (WAN accelerator overhead can exceed savings)
- Cloud object storage targets (object storage has its own efficiency mechanisms)
- Already-compressed data (video, databases with page compression)

### Veeam Enterprise Manager (VEM)

Web-based multi-tenant management portal for large VBR deployments.

**Capabilities:**
- Central console for multiple VBR servers
- Self-service file restore portal (users can restore their own files)
- License reporting
- RESTful API (older API; v12 REST API supersedes for automation)

**Security note:** VEM has access to all connected VBR servers. Secure VEM like the VBR server itself.

### Hardened Linux Repository (Detail)

The hardened repository is a specific configuration of the Linux Server repository type.

**Full security architecture:**

1. **Dedicated OS account**: Veeam creates a local Linux user (`veeamrepo` by default) with minimal permissions
2. **No sudo/root access**: The transport account cannot escalate privileges
3. **No persistent SSH**: SSH is used only during initial deployment. After deployment, the service communicates via a Veeam-proprietary protocol (not SSH)
4. **Immutable flag mechanism**:
   - Transport component writes backup files
   - After write completes, a privileged component (running as root via a locked-down sudo rule for ONLY this operation) applies `chattr +i`
   - The transport account has NO ability to remove `chattr +i`
   - Only root can remove `chattr +i`, and root is only invoked at retention expiry by the authorized component
5. **Single-use credentials** (v12+): Each backup write session uses credentials that are valid for one write operation and are not reusable

**Filesystem recommendation:**
- XFS: Supports `reflink` (fast file cloning for synthetic fulls without data copy)
- ext4: Supported; no reflink
- Do NOT use BTRFS (not supported for hardened repo)

**Mount point layout:**
- Dedicated mount point for backup storage (separate from OS disk)
- XFS formatted with `bigalloc` disabled, `reflink` enabled: `mkfs.xfs -b size=4096 -m reflink=1 /dev/sdX`

### Object Storage Repository (Direct)

In v12+, object storage can be used as a primary backup repository (not just SOBR capacity tier).

**Supported providers:**
- Amazon S3 (+ S3-compatible: MinIO, Wasabi, Cloudflare R2, etc.)
- Microsoft Azure Blob Storage
- Google Cloud Storage
- IBM Cloud Object Storage
- S3-compatible (any S3 API-compatible storage)

**Immutability support:**
- AWS S3: S3 Object Lock (Compliance or Governance mode)
- Azure Blob: Immutable storage with time-based retention policies
- Wasabi: Bucket-level Object Lock
- MinIO: S3 Object Lock support
- Not all S3-compatible providers support Object Lock -- verify before deploying

**Performance characteristics:**
- Object storage is optimized for high latency, sequential access
- Not suitable for primary backup target for VMs needing fast restore (restore reads entire backup chain)
- Best suited for: SOBR capacity tier, archive, or secondary backup copy

### Veeam ONE Architecture

Veeam ONE is a separate product (included in Veeam Universal License) that monitors VBR, vSphere, Hyper-V, and AWS/Azure/GCP environments.

**Components:**
- Veeam ONE Server: Backend processing and database
- Veeam ONE Web Client: Browser-based console (React SPA)
- Veeam ONE Reporter: Scheduled report generation
- Veeam ONE Monitor: Real-time alerting and dashboards

**Data collection:**
- Collects from VBR API: job history, repository status, configuration
- Collects from vCenter/ESXi: VM performance metrics, resource usage
- Collects from Hyper-V: Hyper-V host and VM metrics
- Stores data in local SQL Server database (up to 1 year history by default)

**Integration with VBR for backup security:**
- Veeam ONE can trigger VBR alarms for backup anomalies
- Custom alarms via PowerShell integration
- Reports: infrastructure configuration, protection coverage, recovery verification history

### Veeam Recovery Orchestrator (VRO)

VRO automates and documents DR plans.

**Key capabilities:**
- Orchestration plans: Define recovery order, dependencies, and steps
- Runbook generation: Auto-generate step-by-step recovery documentation
- Automated testing: Execute DR test without manual steps
- Compliance reporting: Document test results for audit

**Integration with backup security:**
- Automates the "restore to clean environment" step in ransomware recovery
- Pre/post-script support: Run scripts to patch systems, re-register AD, etc.
- Network isolation: Can configure isolated recovery environment automatically

## Data Flow: Backup Job Execution

1. VBR Backup Server schedules job, selects backup proxy
2. Proxy connects to source (ESXi via VDDK, Hyper-V VSS, OS agent)
3. Source creates VM snapshot / VSS snapshot
4. Proxy reads changed blocks from source (CBT for VMware, RCT for Hyper-V)
5. Proxy applies inline deduplication and compression
6. Proxy connects to backup repository transport component
7. Data written to repository in backup chain format
8. Source snapshot removed
9. If repository is hardened Linux: `chattr +i` applied to completed backup file
10. VBR records restore point in catalog (PostgreSQL database)
11. If SOBR with Copy policy: offload job copies to capacity tier (object storage)
12. SureBackup job (if scheduled): mounts restore point in virtual lab, runs verification tests

## Data Flow: Instant VM Recovery

1. User initiates Instant Recovery in VBR console or REST API
2. VBR selects restore point and mounts backup file via iSCSI/NFS from repository
3. VM is registered on target ESXi host pointing to mounted backup as disk
4. VM boots directly from backup data (no restore required first)
5. VM is running; user can migrate to production storage in background (vMotion/Storage vMotion)
6. Migration: changed blocks written to production storage; backup mount remains until migration complete
7. After migration: backup mount released; recovery complete
