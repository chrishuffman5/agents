# SELinux — Deep-Dive Research (RHEL 8/9/10)

> Comprehensive technical reference for SELinux configuration, troubleshooting, and management.
> Covers RHEL 8, 9, and 10 unless otherwise noted.

---

## Part 1: Architecture

### 1. MAC Framework — Mandatory Access Control

#### DAC vs MAC
Discretionary Access Control (DAC) — the traditional UNIX permission model — lets the **owner** of a resource decide who can access it. A file owned by root with mode 644 is controlled by root's discretion. DAC is bypassed by root; any process running as UID 0 can read any file.

Mandatory Access Control (MAC) enforces access based on **policy** defined by the system administrator, not the resource owner. Even root is subject to MAC rules. SELinux implements MAC as a kernel-level enforcement mechanism layered on top of DAC. Both must allow an access for it to succeed.

Decision order:
1. DAC check (UID/GID permissions, ACLs) — if denied, stop.
2. SELinux MAC check (policy allow rules) — if denied, generate AVC denial and stop.

#### Linux Security Modules (LSM) Architecture
LSM is a framework in the Linux kernel that provides hooks for security modules to intercept and mediate kernel operations. SELinux is an LSM implementation.

LSM hook locations:
- `inode_permission` — file/directory access
- `file_open` — file open operations
- `socket_connect` — network connections
- `task_create` — process creation (fork/exec)
- `ipc_permission` — IPC operations (shared memory, message queues)
- `sb_mount` — filesystem mount operations

Each hook calls into the registered security module (SELinux) to make an allow/deny decision before the kernel completes the operation.

#### SELinux Kernel Module and Security Server
The SELinux kernel module registers with the LSM framework at boot time. The core component is the **security server**, which:
- Loads and parses the binary policy from `/etc/selinux/<POLICYTYPE>/policy/policy.<version>`
- Evaluates access requests against policy rules
- Maintains the Access Vector Cache (AVC) for performance
- Handles context transitions during exec() calls

Policy is compiled into a binary format offline and loaded into the kernel. The running policy cannot be changed without a full reload (`semodule -B` or reboot).

#### Access Vector Cache (AVC)
The AVC is an in-kernel cache that stores results of recent security decisions. Without the cache, every syscall would require a full policy evaluation.

Cache entry structure: `(source context, target context, object class) → allowed/denied perms`

AVC statistics:
```bash
# View AVC statistics
cat /sys/fs/selinux/avc/cache_stats

# View AVC hash table sizes
cat /sys/fs/selinux/avc/hash_stats
```

AVC misses generate audit messages (denials or permits logged via `audit2allow`). Denials are logged as AVC messages in `/var/log/audit/audit.log`.

---

### 2. Type Enforcement (TE)

Type Enforcement is the primary access control mechanism in SELinux's targeted policy.

#### Domains and Types
- **Domain**: the security type assigned to a **process** (e.g., `httpd_t`, `sshd_t`, `init_t`). A domain is a process context.
- **Type**: the security type assigned to a **file, device, or other object** (e.g., `httpd_sys_content_t`, `shadow_t`, `port_t`). A type is an object context.

Domain/type is part of the full security context: `user:role:type:level`.

Example — Apache (httpd):
- Process runs in domain: `system_u:system_r:httpd_t:s0`
- Web content files have type: `system_u:object_r:httpd_sys_content_t:s0`
- Policy allows: `allow httpd_t httpd_sys_content_t:file { read getattr open };`

#### Type Transitions
When a process executes a binary, SELinux can automatically transition to a new domain. This is the mechanism by which services start in confined domains.

Rule format:
```
type_transition source_domain exec_type : process new_domain;
```

Example: when `init_t` executes `/usr/sbin/httpd` (labeled `httpd_exec_t`), the new process gets `httpd_t`:
```
type_transition init_t httpd_exec_t : process httpd_t;
```

File type transitions also exist — when a process in `httpd_t` creates a file in a directory of type `httpd_log_t`, the file automatically gets type `httpd_log_t`.

#### Allow Rules
Allow rules are the core policy statement granting access:
```
allow source_domain target_type : object_class { permissions };
```

Examples:
```
# httpd can read files of type httpd_sys_content_t
allow httpd_t httpd_sys_content_t : file { read open getattr ioctl };

# httpd can list directories of type httpd_sys_content_t
allow httpd_t httpd_sys_content_t : dir { read open getattr search };

# httpd can connect to the network (self)
allow httpd_t httpd_t : tcp_socket { create connect };
```

Object classes include: `file`, `dir`, `lnk_file`, `chr_file`, `blk_file`, `fifo_file`, `sock_file`, `process`, `tcp_socket`, `udp_socket`, `rawip_socket`, `netif`, `node`, `capability`, `ipc`, `msgq`, `shm`, `sem`.

#### Dontaudit Rules
Suppress AVC logging for known-harmless denials (still denied, just not logged). Used to reduce audit noise for expected denials.
```
dontaudit httpd_t shadow_t : file read;
```
This prevents cluttering audit logs when httpd attempts to read `/etc/shadow` (which it should never need and is denied).

To see dontaudit'd denials, use `seinfo --stats` or temporarily disable dontaudit rules:
```bash
semodule -DB   # Disable dontaudit, rebuild policy
# ... investigate ...
semodule -B    # Re-enable dontaudit, rebuild policy
```

#### Neverallow Rules
Compile-time assertions that certain access combinations must never be allowed. Enforced by `checkpolicy` and `sepolgen`. They cannot be overridden by allow rules.
```
neverallow * shadow_t : file { write append };
```
If a policy module contains an allow rule that contradicts a neverallow, the module will fail to compile.

---

### 3. MLS/MCS — Multi-Level and Multi-Category Security

#### Multi-Level Security (MLS)
MLS implements the Bell-LaPadula model for classified information:
- **Sensitivity levels**: `s0` (unclassified) through `s15` (top secret). Full form: `s0-s15`
- **Categories**: `c0` through `c1023` (compartments)
- Full level: `sensitivity[:category,category...]`

Example levels:
- `s0` — unclassified
- `s2:c10,c20` — sensitivity 2, categories 10 and 20
- `s0-s3:c0.c100` — range from s0 to s3 with categories c0-c100

MLS enforces:
- **No read up**: process at level s1 cannot read object at level s2
- **No write down**: process at level s2 cannot write to object at level s1

MLS policy is only the default in government/classified environments. It requires `SELINUXTYPE=mls` in `/etc/selinux/config`.

#### Multi-Category Security (MCS)
MCS is a simplified MLS subset using only categories (no sensitivity levels above s0). All processes run at `s0` but can have different category sets. Two processes/objects can only interact if their category sets match (or one dominates the other).

Primary use case: **container isolation**.

MCS per-container isolation:
- Container A runs with label `system_u:system_r:container_t:s0:c1,c2`
- Container B runs with label `system_u:system_r:container_t:s0:c3,c4`
- Both are in domain `container_t` (same rules apply), but MCS categories prevent them from accessing each other's resources
- Random category pairs are assigned by the container runtime (Podman, Docker)

MCS categories are assigned by `libselinux` using `/usr/share/selinux/targeted/setrans.conf` for translation and `mcstrans` for human-readable labels.

---

### 4. SELinux Modes

#### Enforcing
Policy is actively enforced. Denied accesses are blocked and logged to the audit log.
```bash
getenforce          # Returns "Enforcing"
setenforce 1        # Switch to enforcing (immediate, non-persistent)
```

#### Permissive
Policy is evaluated and denials are logged, but access is **not blocked**. Used for troubleshooting and policy development.
```bash
getenforce          # Returns "Permissive"
setenforce 0        # Switch to permissive (immediate, non-persistent)
```

WARNING: `setenforce 0` affects the entire system. Prefer per-domain permissive for targeted debugging.

#### Disabled
SELinux is completely disabled in the kernel. No labeling, no enforcement, no audit. Requires reboot to change. When re-enabled after being disabled, a full filesystem relabel is required (create `/.autorelabel` and reboot).

