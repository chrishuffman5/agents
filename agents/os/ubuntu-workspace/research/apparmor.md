# AppArmor — Deep-Dive Research (Ubuntu 20.04/22.04/24.04/26.04)

> Comprehensive technical reference for AppArmor configuration, profile management, denial analysis, and Ubuntu-specific integration.
> Covers Ubuntu 20.04 LTS through 26.04 LTS unless otherwise noted.

---

## Part 1: Architecture

### 1. LSM Framework — Linux Security Modules

#### DAC vs MAC
Like SELinux, AppArmor implements **Mandatory Access Control (MAC)** layered on top of traditional UNIX **Discretionary Access Control (DAC)**. Both must permit an access for it to succeed:

1. DAC check (UID/GID permissions, ACLs) — if denied, stop.
2. AppArmor MAC check (profile rules) — if denied, log denial and stop.

The critical difference from DAC: even a process running as root is subject to AppArmor profile restrictions. A confined root process cannot read files outside its profile's allowed paths.

#### Linux Security Modules (LSM) Architecture
LSM is a kernel framework providing hooks that security modules intercept before kernel operations complete. AppArmor registers as an LSM at boot via the kernel command line (`security=apparmor` or as a secondary LSM via `lsm=` ordering in Linux 5.1+).

LSM hook categories AppArmor uses:
- `inode_permission` — file and directory access control
- `file_open` / `file_lock` — file operation mediation
- `socket_*` — network access control
- `task_alloc` / `task_kill` — signal and process control
- `sb_mount` — filesystem mount mediation
- `dbus_*` — D-Bus message mediation (via apparmor_dbus kernel patch, Ubuntu kernels)

#### AppArmor vs SELinux: Key Differences

| Aspect | AppArmor | SELinux |
|--------|----------|---------|
| Access control basis | **Path-based** (file path strings) | **Label-based** (security contexts on inodes) |
| Policy complexity | Lower — profiles are readable text | Higher — TE rules, contexts, booleans |
| Learning curve | Moderate — `aa-genprof` automates | Steep — requires understanding types/domains |
| Filesystem labeling | Not required | Required (`restorecon`, xattrs) |
| Rename/hardlink issues | Path rules can be bypassed by rename | Labels follow the inode, immune to rename |
| Default on Ubuntu | Yes (20.04+) | Available but not default |
| Default on RHEL | Available | Yes |
| Flexibility | Profile per-application | System-wide policy with type transitions |
| Stacking | Supported (Linux 5.1+, Ubuntu 22.04+) | Supported |

**Path-based limitation:** AppArmor rules apply to the path used at time of access, not the underlying inode. A symlink or bind mount can expose a file under a different path, potentially bypassing profile rules. This is mitigated by careful profile writing and mount restrictions.

**Practical advantage:** No filesystem relabeling needed. Any existing filesystem works with AppArmor immediately. New files inherit no label — only the path matters.

#### AppArmor Kernel Module and Policy Engine
AppArmor's kernel module compiles profile text into a binary representation and loads it into a kernel-side policy engine. The engine evaluates path strings against a DFA (Deterministic Finite Automaton) built from profile rules at load time.

Policy engine components:
- **Profile DFA** — compiled from path glob patterns; evaluated per-access
- **Mediation cache** — per-task profile cache for performance
- **Notification queue** — feeds denial records to userspace (aa-notify)
- **Policy namespace** — isolation boundary; used by containers and snaps

Policy namespace hierarchy (Ubuntu 24.04+):
```
root namespace (system profiles)
└── snap.firefox namespace (snap-generated profiles)
└── lxd.container-name namespace (container profiles)
```

---

### 2. Profile Modes

AppArmor operates each profile in one of three modes. Mode is per-profile, not system-wide.

#### Enforce Mode
The profile is **actively enforced**. Accesses not explicitly allowed by the profile are denied and logged. This is the production mode for profiles that are known-good.

```bash
# Put a profile into enforce mode
sudo aa-enforce /etc/apparmor.d/usr.sbin.mysqld

# Or by profile name
sudo aa-enforce mysqld
```

#### Complain Mode (Learning Mode)
The profile is **loaded but not enforced**. Accesses not covered by the profile are **allowed** but logged as "ALLOWED" (not DENIED). Used during profile development to collect access patterns without breaking the application.

```bash
# Put a profile into complain mode
sudo aa-complain /etc/apparmor.d/usr.sbin.mysqld

# Or by profile name
sudo aa-complain mysqld
```

Complain mode logs appear in `/var/log/syslog` with `audit: type=1400` and `apparmor="ALLOWED"` instead of `apparmor="DENIED"`.

#### Unconfined Mode
The process runs with **no AppArmor restrictions**. Equivalent to AppArmor not being present for that application. Not the same as "no profile loaded" — unconfined is an explicit state.

```bash
# Disable a profile (sets to unconfined, removes from enforcement)
sudo aa-disable /etc/apparmor.d/usr.sbin.mysqld
```

`aa-disable` moves the profile symlink from `/etc/apparmor.d/` to `/etc/apparmor.d/disable/` and removes it from the kernel.

#### aa-status — Viewing Per-Profile Modes
```bash
sudo aa-status

# Output sections:
# - apparmor module is loaded
# - N profiles are loaded
# - N profiles are in enforce mode
# - N profiles are in complain mode
# - N profiles are in kill mode      (Ubuntu 22.04+)
# - N profiles are in unconfined mode
# - N processes have profiles defined
# - N processes are in enforce mode
# - N processes are in complain mode
# - N processes are unconfined but have a profile defined
```

---

### 3. Profile Structure

AppArmor profiles live in `/etc/apparmor.d/` with filenames matching the executable path (slashes replaced by dots, leading slash dropped): `/usr/sbin/mysqld` → `usr.sbin.mysqld`.

#### Basic Profile Anatomy
```
# Profile comment
#include <tunables/global>

profile mysqld /usr/sbin/mysqld {
    # Include common abstractions
    #include <abstractions/base>
    #include <abstractions/nameservice>
    #include <abstractions/mysql>

    # Capabilities
    capability dac_override,
    capability setuid,
    capability sys_nice,

    # Network access
    network tcp,
    network udp,

    # File rules
    /usr/sbin/mysqld              mr,
    /etc/mysql/**                 r,
    /var/lib/mysql/**             rwk,
    /var/log/mysql/**             rw,
    /tmp/mysql.sock               rw,
    /run/mysqld/mysqld.pid        rw,
    /run/mysqld/mysqld.sock       rw,

    # Signal rules
    signal (send) set=(term kill) peer=mysqld,

    # D-Bus (Ubuntu kernel with dbus mediation)
    dbus send bus=system path=/org/freedesktop/systemd1,
}
```

