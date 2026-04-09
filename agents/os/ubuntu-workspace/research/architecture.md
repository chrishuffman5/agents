# Ubuntu Internal Architecture — Cross-Version Reference (20.04–26.04)

> **Scope:** Ubuntu-specific architecture. Generic Linux concepts (kernel basics, systemd unit
> types, cgroup fundamentals) covered in the RHEL architecture reference are not repeated here.
> Focus is on what Ubuntu does differently.

---

## 1. Debian Foundation and Divergence

### Ubuntu's Relationship to Debian
Ubuntu is a downstream derivative of Debian. Key mechanics:
- Ubuntu syncs packages from **Debian unstable (Sid)** at the start of each development cycle,
  then from **Debian testing** as the cycle matures.
- After the sync, Ubuntu diverges: packages are rebuilt, patched, and versioned with an Ubuntu
  epoch (e.g., `1.2.3-4ubuntu2`). The `-4` is the Debian revision; `ubuntu2` is the Ubuntu delta.
- **Merge vs. sync:** Packages with Ubuntu-specific patches require a manual merge each cycle.
  Pure syncs pull Debian packages unmodified. Merge status is tracked at
  https://merges.ubuntu.com.
- Ubuntu ships **~2 cycles behind Debian** for most stable packages — intentional stability lag.

### Canonical-Specific Technologies (Not in Debian)
| Technology | Purpose | Debian Equivalent |
|---|---|---|
| Snap / snapd | Universal packages with sandboxing | Flatpak (third-party) |
| Netplan | Declarative network config | /etc/network/interfaces or ifupdown2 |
| cloud-init | Cloud instance initialization | cloud-init (upstream, shared) |
| Landscape | Systems management SaaS | None |
| Launchpad | Package hosting / PPA infrastructure | mentors.debian.net (weaker) |
| Ubuntu Pro / ESM | Extended security maintenance | LTS security (Debian LTS project) |
| Subiquity | Modern server installer | debian-installer (d-i) |
| curtin | Low-level installer backend | partman / debootstrap |

### Package Format: deb and Source Packages
- Binary packages: `.deb` files (ar archive containing `control.tar.xz` and `data.tar.xz`)
- Source packages: three files — `.dsc` (descriptor), `.orig.tar.gz` (upstream source),
  `.debian.tar.xz` (Ubuntu/Debian delta patches)
- `dpkg-source -x <package.dsc>` — unpacks a source package
- `dpkg-buildpackage -us -uc` — builds binary from source
- Ubuntu adds `debian/changelog` entries with the target series (e.g., `focal`, `jammy`, `noble`)
- `dch -i` — increment changelog version; `dch -D noble` — set target distribution

### PPAs (Personal Package Archives)
PPAs are Launchpad-hosted apt repositories for individual maintainers or teams:
- Format: `ppa:<owner>/<name>` — e.g., `ppa:deadsnakes/ppa`
- Add: `add-apt-repository ppa:owner/name` — fetches signing key, writes source entry
- PPA packages override Ubuntu archive packages when pinned higher
- PPAs build against a specific Ubuntu series; not all PPAs support all releases
- Key storage (modern): `/etc/apt/keyrings/<keyname>.gpg` (not the deprecated apt-key keyring)
- PPA source entry written to `/etc/apt/sources.list.d/<owner>-ubuntu-<name>-<series>.sources`
  (deb822 format, 24.04+) or `.list` (legacy one-liner format)

---

## 2. Package Management: apt / dpkg / snap

### dpkg Internals
dpkg is the low-level package tool; apt is the high-level resolver.
- Package database: `/var/lib/dpkg/status` — installed packages, versions, dependencies
- `/var/lib/dpkg/info/<package>.list` — files owned by a package
- `/var/lib/dpkg/info/<package>.preinst|postinst|prerm|postrm` — maintainer scripts
- States: `ii` (installed), `rc` (removed, config files remain), `pn` (purged)
- `dpkg -l <pattern>` — list packages matching pattern with state codes
- `dpkg -L <package>` — list files owned by installed package
- `dpkg -S <file>` — find which package owns a file
- `dpkg --configure -a` — configure all partially configured packages (post-crash recovery)
- `dpkg --audit` — find broken package states

