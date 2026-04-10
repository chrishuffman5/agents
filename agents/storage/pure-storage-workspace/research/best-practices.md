# Pure Storage FlashArray Best Practices

## Overview

This document covers operational best practices for deploying, configuring, and maintaining Pure Storage FlashArray in production environments. Practices are derived from Pure's official documentation, technical guides, and community knowledge accumulated through production deployments.

---

## Volume Provisioning

### Sizing and Thin Provisioning
- FlashArray volumes are always thin-provisioned — allocate generously to application-declared size without worrying about actual flash consumption
- Set volume size to match the application's maximum expected need; FlashArray only consumes flash for actual written data
- Do not over-engineer volume sizing tiers — the array's global dedup and compression handle the actual footprint
- Track actual vs. provisioned capacity in Pure1 dashboards; alert on physical space consumed, not provisioned size

### Volume Naming Conventions
- Use consistent, descriptive naming: `<env>-<app>-<role>-<index>` (e.g., `prod-sqlserver-data-01`)
- Avoid names that embed array identity — volumes may be migrated between arrays via Pure Fusion or vVol mobility
- For Kubernetes workloads using PSO/CSI, the driver auto-names volumes with a namespace prefix; review naming prefix configuration in the PSO ConfigMap

### Host and Host Group Configuration
- Create a **host** object on FlashArray for each initiator (server/VM)
- Set the **host personality** to match the OS/hypervisor type: `esxi`, `windows`, `aix`, `hpux`, etc. — this tunes protocol behavior automatically
- Group related hosts into **host groups** for shared volume access (e.g., Oracle RAC cluster, SQL Always On AG, VMware cluster)
- For ESXi: use a host group per vSphere cluster; connect shared datastores to the group, not individual hosts

### Protocol Configuration
- **NVMe/TCP (preferred for new Ethernet deployments):** Default from Purity 6.4.2 onward; requires no special hardware, delivers up to 35% lower latency than iSCSI
- **iSCSI:** Use jumbo frames (MTU 9000) end-to-end; configure CHAP for security; minimum 2 paths per host
- **Fibre Channel:** Deploy dual-fabric (A+B fabric) for redundancy; zone single initiator to multiple targets per array controller; 32G FC preferred for new deployments
- **Multipathing:** Always configure multipath I/O (MPIO on Windows, DM-Multipath on Linux, NMP on ESXi) — required for HA and NDU support
- Do not disable multipathing; doing so eliminates controller failover and upgrade non-disruption

### Volume Performance
- Do not set per-volume QoS limits unless workload isolation is specifically required — Purity's continuous QoS handles fair-share distribution automatically
- For latency-sensitive workloads (databases, VDI), explicitly set host personality and verify multipath is active on all paths
- Test with at least 2 paths per controller (4 total) for production; use the pure CLI command `purehost list --connect` to verify path count

---

## Protection Groups

### Design Principles
- **Group volumes by application consistency boundary:** A protection group should contain all volumes needed for a consistent recovery (e.g., Oracle: data, redo, archive, control files together)
- One protection group per application tier, not one per volume — coordinated snapshots are the primary value
- Protection groups can contain volumes, hosts, or host groups; use host-group membership for dynamic inclusion of new volumes connected to that host

### Snapshot Schedule Design
- Minimum recommended schedule: hourly snapshots, 24-hour retention for near-term recovery
- Augment with daily snapshots retained for 7-30 days depending on RPO/SLA requirements
- Use per-minute snapshots only for critical OLTP workloads with very low RPO requirements — this increases snapshot metadata overhead
- Test recovery from snapshots quarterly; use writable clones for non-disruptive recovery testing

### Snapshot Offload
- Configure protection group snapshot replication to a remote target for off-array copies:
  - Remote FlashArray (async replication)
  - FlashBlade (NFS snapshot offload target for long-term retention)
  - Amazon S3 or other S3-compatible targets
- Offloading to FlashBlade is the most cost-effective for high-volume snapshot retention on-premises

### SafeMode Configuration
- Enable SafeMode on all production arrays — it should be treated as a baseline, not optional
- Set eradication timer to at least 72 hours for production; consider 7+ days for compliance environments
- Enable **Auto-On SafeMode for New Arrays** globally — ensures all new arrays are protected from deployment
- Enable **Default Protection SafeMode** — all new volumes are automatically covered
- Verify SafeMode configuration via Pure1 Security Assessment; it will flag uncovered volumes

### Snapshot Consistency for Databases
- Use application-consistent snapshots via the relevant plugin:
  - VMware: use VADP integration (snapshot is quiesced by VMware tools)
  - SQL Server: use VSS provider or Pure Storage PowerShell SDK `New-PfaVolumeDatabaseSnapshot`
  - Oracle: use Pure Storage Oracle integration scripts (available in Pure support portal)
