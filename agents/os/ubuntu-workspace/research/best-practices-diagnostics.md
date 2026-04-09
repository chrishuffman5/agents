# Ubuntu Best Practices and Diagnostics (Cross-Version 20.04–26.04)

> Research compiled for Ubuntu agent library. Covers Ubuntu 20.04 LTS (Focal), 22.04 LTS (Jammy),
> 24.04 LTS (Noble), and 26.04 LTS (Plucky) unless otherwise noted.
> Focus is on Ubuntu-specific tooling distinct from generic Linux or RHEL patterns.

---

## 1. Ubuntu Hardening — CIS Benchmarks and Ubuntu Security Guide (USG)

### Ubuntu Security Guide (USG)

USG is the Canonical-maintained CIS benchmark implementation, available via Ubuntu Pro.

```bash
# Install USG (requires Ubuntu Pro)
sudo apt install ubuntu-security-guide

# Run a CIS Level 1 audit (non-destructive)
sudo usg audit cis_level1_server

# Apply CIS Level 1 hardening (modifies system)
sudo usg fix cis_level1_server

# Generate HTML compliance report
sudo usg audit cis_level1_server --html-file /tmp/cis-report.html

# Available profiles
usg list-profiles
# cis_level1_server, cis_level2_server, cis_level1_workstation, cis_level2_workstation
# stig (DISA STIG, Ubuntu Pro only)
```

USG is preferred over manual CIS hardening because it integrates with Ubuntu Pro's compliance
reporting pipeline and tracks drift over time.

### Ubuntu Pro — ESM and Compliance

```bash
# Attach a system to Ubuntu Pro (free for up to 5 machines)
sudo pro attach <token>

# Check Pro status
pro status
pro status --format json

# Enable specific services
pro enable esm-infra          # Extended Security Maintenance for base packages
pro enable esm-apps           # ESM for Universe packages
pro enable livepatch          # Kernel live patching
pro enable usg                # Ubuntu Security Guide (CIS/STIG)
pro enable fips               # FIPS 140-2 compliance (non-LTS disabling)
pro enable fips-updates       # FIPS with security updates
pro enable cis                # Alias for usg on older clients

# List available services
pro help
```

### Password Quality — pam_pwquality

Ubuntu uses `pam_pwquality` (same as RHEL) but configuration differs:

Config file: `/etc/security/pwquality.conf`
```
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 4
maxrepeat = 3
retry = 3
dictcheck = 1
```

PAM config in `/etc/pam.d/common-password`:
```
password requisite pam_pwquality.so retry=3
```

### Account Lockout — pam_faillock (Ubuntu 22.04+) / pam_tally2 (20.04)

Ubuntu 22.04+ uses `pam_faillock` (replacing deprecated `pam_tally2`):

```bash
# /etc/security/faillock.conf (Ubuntu 22.04+)
deny = 5
fail_interval = 900
unlock_time = 900

# Unlock a user
faillock --user <username> --reset

# On Ubuntu 20.04 (pam_tally2 still present)
pam_tally2 --user <username> --reset
```

### SSH Hardening

Critical settings for `/etc/ssh/sshd_config`:
```
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups sshusers
Banner /etc/issue.net
```

Ubuntu-specific: sshd drops privileges to `sshd` user (not `nobody`) and uses
`/run/sshd` as privilege separation directory (auto-created by systemd service).

```bash
# Validate sshd config before reloading
sudo sshd -t
sudo systemctl reload ssh    # Note: unit is 'ssh', not 'sshd' on Ubuntu
```

---

## 2. Update Management

### apt Command Differences

| Command | Behavior |
|---|---|
| `apt update` | Refresh package index only |
| `apt upgrade` | Upgrade installed packages; never removes packages |
| `apt dist-upgrade` / `apt full-upgrade` | Upgrade + allow package removals for dependency resolution |
| `apt autoremove` | Remove orphaned dependency packages |
| `apt autoclean` | Remove cached .deb files no longer needed |

`full-upgrade` is the correct command for routine patching — `dist-upgrade` is an alias.
Use `dist-upgrade` / `full-upgrade` for security patching to ensure kernel meta-packages update.

```bash
# Full non-interactive upgrade sequence
sudo apt update -q
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean

# Check what will be upgraded without doing it
apt list --upgradable 2>/dev/null

# Show why a package is being held back
apt-cache policy <package>
```

### unattended-upgrades — Automatic Security Updates

Installed by default on Ubuntu Server. Config: `/etc/apt/apt.conf.d/50unattended-upgrades`

Key settings:
```
// Allow ESM security updates (Ubuntu Pro)
"${distro_id}ESMApps:${distro_codename}-apps-security";
"${distro_id}ESM:${distro_codename}-infra-security";

// Automatically reboot (dangerous on servers — default off)
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Email notifications
Unattended-Upgrade::Mail "admin@example.com";
Unattended-Upgrade::MailReport "on-change";
```

Schedule config: `/etc/apt/apt.conf.d/20auto-upgrades`
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
```

```bash
# Manually run unattended-upgrades (dry-run)
sudo unattended-upgrades --dry-run --debug

# Check unattended-upgrades log
cat /var/log/unattended-upgrades/unattended-upgrades.log

# Check if reboot is required
cat /var/run/reboot-required 2>/dev/null && echo "REBOOT REQUIRED"
cat /var/run/reboot-required.pkgs 2>/dev/null
```

### Holding Packages

```bash
# Hold a package at current version
sudo apt-mark hold <package>

# Unhold
sudo apt-mark unhold <package>

# List all held packages
apt-mark showhold

# Pin a package via preferences (more granular)
# /etc/apt/preferences.d/pin-nginx
Package: nginx
Pin: version 1.18.*
Pin-Priority: 1001
```

### HWE Kernel Stack (Hardware Enablement)

Ubuntu LTS releases ship with an initial GA kernel and optionally a rolling HWE kernel.

```bash
# Check if HWE kernel is installed
dpkg -l linux-generic-hwe-* 2>/dev/null

# Install HWE stack (gets newer kernel for older LTS)
sudo apt install --install-recommends linux-generic-hwe-22.04

# List all installed kernels
dpkg -l linux-image-* | grep ^ii

# Remove old kernels (apt handles this automatically with full-upgrade)
sudo apt autoremove --purge
```

### do-release-upgrade — LTS Upgrades

```bash
# Check upgrade availability
do-release-upgrade -c

# Run upgrade to next LTS (interactive)
sudo do-release-upgrade

# Force upgrade to next LTS even if not yet recommended
sudo do-release-upgrade -d    # development / non-recommended

