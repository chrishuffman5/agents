# KVM/QEMU Architecture Reference

Comprehensive architecture reference for KVM/QEMU with libvirt. Covers KVM kernel hypervisor, QEMU device emulation, libvirt management, storage, and networking.

---

## KVM Kernel Hypervisor

### Module Architecture

KVM ships as loadable kernel modules:

| Module | Purpose |
|---|---|
| `kvm` | Core hypervisor logic, /dev/kvm device node |
| `kvm_intel` | Intel VT-x extensions (VMCS, EPT) |
| `kvm_amd` | AMD-V extensions (VMCB, NPT) |

**Hardware requirements:**
- Intel: VT-x (`vmx` flag in `/proc/cpuinfo`) + EPT for nested page tables
- AMD: AMD-V (`svm` flag) + NPT (Nested Page Tables)
- Check: `grep -E 'vmx|svm' /proc/cpuinfo` or `kvm-ok` (cpu-checker package)

### /dev/kvm Interface

`/dev/kvm` is a character device. Userspace programs (QEMU) open it and issue `ioctl()` calls to:
- Create VMs (KVM_CREATE_VM)
- Create vCPUs (KVM_CREATE_VCPU)
- Map guest memory (KVM_SET_USER_MEMORY_REGION)
- Run vCPUs (KVM_RUN)

vCPUs execute directly on physical CPUs. Only VM exits (privileged instructions, I/O, interrupts) trap to KVM/QEMU for handling.

### Extended Page Tables (EPT / NPT)

Two-level address translation done entirely in hardware:
1. Guest virtual -> Guest physical (managed by guest OS)
2. Guest physical -> Host physical (managed by KVM)

Benefits:
- Eliminates software shadow page tables (major performance gain)
- Enables memory overcommit via KSM and ballooning
- Reduces VM exit frequency dramatically

### Nested Virtualization

KVM supports nested virtualization (running a hypervisor inside a VM):
```bash
# Enable nested virtualization
echo "options kvm_intel nested=1" > /etc/modprobe.d/kvm-nested.conf
modprobe -r kvm_intel && modprobe kvm_intel

# Verify
cat /sys/module/kvm_intel/parameters/nested   # Y = enabled
```

Use `cpu mode='host-passthrough'` in the L1 VM XML to expose VMX/SVM to the guest.

---

## QEMU Device Emulation

QEMU runs as a userspace process per VM. KVM handles CPU/memory; QEMU handles everything else (devices, I/O, display).

### Machine Types

| Machine | Architecture | Use Case |
|---|---|---|
| `q35` | Modern PCIe (ICH9) | Default for new VMs; required for NVMe, IOMMU, Secure Boot |
| `i440fx` | Legacy ISA+PCI | Maximum compatibility for older guest OS |
| `virt` | ARM/aarch64 | ARM guests |

Always use `q35` for new VMs unless legacy compatibility is required.

### VirtIO Paravirtualized Devices

VirtIO devices bypass full hardware emulation, providing near-native performance:

| Device | XML Config | Purpose |
|---|---|---|
| `virtio-net` | `<model type='virtio'/>` | Network -- highest throughput, lowest CPU |
| `virtio-blk` | `<target bus='virtio'/>` | Block storage -- simple, one queue per disk |
| `virtio-scsi` | `<controller model='virtio-scsi'/>` | SCSI -- multiple disks, hot-plug, TRIM |
| `virtio-gpu` | `<model type='virtio'/>` | Display -- 2D acceleration |
| `virtio-balloon` | `<memballoon model='virtio'/>` | Dynamic memory reclaim |
| `virtio-rng` | `<rng model='virtio'>` | Guest entropy from host |
| `virtio-serial` | `<channel type='unix'>` | Guest agent communication |

### OVMF / UEFI Firmware

OVMF provides UEFI firmware for VMs. Required for Secure Boot, TPM 2.0, NVMe, and Windows 11.

Packages:
- Debian/Ubuntu: `ovmf`
- RHEL/Fedora: `edk2-ovmf`

Firmware files:
- Read-only code: `/usr/share/OVMF/OVMF_CODE.fd`
- Per-VM variables: `/var/lib/libvirt/qemu/nvram/<vm>_VARS.fd`

In libvirt XML:
```xml
<os>
  <type arch='x86_64' machine='q35'>hvm</type>
  <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>
  <nvram>/var/lib/libvirt/qemu/nvram/myvm_VARS.fd</nvram>
</os>
```

### QEMU Monitor

Two interfaces for live VM inspection:

**HMP (Human Monitor Protocol):**
```bash
virsh qemu-monitor-command myvm --hmp 'info status'
virsh qemu-monitor-command myvm --hmp 'info block'
virsh qemu-monitor-command myvm --hmp 'info network'
```

**QMP (JSON Machine Protocol):**
```bash
virsh qemu-monitor-command myvm '{"execute":"query-status"}'
```

---

## libvirt Management Layer

### Daemon Architecture

