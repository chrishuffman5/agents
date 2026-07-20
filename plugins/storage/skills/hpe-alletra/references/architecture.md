# HPE Alletra Architecture

## Alletra 5000 (Nimble-Lineage, Hybrid Flash)

CASL (Cache Accelerated Sequential Layout) architecture. Dual-controller, active-passive. NVMe cache + HDD/SSD capacity. Triple+ Parity RAID (3 simultaneous drive failures). 99.9999% availability. Scale-out grouping. Up to 6 ES3 shelves (210 TB raw). iSCSI and FC. dHCI support with ProLiant servers (independent compute/storage scale, vCenter managed).

## Alletra 6000 (Nimble-Lineage, All-NVMe)

CASL for NVMe. Dual-controller active-active. PCIe Gen4. Triple+ Parity RAID. Scale-out grouping (up to 4 arrays). iSCSI and FC. 6010: 92 TiB raw. 6080: 4,416 TiB raw / 16,400 TiB effective. 3x Nimble predecessor performance. Inline dedup + compression. Configurable per-volume IOPS/bandwidth limits. Folder-based multi-tenancy.

## Alletra 9000 (Primera-Lineage, Mission-Critical)

Multi-node clustered (2 or 4 nodes, 4U chassis). All-NVMe shared-everything. Dedicated ASICs per controller (zero-detect, SHA-256, XOR, cluster comms, data movement). PCIe Gen3. Active-active across all nodes. 9060 and 9080 models. Max 144 NVMe SSDs. 4-node 9080: 2.1M IOPS, 55 GB/s, sub-250us latency. Up to 96 SAP HANA nodes.

**Active Peer Persistence**: synchronous zero RPO/RTO replication. LUNs share WWN from both sites (transparent to hosts). Metropolitan distances. Rolling non-disruptive firmware updates. Protocols: FC and iSCSI.

## Alletra Storage MP B10000 (DASE, Block + File)

Entirely new DASE (Disaggregated Shared-Everything) architecture. 2-4 compute nodes, all-active. 2U chassis: dual AMD + up to 24 NVMe SSDs. Compute and capacity scale independently. No storage switch required for 2-4 nodes (switchless, Nov 2025). 100% availability guarantee.

Protocols: FC, iSCSI (IPv4/IPv6), NVMe/TCP (no IPv6), NFS (CSI Driver 3.0.0+). Active Peer Persistence: zero RPO, campus distance, third-site Quorum Witness. Classic Peer Persistence: data-path resilience without auto-failover. Managed exclusively via HPE GreenLake / DSCC.

## Alletra Storage MP X10000 (DASE, Object)

VAST Data-licensed DASE architecture. TB to EB scale. All-NVMe + disaggregated compute. S3 + S3 over RDMA (GPU acceleration). Data Protection Accelerator (DPA) Nodes: StoreOnce Catalyst engine for backup ingest. AI Data Intelligence Nodes (Jan 2026): Nvidia L40S GPUs for metadata extraction, vector embeddings, AI pipelines. GA Aug 2025 with Veeam validated.

## InfoSight AI-Driven Operations

Cloud-hosted AIOps across entire Alletra portfolio. 100,000+ systems monitored globally. Predicts drive failures, controller issues, capacity exhaustion. Cross-stack correlation (storage, hypervisor, network). Automated issue resolution and support case creation. B10000: high-frequency telemetry for enhanced ML anomaly detection.

**Wellness Dashboard** (GreenLake): signature-based automation, prescriptive remediation, centralized in DSCC.

## Cloud-Native Management Stack

| Layer | Component |
|---|---|
| Platform | HPE GreenLake (as-a-service) |
| Console | Data Services Cloud Console (DSCC) |
| AIOps | HPE InfoSight |
| Local | InfoSight Portal (5000/6000/9000) |
| K8s | HPE CSI Driver (Helm/Operator) |
| Legacy | Per-array web UI (5000/6000/9000) |

## StoreOnce Backup Integration

Direct snapshot-to-StoreOnce (B10000). X10000 + DPA Nodes: StoreOnce Catalyst embedded. Veeam + StoreOnce Catalyst validated. Models: 3720, 3760, 5720, 7700. Cloud Bank Storage tiers to AWS/Azure/GCP.

## HPE CSI Driver for Kubernetes

All Alletra models. Helm or Operator installation. K8s 1.34/1.35, OpenShift 4.20.

| Protocol | 5000/6000 | 9000 | MP B10000 |
|---|---|---|---|
| iSCSI | Yes | Yes | Yes |
| FC | Yes | Yes | Yes |
| NVMe/TCP | No | No | Yes |
| NFS | No | No | Yes |
| Peer Persistence | No | CPP | APP + CPP |

Replication in K8s: APP (B10000) = zero RPO/RTO for containers with Pod Monitor labels. CPP (9000) = data-path resilience only. LDAP-backed authentication from v2.5.2+.
