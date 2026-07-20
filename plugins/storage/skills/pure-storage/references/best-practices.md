# Pure Storage FlashArray Best Practices

## Volume Provisioning

### Sizing
Always thin-provisioned. Set volume size to application's maximum expected need — only written data consumes flash. Track actual vs provisioned in Pure1. Alert on physical consumed, not provisioned size.

### Naming
Convention: `<env>-<app>-<role>-<index>` (e.g., `prod-sqlserver-data-01`). Avoid embedding array identity — volumes may migrate via Fusion or vVol mobility.

### Host Configuration
- Create host object per initiator. Set **host personality** to match OS/hypervisor (esxi, windows, aix, etc.)
- Group related hosts into **host groups** for shared access (RAC, AG, VMware cluster)
- For ESXi: host group per vSphere cluster, shared datastores to group not individual hosts

### Protocol
- **NVMe/TCP** (preferred, new Ethernet): default from Purity 6.4.2, 35% lower latency than iSCSI, no special hardware
- **iSCSI**: jumbo frames MTU 9000 end-to-end, CHAP, minimum 2 paths
- **FC**: dual-fabric A+B, zone single initiator to multiple targets per controller, 32G preferred
- **Multipath**: always configure (MPIO/DM-Multipath/NMP). Required for HA and NDU. Minimum 4 paths total for production.

### QoS
Do not set per-volume QoS unless isolation is specifically required. Purity's continuous QoS handles fair-share automatically. Verify multipath with `purehost list --connect`.

## Protection Groups

### Design
Group volumes by application consistency boundary (e.g., Oracle: data + redo + archive + control). One group per application tier, not per volume. Can contain volumes, hosts, or host groups.

### Snapshot Schedules
Minimum: hourly, 24-hour retention. Augment: daily for 7-30 days. Per-minute only for critical OLTP. Test recovery quarterly with writable clones.

### Snapshot Offload
Remote FlashArray (async), FlashBlade (NFS offload for long-term), Amazon S3. FlashBlade most cost-effective on-premises.

### SafeMode Configuration
- Enable on ALL production arrays — baseline, not optional
- Eradication timer: 72 hours minimum for production, 7+ days for compliance
- Enable Auto-On SafeMode for New Arrays globally
- Enable Default Protection SafeMode for all new volumes
- Verify via Pure1 Security Assessment

### Database Consistency
VMware: VADP integration (quiesced by VMware Tools). SQL Server: VSS provider or PowerShell SDK. Oracle: Pure integration scripts. Never rely on crash-consistent snapshots for write-heavy OLTP without quiescing.

## ActiveCluster Design

### Pre-Deployment
- Verify RTT under 11 ms with actual replication traffic
- Plan bandwidth: peak write throughput x 2 for bi-directional + resync headroom
- Deploy redundant switched replication network (no direct connections)
- Confirm Pure1 Cloud Mediator reachable (outbound HTTPS). On-prem mediator if blocked.

### Pod Design
All workload volumes in a single pod for atomic failover. Limit pod to volumes needing synchronous replication. Non-sync volumes stay outside pods.

### Topology
Uniform (preferred for metro): stretched fabric, true active/active, transparent failover. Non-Uniform (simpler for DR): local access only, host reconfiguration at failover.

### Mediator
Cloud (preferred): hosted by Pure, no management, physically independent. On-prem: third site, independently powered/connected. Never co-locate with either array.

### VMware vMSC
vMSC certified. Configure HA with vMSC awareness. Set site affinity via VM/Host Groups. Use Uniform topology.

### Monitoring
Pure1 Active Replication Monitoring: pod state, mediator health, lag. Alert on "degraded". Test `purepod failover` annually.

## Kubernetes Integration

### CSI Driver
Deploy via Helm (`purestorage/helm-charts`). Configure backends with read/write API tokens (not admin). Enable CSI topology for multi-site.

### Storage Classes
- `pure-block`: default FlashArray RWO
- `pure-file`: FlashBlade NFS RWX
- `pure-block-clone-enabled`: CSI volume cloning
- Production: `reclaimPolicy: Retain`. Dev/test: `Delete`.
- `volumeBindingMode: WaitForFirstConsumer` for topology-aware scheduling

### Data Protection for K8s
PX-Backup for application-consistent backup. PX-DR with ActiveDR for near-zero RPO. ResourceQuotas on PVC requests per namespace.

## Performance Optimization

### Array-Level
Do not manually tune GC or data reduction. QoS limits only when contractually required. Ensure all paths active and balanced.

### Network
MTU 9000 end-to-end for iSCSI and NVMe/TCP. NVMe/RoCE: PFC + ECN on switches (DCQCN). iSCSI: flow control on switch ports. Bond/LACP host NICs if needed.

### VMware
SATP: `VMW_SATP_ALUA`. PSP: `VMW_PSP_RR` with `iops=1`. Configure SIOC with care (Pure QoS already manages fairness). Separate vmkernel ports per uplink for iSCSI.

### Databases
SQL Server: instant file initialization, pre-allocated files, multiple data files per filegroup. Oracle: ASM with 1 MB AU. PostgreSQL: `random_page_cost = 1.0`.

## Capacity Planning

Alert at 70% effective consumed. Use Pure1 Workload Planner quarterly. Re-evaluate data reduction ratios quarterly. Avoid unchecked snapshot accumulation — set retention on all protection groups.
