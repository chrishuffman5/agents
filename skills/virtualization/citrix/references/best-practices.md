# Citrix Hypervisor / XenServer Best Practices

## Pool Design

- **Homogeneous hardware** -- Keep all hosts in a pool at the same XenServer version, same CPU vendor, and same NIC/HBA models. Heterogeneity causes migration failures and complicates troubleshooting.
- **CPU masking for mixed generations** -- Use `xe pool-param-set` to mask advanced CPU flags when mixing CPU generations within the same vendor family. Test migration before promoting to production.
- **N+1 capacity** -- Size the pool so all workloads fit on N-1 hosts. HA cannot guarantee VM restarts if the pool lacks spare compute and memory capacity.
- **Pool size limits** -- Practical limit is 16 hosts per pool. Larger pools increase pool master load and complicate rolling upgrades.
- **Dedicated pool master** -- For large pools, consider dedicating the master host to management duties with minimal guest VMs.

## Storage Selection

| Workload | Recommended SR | Rationale |
|----------|---------------|-----------|
| General-purpose VMs | NFS | Simple operations, thin provisioning, fast cloning |
| Databases, high IOPS | iSCSI or Fibre Channel | Block-level, predictable latency |
| VDI boot storms | NFS + IntelliCache | Local SSD caching offloads shared SR reads |
| Single-host lab | Local LVM or ext | No shared storage dependency |
| Active-active vGPU | GFS2 | Only SR supporting simultaneous multi-host read-write |

### Storage Practices

- Enable multipath (MPxIO) for iSCSI and FC SRs -- provides redundancy and prevents single-path failures from taking down VMs.
- Monitor SR free space proactively -- thin SR exhaustion crashes VMs without warning. Set alerts at 80% utilization.
- Limit VHD snapshot chains to fewer than 10 levels. Schedule `xe sr-scan` to trigger coalescing and flatten chains.
- Use jumbo frames (MTU 9000) on dedicated iSCSI networks for higher throughput and lower CPU overhead.
- Separate storage traffic onto dedicated NICs or VLANs -- never share with management or VM traffic.

## dom0 Sizing

| Host VM Count | Recommended dom0 RAM |
|--------------|---------------------|
| 1-20 VMs | 2-4 GB (default) |
| 20-50 VMs | 4-6 GB |
| 50+ VMs | 6-8 GB |

dom0 memory pressure degrades all guest I/O because dom0 hosts the I/O backends. Monitor with `free -m` in dom0 and increase allocation if swap usage is non-trivial.

## Network Architecture

- **Four-network minimum** -- Separate management, storage, VM traffic, and migration onto distinct NICs or VLANs.
- **Bond all critical networks** -- Use LACP (802.3ad) where switch support exists; fall back to active-backup for management.
- **10 GbE for storage and migration** -- 1 GbE is insufficient for iSCSI and live migration under load.
- **Jumbo frames only on storage** -- Do not enable MTU 9000 on management or VM networks unless all endpoints support it.
- **Consistent VLAN IDs** -- Use the same VLAN numbering across all hosts to simplify pool operations and migration.

## Backup Strategy

- **Pool database backup** -- Run `xe pool-dump-database` daily. This file contains all VM and pool metadata and is critical for disaster recovery.
- **VM export** -- Use `xe vm-export` for full VM backup. Works on running VMs (snapshot-based). Schedule during low-activity windows.
- **Changed Block Tracking (CBT)** -- Available in XenServer 8.2+. Enables incremental backup via the API. Supported by Veeam, NAKIVO, and Storware.
- **Snapshot retention** -- Keep snapshots short-lived (hours to days, not weeks). Long-lived snapshots build deep VHD chains that degrade performance.
- **Test restores regularly** -- A backup that has never been restored is not a backup. Test `xe vm-import` and `xe pool-restore-database` quarterly.

## Patching and Upgrades

- **Test hotfixes on a non-production host first** -- XenServer hotfixes can cause regressions. Validate before rolling across the pool.
- **Rolling upgrade order** -- Upgrade slaves first, then the pool master last. Use `xe host-evacuate` to drain VMs before patching each host.
- **Verify NTP synchronization** -- Time drift between hosts causes HA false fencing and certificate validation failures. Use chrony on all hosts.
- **Keep XenCenter version aligned** -- Mismatched XenCenter and XenServer versions cause UI errors and missing features.

## Monitoring

- **Enable SNMP or syslog forwarding** -- dom0 supports syslog export to a central collector for event correlation.
- **Track SR utilization trends** -- Capacity planning based on historical growth prevents emergency thin-provisioning exhaustion.
- **Monitor dom0 CPU and memory** -- High dom0 CPU usage indicates I/O bottleneck. High memory pressure causes OOM kills that affect all guests.
- **Review /var/log/xensource.log** -- Primary XAPI log. Check after any failed operation for detailed error context.
- **Automate health checks** -- Script `xe host-list`, `xe sr-list`, and `xe vm-list` to run on a schedule and alert on anomalies.
- **RRDD metrics** -- XAPI's RRDD daemon collects per-host and per-VM metrics (CPU, memory, disk I/O, network I/O) in round-robin databases. Access via XenCenter performance graphs or XAPI API calls.
- **Set baselines early** -- Capture baseline performance data within the first week of deployment. Without baselines, anomaly detection is guesswork.

## Security Hardening

- **Restrict XenCenter access** -- Limit management network access to authorized workstations. Use firewall rules in dom0 to restrict XAPI port 443.
- **Change default root password** -- XenServer installs with a root password set during setup. Rotate it regularly and use SSH key authentication where possible.
- **Disable unused NICs** -- Unplugged or unused PIFs should be removed from management to reduce the attack surface.
- **Enable TLS certificate validation** -- Use trusted certificates for XAPI instead of self-signed defaults, especially in production pools.
- **Audit RBAC roles** -- XenServer supports Role-Based Access Control. Assign least-privilege roles (pool-operator, vm-power-admin, vm-admin, read-only) instead of granting root to all administrators.
- **Keep dom0 patched** -- dom0 is a CentOS-based Linux system. Apply security patches promptly, especially for kernel and OpenSSL vulnerabilities.

## Capacity Planning

- **Track VM density per host** -- Monitor the ratio of running VMs to available host resources. Over-provisioning vCPUs beyond 4:1 degrades performance for CPU-intensive workloads.
- **Memory over-commitment limits** -- DMC allows soft over-commitment, but total dynamic-min across all VMs should not exceed physical RAM minus dom0 reservation.
- **Plan SR growth** -- Project VDI growth rate from historical data. For NFS SRs, ensure the NFS server can scale storage and IOPS to meet demand.
- **Document pool topology** -- Maintain a current diagram of hosts, SRs, networks, bonds, and VLANs. This accelerates troubleshooting and onboarding.
