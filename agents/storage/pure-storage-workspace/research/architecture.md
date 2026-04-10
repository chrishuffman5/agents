# Pure Storage FlashArray Architecture

## Overview

Pure Storage FlashArray (now marketed under the Everpure brand as of early 2026) is an enterprise all-flash block storage platform built entirely on proprietary DirectFlash technology and the Purity operating environment. Unlike legacy arrays that layer flash media into HDD-centric architectures, FlashArray was designed from the ground up for flash, exposing NVMe natively at the array level and managing flash globally in software rather than per-device.

---

## FlashArray Model Family

### FlashArray//X
- Primary positioning: Mission-critical, high-performance workloads
- 100% NVMe with DirectFlash Modules (DFMs)
- Supports NVMe-oF (RoCE and TCP), Fibre Channel, and iSCSI host connectivity
- The R5 generation (generally available 2025) uses Emerald Rapids processors, delivering ~30% performance improvement over the R4 generation
- FlashArray//X 90 R3 demonstrated 20% more TPS and 30-35% lower max latency vs. iSCSI when using NVMe/TCP

### FlashArray//XL
- Positioning: Highest performance at extreme scale
- Built for organizations that have outgrown //X capacity or performance headroom
- FlashArray//XL 190 (GA target: Q4 FY26, approximately February-April 2026)
- Supports the same DFM ecosystem as //X with larger controller and interconnect headroom

### FlashArray//C
- Positioning: Capacity-optimized, enterprise file and general-purpose workloads
- Up to 16.3 PB effective capacity
- NVMe and NVMe-oF connectivity
- R5 generation delivers ~40% performance improvement over R4
- Balances cost-per-TB with all-flash performance; replaces tiered/hybrid arrays

### FlashArray//E
- Positioning: High-density archival and cold-tier flash storage
- Targets workloads benefiting from flash resiliency, density, and power efficiency
- Uses DirectFlash at higher density points for lowest $/TB in the FlashArray family
- Purity//FA 6.6.0 released specifically to enable FlashArray//E capabilities

### FlashArray//ST (Storage Tier)
- Newer addition to the family; does not use DFMs—uses conventional SSDs
- Up to 400 TB usable capacity
- Delivers 18 million IOPS with 200 GB/s throughput
- Purity OS provides snapshots, writable clones, and replication

---

## Purity Operating Environment (Purity//FA)

Purity OS is the foundational software layer running on all FlashArray systems. It implements all enterprise data services in software rather than dedicated hardware ASICs, enabling consistent capability across generations and non-disruptive upgrades.

**Key capabilities delivered by Purity:**
- Inline deduplication, compression, and pattern removal (always-on, never a toggle)
- Global wear leveling and bad block management across all DFMs in the array
- I/O scheduling and QoS — continuous, non-intrusive, no hard caps required
- Snapshot and clone management (writable clones, snapshot schedules)
- Replication (async, synchronous, continuous)
- File services: NFS v3/4.0/4.1 and SMB
- vVols: Multiple vVol storage containers per array (since Purity 6.4.1)
- S3 object protocol support (introduced in recent Purity releases)
- Always-on encryption (AES-256 at rest)
- SafeMode immutable snapshots
- Non-disruptive upgrades (NDU) — controllers and DFMs can be swapped live

**Current release track:** Purity//FA 6.6.x (2025). All Purity versions are backwards compatible with prior array generations supported under the Evergreen model.

---

## DirectFlash Technology

### DirectFlash Modules (DFMs)
DFMs are Pure's proprietary flash media form factor. Unlike commodity SSDs, DFMs contain only NAND flash cells — no embedded controller, no onboard DRAM, no per-device FTL (Flash Translation Layer). All controller functions are executed globally by Purity OS:
- Wear leveling done at the array level across all DFMs simultaneously
- Garbage collection and overprovisioning managed globally — more efficient than per-SSD management
- Bad block management tracked centrally

**Capacity milestones:** 75 TB and 150 TB DFMs are shipping; 300 TB DFMs targeted for end of 2025.

**Reliability claims:** DFMs are rated 6x more reliable than HDDs and 3x more reliable than enterprise SSDs. Storage density doubles year-over-year following Pure's roadmap.