| Daemon | Model | Notes |
|---|---|---|
| `libvirtd` | Monolithic | All-in-one; default on Ubuntu/Debian |
| `virtqemud` | Modular | Dedicated QEMU driver; default on RHEL 9+ |
| `virtstoraged` | Modular | Storage pool management |
| `virtnetworkd` | Modular | Virtual network management |

```bash
# Monolithic
systemctl enable --now libvirtd

# Modular (RHEL 9+, Fedora 36+)
systemctl enable --now virtqemud.socket
```

### Connection URIs

| URI | Access | Notes |
|---|---|---|
| `qemu:///system` | Root/system VMs | Default for virsh |
| `qemu:///session` | Unprivileged user VMs | Per-user VMs |
| `qemu+ssh://user@host/system` | Remote over SSH | Most common remote |
| `qemu+tcp://host:16509/system` | Remote TCP | Add TLS in production |

### XML Domain Definition

Core structure of a VM definition:

```xml
<domain type='kvm'>
  <name>myvm</name>
  <memory unit='GiB'>8</memory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features><acpi/><apic/></features>
  <cpu mode='host-passthrough' check='none' migratable='on'/>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native'/>
      <source file='/var/lib/libvirt/images/myvm.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <memballoon model='virtio'/>
    <rng model='virtio'>
      <backend model='random'>/dev/urandom</backend>
    </rng>
  </devices>
</domain>
```

---

## Storage Architecture

### Disk Formats

| Format | Performance | Snapshots | Thin | Use Case |
|---|---|---|---|---|
| `qcow2` | Good | Yes (internal) | Yes | Default; snapshots, linked clones |
| `raw` | Best | No (external only) | No | Maximum performance, LVM backing |
| `vmdk` | Moderate | N/A | N/A | VMware import/export |

### Storage Pools

| Pool Type | Backend | Use Case |
|---|---|---|
| `dir` | Directory of image files | Default, simplest |
| `logical` | LVM volume group | Raw block performance |
| `iscsi` | iSCSI target | SAN storage |
| `rbd` | Ceph RADOS block device | Scale-out, replicated |
| `netfs` | NFS/CIFS mount | Shared for migration |
| `gluster` | GlusterFS | Distributed filesystem |

### virtiofs (Host-Guest Sharing)

Requires `virtiofsd` daemon and shared memory backing:

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs'/>
  <source dir='/host/share'/>
  <target dir='myshare'/>
</filesystem>
```

Guest mount: `mount -t virtiofs myshare /mnt/share`

---

## Networking Architecture

### Network Types

| Type | Isolation | Performance | Host-Guest | Use Case |
|---|---|---|---|---|
| NAT (virbr0) | Yes | Good | Yes | Default; internet for VMs |
| Bridged | No | Best | Yes | VMs as LAN peers |
| macvtap | Partial | Very good | No | Direct on physical NIC |
| OVS | Configurable | Best | Yes | SDN, VLANs, tunnels |
| SR-IOV | No | Near-native | No | Hardware VF passthrough |
| Isolated | Full | Good | No | VM-to-VM only |

### Default NAT Network (virbr0)

libvirt creates `virbr0` with dnsmasq providing DHCP (192.168.122.0/24) and DNS forwarding. NAT via iptables/nftables masquerade rules.

```bash
virsh net-list --all
virsh net-dumpxml default      # show config
virsh net-dhcp-leases default  # DHCP lease table
```

### Bridged Networking

VMs appear as peers on the physical network:

```bash
# Create bridge with NetworkManager
nmcli con add type bridge ifname br0
nmcli con add type bridge-slave ifname eth0 master br0
nmcli con modify bridge-br0 bridge.stp no
```

VM XML: `<interface type='bridge'><source bridge='br0'/><model type='virtio'/></interface>`

### Open vSwitch

```bash
ovs-vsctl add-br ovsbr0
# VM XML: <interface type='bridge'><source bridge='ovsbr0'/><virtualport type='openvswitch'/></interface>
```

### SR-IOV Passthrough

Requires IOMMU enabled in kernel command line (`intel_iommu=on` or `amd_iommu=on`):

```bash
# Enable VFs on physical function
echo 4 > /sys/class/net/eth0/device/sriov_numvfs

# Pass VF to VM via hostdev XML element
```

---

## Live Migration

### Requirements
- Compatible CPU features on source and destination
- Network connectivity between hosts
- Shared storage visible to both hosts (or use copy-storage)
- Same libvirt version recommended

### Migration Modes

| Mode | Shared Storage | Disk Copy | Use Case |
|---|---|---|---|
| `--live` | Required | No | Standard live migration |
| `--live --copy-storage-all` | Not needed | Full copy | No shared storage |
| `--live --copy-storage-inc` | Not needed | Incremental | Resuming partial copy |
| `--live --postcopy` | Required | No | Large-memory VMs |

### Post-Copy Migration

For VMs with large memory (100+ GB), post-copy migration transfers the VM to the destination immediately and fetches memory pages on demand. Reduces total migration time but the VM is vulnerable to source host failure during the process.

```bash
virsh migrate --live --postcopy myvm qemu+ssh://dest/system
```