# Run upgrade over SSH (uses screen for safety)
sudo do-release-upgrade       # automatically detects SSH and uses screen

# After upgrade: verify
lsb_release -a
uname -r
```

Key difference from RHEL: `do-release-upgrade` handles entire version jump including
kernel, package migration, and config file prompts. Requires 2+ hours and active monitoring.

---

## 3. UFW Firewall

### Core UFW Commands

```bash
# Status and inspection
sudo ufw status                    # on/off + rules
sudo ufw status verbose            # includes defaults, logging, interface
sudo ufw status numbered           # numbered rules for deletion

# Enable / disable
sudo ufw enable
sudo ufw disable
sudo ufw reset                     # Reset all rules (confirmation required)

# Default policies (set before enable)
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny forward

# Allow by port
sudo ufw allow 22/tcp
sudo ufw allow 80
sudo ufw allow 443/tcp comment 'HTTPS'

# Allow by application profile
sudo ufw allow 'OpenSSH'
sudo ufw allow 'Nginx Full'

# Allow from specific IP / subnet
sudo ufw allow from 10.0.0.0/8 to any port 22
sudo ufw allow from 192.168.1.100

# Deny and limit
sudo ufw deny 23/tcp
sudo ufw limit ssh                 # Rate-limit SSH (6 attempts per 30s)

# Delete rules
sudo ufw delete allow 80
sudo ufw delete 3                  # Delete rule #3 (from numbered list)

# Reload
sudo ufw reload
```

### UFW Application Profiles

Profiles live in `/etc/ufw/applications.d/`. Example custom profile:
```ini
[MyApp]
title=My Application
description=Custom application firewall profile
ports=8080/tcp|8443/tcp
```

```bash
# List available profiles
sudo ufw app list

# Show profile detail
sudo ufw app info 'OpenSSH'

# Update profile rules
sudo ufw app update MyApp
```

### UFW Logging

```bash
# Enable logging
sudo ufw logging on              # medium by default
sudo ufw logging low             # BLOCK only
sudo ufw logging medium          # BLOCK + ALLOW rules that match
sudo ufw logging high            # all packets (verbose)
sudo ufw logging full            # all packets + packet data

# Log location
tail -f /var/log/ufw.log

# Parse UFW blocks
grep '\[UFW BLOCK\]' /var/log/ufw.log | awk '{print $12}' | sort | uniq -c | sort -rn | head -20
```

### UFW vs firewalld vs nftables

Ubuntu does **not** install firewalld by default (that is a RHEL/Fedora choice).
- **UFW**: Ubuntu default, iptables/nftables backend, simple CLI
- **nftables**: Underlying framework on Ubuntu 22.04+ (UFW can use nftables backend)
- **firewalld**: Available via `apt install firewalld` but not recommended on Ubuntu — conflicts with UFW

To check what backend UFW uses:
```bash
cat /etc/default/ufw | grep IPTABLES_BACKEND
# IPTABLES_BACKEND=nftables  (Ubuntu 22.04+)
```

---

## 4. AppArmor

AppArmor is Ubuntu's default Mandatory Access Control (MAC) system. Unlike SELinux (RHEL default),
AppArmor uses path-based profiles rather than labels.

```bash
# Status
sudo aa-status                     # All profiles and their modes
apparmor_status                    # Alias

# Modes per profile
# enforce  — policy violations are blocked and logged
# complain — violations are logged only (learning mode)
# unconfined — no profile applied

# Profile management
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx
sudo aa-complain /etc/apparmor.d/usr.sbin.nginx
sudo aa-disable /etc/apparmor.d/usr.sbin.nginx

# Reload profiles
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.nginx
sudo systemctl reload apparmor

# View AppArmor denials
sudo journalctl -k | grep -i apparmor | grep -i denied
sudo dmesg | grep -i apparmor

# Generate profile for an application (audit mode)
sudo aa-genprof /usr/sbin/myapp
sudo aa-logprof                    # Update existing profiles from audit log
```

Key difference from SELinux: AppArmor profiles are easier to write but less granular.
Most Ubuntu packages ship their own AppArmor profiles in `/etc/apparmor.d/`.

---

## 5. Landscape Fleet Management

Landscape is Canonical's commercial fleet management tool for Ubuntu systems.

### SaaS vs Self-Hosted

| Aspect | Landscape SaaS | Landscape Self-Hosted |
|---|---|---|
| URL | landscape.canonical.com | Your infrastructure |
| Included with | Ubuntu Pro | Separate license |
| Setup | Register client only | Full server deployment |
| Air-gapped | No | Yes |

### Client Registration

```bash
# Install client
sudo apt install landscape-client

# Register with SaaS (Ubuntu Pro handles this automatically)
sudo pro attach <token>
pro enable landscape

# Manual registration
sudo landscape-config \
  --computer-title "$(hostname)" \
  --account-name myaccount \
  --url https://landscape.canonical.com/message-system

# Check client status
sudo landscape-client --config=/etc/landscape/client.conf --help
systemctl status landscape-client
```

### Package Management via Landscape

Landscape UI supports:
- Package search, install, remove, upgrade across fleet
- Scheduled package upgrades (maintenance windows)
- Upgrade profiles (test → staging → production)
- Script execution with role-based access

### API Access

```bash
# Landscape REST API (SaaS)
curl -s "https://landscape.canonical.com/api/v11/computers" \
  -H "Authorization: Bearer <token>"

# List computers with specific package
curl -s "https://landscape.canonical.com/api/v11/packages?name=nginx" \
  -H "Authorization: Bearer <token>"
```

---

## 6. Snap Management Best Practices

### Refresh Scheduling

```bash
# View current refresh schedule
snap get system refresh.timer
snap get system refresh.schedule    # older format

# Set refresh window (e.g., weekdays 2-4 AM)
sudo snap set system refresh.timer="mon-fri,02:00-04:00"

# Set refresh on a specific day of month
sudo snap set system refresh.timer="4th-fri,6:00"

# Disable automatic refreshes (not recommended)
sudo snap set system refresh.metered=hold

# Hold a specific snap refresh
sudo snap refresh --hold=48h firefox
sudo snap refresh --hold=forever firefox   # indefinite hold

# Release hold
sudo snap refresh --unhold firefox
```

### Snap Disk Space Management

Old snap revisions accumulate on disk. Default: keep 2 revisions.

```bash
# List all revisions including old/disabled
snap list --all

# Remove specific old revision
sudo snap remove --revision=<rev> <snap>

# Script to remove all disabled snap revisions
snap list --all | awk '/disabled/{print $1, $3}' | \
  while read name rev; do sudo snap remove --revision="$rev" "$name"; done

