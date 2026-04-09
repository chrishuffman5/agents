# Windows Client Architecture Reference

> **Cross-reference:** For NT kernel internals, registry, boot process, NTFS/ReFS, SMB, NDIS, WMI/CIM, and VBS architecture, see `../../windows-server/references/architecture.md`. This file covers desktop-specific architecture only.

---

## Desktop App Model

### Win32 Desktop Applications

The classic Win32 API remains the dominant desktop programming model. Win32 apps communicate with the OS through `kernel32.dll`, `user32.dll`, `gdi32.dll`, and `ntdll.dll`. They have no store delivery, no automatic update infrastructure, and no sandboxing by default. Installation typically modifies `HKLM\SOFTWARE`, `%ProgramFiles%`, and creates COM registrations.

### Universal Windows Platform (UWP)

UWP provides a sandboxed, containerized app model with a unified API surface across device families:
- Runs in an AppContainer (`SECURITY_CAPABILITY_*` SIDs, strongly restricted token)
- Installed per-user or per-machine to `C:\Program Files\WindowsApps\` (ACL-locked)
- Declarative capabilities in `AppxManifest.xml` control resource access
- Lifecycle managed by PLM (Process Lifetime Manager): Suspend/Resume/Terminate
- Filesystem access confined to app package folder and brokered locations (Music, Pictures, etc.)

### MSIX Packaging

MSIX is the modern Windows installer format, unifying MSI and App-V:
- Container format: ZIP-based `.msix` or `.msixbundle`
- Signed with a code-signing certificate (Windows validates at install and execution)
- Installs via copy-on-write virtual registry and virtual filesystem layers -- no shared DLL hell
- Clean uninstall: no orphaned registry or file artifacts
- `AppxManifest.xml` declares identity, capabilities, entry points, and extensions
- Supports Win32 apps via Desktop Bridge (Centennial) without UWP sandboxing

### Desktop Bridge (Project Centennial)

Allows repackaging legacy Win32 apps as MSIX without full UWP porting:
- Win32 process runs unmodified; MSIX container provides clean install/uninstall
- Can progressively add UWP extensions (live tiles, push notifications, background tasks)
- Registry writes to `HKCU\Software` and `HKLM\Software` are redirected to package private hive
- File writes outside allowed locations are virtualized

### WinUI 3 / Windows App SDK

Microsoft's current recommended UI framework for new desktop apps:
- Decoupled from OS shipping cadence (ships via NuGet/Windows App SDK)
- Provides Fluent Design controls, XAML Islands for embedding in Win32 hosts
- Supports both packaged (MSIX) and unpackaged deployment
- Replaces WPF/WinForms for new development; WPF/WinForms still supported

### Windows Package Manager (winget)

CLI package manager included in Windows 10 1709+ and all Win11:
- Architecture: `winget.exe` -> Windows Package Manager COM server -> Sources (WinGet Community Repository, Microsoft Store, configured private feeds)
- Manifest format: YAML, published to `microsoft/winget-pkgs` GitHub repo
- Installer types supported: MSI, MSIX, EXE (silent), Burn, Inno Setup, NSIS, Portable
- DSC integration via `winget configure` using YAML config files
- Enterprise: supports private repo sources, REST-based source servers, Group Policy for source management

### App-V (Application Virtualization)

Streaming virtual application packages for enterprise scenarios:
- App runs in an isolated virtual environment with virtualized registry, filesystem, COM
- Package format: `.appv` (superseded by MSIX for new scenarios; App-V in extended support)
- Key registry paths: `HKLM\SOFTWARE\Microsoft\AppV\`

---

## Driver Model -- Desktop-Specific Stack

### WDDM (Windows Display Driver Model)

GPU drivers on desktop use WDDM, not the server-oriented compute-only path:
- Current version: WDDM 3.x (Win11)
- Split into User-Mode Driver (UMD: `*_UMD.dll`) and Kernel-Mode Driver (KMD: `*.sys`)
- GPU scheduler (`dxgkrnl.sys`) preempts GPU workloads, preventing GPU hangs from killing the desktop
- TDR (Timeout Detection and Recovery): if GPU becomes unresponsive for >2 seconds, Windows resets the GPU without a BSOD -- Event ID 4101 in System log

### Audio Stack

Desktop-specific layered audio architecture:
```
App (WASAPI / DirectSound / Media Foundation)
  -> Audio Engine (audiodg.exe, user mode, isolated process)
     -> Audio Session API (ASIO bypass possible for pro audio)
     -> WaveRT miniport driver (kernel mode)
        -> Audio bus enumerator (PortCls.sys / HDAudio.sys)
