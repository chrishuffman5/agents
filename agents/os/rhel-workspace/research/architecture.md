# RHEL Internal Architecture — Cross-Version Reference (RHEL 8 / 9 / 10)

## 1. Linux Kernel on RHEL

### Kernel Versions per Release
| RHEL Version | Kernel Base | Released |
|---|---|---|
| RHEL 8 | 4.18 (upstream 4.18.0) | May 2019 |
| RHEL 9 | 5.14 (upstream 5.14.0) | May 2022 |
| RHEL 10 | 6.12 (upstream 6.12.0) | May 2025 |

RHEL ships a single kernel version per major release. Minor updates (e.g., RHEL 8.1, 8.2…) deliver security patches and backported features into the same kernel base, never a new upstream kernel version.

### RHEL Backporting Philosophy
Red Hat does NOT simply ship upstream kernels. Features, fixes, and drivers from newer upstream kernels are backported into the RHEL base kernel. This means:
- A RHEL 8 4.18 kernel may contain features originally released in upstream 5.x kernels.
- API/ABI for userspace and kernel modules remains stable across the entire RHEL major lifecycle.
- Backporting is selective — features are reviewed for stability, security, and customer need.

### kABI (Kernel ABI) Guarantee
kABI is Red Hat's commitment that binary kernel modules compiled against the initial RHEL major release kernel will continue to work across all minor updates within that major:
- kABI-stable symbols are whitelisted in `/usr/src/kernels/<version>/Module.symvers`
- Third-party drivers (e.g., from hardware vendors) can be certified against RHEL kABI
- kABI breakage across minor releases is treated as a critical bug
- Package: `kernel-abi-whitelists` (RHEL 8/9) — documents the allowed symbol set

### Kernel Module Compatibility
- Modules built for RHEL 8.0 kABI work on RHEL 8.9+ without recompilation
- Driver Update Programs (DUPs) allow kernel modules to ship outside the main kernel RPM
- `kmod` framework manages module loading; `/etc/modules-load.d/` for persistent loading
- `modprobe.d/` for module parameters: `/etc/modprobe.d/<name>.conf`
- `dracut` integrates modules into initramfs

### kernel-rt (Real-Time Kernel)
Available as a separate package set for deterministic latency workloads:
- Package: `kernel-rt`, `kernel-rt-core`, `kernel-rt-devel`
- Based on the PREEMPT_RT patchset merged incrementally into mainline
- Requires `realtime` or `nfv` subscription add-on (RHEL 8/9); bundled in RHEL 10 for some tiers
- `/etc/tuned/realtime-virtual-guest/tuned.conf` — tuned profile for RT guests
- Typical use: telecoms NFV, industrial control, low-latency finance

### kpatch (Live Patching)
kpatch enables applying kernel security patches without rebooting:
- Architecture: kpatch-build compiles a patch module; kpatch-load inserts it via ftrace hooking
- Patches replace functions at runtime using the ftrace infrastructure
- Package: `kpatch`, `kpatch-patch-<kernel-version>` (delivered via CDN)
- systemd service: `kpatch.service` — applies patches at boot to ensure persistence
- Command: `kpatch list` (view loaded patches), `kpatch load <patch.ko>` (load patch)
- RHEL Kernel Live Patching is a separately entitled feature (requires subscription)
- `/var/lib/kpatch/` — stores installed patch modules
- Patches are cumulative per kernel; each new patch replaces the prior set

---

## 2. systemd Architecture

### Unit Types
| Unit Type | Purpose | Example |
|---|---|---|
| `.service` | Daemon/process lifecycle | `sshd.service` |
| `.socket` | Socket-activated service trigger | `cockpit.socket` |
| `.timer` | Cron replacement, calendar/monotonic | `dnf-makecache.timer` |
| `.mount` | Filesystem mount points | `boot.mount` |
| `.automount` | On-demand mount trigger | `proc-sys-fs-binfmt_misc.automount` |
| `.path` | File/directory change watcher | `cups.path` |
| `.slice` | cgroup resource hierarchy node | `system.slice` |
| `.scope` | Externally created process group | `session-1.scope` |
| `.target` | Synchronization/grouping point | `multi-user.target` |
| `.device` | udev device node representation | `dev-sda1.device` |
| `.swap` | Swap space | `dev-dm-1.swap` |

### Unit Dependency Keywords
- `Requires=` — hard dependency; if dependency fails, this unit also fails
- `Wants=` — soft dependency; failure of dependency does not propagate
- `After=` — ordering only (start after); does not imply dependency
- `Before=` — ordering only (start before)
- `Conflicts=` — mutually exclusive; activating one stops the other
- `BindsTo=` — like Requires but also stops this unit if dependency stops
- `PartOf=` — stop/restart propagates from dependency to this unit only
- `Requisite=` — like Requires but dependency must already be active; does not start it