**Efficiency vs. SSDs:**
- 2-5x more capacity-efficient than COTS SSDs
- 2-3x better storage density
- 39-54% fewer watts per TiB vs. competitors (documented as of August 2025)

### DirectFlash Software (DFS)
The software layer within Purity that manages the DFMs:
- Provides deterministic I/O scheduling — latency predictability is a design goal
- Eliminates the SSD "write cliff" phenomenon caused by per-device garbage collection storms
- Enables global overprovisioning optimization — less wasted flash headroom than per-SSD overprovisioning

---

## Always-On Data Reduction

FlashArray performs data reduction inline on every write — it is never optional or schedulable:
- **Deduplication:** Global deduplication across all volumes on the array
- **Compression:** LZ4-based compression on deduplicated data
- **Pattern removal:** Zero-block detection and elimination

Average effective data reduction ratio: 5:1 (published by Pure; actual ratios depend on workload). Data reduction ratios are shown in real-time on the array dashboard and in Pure1.

---

## ActiveCluster — Synchronous Replication

ActiveCluster is Pure's active/active synchronous replication solution, providing zero RPO and zero RTO across two FlashArray systems.

### Core Architecture
- Two FlashArrays form a stretch cluster; both serve read and write I/O simultaneously
- Data is written synchronously to both arrays before acknowledging to the host
- Volumes are organized into **stretched pods** — logical containers that span both arrays

### Mediator
The Pure1 Cloud Mediator is the arbitration component required to resolve split-brain scenarios. It is hosted by Pure as a SaaS service, eliminating the need for customers to deploy a third-site VM:
- Default and recommended configuration
- An on-premises mediator VM is also available for environments without cloud connectivity
- Starting with Purity 5.3, a built-in Mediator polling and pre-election mechanism handles scenarios where both arrays lose mediator connectivity

### Network Requirements
- Maximum 11 ms round-trip latency between the two FlashArrays
- Minimum 4x 10GbE replication ports per array (2 per controller)
- Redundant switched replication network required — direct connections not supported
- Bandwidth must support synchronous writes plus resynchronization traffic

### Topology Modes
- **Uniform:** Hosts at both sites have access to storage at both sites via stretched FC fabrics. Full active/active with cross-site path failover. More complex network design.
- **Non-Uniform:** Hosts access only their local array. Simpler design; failover requires host I/O path reconfiguration. Suitable for DR configurations.

### ActiveCluster for File
Purity now supports ActiveCluster for NFS file shares in addition to block volumes, providing synchronous replication and transparent mobility for file workloads.

---

## ActiveDR — Continuous Asynchronous Replication

ActiveDR is Purity's continuous asynchronous replication option, distinct from schedule-based protection group replication:
- Near-zero RPO (typically seconds, not minutes)
- Data is streamed to the target array continuously — no wait for snapshot interval
- No write performance impact on source hosts (unlike synchronous replication)
- Supports test failovers without interrupting replication
- Target volumes can be promoted (failed over) with a single CLI/API command
- Snapshot history is replicated along with live data

---

## Pure1 — AIOps and Management Platform

Pure1 is Pure Storage's cloud-based SaaS management and AIOps platform. All FlashArray systems phone home to Pure1 continuously.

### Pure1 Meta AI
- Analyzes telemetry from across Pure's global installed base (trillions of data points daily)
- Provides predictive analytics: capacity forecasting, performance trending, anomaly detection
- **Workload Planner:** Recommends hardware upgrades based on projected workload growth
- **VM Analytics:** Maps VM-level performance to storage-level metrics
- Proactively resolves 70%+ of issues before they cause downtime
- Automatically opens support cases when problems are detected

### AI Copilot (2025-2026)
- Natural-language interface to storage management operations
- Integrated with Model Context Protocol (MCP) connectivity for programmatic access
- Workflow Orchestration with production-ready templates (announced at Accelerate 2025)
- Pure1 AI Copilot MCP integration targeted for GA in Q4 FY26

### Active Replication Monitoring
- Near real-time replication configuration health tracking
- Monitors ActiveCluster configuration health and cloud mediator state
- Continuous lag monitoring for ActiveDR and FlashBlade object replication

---

## Evergreen Subscription Model

Pure's Evergreen architecture is the commercial and operational model that eliminates forklift upgrades:

