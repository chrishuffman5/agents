# Ubuntu Best Practices Reference

> Cross-version best practices (20.04-26.04). Hardening, update management, firewall,
> AppArmor, Livepatch, snap management, backup, and Landscape fleet management.

---

## 1. CIS Benchmarks and Ubuntu Security Guide (USG)

### Ubuntu Security Guide

USG is the Canonical-maintained CIS benchmark implementation, available via Ubuntu Pro.

```bash
# Install (requires Ubuntu Pro)
sudo apt install ubuntu-security-guide

# Run CIS Level 1 audit (non-destructive)
sudo usg audit cis_level1_server

# Apply CIS Level 1 hardening
sudo usg fix cis_level1_server

# Generate HTML compliance report
sudo usg audit cis_level1_server --html-file /tmp/cis-report.html

# Available profiles
usg list-profiles
# cis_level1_server, cis_level2_server, cis_level1_workstation, cis_level2_workstation
# stig (DISA STIG, Ubuntu Pro only)
```

### Password Quality (pam_pwquality)

Config: `/etc/security/pwquality.conf`
```
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
minclass = 4
maxrepeat = 3
```

### Account Lockout

- 22.04+: `pam_faillock` (config: `/etc/security/faillock.conf`)
- 20.04: `pam_tally2` (deprecated)

```bash
# /etc/security/faillock.conf (22.04+)
deny = 5
fail_interval = 900
unlock_time = 900

# Unlock a user
faillock --user <username> --reset
```

### SSH Hardening

Critical settings for `/etc/ssh/sshd_config`:
```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 300
ClientAliveCountMax 2
AllowGroups sshusers
```

Ubuntu note: SSH service unit is `ssh`, not `sshd`. Validate before reload: `sshd -t && systemctl reload ssh`.

---

## 2. Update Management

### apt Upgrade Commands

| Command | Behavior |
|---|---|
| `apt update` | Refresh package index only |
| `apt upgrade` | Upgrade installed; never removes packages |
| `apt full-upgrade` | Upgrade + allow removals for dep resolution |
| `apt autoremove` | Remove orphaned dependency packages |

Use `full-upgrade` for routine patching to ensure kernel meta-packages update.

```bash
# Non-interactive upgrade sequence
sudo apt update -q
sudo apt full-upgrade -y
sudo apt autoremove -y
sudo apt autoclean
```

### unattended-upgrades

Installed by default on Ubuntu Server. Config: `/etc/apt/apt.conf.d/50unattended-upgrades`

```
// ESM security updates (Ubuntu Pro)
"${distro_id}ESMApps:${distro_codename}-apps-security";
"${distro_id}ESM:${distro_codename}-infra-security";

// Auto-reboot (default off)
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Clean up old kernels
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
```

Schedule: `/etc/apt/apt.conf.d/20auto-upgrades`
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

```bash
# Dry-run
sudo unattended-upgrades --dry-run --debug

# Check reboot required
cat /var/run/reboot-required 2>/dev/null && echo "REBOOT REQUIRED"
```

### HWE Kernel Stack

```bash
# Install HWE kernel
sudo apt install --install-recommends linux-generic-hwe-22.04

# List installed kernels
dpkg -l linux-image-* | grep ^ii

# Remove old kernels
sudo apt autoremove --purge
```

### do-release-upgrade

```bash
do-release-upgrade -c              # check availability
sudo do-release-upgrade            # run upgrade (interactive)
```

Requires 2+ hours and active monitoring. Handles kernel, package migration, and config prompts.

---

## 3. UFW Firewall

### Core Commands

```bash
sudo ufw status verbose            # rules + defaults
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable

# Allow rules
sudo ufw allow 22/tcp
sudo ufw allow 'OpenSSH'
sudo ufw allow from 10.0.0.0/8 to any port 22
sudo ufw limit ssh                 # rate-limit

# Delete rules
sudo ufw status numbered
sudo ufw delete 3

# Application profiles
sudo ufw app list
sudo ufw app info 'OpenSSH'
```

### UFW Logging

```bash
sudo ufw logging medium
tail -f /var/log/ufw.log
grep '\[UFW BLOCK\]' /var/log/ufw.log | awk '{print $12}' | sort | uniq -c | sort -rn
```

