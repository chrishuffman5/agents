# RHEL Operational Best Practices (Cross-Version 8/9/10)

> Research compiled for RHEL agent library. Covers RHEL 8, 9, and 10 unless otherwise noted.

---

## 1. CIS Benchmark Hardening

### Password Quality (pwquality.conf)

Config file: `/etc/security/pwquality.conf`

```
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 4
maxrepeat = 3
maxclassrepeat = 4
gecoscheck = 1
dictcheck = 1
```

Apply via PAM: `/etc/pam.d/system-auth` and `/etc/pam.d/password-auth`
```
password requisite pam_pwquality.so try_first_pass local_users_only
```

### Account Lockout (pam_faillock)

Config file: `/etc/security/faillock.conf` (RHEL 8.2+)

```
deny = 5
fail_interval = 900
unlock_time = 900
even_deny_root
root_unlock_time = 60
```

PAM entries in `/etc/pam.d/system-auth` and `/etc/pam.d/password-auth`:
```
auth required pam_faillock.so preauth
auth required pam_faillock.so authfail
account required pam_faillock.so
```

Unlock a locked account: `faillock --user <username> --reset`

### Umask

Set in `/etc/profile`, `/etc/bashrc`, and `/etc/login.defs`:
```
umask 027
```

For `/etc/login.defs`:
```
UMASK 027
```

### SSH Hardening (/etc/ssh/sshd_config)

```
PermitRootLogin no
MaxAuthTries 4
MaxSessions 10
IgnoreRhosts yes
PermitEmptyPasswords no
PasswordAuthentication no
UsePAM yes
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitUserEnvironment no
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 3
Banner /etc/issue.net
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group14-sha256
```

Validate config: `sshd -t`
Apply changes: `systemctl reload sshd`

### File Permissions

```bash
# Critical files
chmod 644 /etc/passwd
chmod 000 /etc/shadow
chmod 644 /etc/group
chmod 600 /etc/gshadow
chown root:root /etc/passwd /etc/group
chown root:shadow /etc/shadow /etc/gshadow

# SSH host keys
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
```

### SUID/SGID Audit

```bash
# Find all SUID binaries
find / -xdev -perm /4000 -type f 2>/dev/null

# Find all SGID binaries
find / -xdev -perm /2000 -type f 2>/dev/null

# Remove SUID/SGID where not required
chmod u-s /path/to/binary
chmod g-s /path/to/binary
```

### Banners

`/etc/issue` (local console) and `/etc/issue.net` (SSH):
```
Authorized users only. All activity may be monitored and reported.
```

MOTD: `/etc/motd`

### Core Dump Restrictions

`/etc/security/limits.conf`:
```
* hard core 0
```

`/etc/sysctl.d/60-coredump.conf`:
```
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false
```

systemd: `/etc/systemd/coredump.conf`:
```
[Coredump]
Storage=none
ProcessSizeMax=0
```

### ASLR

`/etc/sysctl.d/60-aslr.conf`:
```
kernel.randomize_va_space = 2
```
Apply: `sysctl -p /etc/sysctl.d/60-aslr.conf`

### Disable Unused Filesystems

`/etc/modprobe.d/cis-filesystems.conf`:
```
install cramfs /bin/true
install squashfs /bin/true
install udf /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
```

---

## 2. firewalld Configuration

### Zone Overview

| Zone | Policy | Use Case |
|------|--------|----------|
| drop | Drop all incoming | Maximum security edge |
| block | Reject incoming | Controlled rejection |
| public | Default for untrusted NICs | Servers facing internet |
| internal | Trusted internal traffic | LAN interfaces |
| trusted | Accept all traffic | Management interfaces |
| dmz | Limited services | Demilitarized zone |
| work | Work network | Corporate desktop |
| home | Home network | Desktop with MDNS |

### Basic Commands

```bash
# Runtime vs Permanent
firewall-cmd --add-service=http                     # runtime only
firewall-cmd --add-service=http --permanent         # permanent
firewall-cmd --reload                               # apply permanent rules

# Zone assignment
firewall-cmd --zone=internal --change-interface=eth1 --permanent

# List all zones
firewall-cmd --list-all-zones

# Active zones
firewall-cmd --get-active-zones

# Default zone
firewall-cmd --get-default-zone
firewall-cmd --set-default-zone=public
```

### Service Definitions

