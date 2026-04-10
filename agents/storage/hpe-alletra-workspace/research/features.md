# HPE Alletra Features

## Product Line History: From Nimble/3PAR/Primera to Alletra

### Consolidation Timeline

| Year | Event |
|------|-------|
| 2017 | HPE acquires Nimble Storage ($1.09B); gains CASL architecture and InfoSight AIOps |
| 2002-2016 | HPE 3PAR builds reputation as Tier-1 SAN platform (acquired 2010) |
| 2019 | HPE Primera launched as 3PAR successor (mission-critical, always-on) |
| 2021 | HPE Alletra announced; Alletra 6000 = Nimble rebranded/evolved; Alletra 9000 = Primera rebranded/evolved |
| 2022 | GreenLake for Block Storage launched on Alletra MP platform |
| 2023 | HPE Alletra Storage MP B10000 (block/file) and X10000 (object) formally expand the Alletra MP line; file, block, and data protection services consolidated |
| 2025 | HPE discontinues Qumulo, Scality, WEKA partnerships; commits fully to own storage IP; B10000 scales to 4 nodes switchless; X10000 GA with Veeam; Data Intelligence Nodes announced |

### What Replaced What

| Legacy Product | Alletra Replacement | Notes |
|---------------|---------------------|-------|
| HPE Nimble Storage (HF-series) | Alletra 5000 | Hybrid flash, CASL architecture retained |
| HPE Nimble Storage (AF-series) | Alletra 6000 | All-NVMe, CASL re-engineered for NVMe, PCIe Gen4 |
| HPE Primera | Alletra 9000 | All-NVMe, Primera OS and ASIC acceleration retained |
| HPE 3PAR | Alletra 9000 (migration target) | Trade-Up programs; 3PAR EOL path |
| (New platform) | Alletra Storage MP B10000 | Disaggregated block+file; no predecessor |
| (New platform) | Alletra Storage MP X10000 | Disaggregated object; VAST Data technology |

---

## Current Capabilities by Product Line

### Alletra 5000 — Key Features

**Data Protection:**
- Triple Parity RAID (protects against 3 simultaneous drive failures)
- 99.9999% data availability (six nines)
- Hardware-accelerated inline data reduction (deduplication + compression)
- Volume-level snapshots with configurable schedule and retention
- Synchronous replication (RPO=0, performance impact) and asynchronous replication (snapshot-based, minimal impact)
- Volume Collections for group-consistent snapshots and replication across multiple volumes

**Storage Efficiency:**
- Inline deduplication, compression, and thin provisioning enabled by default
- Effective-to-raw ratios commonly 5:1 to 10:1 depending on workload
- Variable block size storage via CASL eliminates the need to pre-tune block size per workload

**Connectivity:**
- iSCSI (1/10/25GbE)
- Fibre Channel (8/16/32 Gb)
- NFS and SMB (via HPE Nimble Storage File Services add-on)

**dHCI Integration:**
- Alletra 5000 certified for HPE dHCI deployments with ProLiant servers
- vCenter plugin for unified compute + storage management
- Independent scale of compute nodes and storage

**Management:**
- HPE InfoSight portal (cloud-based, Nimble-lineage unified dashboard)
- REST API for automation
- vCenter plugin (VMware) and Hyper-V integration

---

### Alletra 6000 — Key Features

**Performance:**
- All-NVMe drives; PCIe Gen 4 internal bus
- Up to 3x performance improvement vs. Nimble predecessor
- Configurable IOPS and bandwidth limits per volume (Quality of Service)
- Performance policies: pre-defined workload templates (Exchange, SQL, Oracle, VMware, etc.)
- Active-active dual controller; reads and writes served from either controller simultaneously

**Data Protection (same as 5000 but on NVMe):**
- Triple+ Parity RAID
- Inline deduplication and compression
- Synchronous and asynchronous replication
- Snapshot scheduling per Volume Collection

