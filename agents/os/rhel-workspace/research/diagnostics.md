# RHEL Diagnostics and Troubleshooting — Cross-Version Reference (RHEL 8/9/10)

## 1. journalctl — Systemd Journal

### Basic Filtering
```bash
journalctl -u nginx.service              # Filter by systemd unit
journalctl -u sshd -u firewalld         # Multiple units
journalctl -p err                        # Priority: emerg/alert/crit/err/warning/notice/info/debug
journalctl -p 0..3                       # Priority range (emerg through err)
journalctl --since "2025-01-01 00:00:00" --until "2025-01-02 00:00:00"
journalctl --since "1 hour ago"
journalctl --since today
journalctl -b                            # Current boot
journalctl -b -1                         # Previous boot
journalctl --list-boots                  # Show all recorded boots
journalctl -f                            # Follow (tail -f equivalent)
journalctl -n 100                        # Last 100 lines
```

### Output Formats
```bash
journalctl -o json                       # JSON (one entry per line)
journalctl -o json-pretty               # Pretty-printed JSON
journalctl -o verbose                   # All fields, human-readable
journalctl -o short-precise             # Microsecond timestamps
journalctl -o cat                       # Message only, no metadata
journalctl -o export                    # Binary export format
```

### Kernel and Catalog Messages
```bash
journalctl -k                            # Kernel messages only (dmesg equivalent)
journalctl -k --since "30 min ago"      # Recent kernel messages
journalctl --catalog                    # Include explanatory catalog entries
journalctl -xe                          # Recent errors with catalog context
```

### Field Filtering
```bash
journalctl _SYSTEMD_UNIT=nginx.service  # Field match
journalctl _PID=1234                    # By PID
journalctl _UID=0                       # By UID (root)
journalctl _COMM=sshd                   # By command name
journalctl _HOSTNAME=web01              # By hostname
journalctl PRIORITY=3 _UID=1000        # Combined field filters
journalctl -F _SYSTEMD_UNIT            # List all unique values for field
```

### Persistent Storage and Size Management
```bash
# Enable persistent journal storage
mkdir -p /var/log/journal
systemd-tmpfiles --create --prefix /var/log/journal

# /etc/systemd/journald.conf key settings:
# Storage=persistent          (auto|volatile|persistent|none)
# SystemMaxUse=1G             (max disk use for system journal)
# SystemKeepFree=500M         (keep this much disk free)
# MaxRetentionSec=1month      (discard entries older than this)
# MaxFileSec=1week            (rotate file after this period)

systemctl restart systemd-journald      # Apply config changes
journalctl --disk-usage                 # Show current disk usage
journalctl --vacuum-size=500M          # Reduce to 500M immediately
journalctl --vacuum-time=1month        # Remove entries older than 1 month
journalctl --verify                    # Verify journal file integrity
```

---

## 2. sosreport / sos collect

### Running sosreport
```bash
# RHEL 8/9
sosreport                                # Interactive, prompts for case number
sosreport --batch                       # Non-interactive, no prompts
sosreport --batch --case-id 12345678    # With case number
sosreport -o kernel,networking,selinux  # Only specified plugins
sosreport -n yum,logs                   # Exclude specified plugins
sosreport --tmp-dir /var/tmp           # Custom output directory
sosreport --list-plugins               # Show all available plugins

# RHEL 9/10 (sos command replaces sosreport)
sos report                              # Equivalent to sosreport
sos report --batch --case-id 12345678
sos report -o kernel,networking,selinux
sos report --list-plugins
```

