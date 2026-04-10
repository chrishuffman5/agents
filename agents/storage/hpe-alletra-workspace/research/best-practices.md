# HPE Alletra Best Practices

## Volume Design

### General Principles

**Thin Provisioning Always:**
- Always use thin provisioning (the default). Thick provisioning pre-allocates capacity and provides no benefit for most workloads on all-flash or NVMe arrays.
- Monitor consumed vs. provisioned capacity in InfoSight to identify over-provisioning waste.

**Data Reduction Alignment:**
- Enable inline deduplication and compression on all volumes unless the workload is known to use pre-compressed or pre-encrypted data (e.g., backup target volumes receiving already-compressed data, encrypted databases).
- For encrypted database volumes, deduplication effectiveness drops to near zero; disable dedup and rely on compression only.
- Test data reduction ratios in InfoSight for 30+ days before committing to effective-capacity sizing.

**Snapshot Space Budget:**
- Account for snapshot space in pool capacity planning. Reserve 20–30% of pool capacity for snapshots on active OLTP volumes.
- Delete obsolete snapshot schedules rather than letting them accumulate — old snapshots consume pool space and slow pool rebalancing.
- Use retention policies to auto-expire snapshots (e.g., 7 daily, 4 weekly, 12 monthly).

---

### Alletra 5000/6000 Volume Design

**Performance Policies:**
- Assign workload-appropriate performance policies when creating volumes. HPE provides pre-defined policies for common workloads: Exchange, SQL Server, Oracle, SharePoint, VMware, Hyper-V, Generic.
- Create custom performance policies for workloads that don't fit standard templates.
- Do not leave volumes on the "Default" performance policy for production workloads — it is tuned for general use and may not match I/O alignment requirements.

**Volume Block Size Alignment:**
- CASL architecture handles variable block sizes automatically, but ensure application-level I/O alignment matches storage expectations:
  - SQL Server: 64KB I/O size, 64KB NTFS allocation unit
  - Oracle: 8KB DB block size, set OS I/O scheduler to `none` or `noop`
  - VMware VMFS: 1MB block size datastores; use VMFS-6 for modern vSphere

**QoS (IOPS/Bandwidth Limits):**
- Use `limitIops` and `limitMbps` parameters on lower-priority volumes to prevent a single workload from monopolizing array resources.
- Set limits via the InfoSight portal, REST API, or CSI Driver StorageClass parameters.
- Leave high-priority volumes unlimited; apply caps to dev/test and backup staging volumes.

**Replication Volume Collections:**
- Group related volumes into Volume Collections for consistent, crash-consistent replication snapshots.
- For application consistency: use application-aware quiescing (VSS for Windows, Oracle RMAN integration) before triggering snapshots.
- Synchronous replication (RPO=0): use only where truly required due to write latency penalty; asynchronous replication with short intervals (5–15 minutes) is sufficient for most workloads.

**Pool Design:**
- Use a single pool per array unless regulatory or performance isolation mandates multiple pools.
- Multiple pools fragment capacity and can lead to uneven utilization — InfoSight will flag pool imbalance.
- For multi-tenant environments (grouped arrays), use Folders within a pool to create logical boundaries without sacrificing capacity efficiency.

---

### Alletra 9000 Volume Design

**Application Sets:**
- When creating volumes on the 9000, define Application Sets to declare workload intent. The array OS automatically tunes volume parameters based on the application type.
- Available Application Sets include: SQL Server, Oracle, SAP HANA, Exchange, Generic, and others.
- Set Application Set at volume creation — changing it post-creation requires a volume migration.

**Striping Across All Nodes:**
- The all-active design automatically stripes volumes across all system resources. Do not attempt manual RAID group or drive selection — the system handles this optimally.
- Do not over-segment workloads across many small volumes when fewer larger volumes perform better (reduced metadata overhead).

**Snapshot Strategy:**
- Snapshot volumes on the 9000 are read-write clones; use them for dev/test instantly without data copy overhead.
- Schedule snapshots via Volume policies; use multiple overlapping schedules for granular recovery points (e.g., every 15 minutes for 24 hours, daily for 30 days).
- For Veeam backups: use Veeam Storage Integration to trigger array-side snapshots; this offloads I/O from the production array during backup.

