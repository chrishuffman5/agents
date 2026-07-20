# macOS Diagnostics Reference

Cross-version coverage: macOS 14 Sonoma through macOS 26 Tahoe.

---

## 1. Unified Logging

macOS uses the Unified Logging System (ULS) since Sierra (10.12), replacing syslog. Logs are stored in a compressed binary format.

### log Command
```bash
# Stream live logs
log stream                                  # All logs (very verbose)
log stream --level debug                    # Include debug messages
log stream --predicate 'subsystem == "com.apple.network"'

# Show historical logs
log show                                    # Recent system logs
log show --last 1h                          # Last hour
log show --last 30m --level error           # Last 30 min, errors only
log show --start "2024-01-15 10:00:00" --end "2024-01-15 11:00:00"

# Collect logs for analysis
sudo log collect --output ~/Desktop/system_logs.logarchive
sudo log collect --last 2h --output ~/Desktop/recent.logarchive
# Open .logarchive in Console.app
```

### Predicate Syntax
```bash
# Filter by subsystem
--predicate 'subsystem == "com.apple.WindowServer"'

# Filter by category
--predicate 'subsystem == "com.apple.network" AND category == "connection"'

# Filter by process
--predicate 'process == "Finder"'

# Filter by message content
--predicate 'eventMessage CONTAINS "error"'
--predicate 'eventMessage BEGINSWITH "Failed"'

# Filter by log level
--predicate 'messageType == fault OR messageType == error'

# Combine predicates
--predicate 'subsystem == "com.apple.bluetooth" AND messageType == error'

# Using processID
--predicate 'processID == 1234'
```

### Log Levels and Persistence

| Level | Default Stored | Info Stored | Notes |
|-------|---------------|-------------|-------|
| Default | Yes | Yes | General operational messages |
| Info | No | Yes | Informational, only with `--info` flag |
| Debug | No | No | Developer detail, only with `--debug` |
| Error | Yes | Yes | Error conditions |
| Fault | Yes | Yes | Critical failures, in crash logs |

### sysdiagnose
```bash
sudo sysdiagnose                    # Full system state (~500MB-2GB)
sudo sysdiagnose -f /tmp/           # Save to specific directory
# Keyboard shortcut: Shift+Control+Option+Command+.
# Captures: logs, crash reports, network state, system info
```

---

## 2. Console.app and Crash Reports

### Console.app Features
- Real-time log streaming with visual filtering
- Filter by device, process, subsystem, category, type
- Activities view: traces correlated operations across processes
- Errors & Faults quick filter
- Search across historical log archive

### Crash Report Locations
```bash
# User crash reports
~/Library/Logs/DiagnosticReports/

# System crash reports (kernel panics, system-level)
/Library/Logs/DiagnosticReports/

# List recent crashes
ls -lt ~/Library/Logs/DiagnosticReports/ | head -20
ls -lt /Library/Logs/DiagnosticReports/ | head -20
```

### Crash Report File Types

| Extension | Description |
|-----------|-------------|
| `.crash` | Application crash (exception, signal) |
| `.hang` | Application hang (spinning beachball) |
| `.spin` | Spindump from spinning application |
| `.ips` | Newer JSON-format report (Monterey+) |
| `.panic` | Kernel panic log |
| `.diag` | General diagnostic reports |

### System and Install Logs
```bash
tail -f /var/log/system.log              # Legacy system log
cat /var/log/install.log                 # Software install log
cat /var/log/wifi.log                    # WiFi log
log show --predicate 'process == "kernel"' --last 1h
```

---

## 3. Performance Diagnostics

### Activity Monitor
- CPU, Memory, Energy, Disk, Network tabs
- Memory Pressure gauge: green (healthy), yellow (constrained), red (critical)
- Energy Impact: tracks power usage per app

