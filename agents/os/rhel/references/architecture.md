# RHEL Architecture Reference

## 1. Kernel

### Kernel Versions

| RHEL | Kernel Base | Released |
|------|-------------|----------|
| 8    | 4.18        | May 2019 |
| 9    | 5.14        | May 2022 |
| 10   | 6.12        | May 2025 |

RHEL ships a single kernel version per major release. Minor updates deliver security patches and backported features into the same kernel base -- never a new upstream kernel.

### Backporting and kABI

Red Hat selectively backports features from newer upstream kernels. The kABI (Kernel ABI) guarantee ensures binary kernel modules compiled against the initial major release continue to work across all minor updates. kABI-stable symbols are whitelisted in `/usr/src/kernels/<version>/Module.symvers`.

- `kernel-abi-whitelists` package documents the allowed symbol set
- Third-party drivers certified against kABI work across minor releases without recompilation
- Driver Update Programs (DUPs) allow modules to ship outside the main kernel RPM
- Module loading: `/etc/modules-load.d/` for persistent, `/etc/modprobe.d/` for parameters

### kernel-rt (Real-Time)

Separate package set for deterministic latency (telecoms, NFV, finance). Based on PREEMPT_RT patchset. Requires `realtime` or `nfv` subscription add-on (RHEL 8/9).

### kpatch (Live Patching)

Applies kernel security patches without rebooting via ftrace function replacement. Patches are cumulative per kernel version. Service: `kpatch.service`. Storage: `/var/lib/kpatch/`. Requires separate entitlement.

---

## 2. systemd Architecture

### Unit Types

| Type | Purpose | Example |
|------|---------|---------|
| `.service` | Daemon lifecycle | `sshd.service` |
| `.socket` | Socket-activated trigger | `cockpit.socket` |
| `.timer` | Calendar/monotonic scheduling | `dnf-makecache.timer` |
| `.mount` | Filesystem mount | `boot.mount` |
| `.target` | Synchronization point | `multi-user.target` |
| `.slice` | cgroup resource node | `system.slice` |
| `.path` | File/directory watcher | `cups.path` |
| `.device` | udev device node | `dev-sda1.device` |

### Dependency Keywords

- `Requires=` / `BindsTo=` -- hard dependency (failure propagates)
- `Wants=` -- soft dependency (failure does not propagate)
- `After=` / `Before=` -- ordering only
- `Conflicts=` -- mutually exclusive
- `PartOf=` -- stop/restart propagates from parent

### cgroup Integration

- RHEL 8: cgroup v1 default; v2 available via `systemd.unified_cgroup_hierarchy=1`
- RHEL 9/10: cgroup v2 (unified hierarchy) is default and only supported mode
- All controllers (cpu, memory, io, pids) under unified tree at `/sys/fs/cgroup/`

### journald

Binary structured logs. Daemon: `systemd-journald.service`. Storage: `/var/log/journal/` (persistent) or `/run/log/journal/` (volatile). Config: `/etc/systemd/journald.conf`. Key settings: `Storage=persistent`, `SystemMaxUse=`, `MaxFileSec=`, `RateLimitBurst=`.

### systemd-resolved

DNS stub resolver on `127.0.0.53:53`. Config: `/etc/systemd/resolved.conf`. Status: `resolvectl status`. RHEL uses NetworkManager as primary networking daemon, not systemd-networkd.

### Targets (Boot Levels)

| Target | Equivalent | Purpose |
|--------|------------|---------|
| `poweroff.target` | 0 | Halt |
| `rescue.target` | 1/S | Single-user |
| `multi-user.target` | 3 | No GUI |
| `graphical.target` | 5 | Display manager |
| `emergency.target` | -- | Minimal shell, read-only root |

### Other Components

- **logind**: seat/session/user management; `/etc/systemd/logind.conf`
- **tmpfiles**: creates/removes temp files at boot; `/etc/tmpfiles.d/`
- **sysctl**: kernel parameters at boot; `/etc/sysctl.d/*.conf`
- **coredump**: crash dump capture; `coredumpctl list`, `coredumpctl debug`

---

## 3. Package Management (dnf / rpm)

### RPM Format

Binary RPM: CPIO archive with metadata (name, version, release, arch, dependencies). Database: BerkeleyDB in RHEL 8, SQLite in RHEL 9+. GPG verification: `rpm -K <package.rpm>`.

### dnf Architecture

- **libdnf**: core C++ library for repo metadata and transaction solving (SAT-solver via libsolv)
- **libdnf5** (RHEL 10): full rewrite; `dnf5` replaces `dnf`
- Config: `/etc/dnf/dnf.conf`; cache: `/var/cache/dnf/`
- Plugin directory: `/usr/lib/python3.x/site-packages/dnf-plugins/`

### Repository Configuration

Files in `/etc/yum.repos.d/*.repo` with `baseurl`, `metalink`, `gpgcheck`, `sslclientcert` directives. Entitlement certificates authenticate to Red Hat CDN via mutual TLS.

