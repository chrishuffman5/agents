# HPE Alletra Architecture

## Product Family Overview

HPE Alletra is the unified storage brand that replaced and consolidated HPE Nimble Storage, HPE 3PAR, and HPE Primera into a single portfolio. The Alletra family spans from midrange hybrid-flash (5000) through all-NVMe enterprise (6000, 9000) to cloud-native disaggregated scale-out platforms (Storage MP B10000, X10000). All models are managed through HPE GreenLake cloud services and the Data Services Cloud Console (DSCC).

---

## Model Lineup

### HPE Alletra 5000 (Nimble-lineage, Hybrid Flash)

**Target Workload:** General-purpose workloads requiring cost-efficient flash performance; dHCI deployments.

**Architecture:**
- Derived from HPE Nimble Storage with CASL (Cache Accelerated Sequential Layout) architecture
- Dual-controller, active-passive configuration
- NVMe-based cache tier with high-capacity SAS/SATA HDDs or SSDs for capacity tier
- Triple+ Parity RAID data protection delivering 99.9999% data availability (six nines)
- Scale-out grouping: multiple arrays can be joined into a group for unified management
- Supports up to 6 ES3 expansion shelves, reaching up to 210 TB raw capacity per unit
- iSCSI and Fibre Channel connectivity

**Software Protection:**
- Triple Parity RAID eliminates single and dual drive failure as failure scenarios; a third simultaneous drive failure is also protected
- Synchronous and asynchronous replication via Volume Collections
- Snapshots with configurable retention schedules

**dHCI (Disaggregated HCI) Support:**
- HPE Alletra dHCI pairs Alletra 5000 arrays with HPE ProLiant DL servers managed as a hyperconverged cluster
- Compute and storage scale independently (unlike traditional HCI)
- Managed through HPE InfoSight and vCenter plugin
- Supported with VMware vSphere; eliminates the need to overprovision compute or storage together

---

### HPE Alletra 6000 (Nimble-lineage, All-NVMe)

**Target Workload:** Mixed business-critical workloads, mid-range OLTP, VDI, analytics.

**Architecture:**
- All-NVMe flash array derived from Nimble Storage design, reengineered for NVMe
- Dual-controller, active-active architecture using PCIe Gen 4 internal bus
- CASL architecture adapted for NVMe media; no spinning disk
- Triple+ Parity RAID protection (same protection model as 5000, extended for NVMe)
- Scale-out grouping across multiple arrays for linear capacity and performance scaling
- iSCSI and Fibre Channel protocols

**Performance:**
- Up to 3x the performance of predecessor Nimble arrays
- 6010 model: max 92 TiB raw / 330 TiB effective capacity
- 6080 model: max 4,416 TiB raw / 16,400 TiB effective capacity
- 99.9999% availability guarantee (less than 32 seconds downtime per year)

**Data Services:**
- Inline deduplication and compression
- Volume collections with synchronous and asynchronous replication
- Configurable performance policies per volume (IOPS and MB/s limits)
- Folder-based multi-tenancy within a group

---

### HPE Alletra 9000 (Primera-lineage, All-NVMe Mission Critical)

**Target Workload:** Tier-0 and Tier-1 mission-critical databases, SAP HANA, financial transaction systems.

**Architecture:**
- Derived from HPE Primera; all-NVMe with NVMe drives exclusively
- Multi-node clustered design: 2 or 4 controller nodes per system in a 4U chassis
- All nodes share direct access to the same pool of NVMe SSDs (shared-everything within a system)
- Multiple parallelized ASICs per controller handle I/O acceleration: zero-detect, SHA-256 hashing, XOR operations, cluster communications, data movement
- Uses PCIe Gen 3 internally (a known limitation vs. Gen 4 in the 6000)
- Active-active I/O across all nodes; system-wide automatic workload prioritization
- Maximum 144 NVMe SFF SSDs (including FIPS-encrypted and TAA variants)
- Supports 9060 and 9080 models

**Performance:**
- 4-node 9080 configuration: up to 2.1 million IOPS and 55 GB/s throughput in 4U
- Latency: 75% of I/O completes at 250 microseconds or better
- Supports up to 96 SAP HANA nodes per array

