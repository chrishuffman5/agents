# WSL (Windows Subsystem for Linux) — Research Notes

**Scope:** WSL1 and WSL2 on Windows 10/11. Architecture, networking, GPU, GUI, systemd, configuration, distro management, memory, dev workflows, enterprise deployment, and diagnostic scripts.

---

## 1. WSL1 vs WSL2 Architecture

### WSL1 — Syscall Translation

WSL1 (introduced 2016, Windows 10 Anniversary Update) operates entirely in user space with a kernel-mode translation layer. There is no Linux kernel. Instead, two kernel drivers implement the translation:

- **lxss.sys** — manages Linux instances (namespaces, PIDs, file descriptors)
- **lxcore.sys** — translates Linux syscalls into NT equivalents

When a Linux binary calls `read()`, `write()`, `fork()`, etc., lxcore.sys intercepts and maps each to the nearest Windows NT operation. Coverage is high but not complete — syscalls with no NT equivalent fail or behave differently (e.g., `epoll`, raw sockets, 32-bit binaries have historically had issues).

**WSL1 characteristics:**
- No hypervisor; runs directly on the Windows kernel
- ELF binaries execute natively (no emulation)
- Linux filesystem emulated via a VolFS driver (maps Linux paths onto NTFS)
- Cross-filesystem I/O (accessing Windows drives at `/mnt/c`) is fast — no VM boundary
- File permission model emulated; Windows ACLs used under the hood
- Does not support `kvm`, `bpf` (full), Docker daemon, or certain ioctl operations

### WSL2 — Lightweight Utility VM

WSL2 (introduced 2004/20H1, May 2020) runs a genuine Linux kernel inside a lightweight Hyper-V virtual machine called a **utility VM**. Each WSL2 distro shares a single VM instance by default (though they have isolated rootfs).

**Kernel:** Microsoft maintains a fork of the Linux kernel, updated via Windows Update (or manually). As of 2025, tracks the LTS series. Source open (github.com/microsoft/WSL2-Linux-Kernel).

**Storage:** Each distro's rootfs lives in an **ext4 virtual hard disk** (`ext4.vhdx`), typically at:
```
%LOCALAPPDATA%\Packages\<distro-package-name>\LocalState\ext4.vhdx
```
Or for non-Store distros imported via `wsl --import`:
```
<user-specified-path>\ext4.vhdx
```

**WSL2 characteristics:**
- Full Linux kernel — near-100% syscall compatibility
- Supports Docker daemon, `kvm` (nested virt, where host supports it), `ebpf`, io_uring
- Real `/proc`, `/sys`, cgroups v2
- Linux-native I/O is significantly faster (ext4 on VHD vs VolFS emulation)
- Cross-filesystem I/O slower (9P protocol crosses VM boundary)
- Memory is dynamic (VM balloon driver); visible to Task Manager as **Vmmem** process

### Performance Tradeoff Summary

| Scenario | WSL1 | WSL2 |
|---|---|---|
| `git status` on `/mnt/c/repo` | Fast | Slow (9P) |
| Compiling Linux project in `~/` | Moderate | Fast (ext4) |
| Docker daemon | Not supported | Supported |
| Full syscall compat | ~80% | ~100% |
| Boot time | Instant | ~1–2 seconds |

**Rule of thumb:** Keep project files inside the WSL2 filesystem (`~/project`, not `/mnt/c/Users/...`) for build-intensive workloads.

---

## 2. Filesystem Architecture

### WSL2 Virtual Disk

The `ext4.vhdx` grows automatically up to the configured limit (default 1 TB). It does **not** automatically shrink when files are deleted — the ext4 layer frees blocks but the VHD file on NTFS retains size. To reclaim:

```powershell
# Compact VHD (run while distro is shut down)
wsl --shutdown
Optimize-VHD -Path "$env:LOCALAPPDATA\Packages\<distro>\LocalState\ext4.vhdx" -Mode Full
```

Or using diskpart:
```
diskpart
select vdisk file="<path>\ext4.vhdx"
attach vdisk readonly
compact vdisk
detach vdisk
exit
```

### Cross-Filesystem Access

**Windows → Linux:**
```
\\wsl$\<distro-name>\home\user\project
\\wsl.localhost\<distro-name>\    # newer alias
```
Access via File Explorer or any UNC-capable app. Uses the 9P server running inside WSL2.

**Linux → Windows:**
```bash
/mnt/c/       # C: drive
/mnt/d/       # D: drive
```
DrvFs mounts, configured in `/etc/wsl.conf`. Metadata option preserves Linux permissions on NTFS.

```ini
# /etc/wsl.conf — enable metadata for proper permissions
[automount]
options = "metadata,umask=22,fmask=11"
```