Persistent mode configuration — `/etc/selinux/config`:
```
SELINUX=enforcing      # enforcing | permissive | disabled
SELINUXTYPE=targeted   # targeted | mls | minimum
```

#### Per-Domain Permissive Mode
Put a single domain in permissive mode while the rest of the system enforces. Invaluable for troubleshooting a specific service without opening up the entire system.
```bash
# Add httpd_t to permissive domains
semanage permissive -a httpd_t

# List permissive domains
semanage permissive -l

# Remove from permissive
semanage permissive -d httpd_t
```

Permissive domains are stored as a policy module named `permissive_<domain>`. They survive reboots.

---

### 5. Policy Types

#### Targeted Policy (default)
Only specific, targeted processes are confined by SELinux. Everything else runs in the `unconfined_t` domain, where all access is permitted by SELinux (DAC still applies).

Confined domains in targeted policy include: `httpd_t`, `sshd_t`, `named_t`, `postgresql_t`, `mysqld_t`, `docker_t`, `container_t`, `init_t`, `kernel_t`, `systemd_t`, and hundreds more.

Unconfined processes — user shells, most user applications — run as `unconfined_t`:
```
system_u:system_r:unconfined_t:s0-s0:c0.c1023
```

Unconfined domains: processes that transition out of unconfined (start confined services) are still constrained by the confined domain rules for that service.

Targeted policy location: `/etc/selinux/targeted/`

#### MLS Policy
Full Multi-Level Security policy. Every process and object has a sensitivity level. Primarily used in government environments. All processes are confined. More restrictive and complex to manage.

Configuration: `SELINUXTYPE=mls`

#### Minimum Policy
A stripped-down targeted policy that confines only a very small set of critical processes. Useful for resource-constrained systems or custom appliances.

---

### 6. Security Contexts

#### Format
```
user:role:type:level
```

- **user**: SELinux user (not Linux user). Common: `system_u`, `user_u`, `staff_u`, `unconfined_u`, `root`
- **role**: RBAC role. Common: `system_r` (system processes), `object_r` (files/objects), `user_r` (regular users), `sysadm_r` (sysadmin)
- **type**: The type/domain (see TE above)
- **level**: MLS/MCS sensitivity:category (e.g., `s0`, `s0:c1,c2`, `s0-s0:c0.c1023`)

#### Process Contexts
```bash
# Show process security contexts
ps auxZ
ps -eZ | grep httpd

# Show current shell context
id -Z

# Show context of a specific process
cat /proc/<PID>/attr/current
```

#### File Contexts
```bash
# Show file security context (long format)
ls -Z /var/www/html/
ls -laZ /etc/passwd

# Show full context including MLS level
ls --scontext /etc/shadow
```

#### Port Contexts
```bash
# List all port contexts
semanage port -l

# Filter for specific port
semanage port -l | grep 8080

# List ports for a specific type
semanage port -l | grep http_port_t
```

Common port types:
- `http_port_t` — 80, 443, 8080, 8443
- `ssh_port_t` — 22
- `mysqld_port_t` — 3306
- `postgresql_port_t` — 5432
- `smtp_port_t` — 25, 465, 587

#### User Contexts
```bash
# List SELinux user mappings
semanage login -l

# Show SELinux user definitions
semanage user -l

# Show context for a logged-in user
id -Z
```

Default user mappings:
- Linux user `root` → SELinux user `unconfined_u` (targeted policy)
- All other Linux users → `__default__` → `unconfined_u` (targeted policy)

In a strict/MLS environment, users map to `staff_u`, `user_u`, or custom users.

---

## Part 2: Best Practices

### 7. Policy Management Tools

#### semanage — SELinux Policy Management
The primary tool for persistent policy customization without writing raw policy files.

```bash
# File context management
semanage fcontext -l                              # List all file context rules
semanage fcontext -a -t httpd_sys_content_t "/srv/www(/.*)?"   # Add rule
semanage fcontext -d "/srv/www(/.*)?"             # Delete rule
semanage fcontext -m -t httpd_sys_rw_content_t "/srv/www/uploads(/.*)?"  # Modify

# Port management
semanage port -a -t http_port_t -p tcp 8181       # Add port
semanage port -d -t http_port_t -p tcp 8181       # Delete port
semanage port -m -t http_port_t -p tcp 8181       # Modify port

# Boolean management
semanage boolean -l                               # List all booleans
semanage boolean -m --on httpd_can_network_connect # Set boolean (persistent)

# Login mapping
semanage login -a -s staff_u webadmin             # Map Linux user to SELinux user
semanage login -d webadmin                        # Remove mapping

# User management
semanage user -l                                  # List SELinux users
semanage user -a -R "staff_r sysadm_r" myuser_u  # Add user with roles

# Module management
semanage module -l                                # List loaded modules
semanage module -d mymodule                       # Disable module
semanage module -e mymodule                       # Enable module
```

All semanage changes are stored in `/etc/selinux/targeted/` and survive policy rebuilds.

#### restorecon — Restore File Contexts
Resets file contexts to match the policy database. Use after moving files or changing fcontext rules.

```bash
# Restore context of a single file
restorecon /var/www/html/index.html

# Recursive restore with verbose output
restorecon -Rv /srv/www/

# Dry-run (show what would change without applying)
restorecon -Rvn /srv/www/

# Force relabel even if context appears correct
restorecon -RvF /var/www/html/
```

restorecon reads from `/etc/selinux/targeted/contexts/files/file_contexts` and its local overrides.

#### chcon — Temporary Context Change
Changes context directly on files. Does NOT update the policy database. Changes are lost if restorecon is run or filesystem is relabeled.

```bash
# Change type only
chcon -t httpd_sys_content_t /tmp/testfile.html

# Change full context
chcon -u system_u -r object_r -t httpd_sys_content_t /srv/content/

# Recursive change
chcon -R -t httpd_sys_content_t /srv/content/

# Reference another file's context
chcon --reference=/var/www/html /srv/www/
```

Use case: quick testing before making permanent with `semanage fcontext + restorecon`.

#### setsebool — Boolean Management
```bash
# Set boolean (non-persistent, immediate)
setsebool httpd_can_network_connect on
setsebool httpd_can_network_connect 1

# Set boolean (persistent, survives reboot)
setsebool -P httpd_can_network_connect on

# Set multiple booleans at once
setsebool -P httpd_can_network_connect on httpd_use_nfs on

# Check current value
getsebool httpd_can_network_connect
getsebool -a | grep httpd
```

#### semodule — Module Management
```bash
# Install a compiled module
semodule -i mypolicy.pp

# List installed modules
semodule -l
semodule -lfull   # Include priorities and disabled status

# Remove a module
semodule -r mypolicy

# Disable without removing
semodule -d mypolicy

# Enable a disabled module
semodule -e mypolicy

# Rebuild the active policy (applies all changes)
semodule -B

# Rebuild with dontaudit disabled (for debugging)
semodule -DB

# Install module with specific priority (default 400)
semodule -X 300 -i mypolicy.pp
```

Module priorities: 100=base, 200=contrib, 300=local, 400=custom/local overrides.

---

### 8. Boolean Management

Booleans are pre-defined on/off switches that enable or disable specific policy rules without requiring custom modules.

#### Listing and Inspecting Booleans
```bash
# List all booleans with current and default values
getsebool -a
semanage boolean -l

# Booleans changed from default
semanage boolean -l | awk '$3 != $4'

# Search for booleans related to a service
semanage boolean -l | grep httpd
getsebool -a | grep samba
```

#### Common Booleans by Service

