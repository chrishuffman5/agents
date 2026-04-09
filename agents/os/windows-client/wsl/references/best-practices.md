# WSL Best Practices Reference

## .wslconfig Configuration (Global)

Located at `C:\Users\<username>\.wslconfig`. Applies to all WSL2 distros. Requires `wsl --shutdown` to take effect after changes.

### Resource Limits

```ini
[wsl2]
memory=8GB          # Hard cap for VM (default: 50% of host RAM or 8 GB, whichever is less)
processors=4        # vCPU limit (default: all logical processors)
swap=2GB            # Swap file size (default: 25% of memory limit)
swapFile=C:\\temp\\wsl-swap.vhdx   # Custom swap location
```

Size `memory=` based on workload. For development (Node.js, Python, Go): 4-8 GB is typical. For ML/AI workloads: 16+ GB. For Docker-heavy workflows: account for container overhead.

### Networking

```ini
[wsl2]
networkingMode=mirrored    # Recommended for Win11 22H2+ (reduces VPN issues)
dnsTunneling=true          # Route DNS through Windows DNS client stack
autoProxy=true             # Inherit Windows proxy settings
firewall=true              # Enable Hyper-V firewall for WSL2
```

Use mirrored mode in enterprise environments where VPN and DNS split-horizon are common. NAT mode is acceptable for simple home/lab setups.

### Memory Reclaim

```ini
[experimental]
autoMemoryReclaim=gradual   # Reclaim unused memory over time
sparseVhd=true              # VHD auto-shrinks when ext4 blocks freed
```

`autoMemoryReclaim=gradual` is the recommended setting for most users. `dropcache` is more aggressive but may impact performance during cache-heavy workloads. Enable `sparseVhd=true` to avoid manual VHD compaction.

### Features

```ini
[wsl2]
guiApplications=true        # WSLg (default: true)
nestedVirtualization=true   # For Docker-in-Docker, KVM, etc.
defaultVhdSize=50GB         # Initial VHD size cap for new distros
```

## wsl.conf Configuration (Per-Distro)

Located at `/etc/wsl.conf` inside each distro. Takes effect on next distro start.

### Recommended Configuration

```ini
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateHosts = true
generateResolvConf = true    # Set false only for custom DNS
hostname = dev-wsl

[interop]
enabled = true               # Launch Windows executables from Linux
appendWindowsPath = true     # Add Windows PATH to Linux PATH

[boot]
systemd = true               # Enable systemd (recommended)

[user]
default = myusername
```

### When to Disable resolv.conf Generation

Set `generateResolvConf = false` when:
- Corporate DNS requires specific server addresses not provided by the WSL NAT gateway
- Using custom DNS-over-HTTPS resolvers
- WSL DNS consistently fails despite Windows DNS working

After disabling, create `/etc/resolv.conf` manually:
```
nameserver 1.1.1.1
nameserver 8.8.8.8
```

## Distro Management

### Import/Export Strategy

Regularly export critical distros as backups:
```powershell
wsl --export Ubuntu-24.04 C:\backups\ubuntu-24-04.tar
```

Use import to create clean development environments:
```powershell
wsl --import DevEnv C:\WSL\DevEnv C:\backups\ubuntu-base.tar --version 2
```

Use `--import-in-place` (Windows 11) for VHD-based workflows:
```powershell
wsl --import-in-place MyDistro C:\WSL\MyDistro\ext4.vhdx
```

### Version Management

Always use WSL2 for new distros:
```powershell
wsl --set-default-version 2
```

Convert legacy WSL1 distros:
```powershell
wsl --set-version <Distro> 2
```

WSL1 is only preferable when cross-filesystem I/O to `/mnt/c/` performance is critical and the workload does not need Docker, full syscall compatibility, or GPU access.

## Memory Management

### Preventing Vmmem Bloat

1. Set a memory cap in `.wslconfig`:
   ```ini
   [wsl2]
   memory=8GB
   ```

2. Enable automatic memory reclaim:
   ```ini
   [experimental]
   autoMemoryReclaim=gradual
   ```

3. Manual reclaim when needed:
   ```bash
   sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
   ```

4. Full shutdown releases all memory:
   ```powershell
   wsl --shutdown
   ```

### VHD Size Management

Enable sparse VHD for automatic shrinking:
```ini
[experimental]
sparseVhd=true
```

Manual compaction (requires distro shutdown):
```powershell
wsl --shutdown
Optimize-VHD -Path "$env:LOCALAPPDATA\Packages\<distro>\LocalState\ext4.vhdx" -Mode Full
```

## Development Workflows

### Project File Location

