# KVM/QEMU Best Practices Reference

Performance tuning and operational best practices for KVM/QEMU with libvirt. Covers VirtIO configuration, hugepages, CPU pinning, NUMA tuning, cache modes, I/O optimization, and security.

---

## VirtIO Configuration

### Always Use VirtIO

VirtIO paravirtualized devices provide 5-10x better performance than emulated devices with lower CPU overhead.

**Disk:** Use `virtio-scsi` (recommended for hot-plug, TRIM, multiple disks) or `virtio-blk` (simpler, slightly higher throughput for single disk).

**Network:** Use `virtio` model. Emulated e1000/rtl8139 should only be used during Windows initial install before loading virtio drivers.

**Windows guests:** Attach the virtio-win ISO during installation. Load `vioscsi` driver to see the virtio disk. After install, run `virtio-win-guest-tools.exe` for all drivers + QEMU guest agent.

### QEMU Guest Agent

Install `qemu-guest-agent` in every VM for:
- Graceful shutdown from host
- Filesystem freeze before snapshots (consistent backups)
- IP address reporting to host
- File read/write from host

Enable in VM XML:
```xml
<channel type='unix'>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
```

---

## CPU Tuning

### CPU Mode

| Mode | Migration | Performance | Use Case |
|---|---|---|---|
| `host-passthrough` | Same CPU only | Best | Single host or identical CPUs |
| `host-model` | Similar CPUs | Very good | Clusters with similar CPUs |
| Custom model | Any compatible | Good | Mixed CPU environments |

```xml
<cpu mode='host-passthrough' check='none' migratable='on'/>
```

Use `host-passthrough` for maximum performance on single hosts. Use `host-model` when live migration across slightly different CPU generations is needed.

### CPU Pinning

Pin vCPUs to specific physical CPUs for predictable performance and NUMA locality:

```xml
<cputune>
  <vcpupin vcpu='0' cpuset='2'/>
  <vcpupin vcpu='1' cpuset='3'/>
  <vcpupin vcpu='2' cpuset='4'/>
  <vcpupin vcpu='3' cpuset='5'/>
  <emulatorpin cpuset='0-1'/>      <!-- pin QEMU emulator threads -->
</cputune>
```

**Guidelines:**
- Pin vCPUs to the same NUMA node as the VM's memory
- Reserve 1-2 cores for QEMU emulator threads (separate from vCPU pins)
- Do not pin multiple VMs to the same cores unless overcommit is intentional
- Check NUMA topology: `lscpu | grep NUMA` or `virsh capabilities`

### NUMA Awareness

VMs that span NUMA nodes suffer 30-40% memory latency penalty for remote memory access.

```xml
<numatune>
  <memory mode='strict' nodeset='0'/>
</numatune>
```

**Guidelines:**
- Size VMs to fit within a single NUMA node (vCPUs <= cores per node)
- Bind VM memory to the same NUMA node as its pinned CPUs
- For large VMs spanning nodes: use `interleave` mode to spread evenly
- Inspect: `virsh capabilities | grep -A20 topology`

---

## Memory Tuning

### Hugepages

Hugepages reduce TLB (Translation Lookaside Buffer) misses, improving memory performance for large VMs.

**1 GB hugepages (recommended for VMs with 8+ GB RAM):**
```bash
# Allocate on host (persistent via kernel cmdline)
echo 8 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
# Or add to GRUB: hugepagesz=1G hugepages=8 default_hugepagesz=1G
```

**In VM XML:**
```xml
<memoryBacking>
  <hugepages>
    <page size='1' unit='G'/>
  </hugepages>
</memoryBacking>
```

**2 MB hugepages (for smaller VMs):**
```bash
echo 4096 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
```

### Memory Ballooning

Allow host to reclaim unused guest memory dynamically:
```xml
<memballoon model='virtio'>
  <stats period='10'/>
</memballoon>
```

Requires `virtio-balloon` driver in guest. Useful for overcommit but adds latency when host reclaims pages.

### KSM (Kernel Same-page Merging)

KSM scans memory for identical pages and merges them (copy-on-write). Saves memory when running many similar VMs.

```bash
# Check KSM status
cat /sys/kernel/mm/ksm/run           # 1 = enabled
cat /sys/kernel/mm/ksm/pages_shared  # pages currently shared
```

Trade-off: KSM uses CPU to scan pages. Disable for latency-sensitive workloads.

