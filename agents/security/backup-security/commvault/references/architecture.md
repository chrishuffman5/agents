# Commvault Architecture Reference

## CommServe

CommServe is the central management and orchestration engine for all Commvault operations.

### Responsibilities

- **Job scheduling**: Initiates all backup, restore, and auxiliary copy jobs
- **Policy engine**: Stores and enforces protection plans, schedules, and retention
- **Catalog/database**: SQL Server database containing all backup metadata (job history, file catalog, restore points)
- **License management**: Tracks capacity usage against license entitlements
- **Alert engine**: Monitors all components and triggers notifications
- **REST API gateway**: All Commvault automation goes through CommServe REST API

### CommServe Database

- Database: Microsoft SQL Server (local or remote)
- Size: Depends on environment size and metadata retention; typical 50-500 GB
- Contents: Job history, file catalog, policy definitions, alert history, agent configuration
- Backup: CommServe runs a daily backup of its own database (DR Backup)

**CommServe DR Backup:**
`CommCell Console > Control Panel > CommCell > CommServe DR Backup`
- Schedule: Daily minimum
- Destination: Remote share NOT on CommServe server
- Contents: CommServe database + configuration files
- Restore: Install fresh CommServe, restore from DR backup to resume operations

### CommServe High Availability

**Active/Passive HA:**
- Windows Server Failover Cluster (WSFC) with shared storage or AlwaysOn SQL
- Automatic failover on CommServe failure
- Requires: Two Windows servers + shared storage or SQL Server AG

**Commvault Cloud / Metallic (SaaS):**
- Commvault manages CommServe HA; customer does not need to manage
- SLA: 99.9% availability

### Scaling CommServe

- Small: < 500 clients -- single CommServe
- Medium: 500-2000 clients -- CommServe + separate SQL Server
- Large: > 2000 clients -- Consider Commvault Cloud (SaaS CommServe)
- Memory: 16 GB minimum; 32-64 GB recommended for large environments
- CPU: 8 cores minimum; 16+ cores for large environments

---

## MediaAgent

The MediaAgent (MA) performs all data movement: reads from source agent, deduplicates, compresses, encrypts, and writes to storage library.

### Data Processing Pipeline

```
Source Agent → [Network] → MediaAgent
    ↓ (on MediaAgent)
Block-level deduplication (fingerprinting)
    ↓
Compression
    ↓
Encryption (AES-256)
    ↓
[Network / local I/O]
    ↓
Storage Library (disk/tape/cloud)
```

### Deduplication Database (DDB)

The DDB stores SHA-512 fingerprints of all deduplicated chunks:
- Location: High-performance SSD on MediaAgent server
- Size: ~1 GB per 100 TB of protected data (typical)
- Critical: DDB loss means loss of all deduplicated backups on that library

**DDB protection:**
- Back up DDB daily (`Storage > Libraries > [Library] > MediaAgent > DDB Backup`)
- Store DDB backup on separate storage (not same library)
- RAID the DDB disk (DDB loss = catastrophic)

### MediaAgent Sizing

| Concurrent streams | CPU cores | RAM | Network |
|---|---|---|---|
| Up to 10 | 8 cores | 16 GB | 1 GbE |
| 10-25 | 16 cores | 32 GB | 10 GbE |
| 25-50 | 32 cores | 64 GB | 10-25 GbE |
| 50+ | 64+ cores | 128+ GB | 25+ GbE |

**Scale-out:** Add MediaAgents; CommServe distributes jobs across available MAs.

### MediaAgent Deployment Options

- **Dedicated server**: Recommended for medium/large environments
- **Co-located with CommServe**: Small environments only
- **On cloud VM**: MediaAgent running in AWS/Azure for cloud-side data movement
- **HyperScale X node**: MediaAgent embedded in converged appliance

---

## Commvault Agents (iDA -- iDataAgents)

Agents are installed on protected workloads to enable backup and restore.

### Agent Types