**Critical rule:** Keep all actively developed project files inside the WSL2 filesystem (`~/projects/`), not on `/mnt/c/`. The 9P protocol overhead for cross-filesystem access makes builds, git operations, and package installs dramatically slower.

```bash
# Good: project inside WSL filesystem
cd ~/projects && git clone https://github.com/user/repo

# Bad: project on Windows drive accessed from WSL
cd /mnt/c/Users/me/repos/repo    # Slow for builds and git
```

### VS Code Integration

Use VS Code Remote WSL extension:
```bash
cd ~/projects/myapp
code .    # Opens VS Code connected to WSL filesystem
```

Extensions and terminal run inside WSL. File operations are fast because VS Code's server runs inside WSL2 directly on ext4.

### Docker Best Practices

**Docker Desktop WSL2 backend** (recommended for most users):
- Docker daemon runs in a dedicated `docker-desktop` distro
- Your distro gets Docker CLI access via mounted socket
- Enable WSL integration in Docker Desktop settings per distro

**Docker Engine directly in WSL** (no Docker Desktop):
```bash
# Requires systemd=true in /etc/wsl.conf
sudo apt install docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

### Git Configuration

```bash
# Credential sharing with Windows Git Credential Manager
git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"

# Line ending handling
git config core.autocrlf input

# If forced to use /mnt/c/ paths
git config core.filemode false
```

### Cross-Compilation

WSL2 provides full Linux toolchains:
```bash
sudo apt install gcc-aarch64-linux-gnu    # Linux ARM64
sudo apt install mingw-w64                # Windows EXE from Linux
```

## Enterprise Deployment

### Group Policy / Intune Controls

WSL can be managed via MDM/Intune (ADMX templates from Microsoft):
- **Allow WSL** -- enable/disable WSL entirely
- **Allow WSL1** -- prevent fallback to WSL1
- **Allowed distros** -- whitelist specific distros by name
- **Allow custom kernel** -- control kernel override
- **Allow kernel debugging** -- restrict debug access

Policy path: `Computer Configuration > Administrative Templates > Windows Components > Windows Subsystem for Linux`

### Custom Kernel Deployment

For environments requiring approved kernel builds:
```ini
[wsl2]
kernel=C:\\IT\\WSL\\approved-kernel\\bzImage
```

### Security Considerations

1. **DLP blind spot:** Files inside `ext4.vhdx` are not scanned by most Windows DLP tools. Assess data residency risk for sensitive environments.

2. **Network isolation:** NAT mode provides some isolation. Mirrored mode exposes WSL to the same network as the host. Choose based on security posture.

3. **Antivirus:** Windows Defender scans `/mnt/` paths but not WSL native filesystem directly. Real-time protection inside WSL requires a Linux AV agent.

4. **Credential exposure:** SSH keys, tokens, and secrets stored in WSL are accessible to any process running in that distro. Use ssh-agent with timeout and consider hardware-backed key storage.

### Offline / Air-Gapped Install

```powershell
# Download appx package on connected machine:
Invoke-WebRequest -Uri https://aka.ms/wslubuntu2204 -OutFile ubuntu2204.appx
# Or use wsl --export from a connected machine

# On air-gapped machine:
wsl --import UbuntuOffline C:\WSL\UbuntuOffline C:\offline\ubuntu-rootfs.tar --version 2
```

### WSL Kernel Updates in Managed Environments

By default, WSL kernel updates via Windows Update. In managed environments, control updates by:
1. Using a custom kernel path in `.wslconfig`
2. Managing WSL Store app updates via Intune Store app policies
3. Using `wsl --update` in controlled maintenance windows

## Common Commands Reference

```powershell
# Management
wsl --install                         # Install WSL + default distro
wsl --install -d <Distro>             # Install specific distro
wsl --update                          # Update WSL package
wsl --version                         # Version info
wsl --status                          # Default distro, version, kernel
wsl --list --verbose                  # All distros with state/version
wsl --shutdown                        # Stop all distros + VM
wsl --terminate <Distro>              # Stop one distro
wsl --set-default-version 2           # New distros default to WSL2
wsl --set-version <Distro> 2          # Convert to WSL2
wsl --export <Distro> <file.tar>      # Backup
wsl --import <Name> <dir> <file.tar>  # Restore/clone
wsl --unregister <Distro>             # Delete (destructive!)
wsl --mount <disk>                    # Mount physical disk in WSL2
```

```bash
# Diagnostics inside WSL
uname -r                              # Kernel version
cat /etc/wsl.conf                     # Per-distro config
cat /proc/version                     # Full kernel string
systemctl status                      # systemd health
df -h /                               # Disk usage
free -h                               # Memory usage
ip addr show eth0                     # WSL IP
cat /etc/resolv.conf                  # DNS config
```
