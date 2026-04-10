# Pure Storage FlashArray — Research Summary

**Research Date:** April 2026
**Platform Covered:** Pure Storage FlashArray (Everpure brand as of February 2026)
**Sources:** Pure Storage official documentation, datasheets, technical blogs, third-party analyst coverage (Blocks & Files, Futurum Group, WWT)

---

## What This Research Covers

This workspace contains four detailed research files:

| File | Contents |
|------|----------|
| `architecture.md` | FlashArray model family (X, XL, C, E, ST), Purity OS, DirectFlash, always-on data reduction, ActiveCluster, ActiveDR, Pure1 Meta AI, Evergreen subscription, Pure Fusion, CSI driver, FlashBlade, Portworx |
| `features.md` | Current Purity capabilities, Pure Cloud Block Store (AWS), Portworx integration, feature matrix by Purity release, API/automation tools |
| `best-practices.md` | Volume provisioning, protection groups, SafeMode, ActiveCluster design, Kubernetes/CSI integration, performance optimization, capacity planning |
| `diagnostics.md` | Pure1 monitoring, performance dashboards, alert types, connectivity troubleshooting (FC/iSCSI/NVMe), replication lag, array health, support workflow |

---

## Platform Identity

Pure Storage rebranded to **Everpure** in February 2026. Product names (FlashArray, FlashBlade, Purity OS, Pure1, Pure Fusion) remain unchanged. The brand change does not affect technology or support relationships.

---

## Key Architectural Differentiators

**1. DirectFlash Modules (DFMs)**
Pure's proprietary flash media contains only NAND cells — no per-device controller or FTL. All flash management (wear leveling, garbage collection, bad block management) is done globally by Purity OS across all DFMs simultaneously. This eliminates the "write cliff" and garbage collection jitter that plague commodity SSD-based arrays. DFMs currently ship at 75 TB and 150 TB; 300 TB was targeted for late 2025. They consume 39-54% fewer watts per TiB than competitors.

**2. Always-On Data Reduction**
Inline deduplication, compression, and pattern removal run on every write — they cannot be disabled. Average 5:1 effective capacity ratio. No performance-vs-efficiency trade-off because the architecture was designed with reduction always active from day one.

**3. Purity OS as the Control Plane**
All enterprise features (replication, encryption, QoS, SafeMode, file services, vVols, S3, NVMe-oF) are delivered through Purity OS software, not dedicated hardware ASICs. This means features improve with every Purity update and work consistently across all array generations. Non-disruptive upgrades are a foundational design requirement.

**4. Pure1 as the AIOps Brain**
Pure1 ingests telemetry from the entire global fleet, trains ML models on trillions of data points, and applies that intelligence to individual array diagnostics. Approximately 70% of hardware and software issues are proactively identified and resolved before customer impact. The AI Copilot (2025) adds natural-language management and MCP-based automation integration.

---

## FlashArray Model Selection Guide

| Model | Primary Use Case | Key Differentiator |
|-------|----------------|--------------------|
| FlashArray//X | Mission-critical OLTP, VDI, databases | Highest performance; full DFM NVMe; R5 = 30% perf boost |
| FlashArray//XL | Extreme-scale mission-critical | Larger controller headroom; XL 190 arriving Q4 FY26 |
| FlashArray//C | Enterprise file, general workloads, secondary storage | Cost-optimized; 16.3 PB effective; R5 = 40% perf boost |
| FlashArray//E | High-density archival, cold flash | Lowest $/TB in family; power/space efficient |
| FlashArray//ST | Mid-market / SSD-based | No DFMs; uses SSDs; 400 TB usable; 18M IOPS |

---

## Replication Options Summary

| Option | Type | RPO | RTO | Use Case |
|--------|------|-----|-----|----------|
| Async (protection groups) | Schedule-based | Minutes | Minutes | Long-distance DR, backup |
| ActiveDR | Continuous async | Seconds | Minutes | Near-zero RPO DR |
| ActiveCluster | Synchronous active/active | Zero | Zero | Metro cluster, business continuity |
| Cloud Block Store replication | Async to cloud | Minutes | Minutes | Cloud DR target |

**ActiveCluster key constraints:** max 11 ms RTT between arrays; requires Pure1 Cloud Mediator or on-premises mediator; max 4x 10GbE replication ports per array.

---

## Evergreen Commercial Model Summary

| Tier | Model | Ownership | SLA |
|------|-------|-----------|-----|
| Evergreen//Forever | Perpetual + refresh | Customer owns | Best-effort uptime |
| Evergreen//Flex | Term subscription | Customer owns | Best-effort uptime |
| Evergreen//One | STaaS | Pure owns hardware | 99.9999% + performance + energy |

Evergreen//One is the only STaaS offering with a published energy efficiency SLA (max watts per TiB). Pure was recognized as a Gartner Magic Quadrant Leader for Infrastructure Platform Consumption Services in 2025.

---

## Current Status (April 2026)

- **Purity version:** 6.6.x generally available; 6.4.2+ enables NVMe/TCP as default
- **Latest hardware:** FlashArray//X R5 and //C R5 GA in 2025; //XL 190 targeting Q4 FY26
- **DFM roadmap:** 300 TB DFMs targeted end-of-2025; density doubles annually
- **New protocol:** S3 object support added natively to FlashArray
- **AI Copilot:** MCP connectivity GA targeted Q4 FY26
- **File replication:** ActiveCluster for File (NFS synchronous replication) now available
- **Brand:** Everpure (formerly Pure Storage) since February 2026

