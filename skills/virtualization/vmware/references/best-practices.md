# VMware vSphere Best Practices Reference

Operational best practices for VMware vSphere environments. Covers VM sizing, NUMA alignment, DRS/HA tuning, snapshot management, hardening, and backup strategy.

---

## VM Sizing and Resource Management

### Right-Size VMs

Over-allocated vCPUs increase CPU scheduler overhead. Every vCPU must be scheduled simultaneously for SMP VMs, so adding unnecessary vCPUs causes co-stop (%CSTP) delays.

**Guidelines:**
- Start with 2 vCPUs for most workloads; scale up based on performance data
- Monitor CPU Ready (%RDY) with esxtop -- >5% per vCPU indicates contention
- Size memory to guest OS working set, not application maximum
- Use memory hot-add where guest OS supports it for dynamic scaling
- Review resource usage quarterly; reclaim unused capacity

### NUMA Alignment

VMs that span NUMA nodes suffer 30-40% memory access latency penalty for remote memory.

**Guidelines:**
- Size VMs to fit within a single NUMA node (vCPUs <= pCPUs per node)
- Monitor NUMA home node efficiency in esxtop (N%L = percentage of local memory)
- Avoid configuring VM sockets to exceed physical NUMA nodes
- For large VMs that must span NUMA: use wide NUMA topology (vNUMA, exposed automatically when vCPUs > cores per socket)

### Resource Pools

- Organize VMs into hierarchical pools with shares, reservations, and limits
- Use shares for relative priority (High=2000, Normal=1000, Low=500 per vCPU)
- Use reservations sparingly -- they lock physical resources
- Avoid deeply nested pools (2 levels maximum recommended)
- Never place VMs directly at the cluster root when resource pools exist -- they share the invisible "Resources" pool with unintended priority

### Memory Management

- Allow ballooning: keep VMware Tools installed and balloon driver enabled
- Avoid setting memory reservations unless required (FT VMs need full reservation)
- KSM (Kernel Same-page Merging) is intra-VM only by default since vSphere 6.0
- Monitor host memory state: High (green) > Soft > Hard > Low (red). Swap activity indicates Hard or Low state.
- Memory compression reduces swap I/O impact but adds CPU overhead

---

## DRS Configuration

- Set DRS to **Fully Automated** for production clusters
- Migration threshold 3 (conservative) for latency-sensitive workloads; 4-5 for general compute
- Create **VM-VM anti-affinity** rules for HA pairs (database primary/secondary, app tier redundancy)
- Use **VM-Host affinity** rules to pin licensed software to specific hosts (Windows per-host licensing)
- Review DRS faults weekly -- stuck affinity rules or resource constraints cause imbalance
- Enable **Predictive DRS** with Aria Operations for proactive load balancing
- Configure DRS groups before creating rules -- rules reference groups, not individual VMs

---

## HA Configuration

- **Admission Control**: use percentage-based policy. Set to percentage equivalent of one host (25% for 4-host cluster) for N+1
- **Heartbeat datastores**: select at least 2 from the cluster's shared datastores
- **VM restart priorities**: Highest for infrastructure (DC, DNS, vCenter), High for tier-1 apps, Medium for general, Low for dev/test
- **Proactive HA**: enable with compatible hardware (Dell, HPE) to migrate VMs off degrading hosts before failure
- **VM Component Protection (VMCP)**: configure response to APD (All Paths Down) and PDL (Permanent Device Loss) events
- **Orchestrated restart**: define VM-VM dependencies (start database before app server)
- Test HA annually by simulating host failure in a maintenance window

---

## Snapshot Management

Snapshots are the most common source of preventable storage problems in vSphere environments.

- **Automate deletion**: configure backup software to delete snapshots after backup completes
- **Alert on age**: set vCenter alarm for snapshots older than 24-72 hours
- **Maximum depth**: never exceed 3 snapshots in a chain
- **Consolidate orphaned snapshots**: check Tasks/Events for "Virtual machine disks consolidation needed" warnings
- **Never use snapshots as backups**: snapshots depend on the base VMDK; if the base is lost, snapshots are useless
- **Schedule consolidation**: consolidate during low-activity windows for VMs with large disks (consolidation is I/O intensive)
- **Monitor datastore space**: thin-provisioned VMs + active snapshots can consume space rapidly

```powershell
# Find snapshots older than 7 days
Get-VM | Get-Snapshot | Where-Object { $_.Created -lt (Get-Date).AddDays(-7) } |
    Select-Object VM, Name, Created, SizeGB | Sort-Object Created | Format-Table
```

---

## Template and Content Library Management