# Configure retention globally (snapd 2.54+)
sudo snap set system snapshots.automatic.retention=30d

# Check snap disk usage
du -sh /var/lib/snapd/snaps/
```

### Snap Configuration

```bash
# Get/set snap config
snap get <snap> [key]
sudo snap set <snap> key=value

# Example: configure nextcloud snap
sudo snap set nextcloud ports.http=8080

# Show snap connections (interfaces/plugs)
snap connections <snap>
snap interfaces <snap>

# Connect a plug/slot manually
sudo snap connect <snap>:<plug> <snap>:<slot>
```

### Enterprise Snap Store Proxy

For air-gapped or controlled environments:
```bash
# Install snap store proxy
sudo snap install snap-store-proxy

# Configure proxy
sudo snap-proxy config proxy.domain=snapproxy.internal
sudo snap-proxy import-keys

# Direct clients to proxy
sudo snap set system proxy.store=<proxy-id>
```

---

## 7. Backup and Recovery

### Timeshift

Timeshift takes system snapshots (excludes home by default).

```bash
# Install
sudo apt install timeshift

# Create RSYNC snapshot
sudo timeshift --create --comments "pre-upgrade" --tags D

# Create BTRFS snapshot (requires BTRFS root)
sudo timeshift --btrfs --create

# List snapshots
sudo timeshift --list

# Restore snapshot
sudo timeshift --restore --snapshot <snapshot-name>

# Delete old snapshots
sudo timeshift --delete --snapshot <snapshot-name>