### cgroup Integration
RHEL 8:
- Ships with cgroup v1 as default, cgroup v2 available but not default
- `/sys/fs/cgroup/` — v1 hierarchy with per-controller subdirs (memory, cpu, blkio…)
- `systemd.unified_cgroup_hierarchy=1` kernel cmdline enables v2 on RHEL 8

RHEL 9/10:
- cgroup v2 (unified hierarchy) is the default and only supported mode
- `/sys/fs/cgroup/` — single unified hierarchy
- All controllers (cpu, memory, io, pids) under unified tree
- `DefaultMemoryAccounting=yes`, `DefaultCPUAccounting=yes` in `/etc/systemd/system.conf`
- Delegation controlled via `Delegate=yes` in unit files

### journald Architecture
- Daemon: `systemd-journald.service`
- Binary log storage: `/var/log/journal/<machine-id>/` (persistent) or `/run/log/journal/` (volatile)
- `/etc/systemd/journald.conf` — retention, size limits, compression, rate limiting
- Key settings: `Storage=persistent`, `SystemMaxUse=`, `MaxFileSec=`, `RateLimitBurst=`
- Query: `journalctl -u <unit>`, `-k` (kernel), `-b` (this boot), `--since`, `--until`
- `journalctl --vacuum-size=500M` — trim journal to target size
- Forward to syslog: `ForwardToSyslog=yes` in journald.conf

### systemd-resolved
- DNS stub resolver listening on `127.0.0.53:53`
- Config: `/etc/systemd/resolved.conf`, per-link DNS in NetworkManager connection files
- `resolvectl status` — view per-link DNS configuration
- `/etc/resolv.conf` — symlinked to `/run/systemd/resolve/stub-resolv.conf` when resolved manages DNS
- DNSSEC validation: `DNSSEC=allow-downgrade` (default on RHEL 9)
- LLMNR and mDNS support configurable per interface

### systemd-networkd vs NetworkManager
- RHEL uses **NetworkManager** as the primary networking daemon (not systemd-networkd)
- systemd-networkd is available but unsupported for production use by Red Hat
- NetworkManager manages: Ethernet, Wi-Fi, bonds, teams, VLANs, bridges, tunnels
- Connection profiles stored in `/etc/NetworkManager/system-connections/*.nmconnection` (RHEL 8+)
- Legacy ifcfg format (`/etc/sysconfig/network-scripts/`) deprecated in RHEL 9, removed in RHEL 10

### systemd Targets (Boot Levels)
| Target | Equivalent Runlevel | Purpose |
|---|---|---|
| `poweroff.target` | 0 | System halt |
| `rescue.target` | 1 / S | Single-user, minimal |
| `multi-user.target` | 3 | Multi-user, no GUI |
| `graphical.target` | 5 | Multi-user with display manager |
| `reboot.target` | 6 | Reboot |
| `emergency.target` | — | Minimal shell, root filesystem read-only |

- `systemctl get-default` — view default target
- `systemctl set-default multi-user.target` — set default
- `systemctl isolate rescue.target` — switch to target immediately

### Other systemd Components
- **logind** (`systemd-logind.service`): seat, session, and user management; controls `/dev/input`, power key handling; config `/etc/systemd/logind.conf`
- **tmpfiles** (`systemd-tmpfiles`): creates/removes/cleans temporary files at boot; config in `/usr/lib/tmpfiles.d/` and `/etc/tmpfiles.d/`; `systemd-tmpfiles --clean`, `--create`
- **sysctl** (`systemd-sysctl.service`): applies kernel parameters at boot; config in `/etc/sysctl.d/*.conf`, `/usr/lib/sysctl.d/`; runtime: `sysctl -w net.ipv4.ip_forward=1`
- **coredump** (`systemd-coredump`): captures crash dumps; stored in `/var/lib/systemd/coredump/`; `coredumpctl list`, `coredumpctl debug` (opens gdb)

---

## 3. Package Management — dnf / rpm

### RPM Package Format
- Binary RPM (`.rpm`): CPIO archive with header metadata (name, version, release, arch, dependencies, scripts)
- Source RPM (`.src.rpm`): spec file + original sources; used to rebuild
- Key metadata fields: `Name`, `Version`, `Release`, `Epoch`, `Arch`, `Provides`, `Requires`, `Conflicts`, `Obsoletes`
- GPG signature verification: `rpm -K <package.rpm>`, `rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release`
- Database: `/var/lib/rpm/` (BerkeleyDB in RHEL 8, SQLite in RHEL 9+)
- `rpm -qa` — list all installed; `rpm -qf /path/to/file` — which package owns file