### apt Architecture

**Repository Configuration — Legacy vs. deb822**
- Legacy (pre-24.04 default): `/etc/apt/sources.list` one-liner format
  ```
  deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
  deb-src http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
  ```
- deb822 format (default in 24.04 Noble+): `/etc/apt/sources.list.d/ubuntu.sources`
  ```yaml
  Types: deb deb-src
  URIs: http://archive.ubuntu.com/ubuntu
  Suites: noble noble-updates noble-backports
  Components: main restricted universe multiverse
  Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
  ```
- `apt-key` is **deprecated** since Ubuntu 22.04. Use `signed-by` with a keyring file instead.
- Import key correctly: `curl -fsSL <url> | gpg --dearmor -o /etc/apt/keyrings/<name>.gpg`

**Ubuntu Archive Components**
| Component | Description | Support |
|---|---|---|
| main | Canonical-supported FOSS | Full security updates |
| restricted | Proprietary drivers (e.g., NVIDIA) | Best-effort |
| universe | Community FOSS (from Debian) | Community; ESM via Ubuntu Pro |
| multiverse | Non-free, patent-restricted | None |

**apt Pinning and Preferences**
- `/etc/apt/preferences` or `/etc/apt/preferences.d/<name>` — package version pinning
- Pin priority: >1000 downgrade-allows; 1000 = force even if older; 990 = target release;
  500 = installed; 100 = non-target; negative = blacklist
  ```
  Package: nodejs
  Pin: version 18.*
  Pin-Priority: 1001
  ```
- `apt-cache policy <package>` — show candidate and all available versions with priorities
- `apt-mark hold <package>` — prevent automatic upgrades; `apt-mark unhold` to release

**apt Command Reference (Ubuntu-specific patterns)**
- `apt list --upgradable` — see pending upgrades
- `apt install --no-install-recommends` — skip recommended packages (common in containers)
- `apt autoremove --purge` — remove unused deps and config files
- `unattended-upgrades` — automatic security updates; config: `/etc/apt/apt.conf.d/50unattended-upgrades`
- `needrestart` — post-upgrade tool that detects daemons needing restart (interactive or auto)

### snap Architecture

**snapd Daemon**
- `snapd` is a persistent system daemon managing snap lifecycle
- Snaps are mounted as squashfs images from `/var/lib/snapd/snaps/<name>_<rev>.snap`
- Mount points: `/snap/<name>/<revision>/` — read-only squashfs mount
- Current symlink: `/snap/<name>/current` → active revision
- `snapd.socket` — Unix socket for snap CLI communication
- Data directories: `/var/snap/<name>/current/` (versioned data), `/var/snap/<name>/common/`
  (revision-independent data), `~/snap/<name>/current/` (user data)

**Snap Store and Channels**
- Snap Store (store.snapcraft.io) — central registry operated by Canonical
- Channels: `<track>/<risk>/<branch>` — e.g., `latest/stable`, `22/stable`, `edge`
  - Tracks: version-specific (e.g., `22`, `3.x`) or `latest`
  - Risks: `stable` → `candidate` → `beta` → `edge` (decreasing stability)
  - Branch: optional temporary channel (e.g., `latest/stable/fix-123`)
- `snap install <name> --channel=<channel>` — install from specific channel
- `snap switch <name> --channel=<channel>` — change tracking channel without reinstalling
- `snap refresh` — update all snaps; runs automatically 4x/day by default
- `snap refresh --hold` or `snap refresh --hold=<duration>` — defer refresh

**Snap Confinement Levels**
| Level | Description | AppArmor Profile |
|---|---|---|
| strict | Full sandbox; access only via declared interfaces | Generated, enforcing |
| classic | No confinement; full system access (like traditional package) | None |
| devmode | Strict confinement but violations logged, not blocked | Generated, complain mode |

- `snap info <name>` — shows confinement level, channels, revision
- `snap list` — installed snaps with confinement and notes
- Classic snaps require explicit `--classic` flag: `snap install code --classic`

