# SELinux Best Practices Reference

## Policy Management with semanage

`semanage` is the primary tool for persistent policy customization without writing raw policy files. All changes are stored in `/etc/selinux/targeted/` and survive policy rebuilds.

### File Context Management

```bash
# List all file context rules
semanage fcontext -l

# List only local customizations
semanage fcontext -l -C

# Add rule for a custom web root
semanage fcontext -a -t httpd_sys_content_t "/srv/www(/.*)?"

# Add rule for writable directory (uploads, caches)
semanage fcontext -a -t httpd_sys_rw_content_t "/srv/www/uploads(/.*)?"

# Add rule for CGI scripts
semanage fcontext -a -t httpd_sys_script_exec_t "/srv/www/cgi-bin(/.*)?"

# Modify existing rule
semanage fcontext -m -t httpd_sys_rw_content_t "/srv/www/uploads(/.*)?"

# Delete rule
semanage fcontext -d "/srv/www(/.*)?"

# Equivalence rule (relocate data to new path)
semanage fcontext -a -e /var/lib/pgsql /data/pgsql

# Apply rules to filesystem
restorecon -Rv /srv/www/
```

### Port Management

```bash
# List all port contexts
semanage port -l

# List only customizations
semanage port -l -C

# Add port label
semanage port -a -t http_port_t -p tcp 8181

# Delete port label
semanage port -d -t http_port_t -p tcp 8181

# Modify port label
semanage port -m -t http_port_t -p tcp 8181
```

### Login and User Management

```bash
# Map Linux user to SELinux user
semanage login -a -s staff_u webadmin

# Remove mapping
semanage login -d webadmin

# Add SELinux user with roles
semanage user -a -R "staff_r sysadm_r" myuser_u

# List mappings
semanage login -l
semanage user -l
```

### Module Management via semanage

```bash
# List loaded modules
semanage module -l

# Disable module
semanage module -d mymodule

# Enable module
semanage module -e mymodule
```

---

## Boolean Management

Booleans are the preferred first-line mechanism for adjusting SELinux policy. Always check for an applicable boolean before writing custom policy.

### Inspecting Booleans

```bash
# List all booleans with current and default values
getsebool -a
semanage boolean -l

# Find booleans changed from default
semanage boolean -l | awk '$3 != $4'

# Search for booleans by service
semanage boolean -l | grep httpd
getsebool -a | grep samba
```

### Setting Booleans

```bash
# Set boolean (persistent, survives reboot)
setsebool -P httpd_can_network_connect on

# Set boolean (non-persistent, immediate)
setsebool httpd_can_network_connect on

# Set multiple booleans at once
setsebool -P httpd_can_network_connect on httpd_use_nfs on

# Via semanage (always persistent)
semanage boolean -m --on httpd_can_network_connect
```

### Common Booleans by Service

**Web Server (httpd)**:

| Boolean | Description |
|---|---|
| `httpd_can_network_connect` | Allow httpd to make outbound network connections |
| `httpd_can_network_connect_db` | Allow httpd to connect to databases |
| `httpd_can_sendmail` | Allow httpd to send mail |
| `httpd_can_network_relay` | Allow httpd to act as a relay/proxy |
| `httpd_use_nfs` | Allow httpd to serve NFS-mounted content |
| `httpd_use_cifs` | Allow httpd to serve CIFS-mounted content |
| `httpd_enable_cgi` | Allow httpd to execute CGI scripts |
| `httpd_enable_homedirs` | Allow httpd to read home directories |
| `httpd_execmem` | Allow httpd to use execmem (for PHP, mod_python) |

**Samba**:

| Boolean | Description |
|---|---|
| `samba_enable_home_dirs` | Allow Samba to share home directories |
| `samba_export_all_ro` | Allow Samba to export any file read-only |
| `samba_export_all_rw` | Allow Samba to export any file read-write |
| `samba_share_nfs` | Allow Samba to share NFS-mounted volumes |

**SSH / Remote Access**:

| Boolean | Description |
|---|---|
| `ssh_sysadm_login` | Allow SSH login by sysadm_r users |
| `rsync_export_all_ro` | Allow rsync to export all files read-only |

**Virtualization / Containers**:

| Boolean | Description |
|---|---|
| `virt_use_nfs` | Allow VMs to use NFS storage |
| `virt_use_samba` | Allow VMs to use Samba storage |
| `container_manage_cgroup` | Allow containers to manage cgroups |

**NFS / CIFS**:

| Boolean | Description |
|---|---|
| `use_nfs_home_dirs` | Allow NFS-mounted home directories |
| `use_samba_home_dirs` | Allow CIFS-mounted home directories |

---

## Custom Policy Modules

### When to Use Custom Modules

Decision order (prefer the simplest fix):
1. **Boolean** -- if one exists that covers the use case
2. **File context** (`semanage fcontext`) -- for files in non-standard locations
3. **Port label** (`semanage port`) -- for services on non-standard ports
4. **Custom module** -- only when none of the above suffice, or you are confining a custom application

### Module File Types

- `.te` -- Type Enforcement file (main policy rules)
- `.if` -- Interface file (macros callable by other modules)
- `.fc` -- File Contexts file (labeling rules)
- `.pp` -- Compiled Policy Package (binary, loaded by semodule)

### Writing a .te File

