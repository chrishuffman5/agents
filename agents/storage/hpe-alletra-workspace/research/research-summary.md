# HPE Alletra Research Summary

**Research Date:** April 2026
**Platform Status:** Current — HPE Alletra is HPE's active enterprise storage portfolio as of 2026

---

## What Is HPE Alletra?

HPE Alletra is the unified storage brand that replaced and consolidated three legacy HPE storage lines — Nimble Storage, 3PAR, and Primera — into a single portfolio launched in 2021. As of 2025-2026, the portfolio spans five distinct product lines targeting different workload tiers, all managed through HPE GreenLake cloud services.

---

## Product Family at a Glance

| Model | Heritage | Architecture | Target Workload | Key Differentiator |
|-------|---------|--------------|-----------------|-------------------|
| Alletra 5000 | Nimble HF | CASL, dual-controller, hybrid flash + NVMe cache | General purpose, cost-efficient, dHCI | Triple+ Parity RAID, dHCI, 99.9999% availability |
| Alletra 6000 | Nimble AF | CASL, dual-controller, all-NVMe, PCIe Gen4 | Mixed business-critical, VDI, OLTP | 3x Nimble performance, scale-out grouping |
| Alletra 9000 | Primera | Multi-node clustered, all-NVMe, dedicated ASIC | Mission-critical, SAP HANA, Tier-0 databases | Sub-250µs latency, Active Peer Persistence, financial SLA |
| Alletra MP B10000 | New (DASE) | Disaggregated scale-out, NVMe, cloud-managed | Containers, Kubernetes, modern apps, cloud-native | NVMe/TCP, 100% availability guarantee, independent scale |
| Alletra MP X10000 | New (VAST Data) | Disaggregated object, all-NVMe, S3/RDMA | AI/ML datasets, backup, unstructured data at scale | S3 over RDMA, StoreOnce integration, AI Data Intelligence Nodes |

---

## Key Themes

### 1. Disaggregation is the Strategic Direction
The Alletra Storage MP B10000 and X10000 represent HPE's strategic future. Both use DASE (Disaggregated Shared-Everything) architecture, which independently scales compute nodes and NVMe capacity. This architecture eliminates the active-standby waste of traditional dual-controller designs and removes dependency on specialized storage switches for small deployments (2-4 nodes, switchless as of November 2025). All Nimble/Primera-lineage arrays are maintained but the MP platform is where new architectural innovation is concentrated.

### 2. GreenLake as-a-Service is the Primary Consumption Model
HPE's preferred commercial model for Alletra is HPE GreenLake, converting on-premises storage from CapEx to a pay-per-use operating expense. Customers pay for consumed capacity above a committed minimum, with hardware owned and maintained by HPE. The Alletra MP B10000 is sold exclusively as a GreenLake service.

### 3. InfoSight AI is Central to Operations
InfoSight is not just a monitoring tool — it is the operational backbone of Alletra. It predicts drive failures days in advance, auto-creates support cases, provides cross-stack correlation from storage through hypervisor to application, and increasingly automates remediation. For Alletra MP B10000, enhanced high-frequency telemetry feeds more sophisticated anomaly detection. Operators who do not engage with InfoSight daily are operating the platform below its capability.

### 4. Kubernetes and Containers Are First-Class Citizens
The HPE CSI Driver for Kubernetes supports all Alletra models with feature parity appropriate to each platform tier. The B10000 adds NVMe/TCP and NFS protocol support in Kubernetes, Active Peer Persistence for zero-RPO container DR, and file services via CSI Driver 3.0.0+. Kubernetes 1.34/1.35 and OpenShift 4.20 are the current validated targets. LDAP-backed CSP authentication reduces credential management overhead in enterprise environments.

### 5. StoreOnce Integration Completes the Data Protection Story
Every tier of the Alletra portfolio integrates with HPE StoreOnce for deduplicated backup. The Alletra MP X10000 with Data Protection Accelerator Nodes represents the highest-performance path, with StoreOnce Catalyst embedded directly in the storage platform. Veeam is the primary validated backup software partner across all models.

---

## Consolidation Status (Nimble/3PAR/Primera EOL Path)

- **Nimble Storage HF-series** → Replaced by Alletra 5000 (same CASL architecture, updated)
- **Nimble Storage AF-series** → Replaced by Alletra 6000 (CASL reengineered for NVMe)
- **HPE Primera** → Replaced by Alletra 9000 (OS and ASIC lineage continues)
- **HPE 3PAR** → Migration target is Alletra 9000; HPE Trade-Up Advantage Plus program assists migration; 3PAR is end-of-life
- **HPE Alletra Storage MP** → Entirely new platform; no prior HPE product replaced

In November 2025, HPE discontinued partnerships with Qumulo, Scality, and WEKA to focus exclusively on its own storage intellectual property. This eliminates competitive complexity in the portfolio and signals full commitment to Alletra MP as the long-term growth platform.

---

## Critical Numbers