# Automated retention (edit /etc/timeshift/timeshift.json)
# keep_daily: 5, keep_weekly: 3, keep_monthly: 1
```

### rsync Strategies

```bash
# Full backup with preservation of all metadata
sudo rsync -aAXvH --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*",\
"/mnt/*","/media/*","lost+found"} / /backup/root/

# Incremental with hardlinks (space-efficient)
sudo rsync -aAXvH --link-dest=/backup/last/ / /backup/$(date +%Y%m%d)/

# Update symlink to latest
ln -sfn /backup/$(date +%Y%m%d) /backup/last
```

### duplicity — Encrypted Backups

```bash
# Install
sudo apt install duplicity

# Backup to local path (GPG encrypted)
duplicity /home/user file:///backup/home-backup \
  --encrypt-key <GPG-KEY-ID>

# Backup to S3
duplicity /etc s3://mybucket/etc-backup \
  --encrypt-key <GPG-KEY-ID>

# Restore
duplicity file:///backup/home-backup /restore/home \
  --encrypt-key <GPG-KEY-ID>

# Verify backup integrity
duplicity verify file:///backup/home-backup /home/user
```

### LVM Snapshots

```bash
# Create snapshot (requires free space in VG)
sudo lvcreate -L10G -s -n snap_root /dev/ubuntu-vg/ubuntu-lv

# Mount snapshot for file recovery
sudo mkdir /mnt/snap
sudo mount -o ro /dev/ubuntu-vg/snap_root /mnt/snap

# Remove snapshot
sudo umount /mnt/snap
sudo lvremove /dev/ubuntu-vg/snap_root

# Check snapshot usage
sudo lvs /dev/ubuntu-vg/snap_root
```

### ZFS Snapshots (if ZFS root — Ubuntu 20.04+ installer option)

```bash
# List ZFS pools and datasets
zpool list
zfs list

# Create snapshot
sudo zfs snapshot rpool/ROOT/ubuntu@pre-upgrade

# List snapshots
zfs list -t snapshot

# Rollback
sudo zfs rollback rpool/ROOT/ubuntu@pre-upgrade

# Send snapshot to remote
sudo zfs send rpool/ROOT/ubuntu@pre-upgrade | ssh backup "zfs recv backup/ubuntu@pre-upgrade"
```

### REAR (Relax-and-Recover) — Bare Metal Recovery

```bash
# Install
sudo apt install rear

# Configure /etc/rear/local.conf
OUTPUT=ISO
BACKUP=NETFS
BACKUP_URL=file:///backup/rear/

# Create recovery ISO
sudo rear mkrescue

# Run full backup
sudo rear mkbackup
```

---

## 8. Ubuntu-Specific Diagnostics

### apport and ubuntu-bug

```bash
# Report a bug (launches apport, collects crash data)
ubuntu-bug <package-name>
ubuntu-bug /usr/bin/nginx

# List crash reports
ls -lh /var/crash/

# Parse a crash file
apport-unpack /var/crash/_usr_sbin_nginx.1000.crash /tmp/crash-unpacked
ls /tmp/crash-unpacked/

# Analyze core dump
apport-retrace /var/crash/_usr_sbin_nginx.1000.crash

# Enable/disable apport crash collection
sudo systemctl enable --now apport
sudo systemctl disable apport

# Apport config: /etc/default/apport
# enabled=1  to enable, enabled=0 to disable
```

### apt Broken Dependencies

```bash
# Fix broken packages
sudo apt --fix-broken install
sudo dpkg --configure -a          # Configure any unconfigured packages

# Force reinstall
sudo apt install --reinstall <package>

# Clean partial downloads
sudo apt clean

# Check for broken packages
dpkg -l | grep -E '^(rc|iF|iU)'
# rc = removed but config files remain
# iF = failed (half-installed)
# iU = unpacked but not configured

# Remove residual config files (rc state)
dpkg -l | awk '/^rc/{print $2}' | xargs sudo apt purge -y 2>/dev/null

# Force dpkg
sudo dpkg --force-depends --remove <package>
```

### snap Troubleshooting

```bash
# View snap change history
snap changes
snap changes <snap>

# View tasks for a specific change
snap tasks <change-id>

# Snap service logs
journalctl --user-unit=snap.<snap>.<service>
journalctl -u snap.nextcloud.mysql

# Snap interface connections
snap connections
snap connections <snap>

# Refresh specific snap
sudo snap refresh <snap>

# Revert snap to previous revision
sudo snap revert <snap>

# Check snap health
snap run --shell <snap> -- /snap/<snap>/current/meta/hooks/check-health 2>/dev/null || true

# Enable/disable a snap
sudo snap disable <snap>
sudo snap enable <snap>

# Remove a snap completely
sudo snap remove --purge <snap>
```

### sosreport on Ubuntu

```bash
# Install
sudo apt install sosreport

# Collect support data (creates tarball)
sudo sosreport

# Specify output directory
sudo sosreport --tmp-dir /tmp/sos

# Include specific plugins
sudo sosreport --enable-plugins networking,apt,systemd

# Skip slow plugins
sudo sosreport --skip-plugins kernel,hardware

# Output goes to /tmp/sosreport-hostname-date.tar.xz
```

### needrestart — Services Requiring Restart

```bash
# Install (may already be installed)
sudo apt install needrestart

# Check which services need restart after updates
sudo needrestart

# Non-interactive check (shows only what needs restart)
sudo needrestart -b    # batch mode

# Auto-restart services (kernel changes still require manual reboot)
sudo needrestart -ra

# Config: /etc/needrestart/needrestart.conf
# $nrconf{restart} = 'a';   # auto-restart services
# $nrconf{ucodehints} = 1;  # detect microcode updates
```

---

## 9. Performance Tools

### Standard Tools (same as RHEL)

```bash
sar -u 1 10             # CPU utilization (10 samples, 1s interval)
sar -r 1 5              # Memory
sar -d 1 5              # Disk I/O
vmstat 1 10             # Virtual memory, I/O, CPU
iostat -xz 1            # Disk I/O extended
```

### ubuntu-drivers — GPU and Driver Management

```bash
# List recommended drivers
ubuntu-drivers devices
ubuntu-drivers list

# Install recommended drivers automatically
sudo ubuntu-drivers autoinstall

# Install specific driver
sudo apt install nvidia-driver-535

# Check loaded modules
lsmod | grep nvidia
```

### lm-sensors — Hardware Temperature

```bash
# Install
sudo apt install lm-sensors

# Detect sensors
sudo sensors-detect --auto

# Read temperatures
sensors

# Watch continuously
watch -n 2 sensors
```

### powertop — Power Consumption

```bash
# Install and run
sudo apt install powertop
sudo powertop

# Generate HTML report
sudo powertop --html=/tmp/powertop.html

# Apply recommendations (non-persistent)
sudo powertop --auto-tune
```

### thermald — Thermal Management

```bash
# Status (Intel platforms)
systemctl status thermald

# Logs
journalctl -u thermald

# Config: /etc/thermald/thermal-conf.xml (if customized)
```

---

## 10. Network Diagnostics

### Netplan Troubleshooting

```bash
# Show current netplan config
cat /etc/netplan/*.yaml

# Apply config with 2-minute auto-revert (safe testing)
sudo netplan try

# Apply without revert window
sudo netplan apply

# Debug mode (shows generated networkd/NM config)
sudo netplan --debug apply
sudo netplan --debug generate

# Generate backend config without applying
sudo netplan generate

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('/etc/netplan/01-netcfg.yaml'))"

# Generated configs land at:
ls /run/systemd/network/   # systemd-networkd
ls /run/NetworkManager/    # NetworkManager
```

### systemd-networkd Diagnostics

```bash
# Status
networkctl
networkctl status
networkctl status eth0

# Link status detail
networkctl lldp

# Logs
journalctl -u systemd-networkd
journalctl -u systemd-networkd --since "1 hour ago"

# Restart networkd
sudo systemctl restart systemd-networkd
```

### NetworkManager Diagnostics

```bash
# Connection status
nmcli general status
nmcli connection show
nmcli device status

# Detailed connection info
nmcli connection show <connection-name>

# Logs (NM logs to syslog / journal)
journalctl -u NetworkManager
journalctl -u NetworkManager --since today

# Increase log verbosity
sudo nmcli general logging level DEBUG domains ALL
journalctl -u NetworkManager -f
# Restore
sudo nmcli general logging level INFO domains ALL
```

### DNS Diagnostics (systemd-resolved)

```bash
# Overall status
resolvectl status
resolvectl status eth0             # Interface-specific

# Test DNS resolution
resolvectl query ubuntu.com
resolvectl query ubuntu.com --type=AAAA

# Show cached entries
resolvectl statistics

# Flush DNS cache
sudo resolvectl flush-caches

# Show DNS servers in use
resolvectl dns

# Diagnostics for stub resolver
systemd-resolve --status
cat /etc/resolv.conf               # Should be symlink to stub or uplink
ls -la /etc/resolv.conf
```

### UFW Log Analysis

```bash
# Real-time UFW log
sudo tail -f /var/log/ufw.log

# Blocked connections by source IP (top offenders)
grep '\[UFW BLOCK\]' /var/log/ufw.log \
  | grep -oP 'SRC=\S+' | sort | uniq -c | sort -rn | head -20

# Blocked by destination port
grep '\[UFW BLOCK\]' /var/log/ufw.log \
  | grep -oP 'DPT=\d+' | sort | uniq -c | sort -rn | head -20

# UFW blocks in journal
journalctl -k | grep '\[UFW'
```

---

## 11. Package Diagnostics

### apt Diagnostics

```bash
# Show installed version vs available version
apt-cache policy <package>

# Show all available versions
apt-cache showpkg <package>

# Why a package is installed (dependency chain)
apt-cache rdepends --installed <package>

# Find which package owns a file
dpkg -S /usr/bin/nginx
dpkg -S /etc/nginx/nginx.conf

# List all files in an installed package
dpkg -L nginx

# List installed packages matching pattern
dpkg -l 'nginx*'
dpkg -l | grep -E '^ii' | awk '{print $2, $3}'

# Find packages with no reverse dependencies (candidates for removal)
deborphan                          # requires: apt install deborphan

# Search for file in uninstalled packages
apt-file search libssl.so.1        # requires: apt install apt-file && apt-file update

# List auto-removable packages
apt list --auto-removable 2>/dev/null

# List upgradable packages
apt list --upgradable 2>/dev/null

# Show PPA sources
grep -r "^deb" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
ls /etc/apt/sources.list.d/
```

### snap Diagnostics

```bash
# Snap package info
snap info <snap>

# List all installed snaps with version and channel
snap list

# Show snap connections
snap connections <snap>

# Show all interfaces
snap interfaces

# Check snap services status
snap services
snap services <snap>

# Find snaps in store
snap find <term>

# Show snap changes log
snap changes

# Debug a failing snap
journalctl -u snapd
journalctl -u snap.<snap>.<service>
snap run --shell <snap>            # Enter snap environment shell
```

---

## Scripts

### 01-system-health.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - System Health Dashboard
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() {
    echo ""
    echo "$SEP"
    echo "  $1"
    echo "$SEP"
}

# ── Section 1: OS Identity and Version ──────────────────────────────────────
section "SECTION 1 - OS Identity and Version"

echo "  Hostname     : $(hostname -f 2>/dev/null || hostname)"
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo "  Distro       : ${PRETTY_NAME:-unknown}"
    echo "  VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "  Codename     : ${UBUNTU_CODENAME:-${VERSION_CODENAME:-unknown}}"
fi
echo "  Kernel       : $(uname -r)"
echo "  Architecture : $(uname -m)"
echo "  LSB Release  : $(lsb_release -ds 2>/dev/null || echo 'lsb_release not found')"

# ── Section 2: Uptime and Reboot Required ───────────────────────────────────
section "SECTION 2 - Uptime and Reboot Status"

echo "  Uptime       : $(uptime -p 2>/dev/null || uptime)"
echo "  Last Boot    : $(who -b 2>/dev/null | awk '{print $3, $4}' || echo 'unknown')"

if [[ -f /var/run/reboot-required ]]; then
    echo "  [WARN] REBOOT REQUIRED"
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        echo "  Packages requiring reboot:"
        sed 's/^/    /' /var/run/reboot-required.pkgs
    fi
else
    echo "  [OK]   No reboot required"
fi

# ── Section 3: Ubuntu Pro / ESM Status ──────────────────────────────────────
section "SECTION 3 - Ubuntu Pro and ESM Status"

if command -v pro &>/dev/null; then
    pro_status=$(pro status 2>/dev/null || echo "  Unable to query Pro status")
    echo "$pro_status" | head -20 | sed 's/^/  /'
elif command -v ua &>/dev/null; then
    ua status 2>/dev/null | head -20 | sed 's/^/  /' || echo "  Unable to query UA status"
else
    echo "  [INFO] ubuntu-advantage-tools not installed"
    echo "  Install: apt install ubuntu-advantage-tools"
fi

# ── Section 4: Livepatch Status ─────────────────────────────────────────────
section "SECTION 4 - Livepatch Status"

if command -v canonical-livepatch &>/dev/null; then
    lp_status=$(canonical-livepatch status 2>/dev/null || echo "  Unable to query Livepatch")
    echo "$lp_status" | sed 's/^/  /'
else
    echo "  [INFO] Livepatch not installed"
    echo "  Enable with: pro enable livepatch"
fi

# ── Section 5: Hardware Summary ─────────────────────────────────────────────
section "SECTION 5 - Hardware Summary"

echo "  CPU Model    : $(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo 'unknown')"
echo "  CPU Cores    : $(nproc)"
echo "  Total RAM    : $(free -h | awk '/^Mem:/{print $2}')"
echo "  Swap         : $(free -h | awk '/^Swap:/{print $2}')"

virt=$(systemd-detect-virt 2>/dev/null || echo "unknown")
echo "  Virtualization: $virt"

echo ""
echo "$SEP"
echo "  System Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 02-performance-baseline.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Performance Baseline
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: CPU ───────────────────────────────────────────────────────────
section "SECTION 1 - CPU Utilization"
echo "  Load Average (1/5/15 min):"
awk '{printf "    %s / %s / %s\n", $1, $2, $3}' /proc/loadavg
echo ""
echo "  Top 10 CPU-consuming processes:"
ps aux --sort=-%cpu | head -11 | awk 'NR==1{print "  "$0} NR>1{print "    "$0}'
echo ""
echo "  CPU governor:"
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null \
    | sed 's/^/    /' || echo "    not available (no cpufreq)"

# ── Section 2: Memory ────────────────────────────────────────────────────────
section "SECTION 2 - Memory Utilization"
free -h | sed 's/^/  /'
echo ""
echo "  Top 10 memory-consuming processes:"
ps aux --sort=-%mem | head -11 | awk 'NR==1{print "  "$0} NR>1{print "    "$0}'
echo ""
echo "  OOM score adjustments (high values = first to kill):"
for pid in $(ls /proc | grep -E '^[0-9]+$' | head -20); do
    score=$(cat /proc/$pid/oom_score 2>/dev/null || continue)
    comm=$(cat /proc/$pid/comm 2>/dev/null || echo "?")
    [[ $score -gt 100 ]] && echo "    PID=$pid comm=$comm oom_score=$score"
done || true

# ── Section 3: Disk I/O ──────────────────────────────────────────────────────
section "SECTION 3 - Disk Utilization"
echo "  Filesystem usage:"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=squashfs \
    2>/dev/null | sed 's/^/  /'
echo ""
echo "  Inode usage (filesystems >80% inode):"
df -i --exclude-type=tmpfs --exclude-type=squashfs 2>/dev/null \
    | awk 'NR==1{print "  "$0} NR>1 && $5!="100%" && int($5)>80{print "  [WARN] "$0}'
echo ""
if command -v iostat &>/dev/null; then
    echo "  I/O statistics (1-second sample):"
    iostat -xz 1 1 2>/dev/null | sed 's/^/  /' | tail -20
fi

# ── Section 4: Network ───────────────────────────────────────────────────────
section "SECTION 4 - Network Connections"
echo "  Connection state summary:"
ss -s 2>/dev/null | sed 's/^/  /'
echo ""
echo "  Listening TCP/UDP services:"
ss -tlunp 2>/dev/null | sed 's/^/  /'

echo ""
echo "$SEP"
echo "  Performance Baseline Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 03-journal-analysis.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Journal Analysis
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"
HOURS="${1:-24}"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

section "SECTION 1 - Failed Systemd Units"
echo "  Failed units:"
systemctl --failed --no-legend 2>/dev/null | sed 's/^/  /' \
    || echo "  Unable to list failed units"

section "SECTION 2 - Critical and Error Messages (last ${HOURS}h)"
echo "  Priority: critical (crit/alert/emerg):"
journalctl -p 2 --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | head -30 | sed 's/^/  /' || echo "  None found"
echo ""
echo "  Priority: error (err):"
journalctl -p 3 --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -v ': error:$' | head -40 | sed 's/^/  /' || echo "  None found"

section "SECTION 3 - Boot Analysis"
echo "  Boot log summary:"
journalctl --list-boots --no-pager 2>/dev/null | tail -5 | sed 's/^/  /'
echo ""
echo "  Last boot critical messages:"
journalctl -b -p 3 --no-pager -q 2>/dev/null | head -20 | sed 's/^/  /' \
    || echo "  None found"

section "SECTION 4 - OOM Events (last ${HOURS}h)"
echo "  Out-of-memory kill events:"
journalctl -k --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'out of memory\|oom.kill\|killed process' \
    | head -20 | sed 's/^/  /' || echo "  None found"

section "SECTION 5 - AppArmor Denials (last ${HOURS}h)"
echo "  AppArmor denial events:"
journalctl -k --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'apparmor.*denied\|apparmor.*audit' \
    | head -20 | sed 's/^/  /' || echo "  None found"

section "SECTION 6 - SSH Authentication Events (last ${HOURS}h)"
echo "  Failed SSH logins:"
journalctl -u ssh --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep -i 'failed password\|invalid user\|authentication failure' \
    | tail -20 | sed 's/^/  /' || echo "  None found"
echo ""
echo "  Successful logins:"
journalctl -u ssh --since "${HOURS} hours ago" --no-pager -q 2>/dev/null \
    | grep 'Accepted' | tail -10 | sed 's/^/  /' || echo "  None found"

echo ""
echo "$SEP"
echo "  Journal Analysis Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 04-storage-health.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Storage Health
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: Mount Points ──────────────────────────────────────────────────
section "SECTION 1 - Filesystem and Mount Points"
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=squashfs \
    2>/dev/null | sed 's/^/  /'
echo ""
echo "  Mounts at/above 80% usage:"
df -hT --exclude-type=tmpfs --exclude-type=squashfs 2>/dev/null \
    | awk 'NR>1 && int($6)>=80 {print "  [WARN] "$0}'

# ── Section 2: LVM ──────────────────────────────────────────────────────────
section "SECTION 2 - LVM Status"
if command -v pvs &>/dev/null; then
    echo "  Physical Volumes:"
    pvs 2>/dev/null | sed 's/^/  /' || echo "  No PVs found"
    echo ""
    echo "  Volume Groups:"
    vgs 2>/dev/null | sed 's/^/  /' || echo "  No VGs found"
    echo ""
    echo "  Logical Volumes:"
    lvs 2>/dev/null | sed 's/^/  /' || echo "  No LVs found"
    echo ""
    echo "  LVM snapshots:"
    lvs -o name,lv_attr,origin,snap_percent 2>/dev/null \
        | grep -E '^.{4}s' | sed 's/^/  /' || echo "  No snapshots active"
else
    echo "  [INFO] LVM tools not installed or no LVM configured"
fi

# ── Section 3: ZFS Pools ─────────────────────────────────────────────────────
section "SECTION 3 - ZFS Status"
if command -v zpool &>/dev/null && zpool list &>/dev/null 2>&1; then
    echo "  Pools:"
    zpool list | sed 's/^/  /'
    echo ""
    echo "  Pool health:"
    zpool status 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  ZFS datasets:"
    zfs list 2>/dev/null | sed 's/^/  /'
else
    echo "  [INFO] ZFS not in use on this system"
fi

# ── Section 4: SMART Disk Health ────────────────────────────────────────────
section "SECTION 4 - Disk SMART Status"
if command -v smartctl &>/dev/null; then
    for dev in /dev/sd? /dev/nvme?; do
        [[ -b "$dev" ]] || continue
        echo "  Disk: $dev"
        smartctl -H "$dev" 2>/dev/null | grep -E 'SMART|result|overall' \
            | sed 's/^/    /' || echo "    Unable to read SMART data"
    done
else
    echo "  [INFO] smartmontools not installed"
    echo "  Install: apt install smartmontools"
fi

# ── Section 5: Snap Disk Usage ───────────────────────────────────────────────
section "SECTION 5 - Snap Disk Usage"
if command -v snap &>/dev/null; then
    echo "  Snap package storage:"
    du -sh /var/lib/snapd/snaps/ 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Disabled (old) snap revisions:"
    snap list --all 2>/dev/null | awk '/disabled/{print "  "$0}' \
        || echo "  Unable to list snap revisions"
else
    echo "  [INFO] snapd not installed"
fi

echo ""
echo "$SEP"
echo "  Storage Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 05-network-diagnostics.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Network Diagnostics
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: Interface Summary ────────────────────────────────────────────
section "SECTION 1 - Network Interfaces"
ip addr show 2>/dev/null | sed 's/^/  /'
echo ""
echo "  Routing table:"
ip route show 2>/dev/null | sed 's/^/  /'

# ── Section 2: Netplan Configuration ────────────────────────────────────────
section "SECTION 2 - Netplan Configuration"
if ls /etc/netplan/*.yaml &>/dev/null 2>&1; then
    for f in /etc/netplan/*.yaml; do
        echo "  File: $f"
        cat "$f" | sed 's/^/    /'
        echo ""
    done
else
    echo "  [INFO] No netplan configuration files found"
fi

# ── Section 3: Backend (networkd vs NetworkManager) ─────────────────────────
section "SECTION 3 - Network Backend Status"
echo "  systemd-networkd:"
systemctl is-active systemd-networkd 2>/dev/null | sed 's/^/    Status: /'
if command -v networkctl &>/dev/null; then
    networkctl 2>/dev/null | head -10 | sed 's/^/    /'
fi
echo ""
echo "  NetworkManager:"
systemctl is-active NetworkManager 2>/dev/null | sed 's/^/    Status: /'
if command -v nmcli &>/dev/null; then
    nmcli -t -f NAME,STATE,TYPE,DEVICE connection show 2>/dev/null \
        | head -10 | sed 's/^/    /'
fi

# ── Section 4: UFW Firewall Status ──────────────────────────────────────────
section "SECTION 4 - UFW Firewall Status"
if command -v ufw &>/dev/null; then
    sudo ufw status verbose 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query UFW (may need sudo)"
else
    echo "  [INFO] UFW not installed"
fi

# ── Section 5: DNS / systemd-resolved ───────────────────────────────────────
section "SECTION 5 - DNS Configuration (resolvectl)"
if command -v resolvectl &>/dev/null; then
    resolvectl status 2>/dev/null | head -30 | sed 's/^/  /'
else
    echo "  [INFO] resolvectl not available"
    echo "  /etc/resolv.conf:"
    cat /etc/resolv.conf | sed 's/^/    /'
fi

# ── Section 6: Listening Ports ───────────────────────────────────────────────
section "SECTION 6 - Listening Ports"
echo "  TCP listening:"
ss -tlnp 2>/dev/null | sed 's/^/  /'
echo ""
echo "  UDP listening:"
ss -ulnp 2>/dev/null | sed 's/^/  /'

# ── Section 7: Connectivity Check ───────────────────────────────────────────
section "SECTION 7 - Basic Connectivity"
for target in 8.8.8.8 1.1.1.1 ubuntu.com; do
    if ping -c1 -W2 "$target" &>/dev/null; then
        echo "  [OK]   $target reachable"
    else
        echo "  [FAIL] $target unreachable"
    fi
done

echo ""
echo "$SEP"
echo "  Network Diagnostics Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 06-security-audit.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Security Audit
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: AppArmor Status ───────────────────────────────────────────────
section "SECTION 1 - AppArmor Status"
if command -v aa-status &>/dev/null; then
    aa-status 2>/dev/null | head -30 | sed 's/^/  /' \
        || echo "  Unable to query AppArmor (need root)"
else
    echo "  [WARN] AppArmor tools (apparmor-utils) not installed"
fi

# ── Section 2: User Accounts ─────────────────────────────────────────────────
section "SECTION 2 - User Accounts"
echo "  Users with login shell:"
grep -E '/bin/(bash|sh|zsh|fish|dash)$' /etc/passwd \
    | awk -F: '{printf "  %-20s uid=%-6s shell=%s\n", $1, $3, $7}'
echo ""
echo "  Users with UID 0 (root equivalents):"
awk -F: '$3==0{print "  [WARN] "$1" has UID 0"}' /etc/passwd

echo ""
echo "  Password status for interactive users:"
awk -F: 'NR==FNR && $3>=1000 && $3<65534 {users[$1]=1} NR!=FNR && $1 in users \
    {printf "  %-20s status=%s\n", $1, $2}' /etc/passwd /etc/shadow 2>/dev/null \
    || echo "  (need root to read /etc/shadow)"

# ── Section 3: Sudo Configuration ───────────────────────────────────────────
section "SECTION 3 - Sudo Configuration"
echo "  /etc/sudoers (NOPASSWD entries):"
grep -r 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null \
    | sed 's/^/  [WARN] /' || echo "  None found"
echo ""
echo "  Sudo group members:"
getent group sudo 2>/dev/null | sed 's/^/  /' || true
getent group admin 2>/dev/null | sed 's/^/  /' || true

# ── Section 4: SSH Configuration ────────────────────────────────────────────
section "SECTION 4 - SSH Hardening Review"
sshd_config="/etc/ssh/sshd_config"
checks=(
    "PermitRootLogin:PermitRootLogin no"
    "PasswordAuthentication:PasswordAuthentication no"
    "X11Forwarding:X11Forwarding no"
    "PermitEmptyPasswords:PermitEmptyPasswords no"
    "Protocol:Protocol 2"
)
for check in "${checks[@]}"; do
    key="${check%%:*}"
    expected="${check#*:}"
    val=$(grep -iE "^${key}\s" "$sshd_config" 2>/dev/null | tail -1 | xargs || echo "not set")
    if [[ "$val" == "$expected" ]]; then
        echo "  [OK]   $val"
    else
        echo "  [WARN] $key = $val (expected: $expected)"
    fi
done

# ── Section 5: Open Ports ───────────────────────────────────────────────────
section "SECTION 5 - Listening Services"
ss -tlunp 2>/dev/null | sed 's/^/  /'

# ── Section 6: Unattended Upgrades ──────────────────────────────────────────
section "SECTION 6 - Unattended Upgrades Configuration"
conf="/etc/apt/apt.conf.d/50unattended-upgrades"
if [[ -f "$conf" ]]; then
    echo "  Key settings from $conf:"
    grep -E 'Automatic-Reboot|Mail|Remove-Unused|Origins-Pattern' "$conf" \
        | grep -v '^\s*//' | sed 's/^/  /'
