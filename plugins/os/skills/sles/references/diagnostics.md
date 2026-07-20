# SLES Diagnostics Reference

Diagnostic procedures for SUSE Linux Enterprise Server 15 SP5+. Covers supportconfig, YaST logs, zypper diagnostics, system health indicators, and Btrfs error analysis.

---

## supportconfig

`supportconfig` is SLES's comprehensive diagnostic collection tool -- equivalent to RHEL's sosreport. It collects system configuration, logs, hardware information, and package state into a compressed tarball for SUSE support.

### Collection Commands

```bash
# Full collection (most comprehensive)
supportconfig -A

# Interactive mode (choose what to collect)
supportconfig -i

# Collect specific features only
supportconfig -i lsof,memory,network,rpm,security,y2logs

# Upload to SUSE support (requires SR number)
supportconfig -u -r <SR-number>

# Specify output directory
supportconfig -R /tmp/support

# Output: /var/log/scc_<hostname>_<date>_<time>.txz
```

### Key Files Inside the Archive

```
basic-environment.txt  — hostname, OS release, kernel, uptime
messages.txt           — /var/log/messages content
rpm.txt                — installed package list
network.txt            — network configuration
memory.txt             — memory info
y2log.txt              — YaST logs
security-apparmor.txt  — AppArmor profiles and status
systemd.txt            — systemd unit status
```

### Analyzing supportconfig Output

```bash
# Unpack
tar xf /var/log/scc_*.txz -C /tmp/support-analysis/

# Quick system summary
grep -A5 "hostname" basic-environment.txt
grep "SUSE Linux" basic-environment.txt

# Check for recent errors
grep -i "error\|fail\|panic\|oops" messages.txt | tail -50

# AppArmor denials
grep "DENIED" security-apparmor.txt | tail -20

# Failed systemd units
grep "failed" systemd.txt
```

---

## YaST Logs

### Log Locations

```bash
# Main YaST log file
tail -100 /var/log/YaST2/y2log

# Installation logs
ls /var/log/YaST2/
# y2log          — main log (all YaST operations)
# y2log.1.gz     — rotated previous log
# storage.log    — partitioning/storage operations
# linuxrc.log    — installer linuxrc output (if present)

# Filter by severity
grep "^<3>" /var/log/YaST2/y2log   # Level 3 = error
grep "^<5>" /var/log/YaST2/y2log   # Level 5 = warning
```

---

## Zypper Diagnostics

### Transaction History

```bash
# Full zypper history log
cat /var/log/zypp/history

# Recent transactions
tail -50 /var/log/zypp/history

# Filter by action type
grep "^[0-9].*|install|" /var/log/zypp/history | tail -20
grep "^[0-9].*|remove|" /var/log/zypp/history | tail -20
```

### Dependency and Solver Issues

```bash
# Dry-run to check for conflicts
zypper install --dry-run <package>

# Verbose solver output
zypper --verbose patch

# Debug mode
zypper --debug install <package>

# Verify package integrity
zypper verify

# Check for orphaned packages (no repo provides them)
zypper packages --orphaned
```

### Repository Health

```bash
# List all repos with details
zypper repos --details

# Force refresh all repos
zypper refresh --force

# Test a specific repo
zypper refresh --repo <alias>

# Check for GPG key issues
rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n'
```

---

## System Health Indicators

### Registration and Repository Status

```bash
# SUSEConnect registration status
SUSEConnect --status

# Verify all registered repos are accessible
zypper refresh --force

# Check for pending security patches
zypper patches --category security | grep "Needed"
```

### systemd Health

```bash
# Check for failed units
systemctl --failed

# Check critical services
for svc in wickedd wicked sshd chronyd firewalld apparmor; do
    echo "$svc: $(systemctl is-active $svc 2>/dev/null || echo 'not-found')"
done

# Boot analysis
systemd-analyze
systemd-analyze blame | head -10

# List all boots
journalctl --list-boots | tail -5
```

### Journal Analysis