### 9P Protocol

WSL2 uses the **9P2000.L** protocol (a Plan 9 filesystem protocol) for cross-filesystem communication. The Linux kernel acts as a 9P client; a host-side server serves Windows filesystem access. This means every file operation crossing the boundary incurs:
- A context switch from the VM
- A 9P message encoded/decoded
- NTFS operation on the host

For projects with thousands of small files (Node.js `node_modules`, Python virtualenvs, Rust target dirs), this overhead compounds significantly. Always place active project files inside the WSL filesystem.

---

## 3. Networking

### NAT Mode (Default)

WSL2 VM gets a private IP on a virtual network adapter (`vEthernet (WSL)`). The host performs NAT. The WSL IP changes on every `wsl --shutdown` + restart.

```bash
# Get WSL IP from inside Linux
ip addr show eth0 | grep 'inet '

# Get WSL IP from Windows PowerShell
(Get-NetAdapter -Name "vEthernet (WSL)").ifIndex | Get-NetIPAddress
# or:
wsl -- ip route | Select-String "default"
```

**Port forwarding from Windows to WSL:**
```powershell
# Add rule: forward Windows port 8080 to WSL port 8080
$wslIp = (wsl -- ip addr show eth0 | Select-String '(\d+\.\d+\.\d+\.\d+)/').Matches[0].Groups[1].Value
netsh interface portproxy add v4tov4 listenport=8080 listenaddress=0.0.0.0 connectport=8080 connectaddress=$wslIp
```

**Localhost forwarding:** By default in recent WSL2 versions, `localhost` from Windows reaches services bound to `0.0.0.0` or `127.0.0.1` inside WSL. This is handled by the WSL host service automatically.

### Mirrored Networking Mode (Windows 11 22H2+)

Set in `~/.wslconfig`:
```ini
[wsl2]
networkingMode=mirrored
```

In mirrored mode:
- WSL sees the same network interfaces as Windows
- WSL IP matches host IP — no separate subnet
- `localhost` from WSL reaches Windows services and vice versa reliably
- IPv6 works correctly
- Reduces VPN compatibility issues (WSL VM appears on the same network as host)
- DNS resolution uses host's DNS directly

**DNS Tunneling** (Win11, complements mirrored mode):
```ini
[wsl2]
dnsTunneling=true
```
Routes WSL DNS queries through the Windows DNS client stack, respecting enterprise DNS policies and split-horizon DNS.

**Auto-Proxy** (Win11):
```ini
[wsl2]
autoProxy=true
```
Automatically applies Windows proxy settings to WSL environment variables (`http_proxy`, `https_proxy`).

### DNS Configuration

By default, WSL2 auto-generates `/etc/resolv.conf` pointing to a DNS relay at `172.x.x.1` (the WSL NAT gateway). To use custom DNS:

```ini
# /etc/wsl.conf — disable auto-generation
[network]
generateResolvConf = false
```

Then manually create `/etc/resolv.conf`:
```
nameserver 1.1.1.1
nameserver 8.8.8.8
```

### VPN Compatibility

VPN clients that modify the host routing table or DNS can break WSL2 NAT networking. Common symptoms: no internet from WSL2, DNS failures. Mitigations:
- Use mirrored networking mode (Win11 22H2+)
- Enable `dnsTunneling=true`
- Use `wsl --shutdown` + restart after VPN connects
- Some VPN clients have WSL2-specific fixes (Cisco AnyConnect requires registry workaround; Mullvad and WireGuard work better with mirrored mode)

### Firewall Interaction

Windows Defender Firewall rules apply to the WSL virtual adapter. In mirrored mode, rules for the physical adapter also affect WSL. The `firewall=true` setting (default in recent builds) enables Hyper-V firewall for WSL2.

---

## 4. GPU and Hardware Passthrough

### GPU-PV (GPU Paravirtualization)

WSL2 supports GPU acceleration via **GPU-PV** — a Hyper-V mechanism where the guest VM shares the host GPU through a paravirtualized driver. No GPU is passed through directly; instead, a kernel-mode driver in WSL2 (`dxgkrnl`) communicates with the Windows GPU driver via the hypervisor.

**Supported workloads:**
- CUDA (NVIDIA) — install `cuda-toolkit` inside WSL2; use host NVIDIA driver (no separate driver inside WSL)
- DirectML (AMD, Intel, NVIDIA) — for Windows ML workloads via D3D12
- OpenGL / OpenCL — via Mesa/D3D12 translation layer (DXVK/VirGL not needed)
- Vulkan — supported via WSL Vulkan ICD

**NVIDIA setup in WSL2:**
```bash
# No nvidia-driver install inside WSL — use host driver
# Install CUDA toolkit for WSL:
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update && sudo apt install cuda-toolkit

# Verify:
nvidia-smi    # Shows GPU info from host driver
nvcc --version
```