**Snap vs. deb Comparison**
| Aspect | snap | deb |
|---|---|---|
| Bundling | Self-contained with dependencies | Shared system libraries |
| Updates | Automatic, delta-based, atomic | Manual via apt |
| Rollback | `snap revert <name>` to previous rev | No built-in rollback |
| Confinement | AppArmor + seccomp sandbox | None (runs as installed) |
| Config files | In `/var/snap/` or `~/snap/` | In `/etc/` and `~/.config/` |
| Multiple versions | Via channels and revisions | Only one installed version |
| Disk usage | Higher (bundled deps) | Lower (shared libs) |

**snapcraft** — Build tool for creating snaps:
- `snapcraft.yaml` defines the snap: `name`, `version`, `parts`, `apps`, `confinement`
- Build environments: Multipass VM or LXD container
- `snapcraft` command builds, packs, and optionally publishes to the Snap Store

---

## 3. Netplan

### Architecture
Netplan is Ubuntu's declarative network configuration layer, introduced in Ubuntu 17.10 and default
for all Ubuntu variants since 18.04. It acts as a **frontend generator** — it does not configure
networking itself but generates backend configuration files.

**Backends:**
| Variant | Default Backend | Config Written To |
|---|---|---|
| Ubuntu Server | `systemd-networkd` | `/run/systemd/network/` |
| Ubuntu Desktop | `NetworkManager` | `/run/NetworkManager/` |

**Configuration location:** `/etc/netplan/*.yaml` — multiple files merged alphabetically.
Higher-numbered files take precedence for conflicting keys.

### Key Commands
- `netplan apply` — applies configuration immediately (may disrupt active connections)
- `netplan try` — applies config with 120-second auto-revert if not confirmed (`netplan try --timeout=60`)
- `netplan generate` — writes backend config without applying
- `netplan get` — read current effective configuration
- `netplan set` — set a key in the configuration file
- `netplan ip leases <interface>` — show DHCP lease info

### Configuration Examples

**Static IP (server with systemd-networkd):**
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
        search: [example.com]
```

**DHCP with optional fallback:**
```yaml
network:
  version: 2
  ethernets:
    ens3:
      dhcp4: true
      dhcp6: false
      optional: true
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
        mii-monitor-interval: 100
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

**WPA2 WiFi:**
```yaml
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlan0:
      dhcp4: true
      access-points:
        "MyNetwork":
          password: "mysecretpassword"
```

---

## 4. cloud-init

### Stage Architecture
cloud-init runs across five ordered stages on first boot:

| Stage | Service | Purpose |
|---|---|---|
| generator | `cloud-init-generator` (systemd generator) | Determines if cloud-init should run; checks `/etc/cloud/cloud-init.disabled` |
| local | `cloud-init-local.service` | Applies local datasource config (before network); sets hostname, writes network config |
| network | `cloud-init.service` | Runs after network is up; fetches user-data from metadata service |
| config | `cloud-config.service` | Applies cloud-config modules (packages, files, users, etc.) |
| final | `cloud-final.service` | Runs scripts in `/var/lib/cloud/scripts/per-boot/`, `per-instance/`, `per-once/` |

### Data Sources
cloud-init auto-detects the platform via data source probing:
| Data Source | Platform | Metadata URL |
|---|---|---|
| EC2 | AWS | `http://169.254.169.254/` |
| Azure | Microsoft Azure | `http://169.254.169.254/` (IMDS) |
| GCE | Google Cloud | `http://metadata.google.internal/` |
| OpenStack / ConfigDrive | OpenStack | ISO9660 config drive attached to instance |
| NoCloud | Local VMs / testing | Seed from ISO, filesystem, or kernel cmdline |
| None | Bare metal / unknown | Disables cloud-init behavior |

- `/etc/cloud/cloud.cfg.d/90_dpkg.cfg` — sets default datasource list on Ubuntu
- Force datasource: `echo 'datasource_list: [NoCloud]' > /etc/cloud/cloud.cfg.d/99-force-ds.cfg`

