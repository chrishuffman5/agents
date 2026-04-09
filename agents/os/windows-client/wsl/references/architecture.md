# WSL Architecture Reference

## WSL1 -- Syscall Translation

WSL1 (introduced Windows 10 Anniversary Update, 2016) operates entirely in user space with a kernel-mode translation layer. There is no Linux kernel. Two kernel drivers implement the translation:

- **lxss.sys** -- manages Linux instances (namespaces, PIDs, file descriptors)
- **lxcore.sys** -- translates Linux syscalls into NT equivalents

When a Linux binary calls `read()`, `write()`, `fork()`, etc., lxcore.sys intercepts and maps each to the nearest Windows NT operation. Coverage is high but not complete -- syscalls with no NT equivalent fail or behave differently (e.g., `epoll`, raw sockets, 32-bit binaries).

### WSL1 Characteristics

- No hypervisor; runs directly on the Windows kernel
- ELF binaries execute natively (no emulation)
- Linux filesystem emulated via a VolFS driver (maps Linux paths onto NTFS)
- Cross-filesystem I/O (accessing Windows drives at `/mnt/c`) is fast -- no VM boundary
- File permission model emulated; Windows ACLs used under the hood
- Does not support `kvm`, `bpf` (full), Docker daemon, or certain ioctl operations
- Approximately 80% syscall compatibility

## WSL2 -- Lightweight Utility VM

WSL2 (introduced 2004/20H1, May 2020) runs a genuine Linux kernel inside a lightweight Hyper-V virtual machine called a **utility VM**. Each WSL2 distro shares a single VM instance by default (though they have isolated rootfs).

### Kernel

Microsoft maintains a fork of the Linux kernel, updated via Windows Update or `wsl --update`. Tracks the LTS series. Source available at github.com/microsoft/WSL2-Linux-Kernel.

### Storage

Each distro's rootfs lives in an ext4 virtual hard disk (`ext4.vhdx`):
```
%LOCALAPPDATA%\Packages\<distro-package-name>\LocalState\ext4.vhdx
```
Or for non-Store distros imported via `wsl --import`:
```
<user-specified-path>\ext4.vhdx
```

### WSL2 Characteristics

- Full Linux kernel -- near-100% syscall compatibility
- Supports Docker daemon, `kvm` (nested virt, where host supports it), `ebpf`, `io_uring`
- Real `/proc`, `/sys`, cgroups v2
- Linux-native I/O is significantly faster (ext4 on VHD vs VolFS emulation)
- Cross-filesystem I/O slower (9P protocol crosses VM boundary)
- Memory is dynamic (VM balloon driver); visible to Task Manager as **Vmmem** process
- Boot time ~1-2 seconds

## Filesystem Architecture

### WSL2 Virtual Disk

The `ext4.vhdx` grows automatically up to the configured limit (default 1 TB). It does **not** automatically shrink when files are deleted -- the ext4 layer frees blocks but the VHD file on NTFS retains size.