**Limitations:**
- Only one GPU instance visible inside WSL (the primary display adapter)
- Multi-GPU not natively supported via GPU-PV
- Real-time display output (video rendering) not intended use case — use WSLg for GUI
- Driver version requirements: NVIDIA driver ≥ 470.76

### USB Device Passthrough (usbipd-win)

Physical USB devices can be attached to WSL2 using **usbipd-win** (USB/IP protocol):

```powershell
# Install on Windows:
winget install usbipd

# List USB devices:
usbipd list

# Attach device to WSL (run as admin):
usbipd attach --wsl --busid 1-7

# Inside WSL:
lsusb
dmesg | tail
```

Use cases: USB serial devices, microcontrollers (Arduino), smartcards, USB cameras.

---

## 5. WSLg — GUI Applications

WSLg (WSL GUI) enables running Linux graphical applications on Windows with no additional configuration. Available since Windows 11 (built-in) and Windows 10 21H2 (via KB update, Insider initially).

### Architecture

WSLg runs a **Wayland compositor** (`weston`) inside the WSL utility VM. It acts as a Wayland server for Linux GUI apps and as a Wayland client to a **RDP virtual desktop** on the Windows side, which renders to a Windows window.

Components:
- **Weston** — the in-VM Wayland compositor
- **XWayland** — X11 compatibility server (forwards X11 apps through Wayland)
- **PulseAudio** — audio server inside VM, streams to Windows audio (RDP audio)
- **FreeRDP / mstsc** — renders the remote desktop session into the Windows desktop seamlessly (no visible RDP window)

**DISPLAY and WAYLAND_DISPLAY** are set automatically:
```bash
echo $DISPLAY         # :0  (XWayland)
echo $WAYLAND_DISPLAY # wayland-0
```

### Running GUI Apps

```bash
# Install and run a GUI app — no xming or VcXsrv needed:
sudo apt install gedit
gedit &

sudo apt install x11-apps
xeyes &

# Electron apps, VS Code inside WSL, etc.
sudo snap install code --classic
code .
```

### Clipboard Integration

Clipboard is automatically shared between Windows and WSL GUI apps. Ctrl+C/Ctrl+V works across the boundary.

### GPU-Accelerated Rendering

WSLg uses D3D12/GPU-PV for hardware-accelerated compositing when available, providing smooth GUI app rendering. Falls back to software rendering if GPU-PV unavailable.

---

## 6. systemd Support

WSL2 gained native systemd support in September 2022 (WSL 0.67.6+).

### Enabling systemd

```ini
# /etc/wsl.conf (inside the distro)
[boot]
systemd=true
```

Restart the distro:
```powershell
wsl --shutdown
wsl
```

Verify:
```bash
systemctl --version
systemctl list-units --type=service --state=running
```

### Implications

With systemd enabled:
- Services start at distro boot (`wsl` invocation): nginx, postgresql, docker, ssh
- `snap` packages work (snapd requires systemd)
- `systemctl enable <service>` works for persistence
- `journalctl` available for log management
- Login sessions go through PAM properly

**Docker without systemd:**
```bash
# Without systemd, start manually:
sudo service docker start
# Or use Docker Desktop WSL2 backend instead
```

**Docker with systemd:**
```bash
sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker
```

**Boot command alternative** (without full systemd):
```ini
[boot]
command = "service docker start; service postgresql start"
```

---

## 7. Configuration Files

### ~/.wslconfig — Global (Windows-side)

Applies to all WSL2 distros. Located at `C:\Users\<username>\.wslconfig`. Requires `wsl --shutdown` to take effect.

```ini
[wsl2]
# Resource limits
memory=8GB
processors=4
swap=2GB
swapFile=C:\\temp\\wsl-swap.vhdx

# Networking
networkingMode=mirrored       # or nat (default)
dnsTunneling=true
firewall=true
autoProxy=true

# Disk
defaultVhdSize=50GB           # Initial VHD size cap for new distros

# Features
guiApplications=true          # WSLg
nestedVirtualization=true
debugConsole=false

# Kernel
# kernel=C:\\path\\to\\custom\\bzImage
# kernelCommandLine=systemd.unified_cgroup_hierarchy=1
```

**Memory reclaim** (default enabled in recent builds):
```ini
[experimental]
autoMemoryReclaim=gradual     # or dropcache, disabled
sparseVhd=true                # VHD sparse file (auto-shrinks on host)
```

### /etc/wsl.conf — Per-Distro (Linux-side)

Located inside each distro. Takes effect on next distro start (not full shutdown required for all settings).