**Web Server (httpd)**:
| Boolean | Description |
|---------|-------------|
| `httpd_can_network_connect` | Allow httpd to make network connections |
| `httpd_can_network_connect_db` | Allow httpd to connect to databases |
| `httpd_can_sendmail` | Allow httpd to send mail |
| `httpd_can_network_relay` | Allow httpd to act as a relay |
| `httpd_use_nfs` | Allow httpd to serve NFS-mounted content |
| `httpd_use_cifs` | Allow httpd to serve CIFS-mounted content |
| `httpd_enable_cgi` | Allow httpd to execute CGI scripts |
| `httpd_enable_homedirs` | Allow httpd to read home directories |
| `httpd_read_user_content` | Allow httpd to read user content |
| `httpd_unified` | Unified httpd_sys_content_t for all web content |
| `httpd_execmem` | Allow httpd to use execmem (for PHP, mod_python) |

**Samba**:
| Boolean | Description |
|---------|-------------|
| `samba_enable_home_dirs` | Allow Samba to share home directories |
| `samba_export_all_ro` | Allow Samba to export any file read-only |
| `samba_export_all_rw` | Allow Samba to export any file read-write |
| `samba_share_nfs` | Allow Samba to share NFS-mounted volumes |
| `use_samba_home_dirs` | Allow users to mount Samba home dirs |

**FTP**:
| Boolean | Description |
|---------|-------------|
| `ftpd_anon_write` | Allow FTP anonymous write |
| `ftpd_full_access` | Allow FTP unrestricted access |
| `ftpd_use_nfs` | Allow FTP to serve NFS content |
| `ftpd_use_cifs` | Allow FTP to serve CIFS content |
| `ftpd_connect_db` | Allow FTP to connect to databases |

**SSH/Remote Access**:
| Boolean | Description |
|---------|-------------|
| `ssh_sysadm_login` | Allow SSH login by sysadm_r users |
| `rsync_client` | Allow rsync to act as client |
| `rsync_export_all_ro` | Allow rsync to export all files read-only |

**Virtualization/Containers**:
| Boolean | Description |
|---------|-------------|
| `virt_use_nfs` | Allow VMs to use NFS storage |
| `virt_use_samba` | Allow VMs to use Samba storage |
| `container_manage_cgroup` | Allow containers to manage cgroups |

**NFS/CIFS**:
| Boolean | Description |
|---------|-------------|
| `use_nfs_home_dirs` | Allow NFS-mounted home directories |
| `use_samba_home_dirs` | Allow CIFS-mounted home directories |

---

### 9. Custom Policy Modules

#### Module File Types
- `.te` — Type Enforcement file (main policy rules)
- `.if` — Interface file (macros callable by other modules)
- `.fc` — File Contexts file (labeling rules)
- `.pp` — Compiled Policy Package (binary, loaded by semodule)

#### Writing a Basic .te File
```
# mypolicy.te
policy_module(mypolicy, 1.0)

# Declare types (if adding new ones)
type myapp_t;
type myapp_exec_t;
type myapp_log_t;
type myapp_data_t;

# Domain transition
domain_type(myapp_t)
domain_entry_file(myapp_t, myapp_exec_t)

# Allow rules
allow myapp_t myapp_log_t:file { create open write append getattr };
allow myapp_t myapp_data_t:file { read open getattr };
allow myapp_t myapp_data_t:dir { read open search getattr };
```

#### Writing a .fc File
```
# mypolicy.fc
/usr/bin/myapp         -- gen_context(system_u:object_r:myapp_exec_t,s0)
/var/log/myapp(/.*)?   gen_context(system_u:object_r:myapp_log_t,s0)
/var/lib/myapp(/.*)?   gen_context(system_u:object_r:myapp_data_t,s0)
```

#### Compiling and Installing a Module
```bash
# Compile .te file to .mod
checkmodule -M -m -o mypolicy.mod mypolicy.te

# Package .mod and .fc into .pp
semodule_package -o mypolicy.pp -m mypolicy.mod -f mypolicy.fc

# Install the module
semodule -i mypolicy.pp

# Apply file contexts
restorecon -Rv /usr/bin/myapp /var/log/myapp /var/lib/myapp
```

#### audit2allow Workflow
The recommended workflow for generating custom policy from AVC denials:

```bash
# Step 1: Reproduce the denial (with system in permissive or per-domain permissive)
semanage permissive -a myapp_t

# Step 2: Run the application and trigger the denied operation
# ...

# Step 3: Collect AVC denials for your domain
ausearch -m AVC -c myapp 2>/dev/null | audit2allow

# Step 4: Generate a policy module
ausearch -m AVC -c myapp 2>/dev/null | audit2allow -M mypolicy

# Step 5: Review the generated .te file
cat mypolicy.te

# Step 6: Install if acceptable
semodule -i mypolicy.pp

# Step 7: Remove permissive domain
semanage permissive -d myapp_t
```

WARNING: audit2allow generates minimal allow rules. Always review before installing. Never blindly use `audit2allow -a` on a production system — it may allow overly broad access.

#### When to Use Custom Modules vs Booleans
- **Use a boolean** if one exists that covers your use case — it's the intended mechanism.
- **Use fcontext** for files in non-standard locations accessed by existing confined services.
- **Use semanage port** for services listening on non-standard ports.
- **Use a custom module** only when:
  - No boolean covers the required access
  - You are confining a custom application not in the base policy
  - You need to add new types for a custom application

---

### 10. Container SELinux

#### container-selinux Package
The `container-selinux` package provides SELinux policy for containerized workloads. It defines:
- `container_t` — domain for container processes
- `container_file_t` — label for container image layers and volumes
- `container_runtime_t` — domain for container runtimes (podman, docker)
- `container_var_lib_t` — `/var/lib/containers` label

```bash
rpm -q container-selinux
```

#### MCS Isolation Between Containers
Each container gets a unique pair of MCS categories automatically assigned by the runtime:
```
container_t:s0:c123,c456   # Container A
container_t:s0:c789,c012   # Container B
```

Because MCS policy requires matching categories, Container A cannot access Container B's files even though both run in `container_t`. This is automatic when container-selinux is installed.

#### Volume Mount Labels — :Z and :z
When bind-mounting host directories into containers:

```bash
# :z — Shared label (relabel with a shared type, all containers can access)
podman run -v /srv/shared:/data:z myimage

# :Z — Private label (relabel with private type, only this container accesses it)
podman run -v /srv/private:/data:Z myimage
```

`:Z` uses the container's unique MCS label. `:z` uses a shared container label. WARNING: `:Z` modifies the host directory's SELinux label. Never use `:Z` on system directories like `/home`, `/etc`, `/var`.

#### udica — Custom Container Policies
udica generates SELinux policies tailored to a specific container's needs by inspecting its definition.

```bash
# Install udica
dnf install udica

# Generate policy from a running container
podman inspect mycontainer | udica mycontainer_policy

# Inspect from a JSON file
podman inspect mycontainer > container.json
udica -j container.json mycontainer_policy

# Install the generated policy
semodule -i mycontainer_policy.cil /usr/share/udica/templates/*.cil

# Run the container with the custom label
podman run --security-opt label=type:mycontainer_policy.process ...
```

udica examines port bindings, volume mounts, and capabilities to produce a least-privilege CIL (Common Intermediate Language) policy.

---

### 11. File Context Management

#### The File Context Database
SELinux maintains a file context database that maps path patterns to security contexts:

- `/etc/selinux/targeted/contexts/files/file_contexts` — base policy contexts (do not edit)
- `/etc/selinux/targeted/contexts/files/file_contexts.local` — local additions from semanage
- `/etc/selinux/targeted/contexts/files/file_contexts.homedirs` — home directory contexts
- `/etc/selinux/targeted/contexts/files/file_contexts.subs` — substitution rules

#### Adding Custom Path Rules
```bash
# Add rule for a custom web root
semanage fcontext -a -t httpd_sys_content_t "/srv/website(/.*)?"

# Add rule for writable directory (uploads, etc.)
semanage fcontext -a -t httpd_sys_rw_content_t "/srv/website/uploads(/.*)?"

# Add rule for CGI scripts
semanage fcontext -a -t httpd_sys_script_exec_t "/srv/website/cgi-bin(/.*)?"

# Apply the rules
restorecon -Rv /srv/website/
```

