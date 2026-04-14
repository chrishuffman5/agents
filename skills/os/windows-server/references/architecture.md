# Windows Server Architecture Reference

## NT Kernel Architecture

### Privilege Separation

Windows NT uses a two-ring privilege model:

| Layer | CPU Ring | Access |
|---|---|---|
| Kernel mode | Ring 0 | Unrestricted access to hardware, memory, all system resources |
| User mode | Ring 3 | Restricted; must request kernel services via syscall |

All kernel-mode components (HAL, kernel, Executive, drivers) share a single address space. A fault in any component causes a BSOD. User-mode processes have isolated virtual address spaces.

### Hardware Abstraction Layer (HAL)

`hal.dll` abstracts platform-specific hardware: interrupt controller management, I/O bus interfaces, DMA, multiprocessor synchronization, timer/clock management. The HAL and kernel ship as matched pairs.

### The NT Kernel (ntoskrnl.exe)

Responsible for:
- **Thread scheduling**: Priority-based preemptive scheduler with 32 priority levels (0-31)
- **Multiprocessor sync**: Spinlocks, queued spinlocks, DPC queues
- **Interrupt handling**: IRQL hierarchy managing hardware/software interrupts and DPCs
- **Exception dispatching**: Structured exception handling (SEH) dispatch chain
- **Trap handling**: System call dispatch from user mode

### Executive Subsystems

| Subsystem | Prefix | Responsibility |
|---|---|---|
| Object Manager | `Ob` | Named kernel resources, reference counting, handles (up to ~16M per process) |
| I/O Manager | `Io` | IRP-based layered driver stacks, async I/O, completion ports |
| Memory Manager | `Mm` | Demand-paged virtual memory (4 KB pages, 2 MB large pages), working sets, paged/non-paged pool |
| Process Manager | `Ps` | Process/thread lifecycle, Job objects, TEB/PEB management |
| Security Reference Monitor | `Se` | Access control enforcement, token-vs-DACL checks, privilege management, audit generation |
| Configuration Manager | `Cm` | Windows Registry implementation, hive management, transactional registry |
| PnP Manager | `Pnp` | Device detection, driver loading, device stack construction |
| Cache Manager | `Cc` | File data caching via memory-mapped files, read-ahead, lazy writes |

### Key System Processes

| Process | Binary | Role |
|---|---|---|
| Session Manager | `smss.exe` | First user-mode process; loads system hive, initializes paging, launches csrss/wininit |
| Windows Init | `wininit.exe` | Session 0 parent; starts services.exe, lsass.exe, lsm.exe |
| Service Control Manager | `services.exe` | Manages all Win32 services; reads config from `HKLM\SYSTEM\CurrentControlSet\Services` |
| LSASS | `lsass.exe` | Authentication, security policy, credential management (Kerberos, NTLM, SAM) |
| CSRSS | `csrss.exe` | Win32 subsystem; console windows, process/thread bookkeeping |

---

## Boot Process

### UEFI Boot Sequence

```
UEFI Firmware (POST, NVRAM boot variable enumeration)
  -> bootmgfw.efi (\EFI\Microsoft\Boot\bootmgfw.efi on ESP)
     -> Reads BCD store
     -> winload.efi
        -> Verifies ntoskrnl.exe signature
        -> Loads ntoskrnl.exe + hal.dll
        -> Loads system registry hive (SYSTEM)
        -> Loads CPU microcode, ELAM driver, boot-start drivers
        -> Transfers control to ntoskrnl.exe
           -> Phase 0/1 initialization -> smss.exe
              -> csrss.exe, wininit.exe -> services.exe, lsass.exe
              -> winlogon.exe
```

### Boot Configuration Data (BCD)

Replaces legacy `boot.ini`. Binary registry-format file on the ESP. Key commands:
```
bcdedit /enum all               # List all entries
bcdedit /set {current} debug yes    # Enable kernel debugger
bcdedit /set {current} nx OptIn     # DEP policy
```

### Secure Boot and Measured Boot

- **Secure Boot**: UEFI feature preventing unauthorized bootloaders. Allow DB (trusted keys) and Disallow DB (DBX, revocation).
- **Measured Boot**: Uses TPM to hash each boot component into PCR banks. Remote attestation verifies PCR values against known-good baselines.
- **ELAM**: Anti-malware driver loaded first among boot-start drivers; classifies subsequent drivers as Good/Bad/Unknown.

### Service Startup Phases

