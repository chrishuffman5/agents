# NetApp ONTAP Features by Version (9.14–9.18)

## ONTAP One Licensing

### Overview
Starting May 2023, all new AFF (A-Series and C-Series), FAS, and ASA systems ship with either ONTAP One or ONTAP Base. ONTAP One replaces the previous bundle model (Core Bundle, Data Protection Bundle, Security and Compliance Bundle, Hybrid Cloud Bundle, Encryption Bundle) with a single NetApp License File (NLF) that enables all licensed functionality.

### What ONTAP One Includes
- **Data Protection**: SnapMirror (async, sync, active sync), SnapRestore, SnapVault, FlexClone, SnapLock
- **Storage Efficiency**: Deduplication, compression, compaction, cross-volume deduplication
- **Hybrid Cloud**: FabricPool tiering, Cloud Volumes ONTAP interoperability
- **Security and Compliance**: Volume encryption (NVE), aggregate encryption (NAE), key management, WORM (SnapLock)
- **Protocols**: All protocols (NFS, SMB, iSCSI, FC, NVMe-oF, S3) included; no separate protocol licenses
- **Performance**: QoS (throughput floors and ceilings), Adaptive QoS
- **Ransomware Protection**: Autonomous Ransomware Protection (ARP/AI)
- **ONTAP Select**: Virtualized ONTAP on commodity hardware (requires separate Select license)

### What ONTAP One Does NOT Include
- NetApp cloud-delivered services (BlueXP, cloud backup, cloud tiering managed service)
- Standalone Cloud Volumes ONTAP licenses
- StorageGRID (separate product/license)

### ONTAP Base
A minimal alternative to ONTAP One for cost-sensitive deployments. Does not include SnapMirror, SnapVault, FlexClone, or most data protection features. Upgrading from Base to One requires purchasing the One upgrade.

### Licensing Delivery (ONTAP 9.10.1+)
All licenses are delivered as a NetApp License File (NLF) — a single file tied to the system serial number. Applied via System Manager or CLI: `system license add -license-code <NLF>`. Legacy capacity-based licenses (28-character license keys) are still supported for older systems.

---

## ONTAP 9.14.1 (Generally Available: 2023)

### Storage Efficiency and Space
- **WAFL reserve reduction for FAS**: The 5% WAFL reserve reduction (from 10%) that was introduced for AFF in 9.12.1 now applies to all FAS platforms for aggregates > 30 TB. Net result: 5% more usable capacity on all FAS systems with large aggregates.
- **Deduplication improvements**: Enhanced cross-volume background deduplication scope.

### Cloud and Tiering
- **FabricPool improvements**: Expanded platform support and interoperability enhancements with StorageGRID.

### Data Protection
- **SnapMirror enhancements**: Improved throttle controls and transfer efficiency for large-scale replication.
- **SnapLock**: Expanded compliance volume capabilities.

### SAN
- **NVMe/TCP**: Continued stability and qualification expansion across host operating systems.

### Platform
- **ONTAP Select KVM support reinstated**: ONTAP Select 9.14.1 re-added KVM hypervisor support (previously removed in 9.10.1).

### Security
- **Multi-admin verification (MAV)**: Enhancements to require approval from multiple administrators for destructive operations (delete volume, delete Snapshot, etc.).

---

## ONTAP 9.15.1 (Generally Available: 2024)

### Business Continuity — SnapMirror Active Sync
- **Symmetric active/active SnapMirror active sync**: Both sites simultaneously serve I/O with equal path preference. Previously (9.14 and earlier), only one site was the preferred active path (asymmetric). This release enables true symmetric active/active for SAN workloads — critical for stretched cluster use cases where any host in any location can read/write with optimal latency.
- Supported on NVMe-oF in addition to SCSI-based protocols.

### FlexCache Write-Back
- **FlexCache write-back mode**: Clients can write data locally to a FlexCache volume rather than waiting for the write to traverse WAN to the origin volume. Writes are buffered at the edge cache and asynchronously replicated to the origin. Reduces write latency for geographically distributed workloads and remote office environments.
- Contrast with prior behavior: FlexCache was previously read-only acceleration; write-back enables bidirectional caching.

### NAS Enhancements
- **SMB 3.1.1 enhancements**: Improved SMB multichannel performance and stability.
- **NFSv4.2 improvements**: Extended attribute (xattr) support, copy offload.

### ONTAP Select
- **Cluster expansion and contraction**: ONTAP Select clusters can be scaled by adding or removing nodes (9.15.1+), supporting elastic deployment models.

### Security
- **Zero Trust posture**: Enhanced audit logging and access controls aligned with NIST zero-trust framework.
- **Certificate-based authentication improvements**: Mutual TLS (mTLS) enhancements for inter-cluster communication.

### Storage Efficiency
- **Inline storage efficiency on AFF C-Series**: Further compression ratio improvements using the dedicated offload processor (ODP) introduced in prior releases.

---

## ONTAP 9.16.1 (Generally Available: 2024–2025)