```ini
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateHosts = true
generateResolvConf = true     # set false for custom DNS
hostname = my-wsl-machine

[interop]
enabled = true                # Allow launching Windows executables from Linux
appendWindowsPath = true      # Add Windows PATH entries to Linux PATH

[boot]
systemd = true
command = ""                  # Shell command run as root on distro start

[user]
default = myusername          # Default login user
```

---

## 8. Distro Management

### Installing Distros

```powershell
# List available distros from Microsoft Store:
wsl --list --online

# Install a distro:
wsl --install -d Ubuntu-24.04
wsl --install -d Debian
wsl --install -d kali-linux

# Install without Store (download from web):
wsl --install -d Ubuntu --web-download

# First launch sets up user account interactively
```

### Listing and Status

```powershell
# List installed distros with WSL version (1 or 2) and state:
wsl --list --verbose
# wsl -l -v

# Example output:
#   NAME            STATE           VERSION
# * Ubuntu-24.04   Running         2
#   Debian          Stopped         2
#   Ubuntu-20.04   Stopped         1
```

### Managing Versions

```powershell
# Convert a distro from WSL1 to WSL2:
wsl --set-version Ubuntu-20.04 2

# Set default WSL version for new installs:
wsl --set-default-version 2

# Set default distro:
wsl --set-default Ubuntu-24.04
```

### Import / Export

```powershell
# Export a distro to a tarball:
wsl --export Ubuntu-24.04 C:\backups\ubuntu-24-04.tar

# Import from tarball (creates new distro):
wsl --import MyUbuntu C:\WSL\MyUbuntu C:\backups\ubuntu-24-04.tar --version 2

# Import as VHD directly (Windows 11):
wsl --import-in-place MyDistro C:\WSL\MyDistro\ext4.vhdx
```

### Unregistering

```powershell
# Unregister (DELETES all data in distro):
wsl --unregister Ubuntu-20.04
```

### Running Commands

```powershell
# Run command in default distro:
wsl ls -la ~/

# Run in specific distro as specific user:
wsl -d Debian -u root apt update

# Shutdown all distros:
wsl --shutdown

# Terminate specific distro:
wsl --terminate Ubuntu-24.04
```

---

## 9. Memory Management

### WSL2 VM Memory Behavior

WSL2 memory is dynamic — the VM balloons up as Linux processes allocate memory and theoretically shrinks when freed. The host sees this as the **Vmmem** process in Task Manager.

**Historical issue:** Early WSL2 builds aggressively cached file pages, causing Vmmem to grow to the configured `memory=` limit and not release to Windows. This was significantly improved in 2023–2024 builds.

### Configuration

```ini
# ~/.wslconfig
[wsl2]
memory=8GB          # Hard cap — VM cannot exceed this

[experimental]
autoMemoryReclaim=gradual   # Reclaim unused memory gradually
# autoMemoryReclaim=dropcache # Aggressively drop page cache
# autoMemoryReclaim=disabled  # Original behavior
```

### Manual Memory Reclaim

```bash
# Inside WSL — drop page cache manually:
sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

# Or via sysctl:
sudo sysctl vm.drop_caches=3
```

### Swap

WSL2 allocates swap on a separate VHD (default: 25% of `memory=` limit, at `%LOCALAPPDATA%\Packages\...\LocalState\swap.vhdx`).

```ini
[wsl2]
swap=4GB
swapFile=C:\\wsl-swap\\swap.vhdx  # Custom location
```

Disable swap:
```ini
swap=0
```

### Sparse VHD

```ini
[experimental]
sparseVhd=true
```
When enabled, the VHD files are created as sparse files — the NTFS-level size shrinks automatically as ext4 blocks are freed (no manual `Optimize-VHD` needed). Available in recent WSL builds (2023+).

---

## 10. Development Workflows

### VS Code Remote WSL

The **Remote - WSL** extension (now part of Remote Development pack) connects VS Code on Windows to the WSL filesystem:

```bash
# From inside WSL terminal:
code .          # Opens VS Code connected to current WSL directory

# VS Code runs its server inside WSL
# Extensions run inside WSL (access Linux tools, compilers, etc.)
# Terminal in VS Code is a WSL terminal
```

**Performance note:** With WSLg, VS Code can also run natively inside WSL as a Linux app. For most users, Remote WSL is preferred.

### Docker Desktop WSL2 Backend

Docker Desktop uses WSL2 as its engine (replaces the older Hyper-V VM approach):

- Docker daemon runs inside a special `docker-desktop` distro
- Your distro gets access via a mounted socket
- `docker` CLI in your distro communicates with the Docker Desktop daemon
- Enables sharing Docker context between Windows and WSL

