# macOS Architecture Reference

Cross-version coverage: macOS 14 Sonoma through macOS 26 Tahoe.

---

## 1. XNU Kernel

### Hybrid Kernel Architecture

XNU ("X is Not Unix") is a hybrid kernel combining three subsystems: Mach microkernel, BSD layer, and I/O Kit. All three run in kernel space, giving XNU the performance of a monolithic kernel with microkernel-inspired IPC primitives.

- **Mach** -- low-level primitives: tasks, threads, ports, IPC, virtual memory
- **BSD** -- POSIX interface: processes, signals, sockets, VFS (Virtual File System)
- **I/O Kit** -- driver framework: C++-based, object-oriented device driver model

### Mach Subsystem

Tasks are the unit of resource ownership (address space, ports). Threads execute within tasks. Mach IPC uses ports as kernel-managed capability-based endpoints. Port rights: `MACH_PORT_RIGHT_RECEIVE`, `MACH_PORT_RIGHT_SEND`, `MACH_PORT_RIGHT_SEND_ONCE`. Messages sent via `mach_msg()` syscall. `launchd` serves as the bootstrap server for port name lookup.

```bash
sudo lsmp -p <pid>       # inspect Mach ports for a process
```

### BSD Layer

Implements POSIX compatibility: `fork()`, `exec()`, signals, pipes, sockets, and VFS. Derives from FreeBSD, not Linux. Uses `kqueue` for event notification (not `inotify`).

### I/O Kit

Drivers are C++ classes inheriting from `IOService`. The driver stack is a tree rooted at `IORegistryEntry`.

```bash
ioreg -l                          # full I/O Kit registry
ioreg -c IOPCIDevice              # filter by class
system_profiler SPUSBDataType     # USB devices via IOKit
```

### Kernel Extensions vs System Extensions

**Kexts (legacy):** Loaded into kernel address space. Deprecated on Apple Silicon; require SIP reduced or Apple approval on Intel.

```bash
kextstat | grep -v com.apple     # list non-Apple kexts
```

**System Extensions (preferred, macOS 10.15+):** Run in user space, mediated by `sysextd`. Types: DriverKit, NetworkExtension, EndpointSecurity. Approved via System Settings > Privacy & Security.

```bash
systemextensionsctl list         # list installed system extensions
```

### Signed System Volume (SSV)

Introduced macOS 11. System volume is sealed with a Merkle tree of hashes; root hash stored in NVRAM and verified at boot. System volume mounts read-only at `/`; Data volume at `/System/Volumes/Data`.

```bash
diskutil apfs listSnapshots disk3s1
csrutil authenticated-root disable   # disable SSV (Recovery only)
```

---

## 2. launchd

### Role and Architecture

`launchd` is PID 1 -- the first process started by the kernel, replacing `init`, `cron`, `inetd`, and `atd`. There is no `systemd` on macOS.

### Daemons vs Agents

| Type | Runs As | Location |
|------|---------|----------|
| LaunchDaemon | root or specified user | `/System/Library/LaunchDaemons/`, `/Library/LaunchDaemons/` |
| LaunchAgent (system) | logged-in user | `/System/Library/LaunchAgents/`, `/Library/LaunchAgents/` |
| LaunchAgent (user) | logged-in user | `~/Library/LaunchAgents/` |

### Plist Key Properties

```xml
<dict>
    <key>Label</key>           <string>com.example.svc</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/myservice</string>
        <string>--config</string><string>/etc/myservice.conf</string>
    </array>
    <key>RunAtLoad</key>       <true/>
    <key>KeepAlive</key>       <true/>
    <key>StartInterval</key>   <integer>300</integer>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>2</integer><key>Minute</key><integer>30</integer></dict>
    <key>WatchPaths</key>
    <array><string>/var/log/myapp.log</string></array>
    <key>StandardOutPath</key> <string>/tmp/svc.out</string>
    <key>StandardErrorPath</key><string>/tmp/svc.err</string>
</dict>
```

### launchctl Commands

```bash
# Modern syntax (load/unload deprecated since 10.11)
launchctl bootstrap system /Library/LaunchDaemons/com.example.svc.plist
launchctl bootout system /Library/LaunchDaemons/com.example.svc.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.agent.plist

# Inspection and control
launchctl list                           # all jobs in current session
launchctl print system/com.example.svc  # detailed service state
launchctl kickstart -k system/com.example.svc   # restart service
launchctl kill SIGTERM system/com.example.svc
launchctl enable system/com.example.svc
launchctl disable system/com.example.svc
```

---

## 3. APFS (Apple File System)

### Container and Volume Architecture

One physical partition holds a single APFS container; multiple volumes share the container's space pool dynamically -- no fixed partition sizes.