### dnf Architecture
- dnf (Dandified YUM) is the default package manager from RHEL 8 onward
- **libdnf**: core C++ library; handles repo metadata, transaction solving, RPM interaction
- **hawkey**: dependency solver built into libdnf; uses SAT-solver (libsolv)
- **modulemd**: library for parsing module metadata YAML (used for Application Streams)
- **libdnf5** (RHEL 10): full rewrite; `dnf5` command replaces `dnf`; faster resolution, plugin API changes
- Plugin directory: `/usr/lib/python3.x/site-packages/dnf-plugins/`
- Config: `/etc/dnf/dnf.conf` — `[main]` section (keepcache, installonly_limit, best, skip_broken)
- Cache: `/var/cache/dnf/` — repomd.xml, primary.xml.gz, filelists

### Repository Configuration
- Repo files: `/etc/yum.repos.d/*.repo`
- Key directives per repo stanza:
  ```
  [repo-id]
  name=Human readable name
  baseurl=https://cdn.redhat.com/content/...    # direct URL
  metalink=https://...                           # mirror list (checksum-verified)
  enabled=1
  gpgcheck=1
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
  sslverify=1
  sslclientcert=/etc/pki/entitlement/<id>.pem   # entitlement cert
  sslclientkey=/etc/pki/entitlement/<id>-key.pem
  ```
- Priority is not natively supported; use `excludepkgs=` or module streams to control versions

### dnf Module Streams (RHEL 8 and 9 only — removed in RHEL 10)
- Application Streams allow multiple versions of software (e.g., Python 3.6, 3.8, 3.9)
- A **module** groups packages for a technology stack; a **stream** is a version track
- Each module has a default stream; only one stream active at a time per module
- `dnf module list` — list available modules
- `dnf module enable nodejs:18` — enable stream
- `dnf module install nodejs:18/common` — install specific profile
- `dnf module reset nodejs` — reset to default stream
- Module metadata stored as `modules.yaml` in repo
- RHEL 10 removes modules entirely; versions managed via standard repos + package naming

### Application Streams: BaseOS vs AppStream
- **BaseOS repo**: core OS packages with long lifecycle (OS lifetime); RPM-format only
- **AppStream repo**: application packages, tools, runtimes; shorter lifecycle than BaseOS; includes both RPMs and modules
- Both repos enabled by default on subscribed RHEL systems
- `dnf repolist` — confirm both repos present
- Additional repos: CodeReady Linux Builder (CRB/PowerTools) — devel packages for building; not for production install

### rpm-ostree (Image Mode)
- Transactional, image-based package management layered on OSTree
- Used in RHEL for Edge and RHEL 10 Image Mode (bootc)
- `rpm-ostree status` — view current and staged deployments
- `rpm-ostree upgrade` — fetch and stage new base image
- `rpm-ostree install <pkg>` — layer additional packages on top of base image
- `rpm-ostree rollback` — revert to previous deployment
- Changes require reboot to take effect (transactional)

### Weak and Rich Dependencies
- **Weak dependencies** (RPM 4.12+):
  - `Recommends:` — installed by default unless explicitly excluded
  - `Suggests:` — informational, not installed automatically
  - `Supplements:` — pulled in if another package is present
  - `Enhances:` — informational for reverse supplements
- **Rich dependencies** (RPM 4.12+): Boolean logic in dep expressions
  - `Requires: (pkgA or pkgB)` — either satisfies
  - `Requires: (pkgA and pkgB)` — both required
  - `Requires: (pkgA if pkgB)` — conditional

### dnf Groups and Environments
- Groups bundle related packages for a functional purpose
- `dnf group list` — list available groups
- `dnf group install "Development Tools"` — install group
- `dnf group info "Server with GUI"` — view group members
- Environments group multiple groups (e.g., "Minimal Install", "Server with GUI")
- `dnf groupremove` — uninstall all group packages not required elsewhere

---

## 4. Subscription Model

### Red Hat Subscription Manager (subscription-manager)
- CLI tool managing entitlement certificates and repo access
- `subscription-manager register --username=<u> --password=<p>` — register system to RHSM
- `subscription-manager register --org=<id> --activationkey=<key>` — preferred automated method
- `subscription-manager status` — view subscription status
- `subscription-manager list --available` — list attachable subscriptions
- `subscription-manager attach --auto` — auto-attach best-matching subscription
- `subscription-manager repos --list` — list available repos
- `subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms` — enable repo
- Entitlement certs stored: `/etc/pki/entitlement/` (cert + key pairs)
- Consumer identity cert: `/etc/pki/consumer/cert.pem`

### Simple Content Access (SCA) Mode
- SCA (enabled by default from 2022 onward on new accounts) removes entitlement attachment requirement
- With SCA enabled: all repos the account is entitled to are accessible without attaching specific subscriptions
- `subscription-manager simple-content-access status` — check SCA status
- Systems still need to be registered; SCA removes the `attach` step
- Usage still tracked for capacity reporting but does not gate access