else
    echo "  [WARN] $conf not found — unattended-upgrades may not be configured"
fi
echo ""
echo "  unattended-upgrades service status:"
systemctl is-active unattended-upgrades 2>/dev/null | sed 's/^/  Status: /'

# ── Section 7: needrestart ───────────────────────────────────────────────────
section "SECTION 7 - Services Requiring Restart"
if command -v needrestart &>/dev/null; then
    sudo needrestart -b 2>/dev/null | sed 's/^/  /' \
        || echo "  Run as root for full results"
else
    echo "  [INFO] needrestart not installed"
    echo "  Install: apt install needrestart"
fi

echo ""
echo "$SEP"
echo "  Security Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 07-package-audit.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Package Audit (apt + snap)
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: apt Package Summary ──────────────────────────────────────────
section "SECTION 1 - APT Package Summary"
echo "  Total installed packages:"
dpkg -l | grep -c '^ii' | sed 's/^/  Count: /'
echo ""
echo "  Upgradable packages:"
apt list --upgradable 2>/dev/null | grep -v '^Listing' | sed 's/^/  /' \
    | head -30 || echo "  None (or apt update needed)"

# ── Section 2: Held Packages ─────────────────────────────────────────────────
section "SECTION 2 - Held Packages"
held=$(apt-mark showhold 2>/dev/null)
if [[ -n "$held" ]]; then
    echo "$held" | sed 's/^/  [HOLD] /'
