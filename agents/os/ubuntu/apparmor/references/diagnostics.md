# AppArmor Diagnostics Reference

## Denial Analysis

### Log Locations

AppArmor denials appear in multiple locations. Check all relevant sources:

```bash
# Primary: systemd journal (all Ubuntu versions 20.04+)
sudo journalctl -xe | grep 'apparmor="DENIED"'
journalctl --since="1 hour ago" | grep apparmor

# Kernel ring buffer (recent denials, volatile -- lost on reboot)
sudo dmesg | grep 'apparmor="DENIED"'

# Syslog (if rsyslog is running)
sudo grep 'apparmor="DENIED"' /var/log/syslog
sudo grep 'apparmor="DENIED"' /var/log/kern.log

# Audit log (if auditd is running)
sudo grep 'apparmor="DENIED"' /var/log/audit/audit.log
```

### Anatomy of a Denial Message

```
audit: type=1400 audit(1712345678.123:456): apparmor="DENIED" operation="open"
  profile="usr.sbin.mysqld" name="/data/mysql/custom.cnf" pid=1234
  comm="mysqld" requested_mask="r" denied_mask="r" fsuid=999 ouid=0
```

| Field | Meaning |
|-------|---------|
| `apparmor="DENIED"` | Enforcement decision (DENIED = blocked, ALLOWED = complain mode) |
| `operation="open"` | Kernel operation attempted |
| `profile="usr.sbin.mysqld"` | AppArmor profile that made the decision |
| `name="/data/mysql/custom.cnf"` | Resource path accessed |
| `pid=1234` | Process ID |
| `comm="mysqld"` | Process command name |
| `requested_mask="r"` | Permission the process requested |
| `denied_mask="r"` | Permission that was denied |
| `fsuid=999` | Filesystem UID of the process |
| `ouid=0` | Owner UID of the target file |

### Common Operation Values

- `open`, `read`, `write` -- file operations
- `exec` -- program execution
- `connect`, `bind`, `listen` -- network operations
- `create`, `unlink`, `rename` -- filesystem modification
- `mknod` -- device file creation
- `mount`, `umount` -- mount operations
- `signal` -- signal delivery
- `dbus_method_call` -- D-Bus method invocation
- `capable` -- Linux capability check (capname field identifies which)

### Mapping Denials to Profile Rules

| Denial Field | Profile Rule Type |
|-------------|-------------------|
| `operation="open"` with `denied_mask="r"` | File read rule: `/path r,` |
| `operation="open"` with `denied_mask="w"` | File write rule: `/path w,` |
| `operation="exec"` | Execute rule: `/path ix,` or `/path px,` |
| `operation="connect"` | Network rule: `network tcp,` |
| `operation="capable"` with `capname="..."` | Capability rule: `capability <name>,` |
| `operation="signal"` | Signal rule: `signal (send) set=(...) peer=...,` |
| `operation="mount"` | Mount rule: `mount options=(...) ...` |
| `operation="dbus_method_call"` | D-Bus rule: `dbus (send) bus=...` |

## Troubleshooting Workflow

### Standard Diagnosis Flow

```
1. Check overall AppArmor status
   sudo aa-status
   -- Is AppArmor loaded? How many profiles enforcing vs complain?

2. Find recent denials for the affected process
   sudo journalctl -xe | grep apparmor | grep DENIED | grep 'comm="myapp"'
   -- Or filter by profile name: grep 'profile="myapp"'

3. Identify the profile and denied resource
   -- Parse: profile name, operation, name (path), requested_mask

4. Switch profile to complain mode for safe analysis
   sudo aa-complain /etc/apparmor.d/usr.sbin.myapp

5. Reproduce the problem
   -- Denials become ALLOWEDs in complain mode
   -- Exercise the failing operation

6. Run aa-logprof to generate proposed rule additions
   sudo aa-logprof

7. Review and accept proposed rules
   -- Be conservative: do not accept overly broad globs
   -- Prefer /specific/path/** over /**

8. Reload the profile
   sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp

9. Switch back to enforce mode
   sudo aa-enforce /etc/apparmor.d/usr.sbin.myapp

10. Test that the problem is resolved and no new denials appear
    sudo journalctl -f | grep apparmor
```

### Quick Denial Triage

For rapid initial assessment without switching to complain mode:

```bash
# 1. Count recent denials by profile
sudo journalctl --since="1 hour ago" | grep 'apparmor="DENIED"' | \
    grep -oP 'profile="\K[^"]+' | sort | uniq -c | sort -rn

# 2. Show denied paths for a specific profile
sudo journalctl --since="1 hour ago" | grep 'apparmor="DENIED"' | \
    grep 'profile="usr.sbin.mysqld"' | \
    grep -oP 'name="\K[^"]+' | sort -u

# 3. Show denied operations for a specific profile
sudo journalctl --since="1 hour ago" | grep 'apparmor="DENIED"' | \
    grep 'profile="usr.sbin.mysqld"' | \
    grep -oP 'operation="\K[^"]+' | sort | uniq -c | sort -rn

# 4. Check for capability denials
sudo dmesg | grep 'apparmor="DENIED"' | grep 'operation="capable"' | \
    grep -oP 'capname="\K[^"]+'
```

### Live Denial Monitoring

```bash
# Watch for denials in real time
sudo journalctl -f | grep 'apparmor="DENIED"'

# Watch with filtering for a specific application
sudo journalctl -f | grep 'apparmor="DENIED"' | grep 'comm="myapp"'

# Desktop notifications (if apparmor-notify is installed)
aa-notify -p    # Show as popup notifications
aa-notify -s 1  # Show denials from last 1 day
```

## Common Issues and Fixes