| Agent | Workload | Notes |
|---|---|---|
| File System Agent (Windows/Linux) | Physical servers, files | Handles VSS on Windows |
| Virtual Server Agent (VSA) | VMware, Hyper-V, Nutanix | Agent-less VM backup via hypervisor APIs |
| SQL Server Agent | SQL Server databases | Full, differential, log backup; log shipping |
| Oracle Agent | Oracle databases | RMAN-integrated |
| MySQL Agent | MySQL/MariaDB | |
| PostgreSQL Agent | PostgreSQL | |
| SAP HANA Agent | SAP HANA | |
| MongoDB Agent | MongoDB | |
| Exchange Agent | Exchange Server on-prem | |
| SharePoint Agent | SharePoint on-prem | |
| Active Directory Agent | AD domains | |
| Kubernetes Agent | K8s clusters | Namespace-level protection |

### Agent Communication

- Agents communicate with CommServe on port 8400 (inbound to CommServe)
- Data flows: Agent → MediaAgent (not through CommServe)
- TLS encrypted in transit
- Firewall: CommServe needs inbound 8400 from all clients

---

## Storage Libraries

Libraries are storage targets managed by a MediaAgent.

### Library Types

| Library Type | Storage | Notes |
|---|---|---|
| Disk Library | Local disk, NAS | Most common; fast restore |
| Cloud Library | S3, Azure Blob, GCS, S3-compatible | Immutability via Object Lock |
| Tape Library | LTO tape, VTL | Long-term retention, air gap |
| HyperScale X Library | Converged storage | Built-in dedup + scale-out |
| Magnetic Library | Storage array (via FC/iSCSI) | High-performance disk |

### Cloud Library Configuration

**AWS S3 with Object Lock:**
1. `Storage > Cloud Storage > Add Cloud`
2. Provider: Amazon S3
3. Account credentials: IAM user with s3:PutObject, s3:GetObject, s3:PutObjectRetention
4. Bucket: Pre-created with Object Lock (compliance mode)
5. In library properties: Enable WORM, set retention period

**Key setting: Retention period alignment**
- Library WORM retention must match or exceed the protection plan retention
- If plan retains 30 days, library WORM retention must be ≥ 30 days

### Deduplication at Library Level

Each disk/cloud library has a MediaAgent-managed dedup database:
- Global deduplication across all jobs using that library
- Saves storage vs. per-job or per-client dedup

---

## Commvault Cloud (Hybrid SaaS Platform)

### Architecture Layers

```
Commvault Command Center (UI)
    ↑
Unity Platform (Management API)
    ├── Commvault Cloud (SaaS CommServe)
    └── Self-managed CommServe
         ↑
    MediaAgent (customer-deployed)
         ↑
    Agents (on protected workloads)
         ↓
    Storage Library (customer cloud or on-prem)
```

### Commvault Cloud vs. Self-Managed

| Aspect | Self-Managed | Commvault Cloud |
|---|---|---|
| CommServe | Customer-managed VM | SaaS (Commvault-managed) |
| CommServe HA | Customer's responsibility | Commvault SLA |
| MediaAgent | Customer-deployed | Customer-deployed (or Metallic-hosted) |
| Updates | Customer-scheduled | Commvault-managed |
| Scalability | Manual | Elastic |

---

## Metallic.io Architecture

### Service Components

**Metallic Control Plane (SaaS):**
- Multi-tenant CommServe instances
- Hosted on Azure (primarily)
- SOC 2 Type II certified

**Metallic MediaAgent:**
- Hosted in Azure (for cloud-to-cloud backups)
- Or: Customer-deployed on-premises/in-cloud for on-prem workloads

**Metallic Storage:**
- Azure Blob (Metallic-managed, globally replicated)
- WORM-enabled (time-based retention policies)
- Or: Customer's own storage (BYOS)

### M365 Protection Architecture

```
Microsoft 365 (Exchange/SharePoint/OneDrive/Teams)
    ↓ [Microsoft Graph API]
Metallic MediaAgent (in Azure)
    ↓
Azure Blob Storage (WORM-enabled)
    ↑
Metallic Control Plane (CommServe SaaS)
```