### Evergreen//Forever
- Perpetual license model with ongoing hardware refresh
- Controllers are upgraded non-disruptively (no data migration required)
- DFMs can be retained at end of controller refresh cycle

### Evergreen//Flex
- Flexible term subscriptions
- Options: NR-Capacity (retain DFMs) and NR-Components (retain controllers/chassis)

### Evergreen//One (STaaS)
- Storage-as-a-Service: Pure owns and manages all hardware/software on-premises
- Customer pays per TiB consumed per month
- SLA guarantees: 99.9999% availability, performance SLAs, energy efficiency SLA (unique in STaaS — maximum watts per TiB)
- Named a Leader in the 2025 Gartner Magic Quadrant for Infrastructure Platform Consumption Services
- Each Evergreen//One instance is coordinated through Pure Fusion

---

## Pure Fusion — Autonomous Storage Delivery

Pure Fusion is an autonomous storage management control plane layered above individual arrays:
- Abstracts multiple FlashArrays and FlashBlades into unified storage pools
- Enables self-service storage provisioning for application teams via APIs/GUI
- Integrates with Pure1 Meta for AI-driven workload placement recommendations
- Supports SafeMode, snapshots, async replication, ActiveCluster, ActiveDR, and snapshot offload
- Powers the Evergreen//One STaaS operating model — each STaaS deployment is coordinated by Fusion

---

## Pure Storage CSI Driver (Kubernetes Integration)

Pure Service Orchestrator (PSO) / Pure Storage CSI Driver provides Kubernetes-native dynamic storage provisioning:
- Supports both FlashArray (block) and FlashBlade (file/object) backends
- CSI 1.x compliant — standard interface for all major Kubernetes distributions
- Deployed via Helm charts (`purestorage/helm-charts` on GitHub)
- Features: topology-aware provisioning, volume cloning, snapshots, QoS policy assignment
- Automatically selects the best array based on capacity, performance load, health, and policy tags
- Metadata (volumes, hosts, IQNs, attachments) stored persistently in the operator

---

## FlashBlade — File and Object Storage (Companion Platform)

FlashBlade is Pure's parallel file and object storage system, complementing FlashArray for unstructured data:
- Delivers high-bandwidth, parallel access for AI/ML training, analytics, and backup targets
- FlashBlade//EXA (2025): 2x faster MLPerf performance than nearest competitor in under half a rack
- Purity//FB 4.6.3 introduces multi-tenancy for object storage (secure logical isolation per tenant)
- Acts as a snapshot offload target for FlashArray protection group snapshots
- Supported as a backend by the Pure Storage CSI driver
- Integrated with Portworx for Kubernetes workloads requiring file access

---

## Portworx Integration

Portworx (acquired by Pure Storage) provides cloud-native storage and data management for Kubernetes:
- Manages storage and data protection for containerized workloads regardless of deployment location
- Supports FlashArray (block) and FlashBlade (file/direct access) as storage backends
- Portworx expanding to add durability to AWS instance stores (December 2025 update)
- CSI topology support for zone-aware volume placement across FlashArray and FlashBlade
- Pure CoPilot: AI-driven recommendations for Kubernetes storage management

---

## References
- Pure Storage FlashArray Product Page: https://www.purestorage.com/products/block-file-object-storage.html
- Purity Data Sheet: https://www.purestorage.com/products/storage-software/purity/data-sheet.html
- FlashArray//X Data Sheet: https://www.purestorage.com/products/unified-block-file-storage/flasharray-x/data-sheet.html
- FlashArray//C Data Sheet: https://www.purestorage.com/products/unified-block-file-storage/flasharray-c.html
- DirectFlash Explained: https://www.purestorage.com/knowledge/what-is-directflash-and-how-does-it-work.html
- ActiveCluster Data Sheet: https://www.purestorage.com/content/dam/pdf/en/datasheets/ds-purity-activecluster.pdf
- Pure1 AIOps: https://www.purestorage.com/products/aiops/pure1.html
- Evergreen//One: https://www.purestorage.com/products/staas/evergreen/resources.html
- Pure Fusion Blog: https://blog.purestorage.com/perspectives/pure-fusion-expands-industry-first-autonomous-storage-delivery-platform/
- Portworx on Pure: https://docs.portworx.com/portworx-enterprise/platform/install/pure-storage
