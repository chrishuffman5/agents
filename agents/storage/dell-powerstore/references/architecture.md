# Dell PowerStore Architecture

## Hardware Models

### T-Series (Storage-Only)
100% CPU/RAM dedicated to storage. Dual-controller active-active. Up to 4 appliances per federated cluster. Models: 500T, 1000T/1200T, 3000T, 3200Q (QLC), 5000T, 5200Q (QLC), 7000T, 9000T/9200T.

### X-Series (AppsON)
50/50 CPU/RAM split between storage and compute. ESXi pre-installed alongside PowerStoreOS (Controller VM). VMs run directly on the storage appliance. Requires vSphere Enterprise Plus. vMotion between PowerStore X and external ESXi supported. Models: 1000X through 9000X.

### QLC Models
3200Q: 15.36 TB QLC drives, min 11 drives. 5200Q: up to 1,055 TBe per appliance. PowerStoreOS 4.3: 30 TB QLC drives, up to 2 PBe per 2RU enclosure. 30 TB and 15 TB QLC mixable.

## Container-Based Software Architecture
PowerStoreOS runs on Linux with Docker containerization. Services updated independently without full system restarts. Enables faster feature delivery and simplified NDU.

## NVMe Architecture
All-NVMe base enclosure. TLC (high endurance) and QLC (high density) NVMe SSDs. Front-end: FC, iSCSI, NVMe/FC, NVMe/TCP, NFS v3/v4/v4.1/v4.2, SMB 1.0–3.1.1, vVols. Max 24 front-end ports per appliance.

## Inline Data Reduction
Always-on, cannot be disabled. Dedup + compression inline before write. 5:1 guaranteed (PowerStore Prime, 4.0+). Intelligent Compression (4.0+): 20% improvement in compressible workload ratios. 28% more TBe/watt vs 3.6.

## Metro Volume
Symmetric active/active synchronous replication. Up to 96 km / 5ms RTT. Zero RPO/RTO. Witness component (3.6+) for split-brain prevention. Host OS: ESXi (3.0+), Windows/Linux (4.0+), SCSI-3 Persistent Reservations for WSFC/Linux clusters (4.0+). Metro file replication (4.3+).

## Native Replication
Async replication without third-party software. Supports volumes, volume groups, thin clones, NAS servers. Transport: Ethernet TCP (3.0+), FC async (4.2+), FC sync (4.3+). RPO: zero (metro), 5 minutes (file async, 4.3+), configurable (block async). 8x replication scale from 4.0+.

## CSI Driver for Kubernetes
csi-powerstore v2.16.0 (Feb 2026). Apache 2.0 licensed. Protocols: iSCSI, FC, NFS, NVMe/TCP, NVMe/FC. Part of Dell CSM suite (Authorization, Observability, Replication, Resiliency). Deployed via Helm or CSM Operator.

## PowerStore Manager
Built-in web GUI (HTTPS). No separate management server. Unified view of cluster, provisioning, protection policies, performance dashboards, alerts, health checks, VASA registration, NDU orchestration. REST API, PowerShell SDK, Ansible, Terraform, vRO Plugin.

## VMware Integration
VASA 3.0/4.0 native provider. vVols 2.0 with SPBM. VAAI for block and file (XCOPY 40% faster in 4.0). VASA registration from PowerStore Manager (no vCenter login needed, 2.0+).

## Scalability (4.0+)
2.5x block volumes, 2x hosts, 3x snapshots, 256 VLANs, 8x replication volumes per cluster vs prior releases.