```bash
# Add predefined service
firewall-cmd --zone=public --add-service=https --permanent

# Custom service definition: /etc/firewalld/services/myapp.xml
cat > /etc/firewalld/services/myapp.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>MyApp</short>
  <description>Custom application service</description>
  <port protocol="tcp" port="8443"/>
</service>
EOF

firewall-cmd --reload
firewall-cmd --zone=public --add-service=myapp --permanent
```

### Rich Rules

```bash
# Allow specific source IP to specific service
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept' --permanent

# Rate limit connections
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" service name="http" limit value="25/m" accept' --permanent

# Log and drop
firewall-cmd --zone=drop --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" log prefix="BLOCKED:" level="warning" drop' --permanent

# Allow port range
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" port port="8080-8090" protocol="tcp" accept' --permanent
```

### Port Forwarding and Masquerading

```bash
# Enable masquerade (required for forwarding/NAT)
firewall-cmd --zone=public --add-masquerade --permanent

# Port forward: external 80 -> internal host port 8080
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=192.168.1.100 --permanent

# Local port forward (same host)
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
```

### Panic Mode

```bash
# Enable panic mode (drop all packets immediately)
firewall-cmd --panic-on

# Disable panic mode
firewall-cmd --panic-off

# Check panic status
firewall-cmd --query-panic
```

---

## 3. Tuned Profiles

### Available Profiles

| Profile | Use Case |
|---------|----------|
| balanced | Default; balance power and performance |
| throughput-performance | High-throughput servers |
| latency-performance | Low latency (disables power saving) |
| network-latency | Low-latency networking |
| network-throughput | High network throughput |
| powersave | Maximum power saving |
| virtual-guest | RHEL as a VM guest |
| virtual-host | RHEL as a VM host |
| sap-hana | SAP HANA in-memory DB |
| oracle | Oracle DB workloads |
| mssql | SQL Server on Linux |
| desktop | Desktop responsiveness |
| hpc-compute | HPC cluster nodes |

### tuned-adm Commands

```bash
# List available profiles
tuned-adm list

# Active profile
tuned-adm active

# Switch profile
tuned-adm profile throughput-performance

# Recommend profile for current system
tuned-adm recommend

# Disable tuned temporarily
tuned-adm off

# Verify profile applied
tuned-adm verify
```

### Custom Profile Creation

Directory: `/etc/tuned/<profile-name>/tuned.conf`

```ini
[main]
summary=Custom production server profile
include=throughput-performance

[sysctl]
vm.swappiness=10
net.core.somaxconn=65535

[disk]
elevator=mq-deadline

[cpu]
force_latency=1
governor=performance
```

Activate: `tuned-adm profile <profile-name>`

---

## 4. System-Wide Crypto Policies

### Available Policies

| Policy | Description |
|--------|-------------|
| DEFAULT | Secure defaults for current RHEL |
| LEGACY | Wider compatibility (SHA-1, older TLS) |
| FUTURE | Stricter; forward-looking |
| FIPS | FIPS 140-2/3 compliance |
| FIPS:OSPP | FIPS + Common Criteria |

### Commands

```bash
# View current policy
update-crypto-policies --show

# Apply a policy
update-crypto-policies --set DEFAULT
update-crypto-policies --set FIPS
update-crypto-policies --set FUTURE

# Custom sub-policy (create in /etc/crypto-policies/policies/modules/)
cat > /etc/crypto-policies/policies/modules/NO-SHA1.pmod <<EOF
hash = -SHA1
sign = -RSA-SHA1 -ECDSA-SHA1 -DSA-SHA1
EOF

update-crypto-policies --set DEFAULT:NO-SHA1
```

### Affected Libraries

- OpenSSL: `/etc/pki/tls/openssl.cnf` includes crypto-policy directives
- GnuTLS: respects `/etc/crypto-policies/back-ends/gnutls.config`
- NSS: `/etc/crypto-policies/back-ends/nss.config`
- OpenSSH: inherits from `/etc/crypto-policies/back-ends/openssh*.txt`
- libkrb5: `/etc/crypto-policies/back-ends/krb5.config`

### FIPS Mode Enablement

```bash
# Enable FIPS mode (requires reboot)
fips-mode-setup --enable
reboot

# Verify FIPS mode
fips-mode-setup --check
cat /proc/sys/crypto/fips_enabled   # returns 1 if enabled

# On RHEL 9+ (kernel parameter approach)
grubby --update-kernel=ALL --args="fips=1"
# Also requires boot partition in same volume as root, or add boot=<device>
```