### Autonomous Ransomware Protection with AI (ARP/AI)
- **AI-based ransomware detection**: ARP/AI replaces the prior rule-based detection engine with a machine-learning model trained on large forensic datasets. Achieves 99% precision and recall on known and novel ransomware families.
- **No learning period**: ARP/AI is active immediately upon enabling — no 30-day "learning mode" required as in prior versions. The model is pre-trained.
- **Automatic model updates**: ARP/AI models are updated out-of-band (independent of ONTAP release cycles) via AutoSupport/Active IQ.
- **Immutable Snapshot on detection**: When ransomware activity is detected, ARP/AI automatically takes an immutable (tamperproof) Snapshot with a user-defined retention period.
- **SAN volume support (9.17.1)**: ARP extended to SAN volumes using encryption-based anomaly detection.

### NVMe Enhancements
- **Space deallocation for NVMe namespaces**: Thin-provisioned NVMe namespaces can now reclaim space when the host application deletes data (TRIM/UNMAP equivalent for NVMe). Critical for database and VM workloads that periodically free large amounts of data.

### Security and Compliance
- **Enhanced multi-admin verification (MAV)**: Broader coverage of protected operations; improved approval workflow integration with email/notification systems.
- **ONTAP supports post-quantum cryptography preparation**: Early groundwork for quantum-resistant algorithms.

### Networking
- **IPsec hardware offload**: IPsec encryption/decryption offloaded to network adapters for link aggregation groups, reducing CPU overhead for encrypted cluster interconnect and data paths.

### Data Protection
- **Consistency Groups enhancements**: Improved hierarchical consistency group management. Consistency groups allow atomic Snapshot creation across multiple volumes for application-consistent backups.

### SAN Management
- **iSCSI improvements**: Enhanced session management and performance for large host counts.

---

## ONTAP 9.17.1 (Generally Available: 2025)

### Security — JIT Privilege Elevation
- **Just-in-time (JIT) privilege elevation**: Users can request temporary elevation to a higher-privilege RBAC role (e.g., to perform a specific maintenance task), with the elevation expiring after a defined window. This follows the principle of least privilege while enabling operational flexibility.

### Identity Management
- **Microsoft Entra ID as SAML IdP**: ONTAP 9.17.1 supports Microsoft Entra (formerly Azure AD) as a SAML 2.0 identity provider for System Manager and REST API authentication. Entra group membership can be mapped to ONTAP RBAC roles.

### Business Continuity — ONTAP Cloud Mediator
- **Cloud-hosted Mediator for SnapMirror active sync**: ONTAP Cloud Mediator acts as the quorum witness (tiebreaker) for SnapMirror active sync relationships without requiring an on-premises Linux VM. Reduces operational complexity for customers who lack a suitable third-site infrastructure for a traditional Mediator deployment.

### ARP/AI for SAN
- **Autonomous Ransomware Protection on SAN volumes**: ARP/AI extended to block storage (LUNs and NVMe namespaces) using encryption-based anomaly detection (monitoring encryption pattern changes in block streams rather than file entropy). Configurable detection thresholds; more deterministic immutable Snapshot retention.

### NVMe
- **NVMe host support with SnapMirror active sync**: NVMe-oF hosts can participate in SnapMirror active sync consistency groups, enabling zero-RPO protection for NVMe-connected workloads.
- **Consistency group hierarchical management**: Improved parent-child consistency group structure for complex multi-application topologies.

### Networking
- **IPsec for LAG (Link Aggregation Groups)**: Hardware-offloaded IPsec encryption for bonded network interfaces.

---

## ONTAP 9.18.1 (Generally Available: 2025)

### Encryption and Security
- **mTLS for cluster back-end network**: ONTAP 9.18.1 supports encrypting the internal cluster interconnect (back-end storage network) using mutual TLS (mTLS), protecting intra-cluster communication.
- **Post-quantum algorithm support**: ONTAP 9.18.1 introduces support for post-quantum cryptographic algorithms for data-in-transit encryption, preparing for the quantum computing threat model.
- **Expanded encryption scalability**: Larger scale NVE (NetApp Volume Encryption) key management deployments supported.

### Cloud and Hybrid
- **Cloud Volumes ONTAP on Google Cloud C3 VMs**: NetApp transitions CVO Google Cloud deployments to the C3 VM series (Intel Sapphire Rapids), delivering improved performance and higher per-instance capacity.

### Scalability
- **Cluster and volume scalability increases**: Expanded maximum volume counts, LUN counts, and namespace counts per cluster on high-end platforms.

---

## Feature Timeline Summary

| Feature | First Available |
|---------|----------------|
| ONTAP S3 object storage | 9.8 |
| NVMe/TCP | 9.10.1 |
| S3 multiprotocol (NFS+SMB+S3 same data) | 9.12.1 |
| WAFL reserve reduction (AFF) | 9.12.1 |
| SnapMirror active sync (asymmetric active/active) | 9.9.1 |
| WAFL reserve reduction (FAS) | 9.14.1 |
| ONTAP Select KVM reinstatement | 9.14.1 |
| SnapMirror active sync symmetric active/active | 9.15.1 |
| FlexCache write-back | 9.15.1 |
| ARP/AI (no learning period, 99% accuracy) | 9.16.1 |
| NVMe namespace space deallocation | 9.16.1 |
| JIT privilege elevation | 9.17.1 |
| ONTAP Cloud Mediator | 9.17.1 |
| ARP/AI for SAN volumes | 9.17.1 |
| NVMe with SnapMirror active sync | 9.17.1 |
| mTLS for cluster back-end network | 9.18.1 |
| Post-quantum algorithm support | 9.18.1 |