#### Handling Relocated Data Directories
Example: PostgreSQL data moved to `/data/pgsql`:
```bash
# Check what context is expected
matchpathcon /var/lib/pgsql/data

# Add equivalent rule for new location
semanage fcontext -a -e /var/lib/pgsql /data/pgsql

# Or be explicit:
semanage fcontext -a -t postgresql_db_t "/data/pgsql(/.*)?"

# Apply
restorecon -Rv /data/pgsql
```

#### matchpathcon — Verify Expected Context
```bash
# Check what context policy expects for a path
matchpathcon /var/www/html/index.html
matchpathcon /etc/passwd

# Check against actual context
matchpathcon -V /var/www/html/index.html  # Reports mismatch if incorrect
```

#### Common File Types for Web/App Servers
| Type | Purpose |
|------|---------|
| `httpd_sys_content_t` | Static web content (read-only) |
| `httpd_sys_rw_content_t` | Web content that httpd can write (uploads, caches) |
| `httpd_sys_script_exec_t` | CGI scripts/executables |
| `httpd_log_t` | Web server log files |
| `httpd_config_t` | Web server configuration |
| `httpd_var_run_t` | PID files and sockets |
| `httpd_cache_t` | Web server caches |
| `httpd_tmp_t` | Temporary files created by httpd |

---

## Part 3: Diagnostics

### 12. AVC Denial Analysis

#### Audit Log Location and Structure
AVC denials are written to `/var/log/audit/audit.log` by `auditd`. If `setroubleshoot` is installed, human-readable summaries also go to `/var/log/messages`.

Raw AVC message format:
```
type=AVC msg=audit(1712345678.123:456): avc: denied { read } for pid=12345
  comm="httpd" name="secret.txt" dev="sda1" ino=98765
  scontext=system_u:system_r:httpd_t:s0
  tcontext=user_u:object_r:user_home_t:s0
  tclass=file permissive=0
```

Fields:
- `{ read }` — the permission requested
- `comm` — the command/process name
- `scontext` — source security context (the process)
- `tcontext` — target security context (the object)
- `tclass` — object class (`file`, `dir`, `tcp_socket`, etc.)
- `permissive=0` — 0 means enforcing (access denied), 1 means permissive (access allowed but logged)

#### ausearch — Query the Audit Log
```bash
# Recent AVC denials (last 10 minutes)
ausearch -m AVC -ts recent

# AVC denials in the last 24 hours
ausearch -m AVC -ts today

# AVC denials for a specific time range
ausearch -m AVC -ts "04/08/2026 08:00:00" -te "04/08/2026 18:00:00"

# Filter by process/command
ausearch -m AVC -c httpd
ausearch -m AVC --comm sshd

# Filter by domain
ausearch -m AVC -se "httpd_t"

# Combine with process ID
ausearch -m AVC -p 12345

# AVC denials AND system call context
ausearch -m AVC,SYSCALL -ts recent
```

#### audit2why — Explain Denials
```bash
# Explain why a specific AVC denial occurred
ausearch -m AVC -ts recent | audit2why

# Explain and suggest fixes
ausearch -m AVC -ts recent | audit2allow

# Generate module from all recent denials
ausearch -m AVC -ts recent | audit2allow -M myfix

# Explain denials from a specific file
audit2why < /var/log/audit/audit.log
```

#### sealert — setroubleshoot Analysis
```bash
# Install setroubleshoot
dnf install setroubleshoot-server

# Enable and start the daemon
systemctl enable --now setroubleshootd

# Analyze the audit log
sealert -a /var/log/audit/audit.log

# Analyze a specific AVC (by UUID from /var/log/messages)
sealert -l <UUID>

# List recent alerts
sealert -l "*"
```

sealert output includes:
- Human-readable description of the denial
- Probability-ranked list of possible causes
- Suggested fix commands (boolean, fcontext, or custom module)

---

### 13. Troubleshooting Workflow

#### Standard SELinux Troubleshooting Decision Tree

```
1. Confirm SELinux is causing the issue
   └── getenforce → is it Enforcing?
   └── setenforce 0 → does the problem go away?
   └── setenforce 1 → re-enable immediately after confirming

2. Check for AVC denials
   └── ausearch -m AVC -ts recent
   └── sealert -a /var/log/audit/audit.log
   └── tail -f /var/log/audit/audit.log | grep AVC

3. Understand the denial
   └── audit2why → explains WHY the denial occurred
   └── Identify: scontext (who), tcontext (what), tclass (class), perms (action)

4. Determine the appropriate fix
   ├── Wrong file context?
   │   └── semanage fcontext + restorecon
   ├── Boolean available?
   │   └── semanage boolean -l | grep <service>
   │   └── setsebool -P <boolean> on
   ├── Non-standard port?
   │   └── semanage port -a -t <port_type> -p tcp <port>
   ├── Container volume issue?
   │   └── Add :Z or :z to volume mount
   └── None of the above?
       └── Test with per-domain permissive, generate module with audit2allow

5. Test the fix
   └── Apply fix
   └── Restart the affected service
   └── Verify operation
   └── Check no new AVC denials: ausearch -m AVC -ts recent

6. Verify in enforcing mode
   └── Confirm setenforce 1 (or was never changed)
   └── Test again in enforcing
```

#### Common Patterns and Root Causes

**Pattern: Service fails after configuration change**
```bash
# Files copied/moved don't inherit correct context
ls -Z /path/to/file          # Check current context
matchpathcon /path/to/file   # Check expected context
restorecon -v /path/to/file  # Fix it
```

**Pattern: Service fails after dnf update**
```bash
# Update may reset file contexts — relabel affected paths
restorecon -Rv /etc/httpd /var/www /usr/sbin/httpd
```

**Pattern: Service works on one server, fails on another**
```bash
# Compare booleans between servers
semanage boolean -l | grep httpd > server1_booleans.txt  # On server1
semanage boolean -l | grep httpd > server2_booleans.txt  # On server2
diff server1_booleans.txt server2_booleans.txt
```

---

### 14. Common SELinux Issues and Fixes

#### Web Server Cannot Serve Files from Custom Directory

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

---

#### Service Cannot Connect to Network

**Symptom**: Application in `httpd_t` cannot reach a backend API or database.

**Diagnosis**:
```bash
ausearch -m AVC -c httpd -ts recent
# Shows: denied { name_connect } ... tclass=tcp_socket
```

**Fix**:
```bash
# For general network connectivity:
setsebool -P httpd_can_network_connect on

# For database connections specifically:
setsebool -P httpd_can_network_connect_db on
```

---

#### Custom Port Not Working

**Symptom**: Service fails to bind to port 8181; shows AVC denial on `port_t`.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# Shows: denied { name_bind } ... tcontext=...:port_t ... tclass=tcp_socket
semanage port -l | grep 8181  # Not listed
```

**Fix**:
```bash
# Determine which type to use based on service
semanage port -l | grep http_port_t

# Add the port
semanage port -a -t http_port_t -p tcp 8181
```

---

#### Container Cannot Access Host Volume

**Symptom**: Container process gets permission denied on a bind-mounted directory.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# Shows: denied { read } ... scontext=...:container_t ... tcontext=...:user_home_t
```

**Fix (for private exclusive access)**:
```bash
podman run -v /srv/mydata:/data:Z myimage
```

**Fix (for shared access across containers)**:
```bash
podman run -v /srv/shared:/data:z myimage
```

**Fix (using udica for complex policies)**:
```bash
podman inspect mycontainer | udica mypolicy
semodule -i mypolicy.cil /usr/share/udica/templates/*.cil
```

---

#### Application Denials After Update

**Symptom**: Application worked before update, now getting AVC denials.

**Diagnosis**:
```bash
ausearch -m AVC -ts "04/08/2026 06:00:00" -te "04/08/2026 12:00:00"
# Check what changed: rpm -qa --last | head -20
```