- No on-premises components needed for M365 protection
- Authentication: Azure AD application registration with required Graph API scopes
- Scopes required: `Mail.ReadWrite`, `Sites.Read.All`, `Files.ReadWrite.All`, etc.

### Salesforce Protection

```
Salesforce Org
    ↓ [Salesforce API]
Metallic MediaAgent (in cloud)
    ↓
Metallic Storage
```

- Supports: Objects, records, files, metadata, field history
- Restore: Full org, specific object types, individual records
- Daily protection minimum; up to hourly for critical orgs

---

## Cloud Rewind Architecture

### Configuration Capture

Commvault periodically inventories cloud infrastructure configuration:

**AWS resources captured:**
- VPC topology (subnets, route tables, internet gateways, NAT gateways)
- Security groups and NACLs
- EC2 instance configurations (type, IAM role, tags, key pairs)
- IAM roles and attached policies
- Route 53 zones and records
- ELB/ALB configurations
- RDS configurations (engine, parameter groups, option groups)
- S3 bucket policies and configurations

**Capture frequency:** Configurable; default daily; can be event-driven via AWS EventBridge

**Storage:** Configuration state snapshots stored in CommServe database + cloud storage (small JSON/YAML representations; not data)

### Recovery Process

Cloud Rewind recovery proceeds in this order:

1. **Network infrastructure**: VPC, subnets, route tables, security groups, NACLs
2. **IAM**: Roles and policies (required for EC2 instances to assume roles on boot)
3. **DNS**: Route 53 records (required for service discovery)
4. **Compute**: EC2 instances (from Commvault backup data; most recent clean restore point)
5. **Load balancers**: ELB/ALB (with updated backend targets pointing to new instances)
6. **Database**: RDS instances (from Commvault database backup)

**Recovery target:**
- Same region (rebuilding after compromise)
- Different region (DR scenario)
- Different AWS account (cleanroom/forensics scenario)

### Infrastructure-as-Code Export

Cloud Rewind can export captured configuration as:
- CloudFormation templates (AWS)
- Terraform (planned/limited support)
- ARM templates (Azure)

This allows "immutable infrastructure" recovery: deploy fresh infrastructure from template, then restore data on top.

---

## Cleanroom Recovery Architecture

### Provisioning

When Cleanroom Recovery is triggered:

**AWS Cleanroom:**
1. Commvault uses its own AWS sub-account (managed by Commvault) or customer's dedicated cleanroom account
2. Provisions VPC with no external peering
3. Provisions EC2 instances (restored from backup)
4. Provisions RDS instances (if included in cleanroom)
5. Cleanroom has internet access via NAT (for patching) but no VPN back to customer production

**Azure Cleanroom:**
1. Provisions Azure VNet (isolated)
2. Provisions VMs from Azure backup or Commvault backup
3. No VNet peering to production Azure subscriptions

### Access to Cleanroom

Customer accesses cleanroom via:
- Commvault Unity Platform portal (RDP/SSH proxy)
- Time-limited credentials generated per session
- All access logged

### Cleanroom Teardown

After testing/forensics:
- Cleanroom resources are destroyed (all cloud resources provisioned for cleanroom)
- Commvault logs teardown confirmation
- Cost management: Cleanroom costs accrue only during active use

---

## HyperScale X Architecture

### Node Architecture

Each HyperScale X node contains:
- Dual-socket Intel Xeon
- NVMe SSDs: DDB and metadata
- High-density HDDs: Backup data storage
- 10/25 GbE networking (redundant)

### Distributed Storage

- SpaceManager: Commvault's distributed storage layer within HyperScale X
- Data striped across all nodes (erasure coding)
- Node failure tolerance: 1-2 nodes depending on cluster size
- Scale-out: Add nodes; storage automatically rebalances

### Software Stack

HyperScale X runs full Commvault software:
- CommServe (embedded, manages the HyperScale X cluster)
- MediaAgent (distributed across all nodes)
- HyperScale Manager (hardware health monitoring)

**Management:**
- Commvault Command Center (browser-based)
- REST API (same as standard Commvault)
- Unity Platform integration
