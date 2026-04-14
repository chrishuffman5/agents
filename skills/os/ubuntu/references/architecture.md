# Ubuntu Architecture Reference

> Cross-version reference (20.04-26.04). Ubuntu-specific architecture only.
> Generic Linux concepts (kernel basics, systemd unit types, cgroup fundamentals) are covered
> in the RHEL architecture reference and not repeated here.

---

## 1. Debian Foundation and Divergence

### Ubuntu's Relationship to Debian

Ubuntu is a downstream derivative of Debian:
- Syncs packages from **Debian unstable (Sid)** at cycle start, then from **Debian testing**
- Packages rebuilt and versioned with Ubuntu epoch (e.g., `1.2.3-4ubuntu2`)
- **Merge vs sync:** Packages with Ubuntu patches require manual merge each cycle
- Ships ~2 cycles behind Debian for stability

### Canonical-Specific Technologies

| Technology | Purpose | Debian Equivalent |
|---|---|---|
| Snap / snapd | Universal packages with sandboxing | Flatpak (third-party) |
| Netplan | Declarative network config | /etc/network/interfaces |
| cloud-init | Cloud instance initialization | cloud-init (upstream, shared) |
| Landscape | Systems management SaaS | None |
| Launchpad | Package hosting / PPA infrastructure | mentors.debian.net |
| Ubuntu Pro / ESM | Extended security maintenance | Debian LTS project |
| Subiquity | Modern server installer | debian-installer (d-i) |
| curtin | Low-level installer backend | partman / debootstrap |

### Package Format

- Binary: `.deb` files (ar archive containing `control.tar.xz` and `data.tar.xz`)
- Source: `.dsc` (descriptor), `.orig.tar.gz` (upstream), `.debian.tar.xz` (delta patches)
- `dpkg-source -x <package.dsc>` -- unpack source package
- `dpkg-buildpackage -us -uc` -- build binary from source

### PPAs (Personal Package Archives)

PPAs are Launchpad-hosted apt repositories:
- Format: `ppa:<owner>/<name>` (e.g., `ppa:deadsnakes/ppa`)
- Add: `add-apt-repository ppa:owner/name`
- Key storage (modern): `/etc/apt/keyrings/<keyname>.gpg`
- Source entry: `.sources` (deb822, 24.04+) or `.list` (legacy one-liner)

---

## 2. Package Management: apt / dpkg / snap

### dpkg Internals

- Database: `/var/lib/dpkg/status` -- installed packages, versions, dependencies
- File lists: `/var/lib/dpkg/info/<package>.list`
- Maintainer scripts: `.preinst`, `.postinst`, `.prerm`, `.postrm`
- States: `ii` (installed), `rc` (removed, config remains), `pn` (purged)
- `dpkg --configure -a` -- configure partially configured packages (post-crash recovery)
- `dpkg --audit` -- find broken package states

### apt Architecture

**Repository configuration -- Legacy vs deb822:**
- Legacy (pre-24.04): `/etc/apt/sources.list` one-liner format
- deb822 (24.04+ default): `/etc/apt/sources.list.d/ubuntu.sources`