| Metric | Value | Platform |
|--------|-------|----------|
| Max IOPS | 2.1 million | Alletra 9000 (4-node 9080, 4U) |
| Max throughput | 55 GB/s | Alletra 9000 (4-node 9080) |
| Latency target | <250 microseconds (75th+ percentile) | Alletra 9000 |
| Availability guarantee | 99.9999% (six nines) | Alletra 5000, 6000, MP B10000 |
| Max raw capacity (6080) | 4,416 TiB raw / 16,400 TiB effective | Alletra 6000 |
| Max raw capacity (9000) | 721 TB (144 NVMe drives) | Alletra 9000 |
| InfoSight telemetry scale | 100,000+ systems monitored globally | InfoSight platform |
| K8s VolumeAttachments per node | 200 recommended (250 tested) | CSI Driver (iSCSI) |
| Kubernetes versions supported | 1.34, 1.35, OpenShift 4.20 | HPE CSI Driver (current) |
| Node hostname limit | 27 characters | CSI Driver constraint |

---

## Files in This Research Package

| File | Contents |
|------|----------|
| `architecture.md` | Model-by-model architecture deep-dive: DASE, dHCI, NVMe, RAID, Peer Persistence, CSI Driver, StoreOnce integration, InfoSight AI operations, cloud-native management stack |
| `features.md` | Current feature capabilities per model; GreenLake consumption model details; product consolidation history; ecosystem integrations; data reduction feature matrix; multi-protocol support matrix |
| `best-practices.md` | Volume design, performance policies, replication strategy, snapshot management, InfoSight operational habits, host-side tuning (multipath, iSCSI jumbo frames, FC zoning), Kubernetes StorageClass design, DR testing |
| `diagnostics.md` | InfoSight predictive analytics usage; array health CLI commands (9000, 6000, B10000); performance issue diagnostic workflow; iSCSI/FC/GreenLake connectivity troubleshooting; support case guidance; firmware management |
| `research-summary.md` | This file — executive summary, key themes, critical numbers, research sources |

---

## Research Sources

- HPE Alletra product page: https://www.hpe.com/us/en/hpe-alletra.html
- HPE Alletra Storage MP B10000: https://www.hpe.com/us/en/alletra-storage-mp-b10000.html
- HPE Alletra Storage MP X10000: https://www.hpe.com/us/en/alletra-storage-mp-x10000.html
- HPE InfoSight: https://www.hpe.com/us/en/software/infosight.html
- HPE Storage Container Orchestrator Documentation (SCOD): https://scod.hpedev.io/csi_driver/
- HPE CSI Driver — B10000/9000/Primera/3PAR: https://scod.hpedev.io/csi_driver/container_storage_provider/hpe_alletra_storage_mp_b10000/index.html
- HPE CSI Driver — Alletra 5000/6000/Nimble: https://scod.hpedev.io/csi_driver/container_storage_provider/hpe_alletra_6000/index.html
- HPE CSI Driver GitHub Releases: https://github.com/hpe-storage/csi-driver/releases
- Blocks and Files — HPE Storage 2025 Analysis: https://blocksandfiles.com/2025/12/01/hpe-storage-in-2025-alletra-rises/
- Blocks and Files — Alletra X10000 Analysis: https://blocksandfiles.com/2025/02/13/hpe-alletra-x10000-analysis/
- Nexstor — Alletra MP Storage Architecture: https://nexstor.com/hpe-greenlake-releases-alletra-mp-a-new-storage-architecture/
- StorageReview — B10000 Multi-Protocol Review: https://www.storagereview.com/review/hpe-alletra-storage-mp-b10000-multi-protocol-storage-for-modern-workloads
- StorageReview — X10000 + DPA Review: https://www.storagereview.com/review/hpe-alletra-storage-mp-x10000-with-the-data-protection-accelerator-node-backup-without-the-bottleneck
- Veeam Community — B10000 + Veeam Backup Architecture: https://community.veeam.com/blogs-and-podcasts-57/building-a-backup-architecture-with-hpe-alletra-storage-mp-b10000-and-veeam-9929
- Red Hat — B10000 for OpenShift: https://www.redhat.com/en/blog/hpe-alletra-storage-mp-b10000-red-hat-openshift
- Oboe — Alletra Systems Explained (Hardware + Troubleshooting): https://oboe.com/learn/hpe-alletra-storage-systems-explained-1kidaym/
- Server-parts.eu — Alletra Comparison: https://www.server-parts.eu/post/hpe-alletra-storage-specs-comparison
- HPE Pointnext Complete Care for Alletra 5000/6000: https://www.hpe.com/psnow/doc/a50004950enw
- HPE GreenLake for Block Storage: https://www.hpe.com/us/en/collaterals/collateral.a50009575enw.html
- HPE Active Peer Persistence: https://www.hpe.com/psnow/doc/a00115612enw
- HPE StoreOnce Systems: https://buy.hpe.com/us/en/storage/disk-storage-systems/storeonce-systems/storeonce-systems/hpe-storeonce-systems/p/5196525
- HPE CloudnRoll — CSI Driver + Morpheus + Kasten Integration: https://cloudnroll.com/2025/12/30/hpe-csi-driver-hpe-morpheus-hpe-kubernetes-services-and-veeam-kasten/
