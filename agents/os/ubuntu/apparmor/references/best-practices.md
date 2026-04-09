# AppArmor Best Practices Reference

## Profile Creation Workflow

### aa-genprof -- Generate a New Profile

`aa-genprof` is the recommended starting point for new profiles. It runs the application, monitors accesses, and interactively builds a profile.

```bash
# Install required tools
sudo apt install apparmor-utils

# Generate profile for a new application
sudo aa-genprof /usr/local/bin/myapp
```

aa-genprof workflow:
1. Creates a minimal profile and puts the app in complain mode
2. Prompts you to run the application in another terminal
3. You exercise all application functionality (normal operations, edge cases)
4. Press `S` to scan logs for new access patterns
5. Interactively allow/deny each detected access
6. Press `F` to finish -- profile saved to `/etc/apparmor.d/`
7. Profile is loaded in complain mode for further testing

Interactive choices during aa-genprof:
- `(A)llow` -- add the access to the profile
- `(D)eny` -- explicitly deny (adds deny rule)
- `(I)gnore` -- skip this event
- `(N)ew` -- enter a custom rule manually
- `(G)lob` -- generalize the path pattern (e.g., `/var/log/myapp/foo.log` becomes `/var/log/myapp/*`)
- `(Q)uit` -- exit without saving

### aa-logprof -- Update Existing Profile from Logs

After a profile is deployed in complain mode and the application runs, `aa-logprof` reads accumulated log entries and proposes profile additions:

```bash
# Update profiles based on accumulated log events
sudo aa-logprof

# Update using a specific log file
sudo aa-logprof -f /var/log/syslog

# Process older rotated logs
sudo aa-logprof -f /var/log/syslog.1
```

### Recommended Workflow for New Applications

1. Write minimal profile or run `sudo aa-genprof /path/to/binary`
2. Set to complain mode: `sudo aa-complain /etc/apparmor.d/myapp`
3. Run application through all use cases (normal operation, edge cases, error paths)
4. Run `sudo aa-logprof` to incorporate missing rules
5. Review proposed changes -- use glob patterns judiciously, prefer specific paths
6. Set to enforce: `sudo aa-enforce /etc/apparmor.d/myapp`
7. Monitor for denials: `sudo journalctl -f | grep apparmor`
8. Iterate if new denials appear (add rules via local additions)

### Manual Profile Writing Best Practices

- Always start with `#include <abstractions/base>` -- provides glibc, locale, /dev/null
- Use `#include <abstractions/nameservice>` if the app does DNS or user lookups
- Prefer specific paths over broad globs where possible
- Use `/** r,` sparingly -- prefer `/specific/dir/** r,`
- Never use `/** rwx,` in production profiles
- Add explicit `deny` rules for sensitive paths even if not technically needed (defense in depth)
- Use `@{PROC}` and `@{SYS}` tunables instead of hardcoded `/proc/` and `/sys/`
- Test with `apparmor_parser --preprocess` to check syntax before loading
- Always include `#include <local/profile-name>` at the end for site-local additions

## Profile Management

### apparmor_parser -- Core Profile Tool

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

### Profile Caching

AppArmor compiles profiles to binary DFA at load time. Caching stores compiled output to speed up boot.

Cache locations:
- Ubuntu 20.04/22.04: `/etc/apparmor.d/cache/`
- Ubuntu 24.04+: `/var/cache/apparmor/` (systemd-based)

Cache invalidation is automatic when profile mtime or AppArmor version changes. Manual invalidation:
```bash
sudo rm -rf /etc/apparmor.d/cache/*     # 20.04/22.04
sudo rm -rf /var/cache/apparmor/*       # 24.04+
sudo systemctl restart apparmor
```

### Boot-Time Profile Loading

Profiles are loaded at boot by `apparmor.service`:

```bash
sudo systemctl status apparmor      # Check service status
sudo systemctl restart apparmor     # Reload all profiles
sudo systemctl enable apparmor      # Ensure enabled at boot
sudo service apparmor reload        # Reload without restart
```

Profiles in `/etc/apparmor.d/disable/` are excluded from loading.

### Directory Structure

```
/etc/apparmor.d/
+-- abstractions/          # Reusable rule snippets
|   +-- base
|   +-- nameservice
|   +-- ssl_certs
+-- tunables/              # Site-configurable variables
|   +-- global
|   +-- home.d/
+-- cache/                 # Compiled profile cache (20.04/22.04)
+-- disable/               # Disabled profiles (symlinks)
+-- force-complain/        # Forced complain overrides
+-- local/                 # Site-local profile additions
|   +-- usr.sbin.mysqld
+-- usr.sbin.mysqld        # MySQL profile
+-- usr.sbin.named         # BIND profile
+-- usr.sbin.sshd          # SSH daemon profile
```

### Local Profile Additions (Upgrade-Safe Customization)