1. `BOOT_START` (0x0): Loaded by winload.efi (disk, volume, filesystem drivers)
2. `SYSTEM_START` (0x1): Started by kernel during phase 1 init
3. `AUTO_START` (0x2): Started by SCM immediately
4. `AUTO_START_DELAYED` (0x2 + DelayedAutostart=1): Started ~2 min after boot
5. `DEMAND_START` (0x3): Started on request
6. `DISABLED` (0x4): Never started

---

## Registry Architecture

### Hive Files

| Hive | Location | Description |
|---|---|---|
| SYSTEM | `C:\Windows\System32\config\SYSTEM` | Boot-critical configuration |
| SOFTWARE | `C:\Windows\System32\config\SOFTWARE` | Application and OS settings |
| SAM | `C:\Windows\System32\config\SAM` | Local user account database (locked at runtime) |
| SECURITY | `C:\Windows\System32\config\SECURITY` | Security policy, LSA secrets (locked) |
| NTUSER.DAT | `%USERPROFILE%\NTUSER.DAT` | Per-user preferences |
| HARDWARE | Volatile (RAM only) | Dynamically generated at boot |

### Critical Server Registry Paths

```
HKLM\SYSTEM\CurrentControlSet\Services\<ServiceName>      # Service config
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager      # Boot config, paging
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters    # TCP/IP settings
HKLM\SYSTEM\CurrentControlSet\Control\Lsa                  # Security policies
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run         # Startup programs
```

---

## Services and Processes

### Service Types

| Type | Name | Description |
|---|---|---|
| 0x1 | Kernel Driver | Kernel-mode driver (disk.sys, tcpip.sys) |
| 0x2 | File System Driver | ntfs.sys, refs.sys |
| 0x10 | Win32OwnProcess | Runs in own process |
| 0x20 | Win32ShareProcess | Shares svchost.exe with other services |

### Service Accounts

| Account | Network Identity | Use Case |
|---|---|---|
| LocalSystem (S-1-5-18) | Machine account | Maximum privilege; legacy services |
| LocalService (S-1-5-19) | Anonymous | Low-privilege, no domain auth needed |
| NetworkService (S-1-5-20) | Machine account | Needs domain-authenticated network access |
| gMSA | Domain account | Auto-managed 120-char passwords for farms |
| dMSA (2025) | Machine-bound domain account | Credential Guard integration, prevents kerberoasting |

### svchost.exe Isolation

On systems with >3.5 GB RAM (Server 2016+), services run in individual svchost.exe instances for improved isolation and fault containment. Service DLL path: `HKLM\SYSTEM\CurrentControlSet\Services\<Name>\Parameters\ServiceDll`.

---

## Memory Management

### Virtual Address Space Layout (x64)

| Region | Size | Notes |
|---|---|---|
| User space | 128 TB | Per-process private virtual address space |
| Kernel space | 128 TB | Shared across all processes |

Default page size: 4 KB. Large pages: 2 MB (require `SeLockMemoryPrivilege`).

### Pool Memory

| Pool | Behavior | Diagnostic Concern |
|---|---|---|
| Non-Paged Pool | Always in physical RAM | >1 GB typically indicates driver memory leak |
| Paged Pool | Can be paged to disk | Normal for large allocations |
| Non-Paged Pool NX | NPP with Execute-Never protection | Security hardening (post-Win8) |

Diagnose pool leaks with `poolmon.exe` or WinDbg `!poolused`.

---

## Storage Subsystem

### Storage Stack (Top to Bottom)

```
Application (ReadFile / WriteFile)
  -> File System Driver (ntfs.sys / refs.sys)
  -> Volume Snapshot / Filter Drivers (volsnap.sys, fvevol.sys)
  -> Volume Manager (volmgr.sys)
  -> Partition Manager (partmgr.sys)
  -> Disk Class Driver (disk.sys)
  -> Storage Port Driver (storport.sys / StorNVMe.sys)
  -> Miniport / Physical Hardware
```

### NTFS Key Facts

- Journaled, B-tree based. MFT record size: 1 KB.
- Small files (<~700 bytes) stored resident in MFT record.
- Transaction log (`$LogFile`) for crash recovery.
- Limits: max file 256 TB, max volume 256 TB.
- EFS provides per-file transparent encryption using symmetric FEK wrapped with user's RSA key.

### ReFS Key Facts

- B+ tree structure; allocation-on-write (copy-on-write metadata).
- 64-bit checksums on all metadata. Optional per-file integrity streams.
- Block cloning for O(1) file copy (Hyper-V checkpoint merge).
- Mirror-accelerated parity on S2D: hot writes in mirror tier, cold data in parity tier.
- Limits: max file 35 PB, max volume 35 PB.
- Cannot boot from ReFS. No disk quotas, no ODX, no TxF.

