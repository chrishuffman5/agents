# Proxmox VE Architecture Reference

Comprehensive architecture reference for Proxmox VE. Covers KVM+LXC virtualization, storage backends, networking, clustering, and backup.

---

## Platform Architecture

### Debian Linux Base

Proxmox VE is built on Debian Linux (PVE 8.x on Debian 12 "Bookworm", PVE 9.x on Debian 13 "Trixie"). The Proxmox team ships a custom kernel with patches for KVM, ZFS, and hardware support. The platform is managed through a web UI on HTTPS port 8006 and a full CLI via SSH.

### KVM Hypervisor

Proxmox uses QEMU/KVM for full virtualization. KVM is a Linux kernel module that turns the kernel into a Type-1 hypervisor. QEMU provides device emulation (storage, NIC, USB, display). Together they deliver near-native CPU performance.

**Hardware requirements:**
- Intel VT-x (`vmx` flag) with EPT, or AMD-V (`svm` flag) with NPT
- Verify: `grep -E 'vmx|svm' /proc/cpuinfo`

### LXC System Containers

LXC containers provide OS-level virtualization. They share the host kernel but have isolated namespaces (PID, network, mount, user). Containers start in seconds, have no hardware emulation overhead, and are ideal for Linux-only workloads.

**Key distinction:** LXC system containers run a full Linux init system (systemd), not a single application process. They are NOT Docker/Podman-style application containers.

### Component Architecture

```
Proxmox VE Node
  ├── Custom Linux Kernel (KVM module, ZFS, patches)
  ├── QEMU/KVM (VM execution)
  ├── LXC (container execution)
  ├── pvedaemon (Proxmox API daemon)
  ├── pveproxy (web UI proxy, port 8006)
  ├── Corosync (cluster communication)
  ├── pmxcfs (cluster filesystem, /etc/pve/)
  ├── HA Manager (resource failover)
  └── Storage Layer (ZFS, LVM, Ceph, NFS, etc.)
```

---

## VM Architecture

### Configuration Files

VM configs live at `/etc/pve/qemu-server/<vmid>.conf`. The VMID is a numeric identifier (100-999999999). On a cluster, `/etc/pve/` is a shared filesystem (pmxcfs) backed by Corosync.

### Disk Formats

| Format | Snapshots | Thin | Performance | Use Case |
|---|---|---|---|---|
| `qcow2` | Yes (internal) | Yes | Good | Default for directory/ZFS |
| `raw` | No (external) | No | Best | High performance, no snapshots |
| `vmdk` | N/A | N/A | N/A | VMware import/export only |
| LVM/LVM-thin | LVM-thin only | LVM-thin only | Very good | Block storage |
| RBD (Ceph) | Yes | Yes | Very good | Distributed HA |

### VirtIO Devices

Always use VirtIO for best performance:

| Device | Function | Notes |
|---|---|---|
| `virtio-scsi` | Disk controller | Recommended; supports hot-plug, TRIM |
| `virtio-blk` | Disk controller | Simpler; one queue per disk |
| `virtio` (net) | Network adapter | Highest throughput, lowest CPU |
| `virtio-balloon` | Memory ballooning | Dynamic memory reclaim |
| `virtio-rng` | Entropy device | From host `/dev/urandom` |
| `virtio-serial` | Serial channel | QEMU Guest Agent communication |

Windows VMs require the VirtIO Windows drivers ISO installed during setup.

### OVMF (UEFI) Boot

UEFI boot via OVMF (EDK2). Set BIOS to `ovmf` in VM Options. Requires EFI disk added to VM. Needed for Windows 11, Secure Boot, and modern OS installations.

### Cloud-Init

Cloud-Init enables unattended VM provisioning. Proxmox adds a Cloud-Init drive (cdrom) with `user-data`, `meta-data`, and `network-config`. Configure via VM Cloud-Init tab: username, SSH keys, IP configuration, DNS.

### Templates and Clones

- **Template:** `qm template <vmid>`. Templates cannot be started. Base images for cloning.
- **Full Clone:** Copies all disk data. Independent of template. Use for production.
- **Linked Clone:** Delta disk referencing template base (requires snapshot-capable storage). Fast creation, saves space, but depends on template.

---

## Container Architecture

### Unprivileged vs Privileged

**Unprivileged (default, recommended):** UID/GID mapping -- container UID 0 maps to host UID 100000+. Container root has no host privileges.

**Privileged (not recommended):** Container UID maps directly to host UID. Container root = host root for device access. Use only if an application requires direct hardware access.

### Container Templates