### Module Streams (RHEL 8/9 Only)

Application Streams allow multiple versions of software. A module groups packages; a stream is a version track. Only one stream active per module. `dnf module list`, `enable`, `install`, `reset`. RHEL 10 removes modules entirely -- versions managed via standard versioned package names.

### BaseOS vs AppStream

- **BaseOS**: core OS packages with long lifecycle (full RHEL lifetime); RPM-format only
- **AppStream**: application packages with shorter lifecycle; includes RPMs and modules
- Additional: CodeReady Linux Builder (CRB) for build dependencies (not production)

### rpm-ostree / bootc (Image Mode)

Transactional image-based package management. Used in RHEL for Edge and RHEL 10 Image Mode. `bootc status`, `bootc upgrade`, `bootc rollback`. Changes require reboot.

---

## 4. Subscription Model

### subscription-manager

CLI for entitlement certificates and repo access. Registration: `subscription-manager register --org=<id> --activationkey=<key>`. Entitlement certs in `/etc/pki/entitlement/`. Consumer identity: `/etc/pki/consumer/cert.pem`.

### Simple Content Access (SCA)

Default from 2022+. Removes entitlement attachment requirement -- all entitled repos accessible org-wide. Systems still must be registered. Usage tracked for capacity but does not gate access.

### Red Hat CDN

All content served from `cdn.redhat.com` over HTTPS. Entitlement certs authenticate via mutual TLS. GPG-signed packages and metadata.

### Red Hat Satellite

On-premises content mirror with Content Views (repo snapshots), Lifecycle Environments (Dev/QA/Prod), activation keys. Systems connect to Satellite instead of CDN.

### Insights Client

Lightweight agent sending system config metadata to Red Hat Insights SaaS. Registration: `insights-client --register`. Provides drift analysis, CVE exposure, advisor recommendations, patch planning.

---

## 5. Filesystem Layout

### FHS with Red Hat Extensions

- `/usr/bin/` and `/bin/` merged (symlink)
- `/usr/lib/` and `/lib/` merged (symlink)
- `/etc/sysconfig/` -- RHEL-specific legacy configuration

### XFS (Default Filesystem)

Default since RHEL 7. Journaling, online resize (grow only), 64-bit inodes, project quotas. Max size: 1 PiB. Tools: `xfs_repair`, `xfs_info`, `xfs_growfs`, `xfs_quota`.

### Stratis Storage (RHEL 8+)

Pool-based thin provisioning. Architecture: pool (block devices) -> filesystem (XFS). Daemon: `stratisd.service`. Supports snapshots and cache tiers (NVMe/SSD). Mount with `x-systemd.requires=stratisd.service` in fstab.

### LVM

Standard PV/VG/LV model. Thin provisioning: `lvcreate --thin`. Snapshots: `lvcreate -s`. Config: `/etc/lvm/lvm.conf`. View non-defaults: `lvmconfig --type diff`.

### Device Mapper

Kernel framework underlying LVM, dm-crypt (LUKS2), multipath, Stratis. Nodes at `/dev/mapper/`.

### VDO (Virtual Data Optimizer)

Deduplication, compression, thin provisioning. RHEL 8: standalone (`vdo create`). RHEL 9+: merged into LVM as `lvcreate --type vdo`.

---

## 6. Networking Stack

### NetworkManager

Primary networking daemon. CLI: `nmcli`; text UI: `nmtui`. Connection profile storage:
- RHEL 8: ifcfg (`/etc/sysconfig/network-scripts/`) or keyfile
- RHEL 9: keyfile (default); ifcfg deprecated
- RHEL 10: keyfile only; ifcfg removed

### firewalld

Zone-based host firewall using nftables backend. Zones: `drop`, `block`, `public`, `internal`, `trusted`, `dmz`. Config: `/etc/firewalld/`. Services: `/usr/lib/firewalld/services/` (system), `/etc/firewalld/services/` (custom).

### nftables

- RHEL 8: nftables backend; `iptables-nft` compatibility layer
- RHEL 9+: iptables package removed; only nftables and `iptables-nft` wrapper
- Direct: `nft list ruleset`, `nft add rule`

### Bonding and Teaming

- **Bonding**: kernel-native (modes 0-6); supported on all versions
- **Teaming**: userspace daemon (`teamd`); deprecated in RHEL 9, removed in RHEL 10
- VLAN: `nmcli connection add type vlan`
- Bridge: `nmcli connection add type bridge`

---

## 7. Security Framework

### SELinux

Mandatory access control. Modes: Enforcing (default), Permissive, Disabled. Policy: `targeted` (default). Tools: `sestatus`, `getenforce`, `setenforce`, `ausearch -m AVC`, `audit2why`, `sealert`, `restorecon`, `setsebool`.

### PAM Stack