---

## 5. Patching Strategy

### dnf Update Workflows

```bash
# Full system update
dnf update -y

# Security updates only
dnf update --security -y

# Apply specific advisory
dnf update --advisory=RHSA-2024:1234 -y

# Check available security updates without applying
dnf check-update --security

# List security advisories
dnf updateinfo list security
dnf updateinfo list critical

# Show details on advisory
dnf updateinfo info RHSA-2024:1234
```

### Errata Types

- **RHSA** — Red Hat Security Advisory (CVEs)
- **RHBA** — Red Hat Bug Advisory (bug fixes)
- **RHEA** — Red Hat Enhancement Advisory (enhancements)

```bash
# Filter by errata type
dnf updateinfo list --security    # RHSA only
dnf updateinfo list --bugfix      # RHBA only
dnf updateinfo list --enhancement # RHEA only
```

### dnf-automatic (Auto Patching)

Config: `/etc/dnf/automatic.conf`

```ini
[commands]
upgrade_type = security
apply_updates = yes
random_sleep = 360

[email]
email_from = root@localhost
email_to = admin@example.com
email_host = localhost
```

Enable:
```bash
systemctl enable --now dnf-automatic.timer
# Or for download-only:
systemctl enable --now dnf-automatic-download.timer
```

### Patch Rollback

```bash
# View dnf history
dnf history list

# Undo last transaction
dnf history undo last

# Undo specific transaction by ID
dnf history undo 42

# Info on specific transaction
dnf history info 42
```

### Kernel Rollback via GRUB

```bash
# List installed kernels
rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n'

# List GRUB entries
grubby --info=ALL

# Set specific kernel as default
grubby --set-default /boot/vmlinuz-<version>

# Boot once into older kernel (temporary)
grub2-reboot <menu-entry-number>
```

---

## 6. User and Access Management

### Local User Management

```bash
# Create user with home dir, shell, comment
useradd -m -s /bin/bash -c "App Service Account" appuser

# Set password
passwd appuser

# Lock/unlock account
passwd -l appuser
passwd -u appuser

# Set password aging (chage)
chage -M 90 -m 7 -W 14 -I 30 username
# -M max days, -m min days, -W warn days, -I inactive days

# View aging info
chage -l username

# Force password change on next login
chage -d 0 username

# Set account expiry
chage -E 2025-12-31 username
```

### sudo Configuration

Best practice: use drop-in files in `/etc/sudoers.d/` rather than editing `/etc/sudoers` directly.

```bash
# Edit safely
visudo -f /etc/sudoers.d/myapp

# Example drop-in: /etc/sudoers.d/webadmins
%webadmins ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart httpd, /usr/bin/systemctl status httpd

# Require password for sudo
%sysadmins ALL=(ALL) ALL

# Allow specific command with logging
Defaults logfile=/var/log/sudo.log
Defaults log_input, log_output
```

Validate: `visudo -c`

### SSSD for Centralized Authentication

Config: `/etc/sssd/sssd.conf`

```ini
[sssd]
domains = example.com
services = nss, pam, ssh

[domain/example.com]
id_provider = ad
auth_provider = ad
access_provider = ad
ad_domain = example.com
krb5_realm = EXAMPLE.COM
realmd_tags = manages-system joined-with-adcli
cache_credentials = True
default_shell = /bin/bash
fallback_homedir = /home/%u@%d
use_fully_qualified_names = False
ldap_id_mapping = True
```

Join domain with realmd:
```bash
realm discover example.com
realm join --user=Administrator example.com
realm list
```

### authselect Profiles

```bash
# List available profiles
authselect list

# Apply SSSD profile
authselect select sssd --force

# With additional features
authselect select sssd with-faillock with-mkhomedir --force

# Current profile
authselect current
```

---

## 7. Logging and Audit

### rsyslog vs journald

- **journald**: binary, structured, per-boot, stored in `/run/log/journal` (volatile) or `/var/log/journal` (persistent)
- **rsyslog**: text-based, traditional syslog, reads from journald via imjournal

### Persistent Journal Configuration

`/etc/systemd/journald.conf`:
```ini
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=2G
SystemKeepFree=1G
MaxFileSec=1month
MaxRetentionSec=1year
ForwardToSyslog=yes
```

Apply: `systemctl restart systemd-journald`