- Use **Content Library** for centralized template distribution across vCenter instances
- Name templates with version info: `win2022-hw20-2024Q4`
- Convert templates back to VMs for patching; reconvert after updates
- Use **Customization Specifications** for automated post-clone configuration (sysprep for Windows, cloud-init for Linux)
- Store ISOs and OVAs in Content Library for consistent distribution
- Subscribe remote sites to publisher Content Library for multi-site template sync

---

## ESXi Hardening

### Lockdown Mode
Enable Normal Lockdown on all production hosts. Define Exception Users for break-glass access. Use Strict Lockdown only in high-security environments with controlled physical console access.

### Services
- Disable SSH and ESXi Shell; enable only for troubleshooting with auto-timeout (15 minutes)
- Disable CIM (sfcbd) if hardware monitoring is handled by vendor agents (iDRAC, iLO)
- Disable SNMP if not in use

### Syslog
Forward logs to central syslog immediately after host deployment:
```bash
esxcli system syslog config set --loghost=tcp://syslog.corp.local:514
esxcli system syslog reload
esxcli network firewall ruleset set --ruleset-id=syslog --enabled=true
```

### NTP
Configure NTP on all hosts for certificate validity, log correlation, vSAN, and clustering:
```bash
esxcli system ntp set --server=ntp1.corp.local --server=ntp2.corp.local --enabled=true
```

### Certificates
- Default: VMCA-signed certificates
- Enterprise: subordinate VMCA to corporate CA
- Regenerate certificates after hostname/IP changes
- Use `certificate-manager` on VCSA for certificate operations

### Account Security
- Change default root password immediately on deployment
- Set password complexity and lockout thresholds
- Use Active Directory integration for named admin accounts
- Audit local accounts quarterly; remove unnecessary accounts

---

## Backup Strategy

### VADP Best Practices
- Deploy dedicated backup proxy VMs on each cluster (hot-add transport)
- Use **SAN transport** for FC environments (fastest)
- Enable **CBT** on all VMs: performance improvement for incremental backups is 10-50x
- Test CBT integrity periodically; reset CBT if backup application reports inconsistencies
- Disable CBT on VMs that should not be backed up (temp VMs, ephemeral workloads)

### Backup Schedule
- **Daily incremental** for all production VMs
- **Weekly full** for critical VMs (or synthetic full from incrementals)
- **Monthly long-term** retention copy to offsite/archive storage
- Stagger backup start times to avoid datastore I/O storms

### Restore Testing
- Test at least 1 full VM restore monthly to verify backup integrity
- Use Veeam SureBackup or equivalent isolated restore validation
- Document RTO (Recovery Time Objective) and RPO (Recovery Point Objective) per workload tier
- Test granular file-level restore (FLR) from image-level backups

### Snapshot Integration
- Backup tools create and delete snapshots automatically via VADP
- If a backup job fails mid-process, the snapshot may be orphaned -- monitor and clean up
- Large VMs (>1 TB) may need extended snapshot consolidation time
- Schedule backup windows when datastore I/O is lowest

---

## Storage Best Practices

### Datastore Sizing
- Keep datastore utilization below 80% for thin-provisioned workloads
- Size datastores for 20-30 VMs each (balance between isolation and management overhead)
- Use Datastore Clusters with Storage DRS for automated space and I/O balancing

### Multipathing
- Use **Round Robin** PSP for active-active arrays (better I/O distribution)
- Use **MRU** (Most Recently Used) PSP for active-passive arrays
- Configure IOPS limit for Round Robin to 1 (default is 1000, too infrequent for path switching)

### VMFS
- Align VMFS partition with storage array block boundaries (automatic in VMFS 6)
- Enable UNMAP for thin-provisioned LUNs (automatic in VMFS 6)
- Monitor SCSI reservation conflicts (ATS VAAI should prevent them on compatible arrays)

### NFS
- Dedicate NICs for NFS traffic on separate VLAN
- Enable jumbo frames end-to-end (NFS array, physical switch, ESXi vmk)
- Use NFS v4.1 for session trunking and Kerberos where supported

---

## Performance Monitoring Cadence

| Check | Frequency | Tool | Threshold |
|---|---|---|---|
| CPU Ready per VM | Daily | esxtop / vCenter | >5% per vCPU |
| Memory swap activity | Daily | esxtop / vCenter | Any SWCUR > 0 |
| Datastore latency | Daily | esxtop / vCenter | >20 ms SSD, >50 ms HDD |
| Snapshot age | Daily | PowerCLI script | >72 hours |
| Datastore free space | Weekly | vCenter alarm | <20% free |
| HA admission control | Weekly | vCenter | Must show "green" |
| DRS imbalance | Weekly | vCenter | DRS faults > 0 |
| vSAN health | Weekly | vSAN Health UI | Any red/yellow |
| Hardware health (CIM) | Weekly | vCenter HW status | Any warnings |
| NTP sync | Monthly | esxcli system ntp get | Offset > 1 second |