**Fix**:
```bash
# Relabel files that may have incorrect contexts after update
restorecon -Rv /usr/sbin/myapp /etc/myapp /var/lib/myapp /var/log/myapp

# If the update added a new policy module that conflicts
semodule -l | grep myapp
```

---

#### NFS/CIFS Mounted Content

**Symptom**: Service cannot access content on NFS or CIFS mounts.

**Diagnosis**:
```bash
ausearch -m AVC -ts recent
# NFS: tcontext=...:nfs_t
# CIFS: tcontext=...:cifs_t
```

**Fix for NFS**:
```bash
# Enable NFS access for the service
setsebool -P httpd_use_nfs on      # for httpd
setsebool -P samba_share_nfs on    # for Samba
setsebool -P use_nfs_home_dirs on  # for home directories on NFS

# Alternatively, relabel the mount with an appropriate type
# Add to /etc/fstab: context=system_u:object_r:httpd_sys_content_t:s0
```

**Fix for CIFS/Samba**:
```bash
setsebool -P httpd_use_cifs on     # for httpd
setsebool -P use_samba_home_dirs on # for home dirs on CIFS
```

---

## Part 4: Diagnostic Scripts

### Script 01 — SELinux Status Overview

```bash
#!/usr/bin/env bash
# ============================================================================
# SELinux - Status Overview
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

# ── SELinux Mode ──────────────────────────────────────────────────────────────
header "SELinux Mode"

ENFORCE_MODE=$(getenforce 2>/dev/null || echo "Error")
CONFIG_MODE=$(grep -E "^SELINUX=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "unknown")
POLICY_TYPE=$(grep -E "^SELINUXTYPE=" /etc/selinux/config 2>/dev/null | cut -d= -f2 || echo "unknown")

case "$ENFORCE_MODE" in
  Enforcing)  ok  "Current mode: ${BOLD}Enforcing${RESET}" ;;
  Permissive) warn "Current mode: ${BOLD}Permissive${RESET} — policy not enforced!" ;;
  Disabled)   fail "Current mode: ${BOLD}Disabled${RESET} — SELinux inactive!" ;;
  *)          fail "Cannot determine mode: $ENFORCE_MODE" ;;
esac

info "Configured mode: $CONFIG_MODE"
info "Policy type: $POLICY_TYPE"

# Check for mode mismatch
if [[ "$ENFORCE_MODE" != "$(echo "$CONFIG_MODE" | sed 's/./\U&/')" ]]; then
  warn "Runtime mode ($ENFORCE_MODE) differs from configured mode ($CONFIG_MODE)"
fi

# ── Permissive Domains ────────────────────────────────────────────────────────
header "Per-Domain Permissive Mode"

PERM_DOMAINS=$(semanage permissive -l 2>/dev/null | grep -v "^Builtin\|^Customized\|^$" || echo "")
if [[ -z "$PERM_DOMAINS" ]]; then
  ok "No domains in permissive mode"
else
  warn "Domains in permissive mode (these bypass enforcement):"
  echo "$PERM_DOMAINS" | while read -r domain; do
    warn "  - $domain"
  done
fi

# ── Policy Information ────────────────────────────────────────────────────────
header "Policy Information"

POLICY_VERSION=$(cat /sys/fs/selinux/policyvers 2>/dev/null || echo "unknown")
LOADED_MODULES=$(semodule -l 2>/dev/null | wc -l)
CUSTOM_MODULES=$(semodule -l 2>/dev/null | grep -c "^[a-z]" || echo "0")

info "Policy kernel version: $POLICY_VERSION"
info "Loaded modules total: $LOADED_MODULES"

# Count modules by priority tier
BASE_MODS=$(semodule -lfull 2>/dev/null | grep -c "^100 " || echo "0")
CONTRIB_MODS=$(semodule -lfull 2>/dev/null | grep -c "^200 " || echo "0")
LOCAL_MODS=$(semodule -lfull 2>/dev/null | grep -c "^[34][0-9][0-9] " || echo "0")
info "  Base modules (priority 100): $BASE_MODS"
info "  Contrib modules (priority 200): $CONTRIB_MODS"
info "  Local/custom modules (priority 300+): $LOCAL_MODS"

# ── Booleans Changed from Default ────────────────────────────────────────────
header "Booleans Changed from Default"

CHANGED_BOOLS=$(semanage boolean -l --noheading 2>/dev/null | \
  awk '{ if ($3 != $4) print $1, "current=" $3, "default=" $4 }' | head -30)

if [[ -z "$CHANGED_BOOLS" ]]; then
  ok "All booleans at default values"
else
  BOOL_COUNT=$(echo "$CHANGED_BOOLS" | wc -l)
  info "Booleans modified from default ($BOOL_COUNT):"
  echo "$CHANGED_BOOLS" | while IFS= read -r line; do
    echo "    $line"
  done
fi

# ── Recent AVC Denials ────────────────────────────────────────────────────────
header "Recent AVC Denials"

AVC_COUNT=$(ausearch -m AVC -ts today 2>/dev/null | grep -c "^type=AVC" || echo "0")
AVC_RECENT=$(ausearch -m AVC -ts recent 2>/dev/null | grep -c "^type=AVC" || echo "0")

if [[ "$AVC_COUNT" -eq 0 ]]; then
  ok "No AVC denials today"
elif [[ "$AVC_COUNT" -lt 10 ]]; then
  warn "AVC denials today: $AVC_COUNT (recent 10min: $AVC_RECENT)"
else
  fail "AVC denials today: $AVC_COUNT (recent 10min: $AVC_RECENT) — investigate!"
fi

if [[ "$AVC_RECENT" -gt 0 ]]; then
  info "Top domains with recent denials:"
  ausearch -m AVC -ts recent 2>/dev/null | \
    grep -oP 'scontext=\S+:\S+:\K[^:]+' | \
    sort | uniq -c | sort -rn | head -5 | \
    while read -r cnt dom; do echo "    $cnt  $dom"; done
fi

# ── File Context Database ─────────────────────────────────────────────────────
header "File Context Database"

FC_BASE_RULES=$(wc -l < /etc/selinux/${POLICY_TYPE:-targeted}/contexts/files/file_contexts 2>/dev/null || echo "0")
FC_LOCAL_RULES=$(wc -l < /etc/selinux/${POLICY_TYPE:-targeted}/contexts/files/file_contexts.local 2>/dev/null || echo "0")

info "Base file context rules: $FC_BASE_RULES"
if [[ "$FC_LOCAL_RULES" -gt 0 ]]; then
  info "Local file context rules (semanage fcontext): $FC_LOCAL_RULES"
else
  ok "No local file context overrides"
fi

# ── AVC Cache Stats ───────────────────────────────────────────────────────────
header "AVC Cache Statistics"

if [[ -f /sys/fs/selinux/avc/cache_stats ]]; then
  while IFS=: read -r key val; do
    info "  $(echo "$key" | xargs): $(echo "$val" | xargs)"
  done < /sys/fs/selinux/avc/cache_stats
else
  warn "AVC cache stats not available"
fi

echo
echo -e "${BOLD}SELinux status check complete.${RESET}"
```

---

### Script 02 — AVC Denial Analysis