Stored in storage pools. Download via web UI or CLI:
```bash
pveam update
pveam available --section system
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

Sources: Debian, Ubuntu, Fedora, Alpine, CentOS, TurnkeyLinux appliances.

### Container Features

Enable special capabilities per container:
- `nesting=1` -- Docker/Podman inside LXC
- `keyctl=1` -- Keyctl syscall (needed for some apps)
- `fuse=1` -- FUSE filesystem support

### Bind Mounts

Share host directories into containers:
```bash
pct set <ctid> -mp0 /host/data,mp=/container/mountpoint
```

---

## Storage Architecture

### Local Storage

**Directory:** Files (qcow2, raw, ISO) in a path. Simplest option. Snapshots via qcow2.

**LVM:** Logical Volumes on local disk. Raw block performance. No built-in thin provisioning or snapshots (LVM2 snapshots are unreliable for VMs).

**LVM-thin:** Thin-provisioned LVM pool. Snapshots supported. Good balance of performance and features. Faster provisioning than ZFS on spinning disk.

**ZFS:** First-class support. Pooled storage with copy-on-write, instant snapshots, checksumming, compression (lz4/zstd), and send/receive replication. Proxmox can boot from ZFS. Managed via web UI or `zpool`/`zfs` CLI.

### Shared Storage

**Ceph RBD:** Distributed block storage. Required for live VM migration in HA clusters. Self-healing with replication. Ceph is installable directly from the Proxmox web UI.

**CephFS:** POSIX filesystem on Ceph. Use for templates, ISOs, backups -- not for VM disks (use RBD for VMs).

**NFS:** Simple shared storage. Good for templates, ISOs, and backups. Usable for VM disks with adequate network bandwidth.

**iSCSI:** Block storage over IP. SAN integration.

**GlusterFS:** Distributed filesystem. Alternative to Ceph for smaller setups.

### Storage Selection Guide

| Scenario | Recommended Storage |
|---|---|
| Single node, general use | ZFS (mirror or RAID-Z2) |
| Single node, high performance | ZFS zvols or LVM-thin on NVMe |
| HA cluster | Ceph RBD for VMs, CephFS for files |
| Backup target | PBS with ZFS dedup, or NFS |
| Templates and ISOs | Local directory, CephFS, or NFS |
| Development | Directory with qcow2 |

---

## Networking Architecture

### Linux Bridges

Default model. Physical NICs enslaved to bridges (`vmbr0`, `vmbr1`). VMs and containers attach virtual interfaces to bridges. Configuration in `/etc/network/interfaces`.

### VLAN-Aware Bridges

Enable "VLAN aware" on a bridge to use 802.1Q VLAN tagging. VMs specify VLAN tag on their NIC. Multiple VLANs share one bridge.

### Open vSwitch

Install `openvswitch-switch` for OVS. Provides flow tables, VLAN trunking, tunneling (VXLAN, GRE). OVS bridges created alongside Linux bridges.

### Bonding

Bond physical NICs for redundancy or throughput:
- `active-backup` (mode 1): failover only
- `802.3ad LACP` (mode 4): aggregation, requires switch support
- `balance-alb` (mode 6): adaptive, no switch config needed

### SDN (Software Defined Networking)

Available in PVE 8.x+ (stable from 8.1). Cluster-wide virtual networking:

| Zone Type | Description |
|---|---|
| Simple | Basic bridge-based L2 |
| VLAN | 802.1Q VLAN zones |
| QinQ | Stacked VLANs |
| VXLAN | Overlay tunneling |
| EVPN | BGP-based overlay with routing |

### Built-in Firewall

Three levels: Datacenter (cluster-wide), Node (per-hypervisor), VM/CT (per-guest). Rules stored in `/etc/pve/firewall/`. Security Groups apply rule sets across multiple VMs.

PVE 8.x: iptables/nftables hybrid. PVE 9.x: full nftables backend.

---

## Clustering Architecture

### Corosync

Corosync handles cluster communication via heartbeat messages. Dedicated cluster network recommended (<1 ms RTT). Configuration at `/etc/corosync/corosync.conf`. Supports redundant rings (ring0 + ring1).

### pmxcfs (Proxmox Cluster Filesystem)

`/etc/pve/` is a cluster-wide filesystem backed by SQLite and Corosync. All node configurations, VM configs, and storage definitions are synchronized cluster-wide. Changes on any node are immediately visible on all nodes.

### Quorum

Each node has 1 vote. Quorum = majority of total votes. Without quorum, a node stops VMs/containers to prevent split-brain.

| Nodes | Quorum | Fault Tolerance |
|---|---|---|
| 2 | 2 (needs QDevice) | 0 without QDevice |
| 3 | 2 | 1 node failure |
| 4 | 3 | 1 node failure |
| 5 | 3 | 2 node failures |

### HA Manager

Monitors HA-managed resources. If a node fails, HA fences the node and restarts resources on a surviving node.

**HA resource states:** `started`, `stopped`, `disabled`, `error`, `migrate`, `relocate`, `fence`

**Fencing sequence:**
1. Node detected as failed (missed Corosync heartbeats)
2. HA Manager attempts to fence the node (IPMI power off, watchdog)
3. After successful fence, resources are started on surviving node
4. If fencing fails, resources remain in `fence` state -- manual intervention required

---

## Backup Architecture

### vzdump

Creates `.vma` (VM) or `.tar.zst` (LXC) archives. Three modes:

| Mode | Downtime | Consistency | How It Works |
|---|---|---|---|
| snapshot | Minimal | Good (with guest agent) | LVM/ZFS/Ceph snapshot during backup |
| suspend | Seconds-minutes | Good | Suspends VM, backs up, resumes |
| stop | Full downtime | Best | Stops VM, backs up, starts |

### Proxmox Backup Server (PBS)

Separate product for enterprise backup:
- **Incremental:** Only changed data chunks transmitted
- **Deduplication:** Chunk-level across all backups
- **Encryption:** Client-side AES-256-GCM
- **Verification:** Automated integrity checks
- **Retention:** Keep N daily/weekly/monthly backups

### Backup Scheduling

Configure in Datacenter > Backup:
- Storage target (PBS, NFS, local)
- Schedule (cron syntax)
- Retention policy
- Compression (zstd recommended)
- Notification on success/failure