```
- `audiodg.exe` runs as a low-privilege isolated process to protect the audio pipeline
- WASAPI Exclusive Mode bypasses mixing for low-latency professional audio

### Driver Signing Requirements

- All kernel-mode drivers must be cross-signed by a trusted CA + signed by Microsoft via WHQL or Attestation signing (Dev Portal)
- Secure Boot + HVCI enforces this at runtime: unsigned or modified driver code cannot execute
- Test signing requires `bcdedit /set testsigning on` -- disables Secure Boot
- Driver update priority: Windows Update WHQL -> OEM OTA -> Manual INF install

### Driver Rollback

Device Manager -> Driver tab -> Roll Back Driver restores previous driver version from `C:\Windows\System32\DriverStore\FileRepository\`. Use `pnputil /enum-drivers` to list all driver packages in the store.

---

## Desktop Window Manager (DWM)

`dwm.exe` is the composition engine that renders all on-screen windows:
- Runs in Session 1 (interactive desktop) as a protected process
- Each window's content is rendered off-screen to a DirectX surface (texture), then DWM composites all surfaces to the screen using GPU hardware
- Enables effects: transparency (Mica, Acrylic), blur, shadows, rounded corners (Win11)
- Hardware acceleration: DWM uses WDDM GPU scheduler; falling back to CPU composition is not possible -- DWM crash triggers session restart

### Fluent Design System (Win11)

- **Mica:** samples desktop wallpaper to tint app backgrounds
- **Acrylic:** blurred transparency effect for surfaces
- **Rounded corners:** 8px radius on Win11
- **Snap Layouts:** DWM + Shell coordinate to offer grid templates when hovering the maximize button
- **Snap Groups:** Shell tracks groups of snapped windows, restoring layout when taskbar thumbnail clicked

### DWM Diagnostics

```powershell
# Check DWM process health
Get-Process dwm | Select-Object CPU, WorkingSet64, HandleCount

# GPU memory usage
Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue

# DWM event log
Get-WinEvent -LogName 'Microsoft-Windows-Dwm-Core/Operational' -MaxEvents 50
```

---

## Modern Standby / Connected Standby

Desktop differs fundamentally from Server in power management. Servers use S3 (Suspend to RAM) or S4 (Hibernate); modern client devices use S0 Low Power Idle (Modern Standby):

| Aspect | S3 Sleep (legacy) | S0 Modern Standby |
|---|---|---|
| CPU state | Powered off | Low-power idle C-states |
| Network | Disconnected | Maintained (Wi-Fi/LTE connected) |
| Background tasks | None | Limited (email sync, notifications) |
| Wake latency | ~2 seconds | Instant (screen on = resumed) |
| Platform requirement | Any | Intel/AMD low-power platform, NVMe/eMMC |

```powershell
powercfg /a                              # Lists available sleep states
powercfg /sleepstudy                     # 72-hour standby drain report (HTML)
powercfg /energy                         # 60-second power efficiency trace
powercfg /batteryreport                  # Battery capacity history
```

Modern Standby devices that cannot enter true S3 may drain faster. Use `powercfg /sleepstudy` to identify apps with excessive standby drain.

---

## Windows Store / App Installer

### Microsoft Store Architecture

- Store client: `WinStore.App.exe` (UWP app)
- Backend: StorePurchaseApp service, `InstallService`
- App packages delivered as MSIX/AppX bundles to `C:\Program Files\WindowsApps\`
- App updates applied atomically -- old version stays until new version fully staged

### App Installer

- `AppInstaller.exe` handles MSIX sideloading and `.appinstaller` manifest-based deployment
- `.appinstaller` XML defines package source URL, version, update checking policy
- Used by winget for MSIX-based packages; also used for enterprise internal app distribution
- Sideloading requires: Developer Mode OR device in enterprise environment with sideload policy

```powershell
# Check developer mode
(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock).AllowDevelopmentWithoutDevLicense

# Check sideloading policy
(Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\Appx -EA SilentlyContinue).AllowAllTrustedApps
```

---

## Dev Drive (Windows 11)

ReFS-backed volume optimized for developer workloads:
- Available on Pro, Enterprise, Education (Win11 22H2+)
- Uses ReFS copy-on-write for fast file operations
- Excluded from Defender real-time scanning by default (configurable)
- Optimized for package manager caches (npm, NuGet, pip, cargo) and source code
- Created via Settings > System > Storage > Disks & volumes > Create Dev Drive
- Minimum 50 GB; can be created as a new partition or VHD