---

## Critical Best Practices (Top 10)

1. Enable SafeMode on all production arrays with at minimum 72-hour eradication delay
2. Always configure multipath I/O (MPIO/DM-Multipath/NMP) — minimum 4 paths per host on FC
3. Set host personality on every host object — controls protocol tuning automatically
4. Group volumes by application consistency boundary in protection groups, not one-per-volume
5. Deploy ActiveCluster with the Pure1 Cloud Mediator (preferred) on a third network
6. Use NVMe/TCP for new Ethernet deployments — 35% lower latency than iSCSI, no special hardware
7. Set MTU 9000 (jumbo frames) end-to-end for iSCSI and NVMe/TCP
8. Set CSI StorageClass `reclaimPolicy: Retain` for production Kubernetes PVCs
9. Use Pure1 Workload Planner quarterly for capacity and performance forecasting
10. Do not manually tune garbage collection, data reduction, or QoS — Purity manages these globally

---

## Key Diagnostic Entry Points

| Issue Type | First Tool | Key Metric |
|-----------|-----------|------------|
| High latency | Pure1 > Array > Performance | Array-side vs. host-side latency split |
| Capacity pressure | Pure1 > Array > Capacity | Effective used % + Workload Planner forecast |
| Replication lag | Pure1 > Replication tab | Pod state + lag seconds (ActiveDR) |
| Hardware degradation | Pure1 > Array > Hardware | DFM wear % + component state |
| Security posture | Pure1 > Security Assessment | SafeMode coverage + Purity version currency |
| Ransomware anomaly | Pure1 > Alerts > Anomaly | Anomaly timestamp vs. snapshot catalog |

---

## Research Gaps and Follow-Up Items

The following topics warrant deeper investigation for specific deployment scenarios:
- FlashArray with specific database platforms (Oracle, SQL Server, SAP HANA) — Pure publishes dedicated white papers per workload
- Cloud Block Store on Azure — AWS is well-documented; Azure availability/pricing needs verification
- Pure Fusion API depth — autonomous provisioning policies and integration with external CMDB/ITSM tools
- Portworx PX-Backup specifics — integration with enterprise backup software (Veeam, Commvault)
- FlashArray//E at scale — archival workflows, lifecycle management with automated tiering from //X or //C

---

## Source Index

- Pure Storage FlashArray Product Page: https://www.purestorage.com/products/block-file-object-storage.html
- Purity//FA Data Sheet: https://www.purestorage.com/products/storage-software/purity/data-sheet.html
- FlashArray//X Data Sheet: https://www.purestorage.com/products/unified-block-file-storage/flasharray-x/data-sheet.html
- FlashArray//C Data Sheet: https://www.purestorage.com/products/unified-block-file-storage/flasharray-c.html
- FlashArray Family Data Sheet: https://www.purestorage.com/content/dam/pdf/en/datasheets/ds-pure-storage-flasharray-family.pdf
- DirectFlash Explained: https://www.purestorage.com/knowledge/what-is-directflash-and-how-does-it-work.html
- DFM vs SSD Comparison: https://www.purestorage.com/knowledge/direct-flash-modules-vs-ssds-vs-hdds-vs-hybrid.html
- ActiveCluster Data Sheet: https://www.purestorage.com/content/dam/pdf/en/datasheets/ds-purity-activecluster.pdf
- ActiveCluster Configuration: https://www.purestorage.com/products/storage-software/purity/active-cluster.html
- ActiveDR White Paper: https://www.purestorage.com/content/dam/pdf/en/white-papers/wp-purity-activedr.pdf
- Pure1 AIOps: https://www.purestorage.com/products/aiops/pure1.html
- Pure1 Meta Introduction: https://blog.purestorage.com/products/introducing-pure1-meta-pures-ai-platform-enable-self-driving-storage/
- Pure Fusion Blog: https://blog.purestorage.com/perspectives/pure-fusion-expands-industry-first-autonomous-storage-delivery-platform/
- Evergreen//One STaaS: https://www.purestorage.com/products/staas/evergreen/resources.html
- Cloud Block Store: https://blog.purestorage.com/purely-technical/announcing-pure-storage-cloud-block-store-for-aws/
- SafeMode Ransomware: https://www.purestorage.com/solutions/cyber-resilience/ransomware/safemode.html
- PSO Helm Charts: https://github.com/purestorage/helm-charts
- Portworx on Pure: https://docs.portworx.com/portworx-enterprise/platform/install/pure-storage
- Blocks & Files Pure Launch Dec 2025: https://blog.purestorage.com/products/pure-launch-blog-december-2025-edition/
- Blocks & Files Enterprise Data Cloud 2025: https://blocksandfiles.com/2025/06/18/pure-storage-enterprise-data-cloud/
- Blocks & Files Everpure Rebrand: https://www.blocksandfiles.com/data-management/2026/02/23/pure-storage-becomes-everpure-snaps-up-1touch-in-data-management-shift/4091751