### user-data Formats
- **cloud-config YAML** (most common): starts with `#cloud-config`
  ```yaml
  #cloud-config
  package_update: true
  packages:
    - nginx
    - git
  users:
    - name: deploy
      sudo: ALL=(ALL) NOPASSWD:ALL
      shell: /bin/bash
      ssh_authorized_keys:
        - ssh-ed25519 AAAA...
  runcmd:
    - systemctl enable nginx
  ```
- **Shell script:** starts with `#!/bin/bash` — executed directly
- **MIME multipart:** combines multiple formats in one user-data blob
- **Jinja2 templating** (22.04+): `## template: jinja` header enables variable substitution from
  instance metadata

### Network Configuration
- v1 format: cloud-init-specific YAML with `config:` list (legacy)
- v2 format: Netplan-compatible YAML — passed through directly to Netplan on Ubuntu
- cloud-init writes network config to `/etc/netplan/50-cloud-init.yaml` (Ubuntu default)
- Disable cloud-init network management: create `/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`
  with `network: {config: disabled}`

### Key Paths and Commands
- `/var/lib/cloud/` — all cloud-init runtime state
- `/var/lib/cloud/instance/` — symlink to current instance data
- `/var/lib/cloud/scripts/` — per-boot, per-instance, per-once script directories
- `/var/log/cloud-init.log` — main log; `/var/log/cloud-init-output.log` — stdout/stderr capture
- `cloud-init status` — show current stage and result
- `cloud-init status --wait` — block until cloud-init completes
- `cloud-init query userdata` — show decoded user-data
- `cloud-init query -a` — dump all instance metadata
- `cloud-init clean --logs` — reset state for re-run (used when building images)
- `cloud-init schema --config-file user-data.yaml` — validate cloud-config syntax

---

## 5. Filesystem and Storage

### Default Filesystems by Variant
| Ubuntu Variant | Default Root FS | Notes |
|---|---|---|
| Server (Subiquity) | ext4 on LVM | LVM group `ubuntu-vg`, logical volume `ubuntu-lv` |
| Desktop | ext4 (no LVM) | Single partition layout |
| Server with ZFS option | ZFS (root on ZFS) | Available since 20.04; uses zfsutils-linux |
| Cloud images | ext4 (no LVM) | Thin provisioned, cloud-init resizes on boot |

### ZFS on Ubuntu
Ubuntu is notable for first-class ZFS root support — not available by default on RHEL:
- Package: `zfsutils-linux` (maintained in Ubuntu universe)
- Root-on-ZFS available since Ubuntu 20.04 via Subiquity installer
- Pool: `rpool` (root pool); dataset: `rpool/ROOT/ubuntu`
- Boot pool: `bpool` (small pool at start of disk for `/boot`)
- Snapshots automatic on upgrades: `rpool/ROOT/ubuntu@<date>`
- `zfs list` — list datasets; `zfs snapshot`, `zfs rollback` — manage snapshots
- `zpool status` — pool health; `zpool scrub <pool>` — integrity check

### LVM Layout (Standard Server Install)
- Volume group: `ubuntu-vg` (default name)
- Logical volume: `ubuntu-lv` — root filesystem (sized at 50% of VG by default in Subiquity)
- Remaining VG space intentionally unallocated for admin use
- Extend root: `lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv && resize2fs /dev/ubuntu-vg/ubuntu-lv`

### LUKS Full-Disk Encryption
- Subiquity supports LUKS encryption during install (20.04+)
- TPM-backed unlock (no passphrase at boot) available in 23.10+ via `tpm2-totp` integration
- Key management: `cryptsetup luksAddKey`, `cryptsetup luksRemoveKey`
- LUKS2 header format default since Ubuntu 20.04

### Btrfs
Available via `apt install btrfs-progs` but not offered as default in installer. Not Ubuntu-specific
and not recommended for production root in Ubuntu (unlike Fedora/openSUSE where it is default).

### Stratis
**Not available on Ubuntu.** Stratis is a Red Hat project; Ubuntu uses ZFS or LVM+ext4 instead.

---

## 6. Snap Confinement and Security

### AppArmor Integration with Snaps
Every strict-confined snap gets a generated AppArmor profile:
- Profile location: `/var/lib/snapd/apparmor/profiles/snap.<name>.<app>`
- Loaded at snap install; kernel enforces via LSM
- `aa-status | grep snap` — list all snap AppArmor profiles
- Profiles are regenerated on snapd or snap updates