### UFW Backend

Ubuntu 22.04+ uses nftables backend. Check: `cat /etc/default/ufw | grep IPTABLES_BACKEND`.

Ubuntu does **not** install firewalld by default. Do not mix UFW and firewalld.

---

## 4. AppArmor

AppArmor is Ubuntu's default MAC system (path-based profiles, not labels like SELinux).

```bash
sudo aa-status                     # profiles and modes
sudo aa-enforce /etc/apparmor.d/usr.sbin.nginx
sudo aa-complain /etc/apparmor.d/usr.sbin.nginx
sudo aa-disable /etc/apparmor.d/usr.sbin.nginx

# View denials
journalctl -k | grep -i "apparmor.*denied"

# Generate/update profiles
sudo aa-genprof /usr/sbin/myapp
sudo aa-logprof
```

Modes: **enforce** (block + log), **complain** (log only), **unconfined** (no profile).

---

## 5. Landscape Fleet Management

### SaaS vs Self-Hosted

| Aspect | SaaS | Self-Hosted |
|---|---|---|
| URL | landscape.canonical.com | Your infrastructure |
| Included with | Ubuntu Pro | Separate license |
| Air-gapped | No | Yes |

### Client Registration

```bash
sudo apt install landscape-client
sudo pro attach <token>
pro enable landscape

# Manual registration
sudo landscape-config \
  --computer-title "$(hostname)" \
  --account-name myaccount \
  --url https://landscape.canonical.com/message-system
```

---

## 6. Snap Management Best Practices

### Refresh Scheduling

```bash
snap get system refresh.timer
sudo snap set system refresh.timer="mon-fri,02:00-04:00"
sudo snap refresh --hold=48h firefox
sudo snap refresh --unhold firefox
```

### Disk Space Management

```bash
# Remove all disabled revisions
snap list --all | awk '/disabled/{print $1, $3}' | \
  while read name rev; do sudo snap remove --revision="$rev" "$name"; done

# Check disk usage
du -sh /var/lib/snapd/snaps/
```

### Enterprise Snap Store Proxy

```bash
sudo snap install snap-store-proxy
sudo snap-proxy config proxy.domain=snapproxy.internal
sudo snap set system proxy.store=<proxy-id>
```

---

## 7. Backup and Recovery

### Timeshift

```bash
sudo apt install timeshift
sudo timeshift --create --comments "pre-upgrade" --tags D
sudo timeshift --list
sudo timeshift --restore --snapshot <name>
```

### rsync Strategies

```bash
# Full backup with metadata preservation
sudo rsync -aAXvH --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*"} / /backup/root/

# Incremental with hardlinks
sudo rsync -aAXvH --link-dest=/backup/last/ / /backup/$(date +%Y%m%d)/
```

### LVM Snapshots

```bash
sudo lvcreate -L10G -s -n snap_root /dev/ubuntu-vg/ubuntu-lv
sudo mount -o ro /dev/ubuntu-vg/snap_root /mnt/snap
```

### ZFS Snapshots

```bash
sudo zfs snapshot rpool/ROOT/ubuntu@pre-upgrade
zfs list -t snapshot
sudo zfs rollback rpool/ROOT/ubuntu@pre-upgrade
```

### REAR (Bare Metal Recovery)

```bash
sudo apt install rear
# Configure /etc/rear/local.conf: OUTPUT=ISO, BACKUP=NETFS
sudo rear mkbackup
```

---

## 8. Holding and Pinning Packages

```bash
# Hold at current version
sudo apt-mark hold <package>
sudo apt-mark unhold <package>
apt-mark showhold

# Pin via preferences
# /etc/apt/preferences.d/pin-nginx
Package: nginx
Pin: version 1.18.*
Pin-Priority: 1001
```

---

## 9. Ubuntu Pro Best Practices

```bash
# Attach (free for 5 machines)
sudo pro attach <token>

# Enable essential services
pro enable esm-infra
pro enable esm-apps
pro enable livepatch

# Fix specific CVE
pro fix CVE-2024-XXXXX

# Check security status
pro security-status
```

Always enable ESM-infra and ESM-apps on production LTS systems. Livepatch is recommended for systems where unplanned reboots are costly.
