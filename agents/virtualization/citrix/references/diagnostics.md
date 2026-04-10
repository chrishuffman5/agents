# Citrix Hypervisor / XenServer Diagnostics Reference

## xe Diagnostic Commands

### Host and Pool Status

```bash
# List all hosts with key parameters
xe host-list params=name-label,uuid,enabled,host-metrics-live

# Pool configuration and master identity
xe pool-list params=all

# Check HA status
xe pool-ha-compute-hypothetical-max-host-failures-to-tolerate
xe pool-list params=ha-enabled,ha-host-failures-to-tolerate

# Host CPU and memory utilization
xe host-param-get uuid=<host-uuid> param-name=memory-free
xe host-cpu-list host-uuid=<host-uuid>
```

### VM Diagnostics

```bash
# VMs with power state
xe vm-list params=name-label,power-state,uuid,resident-on

# VM guest metrics (requires Citrix VM Tools)
xe vm-guest-metrics-list

# VM console access
xe console-list vm-uuid=<vm-uuid>
```

### Storage Diagnostics

```bash
# SR utilization
xe sr-list params=name-label,physical-size,physical-utilisation,type

# Check for coalesce tasks
xe task-list | grep -i coalesce

# Trigger SR scan and coalesce
xe sr-scan uuid=<sr-uuid>

# List all VDIs with parent chain info
xe vdi-list sr-uuid=<sr-uuid> params=name-label,uuid,virtual-size,physical-utilisation,is-a-snapshot
```

### Network Diagnostics

```bash
# Physical interface status
xe pif-list params=uuid,device,VLAN,network-uuid,currently-attached,IP

# Bond status
xe bond-list params=uuid,master,slaves

# Check OVS bridge state (from dom0 shell)
ovs-vsctl show
ovs-ofctl dump-flows <bridge-name>
```

## Log Locations

| Log File | Contents |
|----------|----------|
| `/var/log/xensource.log` | Primary XAPI log -- all management operations, errors, and warnings |
| `/var/log/SMlog` | Storage Manager log -- SR operations, coalescing, VDI lifecycle |
| `/var/log/xen/xenstored-access.log` | XenStore access log -- inter-domain communication |
| `/var/log/audit.log` | Audit trail for XAPI operations |
| `/var/log/daemon.log` | System daemon messages including OVS and multipathd |
| `/var/log/kern.log` | Kernel messages from dom0 |

Xen hypervisor messages (ring buffer): `xl dmesg`

## dom0 Performance Commands

```bash
# CPU and process overview
top -b -n1

# Disk I/O statistics
iostat -x 1 5

# Memory usage
free -m

# Network interface statistics
ip -s link show

# Multipath status (iSCSI/FC)
multipath -ll

# NTP synchronization
chronyc tracking
```

## Common Issues and Resolutions

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| Pool management unavailable | Pool master down | `xe pool-emergency-transition-to-master` on a slave, then `xe pool-recover-slaves` |
| VM fails to start | Insufficient memory or full SR | Check `free -m` in dom0; check SR utilisation with `xe sr-list` |
| Live migration fails | No shared SR, CPU mismatch, or local ISO | Verify SR access on both hosts; apply CPU masking; detach local ISOs |
| HA false fencing | Heartbeat disk I/O timeout or NTP skew | Check NFS/iSCSI connectivity; verify NTP with `chronyc tracking` |
| VHD coalesce stuck | SM worker issue or lock contention | `xe sr-scan uuid=<sr-uuid>`; restart xapi if needed: `xe-toolstack-restart` |
| Slow VM disk I/O | Deep VHD chain or dom0 memory pressure | Flatten chain via `xe vdi-copy`; increase dom0 RAM |
| Management errors after time drift | NTP skew between hosts | Fix NTP on all hosts; restart xapi if certificates were affected |
| VM paused unexpectedly | Thin SR out of space | Free space on backing store; extend NFS export; `xe sr-scan` |
| Bond failover not working | LACP misconfiguration | Verify switch-side LACP config; check `ovs-vsctl show` |
| Snapshot not freeing space | Coalesce not completed | Check `xe task-list`; wait for coalesce or run `xe sr-scan` |

## XAPI Restart and Recovery

```bash
# Restart XAPI toolstack (running VMs are unaffected)
xe-toolstack-restart

# Emergency pool master transition
xe pool-emergency-transition-to-master
xe pool-recover-slaves

# Reset networking after misconfiguration
xe-reset-networking

# Restore pool database from backup
xe pool-restore-database file-name=pool-db-backup.xml
```

## Status Report Collection

```bash
# Generate a server status report (comprehensive diagnostic bundle)
xen-bugtool --yestoall

# Output saved to /var/opt/xen/bug-report/ as a tar.bz2 archive
# Upload to Citrix Support for analysis
```
