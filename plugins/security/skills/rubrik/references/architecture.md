# Rubrik Architecture Reference

## Rubrik Cluster (On-Premises CDM)

### Physical Architecture

A Rubrik cluster consists of 4+ nodes in a shared-nothing distributed architecture. All nodes are equal peers; there is no dedicated primary node for data functions.

**Node components:**
- CPU: Dual-socket Intel Xeon
- RAM: 256-512 GB per node
- Flash (metadata): SSD tier for metadata and hot data cache
- HDD (capacity): High-density SATA for bulk backup data
- Networking: 10 GbE or 25 GbE

**Node scaling:**
- Minimum: 4 nodes (3 nodes for small editions in some models)
- Maximum: 32 nodes per cluster
- Scale-out: Add nodes online; data automatically rebalances

**Erasure coding:**
- Data is erasure-coded across nodes (not simple replication)
- Default: Can sustain 1-2 node failures depending on cluster size
- Metadata: Replicated 3x for higher durability

### Atlas Distributed Filesystem

Atlas is Rubrik's proprietary distributed filesystem, designed specifically for backup data.

**Design principles:**

1. **Immutable object store**: Objects are written once and never modified. All "modifications" create new versions.

2. **No POSIX interface**: Atlas does not implement POSIX semantics. There is no `open()`, `write()`, `delete()` syscall path to backup data. Administrative access to the underlying OS cannot reach the backup data objects.

3. **Garbage collection model**: Objects are marked for deletion when all snapshots referencing them have expired. Actual deletion occurs during GC cycles. This means there is no instant-delete capability even for expired data.

4. **Metadata separation**: All metadata (snapshot catalog, object index, filesystem tree) is stored separately from data objects and replicated independently.

**Data path (write):**
1. Agent or connector reads changed blocks from source
2. Blocks are deduplicated against existing content (inline dedup)
3. Deduplicated chunks are compressed
4. Chunks are encrypted (AES-256)
5. Encrypted chunks are written to Atlas as immutable objects
6. Metadata (snapshot catalog entry, filesystem tree entry) is written and replicated

**Data path (read/restore):**
1. Request references snapshot ID
2. Rubrik resolves snapshot ID to list of Atlas object IDs
3. Objects are read from Atlas, decrypted, decompressed
4. Data assembled and streamed to restore destination

### Node-Level Security