### Interfaces: Plug/Slot Model
Snaps access host resources via **interfaces**:
- **Plug:** what a snap *requests* (consumer side)
- **Slot:** what provides the resource (usually the OS core snap or another snap)
- `snap interfaces` or `snap connections <snap>` — list connected interfaces
- `snap connect <snap>:<plug> <provider>:<slot>` — manually connect
- `snap disconnect <snap>:<plug>` — disconnect

**Common Interfaces:**
| Interface | Provides Access To |
|---|---|
| `network` | Outbound network (auto-connected for strict snaps) |
| `network-bind` | Binding to network ports |
| `home` | User home directory (manual connect required) |
| `removable-media` | `/media/`, `/mnt/` (manual connect required) |
| `system-files` | Specific host filesystem paths (manual, per-path) |
| `content` | Shared data directories between snaps |
| `docker-support` | Docker daemon privileges |
| `hardware-observe` | Read hardware info |

### Auto-connect vs Manual Connect
- Auto-connected: `network`, `network-bind`, `x11`, `wayland`, `opengl` (varies by snap declaration)
- Manual connect: `home`, `removable-media`, `system-files` — require user or admin action
- Store-declared auto-connections: snap publisher can request auto-connect via store declaration

### seccomp Filtering
Each snap also has a seccomp filter:
- Profile: `/var/lib/snapd/seccomp/bpf/<snap>.<app>.src`
- Compiled to BPF and applied at snap launch
- Blocks syscalls not declared in the snap's security definition

---

## 7. Ubuntu Pro and ESM

### Ubuntu Pro Overlay Architecture
Ubuntu Pro is a subscription layer on top of standard Ubuntu LTS releases:
- Free tier: up to 5 machines (personal use)
- Paid tier: unlimited machines (commercial use)
- `pro attach <token>` — attaches machine to Ubuntu Pro account
- `pro detach` — removes Pro entitlements
- `pro status` — shows enabled/disabled services and coverage
- `pro enable <service>` / `pro disable <service>` — manage individual services

### ESM (Extended Security Maintenance) Repos
| Repository | Scope | Coverage Period |
|---|---|---|
| esm-infra | Packages in `main` component | 5 additional years after standard EOL |
| esm-apps | Packages in `universe` component | Ongoing during LTS lifetime |

- ESM repos are authenticated apt repos requiring the Ubuntu Pro token
- Once attached, `apt upgrade` automatically includes ESM security updates
- `pro fix CVE-<year>-<number>` — check and apply fix for a specific CVE

### Livepatch (Kernel Live Patching)
Canonical's kernel live patching service (contrast with RHEL's kpatch):
- Package: `canonical-livepatch` (installed via `pro enable livepatch`)
- Daemon: `livepatchd` — polls Canonical's patch server, applies patches via kernel module
- Different from RHEL kpatch: Canonical operates the patch server; patches are signed and
  delivered as a service, not as individual RPMs from CDN
- `canonical-livepatch status` — show applied patches and coverage
- `canonical-livepatch status --verbose` — detailed patch state
- Patches applied in-memory; `canonical-livepatch status` shows kernel CVE coverage

### FIPS Certified Packages
- `pro enable fips` — installs FIPS-validated cryptographic modules
- `pro enable fips-updates` — FIPS with updated (non-validated) security patches
- FIPS modules: `openssl-fips`, `libssl-fips`, `openssh-fips`
- FIPS certification per Ubuntu LTS release (e.g., 20.04 FIPS certified for US Gov use)
- Enabling FIPS requires reboot; sets kernel boot parameter `fips=1`

### Ubuntu Security Guide (USG) / CIS Hardening
- Package: `usg` (Ubuntu Security Guide), enabled via `pro enable usg`
- Applies CIS Benchmark hardening profiles: `usg fix cis_level1_server`
- Audit mode: `usg audit cis_level1_server` — checks compliance without changing config
- Generates HTML/XML compliance reports
- STIG profile also available: `usg fix stig`

---

## 8. Subiquity and Autoinstall

