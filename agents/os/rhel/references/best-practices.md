# RHEL Operational Best Practices

## 1. CIS Benchmark Hardening

### Password Quality

Config: `/etc/security/pwquality.conf`

```
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 4
maxrepeat = 3
gecoscheck = 1
dictcheck = 1
```

### Account Lockout (pam_faillock)

Config: `/etc/security/faillock.conf` (RHEL 8.2+)

```
deny = 5
fail_interval = 900
unlock_time = 900
even_deny_root
root_unlock_time = 60
```

Unlock: `faillock --user <username> --reset`

### SSH Hardening

Key settings for `/etc/ssh/sshd_config`:

```
PermitRootLogin no
MaxAuthTries 4
PasswordAuthentication no
UsePAM yes
X11Forwarding no
AllowTcpForwarding no
ClientAliveInterval 300
ClientAliveCountMax 3
Banner /etc/issue.net
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
```

Validate: `sshd -t`. Apply: `systemctl reload sshd`.

### File Permissions

```bash
chmod 644 /etc/passwd && chmod 000 /etc/shadow
chmod 644 /etc/group && chmod 600 /etc/gshadow
chmod 600 /etc/ssh/ssh_host_*_key
```

### Core Dump Restrictions

`/etc/security/limits.conf`: `* hard core 0`
`/etc/sysctl.d/60-coredump.conf`: `fs.suid_dumpable = 0`

### Disable Unused Filesystems

`/etc/modprobe.d/cis-filesystems.conf`:
```
install cramfs /bin/true
install squashfs /bin/true
install udf /bin/true
```

---

## 2. firewalld Configuration

### Zone Overview

| Zone | Policy | Use Case |
|------|--------|----------|
| drop | Drop all incoming | Maximum security edge |
| public | Default for untrusted NICs | Internet-facing servers |
| internal | Trusted internal traffic | LAN interfaces |
| trusted | Accept all | Management interfaces |
| dmz | Limited services | Demilitarized zone |

### Service and Port Management

```bash
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-port=8080/tcp --permanent
firewall-cmd --reload

# Custom service: /etc/firewalld/services/myapp.xml
firewall-cmd --zone=public --add-service=myapp --permanent
```

### Rich Rules

```bash
# Allow subnet to SSH
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept' --permanent

# Rate limit HTTP
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" service name="http" limit value="25/m" accept' --permanent

# Port forwarding (requires masquerade)
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=192.168.1.100 --permanent
```

---

## 3. Tuned Profiles

### Key Profiles

| Profile | Use Case |
|---------|----------|
| balanced | Default; power/performance balance |
| throughput-performance | High-throughput servers |
| latency-performance | Low latency (disables power saving) |
| virtual-guest | RHEL as VM guest |
| virtual-host | RHEL as VM host |
| sap-hana | SAP HANA workloads |
| mssql | SQL Server on Linux |

### Commands

```bash
tuned-adm list                         # available profiles
tuned-adm active                       # current profile
tuned-adm profile throughput-performance
tuned-adm recommend                    # auto-recommend
tuned-adm verify                       # verify applied
```

### Custom Profile

Directory: `/etc/tuned/<profile-name>/tuned.conf`

```ini
[main]
summary=Custom production profile
include=throughput-performance

[sysctl]
vm.swappiness=10
net.core.somaxconn=65535

[cpu]
governor=performance
```

---

## 4. System-Wide Crypto Policies

### Policies

| Policy | Description |
|--------|-------------|
| DEFAULT | Secure defaults (TLS 1.2+, RSA >= 2048, SHA-1 deprecated) |
| LEGACY | Wider compatibility (SHA-1, TLS 1.0/1.1) |
| FUTURE | Stricter (TLS 1.3 only, RSA >= 3072) |
| FIPS | FIPS 140-2/3 compliance |

### Commands

```bash
update-crypto-policies --show
update-crypto-policies --set DEFAULT
update-crypto-policies --set DEFAULT:NO-SHA1   # sub-policy

# FIPS mode
fips-mode-setup --enable                       # requires reboot
fips-mode-setup --check
cat /proc/sys/crypto/fips_enabled
```

Affected libraries: OpenSSL, GnuTLS, NSS, OpenSSH, libkrb5.

---

## 5. Patching Strategy

### dnf Update Workflows

```bash
dnf update -y                          # full system update
dnf update --security -y               # security only
dnf update --advisory=RHSA-2024:1234   # specific advisory
dnf check-update --security            # preview
dnf updateinfo list security           # list advisories
```

### Errata Types

- **RHSA** -- Security Advisory (CVEs)
- **RHBA** -- Bug Advisory (fixes)
- **RHEA** -- Enhancement Advisory

### dnf-automatic