```
disk0s2  APFS Container (disk1)
  +-- disk1s1  Macintosh HD  [System, sealed, read-only]
  +-- disk1s2  Preboot        [boot policy, kernel cache]
  +-- disk1s3  Recovery
  +-- disk1s4  VM             [swap]
  +-- disk1s5  Macintosh HD - Data  [read-write: /Users, /Applications]
```

### Key Features

**Snapshots (Time Machine):**
```bash
tmutil listlocalsnapshotdates /
diskutil apfs listSnapshots disk1s1
diskutil apfs deleteSnapshot disk1s1 -uuid <UUID>
```

**Clones:** `cp -c source dest` -- copy-on-write clone at APFS level, instant and space-free until modified.

**Encryption (FileVault):**
```bash
fdesetup status
fdesetup enable / disable
fdesetup list                     # FileVault-enabled users
diskutil apfs list                # shows encryption status per volume
```

Per-volume AES-XTS encryption; per-file encryption also supported at the APFS layer independent of FileVault.

**diskutil APFS commands:**
```bash
diskutil apfs list
diskutil apfs createVolume disk1 APFS "MyVol"
diskutil apfs deleteVolume disk1s6
diskutil apfs encryptVolume disk1s5 -user disk
```

**Crash protection:** Copy-on-write for both metadata and data; atomic B-tree transactions replace journaling.

---

## 4. Apple Silicon vs Intel

### Unified Memory Architecture

Apple Silicon (M-series) uses a single LPDDR5X memory pool shared by CPU, GPU, Neural Engine, and media engines. No discrete GPU VRAM -- GPU memory is the same physical RAM.

```bash
system_profiler SPHardwareDataType   # chip and memory info
sysctl hw.memsize
sysctl hw.perflevel0.physicalcpu    # Performance cores
sysctl hw.perflevel1.physicalcpu    # Efficiency cores
```

### Rosetta 2

AOT translation at first launch; translation cache in `/var/db/oah/`. `oahd` is the translation daemon.

```bash
arch -x86_64 /bin/bash              # run shell via Rosetta 2
arch -arm64 /bin/bash               # explicitly native arm64
file /usr/bin/python3               # shows universal binary info
```

### Universal Binaries

```bash
lipo -info /path/to/binary          # list architectures
lipo -thin arm64 universal_bin -output arm64_only
lipo -create x86_64_bin arm64_bin -output universal_bin
```

### Virtualization Framework

macOS 12+ Virtualization.framework runs macOS or Linux VMs natively on Apple Silicon with hardware acceleration. Intel Macs support Linux guests only.

### Homebrew Paths

| Platform | Homebrew prefix |
|----------|----------------|
| Apple Silicon | `/opt/homebrew` |
| Intel | `/usr/local` |

### T2 (Intel) vs Secure Enclave (Apple Silicon)

On Intel Macs the T2 chip handles Secure Boot, Touch ID, FileVault key storage, SSD controller, and hardware AES. On Apple Silicon, all of these are integrated into the SoC Secure Enclave.

---

## 5. System Integrity Protection (SIP)

SIP restricts modification of `/System`, `/usr` (except `/usr/local`), `/bin`, `/sbin`, and select `/private/var` paths. Runtime protections prevent code injection into Apple processes, debugger attachment to system processes, unsigned kext loading, and `DYLD_*` manipulation for restricted binaries.

```bash
csrutil status                      # check SIP state

# Requires booting to Recovery (hold power on Apple Silicon; Cmd+R on Intel):
csrutil disable
csrutil enable
csrutil enable --without kext       # allow unsigned kexts only
csrutil authenticated-root disable  # disable SSV seal (separate from SIP)
```

**Reduced Security (Apple Silicon):** System Settings > Privacy & Security > Security allows enabling kext support. `bputil -g` (in Recovery) shows the current boot policy.

---

## 6. Frameworks and APIs

| Framework | Purpose |
|-----------|---------|
| Foundation | Collections, strings, networking, JSON, dates, KVO |
| AppKit | macOS UI: NSView, NSWindow, NSApplication |
| SwiftUI | Declarative cross-platform UI |
| Core Data | Object graph persistence backed by SQLite |
| Core ML | ML inference targeting CPU, GPU, or Neural Engine |
| Metal | Low-level GPU compute and rendering API |
| Security | Keychain, code signing, certificates, SecItem API |
| Endpoint Security | User-space EDR events (AUTH + NOTIFY) |
| SystemExtension | Install/activate System Extensions from within an app |

Endpoint Security requires `com.apple.developer.endpoint-security.client` entitlement and explicit Apple approval.

---

## 7. Application Model

### .app Bundle Structure

```
MyApp.app/Contents/
  Info.plist            -- CFBundleIdentifier, version, entitlements
  MacOS/MyApp           -- Mach-O executable (universal or arch-specific)
  Resources/            -- assets, localization (.lproj)
  Frameworks/           -- embedded frameworks
  _CodeSignature/       -- signature manifest
```

### Code Signing and Notarization

