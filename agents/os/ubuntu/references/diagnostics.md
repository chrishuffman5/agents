# Ubuntu Diagnostics Reference

> Cross-version diagnostic procedures (20.04-26.04). Ubuntu-specific tooling for
> troubleshooting package issues, snap problems, network diagnostics, performance,
> and crash analysis.

---

## 1. apport and ubuntu-bug

```bash
# Report a bug (collects crash data)
ubuntu-bug <package-name>
ubuntu-bug /usr/bin/nginx

# List crash reports
ls -lh /var/crash/

# Parse a crash file
apport-unpack /var/crash/_usr_sbin_nginx.1000.crash /tmp/crash-unpacked

# Analyze core dump
apport-retrace /var/crash/_usr_sbin_nginx.1000.crash

# Enable/disable crash collection
sudo systemctl enable --now apport
sudo systemctl disable apport
# Config: /etc/default/apport (enabled=1 or enabled=0)
```

---

## 2. apt Broken Dependencies

```bash
# Fix broken packages
sudo apt --fix-broken install
sudo dpkg --configure -a

# Force reinstall
sudo apt install --reinstall <package>

# Check for broken package states
dpkg -l | grep -E '^(rc|iF|iU)'
# rc = removed but config remains
# iF = failed (half-installed)
# iU = unpacked but not configured

# Remove residual config files
dpkg -l | awk '/^rc/{print $2}' | xargs sudo apt purge -y 2>/dev/null

# Clean partial downloads
sudo apt clean

# Search for file in uninstalled packages
apt-file search libssl.so.1    # requires: apt install apt-file && apt-file update
```

---

## 3. snap Troubleshooting

```bash
# View snap change history
snap changes
snap tasks <change-id>

# Snap service logs
journalctl -u snap.<snap>.<service>
journalctl --user-unit=snap.<snap>.<service>

# Interface connections
snap connections <snap>

# Revert to previous revision
sudo snap revert <snap>

# Enter snap environment shell
snap run --shell <snap>

# Enable/disable snap
sudo snap disable <snap>
sudo snap enable <snap>

# Remove completely
sudo snap remove --purge <snap>

# Debug snapd
journalctl -u snapd
```

---

## 4. sosreport on Ubuntu

```bash
sudo apt install sosreport
sudo sosreport
sudo sosreport --tmp-dir /tmp/sos
sudo sosreport --enable-plugins networking,apt,systemd
sudo sosreport --skip-plugins kernel,hardware
```

Output: `/tmp/sosreport-hostname-date.tar.xz`

---

## 5. needrestart -- Services Requiring Restart

```bash
sudo apt install needrestart
sudo needrestart                # interactive check
sudo needrestart -b             # batch mode (non-interactive)
sudo needrestart -ra            # auto-restart services

# Config: /etc/needrestart/needrestart.conf
# $nrconf{restart} = 'a';      # auto-restart
```

---

## 6. Performance Tools

### Standard Tools

```bash
sar -u 1 10                    # CPU utilization
sar -r 1 5                     # memory
sar -d 1 5                     # disk I/O
vmstat 1 10                    # virtual memory, I/O, CPU
iostat -xz 1                   # disk I/O extended
```

### ubuntu-drivers -- GPU and Driver Management

```bash
ubuntu-drivers devices
ubuntu-drivers list
sudo ubuntu-drivers autoinstall
sudo apt install nvidia-driver-535
```

### lm-sensors

```bash
sudo apt install lm-sensors
sudo sensors-detect --auto
sensors
watch -n 2 sensors
```

### powertop

```bash
sudo apt install powertop
sudo powertop
sudo powertop --html=/tmp/powertop.html
sudo powertop --auto-tune
```

---

## 7. Network Diagnostics

### Netplan Troubleshooting

```bash
# Show current config
cat /etc/netplan/*.yaml

# Safe testing (auto-revert in 120s)
sudo netplan try

# Debug mode
sudo netplan --debug apply
sudo netplan --debug generate

# Generated backend configs
ls /run/systemd/network/       # systemd-networkd
ls /run/NetworkManager/        # NetworkManager

# Validate YAML
python3 -c "import yaml; yaml.safe_load(open('/etc/netplan/01-netcfg.yaml'))"
```

### systemd-networkd Diagnostics