Compacting:
```powershell
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

**Windows to Linux:**
```
\\wsl$\<distro-name>\home\user\project
\\wsl.localhost\<distro-name>\    (newer alias)
```
Access via File Explorer or any UNC-capable app. Uses the 9P server running inside WSL2.

**Linux to Windows:**
```bash
/mnt/c/       # C: drive
/mnt/d/       # D: drive
```
DrvFs mounts, configured in `/etc/wsl.conf`. Metadata option preserves Linux permissions on NTFS:
```ini
[automount]
options = "metadata,umask=22,fmask=11"
```

### 9P Protocol

WSL2 uses **9P2000.L** (a Plan 9 filesystem protocol) for cross-filesystem communication. The Linux kernel acts as a 9P client; a host-side server serves Windows filesystem access. Every file operation crossing the boundary incurs a context switch from the VM, 9P message encode/decode, and NTFS operation on the host. For projects with thousands of small files (node_modules, virtualenvs, cargo target dirs), this overhead compounds significantly.

## Networking

### NAT Mode (Default)

WSL2 VM gets a private IP on a virtual network adapter (`vEthernet (WSL)`). The host performs NAT. The WSL IP changes on every `wsl --shutdown` + restart.

Localhost forwarding: By default in recent WSL2 versions, `localhost` from Windows reaches services bound to `0.0.0.0` or `127.0.0.1` inside WSL.

### Mirrored Networking Mode (Windows 11 22H2+)

```ini
[wsl2]
networkingMode=mirrored
```

In mirrored mode:
- WSL sees the same network interfaces as Windows
- WSL IP matches host IP -- no separate subnet
- IPv6 works correctly
- Reduces VPN compatibility issues
- DNS resolution uses host DNS directly

**DNS Tunneling:** Routes WSL DNS queries through the Windows DNS client stack, respecting enterprise DNS policies and split-horizon DNS. Set `dnsTunneling=true`.

**Auto-Proxy:** Automatically applies Windows proxy settings to WSL environment variables. Set `autoProxy=true`.

### VPN Compatibility

VPN clients that modify the host routing table or DNS can break WSL2 NAT networking. Common symptoms: no internet from WSL2, DNS failures. Mitigations: use mirrored networking mode, enable DNS tunneling, restart WSL after VPN connects.

## GPU Passthrough (GPU-PV)

WSL2 supports GPU acceleration via **GPU-PV** (GPU Paravirtualization) -- a Hyper-V mechanism where the guest VM shares the host GPU through a paravirtualized driver. No GPU is passed through directly; a kernel-mode driver in WSL2 (`dxgkrnl`) communicates with the Windows GPU driver via the hypervisor.

### Supported Workloads

- **CUDA (NVIDIA)** -- install `cuda-toolkit` inside WSL2; use host NVIDIA driver (no driver inside WSL)
- **DirectML (AMD, Intel, NVIDIA)** -- for Windows ML workloads via D3D12
- **OpenGL / OpenCL** -- via Mesa/D3D12 translation layer
- **Vulkan** -- supported via WSL Vulkan ICD

### Limitations

- Only one GPU instance visible inside WSL (primary display adapter)
- Multi-GPU not natively supported via GPU-PV
- Real-time display output not intended use case -- use WSLg for GUI
- NVIDIA driver version requirement: 470.76+

## WSLg -- GUI Applications

WSLg runs a **Wayland compositor** (Weston) inside the WSL utility VM. It acts as a Wayland server for Linux GUI apps and as a client to an RDP virtual desktop on the Windows side.

Components:
- **Weston** -- in-VM Wayland compositor
- **XWayland** -- X11 compatibility server
- **PulseAudio** -- audio server inside VM, streams to Windows audio via RDP
- **FreeRDP / mstsc** -- renders remote desktop into Windows desktop seamlessly

`DISPLAY` and `WAYLAND_DISPLAY` are set automatically. Clipboard shared between Windows and WSL GUI apps. GPU-accelerated compositing via D3D12/GPU-PV when available. Falls back to software rendering if GPU-PV unavailable.

Available since Windows 11 (built-in) and Windows 10 21H2 (via KB update).

## systemd Support

Native systemd support since WSL 0.67.6 (September 2022). Enable per-distro in `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

With systemd enabled:
- Services start at distro boot (on `wsl` invocation)
- `snap` packages work (snapd requires systemd)
- `systemctl enable <service>` works for persistence
- `journalctl` available for log management
- Login sessions go through PAM properly

Without systemd, use `[boot] command = "service docker start"` for startup services.

## USB Device Passthrough

Physical USB devices can be attached to WSL2 using **usbipd-win** (USB/IP protocol):

```powershell
winget install usbipd
usbipd list
usbipd attach --wsl --busid 1-7
```

Use cases: USB serial devices, microcontrollers, smartcards, USB cameras.