else
    echo "  No packages on hold"
fi

# ── Section 3: Auto-removable Packages ──────────────────────────────────────
section "SECTION 3 - Auto-removable Packages"
echo "  Packages eligible for autoremove:"
apt list --auto-removable 2>/dev/null | grep -v '^Listing' | sed 's/^/  /' \
    | head -20 || echo "  None"

# ── Section 4: Residual Config Packages ─────────────────────────────────────
section "SECTION 4 - Residual Config Packages (rc state)"
rc_packages=$(dpkg -l | awk '/^rc/{print $2}')
if [[ -n "$rc_packages" ]]; then
    echo "  Packages removed but with config remaining:"
    echo "$rc_packages" | sed 's/^/  /'
    echo ""
    echo "  Remove with: dpkg -l | awk '/^rc/{print \$2}' | xargs apt purge -y"
else
    echo "  No residual config packages found"
fi

# ── Section 5: PPA and Extra Sources ────────────────────────────────────────
section "SECTION 5 - Package Sources / PPAs"
echo "  Active sources:"
grep -r "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
    | grep -v ':#' | sed 's/^/  /'

# ── Section 6: ESM Package Counts ───────────────────────────────────────────
section "SECTION 6 - ESM (Ubuntu Pro) Package Info"
if command -v pro &>/dev/null; then
    echo "  ESM-eligible packages from 'pro security-status':"
    pro security-status 2>/dev/null | head -30 | sed 's/^/  /' \
        || echo "  Run: pro security-status"
