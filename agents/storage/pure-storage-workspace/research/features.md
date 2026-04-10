# Pure Storage FlashArray Features

## Overview

FlashArray's feature set is delivered entirely through Purity OS — no separate license SKUs for enterprise capabilities. Every array, regardless of model or generation, receives the same data services. Features are upgraded through Purity OS software updates, which are non-disruptive and delivered automatically or on-demand through Pure1.

---

## Purity//FA Current Capabilities

### Data Reduction (Always-On Inline)
- **Global inline deduplication:** Cross-volume, global dedup across the entire array — not per-volume or per-pool
- **Inline compression:** LZ4-based, applied after deduplication on every write
- **Pattern removal (zero-block detection):** Eliminates zero-fill patterns before they consume flash capacity
- Data reduction is never optional, never schedulable, and cannot be disabled
- Published average reduction: 5:1 effective capacity multiplier; actual varies by workload
- Real-time data reduction ratio displayed on array dashboard and in Pure1

### Snapshots and Clones
- Space-efficient copy-on-write (COW) snapshots at the volume level
- Writable volume clones — instant, space-efficient clones for dev/test
- Protection group snapshots — consistent point-in-time copies of multiple volumes simultaneously
- Snapshot schedules: configurable frequency (per-minute to daily), retention periods, and offload targets
- SafeMode snapshots: immutable, cannot be deleted or modified by any user including array admin
- Eradication timer: configurable hold (default 24 hours, up to 30 days with SafeMode) before permanent deletion

### Replication
- **Async replication:** Protection-group-based, schedule-driven, RPO in minutes
- **ActiveDR (continuous async):** Streams data continuously to target; near-zero RPO (seconds), no schedule, no performance impact
- **ActiveCluster (synchronous):** Active/active, zero RPO, zero RTO — see architecture.md for full design details
- Replication targets: Remote FlashArray, Pure Cloud Block Store (AWS/Azure), FlashBlade (snapshot offload)

### File Services (Unified Block + File)
- NFS v3, v4.0, v4.1 support
- SMB support
- Unlimited filesystem size on a single array
- Unified policy management across block and file
- ActiveCluster for File: synchronous replication of NFS shares (Purity 6.x)

### S3 Object Protocol
- FlashArray now supports S3 as a native protocol (introduced in recent Purity releases)
- Enables object workloads on the same array as block and file — true unified storage
- Complements FlashBlade object for workloads requiring higher throughput

### VMware vVols
- vVols 2.0 compliant storage provider
- Multiple vVol storage containers per FlashArray (since Purity 6.4.1)
- Enables per-VM storage policy management via VMware vSphere Storage Policy-Based Management (SPBM)
- vVol snapshots and clones visible and manageable through vCenter

### NVMe-oF (NVMe over Fabrics)
- NVMe/RoCE (RDMA over Converged Ethernet) — low latency, high throughput
- NVMe/TCP — Ethernet-native, no special hardware required (default from Purity 6.4.2)
- NVMe/TCP delivers up to 35% lower latency than iSCSI in Pure's published benchmarks
- FlashArray//X R5 natively exposes NVMe to hosts; eliminates the protocol translation overhead of SCSI

### QoS (Quality of Service)
- Continuous, always-on QoS tuning — not hard caps
- Prevents individual workloads from monopolizing array resources
- Purity QoS integrates with Pure1 Meta Workload Planner for optimal placement decisions
- Per-volume IOPS and bandwidth limits can be set explicitly when isolation is required

### Encryption
- AES-256 encryption at rest — always-on, hardware-assisted
- Self-encrypting DFMs plus array-level key management
- FIPS 140-2 validated encryption
- Keys managed by Purity; external key management (KMIP) supported for regulated environments

### SafeMode (Immutable Snapshots — Ransomware Protection)
- Snapshots locked for a configurable period (24 hours default; up to 30 days)
- Eradication disabled for all users including array admins while SafeMode hold is active
- Only Pure Support can release a SafeMode lock after identity verification
- Introduced in Purity 6.x; enhanced in Purity 6.4:
  - **Per-object SafeMode:** Lock individual volumes/snapshots independently
  - **Default Protection SafeMode:** Apply SafeMode policy to all new volumes automatically
  - **Auto-On SafeMode for New Arrays:** SafeMode enabled by default on new array deployments
- Pure1 anomaly detection surfaces recommended recovery snapshots closest to ransomware onset

### Secure Multi-Tenancy
- Logical isolation of workloads on shared FlashArray infrastructure
- Resource quotas: IOPS, bandwidth, and capacity limits per tenant
- Separate admin credentials and access controls per tenant
- Used for service provider hosting or large enterprise multi-department environments

### Host Connectivity Protocols
- **NVMe/TCP:** Default for Ethernet from Purity 6.4.2
- **NVMe/RoCE (NVMe-oF):** High-performance RDMA connectivity
- **Fibre Channel:** 16G and 32G FC supported; dual-fabric recommended
- **iSCSI:** Supported on all FlashArray models; CHAP authentication supported
- Host personalities: Purity auto-tunes protocol behavior per host OS/hypervisor type

### Non-Disruptive Operations
- NDU (Non-Disruptive Upgrade) for Purity OS software — zero downtime
- NDU for controllers: swap controllers while maintaining data availability
- NDU for DFMs: replace flash media online without quiescing I/O
- 99.9999% availability SLA (6 nines) on Evergreen//One; same design intent on all FlashArrays