#### File Permission Flags
| Flag | Meaning |
|------|---------|
| `r` | Read |
| `w` | Write |
| `a` | Append |
| `x` | Execute (must specify exec mode) |
| `m` | Memory map (mmap) |
| `k` | File locking |
| `l` | Link (create hard links) |
| `d` | Delete (unlink) |
| `i` | Inherit exec mode — child gets parent's profile |
| `p` | Profile exec — child transitions to named profile |
| `P` | Profile exec with clean environment |
| `u` | Unconfined exec — child runs unconfined |
| `U` | Unconfined exec with clean environment |
| `c` | Child profile exec |
| `C` | Child profile exec with clean environment |
| `ix` | Inherit on exec (shorthand) |
| `px` | Transition to named profile on exec (shorthand) |
| `ux` | Execute unconfined (shorthand — avoid) |
| `cx` | Execute in child profile (shorthand) |

#### Capability Rules
Maps to Linux capabilities (man 7 capabilities):
```
capability net_admin,
capability net_bind_service,
capability sys_ptrace,
capability audit_write,
capability dac_read_search,
```

#### Network Rules
```
# Allow all TCP and UDP
network tcp,
network udp,

# Allow specific socket type
network inet stream,
network inet6 stream,
network unix stream,

# Allow raw sockets (requires privilege)
network raw,
```

#### Signal Rules (Ubuntu 22.04+)
```
# Allow sending SIGTERM to processes with same profile
signal (send) set=(term) peer=@{profile_name},

# Allow receiving all signals from parent
signal (receive) set=(term kill hup) peer=unconfined,
```

#### D-Bus Rules (Ubuntu kernel patch)
```
dbus (send, receive) bus=system path=/com/example/myapp,
dbus (send) bus=system
    interface=org.freedesktop.DBus
    member=RequestName,
```

#### Mount Rules
```
# Allow bind mounts
mount options=(bind) /source/ -> /target/,

# Allow read-only remount
mount options=(ro remount) /,

# Restrict all mounts (good for container profiles)
deny mount,
```

#### #include Directives
```
# Angle brackets = /etc/apparmor.d/ relative path
#include <abstractions/base>
#include <tunables/global>

# Quoted = absolute or profile-dir relative
#include "/etc/apparmor.d/abstractions/base"

# Include directory (all files in it)
#include <abstractions/>
```

---

### 4. Abstractions and Tunables

#### Abstractions — `/etc/apparmor.d/abstractions/`
Reusable rule snippets included by profiles. Ubuntu ships ~50 abstractions:

| Abstraction | Purpose |
|------------|---------|
| `base` | Bare minimum for any confined process (libc, locale, etc.) |
| `nameservice` | DNS resolution, NSS, /etc/hosts, /etc/resolv.conf |
| `user-tmp` | Access to /tmp and /var/tmp |
| `python` | Python interpreter access |
| `perl` | Perl interpreter access |
| `bash` | Bash shell access |
| `ssl_certs` | TLS certificate store read access |
| `ssl_keys` | TLS private key access |
| `openssl` | OpenSSL library and config |
| `apache2-common` | Apache web server common rules |
| `mysql` | MySQL client library rules |
| `dbus-session-strict` | Session D-Bus with tight restrictions |
| `gnome` | GNOME desktop environment access |
| `X` | X11 display access |
| `fonts` | Font directory read access |
| `video` | Video device access (/dev/video*) |
| `audio` | Audio device access (ALSA, PulseAudio) |

#### Tunables — `/etc/apparmor.d/tunables/`
Variables substituted into profiles at load time. Allows site-local customization without editing profiles:

```
# /etc/apparmor.d/tunables/home.d/site.local
@{HOME}=/home/*/ /root/

# /etc/apparmor.d/tunables/global
@{PROC}=/proc/
@{SYS}=/sys/
@{run}=/run/ /var/run/
@{HOMEDIRS}=/home/
@{HOME}=@{HOMEDIRS}*/
```

Custom tunables go in `/etc/apparmor.d/tunables/home.d/` or `/etc/apparmor.d/tunables/multiarch.d/` to survive package upgrades.

---

### 5. Profile Naming and Attachment

#### Path-Based Profile Names
The profile name is the executable path by convention, but the **attachment** specification determines which executable uses the profile. They can differ:

```
# Profile name = attachment (most common)
profile /usr/sbin/mysqld { ... }

# Explicit attachment (name differs from path)
profile mysqld /usr/sbin/mysqld { ... }
profile mysqld_custom /usr/sbin/mysqld { ... }  # name differs
```

#### Glob Patterns in Attachment
```
# Match any version of python3
profile python3 /usr/bin/python3* { ... }

# Match script by pattern
profile my-scripts /opt/myapp/scripts/* { ... }
```

#### Profile Stacking (Ubuntu 22.04+, Linux 5.1+)
Profile stacking allows multiple profiles to apply to a single process simultaneously. Access is allowed only when **all** stacked profiles permit it (intersection of rules).

```
# Exec into a stack of two profiles
/usr/bin/someapp  px -> profile1//&profile2,

# Stack notation: profile1//&profile2
# Process must satisfy BOTH profile1 AND profile2 rules
```

Use case: apply a broad base profile plus a narrow application profile. Useful for containers where a namespace profile stacks with the container's application profile.

---

### 6. Snap Integration

#### Auto-Generated Snap Profiles
Snapd generates AppArmor profiles for every installed snap automatically. Profiles are stored in `/var/lib/snapd/apparmor/profiles/` and loaded by `snapd.apparmor.service`.

Profile naming for snaps:
- `snap.firefox.firefox` — the firefox snap, firefox command
- `snap.firefox.hook.configure` — snap hook profile
- `snap-update-ns.firefox` — snap namespace update profile

#### Snap Interfaces and AppArmor Rules
Snap interfaces map to AppArmor rules in `/usr/share/apparmor/snap/interfaces/`:

| Interface | AppArmor permissions granted |
|-----------|------------------------------|
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

#### snap-confine
`/usr/lib/snapd/snap-confine` is the SUID binary that sets up snap confinement. It:
1. Loads the snap's AppArmor profile
2. Sets up the snap's mount namespace
3. Transitions into the snap's AppArmor profile using `aa_change_onexec()`
4. Executes the snap command

Viewing snap AppArmor denials:
```bash
# Snap denials show profile names like snap.firefox.firefox
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep 'snap\.'

# Check what snap interfaces are connected
snap connections firefox
```

---

## Part 2: Best Practices

### 6. Profile Creation Workflow

#### aa-genprof — Generate a New Profile
`aa-genprof` is the recommended starting point for new profiles. It runs the application, monitors accesses, and interactively builds a profile.

```bash
# Install tools
sudo apt install apparmor-utils

# Generate profile for a new application
sudo aa-genprof /usr/local/bin/myapp

# aa-genprof workflow:
# 1. Puts the app in complain mode temporarily
# 2. Prompts you to run the application in another terminal
# 3. You exercise all application functionality
# 4. Press S to scan logs
# 5. Interactively allow/deny each detected access
# 6. Press F to finish — profile saved to /etc/apparmor.d/
# 7. Profile is loaded in complain mode for further testing
```

Interactive choices during aa-genprof:
- `(A)llow` — add the access to the profile
- `(D)eny` — explicitly deny (adds deny rule)
- `(I)gnore` — skip this event
- `(N)ew` — enter a custom rule manually
- `(G)lob` — generalize the path pattern
- `(Q)uit` — exit without saving

#### aa-logprof — Update Existing Profile from Logs
After a profile is deployed in complain mode and the application runs, `aa-logprof` reads the accumulated log entries and proposes profile additions:

```bash
# Update profile based on accumulated log events
sudo aa-logprof

# Update profile using a specific log file
sudo aa-logprof -f /var/log/syslog

# Non-interactive dry run (show what would change)
sudo aa-logprof -d  # Not a real flag — use -n for newer versions

# Process logs from a specific date
sudo aa-logprof -f /var/log/syslog.1
```

Best practice workflow for a new application:
1. Write minimal profile or run `aa-genprof`
2. Set to complain mode: `sudo aa-complain /etc/apparmor.d/myapp`
3. Run application through all use cases (normal operation, edge cases)
4. Run `sudo aa-logprof` to incorporate missing rules
5. Review proposed changes — use glob patterns judiciously
6. Set to enforce: `sudo aa-enforce /etc/apparmor.d/myapp`
7. Monitor for denials in production

#### Manual Profile Writing Best Practices
- Always start with `#include <abstractions/base>` — provides glibc, locale, etc.
- Use `#include <abstractions/nameservice>` if the app does DNS or user lookups
- Prefer specific paths over broad globs where possible
- Use `/** r,` sparingly — prefer `/specific/dir/** r,`
- Never use `/** rwx,` in production profiles
- Add `deny` rules explicitly for sensitive paths even if not needed (defense in depth)
- Use `@{PROC}` and `@{SYS}` tunables instead of hardcoded `/proc/` and `/sys/`
- Test with `apparmor_parser --preprocess` to check syntax before loading

---

### 7. Profile Management

#### apparmor_parser — Core Profile Tool
```bash
# Load or replace a profile (most common operation)
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld

# Replace all profiles in a directory
sudo apparmor_parser -r /etc/apparmor.d/

# Remove a profile from the kernel
sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld

# Check/preprocess profile syntax without loading
sudo apparmor_parser --preprocess /etc/apparmor.d/usr.sbin.mysqld

# Load profile with verbose output
sudo apparmor_parser -v -r /etc/apparmor.d/usr.sbin.mysqld

# Force cache rebuild
sudo apparmor_parser -r --write-cache /etc/apparmor.d/
```

#### Profile Caching — `/etc/apparmor.d/cache/`
AppArmor compiles profile text to a binary DFA at load time. Caching stores compiled output to speed up subsequent boots.

Cache location:
- Ubuntu 20.04/22.04: `/etc/apparmor.d/cache/`
- Ubuntu 24.04+: `/var/cache/apparmor/` (systemd-based cache)

Cache invalidation: automatic when profile mtime changes or AppArmor version changes. Manual invalidation:
```bash
# Clear cache and reload all profiles
sudo rm -rf /etc/apparmor.d/cache/*
sudo systemctl restart apparmor
```

#### Boot-Time Profile Loading
AppArmor profiles are loaded at boot by `apparmor.service` (SysV on older systems) or `apparmor.service` (systemd):

```bash
# AppArmor systemd service management
sudo systemctl status apparmor
sudo systemctl restart apparmor   # Reloads all profiles
sudo systemctl enable apparmor

# Manual full reload (equivalent to service restart)
sudo service apparmor reload      # Reload without restart
sudo service apparmor restart     # Full restart
```

Profiles in `/etc/apparmor.d/disable/` are excluded from loading.

#### Directory Structure
```
/etc/apparmor.d/
├── abstractions/          # Reusable rule snippets
│   ├── base
│   ├── nameservice
│   └── ...
├── tunables/              # Site-configurable variables
│   ├── global
│   └── home.d/
├── cache/                 # Compiled profile cache
├── disable/               # Disabled profiles (symlinks)
├── force-complain/        # Forced complain overrides
├── local/                 # Site-local profile additions
│   ├── usr.sbin.mysqld    # Added to profile via #include
│   └── ...
├── usr.sbin.mysqld        # MySQL profile
├── usr.sbin.named         # BIND profile
├── usr.sbin.sshd          # SSH daemon profile
└── ...
```

#### Local Profile Additions
The `/etc/apparmor.d/local/` directory provides site-specific additions without modifying shipped profiles. Shipped profiles include:
```
#include <local/usr.sbin.mysqld>
```

Add custom rules to `/etc/apparmor.d/local/usr.sbin.mysqld`:
```
# Site-local MySQL additions
/mnt/datadisk/mysql/** rwk,
/backup/mysql/** rw,
```

These survive package upgrades. This is the preferred method for customization.

---

### 8. Common Profiles Shipped with Ubuntu

#### Database and Service Profiles
- `usr.sbin.mysqld` — MySQL/MariaDB server; covers `/var/lib/mysql/`, `/etc/mysql/`, `/run/mysqld/`
- `usr.sbin.named` — BIND DNS server; covers `/etc/bind/`, `/var/cache/bind/`, `/var/run/named/`
- `usr.sbin.ntpd` — NTP daemon; covers `/etc/ntp.conf`, `/var/lib/ntp/`, time sockets
- `usr.sbin.sshd` — SSH daemon (complain by default in some versions); limited as sshd spawns many children

#### Web and Application Profiles
- `usr.sbin.apache2` — Apache HTTP Server (via apache2-utils package)
- Firefox shipped as snap — profile at `/var/lib/snapd/apparmor/profiles/snap.firefox.firefox`

#### Virtualization Profiles
- `usr.lib.libvirt.virt-aa-helper` — libvirt's AppArmor helper that generates per-VM profiles
- `usr.sbin.libvirtd` — libvirt daemon
- `lxc-container-default` and `lxc-container-default-cgns` — LXC container profiles

LXC/libvirt AppArmor integration: each VM/container gets a dynamically-generated profile constraining what the VM process can do, even as root within the VM.

---

### 9. Unprivileged User Namespaces (Ubuntu 24.04+)

#### Background
Linux user namespaces allow unprivileged processes to create isolated environments with their own UID/GID mappings. This enables rootless containers (Podman, Buildah), browser sandboxing (Chrome, Firefox), and developer tools. However, user namespaces also expose kernel attack surface (historically source of many CVEs).

#### Ubuntu 24.04 Restriction
Ubuntu 24.04 LTS introduced AppArmor-based restriction of unprivileged user namespace creation. By default, **unprivileged processes cannot create user namespaces** unless:
1. The process is covered by an AppArmor profile that explicitly permits it, OR
2. The system-wide sysctl `kernel.apparmor_restrict_unprivileged_userns` is set to 0

This is controlled by:
```bash
# Check current restriction status
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns

# Temporarily disable restriction (resets on reboot)
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

# Permanently disable (not recommended)
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/99-userns.conf
```

#### Per-Application Exceptions
Grant a specific application permission to create user namespaces by adding a profile rule:
```
# In the application's AppArmor profile
userns,        # Allow creating user namespaces
```

Or create a targeted exception profile:
```
# /etc/apparmor.d/chrome-userns
abi <abi/4.0>,
profile chrome-userns /usr/bin/google-chrome {
    userns,
}
```

#### Impact on Browsers and Containers
Applications affected and their exception handling:

| Application | Fix |
|------------|-----|
| Google Chrome | AppArmor profile ships with `userns` rule |
| Firefox (snap) | Snap profile handles via snap interface |
| Podman (rootless) | AppArmor profile or sysctl exception |
| Buildah | AppArmor profile or sysctl exception |
| VSCode (sandbox) | AppArmor profile in package |
| Electron apps | May need `--no-sandbox` flag or profile |

Check if an application is failing due to this restriction:
```bash
# Look for userns denials
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep 'userns'
sudo dmesg | grep 'apparmor="DENIED"' | grep 'userns'
```

---

## Part 3: Diagnostics

### 10. Denial Analysis

#### Log Locations
AppArmor denials appear in multiple places:

```bash
# Primary: systemd journal (Ubuntu 20.04+)
sudo journalctl -xe | grep 'apparmor="DENIED"'
journalctl --since="1 hour ago" | grep apparmor

# Kernel ring buffer (recent denials, volatile)
sudo dmesg | grep 'apparmor="DENIED"'
sudo dmesg | grep apparmor

# Syslog (if rsyslog is writing kernel messages)
sudo grep 'apparmor="DENIED"' /var/log/syslog
sudo grep 'apparmor="DENIED"' /var/log/kern.log

# Audit log (if auditd is running)
sudo grep 'apparmor="DENIED"' /var/log/audit/audit.log
```

#### Anatomy of a Denial Message
```
audit: type=1400 audit(1712345678.123:456): apparmor="DENIED" operation="open" profile="usr.sbin.mysqld" name="/data/mysql/custom.cnf" pid=1234 comm="mysqld" requested_mask="r" denied_mask="r" fsuid=999 ouid=0
```

| Field | Meaning |
|-------|---------|
| `apparmor="DENIED"` | Enforcement decision |
| `operation="open"` | Kernel operation attempted |
| `profile="usr.sbin.mysqld"` | AppArmor profile name |
| `name="/data/mysql/custom.cnf"` | Resource path accessed |
| `pid=1234` | Process ID |
| `comm="mysqld"` | Process command name |
| `requested_mask="r"` | Permission the process requested |
| `denied_mask="r"` | Permission that was denied |
| `fsuid=999` | Filesystem UID of the process |
| `ouid=0` | Owner UID of the file |

Common operation values:
- `open`, `read`, `write` — file operations
- `exec` — program execution
- `connect`, `bind`, `listen` — network operations
- `create`, `unlink`, `rename` — filesystem modification
- `mknod` — device file creation
- `mount`, `umount` — mount operations
- `signal` — signal delivery
- `dbus_method_call` — D-Bus method

#### aa-notify — Desktop Notifications
On desktop Ubuntu, `aa-notify` shows AppArmor denials as desktop notifications:

```bash
# Install if not present
sudo apt install apparmor-notify

# Show recent denials as notifications
aa-notify -s 1          # Denials from last 1 day
aa-notify -v            # Verbose output
aa-notify -p            # Show as desktop popup
```

---

### 11. Troubleshooting Workflow

#### Standard Diagnosis Flow
```
1. Check overall AppArmor status
   sudo aa-status

2. Find recent denials for the affected process
   sudo journalctl -xe | grep apparmor | grep DENIED | grep 'comm="myapp"'

3. Identify the profile and denied resource
   (parse the denial message fields)

4. Switch profile to complain mode for safe analysis
   sudo aa-complain /etc/apparmor.d/usr.sbin.myapp

5. Reproduce the problem — denials become ALLOWEDs in complain mode
   (run the application through the failing operation)

6. Run aa-logprof to generate proposed rule additions
   sudo aa-logprof

7. Review and accept proposed rules
   (be conservative — don't accept overly broad globs)

8. Reload the profile
   sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp

9. Switch back to enforce mode
   sudo aa-enforce /etc/apparmor.d/usr.sbin.myapp

10. Test that the problem is resolved and no new denials appear
    sudo journalctl -f | grep apparmor
```

#### Profile Conflicts After Package Update
When a package upgrade ships a new profile version, conflicts can arise with local modifications:

```bash
# Check for .dpkg-new files (unmerged profile updates)
ls /etc/apparmor.d/*.dpkg-new

# Compare and merge
diff /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/usr.sbin.mysqld.dpkg-new

# After merging, reload
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld

# Best practice: put local changes in /etc/apparmor.d/local/ to avoid conflicts
```

---

### 12. Common Issues and Resolutions

#### Application Cannot Access File
**Symptom:** Application fails with "Permission denied" despite correct file ownership.

**Diagnosis:**
```bash
sudo journalctl -xe | grep apparmor | grep DENIED | tail -20
# Look for: operation="open" name="/path/to/file" denied_mask="r"
```

**Fix:** Add the path to the profile or local override:
```bash
# /etc/apparmor.d/local/usr.sbin.myapp
/custom/data/dir/** r,
/custom/data/dir/*.conf r,
```
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
```

#### Network Access Denied
**Symptom:** Application cannot open network connections.

**Diagnosis:**
```bash
sudo dmesg | grep apparmor | grep 'operation="connect"'
# or: denied_mask="send receive" for UDP
```

**Fix options:**
```bash
# Add to profile
network tcp,                          # Allow all TCP
network inet stream,                  # Allow IPv4 TCP
capability net_bind_service,          # Allow binding port < 1024
```

#### Snap Cannot Access Resource
**Symptom:** Snap application fails to access home directory, removable media, etc.

**Diagnosis:**
```bash
snap connections <snap-name>          # Show connected interfaces
journalctl | grep "snap.<snap-name>"  # Find snap-specific denials
```

**Fix:**
```bash
# Connect the appropriate snap interface
sudo snap connect firefox:home :home
sudo snap connect myapp:removable-media :removable-media
sudo snap connect myapp:camera :camera
```

#### Custom Application Needs Profile
**Symptom:** New application deployed with no AppArmor profile.

**Fix:**
```bash
sudo aa-genprof /usr/local/bin/myapp
# Follow interactive prompts
# Exercise all application functionality in another terminal
# Press S to scan, approve rules, press F to finish
sudo aa-enforce /etc/apparmor.d/myapp
```

#### Profile Errors on Load
**Symptom:** `apparmor_parser -r` fails with syntax error.

**Diagnosis:**
```bash
# Check syntax
sudo apparmor_parser --preprocess /etc/apparmor.d/usr.sbin.myapp

# View parser error details
sudo apparmor_parser -d /etc/apparmor.d/usr.sbin.myapp 2>&1 | head -30
```

---

## Part 4: Scripts

### Script 01 — AppArmor Status Overview

```bash
#!/usr/bin/env bash
# =============================================================================
# 01-apparmor-status.sh
# AppArmor Status Overview
# Version: 1.0.0
# Targets Ubuntu 20.04+ with AppArmor enabled
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

BOLD='\033[1m'

print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