```bash
#!/usr/bin/env bash
# ============================================================================
# SELinux - AVC Denial Analysis
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

HOURS="${1:-24}"
info "Analyzing AVC denials from the last ${HOURS} hours..."

# ── Collect AVC Data ──────────────────────────────────────────────────────────
TMPFILE=$(mktemp /tmp/selinux-avc-XXXXXX.log)
trap 'rm -f "$TMPFILE"' EXIT

# Calculate timestamp for ausearch
TS=$(date -d "${HOURS} hours ago" "+%m/%d/%Y %H:%M:%S" 2>/dev/null || \
     date -v-"${HOURS}"H "+%m/%d/%Y %H:%M:%S" 2>/dev/null || echo "")

if [[ -n "$TS" ]]; then
  ausearch -m AVC -ts "$TS" 2>/dev/null > "$TMPFILE" || true
else
  ausearch -m AVC -ts today 2>/dev/null > "$TMPFILE" || true
fi

TOTAL=$(grep -c "^type=AVC" "$TMPFILE" 2>/dev/null || echo "0")

# ── Summary ───────────────────────────────────────────────────────────────────
header "AVC Denial Summary (last ${HOURS}h)"

if [[ "$TOTAL" -eq 0 ]]; then
  ok "No AVC denials found in the specified timeframe."
  exit 0
fi

if [[ "$TOTAL" -lt 10 ]]; then
  warn "Total AVC denials: $TOTAL"
elif [[ "$TOTAL" -lt 100 ]]; then
  warn "Total AVC denials: $TOTAL — elevated activity"
else
  fail "Total AVC denials: $TOTAL — significant SELinux activity!"
fi

# ── Top Denied Domains (source contexts) ─────────────────────────────────────
header "Top Denied Source Domains"

echo "  Count  Domain"
echo "  ─────  ──────────────────────────────────────"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'scontext=\S+:\S+:\K[^:]+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# ── Top Denied Target Types ───────────────────────────────────────────────────
header "Top Denied Target Types"

echo "  Count  Target Type"
echo "  ─────  ──────────────────────────────────────"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'tcontext=\S+:\S+:\K[^:]+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# ── Top Denied Object Classes ─────────────────────────────────────────────────
header "Top Denied Object Classes"

echo "  Count  Object Class"
echo "  ─────  ──────────────────────────────────────"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'tclass=\K\S+' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# ── Top Denied Permissions ────────────────────────────────────────────────────
header "Top Denied Permissions"

echo "  Count  Permission"
echo "  ─────  ──────────────────────────────────────"
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'denied \{ \K[^}]+' | \
  tr ' ' '\n' | grep -v '^$' | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{ printf "  %-6s %s\n", $1, $2 }'

# ── Detailed audit2why Analysis ───────────────────────────────────────────────
header "audit2why Analysis (Top 5 Unique Denial Patterns)"

# Extract unique denial signatures and analyze
grep "^type=AVC" "$TMPFILE" | \
  grep -oP 'scontext=\S+ tcontext=\S+ tclass=\S+' | \
  sort -u | head -5 | while IFS= read -r pattern; do
    echo -e "\n  ${YELLOW}Pattern: $pattern${RESET}"
    # Get a sample AVC for this pattern
    SAMPLE=$(grep "^type=AVC" "$TMPFILE" | grep -F "$pattern" | head -1)
    if [[ -n "$SAMPLE" ]]; then
      echo "$SAMPLE" | audit2why 2>/dev/null | sed 's/^/    /' || \
        echo "    (audit2why not available or no explanation)"
    fi
  done

# ── Suggested Fixes ───────────────────────────────────────────────────────────
header "Suggested Fixes (audit2allow)"

echo -e "  ${YELLOW}NOTE: Review all suggestions before applying. Never blindly execute.${RESET}\n"

# Check for boolean opportunities
info "Checking for applicable boolean fixes..."
ausearch -m AVC -ts today 2>/dev/null | \
  audit2allow 2>/dev/null | grep -E "^#" | head -20 | sed 's/^/  /'

# Generate module suggestion if needed
UNFIXED=$(cat "$TMPFILE" | audit2allow 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l || echo "0")
if [[ "$UNFIXED" -gt 0 ]]; then
  echo
  warn "Denials not covered by booleans ($UNFIXED rules needed):"
  cat "$TMPFILE" | audit2allow 2>/dev/null | grep -v "^#" | grep -v "^$" | head -20 | sed 's/^/    /'
  echo
  info "To generate a policy module (review before installing):"
  echo "    ausearch -m AVC -ts today | audit2allow -M myfix"
  echo "    cat myfix.te   # REVIEW THIS FILE"
  echo "    semodule -i myfix.pp"
fi

# ── Permissive vs Enforcing ───────────────────────────────────────────────────
header "Permissive-Mode Activity"

PERMISSIVE_AVC=$(grep "^type=AVC" "$TMPFILE" | grep -c "permissive=1" || echo "0")
ENFORCING_AVC=$(grep "^type=AVC" "$TMPFILE" | grep -c "permissive=0" || echo "0")

info "Denials in enforcing mode (blocked): $ENFORCING_AVC"
if [[ "$PERMISSIVE_AVC" -gt 0 ]]; then
  warn "Denials in permissive mode (allowed but logged): $PERMISSIVE_AVC"
  info "These would be blocked if enforcing were applied to those domains."
fi

echo
echo -e "${BOLD}AVC analysis complete.${RESET}"
```

---

### Script 03 — Context Audit

```bash
#!/usr/bin/env bash
# ============================================================================
# SELinux - Context Audit
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

# Ensure SELinux is active
if [[ "$(getenforce 2>/dev/null)" == "Disabled" ]]; then
  fail "SELinux is disabled. This script requires SELinux to be active."
  exit 1
fi

# ── Processes in Unexpected Domains ──────────────────────────────────────────
header "Process Context Audit"

info "Processes running in unconfined_t (should be minimal on hardened systems):"
UNCONFINED_PROCS=$(ps -eZ 2>/dev/null | grep "unconfined_t" | grep -v "^system_u" | \
  awk '{print $1, $NF}' | head -20)
if [[ -z "$UNCONFINED_PROCS" ]]; then
  ok "No user processes in unconfined_t (user processes) — good"
else
  echo "$UNCONFINED_PROCS" | while IFS= read -r line; do
    warn "  $line"
  done
fi

echo
info "System services NOT running in a dedicated confined domain:"
ps -eZ 2>/dev/null | grep "system_r" | grep "unconfined_t" | \
  awk '{print $NF}' | sort -u | head -10 | while IFS= read -r proc; do
    warn "  $proc"
  done || ok "All system services appear to be in confined domains"

echo
info "Processes in initrc_t (may indicate improper SysV init usage):"
INITRC_COUNT=$(ps -eZ 2>/dev/null | grep -c "initrc_t" || echo "0")
if [[ "$INITRC_COUNT" -gt 0 ]]; then
  warn "$INITRC_COUNT process(es) in initrc_t:"
  ps -eZ 2>/dev/null | grep "initrc_t" | awk '{print "    " $0}' | head -10
else
  ok "No processes in initrc_t"
fi

# ── Files with Incorrect Contexts ─────────────────────────────────────────────
header "File Context Integrity Check"

info "Checking key directories for incorrect file contexts (this may take a moment)..."

DIRS_TO_CHECK=(
  "/etc/httpd"
  "/var/www"
  "/etc/nginx"
  "/etc/ssh"
  "/etc/passwd"
  "/etc/shadow"
  "/var/log"
  "/etc/cron.d"
  "/usr/bin"
  "/usr/sbin"
)

MISMATCH_FOUND=0
for dir in "${DIRS_TO_CHECK[@]}"; do
  if [[ ! -e "$dir" ]]; then
    continue
  fi
  # Use matchpathcon to find mismatches
  MISMATCHES=$(find "$dir" -maxdepth 2 2>/dev/null | \
    matchpathcon -V -f /dev/stdin 2>/dev/null | \
    grep -v "^$\|verified$" | head -5 || true)
  if [[ -n "$MISMATCHES" ]]; then
    warn "Context mismatches in $dir:"
    echo "$MISMATCHES" | sed 's/^/    /'
    MISMATCH_FOUND=1
  fi
done

if [[ "$MISMATCH_FOUND" -eq 0 ]]; then
  ok "No file context mismatches found in checked directories"
fi

# ── Custom Port Labels ────────────────────────────────────────────────────────
header "Port Context Audit"

info "Ports with custom (locally added) context labels:"
CUSTOM_PORTS=$(semanage port -l --noheading 2>/dev/null | grep "^local" || \
  semanage port -l -C 2>/dev/null || echo "")

if [[ -z "$CUSTOM_PORTS" ]]; then
  ok "No custom port labels defined"
else
  echo "$CUSTOM_PORTS" | while IFS= read -r line; do
    info "  $line"
  done
fi

echo
info "Non-standard ports bound by running services:"
# Check ss output against known port types
ss -tlnpH 2>/dev/null | awk '{print $4}' | grep -oP ':\K[0-9]+$' | sort -un | \
  while read -r port; do
    PTYPE=$(semanage port -l 2>/dev/null | grep -E "\btcp\b" | awk -v p="$port" '
      BEGIN { found=0 }
      {
        for(i=3; i<=NF; i++) {
          gsub(",","", $i)
          if ($i == p) { print $1; found=1; exit }
        }
      }
      END { if (!found) print "UNLABELED" }
    ')
    if [[ "$PTYPE" == "UNLABELED" ]]; then
      warn "  Port $port/tcp — no SELinux label"
    fi
  done

# ── User Context Mappings ─────────────────────────────────────────────────────
header "SELinux User and Login Mapping Audit"

info "Current login mappings (Linux user → SELinux user):"
semanage login -l 2>/dev/null | while IFS= read -r line; do
  echo "  $line"
done

echo
info "Custom login mappings (non-default):"
CUSTOM_LOGINS=$(semanage login -l --noheading 2>/dev/null | grep -v "__default__\|root\|^$" || \
  semanage login -l -C 2>/dev/null || echo "")
if [[ -z "$CUSTOM_LOGINS" ]]; then
  ok "No custom user → SELinux user mappings"
else
  echo "$CUSTOM_LOGINS" | while IFS= read -r line; do
    info "  $line"
  done
fi

# ── Container SELinux Check ───────────────────────────────────────────────────
header "Container SELinux Status"

if command -v podman &>/dev/null; then
  info "Podman version: $(podman --version 2>/dev/null | head -1)"
  CONTAINERS_RUNNING=$(podman ps -q 2>/dev/null | wc -l || echo "0")
  info "Running containers: $CONTAINERS_RUNNING"

  if [[ "$CONTAINERS_RUNNING" -gt 0 ]]; then
    info "Container SELinux labels:"
    podman ps --format "{{.Names}}\t{{.Label}}" 2>/dev/null | \
      while IFS=$'\t' read -r name label; do
        if [[ -z "$label" ]]; then
          warn "  $name — NO SELinux label (--security-opt label=disable?)"
        else
          info "  $name — $label"
        fi
      done
  fi

  SELINUX_DISABLED_CONTAINERS=$(podman ps -a --format "{{.Names}}\t{{.Label}}" 2>/dev/null | \
    grep -c "label=disable" || echo "0")
  if [[ "$SELINUX_DISABLED_CONTAINERS" -gt 0 ]]; then
    warn "$SELINUX_DISABLED_CONTAINERS container(s) running with SELinux disabled"
  fi
else
  info "Podman not installed — skipping container check"
fi

if command -v container-selinux &>/dev/null || rpm -q container-selinux &>/dev/null; then
  ok "container-selinux package is installed"
else
  warn "container-selinux package not installed — containers will have limited SELinux confinement"
fi

echo
echo -e "${BOLD}Context audit complete.${RESET}"
```