The `/etc/apparmor.d/local/` directory provides site-specific additions without modifying shipped profiles. Shipped profiles include a line like:
```
#include <local/usr.sbin.mysqld>
```

Add custom rules to `/etc/apparmor.d/local/usr.sbin.mysqld`:
```
# Site-local MySQL additions
/mnt/datadisk/mysql/** rwk,
/backup/mysql/** rw,
```

These survive package upgrades. This is the preferred method for all customization.

After editing a local addition, reload the parent profile:
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
```

## Common Profiles Shipped with Ubuntu

### Database and Service Profiles

- `usr.sbin.mysqld` -- MySQL/MariaDB server; covers `/var/lib/mysql/`, `/etc/mysql/`, `/run/mysqld/`
- `usr.sbin.named` -- BIND DNS server; covers `/etc/bind/`, `/var/cache/bind/`
- `usr.sbin.ntpd` -- NTP daemon; covers `/etc/ntp.conf`, `/var/lib/ntp/`
- `usr.sbin.sshd` -- SSH daemon (complain by default in some versions)

### Web and Application Profiles

- `usr.sbin.apache2` -- Apache HTTP Server (via apache2-utils package)
- Firefox -- snap-managed profile at `/var/lib/snapd/apparmor/profiles/snap.firefox.firefox` (22.04+)

### Virtualization Profiles

- `usr.lib.libvirt.virt-aa-helper` -- libvirt's AppArmor helper for per-VM profiles
- `usr.sbin.libvirtd` -- libvirt daemon
- `lxc-container-default` / `lxc-container-default-cgns` -- LXC container profiles

Each VM/container gets a dynamically-generated profile constraining what the process can do, even as root within the container.

## Unprivileged User Namespace Configuration

### Understanding the Restriction (Ubuntu 24.04+)

The sysctl `kernel.apparmor_restrict_unprivileged_userns` defaults to 1 on Ubuntu 24.04+. This blocks unprivileged processes from creating user namespaces unless explicitly allowed.

### Per-Application Exception (Recommended)

Add the `userns,` rule to the application's profile or local addition:

```bash
# /etc/apparmor.d/local/usr.bin.myapp
userns,
```

Or create a dedicated profile:
```
abi <abi/4.0>,
profile myapp /usr/bin/myapp {
    #include <abstractions/base>
    userns,
    # ... other rules
}
```

Reload: `sudo apparmor_parser -r /etc/apparmor.d/usr.bin.myapp`

### System-Wide Disable (Not Recommended)

```bash
# Temporary (resets on reboot)
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0

# Persistent
echo 'kernel.apparmor_restrict_unprivileged_userns=0' | \
    sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl -p /etc/sysctl.d/99-userns.conf
```

### Diagnosing Userns Issues

```bash
# Check if restriction is active
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns

# Find userns denials
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep userns
sudo dmesg | grep 'apparmor="DENIED"' | grep userns
```

## Profile Development Tips

### Glob Pattern Guidelines

| Pattern | Matches | Use When |
|---------|---------|----------|
| `/etc/mysql/*.cnf` | Single-level .cnf files | Known config file extension |
| `/etc/mysql/**` | All files recursively | Entire config tree needed |
| `/var/log/myapp/*.log` | Log files in one directory | Predictable log names |
| `/var/log/myapp/**` | All log files recursively | Nested log directories |
| `/tmp/myapp.*` | Temp files with prefix | Application creates temp files |

Avoid:
- `/** rw,` -- grants read/write to entire filesystem
- `/home/** rw,` -- grants access to all user data
- `/proc/** r,` -- use `@{PROC}` tunable and specific proc paths

### Deny Rules for Defense in Depth

Even if a path is not in the allow list (and therefore already denied), explicit deny rules serve two purposes:
1. They prevent future glob expansions from accidentally granting access
2. They document security intent

```
# Explicit denials for sensitive paths
deny /etc/shadow r,
deny /etc/gshadow r,
deny /root/** rwx,
deny @{HOME}/.ssh/** rwx,
```

### ABI Declarations

Starting with Ubuntu 22.04 (AppArmor 3.0), profiles can declare ABI compatibility:

```
abi <abi/3.0>,    # Ubuntu 22.04
abi <abi/4.0>,    # Ubuntu 24.04+
```

ABI declarations affect how the parser interprets rules. Use the ABI matching your target Ubuntu version.

### Profile Conflict Resolution After Package Updates

When a package upgrade ships a new profile, conflicts can arise:

```bash
# Check for unmerged updates
ls /etc/apparmor.d/*.dpkg-new

# Compare and merge
diff /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/usr.sbin.mysqld.dpkg-new

# After merging, reload
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
```

Best practice: keep all local changes in `/etc/apparmor.d/local/` to avoid merge conflicts entirely.