```bash
# Critical/Error messages (last 24h)
journalctl --since "24 hours ago" -p err..crit --no-pager | tail -50

# Kernel errors (last boot)
journalctl -k -b -p err..crit --no-pager | tail -30

# OOM events (last 7 days)
journalctl --since "7 days ago" -k --no-pager | grep -i "oom\|killed process" | tail -20

# AppArmor denials
journalctl --since "24 hours ago" --no-pager | grep -i "apparmor.*DENIED" | tail -20

# Btrfs warnings/errors
journalctl --since "7 days ago" -k --no-pager | grep -i "btrfs" | tail -20

# SSH login failures
journalctl --since "24 hours ago" -u sshd.service --no-pager | grep -i "fail\|invalid" | tail -20
```

### Reboot Status

```bash
# Check if reboot is required
zypper needs-rebooting
[ -f /run/reboot-needed ] && echo "REBOOT REQUIRED"

# Check for processes using deleted files (need restart)
zypper ps -s
```

---

## Btrfs Error Analysis

### Health Check Commands

```bash
# Filesystem overview
btrfs filesystem show /
btrfs filesystem df /
btrfs filesystem usage /

# Device error counters (non-zero = investigate)
btrfs device stats /

# Scrub status (last integrity check result)
btrfs scrub status /
```

### Common Btrfs Error Patterns

| Error | Likely Cause | Resolution |
|---|---|---|
| `checksum mismatch` | Bit rot or RAM error | Run scrub; check RAM with memtest |
| `parent transid verify failed` | Filesystem corruption | May need `btrfs check`; contact SUSE support |
| `No space left` but df shows space | Metadata block groups full | `btrfs balance start -musage=50 /` |
| `Transaction aborted` | I/O error | Check `btrfs device stats /` and `dmesg` |

### Metadata Saturation (ENOSPC)

```bash
# Diagnosis
btrfs filesystem usage /
# Look for Metadata: used much higher than free

# Resolution
btrfs balance start -musage=50 /    # Free underused metadata block groups
# If balance fails with ENOSPC:
btrfs balance start -musage=100 /
btrfs balance start -dusage=50 /    # Balance data too if needed
```

### Slow Write Performance

Causes: fragmentation, qgroup overhead, too many snapshots.

```bash
# Diagnosis
iostat -x 1 10                          # Check I/O wait
btrfs qgroup show / 2>/dev/null | wc -l  # Number of qgroups
btrfs subvolume list / | wc -l           # Number of subvolumes

# Resolution
btrfs quota disable /                   # If qgroup overhead is the cause
snapper cleanup number                  # Delete excess snapshots
btrfs filesystem defragment -r /usr     # If fragmentation is confirmed
```

### Snapshot Accumulation

```bash
snapper list | head -30                 # Check snapshot count
btrfs qgroup show -reF / | sort -k4 -h  # Find largest exclusive-use snapshots
snapper delete 1-50                     # Delete old snapshots
```

---

## Network Diagnostics

### Wicked Diagnostics

```bash
# Show all interfaces with status
wicked show all
wicked ifstatus all

# Validate configuration
wicked check-config

# Daemon logs
journalctl -u wickedd.service --since "1 hour ago"

# XML representation of current state
wicked xpath --ifconfig all
```

### General Network Checks

```bash
# Interface status
ip addr show
ip route show
ip -s link show

# DNS resolution
cat /etc/resolv.conf
host example.com
dig example.com

# Port connectivity
ss -tlnp                                # Listening TCP ports
ss -ulnp                                # Listening UDP ports

# Firewall status
firewall-cmd --list-all
firewall-cmd --get-active-zones
```

---

## Performance Diagnostics

### Quick Performance Snapshot

```bash
# CPU and load
uptime
lscpu | grep -E "CPU\(s\)|Thread|Core|Socket|Model name"

# Memory
free -h
grep -E "MemTotal|MemAvailable|SwapTotal|SwapFree|HugePages" /proc/meminfo

# Disk I/O
iostat -xd 1 3                          # Requires sysstat
cat /proc/diskstats | awk 'NF>10 {print $3, "reads:"$4, "writes:"$8}' | head -20

# Process overview
ps aux --sort=-%cpu | head -11
ps aux --sort=-%mem | head -11

# vmstat snapshot
vmstat -w 1 3
```

### saptune Verification

```bash
saptune status                          # Current tuning state
saptune solution verify HANA           # Verify compliance
saptune note verify 2382421            # Verify specific SAP Note
```