---

### Script 04 — Policy Module Inventory

```bash
#!/usr/bin/env bash
# ============================================================================
# SELinux - Policy Module Inventory
# Version : 1.0.0
# Targets : RHEL 8+ with SELinux enabled
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $1"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $1"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $1"; }
info()   { echo -e "  ${CYAN}[INFO]${RESET}  $1"; }

# ── Module Summary ────────────────────────────────────────────────────────────
header "Policy Module Summary"

# semodule -lfull format: priority  name  version  [disabled]
FULL_LIST=$(semodule -lfull 2>/dev/null || semodule -l 2>/dev/null)

TOTAL=$(echo "$FULL_LIST" | grep -c "." || echo "0")
BASE=$(echo "$FULL_LIST" | grep -c "^100 " || echo "0")
CONTRIB=$(echo "$FULL_LIST" | grep -c "^200 " || echo "0")
LOCAL=$(echo "$FULL_LIST" | grep -cE "^[3-9][0-9]{2} " || echo "0")
DISABLED=$(echo "$FULL_LIST" | grep -c "disabled" || echo "0")

info "Total loaded modules: $TOTAL"
info "  Priority 100 (base):    $BASE"
info "  Priority 200 (contrib): $CONTRIB"
info "  Priority 300+ (local):  $LOCAL"
if [[ "$DISABLED" -gt 0 ]]; then
  warn "  Disabled modules: $DISABLED"
fi

# ── Custom/Local Modules ──────────────────────────────────────────────────────
header "Custom and Local Policy Modules (Priority 300+)"

LOCAL_MODULES=$(echo "$FULL_LIST" | grep -E "^[3-9][0-9]{2} " || echo "")

if [[ -z "$LOCAL_MODULES" ]]; then
  ok "No custom/local policy modules installed"
else
  info "Custom modules:"
  echo "  Priority  Module Name           Version    Status"
  echo "  ────────  ────────────────────  ─────────  ──────"
  echo "$LOCAL_MODULES" | while IFS= read -r line; do
    PRI=$(echo "$line" | awk '{print $1}')
    MOD=$(echo "$line" | awk '{print $2}')
    VER=$(echo "$line" | awk '{print $3}')
    STATUS=$(echo "$line" | grep -o "disabled" || echo "active")
    printf "  %-9s %-21s %-10s %s\n" "$PRI" "$MOD" "${VER:-n/a}" "$STATUS"
  done
fi

# Check for audit2allow-generated modules (often named 'local' or 'mypol')
AUTOGEN_MODULES=$(echo "$LOCAL_MODULES" | grep -iE "\blocal\b|mypol|audit2allow|tmp_" | \
  awk '{print $2}' || echo "")
if [[ -n "$AUTOGEN_MODULES" ]]; then
  warn "Possible audit2allow auto-generated modules (review these):"
  echo "$AUTOGEN_MODULES" | while IFS= read -r mod; do
    warn "  - $mod"
  done
fi

# ── Permissive Modules (per-domain) ──────────────────────────────────────────
header "Per-Domain Permissive Modules"

PERM_MODULES=$(semodule -lfull 2>/dev/null | grep "^400.*permissive_" || echo "")

if [[ -z "$PERM_MODULES" ]]; then
  ok "No per-domain permissive modules active"
else
  warn "Per-domain permissive modules (these domains bypass enforcement):"
  echo "$PERM_MODULES" | while IFS= read -r line; do
    DOMAIN=$(echo "$line" | awk '{print $2}' | sed 's/^permissive_//')
    warn "  - $DOMAIN"
  done
  echo
  info "To remove a permissive domain: semanage permissive -d <domain>"
fi

# ── Booleans Changed from Default ────────────────────────────────────────────
header "Booleans Changed from Default"

CHANGED=$(semanage boolean -l --noheading 2>/dev/null | \
  awk '{ if ($3 != $4) print }' || echo "")

if [[ -z "$CHANGED" ]]; then
  ok "All booleans at default values"
else
  COUNT=$(echo "$CHANGED" | wc -l)
  info "Booleans modified from default ($COUNT):"
  echo
  printf "  %-45s %-10s %-10s\n" "Boolean Name" "Current" "Default"
  printf "  %-45s %-10s %-10s\n" "────────────────────────────────────────────" "───────" "───────"
  echo "$CHANGED" | while IFS= read -r line; do
    NAME=$(echo "$line" | awk '{print $1}')
    CURR=$(echo "$line" | awk '{print $3}')
    DEFT=$(echo "$line" | awk '{print $4}')
    printf "  %-45s %-10s %-10s\n" "$NAME" "$CURR" "$DEFT"
  done
fi

# ── Recent Policy Changes ─────────────────────────────────────────────────────
header "Recent Policy Changes"

info "SELinux-related RPM package changes (last 30 days):"
rpm -qa --queryformat "%{INSTALLTIME:date} %{NAME}-%{VERSION}\n" 2>/dev/null | \
  grep -iE "selinux|setroubleshoot|policycoreutils|container-selinux|udica" | \
  sort -k1,3 -r | head -15 | while IFS= read -r line; do
    info "  $line"
  done

echo
info "Recent audit log entries related to policy changes:"
ausearch -m MAC_POLICY_LOAD -ts today 2>/dev/null | \
  grep "^type=MAC_POLICY_LOAD" | head -5 | \
  awk '{print "  " $0}' || ok "No policy load events today"

# ── Module File Inventory ─────────────────────────────────────────────────────
header "Local Policy Module Files"

MODULE_DIRS=(
  "/etc/selinux/targeted/active/modules"
  "/var/lib/selinux/targeted/active/modules"
  "/usr/share/selinux/targeted"
)

for dir in "${MODULE_DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    info "Policy files in $dir:"
    find "$dir" -maxdepth 3 -name "*.pp" -o -name "*.cil" 2>/dev/null | \
      sort | head -20 | while IFS= read -r f; do
        SIZE=$(du -sh "$f" 2>/dev/null | cut -f1)
        MTIME=$(stat -c "%y" "$f" 2>/dev/null | cut -d' ' -f1)
        info "  [$MTIME] [$SIZE] $f"
      done
  fi
done

# ── Policy Integrity Check ────────────────────────────────────────────────────
header "Policy Integrity"

POLICY_FILE=$(ls /etc/selinux/targeted/policy/policy.* 2>/dev/null | tail -1)
if [[ -n "$POLICY_FILE" ]]; then
  info "Active policy file: $POLICY_FILE"
  info "Policy file size: $(du -sh "$POLICY_FILE" | cut -f1)"
  info "Policy last modified: $(stat -c '%y' "$POLICY_FILE" | cut -d'.' -f1)"

  # Check if policy matches what's in the kernel
  KERNEL_VER=$(cat /sys/fs/selinux/policyvers 2>/dev/null || echo "unknown")
  FILE_VER=$(seinfo --stats 2>/dev/null | grep "Policy Version:" | grep -oP '\d+' | head -1 || echo "unknown")
  info "Kernel policy version: $KERNEL_VER"
  info "Policy file version: $FILE_VER"
else
  warn "No compiled policy file found in expected location"
fi

echo
echo -e "${BOLD}Policy module inventory complete.${RESET}"
```