Create persistent dir if needed:
```bash
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald
```

### Log Rotation

Config: `/etc/logrotate.conf` and `/etc/logrotate.d/`

Example `/etc/logrotate.d/app`:
```
/var/log/myapp/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 appuser adm
    postrotate
        systemctl reload myapp > /dev/null 2>&1 || true
    endscript
}
```

### Audit Rules

Config directory: `/etc/audit/rules.d/`
Apply changes: `augenrules --load` or `systemctl restart auditd`

Key audit rules (`/etc/audit/rules.d/cis.rules`):
```
# Buffer size and failure mode
-b 8192
-f 1

# File system access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access
-a always,exit -F arch=b64 -S open,truncate,ftruncate,creat,openat -F exit=-EPERM -k access

# Privileged commands
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
-a always,exit -F path=/usr/bin/su -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged

# User/group changes
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope

# Network config changes
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale

# Module loading/unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module,delete_module -k modules

# Immutable (must be last rule)
-e 2
```

### aureport Patterns

```bash
# Summary report
aureport --summary

# Failed logins
aureport --auth --failed

# Privilege escalation
aureport --tty

# Specific key
ausearch -k identity --start today --interpret

# By user
ausearch -ua 1000 --interpret

# Recent events
ausearch --start recent --interpret
```

---

## 8. Backup and Recovery

### ReaR (Relax and Recover)

Install: `dnf install rear -y`

Config: `/etc/rear/local.conf`

```bash
# Basic ISO backup to NFS
OUTPUT=ISO
BACKUP=NETFS
BACKUP_URL=nfs://nfsserver/backups/rear
BACKUP_PROG_EXCLUDE+=( '/tmp/*' '/dev/shm/*' '/run/*' )
BACKUP_OPTIONS="nfsvers=4,nolock"
REQUIRED_PROGS+=( snapper btrfs )

# Create backup
rear -v mkbackup

# Create rescue media only
rear -v mkrescue

# Test recovery layout
rear -v checklayout
```

Recovery: boot from ReaR ISO, run `rear recover`

### LVM Snapshots for Consistent Backups

```bash
# Create snapshot (requires free space in VG)
lvcreate -L 10G -s -n snap_root /dev/vg0/root

# Mount snapshot read-only for backup
mount -o ro,nouuid /dev/vg0/snap_root /mnt/snapshot

# Backup snapshot contents
rsync -aAX --exclude '/proc/*' --exclude '/sys/*' /mnt/snapshot/ /backup/root/

# Remove snapshot after backup
umount /mnt/snapshot
lvremove -f /dev/vg0/snap_root
```

### rsync Strategies

```bash
# Full rsync backup with preservation of attributes
rsync -aAXv --exclude='/dev' --exclude='/proc' --exclude='/sys' \
  --exclude='/tmp' --exclude='/run' --exclude='/mnt' \
  / user@backup-server:/backups/$(hostname)/full/

# Incremental using --link-dest
rsync -aAXv --link-dest=/backups/$(hostname)/latest/ \
  / user@backup-server:/backups/$(hostname)/$(date +%Y%m%d)/

# Update latest symlink
ssh user@backup-server "ln -sfn /backups/$(hostname)/$(date +%Y%m%d) /backups/$(hostname)/latest"
```

### Stratis Snapshots (RHEL 8+)

```bash
# Create Stratis pool and filesystem
stratis pool create mypool /dev/sdb
stratis fs create mypool myfs
mount /dev/stratis/mypool/myfs /mydata

# Create snapshot
stratis fs snapshot mypool myfs myfs-snap-$(date +%Y%m%d)

# List snapshots
stratis fs list mypool

# Mount snapshot
mount /dev/stratis/mypool/myfs-snap-20240101 /mnt/snapshot
```

---

## 9. Performance Tuning

### Key sysctl Parameters

`/etc/sysctl.d/99-performance.conf`:

```
# Memory management
vm.swappiness = 10
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 50

# File descriptors
fs.file-max = 2097152

# Network performance
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 300
net.ipv4.ip_local_port_range = 1024 65535

# IPC
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
```

Apply: `sysctl --system`

### Huge Pages Configuration

Static huge pages (`/etc/sysctl.d/99-hugepages.conf`):
```
vm.nr_hugepages = 512
```

