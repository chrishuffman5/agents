# SELinux Architecture Reference

## Mandatory Access Control (MAC) Framework

### DAC vs MAC

Discretionary Access Control (DAC) -- the traditional UNIX permission model -- lets the owner of a resource decide who can access it. DAC is bypassed by root; any process running as UID 0 can read any file.

Mandatory Access Control (MAC) enforces access based on policy defined by the system administrator, not the resource owner. Even root is subject to MAC rules. SELinux implements MAC as a kernel-level enforcement mechanism layered on top of DAC.

Decision order:
1. DAC check (UID/GID permissions, ACLs) -- if denied, stop.
2. SELinux MAC check (policy allow rules) -- if denied, generate AVC denial and stop.

Both must allow an access for it to succeed.

### Linux Security Modules (LSM) Architecture

LSM is a framework in the Linux kernel that provides hooks for security modules to intercept and mediate kernel operations. SELinux is an LSM implementation.

Key LSM hook locations:
- `inode_permission` -- file/directory access
- `file_open` -- file open operations
- `socket_connect` -- network connections
- `task_create` -- process creation (fork/exec)
- `ipc_permission` -- IPC operations (shared memory, message queues)
- `sb_mount` -- filesystem mount operations

Each hook calls into SELinux to make an allow/deny decision before the kernel completes the operation.

### SELinux Security Server

The SELinux kernel module registers with LSM at boot time. The security server:
- Loads and parses the binary policy from `/etc/selinux/<POLICYTYPE>/policy/policy.<version>`
- Evaluates access requests against policy rules
- Maintains the Access Vector Cache (AVC) for performance
- Handles context transitions during `exec()` calls

Policy is compiled into a binary format offline and loaded into the kernel. The running policy cannot be changed without a full reload (`semodule -B` or reboot).

### Access Vector Cache (AVC)

The AVC is an in-kernel cache storing results of recent security decisions. Without the cache, every syscall would require a full policy evaluation.

Cache entry structure: `(source context, target context, object class) -> allowed/denied perms`

```bash
# View AVC statistics
cat /sys/fs/selinux/avc/cache_stats

# View AVC hash table sizes
cat /sys/fs/selinux/avc/hash_stats
```

AVC misses generate audit messages. Denials are logged as AVC messages in `/var/log/audit/audit.log`.

---

## Type Enforcement (TE)

Type Enforcement is the primary access control mechanism in SELinux targeted policy.

### Domains and Types

- **Domain**: the security type assigned to a process (e.g., `httpd_t`, `sshd_t`, `init_t`)
- **Type**: the security type assigned to a file, device, or other object (e.g., `httpd_sys_content_t`, `shadow_t`)

The domain/type is part of the full security context: `user:role:type:level`.

Example -- Apache (httpd):
- Process runs in domain: `system_u:system_r:httpd_t:s0`
- Web content files have type: `system_u:object_r:httpd_sys_content_t:s0`
- Policy allows: `allow httpd_t httpd_sys_content_t:file { read getattr open };`

### Type Transitions

When a process executes a binary, SELinux can automatically transition to a new domain:
```
type_transition source_domain exec_type : process new_domain;
```

Example: when `init_t` executes `/usr/sbin/httpd` (labeled `httpd_exec_t`), the process transitions to `httpd_t`.

File type transitions also exist -- when a process in `httpd_t` creates a file in a directory of type `httpd_log_t`, the file automatically gets type `httpd_log_t`.

### Allow Rules

Allow rules are the core policy statement granting access:
```
allow source_domain target_type : object_class { permissions };
```

Object classes include: `file`, `dir`, `lnk_file`, `chr_file`, `blk_file`, `fifo_file`, `sock_file`, `process`, `tcp_socket`, `udp_socket`, `rawip_socket`, `netif`, `node`, `capability`, `ipc`, `msgq`, `shm`, `sem`.

### Dontaudit Rules

Suppress AVC logging for known-harmless denials (access is still denied, just not logged). Used to reduce audit noise.
```
dontaudit httpd_t shadow_t : file read;
```

To reveal hidden denials during troubleshooting:
```bash
semodule -DB   # Disable dontaudit, rebuild policy
# ... investigate ...
semodule -B    # Re-enable dontaudit, rebuild policy
```

### Neverallow Rules

Compile-time assertions that certain access combinations must never be allowed. Enforced by `checkpolicy`. They cannot be overridden by allow rules. If a module contains a contradicting allow rule, it fails to compile.

---

## MLS/MCS -- Multi-Level and Multi-Category Security

### Multi-Level Security (MLS)

MLS implements the Bell-LaPadula model:
- **Sensitivity levels**: `s0` (unclassified) through `s15` (top secret)
- **Categories**: `c0` through `c1023` (compartments)
- Full level format: `sensitivity[:category,category...]`

MLS enforces:
- **No read up**: process at level s1 cannot read object at level s2
- **No write down**: process at level s2 cannot write to object at level s1

MLS policy requires `SELINUXTYPE=mls` in `/etc/selinux/config`. It is the default only in government/classified environments.

### Multi-Category Security (MCS)

MCS is a simplified MLS subset using only categories (no sensitivity levels above s0). All processes run at `s0` but with different category sets. Two processes can only interact if their category sets match or one dominates the other.