```bash
# Verify Docker is accessible from WSL:
docker info
docker run --rm hello-world
```

Alternative: Install Docker Engine directly in WSL with systemd enabled (no Docker Desktop required).

### Git Considerations

**Key issue:** Git on Windows and Git in WSL track the same files differently (line endings, file permissions, executable bits).

```bash
# Recommended: keep repos inside WSL filesystem
cd ~/projects
git clone https://github.com/user/repo

# If repo must be on Windows filesystem:
git config core.autocrlf input   # Inside WSL
git config core.filemode false   # Ignore permission changes
```

**Credential sharing:** Git Credential Manager (GCM) installed on Windows can be used from WSL:
```bash
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
```

### Cross-Compilation

WSL2 provides a full Linux toolchain for cross-compiling Linux binaries from a Windows development environment:

```bash
# Install cross-compilation toolchains:
sudo apt install gcc-aarch64-linux-gnu
aarch64-linux-gnu-gcc -o myapp-arm64 main.c

# Build Windows EXE from Linux (MinGW):
sudo apt install mingw-w64
x86_64-w64-mingw32-gcc -o myapp.exe main.c
```

### Dev Containers

VS Code Dev Containers work natively with WSL2 — the container runs inside WSL's Docker, the VS Code server attaches via Remote WSL + Docker extension chain.

---

## 11. Enterprise Deployment

### Group Policy / Intune

WSL2 can be managed via MDM/Intune policies (ADMX templates available from Microsoft):

- **Allow WSL** — enable/disable WSL entirely
- **Allow WSL1** — prevent fallback to WSL1
- **Allowed distros** — whitelist specific distros by name
- **Allow custom kernel** — control kernel override capability
- **Allow kernel debugging** — restrict debug access

Group Policy path (with ADMX loaded):
```
Computer Configuration > Administrative Templates > Windows Components > Windows Subsystem for Linux
```

### WSL Kernel Updates

By default, WSL kernel updates via Windows Update. In managed environments:
```ini
# ~/.wslconfig — use custom/approved kernel:
[wsl2]
kernel=C:\\IT\\WSL\\approved-kernel\\bzImage
```

### Security Considerations

- **Data Loss Prevention:** Files inside WSL filesystem (`ext4.vhdx`) are not scanned by most DLP tools by default. Sensitive data in WSL may bypass endpoint DLP policies.
- **Network isolation:** NAT mode provides some isolation; mirrored mode exposes WSL to the same network as host.
- **Antivirus:** Windows Defender scans `/mnt/` paths but not the WSL native filesystem directly. Real-time protection inside WSL requires a Linux AV agent.
- **Credential exposure:** SSH keys, tokens stored in WSL are accessible to any process running in that distro.

### Offline / Air-Gapped Install

```powershell
# Download distro as appx package manually:
Invoke-WebRequest -Uri https://aka.ms/wslubuntu2204 -OutFile ubuntu2204.appx
Add-AppxPackage ubuntu2204.appx

# Or import from tarball (no Store required):
wsl --import UbuntuOffline C:\WSL\UbuntuOffline C:\offline\ubuntu-rootfs.tar --version 2
```

### Version History Reference

| Windows Version | Key WSL Milestone |
|---|---|
| 1607 (Anniversary) | WSL1 introduced |
| 1903/1909 | WSL2 preview |
| 2004 (20H1) | WSL2 GA, `wsl --install` |
| 21H2 | WSLg preview for Win10 |
| Win11 21H2 | WSLg built-in |
| Win11 22H2 | Mirrored networking, systemd |
| 2023 | Memory reclaim improvements, sparseVhd |
| 2024 | DNS tunneling, auto-proxy, firewall improvements |
| May 2025 | WSL goes fully open-source |

---

## 12. Diagnostic Scripts

### Script 01 — WSL Health Check