### Subiquity (Server Installer)
Ubuntu's modern server installer (replaced the old debian-installer in 20.04):
- Written in Python; uses a React-based TUI (text UI) via `urwid`
- Backend: **curtin** (block-level installer using `curtin` commands for partitioning/formatting)
- `subiquity` runs as a systemd service on the installer ISO
- Interactive or automated via **autoinstall**

### Autoinstall YAML
Autoinstall is Ubuntu's unattended installation mechanism (replaces Debian preseed):
- Passed via: cloud-init user-data on the installer, kernel cmdline (`autoinstall ds=nocloud`),
  or a seed ISO
- File location during install: `/autoinstall.yaml` or embedded in cloud-init user-data under
  `autoinstall:` key

**Minimal autoinstall example:**
```yaml
#cloud-config
autoinstall:
  version: 1
  identity:
    hostname: myserver
    username: ubuntu
    password: $6$...  # SHA-512 hash
  storage:
    layout:
      name: lvm
  ssh:
    install-server: true
    authorized-keys:
      - ssh-ed25519 AAAA...
  packages:
    - nginx
  late-commands:
    - curtin in-target -- systemctl enable nginx
```

**Key autoinstall sections:**
| Section | Purpose |
|---|---|
| `identity` | Hostname, username, password |
| `storage` | Partition layout (lvm, direct, zfs, or custom) |
| `network` | Netplan config for installer network |
| `ssh` | OpenSSH server installation and authorized keys |
| `packages` | Extra packages to install |
| `snaps` | Snaps to install post-install |
| `user-data` | cloud-init user-data merged post-install |
| `late-commands` | Shell commands run after installation completes |
| `error-commands` | Commands run on install failure |

### curtin
Low-level installer invoked by Subiquity:
- Handles: partitioning, filesystem creation, bootloader (GRUB) install, package installation
- `curtin in-target -- <command>` — run command in the installed system chroot
- Config: curtin YAML (different from autoinstall YAML — lower level)

---

## 9. LXD / Incus

### Architecture Overview
LXD is a system container and virtual machine manager developed by Canonical. In late 2023,
Canonical transferred LXD to a new path: it became part of the Canonical product portfolio
(no longer community-governed). The community forked LXD as **Incus** under the Linux Containers
project. Ubuntu 24.04+ ships `incus` in universe; `lxd` remains available as a snap.

- `lxd` snap: Canonical's managed version (updated via snap channels)
- `incus` package: Community fork, available in Ubuntu 24.04 universe

### Core Concepts
- **Containers:** System containers sharing host kernel (via LXC); not application containers
- **VMs:** Full VMs managed by QEMU/KVM with `lxd` (or `incus`)
- **Profiles:** Reusable configuration applied to instances
- **Projects:** Namespace isolation for instances, images, profiles, networks, storage pools
- **Image server:** `images.linuxcontainers.org` — prebuilt container images for most distros

### Key Commands (lxc CLI)
```bash
lxc launch ubuntu:22.04 mycontainer          # Create and start container
lxc launch ubuntu:22.04 myvm --vm            # Create and start VM
lxc exec mycontainer -- bash                 # Shell into container
lxc file push localfile mycontainer/path     # Copy file in
lxc file pull mycontainer/path localfile     # Copy file out
lxc snapshot mycontainer snap0               # Create snapshot
lxc restore mycontainer snap0               # Restore snapshot
lxc copy mycontainer newcontainer            # Clone
lxc delete mycontainer --force              # Delete
lxc list                                    # List instances
lxc info mycontainer                        # Instance details
lxc config show mycontainer                 # Configuration
lxc profile list                            # List profiles
lxc profile edit default                    # Edit default profile
```

### Storage Pools
```bash
lxc storage create mypool zfs source=tank/lxd   # ZFS pool on existing dataset
lxc storage create mypool btrfs                  # Btrfs loop-backed pool
lxc storage create mypool lvm vg.name=ubuntu-vg  # LVM-backed pool
lxc storage create mypool dir source=/data/lxd   # Directory-backed pool
```