else
    echo "  [INFO] ubuntu-advantage-tools not installed"
fi

# ── Section 7: Snap Packages ─────────────────────────────────────────────────
section "SECTION 7 - Snap Packages"
if command -v snap &>/dev/null; then
    echo "  Installed snaps:"
    snap list 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  Disabled (old) revisions consuming disk:"
    snap list --all 2>/dev/null | awk '/disabled/{print "  "$0}' \
        || echo "  None"
    echo ""
    echo "  Snap refresh schedule:"
    snap get system refresh.timer 2>/dev/null | sed 's/^/  /' \
        || echo "  (default schedule)"
else
    echo "  [INFO] snapd not installed"
fi

echo ""
echo "$SEP"
echo "  Package Audit Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 08-livepatch-status.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Livepatch Status
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: Kernel Version ────────────────────────────────────────────────
section "SECTION 1 - Kernel Version"
echo "  Running kernel  : $(uname -r)"
echo "  Architecture    : $(uname -m)"
echo ""
echo "  All installed kernels:"
dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print "  "$2, $3}' \
    || echo "  Unable to list kernels"
echo ""
echo "  Reboot required:"
if [[ -f /var/run/reboot-required ]]; then
    echo "  [WARN] YES — kernel or other package requires reboot"
    cat /var/run/reboot-required.pkgs 2>/dev/null | sed 's/^/    /' || true