**Primary use case: container isolation.**

- Container A: `system_u:system_r:container_t:s0:c1,c2`
- Container B: `system_u:system_r:container_t:s0:c3,c4`
- Both in `container_t` (same type enforcement rules), but MCS categories prevent cross-container access
- Random category pairs assigned automatically by the container runtime (Podman, Docker)

---

## SELinux Modes

### Enforcing

Policy actively enforced. Denied accesses blocked and logged.
```bash
getenforce          # Returns "Enforcing"
setenforce 1        # Switch to enforcing (immediate, non-persistent)
```

### Permissive

Policy evaluated and denials logged, but access is not blocked. Used for troubleshooting and policy development.
```bash
getenforce          # Returns "Permissive"
setenforce 0        # Switch to permissive (immediate, non-persistent)
```

WARNING: `setenforce 0` affects the entire system. Prefer per-domain permissive for targeted debugging.

### Disabled

SELinux completely disabled in the kernel. No labeling, no enforcement, no audit. Requires reboot to change. When re-enabled after being disabled, a full filesystem relabel is required (`touch /.autorelabel && reboot`).

### Per-Domain Permissive Mode

Put a single domain in permissive while the rest of the system enforces:
```bash
semanage permissive -a httpd_t    # Add to permissive
semanage permissive -l            # List permissive domains
semanage permissive -d httpd_t    # Remove from permissive
```

Permissive domains are stored as policy modules (`permissive_<domain>`) and survive reboots.

### Persistent Configuration

File: `/etc/selinux/config`
```
SELINUX=enforcing      # enforcing | permissive | disabled
SELINUXTYPE=targeted   # targeted | mls | minimum
```

---

## Policy Types

### Targeted Policy (default)

Only specific, targeted processes are confined. Everything else runs in `unconfined_t`, where all access is permitted by SELinux (DAC still applies).

Confined domains include: `httpd_t`, `sshd_t`, `named_t`, `postgresql_t`, `mysqld_t`, `container_t`, `init_t`, `kernel_t`, `systemd_t`, and hundreds more.

Unconfined processes (user shells, most user applications) run as `unconfined_t`. However, when they start confined services, those services are still constrained by their confined domain rules.

Policy location: `/etc/selinux/targeted/`

### MLS Policy

Full Multi-Level Security policy. Every process and object has a sensitivity level. All processes are confined. Primarily used in government environments. More restrictive and complex to manage.

Configuration: `SELINUXTYPE=mls`

### Minimum Policy

A stripped-down targeted policy confining only a small set of critical processes. Useful for resource-constrained systems or custom appliances.

---

## Security Contexts

### Format

```
user:role:type:level
```

- **user**: SELinux user (not Linux user). Common: `system_u`, `user_u`, `staff_u`, `unconfined_u`, `root`
- **role**: RBAC role. Common: `system_r` (system processes), `object_r` (files), `user_r` (regular users), `sysadm_r` (sysadmin)
- **type**: The domain or type (primary enforcement mechanism in targeted policy)
- **level**: MLS/MCS sensitivity:category (e.g., `s0`, `s0:c1,c2`, `s0-s0:c0.c1023`)

### Viewing Contexts

```bash
# Process contexts
ps auxZ
ps -eZ | grep httpd
id -Z                              # Current shell context
cat /proc/<PID>/attr/current       # Specific process

# File contexts
ls -Z /var/www/html/
ls -laZ /etc/passwd

# Port contexts
semanage port -l
semanage port -l | grep http_port_t

# User mappings
semanage login -l
semanage user -l
```

### Default User Mappings (Targeted Policy)

- Linux user `root` maps to SELinux user `unconfined_u`
- All other Linux users map via `__default__` to `unconfined_u`

In strict/MLS environments, users map to `staff_u`, `user_u`, or custom SELinux users.

### Common Port Types

| Type | Default Ports |
|---|---|
| `http_port_t` | 80, 443, 8080, 8443 |
| `ssh_port_t` | 22 |
| `mysqld_port_t` | 3306 |
| `postgresql_port_t` | 5432 |
| `smtp_port_t` | 25, 465, 587 |

---

## Key Files and Directories

| Path | Purpose |
|---|---|
| `/etc/selinux/config` | Mode and policy type |
| `/etc/selinux/targeted/` | Targeted policy root |
| `/etc/selinux/targeted/contexts/files/file_contexts` | Base file context rules |
| `/etc/selinux/targeted/contexts/files/file_contexts.local` | Local fcontext additions |
| `/etc/selinux/targeted/contexts/files/file_contexts.homedirs` | Home directory contexts |
| `/etc/selinux/targeted/policy/policy.*` | Compiled binary policy |
| `/var/lib/selinux/targeted/active/` | Active policy module store |
| `/sys/fs/selinux/` | Live kernel interface (pseudo-filesystem) |
| `/sys/fs/selinux/enforce` | Current enforce state (0 or 1) |
| `/sys/fs/selinux/policyvers` | Kernel policy version |
| `/sys/fs/selinux/avc/cache_stats` | AVC cache statistics |
| `/var/log/audit/audit.log` | AVC denials and audit events |
| `/var/log/messages` | setroubleshoot summaries |