**RAID and Protection:**
- Advanced RAID protection (RAID-MP equivalent) across the NVMe drive pool
- Synchronous Active Peer Persistence replication (RPO=0, RTO=0) between two sites up to metropolitan distances
- LUNs present the same WWN from both sites; transparent to hosts
- Non-disruptive controller firmware updates (rolling one node at a time)

**Protocols:**
- Fibre Channel and iSCSI
- No NVMe/TCP (that is reserved for the Alletra MP B10000)

---

### HPE Alletra Storage MP B10000 (Cloud-Native, Disaggregated Block + File)

**Target Workload:** Enterprise block and file storage requiring cloud-native management, containers, Kubernetes, zero-downtime operations, AI/ML infrastructure.

**Architecture:**
- Entirely new disaggregated shared-everything (DASE) architecture; not derived from Nimble or Primera
- Scale-out compute nodes: starts at 2 nodes, expanded to 4 nodes (as of November 2025 update, switchless point-to-point connectivity between nodes, eliminating storage switch requirement)
- 2U chassis building blocks: each chassis holds dual AMD processors and up to 24 NVMe SSDs
- All nodes have direct access to all drives; all-active I/O processing (no active-standby)
- Compute (controller) and capacity (drives) scale independently — the core DASE advantage
- 100% data availability guarantee with no single point of failure

**Protocols Supported:**
- Fibre Channel (FC)
- iSCSI (IPv4 and IPv6)
- NVMe/TCP (B10000-exclusive; no IPv6 support)
- NFS file services (B10000-exclusive; requires HPE CSI Driver 3.0.0+)

**NVMe Storage:**
- All-NVMe drive pool shared across all compute nodes
- NVMe/TCP host protocol for lowest-latency host connectivity
- Scale capacity and performance independently by adding drive or compute nodes separately

**Replication:**
- Active Peer Persistence (APP): fully automated disaster recovery, zero RPO, symmetric topology up to campus distance, requires a third-site Quorum Witness
- Classic Peer Persistence (CPP): data-path resilience without automatic workload failover

**Cloud-Native Management:**
- Managed exclusively through HPE GreenLake cloud services
- Data Services Cloud Console (DSCC) / Data Ops Manager is the primary management interface
- No on-premises management software stack; cloud-first operational model
- AIOps via HPE InfoSight and GreenLake Wellness Dashboard
- REST API + HPE CSI Driver for Kubernetes automation

---

### HPE Alletra Storage MP X10000 (Cloud-Native, Disaggregated Object Storage)

**Target Workload:** Unstructured data at scale, AI/ML datasets, backup repositories, object storage, GPU-accelerated data pipelines.

**Architecture:**
- DASE (disaggregated shared-everything) architecture, licensed from VAST Data technology
- Scale from terabytes to exabytes on the same hardware platform
- All-NVMe storage layer with disaggregated compute nodes
- S3-compatible object storage with S3 over RDMA support (for GPU server acceleration)
- Data Protection Accelerator (DPA) Nodes: implement StoreOnce Store and Cloud Bank Storage technologies for integrated backup ingest
- Intelligent inline source-side deduplication, HPE StoreOnce Catalyst compression
- GA announced August 2025 with Veeam as first validated partner

**AI Data Intelligence Nodes (announced January 2026 availability):**
- Nvidia L40S GPU-equipped nodes integrated into X10000 chassis
- Automates metadata extraction, vector embedding creation, AI pipeline execution directly on storage
- Positions X10000 as an AI inferencing storage platform

**Backup Integration:**
- DPA Nodes connect X10000 object storage tier with StoreOnce deduplication
- High-speed write access to object storage for deduplicated and compressed backup data
- Validated with Veeam Backup & Replication

---

## InfoSight AI-Driven Operations

InfoSight is HPE's cloud-based AIOps platform embedded across the entire Alletra portfolio.

**Data Collection:**
- Continuously collects telemetry from 100,000+ HPE systems worldwide every second
- HPE Alletra Storage MP B10000 uses a new high-frequency sensor/metric telemetry metadata collection framework for enhanced analytics