### Red Hat CDN
- All repo content served from `cdn.redhat.com` over HTTPS
- Entitlement certificates authenticate the client to the CDN (mutual TLS)
- Geographic content mirrors; metalink provides mirror selection with checksum verification
- GPG-signed package metadata and packages; verified by dnf automatically

### Red Hat Satellite
- On-premises content mirror and lifecycle management platform
- Syncs content from Red Hat CDN to internal network
- Provides content views (snapshots of repo state), lifecycle environments, activation keys
- Manages subscription assignment at scale via organizations and locations
- Systems connect to Satellite instead of CDN: `subscription-manager register --org --activationkey` pointing to Satellite FQDN
- Foreman (upstream) provides provisioning; Katello provides content management
- Port 443 from managed hosts to Satellite; Satellite to CDN for sync

### Red Hat Insights Client
- `insights-client` — lightweight agent sending system configuration/telemetry to Red Hat Insights SaaS
- Registration: `insights-client --register` (also called during `subscription-manager register` with `--insights`)
- Provides: drift analysis, CVE exposure, advisor recommendations, patch planning, malware detection
- Config: `/etc/insights-client/insights-client.conf`
- Does NOT send logs or file contents by default; sends RPM list, system config metadata

---

## 5. Filesystem Layout

### FHS Compliance
RHEL follows Filesystem Hierarchy Standard with Red Hat extensions:
- `/etc/` — host-specific configuration
- `/usr/` — shareable, read-only data (binaries, libraries, documentation)
- `/var/` — variable data (logs, spool, cache)
- `/run/` — transient runtime data (replaces parts of `/var/run`)
- `/boot/` — kernel, initramfs, GRUB files
- `/home/` — user home directories
- `/opt/` — third-party application trees
- `/srv/` — service data

Key RHEL specifics:
- `/usr/bin/` and `/bin/` — merged (symlink `/bin -> /usr/bin`)
- `/usr/lib/` and `/lib/` — merged (symlink `/lib -> /usr/lib`)
- `/usr/sbin/` and `/sbin/` — merged (symlink `/sbin -> /usr/sbin`)
- `/etc/sysconfig/` — RHEL-specific legacy configuration directory (network, selinux, iptables...)

### XFS as Default Filesystem
- XFS is the default for root and data partitions since RHEL 7
- Features: journaling, online resize (grow only — shrink not supported), 64-bit inodes, project quotas
- Tools: `xfs_repair`, `xfsdump`, `xfsrestore`, `xfs_info`, `xfs_admin`
- Quota: `xfs_quota -x -c 'limit bsoft=1g bhard=2g user1' /data`
- Max filesystem size: 1 PiB (x86_64)
- ext4 remains available and supported but not default; `mkfs.ext4`, `e2fsck`

### Stratis Storage Management
- RHEL 8.3+ native thin-provisioning and snapshot storage manager
- Architecture: pool (block devices) → filesystem (XFS formatted, mounted)
- Daemon: `stratisd.service`; CLI: `stratis`
- `stratis pool create mypool /dev/sdb` — create pool
- `stratis filesystem create mypool myfs` — create thinly provisioned XFS filesystem
- `stratis filesystem snapshot mypool myfs myfs-snap` — create snapshot
- `stratis pool add-cache mypool /dev/sdc` — add cache tier (NVMe/SSD)
- Filesystems mounted via `/etc/fstab` with `x-systemd.requires=stratisd.service`
- Default mount: `/stratis/<pool>/<filesystem>/`
- Does not support shrink; grows automatically from pool space

### LVM Architecture
- Standard: Physical Volumes (PVs) → Volume Groups (VGs) → Logical Volumes (LVs)
- `pvcreate /dev/sdb` — initialize PV
- `vgcreate vg_data /dev/sdb /dev/sdc` — create VG
- `lvcreate -L 50G -n lv_data vg_data` — create LV
- `lvextend -L +10G /dev/vg_data/lv_data && xfs_growfs /mountpoint` — online extend
- Thin provisioning: `lvcreate --thin vg_data/pool_thin -V 100G -n lv_thin`
- Snapshots: `lvcreate -s -n snap -L 10G /dev/vg_data/lv_data`
- Config: `/etc/lvm/lvm.conf` — filter, metadata areas, global settings
- `lvmconfig --type diff` — show non-default settings

### Device Mapper
- Kernel framework underlying LVM, dm-crypt (LUKS), multipath, and Stratis
- `/dev/mapper/<name>` — device mapper device nodes
- `dmsetup ls`, `dmsetup info <name>` — inspect dm devices
- dm-crypt: LUKS2 (default in RHEL 8+) encryption layer; `cryptsetup luksFormat`, `luksOpen`
- dm-multipath: multiple paths to SAN storage; `mpathconf`, `multipath -ll`

