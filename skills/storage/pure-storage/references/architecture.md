# Pure Storage FlashArray Architecture

## FlashArray Model Family

**//X**: Mission-critical, 100% NVMe with DFMs. NVMe-oF, FC, iSCSI. R5 generation: Emerald Rapids, ~30% performance improvement. //X 90 R3: 20% more TPS, 30-35% lower max latency with NVMe/TCP vs iSCSI.

**//XL**: Highest performance at extreme scale. //XL 190 (GA target Q4 FY26). Same DFM ecosystem with larger controller/interconnect headroom.

**//C**: Capacity-optimized, up to 16.3 PB effective. R5: ~40% performance improvement. Replaces tiered/hybrid arrays.

**//E**: High-density archival, cold-tier flash. Lowest $/TB. Enabled by Purity//FA 6.6.0.

**//ST**: Conventional SSDs (no DFMs). 400 TB usable, 18M IOPS, 200 GB/s. Snapshots, clones, replication via Purity OS.

## Purity Operating Environment (Purity//FA)

All enterprise features in software, not hardware ASICs. Consistent across generations. NDU foundational. Current: Purity//FA 6.6.x.

Capabilities: always-on inline dedup/compression/pattern removal, global wear leveling, QoS (continuous non-intrusive), snapshots/clones, replication (async/sync/continuous), file services (NFS/SMB), vVols 2.0, S3 object, NVMe-oF (RoCE/TCP), AES-256 encryption, SafeMode, NDU for OS/controllers/DFMs.

## DirectFlash Technology

DFMs: only NAND cells — no embedded controller, DRAM, or per-device FTL. All management by Purity globally. Eliminates SSD "write cliff" and GC jitter. 75 TB and 150 TB shipping; 300 TB targeted. 6x more reliable than HDDs, 3x more reliable than enterprise SSDs. 2-5x more capacity-efficient than COTS SSDs. 39-54% fewer watts/TiB.

## Always-On Data Reduction

Global inline dedup (cross-volume, entire array), LZ4 compression, zero-block pattern removal. Never optional, never schedulable. Average 5:1 effective. Real-time ratio displayed in dashboard and Pure1.

## ActiveCluster (Synchronous Replication)

Two FlashArrays form stretch cluster. Both serve read/write simultaneously. Synchronous writes to both arrays before host ack. Volumes in stretched pods.

**Mediator**: Pure1 Cloud Mediator (SaaS, recommended) or on-premises VM. Resolves split-brain. Built-in pre-election from Purity 5.3+.

**Network**: Max 11 ms RTT. Min 4x 10GbE replication ports per array. Redundant switched network required.

**Topologies**: Uniform (hosts at both sites access both arrays, stretched fabric, full active/active with cross-site failover) or Non-Uniform (hosts access local array only, simpler, higher RTO).

**ActiveCluster for File**: synchronous replication of NFS shares.

## ActiveDR (Continuous Async)

Streams data continuously to target. Near-zero RPO (seconds). No schedule. No write performance impact. Test failovers without interrupting replication. Single-command promotion. Snapshot history replicated.

## Pure1 AIOps

Cloud SaaS management platform. All arrays phone home continuously.

**Pure1 Meta AI**: Analyzes global fleet telemetry (trillions of data points). Predictive capacity, performance trending, anomaly detection. Workload Planner for upgrade recommendations. VM Analytics. Proactively resolves 70%+ of issues before downtime.

**AI Copilot** (2025-2026): Natural-language management. MCP integration targeted GA Q4 FY26.

**Security Assessment**: SafeMode coverage, Purity version currency, snapshot policy recommendations.

## Evergreen Subscription

**//Forever**: Perpetual + refresh. Controllers upgraded non-disruptively, DFMs retained. **//Flex**: Term subscriptions with NR-Capacity/NR-Components options. **//One**: STaaS, Pure owns hardware. 99.9999% availability + performance + energy efficiency SLA. Gartner MQ Leader 2025.

## Pure Fusion

Autonomous storage management control plane above individual arrays. Abstracts FlashArrays/FlashBlades into unified pools. Self-service provisioning via APIs/GUI. AI-driven workload placement. Powers Evergreen//One.

## CSI Driver (Kubernetes)

Pure Service Orchestrator (PSO). CSI 1.x compliant. Helm charts (`purestorage/helm-charts`). FlashArray (block) and FlashBlade (file/object) backends. Topology-aware provisioning, volume cloning, snapshots, QoS. Auto-selects best array by capacity, performance, health, and policy.

## FlashBlade (Companion)

Parallel file and object storage for AI/ML, analytics, backup. FlashBlade//EXA (2025): 2x MLPerf performance. Multi-tenancy for object (Purity//FB 4.6.3). Snapshot offload target for FlashArray. CSI driver backend.

## Portworx Integration

Kubernetes-native storage/data management (acquired 2020). FlashArray Direct Access volumes. FlashBlade Direct Access filesystems. CSI topology for multi-site. Autopilot, PX-Backup, PX-DR, Stork scheduler. AWS instance store durability (Dec 2025). Pure CoPilot for AI-driven K8s recommendations.

## Cloud Block Store

Purity on AWS cloud instances (EBS io2 Block Express). Managed identically to on-prem. Same GUI, CLI, API, Pure1. Use cases: cloud DR target, cloud-native workloads, hybrid mobility, backup/recovery. Up to 256K IOPS per volume. Azure in roadmap.