### Command-Line Performance Tools
```bash
# CPU and process overview
top -o cpu                          # Sort by CPU
top -o rsize                        # Sort by memory

# Memory statistics
vm_stat                             # Virtual memory stats (page-based)
vm_stat 1                           # Update every second
# Pages free * 4096 = free bytes; Pages wired = kernel-locked

# Disk I/O
iostat                              # Block device statistics
iostat -d 1 5                       # 1-second interval, 5 samples

# File system activity
sudo fs_usage                       # All FS calls
sudo fs_usage -f filesys            # FS operations only
sudo fs_usage -p <pid>              # Specific process
```

### powermetrics (Apple Silicon)
```bash
sudo powermetrics                               # Continuous power/thermal
sudo powermetrics --samplers cpu_power,thermal  # CPU power and thermals
sudo powermetrics -n 1 -i 1000                  # Single sample
sudo powermetrics --samplers all -n 1 | grep -E "ANE|GPU|CPU|thermal"
# Reports: CPU cluster utilization, GPU, ANE (Neural Engine), package power, temperature
```

### Process Analysis
```bash
# Sample a process
sample <process_name_or_pid> 10 -file /tmp/sample_output.txt

# Spindump (snapshot of all threads)
sudo spindump <pid>                 # Specific PID
sudo spindump                       # All hanging processes
sudo spindump -reveal               # Save and open in Finder

# DTrace (requires SIP partial disable for some probes)
sudo dtrace -n 'syscall:::entry { @[execname] = count(); }'
```

### Instruments (Xcode)
- Time Profiler: CPU sampling profiler
- Allocations: memory allocation tracking
- Leaks: memory leak detection
- Network: HTTP/HTTPS traffic inspection
- Energy Log: battery impact analysis
- System Trace: comprehensive kernel/user space view

---

## 4. Disk Diagnostics

### diskutil Commands
```bash
diskutil list                               # All disks
diskutil list external                      # External only
diskutil info disk0                         # Detailed info
diskutil info /dev/disk0s2                  # Specific partition

# APFS-specific
diskutil apfs list                          # Containers and volumes
diskutil apfs listContainers               # List containers
diskutil apfs listVolumes disk1            # Volumes in container

# Verify and repair
diskutil verifyVolume /                     # Verify boot volume
diskutil repairVolume /Volumes/DriveName    # Repair unmounted
diskutil verifyDisk disk0                   # Verify partition map
```

### fsck_apfs
```bash
# Run from Recovery Mode or on unmounted volume
sudo fsck_apfs -n /dev/disk1s1              # Dry run
sudo fsck_apfs /dev/disk1s1                 # Repair
sudo fsck_apfs -y /dev/disk1s1              # Auto-yes
```

### SMART Data
```bash
# Built-in
system_profiler SPStorageDataType

# Via smartmontools (brew install smartmontools)
smartctl -a /dev/disk0                      # Full SMART report
smartctl -H /dev/disk0                      # Health check only
smartctl -t short /dev/disk0               # Short self-test
# NVMe: smartctl -a -d nvme /dev/disk0
```

### Storage Management
```bash
du -sh ~/Library/Caches
du -sh ~/Downloads
brew cleanup --dry-run
```

---

## 5. Network Diagnostics

### networksetup
```bash
networksetup -listallnetworkservices
networksetup -listallhardwareports
networksetup -getinfo "Wi-Fi"
networksetup -getdnsservers "Wi-Fi"
networksetup -setdnsservers "Wi-Fi" 1.1.1.1 8.8.8.8
networksetup -getwebproxy "Wi-Fi"
networksetup -getsecurewebproxy "Wi-Fi"
```

### scutil
```bash
scutil --dns                                # Full DNS configuration
scutil --proxy                              # Proxy configuration
scutil --nwi                                # Network interface state
scutil --nc list                            # VPN connections
scutil --nc status "VPN Name"               # VPN status
scutil --get ComputerName
scutil --get LocalHostName
```

### Standard Network Tools
```bash
ping -c 4 8.8.8.8
traceroute 8.8.8.8
nslookup apple.com
dig apple.com +short
dig @1.1.1.1 apple.com
curl -v https://example.com
netstat -an | grep LISTEN
lsof -i :80
lsof -i TCP
```

