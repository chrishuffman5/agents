# AppArmor Architecture Reference

## Mandatory Access Control (MAC) Framework

### DAC vs MAC

Discretionary Access Control (DAC) -- the traditional UNIX permission model -- lets the owner of a resource decide who can access it. DAC is bypassed by root; any process running as UID 0 can read any file.

Mandatory Access Control (MAC) enforces access based on policy defined by the system administrator, not the resource owner. Even root is subject to MAC rules. AppArmor implements MAC as a kernel-level enforcement mechanism layered on top of DAC.

Decision order:
1. DAC check (UID/GID permissions, ACLs) -- if denied, stop.
2. AppArmor MAC check (profile path rules) -- if denied, log denial and stop.

Both must allow an access for it to succeed. A confined root process cannot read files outside its profile's allowed paths.

### Linux Security Modules (LSM) Architecture

LSM is a framework in the Linux kernel that provides hooks for security modules to intercept and mediate kernel operations. AppArmor registers as an LSM at boot via the kernel command line (`security=apparmor` or as a secondary LSM via `lsm=` ordering in Linux 5.1+).

LSM hook categories AppArmor uses:
- `inode_permission` -- file and directory access control
- `file_open` / `file_lock` -- file operation mediation
- `socket_*` -- network access control (connect, bind, listen)
- `task_alloc` / `task_kill` -- signal and process control
- `sb_mount` -- filesystem mount mediation
- `dbus_*` -- D-Bus message mediation (Ubuntu kernel patch)

Each hook calls into AppArmor's policy engine to make an allow/deny decision before the kernel completes the operation.

### AppArmor vs SELinux: Fundamental Difference

AppArmor is **path-based**: rules reference file system paths as strings. SELinux is **label-based**: rules reference security contexts (labels) stored as extended attributes on inodes.

| Aspect | AppArmor | SELinux |
|--------|----------|---------|
| Access control basis | Path strings | Inode security labels |
| Filesystem labeling | Not required | Required (restorecon) |
| Rename/hardlink | Path rules can be bypassed | Labels follow the inode |
| Policy complexity | Lower -- profiles are readable text | Higher -- TE rules, contexts, booleans |
| Learning curve | Moderate -- aa-genprof automates | Steep -- requires type/domain knowledge |

**Path-based limitation:** Rules apply to the path used at time of access, not the underlying inode. A symlink or bind mount can expose a file under a different path, potentially bypassing profile rules. This is mitigated by careful profile writing and mount restrictions.

**Practical advantage:** No filesystem relabeling needed. Any existing filesystem works with AppArmor immediately. New files require no label assignment.

### Policy Engine Internals

AppArmor's kernel module compiles profile text into a binary representation at load time. The engine evaluates path strings against a Deterministic Finite Automaton (DFA) built from profile rules.

Policy engine components:
- **Profile DFA** -- compiled from path glob patterns; evaluated per-access
- **Mediation cache** -- per-task profile cache for performance
- **Notification queue** -- feeds denial records to userspace (aa-notify, journalctl)
- **Policy namespace** -- isolation boundary; used by containers and snaps

Policy namespace hierarchy (Ubuntu 24.04+):
```
root namespace (system profiles)
+-- snap.firefox namespace (snap-generated profiles)
+-- lxd.container-name namespace (container profiles)
```

Namespaces provide isolation: a profile in a child namespace cannot reference or affect profiles in the parent namespace. This is the foundation for snap and container confinement.

## Profile Modes

AppArmor operates each profile in one of these modes. Mode is per-profile, not system-wide.

### Enforce Mode

The profile is actively enforced. Accesses not explicitly allowed by the profile are denied and logged. This is the production mode for profiles that are known-good.

```bash
sudo aa-enforce /etc/apparmor.d/usr.sbin.mysqld
```

### Complain Mode (Learning Mode)

The profile is loaded but not enforced. Accesses not covered by the profile are allowed but logged as `apparmor="ALLOWED"` instead of `apparmor="DENIED"`. Used during profile development to collect access patterns without breaking the application.

```bash
sudo aa-complain /etc/apparmor.d/usr.sbin.mysqld
```

Complain mode logs appear in `/var/log/syslog` and `journalctl` with `apparmor="ALLOWED"`.

### Unconfined Mode

The process runs with no AppArmor restrictions. `aa-disable` moves the profile symlink to `/etc/apparmor.d/disable/` and removes it from the kernel.

