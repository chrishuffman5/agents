# SELinux Diagnostics Reference

## AVC Denial Analysis

### Audit Log Location and Structure

AVC denials are written to `/var/log/audit/audit.log` by `auditd`. If `setroubleshoot` is installed, human-readable summaries also go to `/var/log/messages`.

Raw AVC message format:
```
type=AVC msg=audit(1712345678.123:456): avc: denied { read } for pid=12345
  comm="httpd" name="secret.txt" dev="sda1" ino=98765
  scontext=system_u:system_r:httpd_t:s0
  tcontext=user_u:object_r:user_home_t:s0
  tclass=file permissive=0
```

Key fields:
- `{ read }` -- the permission requested
- `comm` -- the command/process name
- `scontext` -- source security context (the process)
- `tcontext` -- target security context (the object)
- `tclass` -- object class (`file`, `dir`, `tcp_socket`, etc.)
- `permissive=0` -- 0 means enforcing (access denied), 1 means permissive (access allowed but logged)

### ausearch -- Query the Audit Log

```bash
# Recent AVC denials (last 10 minutes)
ausearch -m AVC -ts recent

# AVC denials in the last 24 hours
ausearch -m AVC -ts today

# Specific time range
ausearch -m AVC -ts "04/08/2026 08:00:00" -te "04/08/2026 18:00:00"

# Filter by process/command
ausearch -m AVC -c httpd
ausearch -m AVC --comm sshd

# Filter by domain
ausearch -m AVC -se "httpd_t"

# Filter by process ID
ausearch -m AVC -p 12345

# AVC denials with system call context
ausearch -m AVC,SYSCALL -ts recent
```

### audit2why -- Explain Denials

```bash
# Explain why a denial occurred
ausearch -m AVC -ts recent | audit2why

# Generate allow rules
ausearch -m AVC -ts recent | audit2allow

# Generate a policy module from denials
ausearch -m AVC -ts recent | audit2allow -M myfix

# Generate CIL format (RHEL 9+)
ausearch -m AVC -ts recent | audit2allow --cil -M myfix
```

### sealert -- setroubleshoot Analysis

```bash
# Install setroubleshoot
dnf install setroubleshoot-server

# Enable the daemon
systemctl enable --now setroubleshootd

# Analyze the audit log
sealert -a /var/log/audit/audit.log

# Analyze a specific alert by UUID (from /var/log/messages)
sealert -l <UUID>

# List recent alerts
sealert -l "*"
```

`sealert` output includes:
- Human-readable description of the denial
- Probability-ranked list of possible causes
- Suggested fix commands (boolean, fcontext, or custom module)

---

## Troubleshooting Workflow

### Standard Decision Tree

```
1. Confirm SELinux is causing the issue
   +-- getenforce --> is it Enforcing?
   +-- setenforce 0 --> does the problem go away?
   +-- setenforce 1 --> re-enable immediately after confirming

2. Check for AVC denials
   +-- ausearch -m AVC -ts recent
   +-- sealert -a /var/log/audit/audit.log
   +-- tail -f /var/log/audit/audit.log | grep AVC

3. Understand the denial
   +-- audit2why --> explains WHY the denial occurred
   +-- Identify: scontext (who), tcontext (what), tclass (class), perms

4. Determine the appropriate fix
   +-- Wrong file context?
   |   +-- semanage fcontext + restorecon
   +-- Boolean available?
   |   +-- semanage boolean -l | grep <service>
   |   +-- setsebool -P <boolean> on
   +-- Non-standard port?
   |   +-- semanage port -a -t <port_type> -p tcp <port>
   +-- Container volume issue?
   |   +-- Add :Z or :z to volume mount
   +-- None of the above?
       +-- Per-domain permissive, generate module with audit2allow

5. Test the fix
   +-- Apply fix
   +-- Restart the affected service
   +-- Verify: ausearch -m AVC -ts recent

6. Verify enforcing mode
   +-- getenforce must show Enforcing
```

### Revealing Hidden Denials

Dontaudit rules suppress logging for expected denials. If troubleshooting yields no AVC messages but SELinux is confirmed as the cause:

```bash
semodule -DB   # Disable dontaudit rules, rebuild policy
# Reproduce the issue
ausearch -m AVC -ts recent
semodule -B    # Re-enable dontaudit rules
```

---

## Common Issues and Fixes

### Web Server Cannot Serve Files from Custom Directory

**Symptom**: Apache/Nginx returns 403 Forbidden for files in `/srv/website/`

**Diagnosis**:
```bash
ausearch -m AVC -c httpd -ts recent
# Shows: denied { read } ... tcontext=...:default_t ...
```

**Fix**:
```bash
semanage fcontext -a -t httpd_sys_content_t "/srv/website(/.*)?"
restorecon -Rv /srv/website/
```

