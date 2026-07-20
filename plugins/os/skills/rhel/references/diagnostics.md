# RHEL Diagnostics and Troubleshooting Reference

## 1. journalctl (Systemd Journal)

### Filtering

```bash
journalctl -u nginx.service              # by unit
journalctl -p err                        # by priority (emerg/alert/crit/err/warning/notice/info/debug)
journalctl -p 0..3                       # priority range (emerg through err)
journalctl --since "1 hour ago"
journalctl -b                            # current boot
journalctl -b -1                         # previous boot
journalctl --list-boots                  # all recorded boots
journalctl -f                            # follow (tail -f)
journalctl -k                            # kernel messages (dmesg equivalent)
journalctl -xe                           # recent errors with catalog context
```

### Field Filtering and Output

```bash
journalctl _SYSTEMD_UNIT=nginx.service   # field match
journalctl _PID=1234                     # by PID
journalctl _COMM=sshd                    # by command name
journalctl -o json-pretty                # JSON output
journalctl -o verbose                    # all fields
journalctl --disk-usage                  # storage used
journalctl --vacuum-size=500M            # trim to 500M
journalctl --verify                      # verify integrity
```

---

## 2. sosreport / sos collect

```bash
# RHEL 8
sosreport --batch --case-id 12345678

# RHEL 9/10
sos report --batch --case-id 12345678
sos report -o kernel,networking,selinux  # specific plugins
sos report --list-plugins                # available plugins

# Cluster-wide
sos collect --nodes node1,node2,node3
```

### Key Plugins

| Plugin | Captures |
|--------|----------|
| kernel | sysctl, modules, dmesg, /proc/*, kernel config |
| filesys | df, mount, fstab, lsblk, filesystem errors |
| networking | ip addr/route, ss, nmcli, firewalld |
| selinux | sestatus, audit.log, SELinux policy, booleans |
| systemd | unit files, service status, journald config |

---

## 3. Performance Analysis Tools

### sar (sysstat)

```bash
dnf install sysstat && systemctl enable --now sysstat
sar -u 5 10                             # CPU (5s interval, 10 samples)
sar -r 5 10                             # memory
sar -b 5 10                             # I/O transfer rates
sar -n DEV 5 10                         # network interfaces
sar -d 5 10                             # disk activity
sar -q 5 10                             # load average
sar -f /var/log/sa/sa15                 # historical (15th of month)
```

### vmstat, iostat, mpstat, pidstat

```bash
vmstat 5 10                             # virtual memory
iostat -xz 5 10                         # extended disk I/O (key: %util, await)
mpstat -P ALL 5                         # per-CPU stats
pidstat 5                               # per-process CPU
pidstat -d 5                            # per-process disk I/O
pidstat -r 5                            # per-process memory
```

### Memory and Sockets

```bash
free -h                                 # memory usage
ss -tlnp                                # TCP listening with process
ss -tulnp                               # TCP+UDP listening
ss -s                                   # summary statistics
```

### Advanced Profiling

```bash
perf top                                # live CPU profiling
perf record -a -g sleep 30             # system-wide 30s recording
perf report                            # analyze recording
bpftrace -e 'tracepoint:syscalls:sys_enter_read { @[comm] = count(); }'
```

---

## 4. Boot Diagnostics

### systemd-analyze

```bash
systemd-analyze                         # total boot time
systemd-analyze blame                  # units by startup time
systemd-analyze critical-chain         # critical path
systemd-analyze security nginx.service # security assessment
```

### dracut Troubleshooting

At GRUB menu, append to kernel line:
- `rd.break` -- drop to initramfs shell before pivot_root
- `rd.shell` -- drop to shell on error
- `rd.debug` -- enable dracut debug logging

```bash
# At rd.break shell
mount -o remount,rw /sysroot
chroot /sysroot
# make changes
touch /.autorelabel                     # if SELinux needs relabel
exit; exit
```

### Emergency and Rescue

```bash
# Kernel cmdline
systemd.unit=emergency.target          # minimal, read-only root
systemd.unit=rescue.target             # single-user, rw root

# Reset root password:
# 1. Boot, press 'e' at GRUB
# 2. Add: rd.break enforcing=0
# 3. Ctrl+X, then remount rw, chroot, passwd root, touch /.autorelabel
```

---

## 5. Crash Dump Analysis (kdump)

```bash
# Configuration
systemctl enable --now kdump
kdumpctl status
cat /proc/cmdline | grep crashkernel

# Dump location: /var/crash/
# Analysis
dnf install crash kernel-debuginfo
crash /usr/lib/debug/lib/modules/$(uname -r)/vmlinux /var/crash/*/vmcore
# Commands: bt (backtrace), ps, log, sys, kmem -i
```

---

## 6. Network Diagnostics

### IP and Routing

```bash
ip addr show                            # interfaces and addresses
ip route show                           # routing table
ip route get 8.8.8.8                   # route to destination
ip -s link show eth0                   # interface statistics
```

### NetworkManager

```bash
nmcli connection show --active
nmcli device status
nmcli general status
journalctl -u NetworkManager -f
```

### Connectivity

```bash
tracepath 8.8.8.8                      # no root required
mtr --report 8.8.8.8                   # combined ping + traceroute
tcpdump -i eth0 -n port 80            # packet capture
curl -v https://example.com            # HTTP verbose
```

### DNS

```bash
dig example.com                        # basic query
dig @8.8.8.8 example.com A            # specific server
dig +trace example.com                # full resolution path
resolvectl status                      # systemd-resolved (RHEL 9+)
```

### Firewalld Diagnostics

```bash
firewall-cmd --state
firewall-cmd --list-all
firewall-cmd --get-active-zones
journalctl -k | grep "FINAL_REJECT\|_DROP"
```

---

## 7. Storage Diagnostics

### Block Devices

```bash
lsblk -f                              # tree with filesystem and UUID
blkid                                  # UUIDs and types
df -hT                                # usage with filesystem type
df -i                                  # inode usage
```

### SMART

```bash
dnf install smartmontools
smartctl -a /dev/sda                  # all SMART data
smartctl -H /dev/sda                  # health check
```

### LVM

```bash
pvs; vgs; lvs                          # summary views
lvs -o +devices                       # backing devices
journalctl -u lvm2-monitor
lvmconfig --type diff                 # non-default config
```

### Stratis

```bash
stratis pool list
stratis filesystem list
stratis blockdev list
journalctl -u stratisd
```

### XFS

```bash
xfs_info /mountpoint
xfs_repair -n /dev/sda1               # dry-run check (unmounted)
xfs_fsr /dev/sda1                     # defragment
fstrim -av                            # TRIM all mounted
```

### Multipath

```bash
multipath -ll                         # list devices
multipathd show paths                # path status
journalctl -u multipathd
```

---

## 8. Process and Service Diagnostics

### systemctl

```bash
systemctl status nginx.service
systemctl --failed                     # all failed units
systemctl list-unit-files --state=enabled
systemctl list-timers
systemctl cat nginx.service           # show unit file
systemctl show nginx.service          # all properties
```

### Tracing

```bash
strace -p 1234 -e trace=open,read,write   # syscall tracing
strace -c command                          # syscall summary
ltrace -p 1234                             # library call tracing
```

### Open Files

```bash
lsof -p 1234                         # files by PID
lsof -i :80                          # port 80 users
lsof | grep deleted                  # held-open deleted files
```

---

## 9. Security Diagnostics

### SELinux

```bash
sestatus                              # status and mode
ausearch -m AVC -ts recent           # recent denials
ausearch -m AVC -c httpd             # by command
audit2why < /var/log/audit/audit.log # explain denials
sealert -a /var/log/audit/audit.log  # human-readable analysis
ls -Z /var/www/html/                 # file contexts
ps -eZ | grep httpd                  # process contexts
restorecon -Rv /var/www/html/        # restore defaults
getsebool -a                         # all booleans
```

### Authentication Failures

```bash
journalctl -u sshd -p warning
grep "Failed password" /var/log/secure | tail -20
lastb | head -20                     # failed logins
faillock --user username             # lockout status
```

### Certificate/TLS

```bash
openssl s_client -connect host:443
openssl x509 -in cert.pem -dates -noout
update-crypto-policies --show
fips-mode-setup --check
```

---

## 10. Red Hat Insights

```bash
insights-client --register
insights-client --status
insights-client --check-results
insights-client --compliance           # OpenSCAP scan
insights-client --diagnosis
```

Capabilities: Advisor, Vulnerability Assessment, Compliance Scanning, Drift Detection, Patch Planning, Malware Detection.

### OpenSCAP

```bash
dnf install openscap-scanner scap-security-guide
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results /tmp/scan-results.xml \
  --report /tmp/scan-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml
```

---

## 11. Diagnostic Workflows

### High CPU

```bash
top -b -n 1 | head -20
mpstat -P ALL 5 3                    # per-CPU breakdown
pidstat -u 5 3                       # per-process
sar -u 5 3                          # %iowait vs %usr vs %sys
strace -p <PID> -c -f               # if high %sys
```

### Memory Pressure / OOM

```bash
free -h
dmesg | grep -i "oom\|killed"
journalctl -k | grep -i "oom\|killed"
cat /proc/<PID>/oom_score
slabtop -o                          # slab memory
```

### Disk Full

```bash
df -hT
du -sh /var/* | sort -rh | head -10
lsof | grep deleted | sort -k7 -rn | head -20
journalctl --vacuum-size=200M
dnf clean all
```

### Service Crash Loop

```bash
systemctl status myservice
journalctl -u myservice -n 100
systemctl show myservice | grep -E "Restart|StartLimit|Result"
coredumpctl list
coredumpctl info
```

### Network Connectivity Loss

```bash
ip link show
ip addr show
ip route show
ping -c 3 $(ip route | awk '/default/ {print $3}')
firewall-cmd --list-all
nmcli connection show --active
```

---

## Key Log Paths

| Path | Contents |
|------|----------|
| `/var/log/messages` | General system messages |
| `/var/log/secure` | Authentication, PAM, sudo, SSH |
| `/var/log/audit/audit.log` | SELinux AVC, auditd events |
| `/var/log/boot.log` | Boot service messages |
| `/var/log/dnf.log` | Package manager activity |
| `/var/crash/` | kdump vmcore files |
| `/var/log/journal/` | Persistent systemd journal |
| `/var/log/sa/` | sar historical data |

## Essential Diagnostic Packages

```bash
dnf install -y sysstat perf bpftrace strace ltrace lsof iotop htop \
  mtr tcpdump nmap smartmontools kexec-tools crash \
  setroubleshoot-server insights-client openscap-scanner scap-security-guide
```
