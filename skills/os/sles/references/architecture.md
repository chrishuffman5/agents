# SLES Architecture Reference

Comprehensive architecture reference for SUSE Linux Enterprise Server 15 SP5+. Covers the module/extension system, YaST administration framework, zypper package management, Btrfs filesystem layout, Wicked networking, transactional updates, and RMT repository mirroring.

---

## Module and Extension System

### Layered Architecture

SLES uses a modular architecture where the base OS is minimal. Functionality is added through modules (included in subscription) and extensions (separately licensed).

```
SLES 15 Base Subscription
├── Basesystem Module          (required — core RPMs, kernel, glibc, systemd)
├── Server Applications Module (Apache, nginx, MariaDB, PostgreSQL, BIND)
├── Desktop Applications Module
├── Development Tools Module   (GCC, GDB, make, cmake, git, perf)
├── Containers Module          (Podman, Buildah, Skopeo)
├── Python 3 Module            (current Python 3 with pip, virtualenv)
├── Web and Scripting Module
├── Legacy Module
├── Public Cloud Module        (cloud-init, provider agents)
├── HPC Module                 (MPI, Slurm — moved from separate product in SP6)
└── SAP Applications Module    (bundled with SLES for SAP)

Paid Extensions (separate entitlement):
├── SUSE Linux Enterprise High Availability Extension
├── SUSE Linux Enterprise Live Patching
├── SUSE Manager Client Tools
├── SUSE Linux Enterprise Workstation Extension
└── Confidential Computing Module (SP6 tech preview)
```

### Module vs Extension

| Characteristic | Module | Extension |
|---|---|---|
| Cost | Included in base subscription | Separate license required |
| Support lifecycle | May differ from base OS | Extension-specific lifecycle |
| Registration | `SUSEConnect --product` (no regcode) | `SUSEConnect --product --regcode` |
| Examples | Basesystem, Containers, Python 3 | HA Extension, Live Patching |

### Module Lifecycle

Modules do NOT always follow the SLES base lifecycle. The Python 3 Module receives updates on a faster cadence. Check `SUSEConnect --list-extensions` for the EOL date of each module. When a module reaches end of life before the base OS, packages in that module stop receiving updates.

### SUSEConnect Internals

SUSEConnect communicates with SUSE Customer Center (SCC) or a local RMT server to register the system and activate product repositories. Registration writes credentials to `/etc/zypp/credentials.d/` and repository definitions to `/etc/zypp/repos.d/`.

```bash
# Registration workflow
SUSEConnect --regcode <KEY>                          # Register base system
SUSEConnect --product sle-module-basesystem/15.5/x86_64  # Activate module
SUSEConnect --status                                 # View registration state
SUSEConnect --list-extensions                        # All available products
```

Each product activation adds new zypper repositories. Deregistering a product removes those repos.

---

## YaST Administration Framework

### Architecture

YaST (Yet another Setup Tool) consists of a core library (`yast2-core`) and independent module packages. Each module is a separate RPM (`yast2-network`, `yast2-firewall`, etc.) that can be installed on demand.

Execution modes:
- **GUI mode** -- GTK-based graphical interface (`yast2` in X session)
- **ncurses mode** -- Text-based TUI for headless servers (`yast2` over SSH or console)
- **Command-line mode** -- Direct module invocation (`yast2 <module> <options>`)

### Core YaST Modules

| Module | Package | Purpose |
|---|---|---|
| `network` | yast2-network | Network interface, routing, hostname |
| `firewall` | yast2-firewall | firewalld rule management |
| `partitioner` | yast2-storage-ng | Disk, LVM, Btrfs, RAID partitioning |
| `users` | yast2-users | Local user and group management |
| `security` | yast2-security | Security policies, password rules |
| `bootloader` | yast2-bootloader | GRUB2 configuration |
| `ntp-client` | yast2-ntp-client | NTP/chronyd configuration |
| `services-manager` | yast2-services-manager | systemd service enable/disable |
| `software` | yast2-software | Package management GUI |
| `scc` | yast2-registration | SCC/RMT registration |
| `apparmor` | yast2-apparmor | AppArmor profile management |