print_ok()   { echo -e "  ${GREEN}[OK]${NC}    $1"; }
print_warn() { echo -e "  ${YELLOW}[WARN]${NC}  $1"; }
print_err()  { echo -e "  ${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "  ${CYAN}[INFO]${NC}  $1"; }

echo -e "${BOLD}AppArmor Status Report${NC}"
echo "Generated: $(date)"
echo "Host: $(hostname -f 2>/dev/null || hostname)"

# ---- Module Status ----
print_header "AppArmor Module Status"

if ! command -v aa-status &>/dev/null; then
    print_err "aa-status not found. Install apparmor-utils: sudo apt install apparmor-utils"
    exit 1
fi

if sudo aa-status --enabled 2>/dev/null; then
    print_ok "AppArmor module is loaded and enabled"
else
    print_err "AppArmor is NOT enabled"
    echo "  Enable with: sudo systemctl enable --now apparmor"
    exit 1
fi

# ---- Profile Counts ----
print_header "Profile Summary"

AA_STATUS=$(sudo aa-status 2>/dev/null)

TOTAL=$(echo "$AA_STATUS" | grep 'profiles are loaded' | awk '{print $1}' || echo "0")
ENFORCE=$(echo "$AA_STATUS" | grep 'profiles are in enforce mode' | awk '{print $1}' || echo "0")
COMPLAIN=$(echo "$AA_STATUS" | grep 'profiles are in complain mode' | awk '{print $1}' || echo "0")
KILL_MODE=$(echo "$AA_STATUS" | grep 'profiles are in kill mode' | awk '{print $1}' || echo "0")

echo "  Total profiles loaded:  ${BOLD}${TOTAL}${NC}"
echo "  Enforce mode:           ${GREEN}${ENFORCE}${NC}"
echo "  Complain mode:          ${YELLOW}${COMPLAIN}${NC}"
[ "$KILL_MODE" -gt 0 ] 2>/dev/null && echo "  Kill mode:              ${RED}${KILL_MODE}${NC}"

# ---- Process Confinement ----
print_header "Process Confinement"

PROC_DEFINED=$(echo "$AA_STATUS" | grep 'processes have profiles defined' | awk '{print $1}' || echo "0")
PROC_ENFORCE=$(echo "$AA_STATUS" | grep 'processes are in enforce mode' | awk '{print $1}' || echo "0")
PROC_COMPLAIN=$(echo "$AA_STATUS" | grep 'processes are in complain mode' | awk '{print $1}' || echo "0")
PROC_UNCONFINED=$(echo "$AA_STATUS" | grep 'processes are unconfined but have' | awk '{print $1}' || echo "0")

echo "  Processes with profiles: ${BOLD}${PROC_DEFINED}${NC}"
echo "  Processes enforced:      ${GREEN}${PROC_ENFORCE}${NC}"
echo "  Processes in complain:   ${YELLOW}${PROC_COMPLAIN}${NC}"

if [ "${PROC_UNCONFINED:-0}" -gt 0 ] 2>/dev/null; then
    print_warn "Processes unconfined but have a profile defined: ${PROC_UNCONFINED}"
    echo "  These processes are running under a profile set to unconfined."
fi

# ---- Complain Mode Profiles (attention needed) ----
if [ "${COMPLAIN:-0}" -gt 0 ] 2>/dev/null; then
    print_header "Profiles in Complain Mode (Review Needed)"
    echo "$AA_STATUS" | awk '/in complain mode:$/,/^$/' | grep -v 'in complain mode:' | grep -v '^$' | head -20 | while read -r line; do
        [ -n "$line" ] && print_warn "$line"
    done
fi

# ---- Snap Profiles ----
print_header "Snap AppArmor Profiles"

SNAP_PROFILE_DIR="/var/lib/snapd/apparmor/profiles"
if [ -d "$SNAP_PROFILE_DIR" ]; then
    SNAP_COUNT=$(ls "$SNAP_PROFILE_DIR" 2>/dev/null | wc -l)
    echo "  Snap profiles directory: $SNAP_PROFILE_DIR"
    echo "  Total snap profiles: ${SNAP_COUNT}"
    if [ "$SNAP_COUNT" -gt 0 ]; then
        echo "  Installed snaps with profiles:"
        ls "$SNAP_PROFILE_DIR" | grep '^snap\.' | sed 's/snap\.\([^.]*\)\..*/\1/' | sort -u | while read -r snap; do
            COUNT=$(ls "$SNAP_PROFILE_DIR" | grep "^snap\.${snap}\." | wc -l)
            echo "    - $snap ($COUNT profile(s))"
        done | head -15
    fi
else
    print_info "Snapd not installed or no snap profiles directory"
fi

# ---- Recent Denials ----
print_header "Recent Denials (Last 24 Hours)"

DENIAL_COUNT=$(journalctl --since="24 hours ago" 2>/dev/null | grep -c 'apparmor="DENIED"' || echo "0")

if [ "$DENIAL_COUNT" -eq 0 ]; then
    print_ok "No AppArmor denials in the last 24 hours"
else
    print_warn "${DENIAL_COUNT} AppArmor denial(s) in the last 24 hours"
    echo "  Run 02-denial-analysis.sh for details"
fi

# ---- Unprivileged Userns Restriction (Ubuntu 24.04+) ----
print_header "Unprivileged User Namespace Restriction"

USERNS_RESTRICT="/proc/sys/kernel/apparmor_restrict_unprivileged_userns"
if [ -f "$USERNS_RESTRICT" ]; then
    RESTRICT_VAL=$(cat "$USERNS_RESTRICT")
    if [ "$RESTRICT_VAL" -eq 1 ]; then
        print_ok "Unprivileged user namespace restriction is ACTIVE (value=1)"
        echo "  Applications need AppArmor 'userns' rule or connected snap interface"
    else
        print_warn "Unprivileged user namespace restriction is DISABLED (value=0)"
    fi
else
    print_info "Unprivileged user namespace restriction not available (pre-24.04 kernel)"
fi

# ---- AppArmor Version ----
print_header "AppArmor Version"

if command -v apparmor_parser &>/dev/null; then
    AA_VER=$(apparmor_parser --version 2>&1 | head -1)
    echo "  $AA_VER"
fi

echo ""
echo "Report complete. Use 02-denial-analysis.sh for denial details."
echo "Use 03-profile-audit.sh for profile inventory."
```

---

### Script 02 — Denial Analysis

```bash
#!/usr/bin/env bash
# =============================================================================
# 02-denial-analysis.sh
# AppArmor Denial Analysis
# Version: 1.0.0
# Targets Ubuntu 20.04+ with AppArmor enabled
# =============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

HOURS="${1:-24}"  # Default: last 24 hours; pass arg to override

print_header() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"; }
print_warn()   { echo -e "  ${YELLOW}[WARN]${NC}  $1"; }
print_info()   { echo -e "  ${CYAN}[INFO]${NC}  $1"; }

echo -e "${BOLD}AppArmor Denial Analysis${NC}"
echo "Generated: $(date)"
echo "Time window: Last ${HOURS} hours"
echo ""

# ---- Collect Denial Lines ----
DENIAL_LINES=$(journalctl --since="${HOURS} hours ago" 2>/dev/null | grep 'apparmor="DENIED"' || true)

DENIAL_COUNT=$(echo "$DENIAL_LINES" | grep -c 'apparmor="DENIED"' 2>/dev/null || echo "0")

if [ "$DENIAL_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}No AppArmor denials found in the last ${HOURS} hours.${NC}"
    exit 0
fi

echo -e "  ${RED}${BOLD}${DENIAL_COUNT} total denial event(s) found${NC}"

# ---- Top Denied Profiles ----
print_header "Top Denied Profiles"

echo "$DENIAL_LINES" | grep -oP 'profile="\K[^"]+' | sort | uniq -c | sort -rn | head -10 | \
while read -r count profile; do
    printf "  %5d  %s\n" "$count" "$profile"
done

# ---- Top Denied Operations ----
print_header "Top Denied Operations"

echo "$DENIAL_LINES" | grep -oP 'operation="\K[^"]+' | sort | uniq -c | sort -rn | head -10 | \
while read -r count op; do
    printf "  %5d  %s\n" "$count" "$op"
done

# ---- Top Denied Paths ----
print_header "Top Denied Paths (name field)"

echo "$DENIAL_LINES" | grep -oP 'name="\K[^"]+' | sort | uniq -c | sort -rn | head -15 | \
while read -r count path; do
    printf "  %5d  %s\n" "$count" "$path"
done

# ---- Top Denied Capabilities ----
print_header "Top Denied Capabilities"

CAP_LINES=$(echo "$DENIAL_LINES" | grep 'operation="capable"' || true)
if [ -n "$CAP_LINES" ]; then
    echo "$CAP_LINES" | grep -oP 'capname="\K[^"]+' | sort | uniq -c | sort -rn | head -10 | \
    while read -r count cap; do
        printf "  %5d  %s\n" "$count" "$cap"
    done
else
    echo "  No capability denials found"
fi

# ---- User Namespace Denials ----
print_header "User Namespace Denials (Ubuntu 24.04+)"

USERNS_LINES=$(echo "$DENIAL_LINES" | grep 'userns' || true)
if [ -n "$USERNS_LINES" ]; then
    print_warn "User namespace denials detected:"
    echo "$USERNS_LINES" | grep -oP 'profile="\K[^"]+' | sort | uniq -c | sort -rn | \
    while read -r count profile; do
        printf "  %5d  %s\n" "$count" "$profile"
        echo "         Fix: add 'userns,' to the profile, or connect snap interface"
    done
else
    echo "  No user namespace denials found"
fi

# ---- Recent Raw Denial Messages ----
print_header "Last 20 Raw Denial Messages"

echo "$DENIAL_LINES" | tail -20 | while read -r line; do
    # Extract key fields for readable output
    PROFILE=$(echo "$line" | grep -oP 'profile="\K[^"]+' || echo "unknown")
    OPER=$(echo "$line" | grep -oP 'operation="\K[^"]+' || echo "unknown")
    NAME=$(echo "$line" | grep -oP 'name="\K[^"]+' || echo "")
    COMM=$(echo "$line" | grep -oP 'comm="\K[^"]+' || echo "unknown")
    MASK=$(echo "$line" | grep -oP 'denied_mask="\K[^"]+' || echo "")
    TS=$(echo "$line" | awk '{print $1" "$2" "$3}')

    echo "  ${CYAN}[$TS]${NC}"
    echo "    Profile:  $PROFILE"
    echo "    Comm:     $COMM"
    echo "    Op:       $OPER"
    [ -n "$NAME" ] && echo "    Path:     $NAME"
    [ -n "$MASK" ] && echo "    Denied:   $MASK"
done

# ---- Suggested Remediation ----
print_header "Suggested Remediation Steps"

# Group by profile and suggest aa-logprof
PROFILES_WITH_DENIALS=$(echo "$DENIAL_LINES" | grep -oP 'profile="\K[^"]+' | sort -u)

if [ -n "$PROFILES_WITH_DENIALS" ]; then
    echo "  Profiles with denials in this time window:"
    echo ""
    while IFS= read -r profile; do
        PROFILE_COUNT=$(echo "$DENIAL_LINES" | grep -c "profile=\"${profile}\"" || echo "0")
        echo -e "  ${YELLOW}${profile}${NC} (${PROFILE_COUNT} denial(s))"

        # Determine profile file path
        PROFILE_FILE=$(find /etc/apparmor.d/ -maxdepth 1 -name "$(echo "$profile" | tr '/' '.')" 2>/dev/null | head -1)
        if [ -n "$PROFILE_FILE" ]; then
            echo "    Profile file: $PROFILE_FILE"
            echo "    To update:    sudo aa-logprof -f <(journalctl --since=\"${HOURS} hours ago\")"
            echo "    Or switch to complain: sudo aa-complain $PROFILE_FILE"
        elif echo "$profile" | grep -q '^snap\.'; then
            SNAP_NAME=$(echo "$profile" | sed 's/snap\.\([^.]*\)\..*/\1/')
            echo "    Snap profile: sudo snap connections $SNAP_NAME"
            echo "    Connect interface or review snap permissions"
        else
            echo "    Profile not found in /etc/apparmor.d/ — may be snap or dynamic profile"
        fi
        echo ""
    done <<< "$PROFILES_WITH_DENIALS"
fi

echo ""
echo "Run 'sudo aa-logprof' to interactively update profiles from log events."
echo "Run 'sudo aa-complain <profile>' to switch a profile to complain mode for safe debugging."
```

---

### Script 03 — Profile Audit

```bash
#!/usr/bin/env bash
# =============================================================================
# 03-profile-audit.sh
# AppArmor Profile Inventory and Audit
# Version: 1.0.0
# Targets Ubuntu 20.04+ with AppArmor enabled
# =============================================================================

set -uo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_header() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"; }
print_ok()     { echo -e "  ${GREEN}[OK]${NC}    $1"; }
print_warn()   { echo -e "  ${YELLOW}[WARN]${NC}  $1"; }
print_info()   { echo -e "  ${CYAN}[INFO]${NC}  $1"; }

PROFILE_DIR="/etc/apparmor.d"
SNAP_PROFILE_DIR="/var/lib/snapd/apparmor/profiles"
DISABLE_DIR="${PROFILE_DIR}/disable"
LOCAL_DIR="${PROFILE_DIR}/local"

echo -e "${BOLD}AppArmor Profile Audit Report${NC}"
echo "Generated: $(date)"
echo "Host: $(hostname -f 2>/dev/null || hostname)"

# ---- Collect aa-status output ----
AA_STATUS=$(sudo aa-status 2>/dev/null)

ENFORCE_LIST=$(echo "$AA_STATUS" | awk '/in enforce mode:$/,/^$/' | grep -v 'in enforce mode:' | grep -v '^$' | sed 's/^[[:space:]]*//')
COMPLAIN_LIST=$(echo "$AA_STATUS" | awk '/in complain mode:$/,/^$/' | grep -v 'in complain mode:' | grep -v '^$' | sed 's/^[[:space:]]*//')

# ---- Profile Inventory ----
print_header "Profile Inventory"

ENFORCE_COUNT=$(echo "$ENFORCE_LIST" | grep -c . 2>/dev/null || echo "0")
COMPLAIN_COUNT=$(echo "$COMPLAIN_LIST" | grep -c . 2>/dev/null || echo "0")
TOTAL_LOADED=$(( ENFORCE_COUNT + COMPLAIN_COUNT ))

echo "  Profiles loaded (enforce):  ${GREEN}${ENFORCE_COUNT}${NC}"
echo "  Profiles loaded (complain): ${YELLOW}${COMPLAIN_COUNT}${NC}"
echo "  Total profiles loaded:      ${BOLD}${TOTAL_LOADED}${NC}"

# Count profiles on disk
DISK_COUNT=$(find "$PROFILE_DIR" -maxdepth 1 -type f ! -name '*.dpkg-*' ! -name '*.rpmsave' | wc -l)
DISABLED_COUNT=$(find "$DISABLE_DIR" -type f 2>/dev/null | wc -l)
LOCAL_COUNT=$(find "$LOCAL_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l)

echo "  Profiles on disk:           ${DISK_COUNT}"
echo "  Disabled profiles:          ${DISABLED_COUNT}"
echo "  Local customizations:       ${LOCAL_COUNT}"

# ---- Disabled Profiles ----
print_header "Disabled Profiles"

if [ "$DISABLED_COUNT" -gt 0 ]; then
    print_warn "${DISABLED_COUNT} profile(s) are disabled:"
    find "$DISABLE_DIR" -type f 2>/dev/null | while read -r f; do
        echo "  - $(basename "$f")"
    done
else
    print_ok "No disabled profiles"
fi

# ---- Profiles in Complain Mode ----
print_header "Profiles in Complain Mode"

if [ "$COMPLAIN_COUNT" -gt 0 ]; then
    print_warn "${COMPLAIN_COUNT} profile(s) in complain mode (not enforced):"
    echo "$COMPLAIN_LIST" | grep -v '^$' | while read -r profile; do
        echo "  - $profile"
    done | head -30
    echo ""
    echo "  To enforce all complain-mode profiles:"
    echo "    sudo aa-enforce /etc/apparmor.d/*"
else
    print_ok "No profiles in complain mode"
fi

# ---- Profile Syntax Check ----
print_header "Profile Syntax Check"

ERROR_COUNT=0
echo "  Checking profiles in $PROFILE_DIR..."
find "$PROFILE_DIR" -maxdepth 1 -type f ! -name '*.dpkg-*' ! -name '*.rpmsave' ! -name '*.orig' | sort | while read -r profile_file; do
    if ! sudo apparmor_parser --preprocess "$profile_file" >/dev/null 2>&1; then
        print_warn "Syntax error in: $profile_file"
        sudo apparmor_parser --preprocess "$profile_file" 2>&1 | grep -i 'error\|warning' | head -3 | sed 's/^/    /'
        ERROR_COUNT=$(( ERROR_COUNT + 1 ))
    fi
done

if [ "$ERROR_COUNT" -eq 0 ]; then
    print_ok "All profiles parsed without errors"
fi

# ---- Unmerged Package Updates ----
print_header "Unmerged Profile Updates"

DPKG_NEW=$(find "$PROFILE_DIR" -name '*.dpkg-new' 2>/dev/null)
if [ -n "$DPKG_NEW" ]; then
    print_warn "Unmerged package profile updates found:"
    echo "$DPKG_NEW" | while read -r f; do
        echo "  $f"
        echo "  Review with: diff $(echo "$f" | sed 's/\.dpkg-new$//') $f"
    done
else
    print_ok "No unmerged profile updates (.dpkg-new files)"
fi

# ---- Custom vs Shipped Profiles ----
print_header "Custom vs Shipped Profiles"

echo "  Identifying custom profiles (not from packages)..."
CUSTOM_COUNT=0
find "$PROFILE_DIR" -maxdepth 1 -type f ! -name '*.dpkg-*' | while read -r f; do
    BASENAME=$(basename "$f")
    # Check if the file belongs to a package
    PKG=$(dpkg -S "$f" 2>/dev/null | cut -d: -f1 || true)
    if [ -z "$PKG" ]; then
        echo "  ${CYAN}[CUSTOM]${NC} $BASENAME"
        CUSTOM_COUNT=$(( CUSTOM_COUNT + 1 ))
    fi
done

# ---- Unconfined Processes That Could Be Confined ----
print_header "Unconfined Network-Listening Processes"

echo "  Checking for unconfined processes with open ports..."
echo "  (These processes have no AppArmor profile and listen on the network)"
echo ""

# Get all network-listening PIDs
SS_OUTPUT=$(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "")

if [ -n "$SS_OUTPUT" ]; then
    echo "$SS_OUTPUT" | grep -oP 'pid=\K\d+' 2>/dev/null | sort -u | while read -r pid; do
        [ -z "$pid" ] && continue
        PROC_AA=$(cat "/proc/${pid}/attr/current" 2>/dev/null || echo "unconfined")
        COMM=$(cat "/proc/${pid}/comm" 2>/dev/null || echo "unknown")
        EXE=$(readlink -f "/proc/${pid}/exe" 2>/dev/null || echo "unknown")
        if echo "$PROC_AA" | grep -q 'unconfined'; then
            printf "  ${YELLOW}%-20s${NC} PID:%-6s Exe: %s\n" "$COMM" "$pid" "$EXE"
        fi
    done
fi

# ---- Snap Profile Coverage ----
print_header "Snap Profile Coverage"

if command -v snap &>/dev/null; then
    INSTALLED_SNAPS=$(snap list 2>/dev/null | tail -n +2 | awk '{print $1}' || echo "")
    if [ -n "$INSTALLED_SNAPS" ]; then
        echo "  Installed snaps and their AppArmor confinement:"
        echo ""
        snap list 2>/dev/null | tail -n +2 | awk '{print $1, $NF}' | while read -r snap_name confinement; do
            SNAP_PROFILES=$(ls "$SNAP_PROFILE_DIR"/snap."${snap_name}".* 2>/dev/null | wc -l)
            case "$confinement" in
                strict)
                    printf "  ${GREEN}%-25s${NC} strict    (%d profile(s))\n" "$snap_name" "$SNAP_PROFILES"
                    ;;
                classic)
                    printf "  ${YELLOW}%-25s${NC} classic   (no AppArmor restriction)\n" "$snap_name"
                    ;;
                devmode)
                    printf "  ${RED}%-25s${NC} devmode   (AppArmor not enforced)\n" "$snap_name"
                    ;;
                *)
                    printf "  ${CYAN}%-25s${NC} %-9s (%d profile(s))\n" "$snap_name" "$confinement" "$SNAP_PROFILES"
                    ;;
            esac
        done
    else
        print_info "No snaps installed"
    fi
