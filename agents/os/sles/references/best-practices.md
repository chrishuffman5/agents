# SLES Best Practices Reference

Best practices for SUSE Linux Enterprise Server 15 SP5+. Covers hardening, patching workflow, SAP tuning, Live Patching, SP upgrade procedure, firewalld configuration, and crypto policies.

---

## AppArmor Hardening

### Overview

SLES uses AppArmor as its default Mandatory Access Control system. AppArmor profiles are path-based and simpler to write than SELinux Type Enforcement rules.

### Profile Management

```bash
# AppArmor status
aa-status                                  # Full profile list and enforcement mode
systemctl status apparmor.service

# Profile enforcement
aa-enforce /etc/apparmor.d/usr.sbin.nginx  # Set profile to enforce mode
aa-complain /etc/apparmor.d/usr.sbin.nginx # Set to complain (log only) mode
aa-disable /etc/apparmor.d/usr.sbin.nginx  # Disable profile

# Profile development
aa-genprof /usr/sbin/myapp                 # Generate profile interactively
aa-logprof                                 # Update profiles from audit log

# Log inspection
journalctl -k | grep -i apparmor
grep -i apparmor /var/log/audit/audit.log
```

### Best Practices

1. Never disable AppArmor globally -- use `aa-complain` for per-profile troubleshooting
2. Run `aa-genprof` in a test environment first, then deploy profiles to production
3. Review `aa-logprof` suggestions before applying -- avoid granting excessive access
4. Store custom profiles in `/etc/apparmor.d/` and include them in configuration management
5. Use tunables (`/etc/apparmor.d/tunables/`) for path variables that differ across environments

---

## YaST Security Module

```bash
# Launch YaST security configuration
yast2 security

# Key settings managed:
# - Password policy (minimum length, complexity, aging)
# - Login restrictions (failed attempts, delay)
# - Kernel hardening sysctl values
# - Bootloader protection
# - File permission checks (SUID/SGID audit)
```

---

## FIPS Mode

SLES supports FIPS 140-2/140-3 validated cryptographic modules:

```bash
# Enable FIPS mode (requires reboot)
fips-mode-setup --enable

# Check FIPS status
fips-mode-setup --check
cat /proc/sys/crypto/fips_enabled          # 1 = enabled

# FIPS affects:
# - OpenSSL limited to FIPS-approved ciphers
# - SSH limited to approved algorithms
# - Disables MD5, RC4, DES, DSA < 2048 bit
```

---

## Crypto Policies

SLES 15 SP3+ supports system-wide crypto policies:

```bash
# View current policy
update-crypto-policies --show

# Available policies: DEFAULT, FUTURE, LEGACY, FIPS
update-crypto-policies --set FUTURE
update-crypto-policies --set FIPS
```

| Policy | TLS 1.0/1.1 | SHA-1 Signatures | RSA < 2048 | Use Case |
|---|---|---|---|---|
| LEGACY | Allowed | Allowed | Allowed | Legacy application compatibility |
| DEFAULT | Deprecated (SP5), Disabled (SP6) | Allowed | Allowed | General purpose |
| FUTURE | Disabled | Disabled | Disabled | Forward-looking security |
| FIPS | Disabled | Disabled | Disabled | Government/compliance |

---

## Firewalld Configuration

SLES 15 uses firewalld (replaced SuSEfirewall2):

```bash
# Status and zones
firewall-cmd --state
firewall-cmd --get-active-zones
firewall-cmd --list-all

# Manage rules
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --permanent --remove-service=telnet
firewall-cmd --reload

# Zone management
firewall-cmd --permanent --new-zone=dmz-custom
firewall-cmd --permanent --zone=dmz --add-interface=eth1

# Rich rules
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept'
```

Best practices:
- Use `--permanent` for all rules, then `--reload` to apply
- Assign interfaces to appropriate zones (public, internal, dmz)
- Use service names (`--add-service`) instead of raw port numbers where possible
- Audit open ports regularly with `firewall-cmd --list-all --zone=public`

---

## Patching Workflow

### Standard Procedure

```bash
# Step 1: Refresh repository metadata
zypper refresh

# Step 2: Check pending patches (review before applying)
zypper patches --category security
zypper patches --category recommended

# Step 3: Apply security patches
zypper patch --category security

# Step 4: Apply recommended patches
zypper patch --category recommended

# Step 5: Check if reboot required
zypper needs-rebooting
[ -f /run/reboot-needed ] && echo "REBOOT REQUIRED"

# Step 6: Check for services needing restart
zypper ps -s
```

### Automated Patching

```bash
# Non-interactive security patching (for automation)
zypper --non-interactive patch --category security

# With email notification (custom wrapper)
zypper --non-interactive patch --category security 2>&1 | mail -s "Patch Report" admin@example.com
```

### Pre-Patch Checklist

1. Take a Snapper snapshot: `snapper create --description "Pre-patch $(date +%F)"`
2. Verify registration: `SUSEConnect --status`
3. Refresh repos: `zypper refresh`
4. Review pending patches: `zypper patches --category security`
5. Apply in maintenance window
6. Verify: `zypper needs-rebooting`, `zypper ps -s`
7. Reboot if required
8. Validate services post-reboot

---

## Live Patching (kGraft)

SLES Live Patching allows kernel security patches without reboot:

```bash
# Install Live Patching (requires Live Patching extension)
SUSEConnect --product sle-module-live-patching/15.5/x86_64 --regcode <KEY>
zypper install kernel-livepatch-tools

# Live patch status
klp status                                 # Show loaded live patches
klp patches                               # List available patches

# Live patches are applied automatically when packages are installed
# Verify active patches:
cat /proc/livepatch_info 2>/dev/null || klp status
```

Live Patching does not replace regular reboots indefinitely. Plan periodic reboot windows (quarterly) to load a fresh kernel. Live patches accumulate and have a finite support window.

---

## Service Pack Upgrade Procedure

### Pre-Upgrade Steps

```bash
# 1. Take a Snapper snapshot
snapper create --description "Pre-SP-upgrade" --type single

# 2. Verify current registration
SUSEConnect --status

# 3. Check for pending patches (apply first)
zypper patch
```

### Upgrade Procedure

```bash
# 4. Register the new SP products
SUSEConnect --product SLES/15.6/x86_64

# 5. Migrate all modules to new SP
SUSEConnect --product sle-module-basesystem/15.6/x86_64
SUSEConnect --product sle-module-server-applications/15.6/x86_64
# Repeat for all registered modules

# 6. Refresh and perform distribution upgrade
zypper refresh
zypper dup --allow-vendor-change

# 7. Reboot
reboot
```

### Post-Upgrade Validation

```bash
# 8. Verify new version
cat /etc/os-release
uname -r

# 9. Check registration
SUSEConnect --status

# 10. Run health check
systemctl --failed
zypper verify
```

### Rollback If Upgrade Fails

Boot from the GRUB snapshot entry created before the upgrade, then run `snapper rollback` to make it the permanent default.

---

## SAP Tuning with saptune

### Overview

saptune is SUSE's tool for applying SAP-certified performance profiles. It configures kernel parameters, I/O schedulers, hugepages, and other settings.

### Applying SAP Solutions

```bash
# Install saptune
zypper install saptune

# List available solutions and notes
saptune solution list
saptune note list

# Apply a solution
saptune solution apply HANA
saptune solution apply NETWEAVER

# Verify current tuning
saptune solution verify HANA
saptune note verify 2382421

# Check saptune status
saptune status
saptune daemon status

# Enable at boot
systemctl enable saptune.service
saptune daemon start

# Simulate changes before applying
saptune solution simulate HANA
```

### Key SAP HANA Parameters Set by saptune

```bash
vm.swappiness = 10
vm.dirty_ratio = 10
kernel.numa_balancing = 0
net.ipv4.tcp_timestamps = 1
# Transparent Huge Pages per SAP Note recommendation
# I/O scheduler: noop/none for SSD, deadline for HDD
```

### Hugepages Configuration

```bash
# Check current hugepage allocation
grep HugePages /proc/meminfo

# Configure persistent hugepages
# /etc/sysctl.d/90-sap-hana.conf:
vm.nr_hugepages = 2048

# Apply without reboot
sysctl -w vm.nr_hugepages=2048
```

### saptune vs tuned

SLES uses saptune instead of tuned for SAP workloads. Do not run both simultaneously -- they will conflict. saptune reads SAP Notes directly and applies vendor-certified configurations.

---

## Logging and Audit Best Practices

### Journal Persistence

Ensure journal logs persist across reboots:

```bash
# Check current storage mode
journalctl --disk-usage

# Enable persistent storage
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal
systemctl restart systemd-journald

# Set size limits in /etc/systemd/journald.conf
# SystemMaxUse=2G
# SystemKeepFree=4G
```

### Audit Framework

```bash
# Check auditd status
systemctl status auditd.service
auditctl -s                                # Audit daemon status

# Add watch rules
auditctl -w /etc/shadow -p wa -k shadow_changes
auditctl -w /etc/sudoers -p wa -k sudoers_changes

# Persist rules
# Add to /etc/audit/rules.d/99-custom.rules
```

---

## Backup and Recovery

### Snapper Snapshot Strategy

Recommended retention policy for `/etc/snapper/configs/root`:

```ini
TIMELINE_CREATE="yes"
TIMELINE_LIMIT_HOURLY="4"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="4"
TIMELINE_LIMIT_MONTHLY="6"
TIMELINE_LIMIT_YEARLY="0"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
```

Plan for 20-40% extra disk space beyond OS data for snapshots.

### Off-Device Backup

Snapshots are NOT backups. Always maintain off-device copies:

```bash
# Btrfs send/receive for incremental backup
btrfs send /.snapshots/42/snapshot | btrfs receive /mnt/backup/
btrfs send -p /.snapshots/41/snapshot /.snapshots/42/snapshot | btrfs receive /mnt/backup/

# rsync from a read-only snapshot for consistency
rsync -avz --delete /.snapshots/42/snapshot/etc /backup/etc/
```

---

## Performance Tuning Checklist

1. **Enable sysstat**: `zypper install sysstat && systemctl enable --now sysstat`
2. **Capture baseline**: Run `02-performance-baseline.sh` script before workload deployment
3. **Apply tuning profile**: `saptune solution apply HANA` for SAP, or manual sysctl for other workloads
4. **Monitor Btrfs**: Schedule monthly scrubs, watch metadata saturation
5. **Manage snapshots**: Configure Snapper retention, run cleanup regularly
6. **Check qgroup overhead**: Disable qgroups on high-IOPS systems if snapshot size reporting is not needed
7. **Disable CoW for databases**: Use `chattr +C` or `nodatacow` mount option for VM images and database files
