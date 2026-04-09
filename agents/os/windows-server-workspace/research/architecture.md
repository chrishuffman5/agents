# Windows Server Internal Architecture — Research Reference

> Research compiled for the Windows Server agent library. Covers cross-version architecture
> applicable to Windows Server 2016 through 2025. Version-specific deltas are noted inline.

---

## 1. NT Kernel Architecture

### Privilege Separation: Kernel Mode vs. User Mode

Windows NT uses a two-ring privilege model mapped onto the CPU's hardware protection rings:

| Layer | CPU Ring | Access |
|---|---|---|
| Kernel mode | Ring 0 (CPL 0) | Unrestricted access to hardware, memory, and all system resources |
| User mode | Ring 3 (CPL 3) | Restricted; must request kernel services via system calls (syscall/int 2e) |

All kernel-mode components — the HAL, the kernel itself, Executive subsystems, and kernel-mode device drivers — share a single address space. A fault in any component can crash the entire system (BSOD). User-mode processes each have isolated virtual address spaces; a crash in one process does not affect others.

The user-mode layer is divided into:
- **Environment subsystems** — run applications written for different OS personalities (Win32 subsystem via `csrss.exe`)
- **Integral subsystem** — performs system-specific functions (e.g., security subsystem via `lsass.exe`)

### Hardware Abstraction Layer (HAL)

The HAL (`hal.dll`) sits at the bottom of the kernel-mode stack and abstracts platform-specific hardware details. It provides:
- Interrupt controller management (APIC, PIC)
- I/O bus interfaces and DMA management
- Multiprocessor synchronization primitives
- Timer and clock management
- Platform-specific power management

The HAL is not a fully independent layer — it relies on kernel and Executive components, so kernel and HAL variants ship as matched pairs. Kernel-mode drivers call HAL routines instead of accessing hardware directly, ensuring portability across hardware platforms.

### The NT Kernel (`ntoskrnl.exe`)

The kernel layer (`ntkrnlpa.exe` on 32-bit PAE, `ntoskrnl.exe` on 64-bit) sits between the HAL and the Executive and is responsible for:
- **Thread scheduling and dispatching** — priority-based preemptive scheduler with 32 priority levels (0–31)
- **Multiprocessor synchronization** — spinlocks, queued spinlocks, and DPC (Deferred Procedure Call) queues
- **Interrupt handling** — IRQL (Interrupt Request Level) hierarchy managing hardware interrupts, software interrupts, and DPCs
- **Exception dispatching** — structured exception handling (SEH) dispatch chain
- **Trap handling** — system call dispatch from user mode
- **Boot-time driver initialization** — loading and initializing drivers tagged `SERVICE_BOOT_START`

### Executive Subsystems

The Windows Executive is the upper portion of `ntoskrnl.exe` and provides the bulk of OS functionality:

**Object Manager (`Ob`)**
- Central resource-management infrastructure; all named kernel resources are objects
- Maintains an object namespace (similar to a filesystem: `\Device\`, `\Driver\`, `\BaseNamedObjects\`, `\Sessions\`, etc.)
- Provides reference counting, handles, and object lifecycle management
- Two-phase object creation: allocate (reserve resources) → insert (make accessible via name or handle)
- Handles are opaque cookies granting access to an object; a process can hold up to ~16 million handles simultaneously
- Object types define type-specific procedures (open, close, delete, query name, parse)

**I/O Manager**
- Translates file and device read/write requests into I/O Request Packets (IRPs)
- Routes IRPs down layered driver stacks (filter → function → bus drivers)
- Manages completion routines and asynchronous I/O (overlapped, I/O completion ports)
- Includes cache manager coordination for buffered I/O

**Memory Manager**
- Implements demand-paged virtual memory with a 4-KB page size (large pages: 2 MB on x64)
- Manages working sets (per-process set of pages currently in physical RAM)
- Controls paged pool (swappable kernel memory) and non-paged pool (must remain in RAM)
- Handles page table management, PTE (Page Table Entry) lifecycle, and VAD (Virtual Address Descriptor) trees
- Implements memory-mapped files (section objects), shared memory, and copy-on-write
- On Windows Server 2016+, supports memory partitions for VM-level memory isolation under Hyper-V

**Process Manager**
- Creates and terminates processes and threads
- Implements the Job object (group of processes sharing resource limits)
- Manages thread context, TEB (Thread Environment Block), and PEB (Process Environment Block)
- Coordinates with Memory Manager for address space setup at process creation

**Security Reference Monitor (SRM)**
- The kernel-mode authority for access control enforcement
- Validates access requests by comparing a caller's access token against an object's security descriptor (DACL)
- Manages privileges (e.g., `SeDebugPrivilege`, `SeTcbPrivilege`, `SeBackupPrivilege`)
- Generates security audit events (success/failure) written to the Security event log
- Implements mandatory integrity control (integrity levels: Low, Medium, High, System)
- Works in tandem with LSASS in user mode for authentication; SRM enforces, LSASS authenticates

**Configuration Manager**
- Implements the Windows Registry; maps registry keys and values to hive files on disk
- Manages hive loading, flushing, and unloading at boot and during user logon/logoff
- Provides transactional registry support via Kernel Transaction Manager (KTM)

**Plug and Play (PnP) Manager**
- Detects devices at boot and manages device addition/removal at runtime
- Builds and manages the device object tree
- Orchestrates driver loading and device stack construction
- Split implementation: kernel-mode core, bulk of enumeration logic in user mode (`umpnpmgr.dll` / `svchost.exe`)

**Cache Manager**
- Coordinates with Memory Manager and I/O Manager for file data caching
- Uses memory-mapped files as the backing store for cached file data
- Provides `CcReadAhead` (read-ahead) and lazy write functionality
- Shared by local (NTFS) and remote (SMB redirector) file system drivers

**Local Procedure Call (LPC / ALPC)**
- High-performance inter-process communication mechanism
- Used internally by subsystems, security infrastructure, and RPC
- ALPC (Advanced LPC, introduced Vista) replaced legacy LPC with improved security and scalability
- Basis for Win32 RPC (kernel-mode: Lpc port objects; user-mode: RPC runtime over ALPC)

### Key System Processes

| Process | Binary | Role |
|---|---|---|
| Session Manager | `smss.exe` | First user-mode process; started by kernel after boot. Loads the system registry hive, initializes paging files, sets environment variables, launches `csrss.exe` and `wininit.exe` for session 0 |
| Windows Init | `wininit.exe` | Session 0 parent process. Starts `services.exe`, `lsass.exe`, and `lsm.exe` |
| Service Control Manager | `services.exe` | Manages all Win32 services: startup, stop, pause, recovery. Reads service configuration from `HKLM\SYSTEM\CurrentControlSet\Services` |
| LSASS | `lsass.exe` | Authentication, security policy, and credential management. Hosts Kerberos, NTLM, and SAM authentication packages |
| CSRSS | `csrss.exe` | Client/Server Runtime Subsystem; Win32 subsystem process. Manages console windows, process/thread lifecycle bookkeeping for Win32 |
| Winlogon | `winlogon.exe` | Handles interactive logon/logoff, Secure Attention Sequence (Ctrl+Alt+Del), and screen saver |

### Kernel Dispatcher Objects

The kernel defines a set of synchronization primitives called **dispatcher objects**. All share a common `DISPATCHER_HEADER` structure embedded at offset 0, enabling the scheduler to place threads into wait states on any of them:

- **Event objects** — notification (broadcast) and synchronization (auto-reset) variants
- **Mutex objects** — recursive, ownership-aware mutual exclusion (kernel-mode mutant)
- **Semaphore objects** — counting semaphores for resource-pool management
- **Timer objects** — waitable timers, periodic or one-shot
- **Thread objects** — a thread itself is a dispatcher object; `WaitForSingleObject` on a thread waits for it to exit
- **Process objects** — signaled when last thread exits
- **Queue objects** — I/O completion queue implementation

The `DISPATCHER_HEADER.Type` field identifies the object type and determines wait/signal semantics.

---

## 2. Boot Process

### UEFI Boot Sequence

```
UEFI Firmware
  └─ POST, platform init, NVRAM boot variable enumeration
       └─ bootmgfw.efi  (\EFI\Microsoft\Boot\bootmgfw.efi on ESP)
            └─ Reads BCD store (\EFI\Microsoft\Boot\BCD on ESP)
            └─ winload.efi  (\Windows\System32\winload.efi)
                 ├─ Verifies ntoskrnl.exe signature
                 ├─ Loads ntoskrnl.exe + hal.dll into memory
                 ├─ Loads system registry hive (SYSTEM)
                 ├─ Loads CPU microcode updates
                 ├─ Loads boot-start drivers (SERVICE_BOOT_START)
                 ├─ Loads ELAM driver (first among boot-start drivers)
                 └─ Transfers control to ntoskrnl.exe
                      └─ Kernel phase 0 and phase 1 initialization
                      └─ Starts smss.exe
                           └─ Starts csrss.exe (session 0)
                           └─ Starts wininit.exe
                                ├─ services.exe  (SCM)
                                ├─ lsass.exe
                                └─ lsm.exe  (Local Session Manager)
                           └─ Starts winlogon.exe
```

### Boot Configuration Data (BCD)

The BCD store replaces the legacy `boot.ini`. It is a registry-format binary file:
- **UEFI location**: `\EFI\Microsoft\Boot\BCD` on the EFI System Partition (ESP)
- **BIOS/MBR location**: `\Boot\BCD` on the System Reserved partition (active partition)
- Each boot entry is identified by a GUID or predefined alias (e.g., `{bootmgr}`, `{current}`, `{default}`)
- Managed with `bcdedit.exe` or WMI (`root\WMI` namespace, `BcdStore` class)

Key BCD elements:
```
bcdedit /enum all          # List all entries
bcdedit /set {current} description "Windows Server 2025"
bcdedit /set {current} nx OptIn    # DEP policy
bcdedit /set {current} debug yes   # Enable kernel debugger
```

### Secure Boot

Secure Boot is a UEFI feature that prevents unauthorized bootloaders from executing:
- **Allow DB**: Database of trusted public keys and hashes (firmware, bootloaders, OS loaders)
- **Disallow DB (DBX)**: Revocation database; code signed by keys in DBX is rejected
- Each component in the boot chain (`bootmgfw.efi` → `winload.efi` → `ntoskrnl.exe`) must bear a valid signature
- Windows ships with keys from Microsoft Certificate Authority in the UEFI DB
- Any code in the DBX causes immediate boot failure

### Measured Boot

Measured Boot uses the TPM (Trusted Platform Module) to create a tamper-evident log of boot components:
- Each component is measured (hashed) and the measurement is extended into TPM PCR (Platform Configuration Register) banks
- PCRs 0–7: firmware, UEFI config, GPT; PCRs 8–15: OS boot components
- Remote Attestation: external services can verify the PCR values against known-good baselines
- The `tcblaunch.exe` / Windows Boot Manager coordinates measurement logging
- Enables Windows Defender System Guard's Runtime Attestation

### Early Launch Anti-Malware (ELAM)

ELAM allows anti-malware vendors to load their driver as the very first `SERVICE_BOOT_START` driver:
- Loaded by `winload.efi` before any other boot-start drivers initialize
- The ELAM driver receives a callback for each subsequent boot-start driver
- It classifies drivers as: **Good**, **Bad**, **Bad but Critical**, **Unknown**
- The kernel uses this classification to decide whether to initialize the driver
- ELAM drivers must be signed with a special Microsoft-issued ELAM certificate
- Registered under: `HKLM\SYSTEM\CurrentControlSet\Control\EarlyLaunch`

### Service Startup Phases

After kernel initialization, services start in waves:
1. **BOOT_START** (`0x0`): Loaded by winload.efi (disk, volume, filesystem drivers)
2. **SYSTEM_START** (`0x1`): Started by kernel during phase 1 init
3. **AUTO_START** (`0x2`): Started by SCM immediately after it initializes
4. **AUTO_START_DELAYED** (`0x2` + `DelayedAutostart=1`): Started ~2 minutes after boot completes to improve boot time
5. **DEMAND_START** (`0x3`): Started on request
6. **DISABLED** (`0x4`): Never started

---

## 3. Registry Architecture

### Hive Files

Registry data is stored in **hives** — binary files using a proprietary B-tree format. System hives are loaded by the kernel during boot; user hives are loaded at logon.

| Hive | File Location | Description |
|---|---|---|
| SYSTEM | `C:\Windows\System32\config\SYSTEM` | Boot-critical configuration; always loaded by kernel |
| SOFTWARE | `C:\Windows\System32\config\SOFTWARE` | Application and OS settings |
| SAM | `C:\Windows\System32\config\SAM` | Local user account database (locked at runtime) |
| SECURITY | `C:\Windows\System32\config\SECURITY` | Security policy, LSA secrets (locked at runtime) |
| DEFAULT | `C:\Windows\System32\config\DEFAULT` | Default profile for new users / service sessions |
| NTUSER.DAT | `%USERPROFILE%\NTUSER.DAT` | Per-user preferences and settings |
| UsrClass.dat | `%USERPROFILE%\AppData\Local\Microsoft\Windows\UsrClass.dat` | Per-user COM class registrations and file associations |
| HARDWARE | Volatile (RAM only) | Dynamically generated at boot; represents detected hardware |

Each non-volatile hive has associated transaction log files:
- `.LOG1` / `.LOG2` — dual transaction logs for crash-safe hive writes (circular log)
- `.regtrans-ms` / `.blf` — Kernel Transaction Manager logs for `RegCreateKeyTransacted` / `RegOpenKeyTransacted` operations; stored in `C:\Windows\System32\config\TxR\` for system hives

### Key Hierarchy

The five predefined root keys are **user-mode concepts** — the kernel internally uses `\Registry\Machine` and `\Registry\User` as the true roots:

| Predefined Key | Kernel Path | Notes |
|---|---|---|
| `HKEY_LOCAL_MACHINE` (HKLM) | `\Registry\Machine` | System-wide settings; all users |
| `HKEY_USERS` (HKU) | `\Registry\User` | All loaded user hives |
| `HKEY_CURRENT_USER` (HKCU) | `\Registry\User\<SID>` | Symbolic alias to current user's hive |
| `HKEY_CLASSES_ROOT` (HKCR) | Merged view | HKLM\Software\Classes + HKCU\Software\Classes |
| `HKEY_CURRENT_CONFIG` (HKCC) | `\Registry\Machine\System\CurrentControlSet\Hardware Profiles\Current` | Current hardware profile |

### Registry Virtualization

For 32-bit legacy applications on 64-bit Windows, writes to `HKLM\Software` are redirected to per-user locations to prevent elevation of privilege:
- Writes redirect to: `HKEY_USERS\<SID>\_Classes\VirtualStore\Machine\Software\`
- Reads check the per-user location first, then fall back to the real `HKLM\Software`
- Applies only to processes flagged as requiring virtualization (no manifest, or `requestedExecutionLevel` not declared)
- Registry virtualization does **not** apply to 64-bit processes or processes running elevated

Additionally, the 64-bit registry has a **reflection** model for 32-bit processes:
- `HKLM\Software\Wow6432Node` — 32-bit view of Software hive for 32-bit processes on 64-bit OS
- Accessed transparently by 32-bit applications via `KEY_WOW64_32KEY` flag

### Critical Server Registry Paths

```
# Service configuration
HKLM\SYSTEM\CurrentControlSet\Services\<ServiceName>

# Boot configuration
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\BootExecute
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\PagingFiles

# Network configuration
HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters

# Security policies
HKLM\SYSTEM\CurrentControlSet\Control\Lsa
HKLM\SECURITY\Policy

# Startup programs
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run

# VSS configuration
HKLM\SYSTEM\CurrentControlSet\Services\VSS
HKLM\SYSTEM\CurrentControlSet\Services\VolSnap

# NVMe native mode (Windows Server 2025)
HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides
  Value: 1176759950 (REG_DWORD) = 1  → enables native NVMe I/O path
```

---

## 4. Services and Processes

### Service Types

Services are registered in `HKLM\SYSTEM\CurrentControlSet\Services\<Name>`:

| Type Value | Name | Description |
|---|---|---|
| `0x1` | Kernel Driver | Kernel-mode driver (e.g., `disk.sys`, `tcpip.sys`) |
| `0x2` | File System Driver | File system kernel driver (e.g., `ntfs.sys`) |
| `0x10` | Win32OwnProcess | Runs in its own dedicated process |
| `0x20` | Win32ShareProcess | Shares a `svchost.exe` process with other services |
| `0x50` | Win32OwnProcess + Interactive | Own process, can interact with desktop (deprecated) |
| `0x60` | Win32ShareProcess + Interactive | Shared process with desktop access (deprecated) |

### svchost.exe Grouping and Isolation

`svchost.exe` (Service Host) is the container for `Win32ShareProcess` services. Each instance loads a DLL specified by the service's `ServiceDll` value:
```
HKLM\SYSTEM\CurrentControlSet\Services\<Name>\Parameters\ServiceDll
```

Services are grouped into named groups (e.g., `netsvcs`, `LocalServiceNoNetwork`, `DcomLaunch`, `LocalSystemNetworkRestricted`). The group name is specified in the service's `SvcHostGroup` value and in:
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Svchost
```

**Service Isolation (Windows 10 1703+ / Windows Server 2016+)**:
On systems with more than 3.5 GB RAM, services run in individual `svchost.exe` instances (one service per host process), greatly improving isolation and fault containment. This means a crash or exploit in one service cannot affect services in other processes.

Service tags (stored in the thread's `SubProcessTag` in the TEB) enable identifying which service within a shared host generated a given thread or network connection.

### Service Accounts

| Account | SID | Capabilities | Use Case |
|---|---|---|---|
| `LocalSystem` | `S-1-5-18` | Full local privileges, network access as machine account | Legacy services requiring maximum privilege |
| `LocalService` | `S-1-5-19` | Reduced privileges, anonymous network access | Low-privilege services not needing domain auth |
| `NetworkService` | `S-1-5-20` | Reduced local privileges, network as machine account | Services requiring domain-authenticated network access |
| `gMSA` (Group Managed Service Account) | Domain account | Auto-managed passwords (120-char), usable across server farms | Clustered/farm services needing domain identity |
| `dMSA` (Delegated MSA, Server 2025) | Domain account (machine-bound) | Machine-identity-bound authentication, Credential Guard integration | Replacing traditional service accounts; prevents kerberoasting |

**dMSA (Windows Server 2025)**: A dMSA binds authentication to specific machine identities listed in AD. The secret (derived from the machine account credential) is held only by the Domain Controller — it cannot be extracted from the service host. Combined with Credential Guard, the TGT for the service account is isolated in `LSAIso.exe`. Migration from a traditional service account to dMSA automatically disables the original account once complete.

### Service Recovery Options

Each service can define up to three recovery actions (First/Second/Subsequent failures):
- **Take No Action**: SCM does nothing
- **Restart the Service**: SCM restarts after a configurable delay
- **Run a Program**: Executes a specified command
- **Restart the Computer**: Reboots the system

Recovery configuration is in `HKLM\SYSTEM\CurrentControlSet\Services\<Name>` values: `FailureActions`, `FailureActionsOnNonCrashFailures`.

### Service SID Types

Services can be assigned a **per-service SID** for access control granularity:
- `Unrestricted`: Service gets its own unique SID (`S-1-5-80-<hash>`)
- `Restricted`: Service SID added as a deny-only SID (limits privilege escalation)
- `None`: No per-service SID (legacy behavior)

Configure with: `sc sidtype <ServiceName> unrestricted|restricted|none`

---

## 5. Memory Management

### Virtual Address Space Layout (x64)

On 64-bit Windows Server, the virtual address space is enormous but only a portion is practically usable:

| Region | Range (approximate) | Size | Notes |
|---|---|---|---|
| User space | `0x0000000000000000` – `0x00007FFFFFFFFFFF` | 128 TB | Per-process private virtual address space |
| Kernel space | `0xFFFF800000000000` – `0xFFFFFFFFFFFFFFFF` | 128 TB | Shared across all processes |
| Non-paged pool | Kernel space region | Dynamic (capped ~TB range) | Must remain in physical RAM |
| Paged pool | Kernel space region | Dynamic | Can be paged to disk |
| System PTEs | Kernel space region | Large | Used for mapping I/O, MDLs, driver allocations |
| Hyperspace | Kernel space region | 4 MB | Temporary mapping space used by Memory Manager |

### Paging and Working Sets

- The default page size is **4 KB**; large pages are **2 MB** on x64 (require `SeLockMemoryPrivilege`)
- **Working set**: The subset of a process's virtual pages currently resident in physical RAM
- When physical memory pressure increases, the Memory Manager trims working sets (soft fault recovery) or pages frames out to `pagefile.sys` (hard fault)
- **Pagefile** (`pagefile.sys`): Can span multiple volumes; size configurable via System Properties or registry
- Multiple pagefiles on separate spindles improve paging throughput

### Non-Paged Pool vs. Paged Pool

| Pool | Behavior | Use Cases |
|---|---|---|
| Non-Paged Pool (NPP) | Never swapped to disk; always physically resident | Interrupt handlers, DPC routines, hardware DMA descriptors |
| Paged Pool | May be paged to disk when not in use | Driver allocations that don't run at IRQL >= DISPATCH_LEVEL |
| Non-Paged Pool NX | NPP with Execute-Never page protection (post-Win8) | Security hardening; prevents code injection via pool |

Normal NPP usage: 200–400 MB. Abnormally large NPP (> 1 GB) typically indicates a driver memory leak; diagnose with poolmon.exe or WinDbg `!poolused` / `!pool`.

### Memory Partitions (Windows Server 2016+)

Memory partitions provide VM-level isolation under Hyper-V:
- Each partition has its own working set, paging policies, and memory counters
- Enables per-VM memory priority and memory reclaim without host-level page sharing
- Managed through the Hyper-V hypervisor in coordination with the guest Memory Manager
- On Hyper-V hosts, the hypervisor uses memory ballooning and second-level address translation (SLAT / EPT) to multiplex physical memory across VMs

### Address Windowing Extensions (AWE)

AWE allows 32-bit applications to access more than 4 GB of physical memory through windowed mapping:
- Application reserves physical memory as non-paged pages
- `AllocateUserPhysicalPages` + `MapUserPhysicalPages` map portions into the 32-bit address space
- Requires `SeLockMemoryPrivilege`
- Largely superseded by 64-bit addressing on modern systems

---

## 6. Storage Subsystem

### Windows Storage Stack (Top to Bottom)

```
Application (ReadFile / WriteFile)
    │
    ▼
File System Driver
    ntfs.sys / refs.sys — translates file operations to volume-relative I/O
    │
    ▼
Volume Snapshot / Filter Drivers
    volsnap.sys  — VSS volume snapshot driver
    fvevol.sys   — BitLocker encryption filter
    │
    ▼
Volume Manager
    volmgr.sys   — manages logical volumes, creates \Device\HarddiskVolumeX objects
    │
    ▼
Partition Manager
    partmgr.sys  — discovers GPT/MBR partitions, creates partition PDOs
    │
    ▼
Disk Class Driver
    disk.sys     — abstracts physical disk operations (+ classpnp.sys SCSI class library)
    │
    ▼
Storage Port Driver
    storport.sys — high-performance port driver for FC, iSCSI, NVMe (via StorNVMe.sys), RAID HBAs
    scsiport.sys — legacy SCSI port driver (deprecated path)
    ataport.sys  — ATA/SATA devices
    │
    ▼
Miniport Driver (vendor-specific)
    storahci.sys — AHCI SATA miniport
    StorNVMe.sys — NVMe miniport (native NVMe path in Server 2025)
    └─ Physical Hardware (NVMe, SAS, SATA, FC)
```

Storage Spaces (`spaceport.sys`) inserts between the volume layer and the disk layer, presenting virtual disks to `volmgr.sys` while distributing I/O across pool drives with configurable resiliency (mirror, parity, simple).

### NTFS Architecture

NTFS (`ntfs.sys`) is a journaled, recoverable file system based on B-trees:

**Master File Table (MFT)**:
- Every file and directory is represented by a record in the MFT
- Default MFT record size: 1 KB; each record stores file attributes (name, timestamps, security, data extents)
- Small files (< ~700 bytes) store data directly in the MFT record (resident data)
- Larger files store data in extents referenced from the MFT (non-resident data)
- The MFT itself is a special file (`$MFT`) at a fixed location for boot purposes

**Journaling (NTFS Log)**:
- Transaction log file (`$LogFile`) records metadata changes before they're committed
- Crash recovery replays or rolls back uncommitted transactions
- Log file size: typically 64 MB; configurable via `chkdsk /L:<size>`

**Key NTFS metadata files**:
- `$MFT` — Master File Table
- `$MFTMirr` — Partial MFT mirror for recovery
- `$LogFile` — NTFS journal
- `$Volume` — Volume metadata (version, flags, name)
- `$AttrDef` — Attribute type definitions
- `$Bitmap` — Cluster allocation bitmap
- `$Boot` — Boot sector and bootstrap code
- `$BadClus` — Bad cluster tracking
- `$Secure` — Security descriptor database (shared SDs, avoiding duplication per-file)
- `$Upcase` — Unicode uppercase table
- `$Extend\$UsnJrnl` — Update Sequence Number journal (change journal)
- `$Extend\$Quota` — Disk quota tracking
- `$Extend\$ObjId` — Object IDs for DFS link tracking

**EFS (Encrypting File System)**:
- Per-file/per-folder transparent encryption using a symmetric file encryption key (FEK)
- FEK is encrypted with the user's RSA public key and stored in the file's `$EFS` attribute
- Recovery agents can decrypt with their certificate if configured via Group Policy

**NTFS Limits**: Maximum file size: 256 TB; maximum volume size: 256 TB

### ReFS Architecture

ReFS (`refs.sys`) was introduced in Windows Server 2012 as a next-generation file system optimized for large-scale storage and resiliency:

**B+ Tree Structure**: ReFS uses B+ trees (vs. NTFS's B-tree), improving efficiency for large metadata sets and enabling faster directory operations at scale.

**Allocation-on-Write (Copy-on-Write Metadata)**:
- Metadata updates never overwrite in-place; new metadata is written to free space
- Old metadata remains valid until new metadata is committed
- Eliminates the need for a separate transaction log for metadata integrity
- 64-bit checksums are stored independently for all metadata structures

**Integrity Streams**:
- Optional per-file checksums using a modified CRC-32C algorithm stored in a separate "integrity stream"
- When combined with Storage Spaces (mirror or parity), detected corruption triggers automatic online repair

**Block Cloning**:
- Allows file regions to be cloned without copying data — O(1) copy operation
- Used by Hyper-V for rapid VHD/VHDX checkpoint merge, expansion, and creation
- The VM Manager layer references the same physical blocks until a copy-on-write event occurs

**Sparse Valid Data Length (VDL)**:
- Creates sparse files that report a specific "valid" data length without actually zeroing storage
- Reduces fixed VHD creation from minutes to seconds
- Hyper-V uses sparse VDL for rapid provisioning of fixed-size disk images

**Mirror-Accelerated Parity**:
- Divides a volume into performance tier (mirrored SSD) and capacity tier (parity HDD/SSD)
- Hot writes land in the mirror tier; ReFS moves cold data to the parity tier in real time
- Only supported on Storage Spaces Direct (S2D)

**Data Integrity Scrubber**:
- Background process that periodically scans for latent corruptions (bit rot)
- When corruption is detected and a redundant copy exists (Storage Spaces mirror/parity), automatic online repair occurs without volume downtime

**ReFS Limits**: Maximum file size: 35 PB; maximum volume size: 35 PB

**ReFS Limitations** (vs. NTFS):
- Not bootable (cannot be used for the system/OS volume)
- No disk quotas
- No Offloaded Data Transfer (ODX)
- No NTFS transactions (`TxF`)
- Cannot shrink volumes

### Storage Spaces Architecture

Storage Spaces (`spaceport.sys`) provides software-defined storage:
- **Storage Pool**: Collection of physical disks (managed as a single capacity resource)
- **Virtual Disk (Space)**: Logical disk provisioned from the pool with resiliency type:
  - Simple (striped, no redundancy)
  - Mirror (2-way or 3-way; tolerates 1 or 2 disk failures)
  - Parity (RAID-5/6-like; capacity-efficient, write-intensive overhead)
- **Tiers**: A virtual disk can span a fast tier (SSD) and a capacity tier (HDD), with automatic tiering
- **Storage Spaces Direct (S2D)**: Hyper-converged variant using direct-attached storage across cluster nodes; uses NVMe/SSD as cache tier

### NVMe Native I/O (Windows Server 2025)

Prior to Windows Server 2025, all NVMe I/O was translated through the SCSI emulation layer — NVMe commands were wrapped in SCSI Request Blocks (SRBs), creating serialization overhead and limiting throughput to a single-queue model.

**Windows Server 2025 Native NVMe**:
- Introduced via October 2025 cumulative update; generally available, opt-in
- The redesigned stack uses `StorNVMe.sys` directly — no SCSI translation layer
- Implements lock-free I/O paths; removes shared locks and synchronization overhead from the kernel I/O path
- Exposes NVMe's native multi-queue model: up to 64,000 queues, 64,000 commands per queue

**Performance gains (DiskSpd 4K random read, NTFS)**:
- Up to **80% higher IOPS** vs. Windows Server 2022
- Up to **45% lower CPU cycles per I/O**

**Enable Native NVMe**:
```powershell
# Via registry (per-machine)
reg add "HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" `
    /v 1176759950 /t REG_DWORD /d 1 /f
```
Requires: Windows Server 2025 + October 2025 cumulative update or later; NVMe device using in-box Windows driver.

### Volume Shadow Copy Service (VSS)

VSS provides point-in-time consistent snapshots while applications continue running.

**Three Core Components**:
- **VSS Service** (`vssvc.exe`): Coordinator; starts on demand and orchestrates the other components
- **VSS Requestor**: Backup application that requests snapshot creation (e.g., Windows Server Backup, third-party backup software, `diskshadow.exe`)
- **VSS Writer**: Application-specific component that ensures data consistency (e.g., SQL Writer, Registry Writer, NTDS Writer for AD)
- **VSS Provider**: Creates and maintains the shadow copy:
  - *System Provider* (`swprv.dll` + `volsnap.sys`): Ships in-box; uses copy-on-write; diff area must be on NTFS
  - *Software Provider*: Third-party DLL + kernel filter driver (e.g., storage vendor)
  - *Hardware Provider*: Storage array–level snapshots via SAN hardware

**Shadow Copy Creation Process** (10-step sequence):
1. Requestor asks VSS to enumerate writers and gather XML metadata
2. Each writer describes its data stores and restore methods
3. VSS notifies writers to prepare data (flush caches, complete transactions)
4. Writers complete preparation and notify VSS
5. VSS freezes application write I/O (max 60 seconds)
6. VSS instructs provider to create the snapshot (max 10 seconds with I/O frozen)
7. VSS releases file system write I/O
8. VSS thaws application write I/O
9. If failed, requestor retries or alerts administrator
10. On success, VSS returns shadow copy location to requestor; optional auto-recovery phase adjusts the snapshot for consistency

**Copy-on-Write (System Provider)**: Before any block on the original volume is overwritten, the original content is saved to the "diff area" (shadow copy storage area). The snapshot is reconstructed by combining the current volume state with the saved original blocks.

**VSS Tools**:
- `vssadmin.exe` — list/delete shadows, resize shadow storage
- `diskshadow.exe` — full VSS requestor for scripted operations (server-only)

**Key registry paths**:
```
HKLM\SYSTEM\CurrentControlSet\Services\VSS
HKLM\SYSTEM\CurrentControlSet\Services\VolSnap
HKLM\SYSTEM\CurrentControlSet\Control\BackupRestore\FilesNotToSnapshot
```

---

## 7. Networking Stack

### NDIS 6.x Architecture

NDIS (Network Driver Interface Specification) is the framework governing network miniport and protocol drivers:

| Driver Type | Role |
|---|---|
| Miniport driver | Hardware-specific; communicates with NIC via NDIS |
| Protocol driver | Implements network protocols (TCP/IP stack: `tcpip.sys`) |
| Filter driver (LWF) | Lightweight filter; sits between miniport and protocol (e.g., packet capture, QoS) |
| Intermediate driver | Virtual adapters (VPN, NIC teaming) |

NDIS 6.0 (Vista+) introduced:
- **Net Buffer Lists (NBL)**: More efficient packet descriptor chains replacing NDIS 5 NDIS_PACKET
- **TCP/IP offload support** (LSO, RSC, checksum offload)
- **Receive-side scaling (RSS)**: Distributes packet processing across CPU cores using hash of IP/port tuples
- IPv6 offload support
- Simplified Lightweight Filter (LWF) driver model

Current shipping version: NDIS 6.8x (Windows Server 2025).

### Windows Filtering Platform (WFP)

WFP is the framework for network packet inspection, filtering, and modification at multiple TCP/IP stack layers:
- **Base Filtering Engine (BFE)**: User-mode service (`bfe.dll` in `svchost.exe`) managing filter policy
- **Generic Filtering Engine (GFE)**: Kernel-mode component in `tcpip.sys` enforcing policies
- **WFP Callout API**: Allows third-party drivers to inject custom processing logic at any layer
- **Layers**: INBOUND/OUTBOUND at Ethernet frame, IP packet, transport (TCP/UDP), application (stream), ALE (Application Layer Enforcement)

WFP is used by: Windows Firewall (`mpssvc`), IPsec (`ikeext`), network inspection engines (antivirus/IPS), VPN clients.

### TCP/IP Stack

The entire TCP/IP stack ships in `tcpip.sys` (kernel mode):
- IPv4 and IPv6 (dual-stack, RFC-compliant)
- TCP, UDP, ICMP, ICMPv6, IGMP
- Connects to NICs via NDIS miniport adapters
- TCP offload (chimney, not widely used today; RSC/LSO/checksum offload are standard)

User-mode socket API: `winsock2` (`ws2_32.dll`) → AFD driver (`afd.sys`, "Ancillary Function Driver") → `tcpip.sys`

HTTP.sys (`http.sys`): Kernel-mode HTTP listener; IIS, WCF, and WAC use it to avoid context switches for every HTTP request.

### SMB 3.x Architecture

SMB (Server Message Block) protocol handles Windows file sharing, implemented in:
- Client: `mrxsmb.sys` (redirector) + `mrxsmb20.sys` (SMB2/3 extensions)
- Server: `srv2.sys` (SMB2/3 server) + `srvnet.sys` (network layer)
- Service: `LanmanServer` (`srv.exe`) and `LanmanWorkstation` (`wkssvc.dll`)

**SMB 3.x Key Features**:

| Feature | Introduced | Description |
|---|---|---|
| SMB Multichannel | SMB 3.0 (Server 2012) | Uses multiple network paths simultaneously; auto-detected via RSS-capable or multiple NICs |
| SMB Direct (RDMA) | SMB 3.0 | Zero-copy transfers over RDMA NICs (iWARP, RoCE, InfiniBand); two RDMA connections per SMB session per interface |
| SMB Encryption | SMB 3.0 | AES-128-CCM per-share or per-session encryption without IPsec |
| SMB Transparent Failover | SMB 3.0 | Clients survive server failover without losing handles (Scale-Out File Server) |
| SMB Compression | SMB 3.1.1 (Server 2019) | LZNT1, LZ4, ZSTD algorithms; auto-negotiated |
| SMB over QUIC | SMB 3.1.1 (Server 2022+) | SMB tunneled over QUIC (UDP/443) instead of TCP/445; TLS 1.3 encrypted tunnel |

**SMB Multichannel** auto-detects:
- Multiple NICs → uses all available paths
- RSS-capable NICs → creates multiple parallel connections over the same NIC
- RDMA NICs → activates SMB Direct for maximum throughput with minimum CPU

**SMB over QUIC**:
- Introduced in Windows Server 2022 Azure Edition; available in all editions in Server 2025
- QUIC (RFC 9000): UDP-based transport with built-in TLS 1.3, 0-RTT, and multiplexed streams
- Operates on UDP port 443 (same as HTTPS) — firewall-friendly
- All SMB features (multichannel, signing, compression, continuous availability) work within the QUIC tunnel
- Server requires a PKI certificate; mutual TLS authentication is mandatory

### NIC Teaming and SET

**NIC Teaming (LBFO)**:
- Combines multiple NICs into a single logical interface for bandwidth aggregation and failover
- Managed via `Set-NetLbfoTeam` PowerShell cmdlets
- **Incompatible with RDMA** — teamed RDMA NICs lose RDMA capability

**Switch Embedded Teaming (SET)**:
- Alternative to LBFO for Hyper-V environments (Server 2016+)
- Integrates NIC teaming directly into the Hyper-V Virtual Switch
- **Preserves RDMA capability** — can be used with RDMA NICs alongside vNICs
- Required for converged networking scenarios (storage + management + VM traffic on same adapters)
- Configured via: `New-VMSwitch -EnableEmbeddedTeaming $true`

### DNS Resolution Order

Windows name resolution proceeds through (configurable via `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters`):
1. DNS cache (`ipconfig /displaydns`)
2. DNS server query (configured in NIC properties or DHCP)
3. HOSTS file (`C:\Windows\System32\drivers\etc\hosts`)
4. NetBIOS name cache, WINS (if configured)
5. NetBIOS broadcast (local subnet only)
6. LMHOSTS file (`C:\Windows\System32\drivers\etc\lmhosts`)

---

## 8. Security Architecture

### Security Reference Monitor and Token Model

Every process and thread has an **access token** containing:
- User SID (`S-1-5-21-<domain>-<RID>`)
- Group SIDs (including domain groups, built-in groups)
- Privilege set (e.g., `SeBackupPrivilege`, `SeRestorePrivilege`, `SeDebugPrivilege`)
- Integrity level (Low / Medium / High / System)
- Logon session ID

When a process attempts to access a securable object, the SRM:
1. Retrieves the object's Security Descriptor (SD) containing a DACL
2. Iterates the DACL's ACEs (Access Control Entries), each containing a SID + access mask
3. Grants access if the token's SIDs match Allowed ACEs and no Deny ACE applies
4. Generates audit events if requested by SACL (System ACL) entries

SIDs follow the format `S-1-<authority>-<sub-authority...>-<RID>`. Well-known SIDs:
- `S-1-1-0` — Everyone
- `S-1-5-18` — LocalSystem
- `S-1-5-19` — LocalService
- `S-1-5-20` — NetworkService
- `S-1-5-21-<domain>-500` — Domain/local Administrator

### Authentication Architecture

**LSASS (`lsass.exe`)**: Hosts all authentication packages as DLLs loaded into its process:
- `kerberos.dll` — Kerberos v5 (primary protocol in domain environments)
- `msv1_0.dll` — NTLM / NTLMv2 (fallback and local authentication)
- `tspkg.dll` — CredSSP (RDP delegation)
- `wdigest.dll` — Digest authentication (disabled by default since Server 2012 R2)
- `schannel.dll` — TLS/SSL (certificate-based)
- `negotiate.dll` — SPNEGO (negotiates between Kerberos and NTLM)

**Kerberos**: Default for domain-joined machines
- Tickets issued by KDC (Domain Controller running `kdcsvc.dll`)
- TGT (Ticket Granting Ticket): Encrypted with KDC's secret, proves identity to KDC
- Service Ticket: Encrypted with target service's secret; client presents to service
- Ticket lifetime: 10 hours (default); renewal up to 7 days

**NTLM**: Challenge-response fallback (used when Kerberos unavailable)
- NTLMv2 is the current version; NTLMv1 disabled by default in Server 2016+
- Three-message challenge-response using MD5/HMAC-MD5

**SAM (`sam.dll`, backed by `SAM` hive)**: Manages local user accounts and their credential hashes. Protected by SYSKEY encryption.

### Virtualization-Based Security (VBS) and Credential Guard

**VBS** uses the Hyper-V hypervisor to create an isolated execution environment called **Virtual Secure Mode (VSM)**:
- The hypervisor enforces memory isolation between the normal OS and the secure world
- Even a fully compromised kernel cannot access VSM memory
- Requires: UEFI Secure Boot, TPM 2.0 (for key protection), Hyper-V, 64-bit CPU with SLAT

**Credential Guard** (`LSAIso.exe` — Isolated LSA):
- `lsass.exe` (normal OS) communicates with `LSAIso.exe` (runs inside VSM) via RPC
- `LSAIso.exe` stores and processes: NTLM hashes, Kerberos TGTs, Kerberos session keys
- These secrets are never accessible to the normal kernel or user-mode processes
- **VSM master key** protects persisted VSM data; protected by TPM (hardware-bound)
- Enabled by default on Server 2025 (and Windows 11 22H2+) on capable hardware

**Credential Guard Limitations**:
- Does not protect: local accounts, Microsoft accounts, NTLMv1/v2 prompted credentials, Kerberos service tickets (only TGTs protected)
- Breaks: unconstrained Kerberos delegation, DES encryption, CredSSP single-sign-on
- Does not protect the Active Directory database on domain controllers

**Windows Defender System Guard**:
- Uses Measured Boot + TPM to attest the integrity of the system at runtime
- Works via `tcblaunch.exe` and the Secure Launch mechanism
- Remote Attestation allows compliance systems to verify boot integrity

### LSASS Protection

- **PPL (Protected Process Light)**: `lsass.exe` runs as a Protected Process in Server 2012+; limits which processes can attach/inject
- **Credential Guard**: Moves secrets out of LSASS into LSAIso (VSM)
- **LSA Audit**: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL` = 1 enables PPL mode

---

## 9. WMI / CIM Architecture

### WMI Repository and Namespace

WMI (Windows Management Instrumentation) is Microsoft's implementation of the DMTF CIM (Common Information Model) standard:
- Repository location: `C:\Windows\System32\wbem\Repository\`
- Default namespace: `root\cimv2` (most OS classes live here)
- Other key namespaces: `root\MicrosoftDNS`, `root\MicrosoftIISv2`, `root\MSCluster`, `root\SecurityCenter2`
- WMI service: `Winmgmt` (`wbemcore.dll` hosted in `svchost.exe`)

**WMI Provider Architecture**:
- Providers are COM servers (DLLs or executables) that supply data to WMI
- They register under: `HKLM\SOFTWARE\Microsoft\WBEM\CIMOM\...` and `root\cimv2\Win32_ProviderEx`
- Provider types: Instance, Method, Event, Class, Property
- Providers run in a `wmiprvse.exe` (WMI Provider Host) process for isolation; one host per provider group

### CIM and WS-Management

- **CIMv2 cmdlets** (`Get-CimInstance`, `Invoke-CimMethod`) use WS-Man (WinRM) as the transport by default
- **WMI cmdlets** (`Get-WmiObject`, legacy) use DCOM — requires RPC ports open (135 + dynamic range)
- CIM over WinRM is firewall-friendly (port 5985 HTTP / 5986 HTTPS)
- Windows Server 2012 introduced ~1,000 new CIM-based cmdlets replacing WMI/DCOM patterns

### PowerShell Remoting (WinRM)

WinRM (Windows Remote Management) is Microsoft's implementation of WS-Management (WS-Man) protocol:
- **WinRM service**: `winrm` (hosted in `svchost.exe`)
- Default ports: 5985 (HTTP), 5986 (HTTPS)
- Transport: SOAP over HTTP/HTTPS; authentication via Kerberos, NTLM, CredSSP, Certificate, or Basic
- `Enable-PSRemoting` / `winrm quickconfig` configure listeners and firewall rules

**PowerShell Remoting Modes**:
- `Enter-PSSession`: Interactive 1:1 remote session
- `Invoke-Command -ComputerName`: Fan-out execution across multiple hosts
- `New-PSSession`: Persistent reusable session object

**Windows Admin Center (WAC)**:
- Browser-based management gateway (installed on a Windows PC or Server gateway)
- All communication from WAC to managed servers uses PowerShell and WMI over WinRM
- WinRM HTTP: port 5985; WinRM HTTPS: port 5986 from WAC gateway to managed nodes
- WAC gateway itself listens on HTTPS (port 443 by default, configurable)
- No agent required on managed servers — uses built-in WinRM

### Key WMI Classes for Server Administration

```powershell
Get-CimInstance Win32_OperatingSystem     # OS info, uptime, memory
Get-CimInstance Win32_ComputerSystem      # Hardware, domain membership
Get-CimInstance Win32_Service             # Service enumeration
Get-CimInstance Win32_Process             # Process list
Get-CimInstance Win32_DiskDrive           # Physical disks
Get-CimInstance Win32_LogicalDisk         # Volumes / drive letters
Get-CimInstance Win32_NetworkAdapter      # Network adapters
Get-CimInstance Win32_NetworkAdapterConfiguration  # IP config
Get-CimInstance Win32_EventLog            # Event log metadata
```

---

## 10. Server Core vs. Desktop Experience

### Installation Options

| Aspect | Server Core | Server with Desktop Experience |
|---|---|---|
| Disk footprint | ~4 GB smaller | Larger (all GUI shell packages) |
| Attack surface | Reduced (fewer components, less code) | Larger |
| GUI shell packages | None | `Microsoft-Windows-Server-Shell-Package`, `Server-Gui-Mgmt-Package`, `Server-Gui-RSAT-Package` |
| Desktop | No desktop shell | Full Windows shell |
| Management method | Remote: PowerShell, RSAT, WAC; Local: CLI, sconfig | Any method including local GUI tools |
| Default in Server 2022/2025 | Not default; selected at install | Must be explicitly chosen at install |

Server Core omits:
- Desktop shell, Explorer, Taskbar
- MMC snap-ins (Event Viewer, Disk Management, Device Manager, Services, Server Manager)
- Microsoft Edge / Internet Explorer
- Control Panel, Windows Update GUI
- Accessibility tools, audio, Out-of-Box Experience (OOBE)
- Hyper-V Manager GUI, PowerShell ISE, `mstsc.exe` (RDP client)
- `Perfmon.exe`, `Resmon.exe`, `Diskmgmt.msc`, `Devmgmt.msc`

Server Core retains:
- `cmd.exe`, PowerShell, `regedit.exe`
- `diskpart.exe`, `fsutil.exe`, `wevtutil.exe`, `taskmgr.exe`
- `Taskkill.exe`, `netsh.exe`, `sconfig.exe`
- Remote Desktop Services (as a *server* accepting connections, not the RDP client)
- All server roles listed below

### Roles Available on Server Core

The following server roles fully support Server Core (no GUI required):

| Role | Notes |
|---|---|
| Active Directory Domain Services | All DC operations; use PowerShell and `ntdsutil` |
| Active Directory Certificate Services | CA role (not Web Enrollment) |
| Active Directory Federation Services | Fully supported |
| Active Directory Lightweight Directory Services | |
| Active Directory Rights Management Services | |
| DHCP Server | |
| DNS Server | |
| File and Storage Services | NTFS, ReFS, SMB, DFS, Storage Spaces |
| Hyper-V | Primary use case for Server Core; Hyper-V Manager managed remotely |
| IIS (Web Server) | Fully supported |
| Network Policy and Access Services (NPAS) | |
| Print and Document Services | |
| Remote Access (VPN, DirectAccess, Routing) | |
| Remote Desktop Services | Session Host, Licensing; Connection Broker requires Desktop Experience |
| Windows Server Update Services (WSUS) | |
| Failover Clustering | |

Roles that **require Desktop Experience**:
- Remote Desktop Connection Broker (limited Server Core support)
- Remote Desktop Web Access
- Remote Desktop Gateway (requires IIS GUI components)

### Local Management Tools

**sconfig.exe**: Text-based configuration utility that auto-launches at Server Core logon:
- Network configuration (IP, DNS, gateway)
- Computer name and domain membership
- Windows Update settings
- Remote Desktop enable/disable
- WinRM / PowerShell remoting enable/disable
- Date/time, telemetry, activate Windows

**Remote Management Stack**:
```
Windows Admin Center (WAC)  ←── HTTPS/443 ──→  WAC Gateway
                                                      │
                                              WinRM (5985/5986)
                                                      │
                                              Managed Server Core
```

**Key PowerShell modules for Server Core management**:
```powershell
# Install roles/features
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Network configuration
New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 10.0.0.10 -PrefixLength 24
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 10.0.0.1

# Domain join
Add-Computer -DomainName "corp.contoso.com" -Credential (Get-Credential)

# Service management
Get-Service | Where-Object Status -eq Running
Set-Service -Name W32Time -StartupType Automatic

# Remote management
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "10.0.0.*"
```

---

## Quick Reference: Key Binaries and Their Locations

| Binary | Location | Role |
|---|---|---|
| `ntoskrnl.exe` | `C:\Windows\System32\` | NT kernel and Executive |
| `hal.dll` | `C:\Windows\System32\` | Hardware Abstraction Layer |
| `smss.exe` | `C:\Windows\System32\` | Session Manager |
| `csrss.exe` | `C:\Windows\System32\` | Win32 subsystem runtime |
| `wininit.exe` | `C:\Windows\System32\` | Session 0 initializer |
| `winlogon.exe` | `C:\Windows\System32\` | Interactive logon handler |
| `services.exe` | `C:\Windows\System32\` | Service Control Manager |
| `lsass.exe` | `C:\Windows\System32\` | Authentication/credential store |
| `lsaiso.exe` | `C:\Windows\System32\` | Isolated LSA (Credential Guard, VSM) |
| `svchost.exe` | `C:\Windows\System32\` | Service host container |
| `bootmgfw.efi` | `\EFI\Microsoft\Boot\` on ESP | UEFI Boot Manager |
| `winload.efi` | `C:\Windows\System32\` | OS Loader (UEFI) |
| `ntfs.sys` | `C:\Windows\System32\drivers\` | NTFS file system driver |
| `refs.sys` | `C:\Windows\System32\drivers\` | ReFS file system driver |
| `tcpip.sys` | `C:\Windows\System32\drivers\` | TCP/IP stack |
| `http.sys` | `C:\Windows\System32\drivers\` | Kernel-mode HTTP listener |
| `StorNVMe.sys` | `C:\Windows\System32\drivers\` | NVMe miniport (native NVMe path in 2025) |
| `volsnap.sys` | `C:\Windows\System32\drivers\` | VSS volume snapshot driver |
| `spaceport.sys` | `C:\Windows\System32\drivers\` | Storage Spaces driver |
| `vssvc.exe` | `C:\Windows\System32\` | VSS coordinator service |
| `wmiprvse.exe` | `C:\Windows\System32\wbem\` | WMI Provider Host |