else
    echo "  [OK]   No reboot required"
fi

# ── Section 2: Ubuntu Pro Status ────────────────────────────────────────────
section "SECTION 2 - Ubuntu Pro Subscription"
if command -v pro &>/dev/null; then
    pro status 2>/dev/null | grep -E 'livepatch|esm|subscription|Account|Contract|Machine' \
        | sed 's/^/  /' || echo "  Run: pro status"
else
    echo "  [WARN] ubuntu-advantage-tools not installed"
    echo "  Livepatch requires Ubuntu Pro — install: apt install ubuntu-advantage-tools"
fi

# ── Section 3: Livepatch Service ────────────────────────────────────────────
section "SECTION 3 - Livepatch Service Status"
if command -v canonical-livepatch &>/dev/null; then
    echo "  Livepatch status:"
    canonical-livepatch status 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query — is Livepatch enabled?"
    echo ""
    echo "  Livepatch daemon:"
    systemctl status snap.canonical-livepatch.canonical-livepatchd.service \
        2>/dev/null | head -10 | sed 's/^/  /' \
        || echo "  Livepatch daemon service not found"
else
    echo "  [INFO] canonical-livepatch not installed"
    echo "  Enable with: pro enable livepatch"
fi

# ── Section 4: Applied Patches ──────────────────────────────────────────────
section "SECTION 4 - Applied Livepatch Details"
if command -v canonical-livepatch &>/dev/null; then
    echo "  Detailed patch status:"
    canonical-livepatch status --verbose 2>/dev/null | sed 's/^/  /' \
        || echo "  Unable to query verbose status"
else
    echo "  [INFO] No Livepatch data available (not installed)"
fi

# ── Section 5: HWE Kernel Stack ─────────────────────────────────────────────
section "SECTION 5 - HWE Kernel Stack"
echo "  HWE kernel packages:"
dpkg -l linux-generic-hwe-* linux-image-generic-hwe-* 2>/dev/null \
    | awk '/^ii/{print "  [installed] "$2, $3}' || echo "  No HWE kernel installed (using GA kernel)"

echo ""
echo "  Current kernel vs HWE availability:"
apt-cache policy linux-generic-hwe-$(lsb_release -sr 2>/dev/null || echo "22.04") \
    2>/dev/null | head -5 | sed 's/^/  /' || echo "  Cannot determine HWE availability"

echo ""
echo "$SEP"
echo "  Livepatch Status Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```

---

### 09-service-health.sh

```bash
#!/usr/bin/env bash
# ============================================================================
# Ubuntu - Service Health
# Version : 1.0.0
# Targets : Ubuntu 20.04+
# Safety  : Read-only. No modifications to system configuration.
# ============================================================================
set -euo pipefail

SEP="$(printf '=%.0s' {1..70})"

section() { echo ""; echo "$SEP"; echo "  $1"; echo "$SEP"; }

# ── Section 1: Failed Units ──────────────────────────────────────────────────
section "SECTION 1 - Failed Systemd Units"
failed=$(systemctl --failed --no-legend 2>/dev/null)
if [[ -n "$failed" ]]; then
    echo "  [WARN] Failed units detected:"
    echo "$failed" | sed 's/^/  /'
else
    echo "  [OK]   No failed units"
fi

# ── Section 2: Enabled Services ─────────────────────────────────────────────
section "SECTION 2 - Enabled Services"
echo "  All enabled services:"
systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null \
    | sed 's/^/  /' | head -40

# ── Section 3: Active Timer Units ───────────────────────────────────────────
section "SECTION 3 - Systemd Timer Units"
echo "  Active timers:"
systemctl list-timers --all --no-legend 2>/dev/null | head -20 | sed 's/^/  /'

# ── Section 4: Critical Service Status ──────────────────────────────────────
section "SECTION 4 - Critical Ubuntu Service Status"
critical_services=(
    ssh
    cron
    ufw
    apparmor
    unattended-upgrades
    systemd-networkd
    systemd-resolved
    snapd
)
for svc in "${critical_services[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        state="[OK]   active"
    elif systemctl is-enabled --quiet "$svc" 2>/dev/null; then
        state="[WARN] enabled but inactive"
    else
        state="[INFO] not active/enabled"
    fi
    printf "  %-30s %s\n" "$svc" "$state"
done

# ── Section 5: Crash Reports ─────────────────────────────────────────────────
section "SECTION 5 - Crash Reports (/var/crash/)"
if [[ -d /var/crash ]]; then
    crashes=$(ls -lt /var/crash/*.crash 2>/dev/null | head -10)
    if [[ -n "$crashes" ]]; then
        echo "  [WARN] Crash reports found:"
        ls -lh /var/crash/*.crash 2>/dev/null | sed 's/^/  /'
        echo ""
        echo "  Most recent crash summary:"
        newest=$(ls -t /var/crash/*.crash 2>/dev/null | head -1)
        if [[ -n "$newest" ]]; then
            echo "  File: $newest"
            strings "$newest" 2>/dev/null \
                | grep -E '^(Package|ProblemType|Uname|ExecutablePath):' \
                | sed 's/^/    /' || echo "  (unable to parse — run as root)"
        fi
    else
        echo "  [OK]   No crash reports in /var/crash/"
    fi
else
    echo "  [INFO] /var/crash/ does not exist"
fi

# ── Section 6: Snap Services ─────────────────────────────────────────────────
section "SECTION 6 - Snap Services"
if command -v snap &>/dev/null; then
    snap_services=$(snap services 2>/dev/null)
    if [[ -n "$snap_services" ]]; then
        echo "$snap_services" | sed 's/^/  /'
    else
        echo "  [INFO] No snap services or snapd not responding"
    fi
else
    echo "  [INFO] snapd not installed"
fi

# ── Section 7: Recent Service Restarts ──────────────────────────────────────
section "SECTION 7 - Recent Service Restarts (last 24h)"
echo "  Services that restarted in last 24 hours:"
journalctl --since "24 hours ago" --no-pager -q 2>/dev/null \
    | grep -E 'Started|Stopped|Restarting' \
    | grep -v 'session' \
    | tail -20 | sed 's/^/  /' || echo "  Unable to query journal"

echo ""
echo "$SEP"
echo "  Service Health Check Complete - $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "$SEP"
```