---

## Part 5: Version-Specific Changes

### RHEL 8 — SELinux Updates

#### Key Additions in RHEL 8

**udica introduction (RHEL 8.1+)**:
udica was introduced in RHEL 8.1 as the recommended tool for generating custom SELinux policies for containers. It replaces the need to manually write policies for Podman and Docker containers.

```bash
dnf install udica    # Available in RHEL 8.1+
```

**container-selinux package**:
Full MCS isolation for containers became the default and well-tested configuration in RHEL 8. The `container_t` domain was substantially expanded with more precise rules. Automatic MCS category assignment by Podman became standard.

**Targeted policy expansion**:
RHEL 8 significantly expanded the targeted policy to confine more system services:
- Expanded `systemd` unit confinement
- Better `cockpit_t` confinement for the web console
- Improved `sssd_t` confinement for identity management

**semanage improvements**:
```bash
# New --noheading flag for scripting
semanage boolean -l --noheading
semanage port -l --noheading

# New -C flag to show only customizations
semanage fcontext -l -C
semanage port -l -C
semanage boolean -l -C
```

**Policy store location change**: Policy now lives in `/var/lib/selinux/` (module store) with `/etc/selinux/` for configuration and compiled policy.

**audit2allow improvements**: Better handling of dontaudit rules and cleaner output format.

---

### RHEL 9 — SELinux Updates

#### Key Additions in RHEL 9

**Performance improvements**:
The AVC (Access Vector Cache) was expanded and optimized, reducing latency overhead for SELinux enforcement on high-throughput workloads. Benchmark data from Red Hat shows ~5% overhead reduction on storage-intensive workloads.

**New policy modules in RHEL 9**:
- `ipa` — Extended FreeIPA/IdM confinement
- `keylime` — Remote attestation agent confinement
- `grafana_t` — Grafana monitoring confinement
- Improved `podman_t` / `container_t` transitions

**audit2allow CIL output**:
```bash
# Generate CIL (Common Intermediate Language) format instead of .te
ausearch -m AVC -ts recent | audit2allow --cil -M mypolicy
```

CIL policies are the native policy language for modern SELinux (vs. the older .te macro language). They are smaller and easier to reason about.

**Improved setroubleshoot**:
`setroubleshootd` in RHEL 9 includes better pattern matching and more accurate fix suggestions, including detection of common container and NFS scenarios.

**selinux-policy-doc package**:
```bash
dnf install selinux-policy-doc
man httpd_selinux   # Per-service SELinux man pages
man rsync_selinux
man samba_selinux
```

Man pages for each confined service describe all applicable booleans, types, and file context rules.

**Confined user improvements**:
RHEL 9 improved the `staff_u` and `sysadm_r` configurations for environments requiring user confinement beyond the default `unconfined_u`.

---

### RHEL 10 — SELinux Updates

#### Key Additions in RHEL 10

**Further enforcement improvements**:
RHEL 10 continues expanding the set of confined domains in the targeted policy, moving more services from `unconfined_t` into dedicated confined domains. This follows the principle of reducing the unconfined attack surface.

**Auditing flexibility**:
Enhanced audit rules allow more granular filtering of AVC events, reducing log noise in high-volume environments while retaining audit completeness for compliance:
```bash
# New audit filter options for AVC events in RHEL 10
auditctl -a always,exit -F arch=b64 -S all -F subj_type=httpd_t
```

**Policy development tools**:
Improved `sepolicy` tooling for generating policy templates:
```bash
sepolicy generate --init /usr/sbin/myapp   # Generate full policy scaffold
sepolicy booleans -d httpd_t               # Show booleans affecting a domain
sepolicy network -d httpd_t                # Show network access for a domain
```

**Container policy evolution**:
RHEL 10 aligns with the Podman 5.x container model with improved `container_t` policy, better rootless container confinement, and automatic label management for container volumes without requiring explicit `:Z`/`:z` flags in common scenarios.

**CIL-first policy approach**:
RHEL 10 accelerates the transition from M4 macro-based `.te` files to native CIL policy. The `semodule` tooling prefers CIL input, and `audit2allow --cil` output is now the recommended format for custom policy development.

---

## Quick Reference Card

### Most Used Commands

```bash
# Check status
getenforce
sestatus

# Temporary mode change (non-persistent)
setenforce 0    # permissive
setenforce 1    # enforcing

# Check denials
ausearch -m AVC -ts recent
ausearch -m AVC -ts today | audit2why
sealert -a /var/log/audit/audit.log

# Fix file contexts
semanage fcontext -a -t httpd_sys_content_t "/srv/web(/.*)?"
restorecon -Rv /srv/web/

# Fix ports
semanage port -a -t http_port_t -p tcp 8181

# Fix booleans
setsebool -P httpd_can_network_connect on
getsebool -a | grep httpd

# Generate policy from denials
ausearch -m AVC -ts recent | audit2allow -M myfix
cat myfix.te           # REVIEW before installing
semodule -i myfix.pp

# Per-domain permissive
semanage permissive -a httpd_t
semanage permissive -d httpd_t

# Container volumes
podman run -v /srv/data:/data:Z image    # private
podman run -v /srv/data:/data:z image    # shared
```

### Critical Files and Directories

| Path | Purpose |
|------|---------|
| `/etc/selinux/config` | Mode and policy type configuration |
| `/var/log/audit/audit.log` | AVC denials and audit events |
| `/var/log/messages` | setroubleshoot summaries |
| `/etc/selinux/targeted/contexts/files/file_contexts.local` | Local fcontext rules |
| `/sys/fs/selinux/` | Live SELinux kernel interface |
| `/var/lib/selinux/targeted/active/` | Active policy modules store |