**Core Capabilities:**
- Predictive analytics: identifies potential failures before they occur (predicts drive failures, controller issues, capacity exhaustion)
- Cross-stack correlation: correlates storage, server (VMware, Hyper-V), and network data to identify root cause across infrastructure layers
- Automated issue resolution: initiates support cases, contacts HPE proactively, and in some cases resolves issues without human intervention
- Anomaly detection on Alletra MP B10000: AI/ML-based detection of unusual patterns in real time
- Intelligent workflow automation and prescriptive remediation guidance

**Wellness Dashboard (GreenLake):**
- Signature-based wellness automation continuously analyzes incoming telemetry
- GreenLake Wellness Dashboard provides centralized view of wellness events, health insights, and prescriptive recommendations
- Available in Data Services Cloud Console for all Alletra MP B10000 systems

---

## Cloud-Native Management Stack

| Layer | Component | Details |
|-------|-----------|---------|
| Cloud Platform | HPE GreenLake | Consumption-based as-a-service delivery; unified operating model |
| Management Console | Data Services Cloud Console (DSCC) | Cloud-hosted; manages all Alletra MP systems; REST API access |
| AIOps | HPE InfoSight | Predictive analytics, anomaly detection, wellness automation |
| On-Prem Management | HPE InfoSight Portal (5000/6000/9000) | Local and cloud-accessible; operational dashboards |
| Container Integration | HPE CSI Driver for Kubernetes | Helm or Operator installation; StorageClass-based provisioning |
| Legacy GUI | Array Management (5000/6000/9000) | Per-array web UI for Nimble-lineage arrays |

---

## StoreOnce Backup Integration

HPE StoreOnce is the deduplication backup appliance line that integrates directly with Alletra storage.

**Integration Models:**
- Direct snapshot-to-StoreOnce: Alletra MP B10000 snapshots can be backed up directly to StoreOnce 3720, 3760, 5720, or 7700 appliances
- Alletra MP X10000 + DPA Nodes: StoreOnce Catalyst engine ingests, deduplicates, and compresses data; writes to X10000 object storage
- Veeam + StoreOnce Catalyst: validated integration for backup from Alletra arrays via Veeam Backup & Replication

**StoreOnce New Models (December 2025):**
- HPE StoreOnce 7700 (all-flash) and 5720 (high-end) added to the lineup
- Designed to support higher backup ingest rates from NVMe-backed Alletra MP systems

---

## HPE CSI Driver for Kubernetes

**Overview:** The HPE CSI Driver for Kubernetes provides StorageClass-based dynamic provisioning, snapshots, cloning, replication, and volume mutation across all Alletra models.

**Supported Arrays:**
- Alletra Storage MP B10000: port 443, WSAPI, `edit` or `super` role (LDAP supported from v2.5.2+)
- Alletra 9000/Primera/3PAR: port 443 (WSAPI) or port 8080 (3PAR), SSH for 3PAR
- Alletra 5000/6000/Nimble: port 5392 (REST API), `poweruser` or `administrator` role; multitenant via port 4431

**Installation:**
- Helm chart or Kubernetes Operator (standard)
- Object configuration files for OEM/partner customization

**Kubernetes Compatibility:**
- Minimum tested: Kubernetes 1.21
- Current support: Kubernetes 1.34, 1.35, OpenShift 4.20

**Protocol Support Matrix:**

| Protocol | 5000/6000 | 9000 | MP B10000 |
|----------|-----------|------|-----------|
| iSCSI | Yes | Yes | Yes |
| FC | Yes | Yes | Yes |
| NVMe/TCP | No | No | Yes |
| NFS | No | No | Yes |
| IPv6 | iSCSI only | iSCSI only | iSCSI only |
| Peer Persistence | No | CPP | APP + CPP |

**Replication in Kubernetes:**
- Active Peer Persistence (B10000): zero RPO/RTO for containers; requires three-site infrastructure with Quorum Witness; Pod Monitor labels required for failover
- Classic Peer Persistence (9000): data-path resilience only; no automatic workload failover
- Replication requires HPEReplicationDeviceInfos CRD and replication-enabled StorageClass