```
# mypolicy.te
policy_module(mypolicy, 1.0)

# Declare types
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

### Writing a .fc File

```
# mypolicy.fc
/usr/bin/myapp         -- gen_context(system_u:object_r:myapp_exec_t,s0)
/var/log/myapp(/.*)?   gen_context(system_u:object_r:myapp_log_t,s0)
/var/lib/myapp(/.*)?   gen_context(system_u:object_r:myapp_data_t,s0)
```

### Compiling and Installing

```bash
# Compile .te to .mod
checkmodule -M -m -o mypolicy.mod mypolicy.te

# Package into .pp
semodule_package -o mypolicy.pp -m mypolicy.mod -f mypolicy.fc

# Install
semodule -i mypolicy.pp

# Apply file contexts
restorecon -Rv /usr/bin/myapp /var/log/myapp /var/lib/myapp
```

### The audit2allow Workflow

The recommended workflow for generating custom policy from AVC denials:

```bash
# 1. Put the domain in per-domain permissive
semanage permissive -a myapp_t

# 2. Run the application and trigger the denied operations

# 3. Collect AVC denials for your domain
ausearch -m AVC -c myapp 2>/dev/null | audit2allow

# 4. Generate a policy module
ausearch -m AVC -c myapp 2>/dev/null | audit2allow -M mypolicy

# 5. Review the generated .te file (CRITICAL -- never skip this)
cat mypolicy.te

# 6. Install if acceptable
semodule -i mypolicy.pp

# 7. Remove permissive domain
semanage permissive -d myapp_t
```

WARNING: `audit2allow` generates minimal allow rules. Always review before installing. Never use `audit2allow -a` on a production system -- it generates rules for all denials system-wide.

### Module Management with semodule

```bash
# List installed modules
semodule -l
semodule -lfull    # Include priorities and disabled status

# Install module
semodule -i mypolicy.pp

# Install with specific priority (default 400)
semodule -X 300 -i mypolicy.pp

# Remove module
semodule -r mypolicy

# Disable without removing
semodule -d mypolicy

# Enable a disabled module
semodule -e mypolicy

# Rebuild the active policy
semodule -B
```

Module priorities: 100 (base), 200 (contrib), 300 (local), 400 (custom overrides).

---

## Container SELinux

### container-selinux Package

Provides SELinux policy for containerized workloads:
- `container_t` -- domain for container processes
- `container_file_t` -- label for container image layers and volumes
- `container_runtime_t` -- domain for container runtimes (Podman, Docker)
- `container_var_lib_t` -- `/var/lib/containers` label

```bash
rpm -q container-selinux
```

### MCS Isolation Between Containers

Each container gets a unique MCS category pair automatically:
```
container_t:s0:c123,c456   # Container A
container_t:s0:c789,c012   # Container B
```

MCS policy requires matching categories, so Container A cannot access Container B's files even though both run in `container_t`.

### Volume Mount Labels -- :Z and :z

```bash
# :z -- Shared label (relabel with shared type, all containers can access)
podman run -v /srv/shared:/data:z myimage

# :Z -- Private label (relabel with container-private MCS label)
podman run -v /srv/private:/data:Z myimage
```

`:Z` uses the container's unique MCS label. `:z` uses a shared container label.

WARNING: `:Z` modifies the host directory's SELinux label. Never use `:Z` on system directories like `/home`, `/etc`, `/var`.

### udica -- Custom Container Policies

`udica` generates SELinux policies tailored to a container's specific needs:

```bash
# Install
dnf install udica

# Generate policy from a running container
podman inspect mycontainer | udica mycontainer_policy

# Install the generated policy
semodule -i mycontainer_policy.cil /usr/share/udica/templates/*.cil

# Run the container with the custom label
podman run --security-opt label=type:mycontainer_policy.process ...
```

`udica` examines port bindings, volume mounts, and capabilities to produce a least-privilege CIL policy.

---

## File Context Management

### The File Context Database

SELinux maps path patterns to security contexts:

| File | Purpose |
|---|---|
| `file_contexts` | Base policy contexts (do not edit) |
| `file_contexts.local` | Local additions from semanage |
| `file_contexts.homedirs` | Home directory contexts |
| `file_contexts.subs` | Path substitution rules |

All under `/etc/selinux/targeted/contexts/files/`.

### restorecon -- Restore File Contexts

```bash
# Restore context of a single file
restorecon /var/www/html/index.html

# Recursive restore with verbose output
restorecon -Rv /srv/www/

# Dry-run (show what would change)
restorecon -Rvn /srv/www/

# Force relabel even if context appears correct
restorecon -RvF /var/www/html/
```

### chcon -- Temporary Context Change

Changes context directly on files. Does NOT update the policy database. Changes are lost if `restorecon` is run or filesystem is relabeled.

```bash
# Change type only
chcon -t httpd_sys_content_t /tmp/testfile.html

# Recursive change
chcon -R -t httpd_sys_content_t /srv/content/

# Reference another file's context
chcon --reference=/var/www/html /srv/www/
```

Use case: quick testing before making permanent with `semanage fcontext` + `restorecon`.

### matchpathcon -- Verify Expected Context

```bash
# Check what context policy expects
matchpathcon /var/www/html/index.html

# Verify against actual context (reports mismatch if wrong)
matchpathcon -V /var/www/html/index.html
```

### Common File Types for Web/App Servers

| Type | Purpose |
|---|---|
| `httpd_sys_content_t` | Static web content (read-only) |
| `httpd_sys_rw_content_t` | Web content httpd can write (uploads, caches) |
| `httpd_sys_script_exec_t` | CGI scripts and executables |
| `httpd_log_t` | Web server log files |
| `httpd_config_t` | Web server configuration |
| `httpd_var_run_t` | PID files and sockets |
| `httpd_cache_t` | Web server caches |