```powershell
<#
.SYNOPSIS
    WSL - Health and Status Assessment
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11 with WSL installed
    Safety  : Read-only. No modifications to system configuration.
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

function Write-Item {
    param([string]$Label, [string]$Value, [string]$Color = 'White')
    Write-Host ("  {0,-35} {1}" -f "${Label}:", $Value) -ForegroundColor $Color
}

# ─── Windows Feature Status ───────────────────────────────────────────────────
Write-Section "Windows Features"

$features = @(
    'Microsoft-Windows-Subsystem-Linux',
    'VirtualMachinePlatform',
    'HypervisorPlatform'
)

foreach ($feature in $features) {
    $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue).State
    $color = if ($state -eq 'Enabled') { 'Green' } else { 'Red' }
    Write-Item $feature ($state ?? 'Not found') $color
}

# ─── WSL Version ──────────────────────────────────────────────────────────────
Write-Section "WSL Version Information"

$wslVersion = wsl --version 2>&1
if ($LASTEXITCODE -eq 0 -or $wslVersion) {
    $wslVersion | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "  WSL not installed or --version not supported" -ForegroundColor Red
}

# ─── Installed Distros ────────────────────────────────────────────────────────
Write-Section "Installed Distributions"

$distroList = wsl --list --verbose 2>&1
if ($LASTEXITCODE -eq 0 -or $distroList -match 'NAME') {
    $distroList | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No distros found or WSL not available" -ForegroundColor Yellow
}

# ─── Default Distro ──────────────────────────────────────────────────────────
Write-Section "Default Distribution"

$defaultDistro = (wsl --list 2>&1 | Select-String '\(Default\)').ToString().Trim()
if ($defaultDistro) {
    Write-Item "Default distro" ($defaultDistro -replace '\(Default\)', '').Trim()
} else {
    Write-Host "  Unable to determine default distro" -ForegroundColor Yellow
}

# ─── Linux Kernel Version ────────────────────────────────────────────────────
Write-Section "Linux Kernel"

$kernelVersion = wsl -- uname -r 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "Kernel version" $kernelVersion 'Green'
} else {
    Write-Host "  Could not retrieve kernel version (no running distro?)" -ForegroundColor Yellow
}

# ─── WSLg Status ─────────────────────────────────────────────────────────────
Write-Section "WSLg (GUI Apps) Status"

$wslgCheck = wsl -- ls /mnt/wslg 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "WSLg" "Available" 'Green'
    $wayland = wsl -- sh -c 'echo $WAYLAND_DISPLAY' 2>&1
    Write-Item "WAYLAND_DISPLAY" ($wayland ?? '(not set)')
    $display = wsl -- sh -c 'echo $DISPLAY' 2>&1
    Write-Item "DISPLAY" ($display ?? '(not set)')
} else {
    Write-Item "WSLg" "Not available or not enabled" 'Yellow'
}

# ─── systemd Status per Distro ───────────────────────────────────────────────
Write-Section "systemd Status per Distribution"

$distros = wsl --list --quiet 2>&1 | Where-Object { $_ -match '\S' -and $_ -notmatch '^Windows' }
foreach ($distro in $distros) {
    $distroName = $distro.Trim() -replace '\(Default\)', '' -replace '\s+', ''
    if (-not $distroName) { continue }

    $systemdPid1 = wsl -d $distroName -- sh -c 'cat /proc/1/comm 2>/dev/null' 2>&1
    $systemdStatus = if ($systemdPid1 -match 'systemd') { 'Enabled (PID1=systemd)' } else { "Not enabled (PID1=$systemdPid1)" }
    $color = if ($systemdPid1 -match 'systemd') { 'Green' } else { 'Gray' }
    Write-Item "  $distroName" $systemdStatus $color
}

# ─── VHD Sizes ───────────────────────────────────────────────────────────────
Write-Section "Virtual Hard Disk Sizes"

$vhdPaths = @(
    "$env:LOCALAPPDATA\Packages",
    "$env:USERPROFILE"
)

$vhds = Get-ChildItem -Path $vhdPaths -Recurse -Filter 'ext4.vhdx' -ErrorAction SilentlyContinue
if ($vhds) {
    foreach ($vhd in $vhds) {
        $sizeGB = [math]::Round($vhd.Length / 1GB, 2)
        $parent = $vhd.DirectoryName -replace [regex]::Escape($env:LOCALAPPDATA), '%LOCALAPPDATA%'
        Write-Item ($vhd.Name) ("{0} GB — {1}" -f $sizeGB, $parent)
    }
} else {
    Write-Host "  No ext4.vhdx files found in standard locations" -ForegroundColor Yellow
    Write-Host "  (Custom import locations will not be scanned)" -ForegroundColor Gray
}

# ─── .wslconfig Summary ──────────────────────────────────────────────────────
Write-Section ".wslconfig Configuration"

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
if (Test-Path $wslConfigPath) {
    Write-Item ".wslconfig" "Found at $wslConfigPath" 'Green'
    Get-Content $wslConfigPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
} else {
    Write-Item ".wslconfig" "Not present (defaults in use)" 'Yellow'
}

Write-Host "`nHealth check complete.`n" -ForegroundColor Cyan
```

---

### Script 02 — WSL Network Diagnostics