### AutoYaST

AutoYaST is SLES's automated installation system using XML control files. Key sections: `<general>`, `<networking>`, `<partitioning>`, `<software>`, `<users>`, `<services-manager>`, `<scripts>`, `<registration>`.

Profile delivery: `autoyast=http://server/autoyast.xml` as kernel boot parameter for network installations.

### YaST vs Cockpit vs Agama

| Tool | Status | Use Case |
|---|---|---|
| YaST | Current default (SLES 15) | Full system administration, ncurses TUI |
| Cockpit | Available via module | Web-based remote management |
| Agama | SLE 16 installer (preview) | Next-gen replacement for YaST installer |

YaST's installation component is being phased out in favor of Agama for SLE 16. Post-install administration modules remain supported in SLES 15.

### YaST Logs

Main log: `/var/log/YaST2/y2log`. Filter by severity: `grep "^<3>" /var/log/YaST2/y2log` (level 3 = error), `grep "^<5>"` (level 5 = warning). Storage operations: `/var/log/YaST2/storage.log`.

---

## Zypper Package Management

### Command Model

Zypper uses a patch-based model for security compliance, distinct from RHEL's errata system.

| Command | What It Does | When to Use |
|---|---|---|
| `zypper patch` | Applies SUSE-curated patches (security/recommended) | Routine patching |
| `zypper update` | Updates individual packages to latest version | Specific package updates |
| `zypper dup` | Full distribution upgrade with vendor/package changes | SP migration only |

### Repository Priority

Lower numeric priority = higher precedence. Default priority is 99. SUSE official repos should be 90 or lower to override third-party repos.

```bash
zypper modifyrepo --priority 50 SUSE_Updates_SLE-Module-Basesystem_15-SP5_x86_64
```

### Patch Categories

| Category | Description | Urgency |
|---|---|---|
| security | CVE fixes, security vulnerabilities | Apply ASAP |
| recommended | Bug fixes, stability improvements | Maintenance window |
| optional | New features, non-critical updates | Discretionary |
| feature | Major functionality additions | Planned upgrades only |

### Zypper History and Diagnostics

Transaction history: `/var/log/zypp/history`. Solver debugging: `zypper --debug install <package>`. Dry-run: `zypper install --dry-run <package>`.

### zypper search-packages (SP6+)

SP6 adds `zypper search-packages` to search across ALL modules and extensions, not just enabled repositories. Output includes the module name and the SUSEConnect command to enable it.

---

## Btrfs Filesystem Architecture

### Why SLES Uses Btrfs

SUSE adopted Btrfs as the default root filesystem because it enables atomic rollbacks via Snapper. If a zypper update or configuration change breaks the system, boot back to the pre-change snapshot. CoW performance and compression are secondary benefits.

### Default Subvolume Layout

```
Btrfs pool on / partition:
├── @               → mounted as /               (snapshotted by Snapper)
├── @/home          → /home                      (excluded from snapshots)
├── @/opt           → /opt                       (excluded)
├── @/root          → /root                      (excluded)
├── @/srv           → /srv                       (excluded)
├── @/tmp           → /tmp                       (excluded)
├── @/usr/local     → /usr/local                 (excluded)
├── @/var           → /var                        (excluded — logs, databases)
├── @/var/log       → /var/log                   (excluded)
├── @/var/crash     → /var/crash                 (excluded)
├── @/var/spool     → /var/spool                 (excluded)
├── @/var/tmp       → /var/tmp                   (excluded)
└── @/.snapshots    → /.snapshots                (Snapper snapshot storage)
```

Excluded subvolumes are NOT rolled back with the root subvolume. This preserves runtime data (logs, database state, user data) across rollbacks.

