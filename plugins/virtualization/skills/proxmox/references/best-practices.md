# Proxmox VE Best Practices Reference

Operational best practices for Proxmox VE environments. Covers storage selection, Ceph design, network architecture, HA fencing, resource management, and security hardening.

---

## Storage Selection

### ZFS vs LVM-thin

**Choose ZFS when:**
- Single-node or non-Ceph multi-node setups
- Data integrity is paramount (checksumming detects silent corruption)
- Instant snapshots and efficient send/receive replication are needed
- ECC RAM is available (strongly recommended but not strictly required)
- Compression is desired (lz4 default, zstd for higher ratio)

**Choose LVM-thin when:**
- ZFS memory overhead is a concern (ZFS ARC uses significant RAM)
- Spinning disks are the primary storage (LVM-thin is less memory-hungry)
- Simple thin provisioning is sufficient without checksumming
- Budget or hardware constraints prevent ZFS

**ZFS tuning:**
- Set `zfs_arc_max` to leave 1-2 GB per GB of VM RAM needed. Example: 64 GB host, 48 GB for VMs = set ARC max to ~12 GB
- Use mirror vdevs for small pools (best IOPS/resilience). RAID-Z2 for capacity pools (6+ drives)
- Never use RAID-Z1 for production (single-parity = high rebuild risk on large drives)
- Enable compression: `zfs set compression=lz4 rpool` (nearly free performance gain)
- Do NOT use dedup unless you have 5+ GB RAM per TB of data

### Ceph for HA Storage

**When to use Ceph:**
- Multi-node clusters requiring live VM migration
- HA environments where VM disks must be accessible from any node
- Scale-out storage that grows by adding nodes/disks

**Ceph design guidelines:**
- Minimum 3 nodes with 3 OSDs per node for replication factor 3
- Separate Ceph public (client) and cluster (replication) networks on dedicated NICs
- Use NVMe for OSD WAL/DB when using HDD capacity drives
- Set `min_size=2` on pools (2 replicas must be available to accept writes)
- Use NVMe-only OSDs for high-IOPS workloads (database, random I/O)
- Size OSD devices uniformly within a pool; mixed sizes cause uneven distribution
- Monitor with `ceph status`, `ceph osd df`, `ceph health detail`

**Ceph networking:**
- Public network: client (VM) access to Ceph. On same VLAN as VM storage network
- Cluster network: OSD-to-OSD replication. Dedicated VLAN, ideally 25 GbE
- Never share Ceph cluster network with Corosync or management traffic

---

## Network Design

### Traffic Separation

Separate traffic onto dedicated NICs or VLANs:

| Network | Purpose | Bandwidth | Notes |
|---|---|---|---|
| Management | Web UI, SSH, Corosync | 1-10 GbE | Redundant (bond) |
| Ceph Public | Client-to-OSD traffic | 10-25 GbE | Dedicated VLAN |
| Ceph Cluster | OSD replication | 10-25 GbE | Dedicated VLAN |
| VM/Tenant | Guest traffic | 10+ GbE | VLAN-tagged |
| Migration | Live VM migration | 10+ GbE | High bandwidth |

### Bonding Recommendations

- **Management:** active-backup (mode 1) for redundancy
- **Ceph/Storage:** 802.3ad LACP (mode 4) for bandwidth aggregation (requires switch support)
- **VM traffic:** LACP or active-backup depending on switch capabilities

### MTU / Jumbo Frames

Enable jumbo frames (MTU 9000) on Ceph, NFS, and migration networks:
- Configure on physical switch ports, bonds, bridges, and VMkernel adapters
- Verify end-to-end: `ping -M do -s 8972 <destination>` (8972 + 28 header = 9000)
- Do NOT enable jumbo frames on management network (complicates troubleshooting)

---

## HA Fencing

### Always Configure Fencing Before Enabling HA

Without working fencing, HA cannot safely restart VMs. If a node is unresponsive, its state is unknown -- it might still be running VMs.

### Fencing Priority

1. **IPMI/iDRAC/iLO (best):** Out-of-band power management. Works even when OS is hung. Most reliable.
2. **Hardware watchdog:** Timer that triggers hard reboot if not reset by the HA manager. Good fallback.
3. **Softdog (acceptable):** Software watchdog. Less reliable than hardware but better than nothing.

### Testing Fencing

- Simulate node failure by blocking Corosync traffic (not by pulling power in production)
- Verify HA fences the node and restarts resources on another node
- Test power-off via IPMI: `ipmitool -H <bmc-ip> -U admin -P pass power off`
- Monitor HA state: `ha-manager status`

---

## Resource Management

### CPU Overcommit

CPU overcommit is normal and expected. Proxmox schedules vCPUs on physical cores with time-slicing.

**Guidelines:**
- 4:1 to 8:1 vCPU-to-pCPU ratio is typical for mixed workloads
- Use `cpu_units` to set relative priority (default 1024; higher = more CPU time)
- Use `cpulimit` to cap a VM's CPU usage (e.g., `cpulimit=2` = max 2 cores equivalent)
- Monitor CPU steal time inside guests to detect contention

### Memory Management

- **VMs:** Do NOT overcommit memory without ballooning. Set minimum and maximum memory, enable balloon device.
- **LXC containers:** Safer to overcommit because there is no balloon overhead. Kernel shares memory efficiently.
- **KSM (Kernel Same-page Merging):** Enabled by default. Merges identical memory pages across VMs. Adds CPU overhead but saves RAM.
- Monitor with: `cat /proc/meminfo | grep -i ksm`

### Disk Thin Provisioning

LVM-thin, qcow2, and Ceph all support thin provisioning (allocate on write). Actual usage grows over time.

- Set monitoring alerts at 80% pool utilization
- Monitor with web UI Storage panel or `lvs` / `ceph df`
- Guest TRIM/discard support reclaims space: enable `discard=on` in VM disk settings

---

## Security Hardening

### Authentication

- Change default `root` password immediately
- Create named admin users (never share the root account)
- Enable 2FA (TOTP) for web UI: Datacenter > Permissions > Two Factor
- Use LDAP/AD integration for centralized authentication
- Create API tokens for automation (limited permissions, no password sharing)

### Access Control

- Restrict web UI access with Datacenter-level firewall rules
- Use Proxmox roles and permissions for least-privilege access
- Separate admin users from VM operators
- Audit permissions quarterly

### Updates

- Apply Proxmox updates regularly: `apt update && apt dist-upgrade`
- Subscribe to Proxmox security advisories
- Test updates on a non-production node first in multi-node clusters
- For enterprise: use Proxmox Enterprise Repository (requires subscription)
- For community: use No-Subscription Repository (suitable for non-critical environments)

### Container Security

- Use unprivileged containers exclusively
- Enable AppArmor profiles (enabled by default)
- Limit container capabilities to minimum required
- Do not enable `nesting` unless Docker/Podman inside LXC is required
- Restrict bind mounts to read-only where possible

---

## Backup Best Practices

### Schedule

- **Daily:** snapshot-mode backup of all production VMs/containers
- **Weekly:** full backup or verification of incremental chain
- **Monthly:** test restore of at least one VM to verify backup integrity

### PBS Recommendations

- Dedicate a separate host or VM for PBS (do not co-locate with production PVE)
- Use ZFS on PBS for deduplication efficiency
- Enable client-side encryption for offsite replication
- Set retention policies: keep 7 daily, 4 weekly, 6 monthly
- Schedule verification jobs to detect bit-rot

### Restore Testing

- Test full VM restore monthly
- Test container restore monthly
- Document recovery procedures for each workload tier
- Verify backup network bandwidth is sufficient for RTO requirements