```bash
codesign --sign "Developer ID Application: Name (TEAMID)" MyApp.app
codesign --verify --verbose MyApp.app
codesign -dv --verbose=4 MyApp.app
codesign -dv --entitlements :- MyApp.app

# Notarization
xcrun notarytool submit MyApp.zip \
    --apple-id user@example.com \
    --password "@keychain:APP_SPECIFIC_PWD" \
    --team-id TEAMID --wait
xcrun stapler staple MyApp.app
```

### Gatekeeper, XProtect, MRT

**Gatekeeper:** Checks code signature, notarization, and quarantine xattr on first launch.
```bash
xattr -l /Applications/MyApp.app
xattr -d com.apple.quarantine /Applications/MyApp.app
spctl --assess --verbose /Applications/MyApp.app
```

**XProtect:** Signature-based malware scanner at `/Library/Apple/System/Library/CoreServices/XProtect.bundle/`.

**App Sandbox:** Sandboxed apps confined to `~/Library/Containers/<BundleID>/`. Access to Camera, Microphone, Files declared via entitlements.

---

## 8. User and Permission Model

### Users, Groups, and dscl

```bash
id                                      # uid/gid/groups
dscl . list /Users                      # all local users
dscl . -read /Users/chris               # full user record
dscl . -merge /Groups/admin GroupMembership newuser  # grant sudo
dscacheutil -flushcache                 # flush Directory Services cache
```

**admin group:** Membership grants `sudo` rights; password prompt still required.

### Keychain Architecture

| Keychain | Path | Scope |
|----------|------|-------|
| Login | `~/Library/Keychains/login.keychain-db` | Per-user; unlocks at login |
| System | `/Library/Keychains/System.keychain` | Machine-wide |
| iCloud | Cloud-synced | Cross-device; Secure Enclave protected |

```bash
security list-keychains
security find-generic-password -s "MyService"
security add-generic-password -s "MyService" -a "user" -w "pass"
```

---

## 9. Network Architecture

### networksetup and scutil

```bash
networksetup -listallnetworkservices
networksetup -getinfo "Wi-Fi"
networksetup -setdnsservers "Wi-Fi" 8.8.8.8 8.8.4.4
networksetup -listnetworkserviceorder
networksetup -listlocations
networksetup -switchtolocation "Office"

scutil --get ComputerName
scutil --set ComputerName "MacBook-Pro"
scutil --dns                           # DNS resolver config
scutil --proxy                         # proxy settings
scutil --nwi                           # network interface info
scutil --nc list                       # VPN connections
```

`configd` maintains the System Configuration dynamic store. `/etc/resolv.conf` is auto-generated -- never edit manually.

### mDNSResponder (Bonjour)

```bash
dns-sd -B _http._tcp local.           # browse HTTP services
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder  # flush DNS
```

### VPN and Network Extension

Built-in protocols: IKEv2, L2TP/IPSec, Cisco IPSec. Custom VPN uses the `NetworkExtension` framework running as a System Extension.

---

## 10. Shell Environment

### Default Shell: zsh

zsh became the default in macOS 10.15 Catalina. `/bin/bash` is version 3.2 (GPLv2; Apple cannot ship GPLv3 bash).

### Startup File Order

| Mode | Files sourced (in order) |
|------|--------------------------|
| Login shell | `/etc/zprofile` > `~/.zprofile` > `~/.zshrc` > `~/.zlogin` |
| Interactive non-login | `~/.zshrc` only |
| All modes | `/etc/zshenv` > `~/.zshenv` (always first) |

Terminal.app and iTerm2 both open login shells by default -- unlike most Linux terminal emulators.

### PATH Management

```bash
cat /etc/paths                        # base entries
ls /etc/paths.d/                      # drop-in additions
/usr/libexec/path_helper -s           # generates PATH

# Apple Silicon Homebrew (add to ~/.zprofile)
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### arch Command

```bash
arch                                  # arm64 or i386
arch -arm64 command                   # native Apple Silicon
arch -x86_64 command                  # via Rosetta 2
```

---

## Quick Reference: Key macOS Commands

```bash
# System info
sw_vers                              # macOS version and build
system_profiler SPSoftwareDataType
sysctl -a | grep hw                  # hardware parameters

# Disk / APFS
diskutil list
diskutil apfs list
diskutil info disk1s1

# Processes and services
launchctl list
launchctl print system/<label>
sudo lsof -i :8080

# Code signing / security
codesign -dv --verbose=4 /Applications/App.app
spctl --assess -v /Applications/App.app
csrutil status

# Network
networksetup -listallnetworkservices
scutil --dns
dns-sd -B _services._dns-sd._udp local.

# Users / directory
dscl . list /Users
security list-keychains
```

---

*Coverage: macOS 14 Sonoma, 15 Sequoia, 26 Tahoe. Core kernel and framework behavior is consistent across these versions; version-specific differences noted in version agents.*
