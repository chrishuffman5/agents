# HPE Alletra Best Practices

## Volume Design

### General Principles
- Always use thin provisioning (default). Monitor consumed vs provisioned in InfoSight.
- Enable inline dedup + compression unless workload is pre-compressed/pre-encrypted.
- Reserve 20-30% pool capacity for snapshots on active OLTP volumes.
- Use retention policies to auto-expire snapshots (7 daily, 4 weekly, 12 monthly).

### Alletra 5000/6000
- Assign workload-appropriate performance policies (Exchange, SQL, Oracle, VMware, etc). Do not leave on "Default" for production.
- Block size alignment: SQL 64KB, Oracle 8KB, VMware VMFS 1MB.
- QoS: use `limitIops`/`limitMbps` on lower-priority volumes. Leave high-priority unlimited.
- Group related volumes into Volume Collections for crash-consistent replication.
- Single pool per array unless isolation mandated. Use Folders for multi-tenancy.

### Alletra 9000
- Define Application Sets at volume creation (SQL Server, Oracle, SAP HANA, etc) — auto-tunes parameters.
- Do not over-segment into many small volumes; fewer larger volumes reduce metadata overhead.
- Snapshots are read-write clones — use for instant dev/test without copy overhead.
- Peer Persistence: tested up to 1ms RTT (~150km). Mediator on third site (not co-located). Test failover quarterly. Set VMware DRS/HA affinity for local site preference.

### Alletra MP B10000 (Kubernetes)
- Separate StorageClasses per protocol and tier: `alletra-nvmetcp-gold`, `alletra-iscsi-silver`, `alletra-fc-bronze`.
- Use `accessProtocol: nvmetcp` for latency-sensitive workloads.
- Scale decisions: CPU saturation = add compute nodes; pool > 70% = add drives; both = add chassis.
- APP for K8s: Pod Monitor labels on all pods, Quorum Witness on third site, test failover in staging.
- Hostname limit: 27 characters (protocol prefixes consume additional).
- Volume attachments: 200 recommended per node (250 tested for iSCSI).

## Data Protection

### Snapshot Management
Tiered retention: hourly (24-48h), daily (14-30d), weekly (8-12w), monthly (12-24m). Application-aware quiescing for databases.

### Veeam Integration
Use Veeam Storage Integration (HPE Plugin) for array-level snapshots. Instantaneous, no application quiesce window. 80-90% backup window reduction. After read, snapshot auto-removed unless retained.

### StoreOnce
Long-term retention via Catalyst over IP. 10:1 to 60:1 dedup ratio. Cloud Bank Storage for cold backup tiering. B10000: direct snapshot-to-StoreOnce path.

### Replication

| RPO | Mode |
|---|---|
| Zero | Synchronous (Peer Persistence) |
| < 5 min | Async, 5-minute schedule |
| < 1 hour | Async, 15-30 min schedule |
| Daily | Async daily or snapshot copy |

Synchronous adds write latency = RTT. Benchmark before production. Test failover/failback quarterly. Document failback procedures.

## InfoSight Usage

### Daily
Review Wellness Dashboard each morning. Filter by severity: Critical/Warning first. Check Predictive Alerts for upcoming issues.

### Performance
Use workload heatmaps for latency spikes by volume. Correlate with VMware host metrics via VM Analytics. Review Cross-Stack analytics for root cause across layers.

### Capacity
30-day and 90-day forecasts. Export monthly reports. Alert at 70% pool, critical at 80%.

### Proactive Cases
Enable automatic case creation for hardware failures. Configure notification emails to on-call distribution list.

## Performance Tuning

### Host-Side
- Multipath on all hosts. Linux: `device-mapper-multipath` with `round-robin`. Windows: MPIO. Min 2 paths, prefer 4 for FC.
- iSCSI: dedicated NICs, MTU 9000 end-to-end, disable TOE if unstable. Linux: `nr_requests 1024`, I/O scheduler `none`.
- NVMe/TCP (B10000): 25GbE min, 100GbE recommended. Flat L2 network (no routing). Tune interrupt coalescing.
- FC: single-initiator/single-target zoning. Small, documented zonesets. NPIV for virtual environments.

### Array-Side
- 5000/6000: separate pools for extreme performance differences. Monitor cache hit rates (< 80% = investigate).
- 9000: do not manually pin workloads to nodes — all-active design distributes optimally.

## Kubernetes Integration

### StorageClass Example (B10000 NVMe/TCP)
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alletra-nvmetcp-gold
provisioner: csi.hpe.com
parameters:
  csi.storage.k8s.io/fstype: xfs
  accessProtocol: nvmetcp
reclaimPolicy: Retain
volumeBindingMode: Immediate
allowVolumeExpansion: true
```

- Always `reclaimPolicy: Retain` for production. `allowVolumeExpansion: true` for online growth.
- `WaitForFirstConsumer` in multi-zone or rack-aware clusters.
- Use `edit` role (not `super`) for B10000 CSP. `poweruser` for 5000/6000. LDAP from v2.5.2+.
- Store credentials as Kubernetes Secrets; use sealed secrets or Vault for GitOps. Rotate every 90 days.
- Veeam Kasten K10 + CSI VolumeSnapshots for K8s backup. OADP for OpenShift.
- APP DR: Pod Monitor labels, Pod Disruption Budgets, three-site topology.