```
# deb822 format
Types: deb deb-src
URIs: http://archive.ubuntu.com/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

**Ubuntu archive components:**

| Component | Description | Support |
|---|---|---|
| main | Canonical-supported FOSS | Full security updates |
| restricted | Proprietary drivers (NVIDIA) | Best-effort |
| universe | Community FOSS (from Debian) | Community; ESM via Pro |
| multiverse | Non-free, patent-restricted | None |

**apt pinning:** `/etc/apt/preferences.d/<name>` -- version pinning with priority values. `apt-mark hold <package>` prevents upgrades.

**Key commands:**
- `apt list --upgradable` -- pending upgrades
- `apt install --no-install-recommends` -- skip recommended packages
- `apt autoremove --purge` -- remove unused deps and config
- `unattended-upgrades` -- automatic security updates
- `needrestart` -- detect daemons needing restart after upgrades

### snap Architecture

**snapd daemon** manages snap lifecycle:
- Snaps are squashfs images in `/var/lib/snapd/snaps/<name>_<rev>.snap`
- Mount points: `/snap/<name>/<revision>/` (read-only)
- Current symlink: `/snap/<name>/current`
- Data: `/var/snap/<name>/current/` (versioned), `/var/snap/<name>/common/` (revision-independent)

**Snap Store and channels:**
- Channels: `<track>/<risk>/<branch>` (e.g., `latest/stable`, `22/stable`)
- Risks: `stable` > `candidate` > `beta` > `edge`
- Automatic refresh 4x/day; defer with `snap refresh --hold`

**Confinement levels:**

| Level | Description | AppArmor |
|---|---|---|
| strict | Full sandbox; access via declared interfaces | Generated, enforcing |
| classic | No confinement; full system access | None |
| devmode | Violations logged, not blocked | Generated, complain |

**Snap vs deb comparison:**

| Aspect | snap | deb |
|---|---|---|
| Bundling | Self-contained with dependencies | Shared system libraries |
| Updates | Automatic, delta-based, atomic | Manual via apt |
| Rollback | `snap revert <name>` | No built-in rollback |
| Confinement | AppArmor + seccomp sandbox | None |
| Disk usage | Higher (bundled deps) | Lower (shared libs) |

---

## 3. Netplan

### Architecture

Netplan is a declarative network configuration frontend that generates backend config files:

| Variant | Default Backend | Config Written To |
|---|---|---|
| Server | systemd-networkd | `/run/systemd/network/` |
| Desktop | NetworkManager | `/run/NetworkManager/` |

Configuration: `/etc/netplan/*.yaml` -- multiple files merged alphabetically.

### Key Commands

- `netplan apply` -- apply immediately (may disrupt connections)
- `netplan try` -- apply with 120s auto-revert
- `netplan generate` -- write backend config without applying
- `netplan get` -- read effective configuration
- `netplan set` -- set a config key
- `netplan status` -- interface status (Netplan 1.0+)

### Configuration Examples

**Static IP (server):**
```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      addresses: [192.168.1.10/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

**Bonding:**
```yaml
network:
  version: 2
  bonds:
    bond0:
      interfaces: [enp1s0, enp2s0]
      parameters:
        mode: active-backup
        primary: enp1s0
      dhcp4: true
```

**VLAN:**
```yaml
network:
  version: 2
  vlans:
    vlan10:
      id: 10
      link: eth0
      addresses: [10.10.10.1/24]
```

---

## 4. cloud-init

### Stage Architecture

| Stage | Service | Purpose |
|---|---|---|
| generator | `cloud-init-generator` | Determines if cloud-init should run |
| local | `cloud-init-local.service` | Local config before network; sets hostname |
| network | `cloud-init.service` | Fetches user-data from metadata service |
| config | `cloud-config.service` | Applies modules (packages, files, users) |
| final | `cloud-final.service` | Runs per-boot/per-instance/per-once scripts |

### Data Sources

| Data Source | Platform | Metadata URL |
|---|---|---|
| EC2 | AWS | `http://169.254.169.254/` |
| Azure | Microsoft Azure | `http://169.254.169.254/` (IMDS) |
| GCE | Google Cloud | `http://metadata.google.internal/` |
| OpenStack | OpenStack | ISO9660 config drive |
| NoCloud | Local VMs / testing | Seed from ISO or kernel cmdline |

### Key Paths and Commands

- `/var/lib/cloud/` -- runtime state
- `/var/log/cloud-init.log` -- main log
- `cloud-init status --wait` -- block until complete
- `cloud-init query -a` -- dump all metadata
- `cloud-init clean --logs` -- reset for re-run
- `cloud-init schema --config-file <file>` -- validate syntax

Network config written to `/etc/netplan/50-cloud-init.yaml`. Disable with `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg` containing `network: {config: disabled}`.

---

## 5. Filesystem and Storage

### Default Layouts

| Variant | Default Root FS | Notes |
|---|---|---|
| Server (Subiquity) | ext4 on LVM | VG `ubuntu-vg`, LV `ubuntu-lv` (50% VG) |
| Desktop | ext4 (no LVM) | Single partition |
| Server ZFS option | ZFS root | `rpool` + `bpool`, available since 20.04 |
| Cloud images | ext4 (no LVM) | cloud-init resizes on boot |

### ZFS on Ubuntu

Ubuntu provides first-class ZFS root support:
- Package: `zfsutils-linux` (universe)
- Pool: `rpool` (root); dataset: `rpool/ROOT/ubuntu`
- Boot pool: `bpool` for `/boot`
- `zpool status` -- health; `zpool scrub` -- integrity check
- `zfs snapshot`, `zfs rollback` -- manage snapshots

### LVM Layout

- Default VG: `ubuntu-vg`; LV: `ubuntu-lv` (sized at 50% of VG)
- Extend root: `lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && resize2fs /dev/ubuntu-vg/ubuntu-lv`

---

## 6. Snap Confinement and Security

### AppArmor Integration

Every strict-confined snap gets a generated AppArmor profile:
- Location: `/var/lib/snapd/apparmor/profiles/snap.<name>.<app>`
- `aa-status | grep snap` -- list snap profiles

### Interfaces: Plug/Slot Model

- **Plug:** what a snap requests (consumer)
- **Slot:** what provides the resource (OS core or other snap)
- `snap connections <snap>` -- list connected interfaces
- `snap connect <snap>:<plug> <provider>:<slot>` -- manual connect

**Common interfaces:** `network`, `network-bind`, `home` (manual), `removable-media` (manual), `system-files` (manual, per-path), `content` (shared data), `docker-support`.

---

## 7. Ubuntu Pro and ESM

### Ubuntu Pro Overlay

- Free tier: up to 5 machines (personal)
- `pro attach <token>` -- attach to subscription
- `pro status` -- enabled/disabled services

### ESM Repositories

| Repository | Scope | Coverage |
|---|---|---|
| esm-infra | main component | +5 years after standard EOL |
| esm-apps | universe component | Ongoing during LTS lifetime |

### Livepatch

- Package: `canonical-livepatch` (via `pro enable livepatch`)
- Daemon polls Canonical's patch server; applies patches via kernel module
- `canonical-livepatch status --verbose` -- detailed patch state

### FIPS and USG

- `pro enable fips` / `pro enable fips-updates` -- FIPS-validated crypto
- `pro enable usg` -- Ubuntu Security Guide for CIS/STIG hardening
- `usg audit cis_level1_server` -- compliance audit
- `usg fix cis_level1_server` -- apply hardening

---

## 8. Subiquity and Autoinstall

### Subiquity

Ubuntu's modern server installer (Python/urwid TUI, curtin backend). Runs as systemd service on the installer ISO.

### Autoinstall YAML

Unattended installation via cloud-init user-data:

**Key sections:** `identity` (hostname, user, password), `storage` (lvm, zfs, direct), `network` (netplan config), `ssh` (OpenSSH + keys), `packages`, `snaps`, `late-commands`, `error-commands`.

---

## 9. LXD / Incus

### Architecture

LXD: Canonical's system container/VM manager (snap). Incus: community fork (deb, 24.04+ universe).

- Containers share host kernel (via LXC); VMs use QEMU/KVM
- Profiles: reusable config; Projects: namespace isolation
- Storage pools: ZFS, Btrfs, LVM, directory-backed
- Default bridge: `lxdbr0` (NAT + DHCP/DNS via dnsmasq)
- Clustering via Dqlite (distributed SQLite)

---

## 10. MicroK8s

### Architecture

All Kubernetes components run as snap services inside a single strict-confined snap: kubelet, kube-apiserver, kube-scheduler, kube-controller-manager, containerd, etcd.

### Add-ons

| Add-on | Function |
|---|---|
| dns | CoreDNS cluster DNS |
| storage | Hostpath provisioner |
| ingress | NGINX ingress controller |
| metallb | Bare-metal load balancer |
| gpu | NVIDIA GPU operator |
| observability | Prometheus + Grafana + Loki |
| cert-manager | TLS certificate manager |

### High Availability

- HA requires 3+ nodes with Dqlite (not external etcd)
- `microk8s add-node` generates single-use join token
- HA activates automatically at 3 nodes

---

## Version Matrix: Feature Availability

| Feature | 20.04 | 22.04 | 24.04 | 26.04 |
|---|---|---|---|---|
| deb822 sources | No | Partial | Default | Default |
| apt-key deprecated | No | Yes | Removed | Removed |
| ZFS root option | Yes | Yes | Yes | Yes |
| Netplan default | Yes | Yes | Yes (1.0) | Yes |
| Ubuntu Pro free tier | No | Yes | Yes | Yes |
| TPM LUKS unlock | No | No | Experimental | GA |
| LXD/Incus | lxd | lxd | incus+lxd | incus |
| Jinja2 cloud-config | No | Yes | Yes | Yes |
| dracut initramfs | No | No | No | Default |
| cgroup v2 only | No | No | No | Yes |