### VDO (Virtual Data Optimizer)
- RHEL 8: VDO as standalone device mapper target (`vdo create --name=vdo0 --device=/dev/sdb --vdoLogicalSize=1T`)
- RHEL 9+: VDO merged into LVM as `lvcreate --type vdo`; standalone vdo command removed
- Provides: deduplication (4K block-level), compression (LZ4), thin provisioning
- `vdostats --human-readable` — view deduplication/compression ratios (RHEL 8)
- RHEL 9: `lvs -o+vdo_saving` — equivalent statistics via LVM

---

## 6. Networking Stack

### NetworkManager
Primary networking daemon on all RHEL versions:
- `nmcli` — scriptable CLI; `nmtui` — text UI
- `nmcli device status` — list interfaces
- `nmcli connection show` — list connection profiles
- `nmcli connection add type ethernet ifname eth0 con-name myconn ipv4.addresses 192.168.1.10/24 ipv4.gateway 192.168.1.1 ipv4.dns 8.8.8.8 ipv4.method manual`
- `nmcli connection up myconn`
- Connection profile storage:
  - RHEL 8: `/etc/sysconfig/network-scripts/ifcfg-*` (legacy) or `/etc/NetworkManager/system-connections/`
  - RHEL 9: keyfile format in `/etc/NetworkManager/system-connections/*.nmconnection` (default)
  - RHEL 10: ifcfg format removed; keyfile only
- `/etc/NetworkManager/NetworkManager.conf` — global daemon config
- `nmcli general logging level DEBUG domains ALL` — enable debug logging

### firewalld
Zone-based host firewall using nftables backend:
- Zones define trust level for network interfaces/sources: `drop`, `block`, `public`, `external`, `internal`, `dmz`, `work`, `home`, `trusted`
- Default zone applied to interfaces without explicit zone assignment
- `firewall-cmd --get-default-zone`
- `firewall-cmd --zone=public --add-service=https --permanent`
- `firewall-cmd --zone=public --add-port=8080/tcp --permanent`
- `firewall-cmd --reload` — apply permanent rules
- Rich rules: `firewall-cmd --zone=public --add-rich-rule='rule family=ipv4 source address=10.0.0.0/8 service name=ssh accept'`
- Runtime vs permanent: `--permanent` writes to `/etc/firewalld/zones/`; without writes to runtime only
- Config: `/etc/firewalld/firewalld.conf`, zone XMLs in `/etc/firewalld/zones/` and `/usr/lib/firewalld/zones/`
- Services defined in `/usr/lib/firewalld/services/*.xml` (system) and `/etc/firewalld/services/` (custom)

### nftables Backend
- RHEL 8: firewalld uses nftables backend; legacy `iptables` commands redirected via `iptables-nft` compatibility layer
- RHEL 9+: `iptables` package removed; only `nftables` and `iptables-nft` wrapper remain
- `nft list ruleset` — view all nftables rules
- `nft list tables` — list tables
- Direct nftables use alongside firewalld: use `firewalld`'s direct rules or custom tables not managed by firewalld
- `/etc/nftables/` — custom nftables config if managing directly

### IP Command Suite
- `iproute2` package: `ip`, `ss`, `tc`, `bridge`
- `ip addr show` — interface addresses
- `ip route show` — routing table
- `ip link set eth0 up/down` — bring interface up/down
- `ss -tulnp` — listening sockets with process info (replaces `netstat`)
- `tc qdisc show dev eth0` — traffic control queuing disciplines

### Network Namespaces
- Isolate network stack (interfaces, routes, firewall rules) per namespace
- `ip netns add <name>` — create namespace
- `ip netns exec <name> ip link list` — run command in namespace
- Used by: containers (Podman/OCI), OpenShift networking, VRF (Virtual Routing and Forwarding)

### Bonding vs Teaming
- **Bonding**: kernel-native driver; modes 0-6 (round-robin, active-backup, LACP, etc.)
  - `nmcli connection add type bond ifname bond0 bond.options "mode=active-backup"`
  - Config via NM or `/etc/modprobe.d/bonding.conf`
- **Teaming**: userspace daemon (`teamd`) with JSON runner config; deprecated in RHEL 9, removed in RHEL 10
  - RHEL 10: only bonding supported for link aggregation
- VLAN: `nmcli connection add type vlan ifname eth0.100 dev eth0 id 100`
- Bridge: `nmcli connection add type bridge ifname br0`

---

## 7. Security Framework