---

## Disk I/O Tuning

### Cache Modes

| Cache Mode | Host Writeback | O_DIRECT | Data Safety | Performance |
|---|---|---|---|---|
| `none` | No | Yes | Best (with UPS) | Good |
| `writeback` | Yes | No | Risk on power loss | Best |
| `writethrough` | No | No | Safe | Slowest |
| `directsync` | No | Yes | Safest | Moderate |
| `unsafe` | Yes | No | None | Testing only |

**Recommended:** `cache='none' io='native'` for virtio-blk; `cache='none' io='threads'` for virtio-scsi.

### I/O Threads

Dedicate I/O threads per disk to avoid QEMU main loop bottleneck:

```xml
<iothreads>2</iothreads>
<disk ...>
  <driver name='qemu' type='qcow2' cache='none' io='native' iothread='1'/>
</disk>
```

Assign one I/O thread per high-throughput disk. Share I/O threads among low-activity disks.

### Disk Format Selection

- **qcow2:** Default. Supports snapshots, thin provisioning, and backing files. Good performance.
- **raw:** Maximum performance. No snapshot support (external only). Use with LVM for best results.
- **Recommendation:** qcow2 for flexibility; raw for latency-sensitive workloads (databases).

### Preallocation

For qcow2, preallocate metadata and data to avoid allocation overhead during writes:
```bash
qemu-img create -f qcow2 -o preallocation=metadata myvm.qcow2 50G
# or for full preallocation:
qemu-img create -f qcow2 -o preallocation=full myvm.qcow2 50G
```

---

## Network Tuning

### Multi-Queue VirtIO-Net

Enable multiple queues for high-throughput networking:

```xml
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>
  <driver name='vhost' queues='4'/>
</interface>
```

Inside guest: `ethtool -L eth0 combined 4`

### vhost-net

vhost-net moves virtio-net processing from QEMU userspace to kernel space:
```xml
<driver name='vhost'/>
```

Enabled by default on modern libvirt. Verify: `lsmod | grep vhost_net`

### Bridge Netfilter

Linux netfilter processes bridge traffic by default, causing unexpected drops:
```bash
# Disable for VM bridges
echo 0 > /proc/sys/net/bridge/bridge-nf-call-iptables
echo 0 > /proc/sys/net/bridge/bridge-nf-call-ip6tables

# Persist via sysctl
echo "net.bridge.bridge-nf-call-iptables = 0" >> /etc/sysctl.d/99-bridge.conf
sysctl --system
```

---

## Security Best Practices

### VFIO Device Passthrough

For GPU, NIC, or NVMe passthrough:
1. Enable IOMMU: add `intel_iommu=on` or `amd_iommu=on` to kernel cmdline
2. Bind device to vfio-pci driver
3. Verify IOMMU groups: `ls /sys/kernel/iommu_groups/*/devices/`
4. Add hostdev XML to VM definition

### SELinux / AppArmor

- **RHEL/Fedora:** SELinux with svirt labels isolates VM processes. Do not disable.
- **Ubuntu/Debian:** AppArmor profiles for libvirt. Keep enabled.

### libvirt Access Control

- Use `polkit` rules to control which users can manage VMs
- Create separate system users for VM management (not root)
- Use `qemu:///session` for unprivileged VMs where possible

### Network Isolation

- Use isolated networks for inter-VM communication that should not reach the LAN
- Apply nftables rules on the host to filter VM bridge traffic
- Use SR-IOV with MAC/VLAN filtering for hardware-enforced isolation

---

## Backup Best Practices

### Snapshot-Based Backup

```bash
# Create disk-only snapshot (creates overlay)
virsh snapshot-create-as myvm backup-snap --disk-only --atomic --quiesce

# Copy the base image (now read-only)
cp /var/lib/libvirt/images/myvm.qcow2 /backup/myvm-$(date +%Y%m%d).qcow2

# Merge snapshot back (blockcommit)
virsh blockcommit myvm vda --active --pivot --delete

# Delete snapshot metadata
virsh snapshot-delete myvm backup-snap --metadata
```

### Guest Agent Quiescing

Add `--quiesce` to snapshot commands. Requires `qemu-guest-agent` in guest. Flushes filesystem buffers before snapshot for consistency.

### Regular Practices

- Test backup restores monthly
- Keep at least 3 generations of backups
- Store backups on separate storage from VM disks
- Document recovery procedures for each VM