---

## Pure Cloud Block Store

Pure Cloud Block Store (CBS) extends FlashArray capabilities into public cloud, providing native Purity functionality on cloud infrastructure.

### Architecture
- Purity software running on cloud-hosted compute instances (not a cloud-native SaaS object rewrite)
- Data stored on cloud block storage volumes (e.g., AWS EBS io2 Block Express)
- Managed identically to on-premises FlashArray via same GUI, CLI, API, and Pure1
- Available on AWS (primary); Azure support in roadmap

### Use Cases
- **Cloud disaster recovery:** On-premises FlashArray replicates to Cloud Block Store as target
- **Cloud-native workloads:** Provides enterprise-grade storage for EC2 workloads requiring consistent sub-ms latency
- **Hybrid cloud mobility:** Move data between on-premises and cloud with consistent snapshots and replication
- **Backup and recovery:** Quick restores with low RTO/RPO; compliance monitoring and long-term backup

### AWS io2 Block Express Integration
- Cloud Block Store uses AWS io2 Block Express volumes as the underlying storage layer
- Enables up to 256K IOPS and 4,000 MB/s per volume — highest IOPS density available in AWS
- Combined with Purity's deduplication and compression, reduces cloud storage costs significantly

### Key Differentiators vs. Native Cloud Storage
- Same Purity OS features (SafeMode, snapshots, replication, QoS) in cloud
- Consistent management plane (Pure1, same API)
- Data mobility: replicate on-premises snapshots to cloud and vice versa without format conversion

---

## Portworx Integration

Portworx (acquired by Pure Storage in 2020) is the Kubernetes-native storage and data management layer that sits above FlashArray and FlashBlade.

### Core Integration Points
- Portworx uses FlashArray as a high-performance backend storage pool for Kubernetes persistent volumes
- FlashArray Direct Access volumes: PVs provisioned directly from FlashArray, bypassing Portworx's own volume manager for maximum performance
- FlashBlade Direct Access filesystems: NFS filesystems from FlashBlade exposed directly to pods
- CSI topology support: zone-aware volume scheduling, ensures pods and PVs land on the same site in multi-site clusters

### Portworx Data Services on FlashArray
- **Autopilot:** Automatic volume expansion based on usage policies
- **PX-Backup:** Application-consistent Kubernetes backup using FlashArray snapshots
- **PX-DR:** Disaster recovery for stateful Kubernetes apps using FlashArray async replication
- **Stork:** Kubernetes scheduler extender for hyperconvergence — schedules pods where data lives

### AWS Instance Store Durability (December 2025)
- Portworx extends to protect AWS instance store (ephemeral NVMe) volumes
- Adds a synchronous replication layer across multiple EC2 instances
- Provides the raw performance of instance storage with persistent, durable semantics

### Pure CoPilot
- AI-driven recommendations for Kubernetes storage management
- Integrated with Pure1 Meta for cross-stack observability (storage + application layer)
- Simplifies storage class selection, capacity planning, and performance optimization for K8s operators

---

## FlashArray Management APIs

### REST API
- RESTful API (Purity//FA API 2.x) — all operations available via API
- OpenAPI specification published; used by automation, Terraform, Ansible
- Supports bulk operations, async API patterns for long-running tasks

### Terraform Provider
- Official Pure Storage Terraform provider for infrastructure-as-code provisioning
- Manages volumes, hosts, host groups, protection groups, pods, replication

### Ansible Collection
- `purestorage.flasharray` Ansible collection on Ansible Galaxy
- Full lifecycle management: array configuration, volume provisioning, snapshot operations

### Python SDK
- `py-pure-client` SDK for Python automation
- Used for custom scripts, CI/CD pipeline integration, and monitoring tools

---

## Recent Purity Feature Highlights (2024-2025)

| Release | Key Feature |
|---------|-------------|
| Purity 6.4 | SafeMode enhancements (per-object, default protection, auto-on for new arrays) |
| Purity 6.4.1 | Multiple vVol containers per FlashArray |
| Purity 6.4.2 | NVMe/TCP as default protocol for Ethernet host connectivity |
| Purity 6.6.0 | FlashArray//E enablement; ESG improvements; storage consolidation features |
| 2025 (CBS) | Cloud Block Store enhancements for AWS; Azure expansion |
| 2025 (File) | ActiveCluster for File (synchronous NFS replication) |
| 2025 (Object) | S3 protocol support on FlashArray |

---

## References
- Purity Data Sheet: https://www.purestorage.com/products/storage-software/purity/data-sheet.html
- Purity 6.6.0 Release: https://blog.purestorage.com/purity-fa-releases/purity-fa-6-6-0-paving-the-way-for-flasharray-e/
- Pure Cloud Block Store: https://blog.purestorage.com/purely-technical/announcing-pure-storage-cloud-block-store-for-aws/
- AWS io2 Block Express: https://blog.purestorage.com/products/aws-io2-block-express-and-pure-cloud-block-store/
- SafeMode: https://www.purestorage.com/solutions/cyber-resilience/ransomware/safemode.html
- Portworx CSI: https://docs.portworx.com/portworx-csi/
- ActiveCluster for File: https://blog.purestorage.com/products/introducing-activecluster-for-file/
- NVMe/TCP on FlashArray: https://blog.purestorage.com/purely-technical/flasharray-extends-nvme-of-support-to-tcp/