else
    print_info "snap command not available"
fi

# ---- Local Customizations ----
print_header "Local Profile Customizations"

if [ "$LOCAL_COUNT" -gt 0 ]; then
    echo "  Local additions in $LOCAL_DIR:"
    find "$LOCAL_DIR" -maxdepth 1 -type f 2>/dev/null | while read -r f; do
        LINES=$(wc -l < "$f" 2>/dev/null || echo "0")
        # Count non-comment, non-blank rules
        RULES=$(grep -v '^\s*#' "$f" 2>/dev/null | grep -v '^\s*$' | wc -l || echo "0")
        printf "  %-40s  %3d rule(s)\n" "$(basename "$f")" "$RULES"
    done
else
    print_info "No local customizations in $LOCAL_DIR"
    echo "  Tip: Add site-local profile rules to $LOCAL_DIR/<profile-name>"
    echo "       These survive package upgrades."
fi

# ---- Summary ----
print_header "Audit Summary"

echo "  Profile counts:"
echo "    Enforce:    ${ENFORCE_COUNT}"
echo "    Complain:   ${COMPLAIN_COUNT}"
echo "    Disabled:   ${DISABLED_COUNT}"
echo "    Local mods: ${LOCAL_COUNT}"
echo ""

if [ "$COMPLAIN_COUNT" -gt 0 ]; then
    print_warn "Action: ${COMPLAIN_COUNT} profile(s) in complain mode — review logs and enforce when stable"