Config: `/etc/dnf/automatic.conf`. Set `upgrade_type = security` and `apply_updates = yes`. Enable: `systemctl enable --now dnf-automatic.timer`.

### Patch Rollback

```bash
dnf history list
dnf history undo last
dnf history undo 42
```

### Kernel Rollback

```bash
grubby --info=ALL                      # list entries
grubby --set-default /boot/vmlinuz-<version>
```

---

## 6. User and Access Management

### Local Users

```bash
useradd -m -s /bin/bash -c "App Service Account" appuser
chage -M 90 -m 7 -W 14 -I 30 username   # password aging
chage -l username                         # view aging
```

### sudo Configuration

Use drop-in files in `/etc/sudoers.d/`. Validate: `visudo -c`.

```bash
# /etc/sudoers.d/webadmins
%webadmins ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart httpd
```

### SSSD for Centralized Authentication

Config: `/etc/sssd/sssd.conf`. Domain join: `realm join example.com`. Profile management: `authselect select sssd with-faillock with-mkhomedir --force`.

---

## 7. Logging and Audit

### Persistent Journal

`/etc/systemd/journald.conf`:
```ini
[Journal]
Storage=persistent
Compress=yes
SystemMaxUse=2G
MaxRetentionSec=1year
ForwardToSyslog=yes
```

Create dir: `mkdir -p /var/log/journal && systemd-tmpfiles --create --prefix /var/log/journal`

### Log Rotation

Config: `/etc/logrotate.d/`. Example: daily rotation, 30 copies, compress.

### Audit Rules

Key rules in `/etc/audit/rules.d/cis.rules`:

```
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-a always,exit -F path=/usr/bin/sudo -F perm=x -F auid>=1000 -k privileged
-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale
-e 2                                   # immutable (last rule)
```

Apply: `augenrules --load`. Query: `ausearch -k identity --start today --interpret`.

---

## 8. Backup and Recovery

### ReaR (Relax and Recover)

Config: `/etc/rear/local.conf`

```bash
OUTPUT=ISO
BACKUP=NETFS
BACKUP_URL=nfs://nfsserver/backups/rear
```

Create: `rear -v mkbackup`. Recover: boot from ISO, run `rear recover`.

### LVM Snapshots

```bash
lvcreate -L 10G -s -n snap_root /dev/vg0/root
mount -o ro,nouuid /dev/vg0/snap_root /mnt/snapshot
# backup, then remove snapshot
lvremove -f /dev/vg0/snap_root
```

### Stratis Snapshots

```bash
stratis fs snapshot mypool myfs myfs-snap-$(date +%Y%m%d)
mount /dev/stratis/mypool/myfs-snap-20240101 /mnt/snapshot
```

---

## 9. Performance Tuning

### Key sysctl Parameters

`/etc/sysctl.d/99-performance.conf`:

```
vm.swappiness = 10
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
fs.file-max = 2097152
net.core.somaxconn = 65535
net.core.rmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
```

Apply: `sysctl --system`

### Huge Pages

Static: `vm.nr_hugepages = 512` in sysctl. Disable THP for databases: `echo never > /sys/kernel/mm/transparent_hugepage/enabled`.

### NUMA

```bash
numactl --hardware                     # view topology
numactl --cpunodebind=0 --membind=0 myprocess
systemctl enable --now numad           # automatic management
```

### I/O Scheduler

```bash
# Check: cat /sys/block/sda/queue/scheduler
# HDD: mq-deadline; SSD/NVMe: none
# Persistent via udev: /etc/udev/rules.d/60-io-scheduler.rules
```

---

## 10. Subscription and Entitlement Management

### subscription-manager

```bash
subscription-manager register --org=MyOrg --activationkey=rhel9-prod
subscription-manager status
subscription-manager repos --list-enabled
subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
```

### Red Hat Insights

```bash
dnf install insights-client -y
insights-client --register
insights-client --status
insights-client --compliance           # run compliance scan
```

### Convert2RHEL

In-place conversion from CentOS, Oracle Linux, Rocky, AlmaLinux:

```bash
dnf install convert2rhel
convert2rhel analyze --username <user>   # pre-check
convert2rhel --org MyOrg --activationkey key   # execute
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
| tuned profile | `/etc/tuned/<name>/tuned.conf` |
| SSSD | `/etc/sssd/sssd.conf` |
| sudoers drop-ins | `/etc/sudoers.d/` |
| ReaR backup | `/etc/rear/local.conf` |
| dnf-automatic | `/etc/dnf/automatic.conf` |
| GRUB config | `/etc/default/grub` |
| PAM auth | `/etc/pam.d/system-auth`, `/etc/pam.d/password-auth` |
| Logrotate | `/etc/logrotate.d/` |
| Limits | `/etc/security/limits.conf` |