### PAM Stack
- Pluggable Authentication Modules control authentication, account management, session setup, password policies
- Config: `/etc/pam.d/` — per-service config files; `/etc/pam.d/system-auth` and `password-auth` are central
- Common modules: `pam_unix` (local), `pam_sss` (sssd), `pam_faillock` (lockout), `pam_pwquality` (complexity), `pam_limits` (resource limits)
- `authselect` (RHEL 8+) manages PAM and nsswitch configuration as profiles:
  - `authselect select sssd` — configure for sssd-based auth
  - `authselect select sssd with-mkhomedir with-faillock` — add optional features
  - `authselect current` — show active profile
  - Profile files: `/etc/authselect/`, `/usr/share/authselect/profiles/`

### sssd (System Security Services Daemon)
- Single daemon providing: identity lookup (NSS), authentication (PAM), group membership, Kerberos ticket management, offline caching
- Backends: Active Directory (ad provider), LDAP, Kerberos, FreeIPA (ipa provider)
- Config: `/etc/sssd/sssd.conf` (mode 0600, owned root:root)
- `realm join AD.EXAMPLE.COM` — auto-configures sssd for AD join (uses `realmd`)
- `sssctl user-checks <user>` — test user resolution and auth
- `sssctl cache-expire -a` — clear sssd cache
- Offline caching: credentials cached for configurable duration; `offline_credentials_expiration`
- `/var/log/sssd/sssd_<domain>.log` — per-domain logs

### System-Wide Crypto Policies
- Central mechanism to set cryptographic defaults across OpenSSL, GnuTLS, NSS, Java, libssh, Kerberos
- Policies: `DEFAULT`, `FUTURE`, `LEGACY`, `FIPS`
- `update-crypto-policies --set FUTURE` — raise policy
- `update-crypto-policies --show` — current policy
- Policy files: `/usr/share/crypto-policies/policies/` and `/etc/crypto-policies/back-ends/` (generated)
- Custom policy: `/etc/crypto-policies/policies/modules/*.pmod` — override specific algorithms
- `update-crypto-policies --set DEFAULT:NO-SHA1` — apply module override

### FIPS 140 Mode
- `fips-mode-setup --enable` — enable FIPS (requires reboot)
- Kernel cmdline adds `fips=1`; initramfs regenerated
- `/proc/sys/crypto/fips_enabled` — runtime check (1 = enabled)
- FIPS restricts: key sizes, algorithms (no MD5, RC4, 3DES below certain configs), RNG requirements
- RHEL is FIPS 140-2/140-3 validated for specific versions

### auditd
- Kernel audit framework for syscall and file access logging
- `auditd.service` — userspace daemon
- Rules: `/etc/audit/rules.d/*.rules`; compiled to `/etc/audit/audit.rules` by `augenrules`
- `auditctl -l` — list active rules
- Log: `/var/log/audit/audit.log`
- `ausearch -k <key> -i` — search by rule key, interpret fields
- `aureport --summary` — high-level audit summary
- Pre-built rule sets: `/usr/share/audit/sample-rules/` (PCI-DSS, STIG, OSPP)
- `auditctl -w /etc/passwd -p wa -k passwd_changes` — watch file for writes/attribute changes

### AIDE (Advanced Intrusion Detection Environment)
- File integrity monitoring via checksums
- Config: `/etc/aide.conf` — specifies directories and attributes to monitor
- `aide --init` — build initial database (`/var/lib/aide/aide.db.new.gz`)
- `aide --check` — compare current state to database
- Typical use: run `--init` after fresh install; schedule `--check` via cron or systemd timer

---

## 8. Boot Process

### GRUB2
- Bootloader for both BIOS/MBR and UEFI systems
- BIOS: first-stage in MBR; core image in `/boot/grub2/`
- UEFI: EFI binary at `/boot/efi/EFI/redhat/grubx64.efi`
- Main config: `/boot/grub2/grub.cfg` (BIOS) or `/boot/efi/EFI/redhat/grub.cfg` (UEFI) — auto-generated, do not edit directly
- BLS (Boot Loader Specification) entries (RHEL 8+): `/boot/loader/entries/*.conf` — one file per kernel, human-readable
  ```
  title Red Hat Enterprise Linux (5.14.0-427.el9.x86_64) 9.4
  linux /vmlinuz-5.14.0-427.el9.x86_64
  initrd /initramfs-5.14.0-427.el9.x86_64.img
  options root=/dev/mapper/rhel-root ro crashkernel=auto rd.lvm.lv=rhel/root quiet
  ```
- `grub2-mkconfig -o /boot/grub2/grub.cfg` — regenerate from BLS entries + `/etc/default/grub`
- `/etc/default/grub` — editable settings: `GRUB_TIMEOUT`, `GRUB_CMDLINE_LINUX`
- `grubby --update-kernel=ALL --args="quiet"` — modify kernel args across all entries