```bash
sudo aa-disable /etc/apparmor.d/usr.sbin.mysqld
```

### Kill Mode (Ubuntu 22.04+)

The process is killed immediately upon any denial, rather than just having the access denied. Used for high-security confinement where any violation is treated as a compromise.

```bash
# Set via profile flags
profile myapp /usr/bin/myapp flags=(kill) {
    ...
}
```

### Viewing Profile Modes

```bash
sudo aa-status

# Output includes:
# - N profiles are loaded
# - N profiles are in enforce mode
# - N profiles are in complain mode
# - N profiles are in kill mode (22.04+)
# - N processes have profiles defined
# - N processes are in enforce mode
# - N processes are unconfined but have a profile defined
```

## Profile Structure and Syntax

### File Location and Naming

Profiles live in `/etc/apparmor.d/` with filenames derived from the executable path (slashes replaced by dots, leading slash dropped):
- `/usr/sbin/mysqld` becomes `usr.sbin.mysqld`
- `/usr/bin/firefox` becomes `usr.bin.firefox`

### Basic Profile Anatomy

```
# Comment
#include <tunables/global>

profile mysqld /usr/sbin/mysqld {
    #include <abstractions/base>
    #include <abstractions/nameservice>

    # Capabilities
    capability dac_override,
    capability setuid,
    capability sys_nice,

    # Network
    network tcp,
    network udp,

    # File rules
    /usr/sbin/mysqld              mr,
    /etc/mysql/**                 r,
    /var/lib/mysql/**             rwk,
    /var/log/mysql/**             rw,
    /run/mysqld/mysqld.pid        rw,

    # Signal rules
    signal (send) set=(term kill) peer=mysqld,

    # Local additions (upgrade-safe)
    #include <local/usr.sbin.mysqld>
}
```

### File Permission Flags

| Flag | Meaning |
|------|---------|
| `r` | Read |
| `w` | Write |
| `a` | Append (write-only, no truncate) |
| `m` | Memory map (mmap with PROT_EXEC) |
| `k` | File locking (flock, fcntl) |
| `l` | Create hard links |
| `d` | Delete (unlink) |

### Execute Transition Modes

| Mode | Behavior |
|------|----------|
| `ix` | Inherit -- child gets parent's profile |
| `px` | Profile -- child transitions to its own named profile |
| `Px` | Profile with clean environment |
| `cx` | Child -- child runs under a child profile defined within parent |
| `Cx` | Child with clean environment |
| `ux` | Unconfined -- child runs with no profile (avoid in production) |
| `Ux` | Unconfined with clean environment |

### Capability Rules

Map directly to Linux capabilities (man 7 capabilities):
```
capability net_admin,
capability net_bind_service,
capability sys_ptrace,
capability dac_read_search,
```

### Network Rules

```
network tcp,                    # All TCP
network udp,                    # All UDP
network inet stream,            # IPv4 TCP
network inet6 stream,           # IPv6 TCP
network unix stream,            # Unix domain sockets
network raw,                    # Raw sockets (requires privilege)
```

### Signal Rules (Ubuntu 22.04+)

```
signal (send) set=(term) peer=@{profile_name},
signal (receive) set=(term kill hup) peer=unconfined,
```

### D-Bus Rules (Ubuntu Kernel Patch)

```
dbus (send, receive) bus=system path=/com/example/myapp,
dbus (send) bus=system
    interface=org.freedesktop.DBus
    member=RequestName,
```

### Mount Rules

```
mount options=(bind) /source/ -> /target/,
mount options=(ro remount) /,
deny mount,       # Restrict all mounts (good for containers)
```

### Profile Attachment and Globs

The profile name is the executable path by convention, but attachment can differ:

```
# Name = attachment (most common)
profile /usr/sbin/mysqld { ... }

# Explicit name differs from attachment
profile mysqld /usr/sbin/mysqld { ... }

# Glob-based attachment
profile python3 /usr/bin/python3* { ... }
```

### Profile Stacking (Ubuntu 22.04+, Linux 5.1+)

Profile stacking allows multiple profiles to apply to a single process simultaneously. Access is allowed only when all stacked profiles permit it (intersection).

```
/usr/bin/someapp  px -> profile1//&profile2,
```

Use case: broad base profile plus narrow application profile. Used by containers where a namespace profile stacks with the application profile.

## Abstractions