**Peer Persistence Configuration:**
- Synchronous replication distance: tested up to 1ms RTT (approximately 150km, depending on link quality); consult HPE Pointnext for site survey before deployment.
- Mediator/Quorum Witness must be in a third site (not co-located with either array) — a mediator co-located with one array defeats the purpose of automatic failover.
- Test failover quarterly: fail over the primary array and verify host continuity without application restarts.
- Set VMware DRS/HA affinity rules to prefer the local site's hosts to minimize cross-site I/O under normal operation.

**SAP HANA Specifics:**
- Use dedicated CPGs (capacity pool groups) for HANA data and log volumes; separate HANA shared from data/log for performance isolation.
- Enable persistent memory (pmem) if available in the configuration for HANA log writes.
- Validate with HPE's SAP HANA Configuration Guide (published by HPE Pointnext for each Alletra model).

---

### Alletra Storage MP B10000 Volume Design

**StorageClass Design (Kubernetes):**
- Define separate StorageClasses per access protocol and workload tier:
  - `alletra-nvmetcp-gold`: NVMe/TCP, no limits, for production databases
  - `alletra-iscsi-silver`: iSCSI, IOPS limits, for general application workloads
  - `alletra-fc-bronze`: FC, conservative limits, for batch/archive
- Use `accessProtocol: nvmetcp` for latency-sensitive Kubernetes workloads where supported.

**Independent Scale Decisions:**
- When adding capacity (more NVMe drives) vs. adding performance (more compute nodes), monitor InfoSight telemetry:
  - CPU saturation on existing compute nodes → add compute nodes
  - Capacity pool utilization above 70% → add drive capacity
  - Both constrained → add full chassis (drives + compute)

**Active Peer Persistence (APP) for Kubernetes:**
- Ensure all Kubernetes nodes have Pod Monitor labels for automatic pod rescheduling during failover.
- The Quorum Witness (third-site) must be a dedicated VM or service — it cannot be on either primary or secondary storage node.
- Thoroughly test APP failover in staging before production: simulate primary array outage and verify pods reschedule automatically.
- Note: APP prohibits provisioning new volumes during a primary array outage; maintain headroom on both sites.

**Hostname Length:**
- Kubernetes node hostnames must not exceed 27 characters for HPE CSI Driver compatibility. Protocol prefixes (iqn-, wwn-, nqntcp-) consume additional characters — plan your naming convention before cluster deployment.

**Volume Attachment Limits:**
- Maximum tested: 250 VolumeAttachments per compute node (iSCSI); HPE recommends staying below 200 to maintain headroom.
- For NVMe/TCP: limits vary; consult current SCOD documentation at scod.hpedev.io.

---

## Data Protection Best Practices

### Snapshot Management

**Retention Strategy:**
- Follow a tiered retention policy:
  - Hourly snapshots: retain 24–48 hours (catch recently corrupted data)
  - Daily snapshots: retain 14–30 days
  - Weekly snapshots: retain 8–12 weeks
  - Monthly snapshots: retain 12–24 months (compliance)
- Use application-aware quiescing for database volumes before scheduled snapshots.

**Snapshot-Based Backup with Veeam:**
- Use Veeam Storage Integration (HPE Storage Plugin) to trigger array-level snapshots instead of agent-based backups.
- Array snapshots are instantaneous and do not require application quiesce windows; Veeam then mounts the snapshot and reads data, not production volumes.
- Configure Veeam backup jobs to "Use HPE storage snapshot" to reduce backup window time by 80–90% for large VMs.
- After Veeam reads the snapshot, the snapshot is automatically removed unless configured for retention.

**StoreOnce Integration:**
- For long-term retention, send Veeam backup copies to HPE StoreOnce via Catalyst over IP.
- StoreOnce deduplication reduces on-disk backup footprint by 10:1 to 60:1 depending on data type.
- Enable Cloud Bank Storage on StoreOnce to tier cold backup data to AWS, Azure, or GCP S3-compatible storage.
- For B10000: use the direct snapshot-to-StoreOnce integrated backup path for the lowest-overhead backups without Veeam.