### dracut (initramfs)
- Modular framework for building initramfs images
- `dracut --force /boot/initramfs-$(uname -r).img $(uname -r)` — rebuild initramfs
- Modules in `/usr/lib/dracut/modules.d/`; local overrides in `/etc/dracut.conf.d/`
- `dracut --list-modules` — available modules
- Early userspace: mounts root filesystem, activates LVM/LUKS/network before pivoting to real root
- Emergency shell: `rd.break` kernel parameter drops to shell in initramfs before pivot

### Kernel Command Line Parameters
Key RHEL-relevant parameters:
- `rd.lvm.lv=<vg/lv>` — activate specific LV during boot
- `rd.luks.uuid=<uuid>` — unlock LUKS device
- `rd.break=pre-mount` — drop to dracut emergency shell
- `systemd.unit=rescue.target` — boot to rescue mode
- `crashkernel=auto` — kdump reserved memory
- `selinux=0` or `enforcing=0` — SELinux control
- `fips=1` — enable FIPS mode
- `quiet` / `rhgb` — suppress boot messages / graphical boot

### UEFI Secure Boot
- RHEL signed shim (`shim.efi`) is first UEFI executable; verified by Microsoft certificate in UEFI DB
- Shim verifies Red Hat's second-stage bootloader (grubx64.efi) using embedded Red Hat certificate
- GRUB2 verifies kernel signature; kernel verifies module signatures
- `mokutil --sb-state` — check Secure Boot status
- Machine Owner Keys (MOK): `mokutil --import cert.cer` — enroll custom signing cert
- Third-party kernel modules must be signed with a key enrolled in MOK or Red Hat's keyring
- `pesign` / `sbsign` — tools for signing EFI binaries and kernel modules

### Measured Boot
- TPM 2.0 extends boot component hashes into PCR (Platform Configuration Registers) during boot
- Each stage (firmware, shim, GRUB, kernel, initramfs, cmdline) measured into specific PCRs
- `tpm2-tools`: `tpm2_pcrread` — read PCR values
- Integration with LUKS: Tang/Clevis `tang`+`clevis-luks-tang` for network-bound disk encryption using TPM PCRs
- `systemd-cryptenroll` (RHEL 9+): enroll TPM2 into LUKS keyslots — `systemd-cryptenroll --tpm2-device=auto /dev/sda2`

---

## 9. Cockpit Web Console

### Architecture
- Three-tier: browser (React JS SPA) ↔ `cockpit-ws` (WebSocket gateway) ↔ `cockpit-bridge` (per-session process on managed host)
- `cockpit-ws`: listens on port 9090 (HTTPS); handles TLS, authentication, WebSocket upgrade
- `cockpit-bridge`: runs as the authenticated user; executes privileged operations via sudo/polkit; communicates with system DBus
- Single systemd socket-activated service: `cockpit.socket` activates `cockpit.service`
- `systemctl enable --now cockpit.socket` — enable Cockpit

### Plugin Model
- Each Cockpit plugin is a directory of HTML/JS/CSS + a `manifest.json` declaring its position in the UI
- Plugin locations: `/usr/share/cockpit/<plugin>/` (system), `/etc/cockpit/<plugin>/` (local override)
- `manifest.json` declares: menu entries, dashboard contributions, required cockpit version
- Packages installed via RPM (e.g., `cockpit-storaged`, `cockpit-podman`, `cockpit-machines`)

### Authentication
- PAM authentication via `cockpit-ws`; uses `/etc/pam.d/cockpit`
- SSO: Kerberos (negotiate authentication) when joined to AD/FreeIPA domain
- Certificate authentication: client TLS certificates mapped to users
- Session keys generated per session; `cockpit-bridge` does not store credentials

### Available Modules
| Package | Module | Capabilities |
|---|---|---|
| `cockpit` | System | Overview, CPU/mem/disk/net graphs, hostname, time, shutdown |
| `cockpit-storaged` | Storage | Disks, LVM, RAID, LUKS, NFS, Stratis |
| `cockpit-networkmanager` | Networking | NM connections, bonds, VLANs, firewall |
| `cockpit` | Services | systemd unit management, journal view |
| `cockpit` | Logs | journald query UI |
| `cockpit` | Terminal | In-browser terminal (PTY via bridge) |
| `cockpit-machines` | Virtual Machines | libvirt/KVM VM management |
| `cockpit-podman` | Podman | Container management |
| `cockpit-pcp` | Metrics | PCP (Performance Co-Pilot) historical graphs |
| `cockpit-composer` | Image Builder | Build system images via osbuild |

- TLS cert: `/etc/cockpit/ws-certs.d/` — drop PEM cert+key here; auto-detected
- Firewall: `firewall-cmd --add-service=cockpit --permanent` — pre-defined service (port 9090)

---

## 10. Image Mode / rpm-ostree / bootc (RHEL 10)