Abstractions are reusable rule snippets in `/etc/apparmor.d/abstractions/`. Ubuntu ships approximately 50:

| Abstraction | Purpose |
|------------|---------|
| `base` | Bare minimum for any confined process (glibc, locale, /dev/null) |
| `nameservice` | DNS resolution, NSS, /etc/hosts, /etc/resolv.conf |
| `user-tmp` | Access to /tmp and /var/tmp |
| `python` | Python interpreter access |
| `perl` | Perl interpreter access |
| `bash` | Bash shell access |
| `ssl_certs` | TLS certificate store read access |
| `ssl_keys` | TLS private key access |
| `apache2-common` | Apache web server common rules |
| `mysql` | MySQL client library rules |
| `dbus-session-strict` | Session D-Bus with tight restrictions |
| `gnome` | GNOME desktop environment access |
| `fonts` | Font directory read access |
| `audio` | Audio device access (ALSA, PulseAudio) |

Include syntax:
```
#include <abstractions/base>        # Angle brackets = /etc/apparmor.d/ relative
#include "/etc/apparmor.d/abstractions/base"   # Quoted = absolute path
```

## Tunables

Variables in `/etc/apparmor.d/tunables/` substituted at profile load time:

```
@{HOME}=/home/*/ /root/
@{PROC}=/proc/
@{SYS}=/sys/
@{run}=/run/ /var/run/
@{HOMEDIRS}=/home/
```

Custom tunables in `/etc/apparmor.d/tunables/home.d/` or `/etc/apparmor.d/tunables/multiarch.d/` survive package upgrades.

## Snap Integration

### Auto-Generated Snap Profiles

Snapd generates AppArmor profiles for every installed snap. Profiles are stored in `/var/lib/snapd/apparmor/profiles/` and loaded by `snapd.apparmor.service`.

Profile naming:
- `snap.firefox.firefox` -- the firefox snap, firefox command
- `snap.firefox.hook.configure` -- snap hook profile
- `snap-update-ns.firefox` -- snap namespace update profile

### Snap Interfaces and AppArmor Rules

Snap interfaces map to AppArmor rules:

| Interface | Permissions Granted |
|-----------|---------------------|
| `home` | Read/write `@{HOME}/` (not dotfiles) |
| `removable-media` | Read/write `/media/`, `/mnt/` |
| `network` | Full network access |
| `network-bind` | `capability net_bind_service` |
| `camera` | `/dev/video*` access |
| `audio-playback` | PulseAudio socket access |
| `x11` | X11 socket access |
| `wayland` | Wayland socket access |
| `system-files` | Specific system paths (configured per snap) |
| `personal-files` | Specific home paths (configured per snap) |

### snap-confine

`/usr/lib/snapd/snap-confine` is the SUID binary that sets up snap confinement:
1. Loads the snap's AppArmor profile
2. Sets up the snap's mount namespace
3. Transitions into the snap's AppArmor profile using `aa_change_onexec()`
4. Executes the snap command

## Unprivileged User Namespace Restrictions (Ubuntu 24.04+)

### Background

Linux user namespaces allow unprivileged processes to create isolated environments with their own UID/GID mappings. This enables rootless containers, browser sandboxing, and developer tools. However, user namespaces expose kernel attack surface and have been the source of many CVEs.

### The Restriction

Ubuntu 24.04 introduced AppArmor-based restriction: unprivileged processes cannot create user namespaces unless:
1. The process has an AppArmor profile with the `userns` rule, OR
2. The system-wide sysctl `kernel.apparmor_restrict_unprivileged_userns` is set to 0

### Control and Exceptions

```bash
# Check current restriction
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns

# Temporarily disable (resets on reboot)
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

# Permanently disable (not recommended)
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | \
    sudo tee /etc/sysctl.d/99-userns.conf

# Per-application exception in profile
userns,
```

### Affected Applications

| Application | Fix |
|------------|-----|
| Google Chrome | AppArmor profile ships with `userns` rule |
| Firefox (snap) | Snap profile handles via interface |
| Podman (rootless) | AppArmor profile or sysctl exception |
| Buildah | AppArmor profile or sysctl exception |
| VSCode | AppArmor profile included in package |
| Electron apps | May need `--no-sandbox` flag or profile |

Diagnose userns denials:
```bash
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep 'userns'
sudo dmesg | grep 'apparmor="DENIED"' | grep 'userns'
```