```powershell
<#
.SYNOPSIS
    WSL - Network Configuration and Connectivity Diagnostics
.NOTES
    Version : 1.0.0
    Targets : Windows 10/11 with WSL installed
    Safety  : Read-only. No modifications to system configuration.
#>

#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

function Write-Item {
    param([string]$Label, [string]$Value, [string]$Color = 'White')
    Write-Host ("  {0,-38} {1}" -f "${Label}:", $Value) -ForegroundColor $Color
}

# ─── Networking Mode ──────────────────────────────────────────────────────────
Write-Section "WSL Networking Mode"

$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$networkingMode = 'nat (default — not explicitly configured)'

if (Test-Path $wslConfigPath) {
    $configContent = Get-Content $wslConfigPath -Raw
    if ($configContent -match 'networkingMode\s*=\s*(\S+)') {
        $networkingMode = $Matches[1]
    }
}

$modeColor = if ($networkingMode -match 'mirrored') { 'Green' } else { 'White' }
Write-Item "Networking mode" $networkingMode $modeColor

# Check for mirrored mode indicators
$dnsTunneling = if ($configContent -match 'dnsTunneling\s*=\s*true') { 'true' } else { 'false (default)' }
$autoProxy    = if ($configContent -match 'autoProxy\s*=\s*true')    { 'true' } else { 'false (default)' }
Write-Item "DNS tunneling" $dnsTunneling
Write-Item "Auto proxy" $autoProxy

# ─── WSL Network Adapters ────────────────────────────────────────────────────
Write-Section "WSL Network Adapters (Windows Side)"

$wslAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'WSL|Hyper-V Virtual' }
if ($wslAdapters) {
    foreach ($adapter in $wslAdapters) {
        Write-Item $adapter.Name ("{0} — {1}" -f $adapter.Status, $adapter.InterfaceDescription)
        $ip = ($adapter | Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress
        if ($ip) { Write-Item "  IP Address" $ip }
    }
} else {
    Write-Host "  No WSL/Hyper-V virtual adapters found" -ForegroundColor Yellow
}

# ─── WSL IP (from inside WSL) ────────────────────────────────────────────────
Write-Section "WSL Internal IP Address"

$wslIpRaw = wsl -- ip addr show eth0 2>&1
if ($LASTEXITCODE -eq 0 -and $wslIpRaw -match '(\d+\.\d+\.\d+\.\d+)/') {
    $wslIp = $Matches[1]
    Write-Item "WSL eth0 IP" $wslIp 'Green'
} else {
    $wslIp = $null
    Write-Host "  Could not retrieve WSL IP (no running distro or eth0 not found)" -ForegroundColor Yellow
}

# In mirrored mode, WSL may use same IP as host
$hostIps = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch 'Loopback|WSL|vEthernet' }).IPAddress
Write-Item "Windows host IPs" ($hostIps -join ', ')

# ─── DNS Configuration per Distro ────────────────────────────────────────────
Write-Section "DNS Configuration (resolv.conf per Distro)"

$distros = wsl --list --quiet 2>&1 | Where-Object { $_ -match '\S' }
foreach ($distro in $distros) {
    $distroName = $distro.Trim() -replace '\(Default\)', '' -replace '\s+', ''
    if (-not $distroName) { continue }

    Write-Host "`n  [$distroName]" -ForegroundColor Yellow
    $resolv = wsl -d $distroName -- cat /etc/resolv.conf 2>&1
    if ($LASTEXITCODE -eq 0) {
        $resolv | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    } else {
        Write-Host "    Could not read resolv.conf" -ForegroundColor Red
    }

    $wslConf = wsl -d $distroName -- cat /etc/wsl.conf 2>&1
    if ($wslConf -match 'generateResolvConf\s*=\s*false') {
        Write-Host "    [network] generateResolvConf = false (custom DNS)" -ForegroundColor Cyan
    }
}

# ─── Port Forwarding Rules ────────────────────────────────────────────────────
Write-Section "Portproxy Rules (netsh interface portproxy)"

$portProxyRules = netsh interface portproxy show all 2>&1
if ($portProxyRules -match 'Listen on') {
    $portProxyRules | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host "  No portproxy rules configured" -ForegroundColor Gray
}

# ─── Windows Firewall — WSL Rules ────────────────────────────────────────────
Write-Section "Windows Firewall Rules Referencing WSL"

$wslFirewallRules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'WSL|wsl' -or $_.Description -match 'WSL|wsl' }

if ($wslFirewallRules) {
    foreach ($rule in $wslFirewallRules) {
        $color = if ($rule.Enabled -eq 'True') { 'White' } else { 'Gray' }
        Write-Host ("  [{0}] {1} — {2}" -f $rule.Direction, $rule.DisplayName, $rule.Action) -ForegroundColor $color
    }
} else {
    Write-Host "  No firewall rules explicitly named/described 'WSL'" -ForegroundColor Gray
}

# ─── Localhost Connectivity Test ─────────────────────────────────────────────
Write-Section "Localhost Connectivity Test"

Write-Host "  Starting a simple listener in WSL to test localhost forwarding..." -ForegroundColor Gray