- Never rely on crash-consistent snapshots for write-heavy transactional databases without application-level quiescing

---

## ActiveCluster Design

### Pre-Deployment Checklist
- Verify round-trip latency between arrays is under 11 ms — measure with actual replication traffic, not just ICMP ping
- Plan replication network bandwidth: measure peak write throughput on each array and multiply by 2x for synchronous bi-directional replication plus resync headroom
- Deploy redundant switched replication network — no direct connections permitted
- Confirm Pure1 Cloud Mediator is reachable from both arrays (outbound HTTPS to Pure's cloud endpoint)
- If cloud mediator is blocked, deploy on-premises mediator VM on a third-site network segment

### Pod (Stretched Storage Container) Design
- Put all volumes of a workload into a **single pod** — pod-level consistency ensures all member volumes fail over atomically
- Limit pod membership to volumes that genuinely need synchronous replication — each volume in a pod adds replication overhead
- Separate workloads that do not require synchronous replication into standard (non-pod) volumes

### Uniform vs. Non-Uniform Topology
- **Uniform (preferred for metro clusters):** Hosts at both sites access storage at both sites; requires stretched FC fabric or NVMe-oF fabric spanning sites; provides true active/active with transparent failover
- **Non-Uniform (simpler for DR):** Each host accesses only its local array; simpler network design but recovery requires host-side path reconfiguration; increases effective RTO
- Choose Uniform if the stretch distance allows FC/NVMe fabric extension; choose Non-Uniform for longer distances or where cross-site fabric is impractical

### Mediator Considerations
- **Cloud mediator:** Always the preferred choice; hosted by Pure, no customer management, physically separate from both sites
- **On-premises mediator:** Deploy on a third network that is independently powered and connected from both array sites; a Raspberry Pi or minimal VM at a third location is sufficient
- Do not co-locate the mediator with either array — it must be independent for split-brain arbitration to work

### VMware vMSC (vSphere Metro Storage Cluster)
- ActiveCluster is VMware vSphere Metro Storage Cluster (vMSC) certified
- Use vSphere HA with vMSC awareness enabled — configure HA to understand that storage is on both sites
- Set preferred site affinity for VMs via VM/Host Groups and VM/Host Rules to keep I/O local under normal operation
- Use Uniform topology for vMSC — hosts at both sites must see the same datastores

### ActiveCluster Monitoring
- Monitor via Pure1 Active Replication Monitoring — check pod state (synced/unsynced), mediator health, and replication lag
- Alert on pod "degraded" status (pod is syncing but one copy is behind) — this indicates an impending protection gap
- Test planned failover at least annually using the `purepod failover` command

---

## Kubernetes Integration

### CSI Driver Deployment
- Deploy the Pure Storage CSI driver via the official Helm chart: `purestorage/helm-charts`
- Configure FlashArray and FlashBlade backends in the CSI driver ConfigMap with API tokens (use read/write tokens, not admin tokens for least-privilege)
- Enable CSI topology if deploying across multiple sites or availability zones — this ensures volumes are created on the array closest to the scheduled pod

### Storage Classes
- Define multiple StorageClasses for different tiers:
  - `pure-block`: Default FlashArray block volume, RWO (ReadWriteOnce)
  - `pure-file`: FlashBlade NFS, RWX (ReadWriteMany) for shared access
  - `pure-block-clone-enabled`: Enables CSI volume cloning
- Set `reclaimPolicy: Retain` for production persistent volumes — prevents accidental deletion when PVC is deleted
- Set `reclaimPolicy: Delete` for dev/test environments to avoid snapshot accumulation

### Volume Provisioning in Kubernetes
- The CSI driver automatically selects the best FlashArray based on capacity, performance load, health, and policy labels
- Use PSO labels/annotations on StorageClasses to target specific arrays when placement control is needed
- Set appropriate `volumeBindingMode: WaitForFirstConsumer` to enable topology-aware scheduling

### Data Protection for Kubernetes Workloads
- Use PX-Backup (Portworx) for application-consistent Kubernetes backup — it integrates with FlashArray snapshots
- For stateless microservices with external state: standard Kubernetes backup tools are sufficient
- For stateful databases on Kubernetes: use PX-DR with ActiveDR replication for near-zero RPO DR

### Resource Limits and Quotas
- Set Kubernetes ResourceQuotas on PVC requests per namespace to prevent storage overconsumption
- Monitor PVC-to-volume mapping via Pure1 to correlate Kubernetes namespaces with FlashArray volumes
- Use PSO volume naming convention knowledge to identify which Kubernetes namespace owns which FlashArray volume

---

## Performance Optimization

### Array-Level Tuning
- Do not manually tune garbage collection or data reduction — Purity manages these globally; intervention degrades performance
- QoS: only set explicit per-volume limits when strict workload isolation is contractually required; otherwise leave Purity's continuous QoS in control
- Ensure all paths are active and balanced — uneven path distribution causes artificial bottlenecks

### Network Configuration for Maximum Performance
- Use jumbo frames (MTU 9000) end-to-end for iSCSI and NVMe/TCP — array side, switch side, and host side must all match
- For NVMe/RoCE: configure PFC (Priority Flow Control) and ECN (Explicit Congestion Notification) on switches — DCQCN is the recommended congestion management protocol
- For iSCSI: enable flow control on switch ports connected to FlashArray; disable it on host-side iSCSI NICs
- Bond/LACP aggregate host-side NICs for bandwidth if needed — FlashArray supports active/active multipath across bonded uplinks

### VMware-Specific Optimizations
- Set ESXi SATP (Storage Array Type Policy) to `VMW_SATP_ALUA` for FlashArray volumes
- Set PSP (Path Selection Policy) to `VMW_PSP_RR` (Round Robin) with `iops=1` setting — Pure recommends 1 I/O per path switch, not the default 1000
- Configure vSphere Storage I/O Control (SIOC) with care — FlashArray's internal QoS already manages I/O fairness; SIOC can create conflicts
- Enable ESXi iSCSI software adapter with separate vmkernel ports per uplink for path isolation

### Database-Specific Tuning
- **SQL Server:** Enable instant file initialization; set database files to pre-allocated sizes; use multiple data files per filegroup aligned with array geometry (no fixed stripe size needed — array handles it)
- **Oracle:** Use ASM (Automatic Storage Management) with 1 MB AU size; align extent sizes; do not use raw devices
- **PostgreSQL:** Set `random_page_cost = 1.0` in postgresql.conf — flash has effectively zero seek penalty; default of 4.0 causes suboptimal query plans

### Snapshot Impact
- Scheduled snapshots have near-zero performance impact — copy-on-write only writes modified blocks
- Avoid scheduling snapshot offload (replication) during peak write hours — offload copies snapshot data over the replication network and adds WAN bandwidth consumption
- Writable clones (volume copies) do not consume additional flash until data diverges from the source — safe for dev/test without performance impact on production

---

## Capacity Planning

- Monitor effective capacity utilization (not raw/provisioned) via Pure1 dashboards
- Alert at 70% effective capacity consumed — Pure1 Workload Planner provides forecasting curves
- Data reduction ratios fluctuate with workload changes — re-evaluate quarterly
- When adding DFMs: use Evergreen//Forever NR-Capacity or coordinate through Evergreen//One scaling request
- Avoid letting snapshots accumulate unchecked — snapshot metadata consumes catalog space; set retention policies on all protection groups

---

## References
- SAN Guidelines for Maximum Performance: https://support.purestorage.com/bundle/m_san/page/Solutions/VMware_Platform_Guide/User_Guides_for_VMware_Solutions/FlashArray_VMFS_RDM_VMware_Best_Practices_User_Guide/library/common_content/r_san_guidelines_for_maximizing_pure_performance.html
- ActiveCluster Setup Guide: https://blog.purestorage.com/purely-technical/setting-up-flasharray-active-active-replication-activecluster/
- ActiveCluster Background: https://www.penguinpunk.net/blog/pure-storage-activecluster-background-information/
- ActiveDR White Paper: https://www.purestorage.com/content/dam/pdf/en/white-papers/wp-purity-activedr.pdf
- Async Replication Best Practices: https://support-be.purestorage.com/bundle/FlashArray_Asynchronous_Replication_Best_Practices_Guide_2/raw/resource/enus/FlashArray_Asynchronous_Replication_Best_Practices_Guide_2.pdf
- PSO Helm Charts: https://github.com/purestorage/helm-charts
- Portworx CSI Topology: https://docs.portworx.com/portworx-enterprise/operations/operate-kubernetes/cluster-topology/csi-topology
- NVMe-oF Leaf-Spine Design Guide: https://www.purestorage.com/content/dam/pdf/en/white-papers/wp-arista-pure-deploying-nvme-of-enterprise-leaf-spine-architecture.pdf
- SafeMode 101: https://www.purestorage.com/solutions/cyber-resilience/ransomware/safemode.html
- vMSC with ActiveCluster: https://support.purestorage.com/Solutions/VMware_Platform_Guide/User_Guides_for_VMware_Solutions/ActiveCluster_with_VMware_User_Guide/vSphere_Metro_Storage_Cluster_With_ActiveCluster:_Overview_and_Introduction