### Image-Based Deployment Model
- RHEL 10 introduces **Image Mode** as an equal deployment model alongside traditional package mode
- System image = bootable OCI container image built with standard container tools
- Images are immutable at runtime; updates are atomic (full image swap, not package delta)
- Based on the `bootc` (Boot Container) technology

### bootc Architecture
- `bootc` is the client tool for managing bootable OCI container deployments
- `bootc upgrade` — check and apply image updates (pulls new image, stages for next boot)
- `bootc switch quay.io/myorg/rhel10-custom:latest` — switch to different image
- `bootc status` — show current, staged, and rollback image
- `bootc rollback` — revert to previous image (no reboot required for staging, reboot to apply)
- Underlying storage: OSTree for filesystem layout versioning; OCI layers map to OSTree commits
- `/sysroot/ostree/` — OSTree repository on deployed systems

### Bootable OCI Container Build
- Start from `registry.redhat.io/rhel10/rhel-bootc:10`
- Standard Containerfile:
  ```dockerfile
  FROM registry.redhat.io/rhel10/rhel-bootc:10
  RUN dnf install -y httpd && dnf clean all
  COPY my-app.conf /etc/httpd/conf.d/
  RUN systemctl enable httpd
  ```
- Build: `podman build -t myorg/rhel10-web:1.0 .`
- Push: `podman push myorg/rhel10-web:1.0`
- Convert to disk image: `bootc image to-disk --type qcow2 myorg/rhel10-web:1.0 output.qcow2`
- `image-builder` / `osbuild` integration for producing ISO, AMI, VMDK from bootc images

### rpm-ostree vs Traditional Package Management
| Aspect | Traditional dnf | rpm-ostree / bootc |
|---|---|---|
| Mutability | Fully mutable at runtime | Immutable base; layered packages allowed |
| Rollback | Manual (snapshot/backup) | Built-in; previous deployment preserved |
| Updates | In-place package delta | Full image pull; atomic switch on reboot |
| Customization | Any package, any time | Base image in Containerfile; layers for ad-hoc |
| Boot integrity | No built-in verification | OSTree content-addressed; hash-verified |
| Config drift | Common over time | Eliminated by image re-pulls |

### Soft Reboot (Userspace Reboot)
- `systemctl soft-reboot` — restarts userspace without firmware/bootloader/kernel reload
- Useful for applying image updates faster when kernel is unchanged
- systemd shuts down all services, unmounts filesystems, exec's new init without firmware cycle
- `bootc upgrade` followed by `systemctl soft-reboot` — sub-60s update cycle if kernel unchanged

### Container Registry Management
- Images hosted on OCI-compliant registries: `registry.redhat.io` (official), Quay.io, private registries
- `/etc/containers/registries.conf` — configure trusted registries, mirrors, unqualified-search registries
- `skopeo inspect docker://registry.redhat.io/rhel10/rhel-bootc:10` — inspect image without pulling
- Signature verification: `sigstore` or simple signing with `cosign`; `/etc/containers/policy.json` governs trust
- Pull-through caching: deploy a Quay.io mirror or `zot` registry on-premises for air-gapped deployments

---

## Quick Reference: Key Config File Locations

| Subsystem | Key Files / Directories |
|---|---|
| Kernel modules | `/etc/modules-load.d/`, `/etc/modprobe.d/` |
| systemd units | `/usr/lib/systemd/system/` (vendor), `/etc/systemd/system/` (admin override) |
| journald | `/etc/systemd/journald.conf`, `/var/log/journal/` |
| dnf | `/etc/dnf/dnf.conf`, `/etc/yum.repos.d/*.repo` |
| Subscriptions | `/etc/pki/entitlement/`, `/etc/pki/consumer/cert.pem` |
| NetworkManager | `/etc/NetworkManager/system-connections/`, `/etc/NetworkManager/NetworkManager.conf` |
| firewalld | `/etc/firewalld/firewalld.conf`, `/etc/firewalld/zones/` |
| nftables | `/etc/nftables.conf` |
| GRUB2 | `/etc/default/grub`, `/boot/loader/entries/`, `/boot/grub2/grub.cfg` |
| dracut | `/etc/dracut.conf.d/` |
| PAM / authselect | `/etc/pam.d/`, `/etc/authselect/` |
| sssd | `/etc/sssd/sssd.conf`, `/var/log/sssd/` |
| Crypto policies | `/etc/crypto-policies/`, `/usr/share/crypto-policies/policies/` |
| auditd | `/etc/audit/rules.d/`, `/var/log/audit/audit.log` |
| AIDE | `/etc/aide.conf`, `/var/lib/aide/` |
| LVM | `/etc/lvm/lvm.conf` |
| Cockpit | `/etc/cockpit/`, `/usr/share/cockpit/`, `/etc/cockpit/ws-certs.d/` |
| bootc | `/etc/containers/registries.conf`, `/etc/containers/policy.json`, `/sysroot/ostree/` |