# Check if nc is available in WSL
$ncAvailable = wsl -- which nc 2>&1
if ($LASTEXITCODE -eq 0) {
    # Start nc listener in background in WSL, test from Windows
    $job = Start-Job {
        wsl -- sh -c 'echo "WSL_OK" | nc -l -p 19876 -q 1' 2>&1
    }
    Start-Sleep -Milliseconds 800

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.ConnectAsync('127.0.0.1', 19876).Wait(1000) | Out-Null
        if ($tcp.Connected) {
            $stream = $tcp.GetStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $response = $reader.ReadLine()
            $tcp.Close()
            if ($response -match 'WSL_OK') {
                Write-Item "localhost:19876 → WSL" "REACHABLE" 'Green'
            } else {
                Write-Item "localhost:19876 → WSL" "Connected but unexpected response: $response" 'Yellow'
            }
        } else {
            Write-Item "localhost:19876 → WSL" "Connection failed" 'Red'
        }
    } catch {
        Write-Item "localhost:19876 → WSL" "Test failed: $_" 'Red'
    }
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -ErrorAction SilentlyContinue
} else {
    Write-Host "  nc (netcat) not available in default distro — skipping connectivity test" -ForegroundColor Yellow
    Write-Host "  Install with: sudo apt install netcat-openbsd" -ForegroundColor Gray
}

# ─── Internet Connectivity from WSL ──────────────────────────────────────────
Write-Section "Internet Connectivity from WSL"

$pingResult = wsl -- ping -c 2 -W 3 8.8.8.8 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Item "Ping 8.8.8.8 from WSL" "SUCCESS" 'Green'
} else {
    Write-Item "Ping 8.8.8.8 from WSL" "FAILED" 'Red'
    Write-Host "  $pingResult" -ForegroundColor Gray
}

$dnsResult = wsl -- sh -c 'nslookup microsoft.com 2>&1 | head -5' 2>&1
if ($dnsResult -match 'Address') {
    Write-Item "DNS resolution from WSL" "SUCCESS" 'Green'
} else {
    Write-Item "DNS resolution from WSL" "FAILED or inconclusive" 'Yellow'
}

# ─── VPN Detection ───────────────────────────────────────────────────────────
Write-Section "VPN Detection"

$vpnAdapters = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match 'VPN|Tunnel|TAP|WireGuard|OpenVPN|Cisco|Pulse|GlobalProtect|Zscaler|FortiClient'
}

if ($vpnAdapters) {
    Write-Host "  VPN adapter(s) detected — may affect WSL networking:" -ForegroundColor Yellow
    foreach ($vpn in $vpnAdapters) {
        Write-Host ("  [{0}] {1}" -f $vpn.Status, $vpn.InterfaceDescription) -ForegroundColor Yellow
    }
    Write-Host "`n  Recommendations:" -ForegroundColor Cyan
    Write-Host "    - Use networkingMode=mirrored in ~/.wslconfig (Win11 22H2+)" -ForegroundColor Gray
    Write-Host "    - Enable dnsTunneling=true in ~/.wslconfig" -ForegroundColor Gray
    Write-Host "    - Run 'wsl --shutdown' then relaunch WSL after connecting VPN" -ForegroundColor Gray
} else {
    Write-Item "VPN adapters" "None detected" 'Green'
}

Write-Host "`nNetwork diagnostics complete.`n" -ForegroundColor Cyan
```

---

## Reference: Common Commands

```powershell
# WSL management
wsl --install                         # Install WSL + Ubuntu (default)
wsl --install -d <Distro>             # Install specific distro
wsl --update                          # Update WSL package
wsl --version                         # WSL, kernel, WSLg versions
wsl --status                          # Default distro, version, kernel
wsl --list --verbose                  # All distros with state/version
wsl --shutdown                        # Stop all distros + VM
wsl --terminate <Distro>              # Stop one distro
wsl --set-default-version 2           # New distros default to WSL2
wsl --set-version <Distro> 2          # Convert distro to WSL2
wsl --export <Distro> <file.tar>      # Backup distro
wsl --import <Name> <dir> <file.tar>  # Restore/clone distro
wsl --unregister <Distro>             # Delete distro (destructive)
wsl --mount <disk>                    # Mount physical disk in WSL2
```

```bash
# Inside WSL — useful diagnostics
uname -r                              # Kernel version
cat /etc/wsl.conf                     # Per-distro config
cat /proc/version                     # Full kernel string
systemctl status                      # systemd health (if enabled)
df -h /                               # Disk usage of ext4 VHD
free -h                               # Memory usage
ip addr show eth0                     # WSL IP
cat /etc/resolv.conf                  # DNS config
```