fi
if [ "$DISABLED_COUNT" -gt 0 ]; then
    print_warn "Action: ${DISABLED_COUNT} profile(s) disabled — ensure this is intentional"
fi

echo ""
echo "Run 01-apparmor-status.sh for a quick status overview."
echo "Run 02-denial-analysis.sh to analyze active denials."
```

---

## Part 5: Version Changes

### Ubuntu 20.04 LTS — AppArmor 2.13

- **AppArmor version:** 2.13.x
- **Kernel:** 5.4 LTS with AppArmor LSM
- **Default profiles shipped:** mysqld, named, ntpd, tcpdump, avahi-daemon, cups, evince, lxc-container-default
- **Notable:** Firefox still shipped as deb with AppArmor profile `usr.bin.firefox`
- **Snap AppArmor:** Snapd 2.44+ managing snap profiles; Firefox transition to snap beginning
- **Userns restriction:** Not present; `/proc/sys/kernel/apparmor_restrict_unprivileged_userns` not available
- **Profile stacking:** Basic stacking support but limited tooling
- **Container integration:** LXD 4.x with AppArmor namespace support

Key defaults in 20.04:
```bash
# AppArmor service
sudo systemctl status apparmor

# Profile cache location
/etc/apparmor.d/cache/
```

---

### Ubuntu 22.04 LTS — AppArmor 3.0

- **AppArmor version:** 3.0.x
- **Kernel:** 5.15 LTS
- **Changes from 2.13:**
  - Improved container profiles with better LXD/LXC integration
  - Signal and D-Bus mediation improvements
  - Kill mode added (process killed immediately on denial, not just denied)
  - Improved profile stacking syntax and tooling
  - Firefox fully transitioned to snap; `usr.bin.firefox` profile replaced by snap-managed profile
  - Better `aa-notify` desktop integration
- **Snap AppArmor:** Snapd 2.54+ with improved interface-to-AppArmor rule mapping
- **Userns restriction:** Not yet enforced by default
- **ABI versioning:** Profiles can declare `abi <abi/3.0>` for version-specific syntax

Notable 22.04 profile changes:
```bash
# Profiles gained abi declarations
abi <abi/3.0>,