### Networking
- Default bridge: `lxdbr0` — NAT bridge with DHCP/DNS (dnsmasq)
- OVN integration: software-defined networking for multi-host clusters
- `lxc network create mybr --type=bridge` — create custom bridge
- `lxc network attach mycontainer mybr eth0` — attach instance to network

### Clustering
- `lxd init --cluster` — initialize cluster on first node
- Additional nodes join via `lxd init` with cluster join token
- Instances can be scheduled across cluster members
- Shared storage via Ceph or remote ZFS

---

## 10. MicroK8s

### Architecture
MicroK8s is Canonical's lightweight Kubernetes distribution, packaged as a **strict-confined snap**.
This is architecturally distinct from other K8s distributions:
- All Kubernetes components run as snap services inside a single snap
- Strict confinement means MicroK8s uses snap interfaces for host resource access
- Single binary snap wrapping `kubelet`, `kube-apiserver`, `kube-scheduler`, `kube-controller-manager`,
  `containerd`, `etcd`
- No dependency on system-installed container runtime or etcd

### Installation and Channels
```bash
snap install microk8s --classic --channel=1.31/stable
snap install microk8s --classic --channel=1.32/stable
```
Note: MicroK8s uses `--classic` confinement for production (full system access needed for networking
and storage operations).

### Key Commands
```bash
microk8s status                              # Cluster and add-on status
microk8s kubectl get nodes                   # Standard kubectl via microk8s
microk8s kubectl get all -A                 # All resources
microk8s enable dns                         # Enable CoreDNS
microk8s enable storage                     # Enable default storage class (hostpath)
microk8s enable ingress                     # Enable NGINX ingress controller
microk8s enable dashboard                   # Enable Kubernetes dashboard
microk8s enable gpu                         # Enable NVIDIA GPU operator
microk8s disable <addon>                    # Disable add-on
microk8s add-node                           # Generate join token for HA cluster
microk8s join <ip>:<port>/<token>           # Join node to cluster
microk8s config                             # Print kubeconfig
microk8s inspect                            # Diagnostic report
```

### Add-on Reference
| Add-on | Function |
|---|---|
| dns | CoreDNS cluster DNS |
| storage | Hostpath provisioner (default StorageClass) |
| ingress | NGINX ingress controller |
| metallb | Bare-metal load balancer |
| cert-manager | TLS certificate manager |
| gpu | NVIDIA GPU operator |
| observability | Prometheus + Grafana + Loki stack |
| registry | Private Docker registry |
| istio | Service mesh |
| knative | Serverless functions runtime |
| minio | S3-compatible object storage |
| hostpath-storage | Simplified hostpath provisioner |

### High Availability
- HA requires 3+ nodes
- Uses Dqlite (distributed SQLite) instead of external etcd for HA coordination
- `microk8s add-node` — generates single-use join token
- HA activates automatically once 3 nodes are joined

### kubectl Alias
```bash
# Add alias so standard kubectl works
alias kubectl='microk8s kubectl'
# Or install kubectl config:
microk8s config > ~/.kube/config
```

---

## Version Matrix: Feature Availability

| Feature | 20.04 LTS | 22.04 LTS | 24.04 LTS | 25.10 | 26.04 LTS |
|---|---|---|---|---|---|
| deb822 sources format | No | Partial | Default | Default | Default |
| apt-key deprecated | No | Yes (warned) | Removed | Removed | Removed |
| ZFS root option | Yes | Yes | Yes | Yes | Yes |
| Netplan default | Yes | Yes | Yes | Yes | Yes |
| cloud-init v2 network | Yes | Yes | Yes | Yes | Yes |
| Ubuntu Pro free tier | No | Yes | Yes | Yes | Yes |
| Livepatch via pro | Yes | Yes | Yes | Yes | Yes |
| USG/CIS via pro | Yes | Yes | Yes | Yes | Yes |
| TPM LUKS unlock | No | No | Yes | Yes | Yes |
| Subiquity autoinstall | Yes | Yes | Yes | Yes | Yes |
| MicroK8s snap | Yes | Yes | Yes | Yes | Yes |
| LXD → Incus transition | lxd | lxd | incus+lxd | incus | incus |
| Jinja2 cloud-config | No | Yes | Yes | Yes | Yes |