### Application Cannot Access File

**Symptom:** Application fails with "Permission denied" despite correct file ownership and UNIX permissions.

**Diagnosis:**
```bash
sudo journalctl -xe | grep apparmor | grep DENIED | tail -20
# Look for: operation="open" name="/path/to/file" denied_mask="r"
```

**Fix:** Add the path to the local profile addition:
```bash
# /etc/apparmor.d/local/usr.sbin.myapp
/custom/data/dir/** r,
/custom/data/dir/*.conf r,
```
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
```

### Network Access Denied

**Symptom:** Application cannot open network connections or bind ports.

**Diagnosis:**
```bash
sudo dmesg | grep apparmor | grep 'operation="connect"'
# or: denied_mask="send receive" for UDP
```

**Fix:** Add network rules to the profile:
```
network tcp,                          # Allow all TCP
network inet stream,                  # Allow IPv4 TCP only
capability net_bind_service,          # Allow binding ports < 1024
```

### Snap Cannot Access Resource

**Symptom:** Snap application fails to access home directory, removable media, camera, etc.

**Diagnosis:**
```bash
snap connections <snap-name>          # Show connected interfaces
journalctl | grep "snap.<snap-name>"  # Find snap-specific denials
```

**Fix:** Connect the appropriate snap interface:
```bash
sudo snap connect firefox:home :home
sudo snap connect myapp:removable-media :removable-media
sudo snap connect myapp:camera :camera
```

### User Namespace Denied (Ubuntu 24.04+)

**Symptom:** Application crashes or sandbox fails. Browser shows "sandbox not available" warning. Rootless container tools fail.

**Diagnosis:**
```bash
sudo journalctl -xe | grep 'apparmor="DENIED"' | grep userns
sudo dmesg | grep 'apparmor="DENIED"' | grep userns
cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns
```

**Fix (per-application):**
```bash
# /etc/apparmor.d/local/usr.bin.myapp
userns,
```
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.myapp
```

**Fix (system-wide, not recommended):**
```bash
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
```

### Custom Application Needs Profile

**Symptom:** New application deployed with no AppArmor profile; running unconfined.

**Fix:**
```bash
sudo aa-genprof /usr/local/bin/myapp
# Follow interactive prompts
# Exercise all application functionality in another terminal
# Press S to scan, approve rules, press F to finish
sudo aa-enforce /etc/apparmor.d/myapp
```

### Profile Errors on Load

**Symptom:** `apparmor_parser -r` fails with syntax error.

**Diagnosis:**
```bash
# Check syntax without loading
sudo apparmor_parser --preprocess /etc/apparmor.d/usr.sbin.myapp

# View detailed errors
sudo apparmor_parser -d /etc/apparmor.d/usr.sbin.myapp 2>&1 | head -30
```

Common syntax causes:
- Missing comma at end of rule
- Unmatched braces
- Invalid glob pattern
- ABI mismatch (using 4.0 syntax on 3.0 parser)

### Profile Conflicts After Package Update

**Symptom:** Profile behavior changes after `apt upgrade`. New `.dpkg-new` files appear.

**Diagnosis:**
```bash
ls /etc/apparmor.d/*.dpkg-new
diff /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/usr.sbin.mysqld.dpkg-new
```

**Fix:** Merge changes, then reload:
```bash
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
```

**Prevention:** Keep all local changes in `/etc/apparmor.d/local/` to avoid conflicts entirely.

### Process Running Unconfined Despite Having a Profile

**Symptom:** `aa-status` shows "processes are unconfined but have a profile defined."

**Causes:**
- Process started before the profile was loaded
- Profile was loaded after the process started (not retroactive)
- Profile is in the `disable/` directory

**Fix:**
```bash
# Ensure profile is loaded
sudo apparmor_parser -r /etc/apparmor.d/<profile>

# Restart the process to pick up the profile
sudo systemctl restart <service>

# Verify
sudo aa-status | grep <process-name>
```

### Complain Mode Denials Not Appearing in Logs

**Symptom:** Profile is in complain mode but no log entries for expected accesses.

**Causes:**
- Log rate limiting (kernel suppresses repeated messages)
- Logging going to a different facility than expected
- Profile actually does allow the access (no denial to log)

**Fix:**
```bash
# Check all log sources
sudo journalctl --since="10 min ago" | grep apparmor
sudo dmesg | grep apparmor
sudo grep apparmor /var/log/syslog /var/log/kern.log 2>/dev/null

# Disable rate limiting temporarily
sudo sysctl -w kernel.printk_ratelimit=0
# Remember to re-enable: sudo sysctl -w kernel.printk_ratelimit=5
```

## Diagnostic Commands Quick Reference

```bash
# Status overview
sudo aa-status                              # Full status
sudo aa-status --enabled                    # Boolean: is AppArmor enabled?

# Per-process profile
cat /proc/<pid>/attr/current               # Profile for a specific PID

# Denial search
sudo journalctl -xe | grep 'apparmor="DENIED"'
sudo dmesg | grep 'apparmor="DENIED"'

# Profile syntax check (no load)
sudo apparmor_parser --preprocess /etc/apparmor.d/<profile>

# Reload profile
sudo apparmor_parser -r /etc/apparmor.d/<profile>

# Mode changes
sudo aa-complain /etc/apparmor.d/<profile>  # Safe debugging
sudo aa-enforce /etc/apparmor.d/<profile>   # Re-enable enforcement

# Profile development
sudo aa-logprof                             # Update from logs
sudo aa-genprof /path/to/binary             # Generate new profile

# Snap diagnostics
snap connections <snap-name>
sudo journalctl | grep "snap.<snap-name>" | grep DENIED
```