# Kill mode syntax
profile myapp /usr/bin/myapp flags=(kill) {
    ...
}
```

---

### Ubuntu 24.04 LTS — AppArmor 4.0

- **AppArmor version:** 4.0.x
- **Kernel:** 6.8 LTS
- **Major changes:**

**Unprivileged User Namespace Restriction (most significant)**
- New sysctl: `kernel.apparmor_restrict_unprivileged_userns=1` (default enabled)
- Breaks rootless containers, browser sandboxing without explicit exceptions
- Per-application `userns,` rule in profiles grants exception
- `/proc/sys/kernel/apparmor_restrict_unprivileged_userns` controls system-wide default

**Profile Stacking improvements**
- Full profile stacking support with cleaner tooling
- Namespace-aware stacking for container workloads
- `aa-status` shows stacked profile combinations

**ABI 4.0**
- Profiles declare `abi <abi/4.0>`
- New `userns` permission keyword
- Improved `mount` mediation

**Snap integration improvements**
- Snapd 2.61+ with updated interface AppArmor rule sets
- Better handling of new snap interfaces for Wayland, Pipewire

Key 24.04 migration steps:
```bash
# Check if userns restriction is causing issues
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep userns

# Grant userns to a specific application
# In /etc/apparmor.d/local/usr.bin.myapp:
userns,

# Or system-wide disable (not recommended)
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

---

### Ubuntu 26.04 LTS — AppArmor 4.x (Projected)

- **Kernel:** 6.14+ (anticipated)
- **AppArmor version:** 4.x series continuation
- **Expected improvements:**
  - Expanded `io_uring` mediation (io_uring operations as first-class AppArmor permissions)
  - Improved eBPF program mediation
  - Better Wayland compositor confinement rules
  - Landlock integration or co-mediation (Landlock LSM + AppArmor stacking)
  - Improved `aa-genprof` / `aa-logprof` tooling with better glob analysis
  - Unified snap/system profile namespace tooling
  - Potential: AppArmor policy compiler performance improvements for large snap ecosystems

Note: Ubuntu 26.04 information is projected based on upstream AppArmor development trajectory as of early 2026; specifics will vary.

---

## Quick Reference

### Essential Commands

```bash
# Status
sudo aa-status                              # Full status
sudo aa-status --enabled                    # Just check if enabled

# Mode changes
sudo aa-enforce /etc/apparmor.d/<profile>   # Enable enforcement
sudo aa-complain /etc/apparmor.d/<profile>  # Set to complain (learning) mode
sudo aa-disable /etc/apparmor.d/<profile>   # Disable (unconfined)

# Profile operations
sudo apparmor_parser -r /etc/apparmor.d/<profile>   # Reload profile
sudo apparmor_parser -R /etc/apparmor.d/<profile>   # Remove from kernel
sudo apparmor_parser --preprocess <profile>          # Syntax check

# Profile development
sudo aa-genprof /path/to/binary             # Generate new profile interactively
sudo aa-logprof                             # Update profiles from log events

# Denial analysis
sudo journalctl -xe | grep 'apparmor="DENIED"'
sudo dmesg | grep 'apparmor="DENIED"'
sudo grep 'apparmor="DENIED"' /var/log/syslog

# Service management
sudo systemctl restart apparmor             # Reload all profiles
sudo systemctl status apparmor

# Snap-specific
snap connections <snap-name>               # View snap interface connections
sudo snap connect <snap>:<interface> :<interface>  # Connect snap interface
```

### Key File Locations

| Path | Purpose |
|------|---------|
| `/etc/apparmor.d/` | Profile directory |
| `/etc/apparmor.d/abstractions/` | Reusable rule snippets |
| `/etc/apparmor.d/tunables/` | Site-configurable variables |
| `/etc/apparmor.d/local/` | Local profile additions (upgrade-safe) |
| `/etc/apparmor.d/disable/` | Disabled profile links |
| `/etc/apparmor.d/cache/` | Compiled profile cache |
| `/var/lib/snapd/apparmor/profiles/` | Snap-managed profiles |
| `/var/log/syslog` | System log (AppArmor denials) |
| `/proc/sys/kernel/apparmor_restrict_unprivileged_userns` | Userns restriction sysctl |