### Wi-Fi Diagnostics
```bash
# wdutil (macOS 12+, replaces airport utility)
sudo wdutil info                            # Current Wi-Fi info
sudo wdutil log +wifi +dhcp +dns            # Enable enhanced logging
sudo wdutil log -wifi                       # Disable logging
```

### Network Quality
```bash
networkQuality                              # Speed test (macOS 12+)
networkQuality -v                           # Verbose with responsiveness
networkQuality -I en0                       # Specific interface
```

### Firewall Status
```bash
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
/usr/libexec/ApplicationFirewall/socketfilterfw --getloggingmode
/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode
/usr/libexec/ApplicationFirewall/socketfilterfw --listapps
```

---

## 6. Crash and Hang Analysis

### DiagnosticReports
```bash
# User-level reports
ls -lt ~/Library/Logs/DiagnosticReports/

# System-level reports
ls -lt /Library/Logs/DiagnosticReports/

# View most recent crash
cat $(ls -t ~/Library/Logs/DiagnosticReports/*.crash 2>/dev/null | head -1)
# JSON format (.ips, Monterey+):
cat $(ls -t ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -1) | python3 -m json.tool
```

### IPS Crash Report Format (macOS 12+)
JSON-structured reports contain:
- `exception`: Exception type, codes, signal
- `threads`: All thread backtraces at crash time
- `usedImages`: Loaded binaries with UUIDs for symbolication
- `crashReporterKey`: Anonymous device identifier

### spindump and sample
```bash
sudo spindump                               # All hanging processes
sudo spindump <pid> 10 10                   # PID, duration, interval
sudo spindump -reveal                       # Save and open

sample Finder 10                            # 10-second CPU sample
sample <pid> 5 -file /tmp/output.txt
```

### Kernel Panics
```bash
ls /Library/Logs/DiagnosticReports/*.panic
log show --predicate 'process == "kernel" AND messageType == fault' --last 24h
sudo log show --predicate 'process == "diagnosticd"' --last 1h | grep -i panic
```

### Process Control
```bash
kill -9 <pid>                               # Force kill
killall -9 "Application Name"              # Kill by name
pkill -9 "partial name"                    # Pattern match
```

---

## 7. MDM Diagnostics

### Enrollment Status
```bash
sudo profiles show -type enrollment
sudo profiles status -type enrollment
sudo profiles status -type bootstraptoken
```

### MDM Log Stream
```bash
log stream --predicate 'subsystem == "com.apple.ManagedClient"' --level debug
log show --predicate 'subsystem == "com.apple.ManagedClient"' --last 1h --level debug
log show --predicate 'subsystem == "com.apple.ManagedClient" AND category == "CommandManager"' --last 2h
```

### Profile Debugging
```bash
sudo profiles show -all
sudo profiles show -type configuration
sudo profiles validate -path /path/to/profile.mobileconfig
sudo defaults read /Library/Managed\ Preferences/com.apple.applicationaccess
```

### Platform SSO Diagnostics
```bash
app-sso -l                                  # List SSO extensions
app-sso platform -s                         # PSSO state
log stream --predicate 'subsystem == "com.apple.AppSSO"' --level debug
log stream --predicate 'subsystem == "com.apple.AuthenticationServices"' --level debug
```

### Key Filesystem Paths

| Path | Contents |
|------|----------|
| `/var/db/ConfigurationProfiles/` | Installed profiles database |
| `/Library/Managed Preferences/` | MDM-enforced preferences |
| `/private/var/db/MDMClientEnrollment.plist` | Enrollment record |
| `~/Library/Logs/DiagnosticReports/` | User crash reports |
| `/Library/Logs/DiagnosticReports/` | System crash/panic reports |

---

*Coverage: macOS 14 Sonoma, 15 Sequoia, 26 Tahoe. Diagnostic commands are consistent across these versions unless noted.*
