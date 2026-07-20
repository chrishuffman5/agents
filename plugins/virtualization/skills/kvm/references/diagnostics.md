# KVM/QEMU Diagnostics Reference

Troubleshooting and diagnostic reference for KVM/QEMU with libvirt. Covers virt-top monitoring, domain statistics, KVM debugfs, QEMU logs, and common issue resolution.

---

## Real-Time Monitoring

### virt-top

`virt-top` provides a top-like view of all VMs with vCPU%, memory, and I/O metrics:

```bash
virt-top                                # interactive mode
virt-top --csv output.csv -n 10         # CSV export, 10 iterations
```

### Domain Statistics

```bash
# All counters for a VM
virsh domstats myvm

# Block device I/O
virsh domblkstat myvm vda               # rd_req, rd_bytes, wr_req, wr_bytes

# Network interface I/O
virsh domifstat myvm vnet0              # rx/tx bytes, packets, errors, drops

# vCPU info
virsh vcpuinfo myvm                     # per-vCPU state, CPU time, affinity

# Memory stats
virsh dommemstat myvm                   # actual_balloon, swap_in, minor_fault

# Job info (during migration)
virsh domjobinfo myvm
```

### Resource Usage

```bash
# VM block device list
virsh domblklist myvm                   # attached block devices

# VM network interface list
virsh domiflist myvm                    # NICs and MACs

# VM info summary
virsh dominfo myvm                      # ID, UUID, state, memory, vCPUs
```

---

## KVM-Level Diagnostics

### Verify KVM Modules

```bash
# Confirm modules loaded
lsmod | grep kvm

# Confirm hardware virtualization
cat /sys/module/kvm_intel/parameters/ept   # 1 = EPT active
cat /sys/module/kvm_amd/parameters/npt     # 1 = NPT active

# Nested virtualization
cat /sys/module/kvm_intel/parameters/nested  # Y = enabled
```

### KVM debugfs Statistics

```bash
# Mount debugfs if not already mounted
mount -t debugfs none /sys/kernel/debug

# Global KVM stats
cat /sys/kernel/debug/kvm/stat

# VM exit analysis with perf
perf kvm stat live -p $(pgrep -f 'qemu.*myvm')
```

Key KVM exit reasons:
- `exits`: total VM exits
- `halt_exits`: guest executing HLT (idle)
- `io_exits`: I/O port access
- `mmio_exits`: memory-mapped I/O
- `irq_exits`: interrupt injection

High `io_exits` or `mmio_exits` indicate the VM is using emulated (non-VirtIO) devices.

### Hugepage Verification

```bash
cat /proc/meminfo | grep -i huge
# HugePages_Total, HugePages_Free, HugePages_Rsvd, HugePages_Surp
```

---

## QEMU Logs

### Per-VM QEMU Log

Each VM has a QEMU stderr log:
```
/var/log/libvirt/qemu/<vmname>.log
```

Contains QEMU startup arguments, device initialization, error messages, and crash output.

### libvirt Daemon Log

```bash
# Monolithic daemon
journalctl -u libvirtd -f

# Modular daemon
journalctl -u virtqemud -f

# Storage daemon
journalctl -u virtstoraged -f

# Network daemon
journalctl -u virtnetworkd -f
```

---

## Common Issue Troubleshooting

### VM Won't Start

| Symptom | Check | Resolution |
|---|---|---|
| "Cannot access storage" | `virsh vol-info`, disk path | Fix path, check permissions |
| "Permission denied" | SELinux/AppArmor | `restorecon` or check AppArmor profile |
| "Failed to connect to monitor" | QEMU crash | Check `/var/log/libvirt/qemu/<vm>.log` |
| "Network not found" | `virsh net-list --all` | Start network: `virsh net-start default` |
| "CPU incompatible" | CPU flags/model | Change CPU mode in XML |
| "UEFI firmware missing" | OVMF not installed | Install `ovmf` or `edk2-ovmf` package |

### Migration Failures

| Error | Cause | Fix |
|---|---|---|
| "Unsupported CPU" | CPU feature mismatch | Use `host-model` CPU mode |
| "Cannot access storage" | Disk not on shared storage | Use `--copy-storage-all` |
| "Connection refused" | libvirtd not listening | Check daemon on destination |
| "Timed out" | Network too slow | Increase bandwidth, use post-copy |
| "Domain already exists" | Same name on destination | Use `--undefinesource` or rename |

### Storage Issues

```bash
# Check disk image integrity
qemu-img check myvm.qcow2

# Check for snapshot chains
qemu-img info --backing-chain myvm.qcow2

# Check storage pool health
virsh pool-info mypool
virsh pool-refresh mypool               # rescan for new volumes

# Check LVM thin pool usage
lvs -a | grep thin
```

### Network Issues

```bash
# Verify default network
virsh net-list --all
virsh net-start default                 # start if not running

# Check bridge status
ip link show virbr0
bridge fdb show dev virbr0

# DHCP leases
virsh net-dhcp-leases default

# Check dnsmasq (NAT network)
ps aux | grep dnsmasq
journalctl -u libvirtd | grep dnsmasq
```

### Performance Issues

| Symptom | Diagnostic | Resolution |
|---|---|---|
| High CPU usage | `virt-top`, `virsh vcpuinfo` | Check overcommit, pin CPUs |
| Slow disk I/O | `virsh domblkstat`, guest `iostat` | Use VirtIO, cache=none, I/O threads |
| Slow network | `virsh domifstat`, guest `iperf3` | Use VirtIO, enable vhost-net |
| Memory pressure | `virsh dommemstat`, host `free` | Add RAM, enable hugepages |
| NUMA penalty | `numastat -c qemu-system` | Pin to single NUMA node |

---

## Useful Diagnostic Commands

```bash
# List all VMs with detailed state
virsh list --all --title

# Check which QEMU process is which VM
ps aux | grep qemu-system | grep -v grep

# Get VM PID for further analysis
virsh dominfo myvm | grep "^Id"

# Check QEMU command line for a running VM
cat /proc/$(virsh dominfo myvm | awk '/^Id/ {print $2}')/cmdline | tr '\0' '\n'

# Storage performance (inside guest)
fio --name=test --filename=/dev/vda --rw=randread --bs=4k \
  --iodepth=32 --runtime=30 --numjobs=4 --output-format=json

# Network performance (between host and guest)
iperf3 -s        # on one end
iperf3 -c <ip>   # on other end
```