**Scale:**
- Scale-out grouping: up to 4 arrays in a group, presenting as a single logical system
- Linear performance scaling as arrays are added to a group
- 6010 (entry): 92 TiB raw — 6080 (high-cap): 4,416 TiB raw / 16,400 TiB effective

**Connectivity:**
- iSCSI (1/10/25GbE)
- Fibre Channel (8/16/32 Gb)

**Management:**
- InfoSight portal with performance-per-VM/application analytics
- REST API and CSI Driver for Kubernetes
- Commvault, Veeam, NAKIVO, NetBackup integration for snapshot-based backup

---

### Alletra 9000 — Key Features

**Mission-Critical Design:**
- All-NVMe; 100% active-active across up to 4 controller nodes
- Sub-250-microsecond latency guarantee (75th+ percentile of I/O)
- Zero-downtime firmware and OS updates (rolling node-by-node)
- 100% data availability guarantee from HPE with financial backing

**Replication:**
- Active Peer Persistence: synchronous, zero-RPO/RTO; LUNs share WWN across two sites, transparent failover
- Asynchronous periodic replication: snapshot-and-delta-resync, minimal host impact
- Supports up to metropolitan distances for synchronous replication

**SAP HANA Certified:**
- Validated for SAP HANA scale-out configurations (up to 96 nodes)
- Consistent sub-millisecond latency for HANA workloads

**VMware Integration:**
- vSphere Metro Storage Cluster (vMSC) supported with Peer Persistence
- VASA provider for storage policy-based management
- vVols (VMware Virtual Volumes) support

**Protocols:**
- Fibre Channel (8/16/32 Gb)
- iSCSI (10/25GbE)

**Models:**
- 9060: 2 or 4 nodes, max 144 NVMe drives, up to 721 TB raw
- 9080: 2 or 4 nodes, max 144 NVMe drives, up to 721 TB raw (higher performance CPU configs)

---

### Alletra Storage MP B10000 — Key Features

**Architecture Advantages:**
- Industry's only disaggregated scale-out block and file storage with 100% availability guarantee
- Compute and capacity scale independently (DASE architecture)
- No storage fabric/switch required between nodes (point-to-point, switchless at 2-4 nodes as of 2025)
- All nodes active for I/O; no active-standby waste

**Block Storage:**
- Fibre Channel, iSCSI, NVMe/TCP protocols
- Thin provisioning, inline deduplication, compression
- Active Peer Persistence: zero RPO/RTO across two sites, campus distance, with third-site Quorum Witness
- Non-disruptive data-in-place upgrades (no forklift upgrades)

**File Storage:**
- NFS v3/v4.1 via HPE CSI Driver 3.0.0+ integration
- Managed from same DSCC cloud console as block
- File Services provisioned via Kubernetes PVC workflows

**Cloud-Native:**
- No on-premises management software stack; managed via DSCC in HPE GreenLake cloud
- AIOps with high-frequency telemetry, anomaly detection, prescriptive remediation
- REST API; Terraform provider for infrastructure-as-code
- HPE CSI Driver for Kubernetes: Helm/Operator installation, StorageClass-based provisioning

**Snapshot-to-StoreOnce Backup:**
- Direct integrated backup from B10000 snapshots to StoreOnce 3720/3760/5720/7700 appliances
- StoreOnce Catalyst deduplication and compression
- Veeam integration validated

**OpenShift / Red Hat Certification:**
- Certified for Red Hat OpenShift container platform
- CSI Driver deployed via Operator Hub

---

### Alletra Storage MP X10000 — Key Features

**Object Storage at Scale:**
- S3-compatible API; scale terabytes to exabytes
- S3 over RDMA for GPU server acceleration (AI/ML training data pipelines)
- Disaggregated compute + NVMe capacity; scale each independently
- VAST Data-licensed disaggregated architecture

**Backup Acceleration:**
- Data Protection Accelerator (DPA) Nodes: integrated deduplication and compression
- StoreOnce Catalyst engine embedded; "world's fastest backup storage" positioning
- Veeam Backup & Replication validated (GA August 2025)
- Zerto backup integration added in August 2025 upgrade
- Intelligent inline source-side deduplication reduces data transferred and stored