### Storage Spaces Direct (S2D)

S2D provides hyperconverged software-defined storage using direct-attached disks across cluster nodes:
- **Storage Pool**: collection of physical disks across nodes
- **Virtual Disk**: provisioned with resiliency (Simple, Mirror, Parity)
- **Cache tier**: NVMe/SSD auto-assigned as write-back cache
- **Capacity tier**: HDD or slower SSD
- Requires Datacenter edition; minimum 2 nodes (mirror), 4 nodes recommended for parity

### NVMe Native I/O (Server 2025)

Server 2025 replaces SCSI emulation with direct NVMe I/O via StorNVMe.sys:
- Lock-free I/O paths, up to 64,000 queues and 64,000 commands per queue
- Up to 80% higher IOPS and 45% lower CPU per I/O vs. Server 2022
- NVMe/TCP extends NVMe over standard TCP/IP for remote block storage (Datacenter only)

### Volume Shadow Copy Service (VSS)

Three core components: VSS Service (coordinator), VSS Requestor (backup app), VSS Writer (app consistency), VSS Provider (snapshot implementation).

Shadow copy creation freezes write I/O for max 60 seconds, creates snapshot in max 10 seconds, then releases I/O. System Provider uses copy-on-write to the diff area.

Tools: `vssadmin.exe` (list/delete/resize), `diskshadow.exe` (scripted VSS operations).

---

## Networking Stack

### NDIS and TCP/IP

NDIS 6.x governs miniport, protocol, and lightweight filter drivers. Key capabilities: Net Buffer Lists (efficient packet descriptors), TCP/IP offload (LSO, RSC, checksum), Receive-Side Scaling (RSS) distributing packets across CPU cores.

TCP/IP stack (`tcpip.sys`): dual-stack IPv4/IPv6. HTTP.sys provides kernel-mode HTTP listener for IIS, WCF, and WAC.

### SMB 3.x Architecture

| Feature | Introduced | Description |
|---|---|---|
| SMB Multichannel | Server 2012 | Multiple network paths simultaneously |
| SMB Direct (RDMA) | Server 2012 | Zero-copy over RDMA NICs |
| SMB Encryption | Server 2012 | AES-128-CCM per-share/session |
| SMB Compression | Server 2022 | LZ4, ZSTD in-transit compression |
| SMB over QUIC | Server 2022 AE | UDP/443 with TLS 1.3 tunnel |
| AES-256 encryption | Server 2022 | AES-256-GCM/CCM for SMB |

### NIC Teaming vs SET

- **LBFO**: Traditional teaming via `Set-NetLbfoTeam`. Incompatible with RDMA.
- **SET**: Integrated into Hyper-V virtual switch (`New-VMSwitch -EnableEmbeddedTeaming $true`). Preserves RDMA. Required for converged networking.

---

## Security Architecture

### Authentication

LSASS hosts authentication packages as DLLs:
- `kerberos.dll`: Kerberos v5 (primary for domain). TGT lifetime: 10 hours, renewal: 7 days.
- `msv1_0.dll`: NTLM/NTLMv2 (fallback). NTLMv1 blocked by default in Server 2025.
- `schannel.dll`: TLS/SSL certificate-based authentication.
- `negotiate.dll`: SPNEGO (negotiates between Kerberos and NTLM).

### VBS and Credential Guard

VBS uses Hyper-V hypervisor to create Virtual Secure Mode (VSM). Even a fully compromised kernel cannot access VSM memory.

**Credential Guard** (`LSAIso.exe` in VSM): stores NTLM hashes, Kerberos TGTs, session keys. Protected by TPM-bound VSM master key. Enabled by default on Server 2025 on capable hardware.

**Limitations**: Does not protect local accounts, NTLMv1/v2 prompted credentials, or Kerberos service tickets. Breaks unconstrained delegation and CredSSP SSO.

### LSASS Protection

- **PPL (Protected Process Light)**: Limits which processes can attach to lsass.exe (Server 2012+)
- **Credential Guard**: Moves secrets into LSAIso (VSM)
- Enable PPL: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL` = 1

---

## WMI / CIM Architecture

WMI implements the DMTF CIM standard:
- Repository: `C:\Windows\System32\wbem\Repository\`
- Default namespace: `root\cimv2`
- Service: `Winmgmt` (wbemcore.dll in svchost.exe)

Use `Get-CimInstance` for queries. For remote machines, CIM uses WS-Man (WinRM) by default. DCOM fallback available via `New-CimSession -SessionOption (New-CimSessionOption -Protocol Dcom)`.