```bash
networkctl
networkctl status
networkctl status eth0
journalctl -u systemd-networkd
```

### NetworkManager Diagnostics

```bash
nmcli general status
nmcli connection show
nmcli device status
journalctl -u NetworkManager

# Increase log verbosity
sudo nmcli general logging level DEBUG domains ALL
# Restore
sudo nmcli general logging level INFO domains ALL
```

### DNS Diagnostics (systemd-resolved)

```bash
resolvectl status
resolvectl status eth0
resolvectl query ubuntu.com
resolvectl statistics
sudo resolvectl flush-caches
resolvectl dns

# Stub resolver check
ls -la /etc/resolv.conf        # should be symlink
```

### UFW Log Analysis

```bash
sudo tail -f /var/log/ufw.log

# Blocked by source IP
grep '\[UFW BLOCK\]' /var/log/ufw.log \
  | grep -oP 'SRC=\S+' | sort | uniq -c | sort -rn | head -20

# Blocked by destination port
grep '\[UFW BLOCK\]' /var/log/ufw.log \
  | grep -oP 'DPT=\d+' | sort | uniq -c | sort -rn | head -20

# UFW blocks in journal
journalctl -k | grep '\[UFW'
```

---

## 8. Package Diagnostics

### apt Diagnostics

```bash
# Installed vs available version
apt-cache policy <package>

# All available versions
apt-cache showpkg <package>

# Reverse dependencies
apt-cache rdepends --installed <package>

# Which package owns a file
dpkg -S /usr/bin/nginx

# Files in an installed package
dpkg -L nginx

# Search for file in uninstalled packages
apt-file search <file>

# Auto-removable packages
apt list --auto-removable 2>/dev/null

# Upgradable packages
apt list --upgradable 2>/dev/null

# PPA sources
grep -r "^deb" /etc/apt/sources.list /etc/apt/sources.list.d/
ls /etc/apt/sources.list.d/
```

### snap Diagnostics

```bash
snap info <snap>
snap list
snap connections <snap>
snap interfaces
snap services
snap changes
snap find <term>
```

---

## 9. Journal Analysis

### Critical and Error Messages

```bash
# Critical priority (crit/alert/emerg)
journalctl -p 2 --since "24 hours ago" --no-pager -q | head -30

# Error priority
journalctl -p 3 --since "24 hours ago" --no-pager -q | head -40

# Boot analysis
journalctl --list-boots --no-pager | tail -5
journalctl -b -p 3 --no-pager -q | head -20
```

### OOM Events

```bash
journalctl -k --since "24 hours ago" | grep -i 'out of memory\|oom.kill\|killed process'
```

### AppArmor Denials

```bash
journalctl -k --since "24 hours ago" | grep -i 'apparmor.*denied'
```

### SSH Authentication

```bash
# Failed logins
journalctl -u ssh --since "24 hours ago" | grep -i 'failed password\|invalid user'

# Successful logins
journalctl -u ssh --since "24 hours ago" | grep 'Accepted'
```

---

## 10. Storage Diagnostics

### Filesystem Usage

```bash
df -hT --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=squashfs
df -i   # inode usage
```

### LVM

```bash
pvs; vgs; lvs
lvs -o name,lv_attr,origin,snap_percent   # snapshot info
```

### ZFS

```bash
zpool list
zpool status
zfs list
zfs list -t snapshot
```

### SMART Disk Health

```bash
sudo apt install smartmontools
sudo smartctl -H /dev/sda
```

### Snap Disk Usage

```bash
du -sh /var/lib/snapd/snaps/
snap list --all | awk '/disabled/{print $0}'
```

---

## 11. Service Health

### Failed Units

```bash
systemctl --failed
systemctl --failed --no-legend
```

### Critical Ubuntu Services

Check status of: `ssh`, `cron`, `ufw`, `apparmor`, `unattended-upgrades`, `systemd-networkd`, `systemd-resolved`, `snapd`.

### Timer Units

```bash
systemctl list-timers --all
```

### Crash Reports

```bash
ls -lt /var/crash/*.crash | head -10
strings /var/crash/<file>.crash | grep -E '^(Package|ProblemType|ExecutablePath):'
```

### Snap Services

```bash
snap services
snap services <snap>
```