**AI/ML Integration:**
- Data Intelligence Nodes (available Q1 2026): Nvidia L40S GPUs
- Automates metadata extraction and vector embedding creation
- Runs AI pipelines directly on the storage platform
- Designed for AI inferencing workloads

**Management:**
- HPE GreenLake cloud console
- Unified with B10000 in DSCC operational experience

---

## GreenLake Consumption Model

### HPE GreenLake for Block Storage

HPE GreenLake converts on-premises storage capital expenditure into a consumption-based, as-a-service model:

**Pricing Model:**
- Pay-per-use: billed based on actual consumed capacity (TB consumed per month)
- Buffer capacity pre-installed on-site; customer pays only for what they use above a committed baseline
- No forklift upgrades; capacity automatically added as consumption grows
- HPE installs, owns, and maintains the hardware infrastructure

**Committed vs. Burst:**
- Committed tier: pre-agreed minimum monthly consumption, lower unit price
- Burst tier: above committed, billed at higher rate per TB
- Rebalance services available to right-size committed levels

**Included Services:**
- HPE GreenLake cloud platform access (DSCC management console)
- InfoSight AIOps and Wellness Dashboard
- HPE Pointnext Complete Care: tier-less, collaborative support with proactive monitoring
- Hardware refresh on defined cycles (no forklift replacement costs)

**Deployment Models:**
- On-premises (most common): hardware at customer site, managed via GreenLake cloud
- Co-location: GreenLake equipment in third-party data centers
- Edge deployments: supported for remote/branch use cases

### HPE Pointnext Services

- Complete Care: proactive, personalized support; dedicated Technical Account Manager; 24x7 coverage
- Installation and Startup Services: deployment, zoning, host integration, cloud onboarding
- Replication Software Installation and Startup: Remote Copy Group configuration, Peer Persistence setup
- Software and Firmware maintenance included in base GreenLake subscription

---

## Data Reduction and Efficiency Features

| Feature | 5000 | 6000 | 9000 | MP B10000 |
|---------|------|------|------|-----------|
| Inline Deduplication | Yes | Yes | Yes | Yes |
| Inline Compression | Yes | Yes | Yes | Yes |
| Thin Provisioning | Yes | Yes | Yes | Yes |
| Variable Block Size (CASL) | Yes | Yes | No (NVMe-native) | No |
| Data-at-Rest Encryption | Yes | Yes | Yes | Yes |
| FIPS Drives Available | Yes | Yes | Yes | Yes |

---

## Multi-Protocol and Host Connectivity

| Protocol | 5000 | 6000 | 9000 | MP B10000 | MP X10000 |
|----------|------|------|------|-----------|-----------|
| Fibre Channel | Yes | Yes | Yes | Yes | No |
| iSCSI | Yes | Yes | Yes | Yes | No |
| NVMe/TCP | No | No | No | Yes | No |
| NFS | Limited | Limited | No | Yes | Yes (S3+NFS) |
| S3 Object | No | No | No | No | Yes |
| RDMA | No | No | No | No | Yes |

---

## Ecosystem Integrations (Current as of 2025-2026)

**Hypervisors:**
- VMware vSphere (all models): VASA, vVols, vSphere Metro Storage Cluster (vMSC with Peer Persistence)
- Microsoft Hyper-V (5000/6000): InfoSight VM-level analytics

**Backup Software:**
- Veeam Backup & Replication: snapshot integration, HPE Storage Plugin, validated on all models
- Commvault: snapshot-based backup for 5000/6000
- NAKIVO: snapshot integration
- Veritas NetBackup: Snapshot Manager plugin for 9000

**Kubernetes/Containers:**
- HPE CSI Driver: all models, Helm + Operator installation
- Red Hat OpenShift: certified, available via OperatorHub
- HPE Morpheus: cloud management platform integration with CSI Driver

**Orchestration/Automation:**
- Terraform provider via HPE GreenLake
- Ansible playbooks (HPE community supported)
- REST API on all models