### Common Plugins
| Plugin | Captures |
|--------|----------|
| `kernel` | sysctl, modules, dmesg, /proc/*, kernel config |
| `filesys` | df, mount, fstab, lsblk, filesystem errors |
| `networking` | ip addr/route, ss, iptables, nmcli, /etc/sysconfig/network-scripts |
| `selinux` | sestatus, audit.log, SELinux policy, booleans |
| `yum` | repo configs, installed packages, update history |
| `systemd` | Unit files, service status, journald config |
| `logs` | /var/log/messages, secure, boot.log, dmesg |
| `memory` | /proc/meminfo, /proc/slabinfo, vmstat |
| `hardware` | dmidecode, lspci, lsusb, smartctl |
| `kdump` | kdump config, crash kernel info |

### sos collect (Cluster-Wide)
```bash
sos collect                              # Collect from cluster nodes
sos collect --nodes node1,node2,node3  # Specify nodes explicitly
sos collect --master node1             # Designate master node
sos collect --cluster-type kubernetes  # Kubernetes cluster
sos collect --ssh-user admin          # SSH user for remote nodes
```

### Analyzing sos Reports
```bash
# Extract the archive
tar -xzf sosreport-hostname-*.tar.xz

# Key files to examine inside extracted report:
# sos_logs/                         - sos collection logs
# var/log/messages                  - system messages
# var/log/secure                    - auth/security events
# sos_commands/networking/          - ip, ss, nmcli output
# sos_commands/systemd/             - systemctl output
# proc/meminfo                      - memory snapshot
# etc/                              - configuration files

# Upload to Red Hat support
redhat-support-tool addattachment -c 12345678 sosreport-*.tar.xz
```

---

## 3. Performance Analysis Tools

### sar (System Activity Reporter) — sysstat package
```bash
dnf install sysstat                      # Install
systemctl enable --now sysstat          # Enable collection (runs via cron/timer)

sar -u 5 10                             # CPU util: 5s interval, 10 samples
sar -r 5 10                             # Memory utilization
sar -b 5 10                             # I/O transfer rates
sar -n DEV 5 10                         # Network interface stats
sar -n SOCK                             # Socket statistics
sar -q 5 10                             # Load average / run queue
sar -d 5 10                             # Disk activity (per device)
sar -f /var/log/sa/sa15                 # Read historical data (15th of month)
sar -A                                  # All statistics
sar -s 09:00:00 -e 17:00:00 -f /var/log/sa/sa15  # Time range from file
```

### vmstat, iostat, mpstat, pidstat
```bash
vmstat 5 10                             # Virtual memory: 5s interval, 10 samples
vmstat -s                               # Summary statistics
vmstat -d                               # Disk statistics

iostat -xz 5 10                         # Extended disk I/O stats (skip zero)
iostat -h -x 5                          # Human-readable extended stats
# Key iostat fields: %util (saturation), await (ms), r/s, w/s, rkB/s, wkB/s

mpstat -P ALL 5                         # Per-CPU stats every 5s
mpstat -P 0,1,2 5                       # Specific CPUs

pidstat 5                               # Per-process CPU
pidstat -d 5                            # Per-process disk I/O
pidstat -r 5                            # Per-process memory
pidstat -w 5                            # Context switches
pidstat -p 1234 5                       # Specific PID
```

### Memory and Socket Tools
```bash
free -h                                 # Memory usage (human-readable)
free -h -s 5                            # Repeat every 5s
cat /proc/meminfo                       # Detailed memory info

ss -tlnp                                # TCP listening ports with process
ss -tulnp                               # TCP+UDP listening
ss -s                                   # Summary statistics
ss -o state established '( dport = :80 or dport = :443 )'
ss -anp | grep ESTABLISHED | wc -l     # Count established connections

nstat -az                               # Network counters (replaces netstat -s)
nstat -d                                # Delta since last call
```

### Advanced Profiling
```bash
# perf — Linux profiling
dnf install perf
perf top                                # Live profiling (like top for CPU cycles)
perf record -a -g sleep 30             # Record system-wide 30s
perf report                            # Analyze recording
perf stat -p 1234                      # Performance counters for PID
perf trace -p 1234                     # Syscall tracing (like strace)

# bpftrace — eBPF tracing (RHEL 8.2+)
dnf install bpftrace
bpftrace -l                            # List available probes
bpftrace -e 'tracepoint:syscalls:sys_enter_read { @[comm] = count(); }'
bpftrace /usr/share/bpftrace/tools/opensnoop.bt    # Track file opens

# tuna — IRQ and thread tuning
dnf install tuna
tuna --show-irqs                       # Show IRQ affinity
tuna --irqs=<irq> --cpus=0,1          # Set IRQ affinity
tuna -P                                # Show thread priorities
```

---

## 4. System Boot Diagnostics

### systemd-analyze
```bash
systemd-analyze                         # Total boot time
systemd-analyze blame                  # Units by startup time (slowest first)
systemd-analyze critical-chain         # Critical path in boot sequence
systemd-analyze critical-chain nginx.service  # Chain for specific unit
systemd-analyze plot > boot.svg        # SVG timeline of boot
systemd-analyze verify /etc/systemd/system/myservice.service  # Validate unit file
systemd-analyze security nginx.service # Security assessment of unit
```

### dracut Troubleshooting
```bash
# Add to GRUB kernel line at boot (press 'e' at GRUB menu):
rd.break            # Drop to shell before pivot_root (initramfs shell)
rd.shell            # Drop to shell on error
rd.debug            # Enable dracut debug logging
rd.info             # Verbose boot messages

# At rd.break shell (remount and fix):
mount -o remount,rw /sysroot
chroot /sysroot
# make changes...
touch /.autorelabel  # if SELinux needs relabel
exit; exit

# Rebuild initramfs
dracut --force                          # Rebuild for current kernel
dracut --force /boot/initramfs-$(uname -r).img $(uname -r)
dracut --list-modules                  # Show included modules
```

### Emergency and Rescue Targets
```bash
# At GRUB: append to kernel line
systemd.unit=emergency.target          # Emergency (minimal, read-only /)
systemd.unit=rescue.target            # Rescue (single-user, rw /)

# After booting
systemctl isolate emergency.target    # Switch to emergency from running system
systemctl isolate rescue.target

# Reset root password procedure:
# 1. Boot, press 'e' at GRUB
# 2. Add to 'linux' line: rd.break enforcing=0
# 3. Ctrl+X to boot
# At initramfs shell:
mount -o remount,rw /sysroot
chroot /sysroot
passwd root
touch /.autorelabel
exit; exit
```

### SELinux Autorelabel
```bash
# Force relabel on next boot
touch /.autorelabel
reboot

# Or add kernel parameter at GRUB:
autorelabel=1

# Monitor relabel progress (slow on large filesystems):
journalctl -f -u selinux-autorelabel
```

---

## 5. Crash Dump Analysis (kdump)

### Configuration
```bash
# /etc/kdump.conf — key directives:
# path /var/crash              (local dump path)
# core_collector makedumpfile -l --message-level 1 -d 31
# default reboot               (action if dump fails)

# Kernel parameter (set via grub):
# crashkernel=auto             (RHEL 8 default)
# crashkernel=256M             (explicit reservation)

# Check if kdump is active
systemctl status kdump
kdumpctl status                         # Detailed kdump status

# Enable kdump
dnf install kexec-tools
systemctl enable --now kdump

# After changing crashkernel parameter, reboot required
# Verify crashkernel memory reserved:
cat /proc/cmdline | grep crashkernel
dmesg | grep crashkernel
```

### Testing and Analysis
```bash
# TEST ONLY — triggers kernel panic and dump:
echo c > /proc/sysrq-trigger            # WARNING: causes system crash/reboot

# Locate vmcore
ls /var/crash/                          # Default dump location
ls /var/crash/$(hostname)-*/           # Timestamped subdirectory