Even if an attacker gains root access to a Rubrik node OS:
- Cannot access Atlas data objects (no filesystem path)
- Cannot delete snapshots (no direct DB write; changes must go through Rubrik API with valid auth token)
- Cannot disable services persistently (Rubrik node OS is read-only; changes don't survive reboot)
- Node configuration is cryptographically signed; tampering detected on boot

**Hardened OS characteristics:**
- Read-only root filesystem
- No standard package manager (cannot install tools)
- No persistent shell sessions for administrative tasks
- All legitimate admin is done through Rubrik's management interface or CDM REST API

## Rubrik Cloud Data Management (CDM)

CDM is the software stack running on Rubrik cluster nodes (or cloud instances).

### CDM Version 9.x Architecture

**CDM processes:**

| Service | Responsibility |
|---|---|
| Backup Engine | Source data reading, deduplication, scheduling |
| Atlas Service | Distributed filesystem operations |
| Recovery Engine | Restore, Live Mount, export operations |
| Anomaly Detection Engine | ML-based analysis of snapshot deltas |
| Classification Engine | Sensitive data scanning |
| Replication Service | Cluster-to-cluster replication |
| Archival Service | Cloud tiering |

**Communication:**
- CDM nodes communicate over a dedicated cluster network (separate from backup data network)
- All inter-node communication is mTLS encrypted
- Rubrik Security Cloud (SaaS) communicates with CDM via outbound HTTPS; CDM initiates connection (no inbound from internet required)

### Software Update Model

CDM updates are delivered as signed firmware-like packages:
- CDM nodes updated one at a time (rolling update; no downtime)
- Update package is cryptographically signed by Rubrik
- Node OS is replaced atomically (not patched in place)
- Configuration persists across updates

## Rubrik Security Cloud (SaaS Management Plane)

### Architecture Overview

Security Cloud (formerly Polaris) is a multi-tenant SaaS platform hosted in Rubrik's cloud infrastructure (AWS).

**Components:**
- **Security Cloud UI**: React-based web application
- **Security Cloud GraphQL API**: All operations exposed via GraphQL
- **Collective Intelligence**: Anonymized telemetry aggregation across all Rubrik customers
- **Threat Intelligence feeds**: Rubrik-curated IOC and threat indicator database

**CDM ↔ Security Cloud integration:**
- CDM clusters establish outbound HTTPS connection to Security Cloud
- CDM pushes snapshot metadata, anomaly scores, and events to Security Cloud
- Security Cloud pushes policy changes and threat intelligence to CDM
- No inbound connections from Security Cloud to CDM (firewall-friendly)

### Polaris GPS (Global Policy Service)

GPS manages data protection policies across multiple CDM clusters from a single interface.

**Policy hierarchy:**
```
Security Cloud Organization
└── SLA Domain (e.g., "Gold - 30 day")
    ├── Retention rules (hourly/daily/weekly/monthly/yearly)
    ├── Replication rule (target cluster)
    ├── Archival rule (cloud target + retention)
    └── Applied to: VM tags, database names, file patterns
```

**Multi-cluster policy management:**
- Define SLA domain once in Security Cloud
- Push to any/all CDM clusters
- Compliance reports across all clusters in one view

### Collective Intelligence (CI)

Rubrik aggregates anonymized metadata from all customer CDM deployments to improve anomaly detection:
- No customer data leaves the cluster; only behavioral metadata (file count deltas, entropy scores, job statistics)
- ML models trained on anomaly patterns seen across the entire customer base
- New ransomware variants detected by one customer's cluster improve detection for all clusters

## Anomaly Detection Architecture

### Data Collection

For each snapshot, CDM computes:
- `file_count_delta`: Absolute and percentage change in file count
- `file_size_delta`: Change in total file size
- `entropy_delta`: Change in average file entropy across the snapshot
- `extension_change_ratio`: Percentage of files with changed extensions
- `deletion_spike`: Number of deleted files vs. rolling baseline

### ML Model

- Model type: Ensemble (gradient boosting + rule-based thresholds)
- Training data: Known-ransomware snapshots (labeled), known-clean snapshots (labeled)
- Feature set: The delta metrics above, time-of-day, day-of-week (to normalize backup windows)
- Inference: Runs on each new snapshot within minutes of snapshot completion
- Model updates: Distributed by Rubrik via Security Cloud on regular cadence

### Alert Routing

Anomaly alerts can be delivered to:
- Security Cloud portal (always)
- Email (SMTP configuration in Security Cloud settings)
- Webhook (JSON POST to configured URL -- integrates with Slack, Teams, PagerDuty, custom SIEM)
- SNMP trap
- Syslog (CEF/LEEF format for SIEM ingestion)
- ServiceNow (native integration)
- Splunk (Rubrik app for Splunk)

## Data Classification Engine

### Architecture

Classification runs against backup snapshots asynchronously (not in the backup data path).

1. Classification job scheduled per policy (on-demand or periodic)
2. Engine mounts snapshot read-only via internal mechanism
3. File content scanned against classifier patterns
4. Results stored in Security Cloud metadata database
5. Sensitive file locations reported in Security Cloud UI

### Classification Categories (Built-in)

| Category | Standard | Examples |
|---|---|---|
| PII - US | Various | SSN, DL#, passport, full name + DOB |
| PII - EU | GDPR | National ID numbers for EU member states |
| PHI | HIPAA | MRN, diagnosis codes, health plan IDs |
| PCI | PCI-DSS | Luhn-validated card numbers, CVVs |
| Financial | SOX | Account numbers, routing numbers, financial statements |

### Custom Classifiers

`Data Management > Classification > Custom Policies > Add Classifier`
- Type: Regular expression
- Test against sample data in the UI before deploying
- Example: Employee ID pattern: `EMP-\d{6}`
- False positive rate matters: overly broad patterns create noise

## Cloud Archival Architecture

### Supported Archive Targets

- Amazon S3 (standard, IA, Glacier)
- Microsoft Azure Blob (hot, cool, archive)
- Google Cloud Storage
- Hitachi Content Platform
- NFS

### Archive Immutability

For S3 archives:
- Rubrik can write to S3 buckets with Object Lock enabled
- Compliance mode recommended
- Rubrik sets object-level retention equal to archival retention policy

### Air-Gap via Cloud Archive

For organizations without a second CDM cluster:
- Archive to S3 in a separate AWS account (not the account where production runs)
- Use S3 Object Lock compliance mode
- Use IAM role with limited permissions (write + read, no governance bypass)
- This satisfies: offsite (different AWS account/region), immutable (Object Lock), isolated (separate account credentials)

## Rubrik NAS Backup

### Architecture for File Services Backup

- **Rubrik Cloud Cluster for NAS (RC4N)**: Rubrik-managed cloud instances for backing up NAS systems
- **Direct Archive**: Files can be archived directly to cloud storage with Rubrik managing the catalog
- **Fileset policies**: Granular inclusion/exclusion rules for file paths, types, sizes

### Incremental Forever

Rubrik uses incremental-forever backup for file services:
- First backup: Full snapshot
- Subsequent: Only changed files/blocks
- All snapshots appear as full (no chain dependency visible to user)
- Underlying deduplication removes redundancy across snapshots

## Replication Architecture

### Cluster-to-Cluster Replication

**Topology options:**
- One-to-one: Primary cluster → DR cluster
- One-to-many: Primary cluster → multiple regional DR clusters
- Many-to-one: Multiple primary clusters → central DR cluster

**Replication mechanism:**
- Changed blocks replicated after each snapshot
- WAN-optimized (deduplication across what the target already has)
- Encrypted in transit (TLS)
- Independent retention on replication target (can keep longer than primary)

**Replication lag monitoring:**
- Security Cloud dashboard shows replication lag per VM/SLA domain
- Alert when lag exceeds RPO target
- `Security Cloud > Data Protection > Replication > Lag Report`

### Live Mount on Replication Target

In a DR scenario:
- VMs can be Live Mounted directly on the replication target cluster
- No data transfer required (data already replicated)
- Boot from Rubrik cluster while production is unavailable
- Export (restore) to DR compute infrastructure when ready