Transparent Huge Pages (THP) - disable for databases:
```bash
# Check current THP status
cat /sys/kernel/mm/transparent_hugepage/enabled

# Disable via tuned profile or directly
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

# Persistent via tuned custom profile
[vm]
transparent_hugepages=never
```

### NUMA Awareness

```bash
# Install tools
dnf install numactl numad -y

# View NUMA topology
numactl --hardware
numactl --show

# Run process on specific NUMA node
numactl --cpunodebind=0 --membind=0 myprocess

# Enable numad for automatic NUMA management
systemctl enable --now numad

# Check NUMA stats
numastat
numastat -p <pid>
```

### I/O Scheduler Selection

```bash
# Check current scheduler per device
cat /sys/block/sda/queue/scheduler

# Set scheduler (mq-deadline for SATA, none/noop for NVMe/SSD)
echo mq-deadline > /sys/block/sda/queue/scheduler
echo none > /sys/block/nvme0n1/queue/scheduler

# Persistent via udev rule: /etc/udev/rules.d/60-io-scheduler.rules
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="none"

# Via tuned profile
[disk]
elevator=mq-deadline
```

---

## 10. Subscription and Entitlement Management

### subscription-manager Commands

```bash
# Register system
subscription-manager register --username=user@example.com --password=pass
# Or with activation key (preferred for automation)
subscription-manager register --org=MyOrg --activationkey=rhel9-prod

# List available subscriptions
subscription-manager list --available

# Attach subscription
subscription-manager attach --auto
subscription-manager attach --pool=<pool-id>

# List attached subscriptions
subscription-manager list --consumed

# View system status
subscription-manager status

# Unregister
subscription-manager unregister

# Remove all entitlements
subscription-manager remove --all
```

### Content Access Modes

Simple Content Access (SCA) — recommended for RHEL 8.1+:
```bash
# SCA is enabled at org level in Red Hat Customer Portal
# When SCA is active, all entitled content is accessible without pool attachment
subscription-manager config --rhsm.manage_repos=1
```

### Repository Management

```bash
# List available repos
subscription-manager repos --list

# Enable specific repo
subscription-manager repos --enable=rhel-9-for-x86_64-baseos-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
subscription-manager repos --enable=rhel-9-for-x86_64-supplementary-rpms

# Disable repo
subscription-manager repos --disable=<repo-id>

# List enabled repos
subscription-manager repos --list-enabled
dnf repolist
```

### Red Hat Insights

```bash
# Install client
dnf install insights-client -y

# Register with Insights
insights-client --register

# Run assessment
insights-client

# Check status
insights-client --status

# Unregister
insights-client --unregister
```

### Convert2RHEL (CentOS/OracleLinux Migration)

```bash
# Install convert2rhel
curl -o /etc/yum.repos.d/convert2rhel.repo https://ftp.redhat.com/redhat/convert2rhel/8/convert2rhel.repo
dnf install convert2rhel -y

# Pre-conversion analysis only
convert2rhel analyze --username user@example.com --password pass

# Full conversion
convert2rhel --username user@example.com --password pass
# Or with activation key
convert2rhel --org MyOrg --activationkey rhel-convert-key
```

---

## Quick Reference: Key Config Files

| Category | Config File |
|----------|-------------|
| Password quality | `/etc/security/pwquality.conf` |
| Account lockout | `/etc/security/faillock.conf` |
| SSH daemon | `/etc/ssh/sshd_config` |
| Crypto policy | `/etc/crypto-policies/config` |
| Audit rules | `/etc/audit/rules.d/*.rules` |
| Journal | `/etc/systemd/journald.conf` |
| sysctl tuning | `/etc/sysctl.d/99-performance.conf` |
| Firewalld zones | `/etc/firewalld/zones/` |
| Custom services | `/etc/firewalld/services/` |
| tuned profile | `/etc/tuned/<name>/tuned.conf` |
| SSSD | `/etc/sssd/sssd.conf` |
| sudoers drop-ins | `/etc/sudoers.d/` |
| ReaR backup | `/etc/rear/local.conf` |
| dnf-automatic | `/etc/dnf/automatic.conf` |
| GRUB config | `/etc/default/grub` |
| Module blocklist | `/etc/modprobe.d/` |
| Login defaults | `/etc/login.defs` |
| PAM auth | `/etc/pam.d/system-auth`, `/etc/pam.d/password-auth` |
| Logrotate | `/etc/logrotate.d/` |
| Limits | `/etc/security/limits.conf` |