# makedumpfile — create filtered dump
makedumpfile -d 31 /proc/vmcore /var/crash/vmcore.filtered
# -d 31: exclude free, zero, cache pages (reduces size)

# crash utility — analyze vmcore
dnf install crash kernel-debuginfo
crash /usr/lib/debug/lib/modules/$(uname -r)/vmlinux /var/crash/*/vmcore

# Common crash commands:
# bt          - backtrace (call stack)
# bt -a       - all tasks backtraces
# ps          - process list at crash time
# log         - kernel message buffer
# sys         - system info
# vm          - virtual memory info
# kmem -i     - memory info
# files -d    - open files at crash
# quit        - exit
```

---

## 6. Network Diagnostics

### IP and Routing
```bash
ip addr show                            # All interfaces and addresses
ip addr show dev eth0                  # Specific interface
ip link show                           # Link status / MTU
ip link set eth0 up/down               # Bring interface up/down
ip route show                          # Routing table
ip route get 8.8.8.8                  # Route to specific destination
ip neigh show                          # ARP/neighbor table
ip -s link show eth0                  # Interface statistics
```

### NetworkManager (nmcli)
```bash
nmcli connection show                  # List all connections
nmcli connection show --active        # Active connections only
nmcli connection up "eth0"            # Activate connection
nmcli connection down "eth0"          # Deactivate
nmcli connection modify "eth0" ipv4.addresses 192.168.1.100/24
nmcli connection modify "eth0" ipv4.gateway 192.168.1.1
nmcli connection modify "eth0" ipv4.dns "8.8.8.8 8.8.4.4"
nmcli connection modify "eth0" ipv4.method manual
nmcli device status                    # Device status overview
nmcli general status                  # General NetworkManager status
nmcli radio wifi                      # WiFi radio state
journalctl -u NetworkManager -f       # NM logs
```

### Connectivity Testing
```bash
tracepath 8.8.8.8                      # Traceroute (no root required, uses UDP)
traceroute -I 8.8.8.8                 # ICMP traceroute
mtr 8.8.8.8                           # Combined ping + traceroute (interactive)
mtr --report 8.8.8.8                  # Non-interactive report

tcpdump -i eth0 -n port 80            # Capture HTTP on interface
tcpdump -i any -w /tmp/cap.pcap       # Write all traffic to file
tcpdump -r /tmp/cap.pcap              # Read capture file

nmap -sV -p 80,443,22 192.168.1.0/24 # Service version scan
nmap -sn 192.168.1.0/24              # Ping sweep (no port scan)

curl -v https://example.com           # HTTP test with verbose
curl -I https://example.com           # Headers only
wget --spider https://example.com     # Test URL accessibility
```

### DNS Diagnostics
```bash
dig example.com                        # Basic DNS query
dig @8.8.8.8 example.com A            # Query specific server, A record
dig example.com MX                    # MX records
dig +short example.com                # Short output
dig +trace example.com                # Trace full resolution path
nslookup example.com                  # Interactive DNS lookup
getent ahosts example.com            # Use NSS (respects /etc/nsswitch.conf)
cat /etc/resolv.conf                  # Current resolver config
resolvectl status                     # systemd-resolved status (RHEL 9+)
```

### Firewalld Diagnostics
```bash
firewall-cmd --state                  # Is firewalld running?
firewall-cmd --list-all               # All rules for default zone
firewall-cmd --list-all-zones        # All zones with rules
firewall-cmd --get-active-zones      # Active zones and interfaces
firewall-cmd --zone=public --list-services
firewall-cmd --zone=public --list-ports
firewall-cmd --query-service=ssh     # Is SSH allowed?
# Check dropped packets:
journalctl -k | grep "FINAL_REJECT\|_DROP"
iptables -L -n -v                    # View underlying iptables rules
```

---

## 7. Storage Diagnostics

### Block Device Inspection
```bash
lsblk                                  # Tree view of block devices
lsblk -f                              # With filesystem type and UUID
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID
blkid                                  # Block device UUIDs and types
blkid /dev/sda1                       # Specific device

fdisk -l                              # List partition tables (MBR)
gdisk -l /dev/sda                     # GPT partition table
parted -l                             # All disks, partition details

df -hT                                # Disk usage with filesystem type
df -i                                 # Inode usage
du -sh /var/*                         # Directory sizes
du -sh --exclude=/proc /*             # Top-level excluding /proc
```

### SMART Data
```bash
dnf install smartmontools
smartctl -a /dev/sda                  # All SMART data
smartctl -H /dev/sda                  # Health check only
smartctl -t short /dev/sda           # Run short self-test
smartctl -t long /dev/sda            # Run long self-test
smartctl -l selftest /dev/sda        # View test results
```

### LVM Diagnostics
```bash
pvs                                    # Physical volumes summary
pvdisplay                             # Detailed PV info
pvdisplay /dev/sda2                   # Specific PV

vgs                                    # Volume groups summary
vgdisplay                             # Detailed VG info
vgdisplay rhel                        # Specific VG

lvs                                    # Logical volumes summary
lvdisplay                             # Detailed LV info
lvs -o +devices                       # Show backing devices

# LVM event log
journalctl -u lvm2-monitor            # LVM events
lvmconfig --type diff                 # Non-default LVM config
```

### Stratis Diagnostics (RHEL 8+)
```bash
stratis pool list                     # List pools
stratis filesystem list               # List filesystems
stratis blockdev list                 # List block devices in pools
stratis pool list --name mypool       # Specific pool info
journalctl -u stratisd                # Stratis daemon logs
```

### XFS Tools
```bash
xfs_info /dev/mapper/rhel-root       # Filesystem geometry
xfs_info /mountpoint                  # By mount point
xfs_repair -n /dev/sda1              # Dry-run check (unmounted only)
xfs_repair /dev/sda1                 # Repair (filesystem must be unmounted)
xfs_fsr /dev/sda1                    # Defragment XFS filesystem
xfs_db -c check /dev/sda1           # Database-level check

# SSD TRIM
fstrim -av                            # TRIM all mounted filesystems
systemctl enable fstrim.timer         # Enable weekly TRIM
```

### Multipath Diagnostics
```bash
dnf install device-mapper-multipath
mpathconf --enable                    # Enable multipath
multipath -ll                         # List multipath devices
multipath -v3                         # Verbose check
multipathd show paths                 # Path status
multipathd show maps                  # Map status
journalctl -u multipathd              # Multipath logs
```

---

## 8. Process and Service Diagnostics

### systemctl
```bash
systemctl status nginx.service        # Service status with recent logs
systemctl show nginx.service          # All unit properties
systemctl cat nginx.service           # Show unit file content
systemctl list-dependencies nginx     # Dependency tree
systemctl list-dependencies --reverse nginx  # What depends on nginx
systemctl --failed                    # All failed units
systemctl list-units --state=failed  # Same (explicit)
systemctl list-unit-files --state=enabled
systemctl list-timers                 # All timers with next trigger time
systemctl daemon-reload               # Reload unit files
```

### Syscall and Library Tracing
```bash
# strace — system call tracer
dnf install strace
strace -p 1234                        # Attach to running process
strace -p 1234 -o /tmp/trace.txt     # Write to file
strace -p 1234 -e trace=open,read,write  # Filter syscalls
strace -f -p 1234                    # Follow forks
strace -c command                    # Count syscall stats for command
strace -T -p 1234                    # Show time in each syscall

# ltrace — library call tracer
dnf install ltrace
ltrace -p 1234                       # Attach to process
ltrace -e malloc,free command        # Filter library calls
```

### lsof — Open Files and Sockets
```bash
lsof -p 1234                         # All files opened by PID
lsof -u username                     # Files opened by user
lsof /var/log/messages               # What has this file open
lsof +D /var/www                     # All files under directory
lsof -i :80                          # What's using port 80
lsof -i TCP:1-1024                   # All low TCP ports
lsof -i -n -P                        # All network connections (no DNS)
lsof | grep deleted                  # Deleted files still held open (disk space recovery)
```

### /proc Filesystem
```bash
cat /proc/1234/status                # Process status (VmRSS, threads, etc.)
cat /proc/1234/cmdline               # Command line (null-separated)
cat /proc/1234/environ               # Environment variables
ls -l /proc/1234/fd                  # File descriptors
ls -l /proc/1234/fd | wc -l         # Count open FDs
cat /proc/1234/maps                  # Memory mappings
cat /proc/1234/net/tcp               # TCP sockets for process net namespace
cat /proc/meminfo                    # System memory breakdown
cat /proc/cpuinfo                    # CPU details
cat /proc/interrupts                 # IRQ counts per CPU
cat /proc/loadavg                    # Load averages + running/total tasks
cat /proc/sys/vm/swappiness          # Current swappiness value
```

---

## 9. Security Diagnostics

### SELinux
```bash
sestatus                              # SELinux status and mode
getenforce                            # Enforcing / Permissive / Disabled
setenforce 0                         # Set permissive (temporary, test only)
setenforce 1                         # Re-enable enforcing

# Find AVC denials
ausearch -m AVC -ts recent           # Recent AVC denials
ausearch -m AVC -ts today            # Today's AVC denials
ausearch -m AVC -c httpd             # Denials for specific command
audit2why < /var/log/audit/audit.log # Explain denials
audit2allow -a                       # Generate policy from all denials
sealert -a /var/log/audit/audit.log  # Human-readable analysis (setroubleshoot)

# Context inspection
ls -Z /var/www/html/                 # File SELinux context
ps -eZ | grep httpd                  # Process context
id -Z                                # Current user context
chcon -t httpd_sys_content_t /var/www/html/index.html  # Change context (temp)
restorecon -Rv /var/www/html/        # Restore default context

# Booleans
getsebool -a                         # All booleans
getsebool httpd_can_network_connect  # Specific boolean
setsebool -P httpd_can_network_connect on  # Set persistent boolean
```

### Authentication Failures
```bash
journalctl -u sshd                    # SSH service logs
journalctl -u sshd -p warning        # SSH warnings and above
grep "Failed password" /var/log/secure | tail -20
grep "authentication failure" /var/log/secure
lastb | head -20                     # Failed login attempts
last | head -20                      # Successful logins
faillock --user username             # PAM faillock status
faillock --reset --user username     # Reset account lockout

# PAM debugging
journalctl -u systemd-logind        # Login service
grep pam /var/log/secure             # PAM messages in secure log
# For verbose PAM, temporarily add to /etc/pam.d/sshd:
# auth optional pam_echo.so msg=PAM_DEBUG
```

### Certificate and TLS Diagnostics
```bash
# Test TLS connection
openssl s_client -connect example.com:443
openssl s_client -connect example.com:443 -showcerts
openssl s_client -connect example.com:443 -CAfile /etc/pki/tls/cert.pem

# Inspect certificate
openssl x509 -in /path/to/cert.pem -text -noout
openssl x509 -in /path/to/cert.pem -dates -noout  # Expiry dates
openssl x509 -in /path/to/cert.pem -subject -issuer -noout

# System crypto policy (RHEL 8+)
update-crypto-policies --show        # Current policy
update-crypto-policies --set DEFAULT # Set policy
update-crypto-policies --set FIPS    # FIPS mode
fips-mode-setup --check             # Verify FIPS status
```

---

## 10. Red Hat Insights / RHEL Lightspeed

### Insights Client
```bash
dnf install insights-client
insights-client --register           # Register system with Insights
insights-client --status             # Check registration status
insights-client --check-results      # Pull latest advisor results
insights-client --unregister         # Remove system from Insights
insights-client --diagnosis          # Request diagnosis
insights-client --compliance         # Run compliance scan
insights-client --collector malware  # Malware detection (if enabled)
```

### Insights Capabilities
- **Advisor**: Proactive recommendations for security, performance, availability, stability
- **Vulnerability Assessment**: CVE exposure based on installed packages and kernel version
- **Compliance Scanning**: OpenSCAP-based compliance (PCI-DSS, CIS, STIG, HIPAA)
- **Drift Detection**: Configuration drift from a defined baseline
- **Patch Planning**: Identify and schedule applicable patches with risk scoring
- **Malware Detection**: Checks for known malware signatures (opt-in)

### OpenSCAP Integration
```bash
dnf install openscap-scanner scap-security-guide
# List available profiles
oscap info /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Run scan
oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_cis \
  --results /tmp/scan-results.xml \
  --report /tmp/scan-report.html \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# Generate remediation script
oscap xccdf generate fix \
  --profile xccdf_org.ssgproject.content_profile_cis \
  /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml > remediation.sh
```

### RHEL Lightspeed (RHEL 10)
- AI assistant integrated into RHEL 10 for natural-language troubleshooting
- Accessible via `rhel-lightspeed` CLI or GNOME Cockpit web console
- Provides context-aware command suggestions and log analysis
- Requires Red Hat subscription and network access to Ansible Lightspeed API

---

## 11. Quick Reference Diagnostic Workflows

### High CPU Investigation
```bash
top -b -n 1 | head -20               # Snapshot top processes
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -20
mpstat -P ALL 5 3                    # Per-CPU breakdown
pidstat -u 5 3                       # Per-process CPU over time
perf top -d 5                        # Live profiling (what code is hot)
# Identify wait type:
sar -u 5 3  # Look for %iowait vs %usr vs %sys
# If high %iowait → go to disk I/O workflow
# If high %sys  → strace the process
strace -p <PID> -c -f               # Syscall summary for process
```

### Memory Pressure / OOM Killer
```bash
free -h                              # Basic memory view
vmstat 5 5                          # Watch memory columns
cat /proc/meminfo | grep -E "MemTotal|MemFree|Buffers|Cached|Slab|Swap"
dmesg | grep -i "oom\|killed"       # OOM events in dmesg
journalctl -k | grep -i "oom\|killed"
# Find OOM details:
grep -i "oom_kill\|out of memory" /var/log/messages
# Check per-process OOM score
cat /proc/<PID>/oom_score
cat /proc/<PID>/oom_score_adj
# Slab memory leak:
cat /proc/slabinfo | sort -k3 -rn | head -20
slabtop -o                          # Interactive slab view
```

### Disk Full Emergency
```bash
df -hT                               # Identify full filesystem
du -sh /var/* | sort -rh | head -10 # Largest dirs in /var
du -sh /var/log/*                   # Log sizes
# Find large files:
find /var -xdev -size +100M -ls 2>/dev/null
# Find deleted but held-open files (reclaimable space):
lsof | grep deleted | awk '{print $7, $1, $2}' | sort -rn | head -20
# Kill or restart the process holding the deleted file, or:
# Truncate log if safe: > /var/log/somelog.log
# Clear journal:
journalctl --vacuum-size=200M
# Clear package cache:
dnf clean all
```

### High I/O Wait
```bash
iostat -xz 5 5                       # Identify saturated disk (%util near 100)
iotop -bo -d 5                       # Per-process I/O (requires iotop package)
pidstat -d 5 3                       # Per-process I/O via sysstat
# Identify what's reading/writing:
lsof -p <PID>                        # Files open by high-I/O process
# Check for I/O errors:
dmesg | grep -iE "error|reset|failed" | grep -i sd
journalctl -k | grep -iE "I/O error|medium error"
smartctl -H /dev/sda                 # Check disk health
```

### Network Connectivity Loss
```bash
ip link show                         # Interface up/down state
ip addr show                         # IP assignment
ip route show                        # Default gateway present?
ping -c 3 $(ip route | awk '/default/ {print $3}')  # Ping gateway
ping -c 3 8.8.8.8                   # Internet reachability
dig +short @8.8.8.8 example.com     # DNS bypass local resolver
firewall-cmd --list-all             # Firewall rules blocking?
journalctl -u NetworkManager -n 50  # NM recent events
nmcli connection show --active      # Active connection state
ss -tlnp                            # Any local service down?
```

### Service Crash Loop
```bash
systemctl status myservice          # Last error and PID
journalctl -u myservice -n 100      # Recent logs
journalctl -u myservice --since "10 minutes ago"
systemctl show myservice | grep -E "Restart|StartLimit|ActiveState|Result"
# Check for resource limits:
systemctl show myservice | grep -i limit
cat /proc/<last_pid>/limits         # If process still exists
# Core dump check:
coredumpctl list                    # List core dumps
coredumpctl info                    # Details of latest core dump
coredumpctl debug                   # Open gdb on latest core
# Increase verbosity temporarily:
systemctl edit myservice            # Override: Environment=DEBUG=1
```

### Authentication Failure Investigation
```bash
journalctl -u sshd --since "1 hour ago"
grep "Failed\|Invalid\|Connection closed" /var/log/secure | tail -30
faillock --user <username>          # Check if account is locked
lastb -a | head -20                # Failed login log
last -a | head -20                 # Successful logins
# Check PAM config:
cat /etc/pam.d/sshd
cat /etc/security/faillock.conf    # Lockout thresholds
# SELinux blocking SSH?
ausearch -m AVC -c sshd -ts today
sealert -a /var/log/audit/audit.log | grep sshd
# Check for IP blocks:
firewall-cmd --zone=public --list-rich-rules
```

---

## Key Log Paths Reference

| Path | Contents |
|------|----------|
| `/var/log/messages` | General system messages (RHEL 8/9) |
| `/var/log/secure` | Authentication, PAM, sudo, SSH |
| `/var/log/audit/audit.log` | SELinux AVC, auditd events |
| `/var/log/dmesg` | Boot-time kernel messages |
| `/var/log/boot.log` | Boot service messages |
| `/var/log/cron` | Cron job output |
| `/var/log/dnf.log` | Package manager activity |
| `/var/crash/` | kdump vmcore files |
| `/var/log/journal/` | Persistent systemd journal (if enabled) |
| `/var/log/sa/` | sar historical data files |
| `/run/log/journal/` | Volatile systemd journal |

## Essential Package List for Diagnostics

```bash
dnf install -y \
  sysstat \          # sar, iostat, mpstat, pidstat, sadf
  perf \             # Linux perf profiler
  bpftrace \         # eBPF tracing
  strace \           # System call tracer
  ltrace \           # Library call tracer
  lsof \             # Open files/sockets
  iotop \            # Per-process I/O monitor
  htop \             # Interactive process viewer
  mtr \              # Network path analysis
  tcpdump \          # Packet capture
  nmap \             # Network scanner
  smartmontools \    # SMART disk health
  kexec-tools \      # kdump
  crash \            # vmcore analysis
  setroubleshoot-server \  # sealert for SELinux
  insights-client \  # Red Hat Insights
  openscap-scanner \ # OpenSCAP compliance
  scap-security-guide  # SCAP content profiles
```