### Service Cannot Connect to Network

**Symptom**: Application in `httpd_t` cannot reach a backend API or database.

**Diagnosis**:
```bash
ausearch -m AVC -c httpd -ts recent
# Shows: denied { name_connect } ... tclass=tcp_socket
```

**Fix**:
```bash
# General network connectivity
setsebool -P httpd_can_network_connect on

# Database connections specifically
setsebool -P httpd_can_network_connect_db on
```

### Custom Port Not Working

**Symptom**: Service fails to bind to port 8181; AVC denial on `port_t`.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# Shows: denied { name_bind } ... tclass=tcp_socket
semanage port -l | grep 8181  # Not listed
```

**Fix**:
```bash
semanage port -l | grep http_port_t    # Find the correct type
semanage port -a -t http_port_t -p tcp 8181
```

### Container Cannot Access Host Volume

**Symptom**: Container process gets permission denied on a bind-mounted directory.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# Shows: denied { read } ... scontext=...:container_t ... tcontext=...:user_home_t
```

**Fix (private exclusive access)**:
```bash
podman run -v /srv/mydata:/data:Z myimage
```

**Fix (shared access across containers)**:
```bash
podman run -v /srv/shared:/data:z myimage
```

**Fix (complex container policy using udica)**:
```bash
podman inspect mycontainer | udica mypolicy
semodule -i mypolicy.cil /usr/share/udica/templates/*.cil
```

### Application Denials After Update

**Symptom**: Application worked before, now getting AVC denials after package update.

**Diagnosis**:
```bash
ausearch -m AVC -ts "04/08/2026 06:00:00"
rpm -qa --last | head -20    # Check what was updated
```

**Fix**:
```bash
# Relabel files that may have incorrect contexts
restorecon -Rv /usr/sbin/myapp /etc/myapp /var/lib/myapp /var/log/myapp
```

### NFS/CIFS Mounted Content

**Symptom**: Service cannot access content on NFS or CIFS mounts.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# NFS: tcontext=...:nfs_t
# CIFS: tcontext=...:cifs_t
```

**Fix for NFS**:
```bash
setsebool -P httpd_use_nfs on       # for httpd
setsebool -P use_nfs_home_dirs on   # for home directories on NFS
```

**Fix for CIFS**:
```bash
setsebool -P httpd_use_cifs on      # for httpd
setsebool -P use_samba_home_dirs on # for home dirs on CIFS
```

### Service Works on One Server but Fails on Another

**Diagnosis**:
```bash
# Compare booleans between servers
semanage boolean -l | grep httpd > server1_booleans.txt   # On server1
semanage boolean -l | grep httpd > server2_booleans.txt   # On server2
diff server1_booleans.txt server2_booleans.txt
```

### Files Copied or Moved Have Wrong Context

When files are moved (not copied), they retain their original context. When copied, they inherit the destination directory's context.

```bash
# Check current vs expected context
ls -Z /path/to/file
matchpathcon /path/to/file

# Fix
restorecon -v /path/to/file
```

---

## Diagnostic Patterns

### Service Fails After Configuration Change

Files placed in non-standard locations inherit the default context (`default_t` or `unlabeled_t`), which confined services cannot access.

```bash
ls -Z /path/to/file          # Check current context
matchpathcon /path/to/file   # Check expected context
restorecon -v /path/to/file  # Fix it
```

### Service Fails After Package Update

Updates may reset file contexts. Relabel affected paths:
```bash
restorecon -Rv /etc/httpd /var/www /usr/sbin/httpd
```

### Denials During Boot or Service Startup

Check for AVC denials during startup:
```bash
ausearch -m AVC -ts boot
journalctl -t setroubleshoot --since "1 hour ago"
```

### No AVC Messages But SELinux Is the Cause

This typically means dontaudit rules are hiding the denials:
```bash
semodule -DB    # Disable dontaudit
# Reproduce the issue
ausearch -m AVC -ts recent
semodule -B     # Re-enable dontaudit
```

---

## Key Diagnostic Commands

```bash
# Mode and status
getenforce
sestatus

# AVC denials
ausearch -m AVC -ts recent
ausearch -m AVC -c <process> -ts recent
ausearch -m AVC -ts recent | audit2why
sealert -a /var/log/audit/audit.log

# Context inspection
ps auxZ                           # Process contexts
ls -Z /path                       # File contexts
semanage port -l                  # Port contexts
semanage login -l                 # User mappings

# Context verification
matchpathcon -V /path/to/file    # Check for mismatch
restorecon -Rvn /path/           # Dry-run restore

# Boolean inspection
getsebool -a | grep <service>
semanage boolean -l | awk '$3 != $4'

# Policy inspection
semodule -lfull                   # All modules with priorities
semanage permissive -l            # Permissive domains
seinfo --stats                    # Policy statistics
```