Config: `/etc/pam.d/`. Key modules: `pam_unix`, `pam_sss`, `pam_faillock`, `pam_pwquality`, `pam_limits`. Managed via `authselect` profiles.

### sssd

Identity and authentication daemon. Backends: Active Directory, LDAP, Kerberos, FreeIPA. Config: `/etc/sssd/sssd.conf`. Domain join: `realm join AD.EXAMPLE.COM`.

### Crypto Policies

Central mechanism across OpenSSL, GnuTLS, NSS, Java, libssh, Kerberos. Policies: `DEFAULT`, `FUTURE`, `LEGACY`, `FIPS`. Custom modules in `/etc/crypto-policies/policies/modules/*.pmod`.

### FIPS 140 Mode

`fips-mode-setup --enable` adds `fips=1` to kernel cmdline. Verify: `/proc/sys/crypto/fips_enabled`. Restricts algorithms and key sizes.

### auditd

Kernel audit framework. Rules: `/etc/audit/rules.d/*.rules`. Log: `/var/log/audit/audit.log`. Tools: `ausearch`, `aureport`, `auditctl`.

### AIDE

File integrity monitoring. Config: `/etc/aide.conf`. Initialize: `aide --init`. Check: `aide --check`.

---

## 8. Boot Process

### GRUB2

BIOS: `/boot/grub2/grub.cfg`. UEFI: `/boot/efi/EFI/redhat/grub.cfg`. BLS entries (RHEL 8+): `/boot/loader/entries/*.conf`. Editable settings: `/etc/default/grub`. Kernel args: `grubby --update-kernel=ALL --args="quiet"`.

### dracut (initramfs)

Modular framework for building initramfs. Rebuild: `dracut --force`. Emergency shell: `rd.break` kernel parameter. Modules: `/usr/lib/dracut/modules.d/`; overrides: `/etc/dracut.conf.d/`.

### UEFI Secure Boot

Chain of trust: Microsoft cert -> shim.efi -> grubx64.efi -> kernel -> modules. Machine Owner Keys (MOK) for custom signing. Check: `mokutil --sb-state`.

### Measured Boot

TPM 2.0 extends boot component hashes into PCR registers. Integration with LUKS via Clevis/Tang for network-bound disk encryption. RHEL 9+: `systemd-cryptenroll --tpm2-device=auto`.

---

## 9. Cockpit Web Console

Three-tier architecture: browser (React SPA) <-> `cockpit-ws` (WebSocket gateway, port 9090) <-> `cockpit-bridge` (per-session process). Socket-activated: `cockpit.socket`. PAM authentication with Kerberos SSO support. TLS certs in `/etc/cockpit/ws-certs.d/`.

Plugins: `cockpit-storaged`, `cockpit-networkmanager`, `cockpit-machines`, `cockpit-podman`, `cockpit-composer`, `cockpit-pcp`.

---

## 10. Image Mode / bootc (RHEL 10)

RHEL 10 introduces Image Mode as a first-class deployment model alongside traditional package mode. The OS is an immutable OCI container image built with standard container tools, delivered from a registry.

- `bootc upgrade` -- pull and stage new image
- `bootc rollback` -- revert to previous image
- `bootc switch` -- switch to different image
- `systemctl soft-reboot` -- userspace-only restart for faster updates

Build with standard Containerfile from `registry.redhat.io/rhel10/rhel-bootc:10`. Convert to disk images with `bootc-image-builder`.

## Key Config File Locations

| Subsystem | Key Files |
|-----------|-----------|
| Kernel modules | `/etc/modules-load.d/`, `/etc/modprobe.d/` |
| systemd units | `/usr/lib/systemd/system/` (vendor), `/etc/systemd/system/` (override) |
| journald | `/etc/systemd/journald.conf`, `/var/log/journal/` |
| dnf | `/etc/dnf/dnf.conf`, `/etc/yum.repos.d/*.repo` |
| Subscriptions | `/etc/pki/entitlement/`, `/etc/pki/consumer/cert.pem` |
| NetworkManager | `/etc/NetworkManager/system-connections/`, `/etc/NetworkManager/NetworkManager.conf` |
| firewalld | `/etc/firewalld/firewalld.conf`, `/etc/firewalld/zones/` |
| GRUB2 | `/etc/default/grub`, `/boot/loader/entries/`, `/boot/grub2/grub.cfg` |
| PAM / authselect | `/etc/pam.d/`, `/etc/authselect/` |
| sssd | `/etc/sssd/sssd.conf`, `/var/log/sssd/` |
| Crypto policies | `/etc/crypto-policies/`, `/usr/share/crypto-policies/policies/` |
| auditd | `/etc/audit/rules.d/`, `/var/log/audit/audit.log` |
| LVM | `/etc/lvm/lvm.conf` |
| Cockpit | `/etc/cockpit/`, `/etc/cockpit/ws-certs.d/` |
| bootc | `/etc/containers/registries.conf`, `/etc/containers/policy.json` |