### Replication Design

**RPO Requirements:**
| RPO Target | Recommended Replication Mode |
|------------|------------------------------|
| 0 (zero loss) | Synchronous (Peer Persistence) |
| < 5 minutes | Asynchronous, 5-minute schedule |
| < 1 hour | Asynchronous, 15–30 minute schedule |
| Daily | Asynchronous, daily schedule or snapshot copy |

**Synchronous Replication Considerations:**
- Synchronous replication adds write latency equal to round-trip network latency between sites.
- Benchmark application response time with synchronous replication enabled before committing to production.
- Use asynchronous replication for latency-sensitive workloads (OLTP) unless zero RPO is a hard requirement.

**Test Failover and Failback:**
- Schedule quarterly DR drills: fail over to secondary array, run application smoke tests, then fail back.
- Document failback procedures — the reverse replication setup takes time; don't discover the process during an actual disaster.
- For Peer Persistence: test mediator failure scenarios separately from array failure scenarios.

---

## InfoSight Usage Best Practices

**Daily Checks:**
- Review the InfoSight Wellness Dashboard each morning for new recommendations or alerts.
- Filter by severity: address "Critical" and "Warning" items before "Informational."
- Check the "Predictive Alerts" view for upcoming issues (drive wear, capacity exhaustion forecasts, controller temperature trends).