### Subvolume Mounting

Subvolumes mount by name or ID in `/etc/fstab`:

```
/dev/sda2  /        btrfs  defaults,subvol=@       0 0
/dev/sda2  /var     btrfs  defaults,subvol=@/var   0 0
/dev/sda2  /home    btrfs  defaults,subvol=@/home  0 0
```

SLES uses a flat layout (all subvolumes as children of subvolid=5). Flat is preferred for Snapper rollback because it allows the default subvolume to be changed without restructuring the tree.

### Btrfs vs XFS Decision Matrix

| Factor | Btrfs | XFS |
|---|---|---|
| Rollback capability | Yes (via Snapper) | No |
| Default for / | Yes | Alternative |
| SAP HANA data volumes | Not recommended | Recommended |
| Maximum file size | 16 EiB | 8 EiB |
| Performance on large files | Good | Excellent |
| Maturity | Production for root | Very mature |

### Maintenance Schedule

SUSE runs Btrfs scrub and balance via systemd timers. Configuration in `/etc/sysconfig/btrfsmaintenance`. Verify with `systemctl status btrfsmaintenance-scrub.timer`.

---

## Wicked Networking

### Architecture

Wicked is SLES's default network management daemon for server deployments. It uses ifcfg-compatible configuration files in `/etc/sysconfig/network/`. Wicked is a daemon that owns interface state, unlike legacy ifup/ifdown scripts.

### Configuration Layout

```
/etc/sysconfig/network/
├── ifcfg-eth0         # Interface configuration
├── ifcfg-bond0        # Bond interface
├── ifcfg-br0          # Bridge interface
├── ifcfg-vlan10       # VLAN interface
├── routes             # Static routes
├── dhcp               # DHCP client global config
└── config             # Global network config
```

### Wicked vs NetworkManager

| Feature | Wicked | NetworkManager |
|---|---|---|
| Default for | SLES (server) | SLED (desktop) |
| Config files | /etc/sysconfig/network/ifcfg-* | /etc/NetworkManager/system-connections/ |
| CLI tool | wicked | nmcli |
| TUI tool | yast2 network | nmtui |
| Future status | Being replaced | Future default for SLES |

Wicked is being phased out. SUSE is replacing it with NetworkManager in future SLE releases. Plan migration for post-SLES 15 environments.

---

## Transactional Updates

### Architecture

Transactional updates provide atomic OS updates using Btrfs snapshots with a read-only root filesystem. This is the update model for SLE Micro and MicroOS.

How it works:
1. Creates a new Btrfs snapshot of the current root
2. Mounts the snapshot as an overlay
3. Applies updates into the new snapshot (not the live root)
4. On reboot, GRUB boots into the new snapshot
5. If the new snapshot is healthy, it becomes the new default
6. Old snapshot remains available for rollback

The live root filesystem is not modified during the update process, guaranteeing that the running system is always consistent.

---

## RMT Architecture

```
SUSE Customer Center (SCC)
        │  (sync metadata + packages)
        ▼
   RMT Server (internal)
   /var/lib/rmt/public/repo/
        │  (client registration + package delivery)
        ▼
   SLES Client Systems
```

RMT requires its own SLES subscription and outbound internet access to SCC. Clients need only inbound access to the RMT server. Configuration in `/etc/rmt.conf`. Service: `rmt-server.service`. Scheduled mirroring: `rmt-server-mirror.timer`.

---

## Boot Process

SLES uses GRUB2 with Snapper integration. The `grub2-snapper-plugin` generates boot entries for each Snapper snapshot. At boot, the GRUB menu shows the live system and available snapshots.

Selecting a snapshot entry mounts that snapshot as a read-only root. From within the booted snapshot, run `snapper rollback` to make it the permanent default, then reboot.

Default subvolume management: `btrfs subvolume get-default /` shows the current boot target. `snapper rollback` automates changing the default subvolume.