**Performance Analysis:**
- Use InfoSight's workload heatmaps to identify latency spikes by volume or application.
- Correlate storage latency spikes with VMware host metrics (using InfoSight's VM Analytics feature) to distinguish storage-caused vs. compute-caused application slowness.
- Review the "Cross-Stack" analytics view if available — it correlates storage, server, and network telemetry to find root cause across infrastructure layers.

**Capacity Planning:**
- InfoSight provides a 30-day and 90-day capacity forecast based on growth trend modeling.
- Export capacity reports monthly to track against GreenLake committed consumption tiers.
- Alert thresholds: set warnings at 70% pool utilization and critical at 80% to allow time for expansion without emergency ordering.

**Proactive Case Management:**
- Enable automatic case creation in InfoSight for hardware failures (drive, power supply, fan, controller).
- HPE Proactive Care monitoring triggers a support case before the customer detects a failure in many scenarios.
- Configure notification emails for wellness events to on-call storage team distribution lists.

**Config Baseline:**
- Use InfoSight's configuration comparison tool to identify arrays that have drifted from the established baseline configuration.
- After any major configuration change (new volume policy, replication setup, firmware update), capture a new baseline.

---

## Performance Tuning

### Host-Side Configuration

**Multipath I/O:**
- Enable multipath on all hosts connecting to Alletra arrays.
- For Linux: use `device-mapper-multipath` with `round-robin` path selector for active-active arrays (6000, 9000, B10000).
- For Windows: use MPIO with "Round Robin with Subset" or "Least Queue Depth" policy.
- Configure at minimum 2 paths per volume; 4 paths preferred for FC environments.

**iSCSI Tuning:**
- Use dedicated iSCSI NICs (not shared with general network traffic).
- Enable Jumbo Frames (MTU 9000) end-to-end: array ports, switches, and host NICs must all be configured consistently.
- Disable TCP offload engine (TOE) if experiencing iSCSI instability; modern NICs with proper drivers generally work well with TOE enabled.
- For Linux: set `nr_requests` to 1024 and I/O scheduler to `none` (for NVMe or flash-backed storage).

**NVMe/TCP Tuning (B10000):**
- Use high-speed NICs (25GbE minimum; 100GbE recommended for high throughput workloads).
- NVMe/TCP requires flat L2 network between hosts and B10000 array ports; routing is not supported.
- Set host NIC interrupt coalescing appropriately — too aggressive causes latency spikes; too little increases CPU overhead.

**FC Zoning:**
- Use single-initiator / single-target zoning (one host port per zone, one array port per zone). Avoid broad zones that allow multiple initiators per zone.
- Keep zonesets small and well-documented; large zonesets cause slower fabric recalculation on changes.
- Use NPIV on FC switches to simplify zoning for virtual environments.

### Array-Side Tuning

**Volume Placement (5000/6000):**
- Use separate pools for workloads with extreme performance differences (e.g., dedicated pool for backup staging volumes to isolate their sequential I/O from OLTP random I/O).
- Monitor pool latency by pool in InfoSight; if a pool shows consistently higher latency, investigate which volumes are generating the most I/O.

**Cache Optimization (5000/6000):**
- CASL architecture uses NVMe or SSD as read cache automatically. If cache hit rates drop below 80% consistently, investigate whether the working set exceeds cache capacity.
- Consider moving hot datasets to a higher tier (Alletra 6000 or 9000) if sustained cache miss rates cause unacceptable latency.

**9000 Workload Prioritization:**
- The 9000's OS auto-prioritizes workloads based on latency SLAs. If you have explicit SLA requirements, define them in Application Sets.
- Do not manually pin workloads to specific controller nodes — the all-active design distributes I/O optimally.

---

## Kubernetes Integration Best Practices

### StorageClass Design

```yaml
# Example: Alletra MP B10000 NVMe/TCP production StorageClass
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alletra-nvmetcp-gold
provisioner: csi.hpe.com
parameters:
  csi.storage.k8s.io/fstype: xfs
  accessProtocol: nvmetcp
  description: "Gold tier - NVMe/TCP production"
  # limitIops: "-1"   # -1 = unlimited; set a number to cap
  # limitMbps: "-1"
reclaimPolicy: Retain
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

**Key Parameter Guidance:**
- Always set `reclaimPolicy: Retain` for production PVCs — `Delete` will remove the underlying volume when the PVC is deleted.
- Set `allowVolumeExpansion: true` to enable online volume growth without pod restart.
- Use `volumeBindingMode: WaitForFirstConsumer` in multi-zone or rack-aware clusters to ensure volumes provision in the correct failure domain.
- Set `accessProtocol` explicitly — never rely on defaults for protocol selection in production.

### Role and Security

**Least Privilege Access:**
- Use `edit` role (not `super`) for CSP authentication on Alletra MP B10000.
- Use `poweruser` (not `administrator`) for Alletra 5000/6000 if your use case allows; use `administrator` only when required.
- From CSI Driver v2.5.2+: use LDAP accounts bound to array roles instead of local array accounts for centralized credential management and rotation.

**Secret Management:**
- Store CSP credentials as Kubernetes Secrets in the `hpe-storage` namespace.
- Use sealed secrets or Vault-backed secrets for GitOps workflows instead of plaintext Secrets in git.
- Rotate credentials on a defined schedule (90 days recommended) and update Kubernetes Secrets before the array credentials expire.

### Volume Limits and Node Sizing

- Size Kubernetes worker nodes with the 200 VolumeAttachments-per-node limit in mind.
- For high-density storage workloads (databases, analytics), use dedicated storage-attached node pools.
- Monitor actual VolumeAttachment counts with: `kubectl get volumeattachments | wc -l`

### Backup for Kubernetes Volumes

- Integrate Veeam Kasten K10 with HPE CSI Driver for Kubernetes-native backup.
- Kasten K10 uses CSI VolumeSnapshots and array-level snapshots for application-consistent Kubernetes backup.
- As of 2025, `volumeMode: Block` backup for Kasten is supported on B10000.
- For OpenShift: use OADP (OpenShift API for Data Protection) with CSI snapshot integration.

### DR for Kubernetes with Active Peer Persistence

- Label Pods with HPE Pod Monitor labels to enable automatic pod rescheduling during APP failover.
- Use Pod Disruption Budgets to prevent too many pods rescheduling simultaneously during failover.
- Test APP failover scenarios in staging Kubernetes clusters before deploying production workloads that depend on zero-RPO recovery.
- Maintain at minimum a three-site topology: primary site (array + Kubernetes nodes), secondary site (array + Kubernetes nodes), Quorum Witness (third-site VM or cloud instance).
