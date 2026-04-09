# Operating System Agent Library — Comprehensive Plan

Complete plan for the OS domain agent hierarchy covering Windows Server, Windows Client, Enterprise Linux distributions, and macOS. Each technology includes edition breakdowns, version-specific features, key feature deep-dives, and scripting strategy.

---

## Domain Structure Overview

```
agents/os/
├── SKILL.md                              # OS domain router
├── references/
│   ├── concepts.md                       # Kernel architectures, process models, filesystems, networking
│   ├── paradigm-windows.md               # Windows ecosystem (NT kernel, registry, WMI, COM, .NET)
│   ├── paradigm-linux.md                 # Linux ecosystem (kernel, systemd, package mgmt, POSIX)
│   └── paradigm-macos.md                 # macOS ecosystem (XNU kernel, launchd, frameworks, Mach-O)
│
├── windows-server/                       # Technology: Windows Server
├── windows-client/                       # Technology: Windows Desktop (10, 11)
├── rhel/                                 # Technology: Red Hat Enterprise Linux
├── ubuntu/                               # Technology: Ubuntu (Desktop + Server LTS)
├── debian/                               # Technology: Debian
├── rocky-alma/                           # Technology: Rocky Linux / AlmaLinux (combined — binary-compatible)
├── sles/                                 # Technology: SUSE Linux Enterprise
└── macos/                                # Technology: macOS
```

### Scripting Strategy by OS Family

| OS Family | Primary Shell | Script Extension | Modules/Tools |
|---|---|---|---|
| Windows Server | PowerShell 5.1 / 7.x | `.ps1` | ServerManager, FailoverClusters, Hyper-V, ActiveDirectory, Storage |
| Windows Client | PowerShell 5.1 / 7.x | `.ps1` | DISM, BitLocker, Defender, WindowsUpdate, Hyper-V |
| RHEL / Rocky / Alma | Bash | `.sh` | systemctl, firewall-cmd, nmcli, podman, dnf, sestatus |
| Ubuntu / Debian | Bash | `.sh` | systemctl, ufw/nftables, netplan, apt, snap, apparmor |
| SLES | Bash | `.sh` | systemctl, zypper, yast, wicked, btrfs, SUSEConnect |
| macOS | zsh / Bash | `.sh` | networksetup, diskutil, profiles, mdm, defaults, launchctl |

---

## 1. Windows Server

### Editions by Version

#### Windows Server 2016

| Feature | Essentials | Standard | Datacenter |
|---|:---:|:---:|:---:|
| **Licensing model** | Per-server (25 users/50 devices) | Per-core (16-core min) + CAL | Per-core (16-core min) + CAL |
| **Max RAM** | 64 GB | 24 TB | 24 TB |
| **Max CPU sockets** | 2 | 64 | 64 |
| **Max logical processors** | N/A (2 socket cap) | 512 | 512 |
| **Hyper-V VM rights** | None | 2 VMs | Unlimited VMs |
| **Storage Spaces Direct** | No | No | Yes |
| **Shielded VMs / HGS** | No | No | Yes |
| **Storage Replica** | No | Limited (1 partnership, 1 resource group, 2 TB) | Unlimited |
| **Network Controller / SDN** | No | No | Yes |
| **Nano Server** | No | Yes | Yes |
| **Windows Containers** | No | Unlimited | Unlimited |
| **Hyper-V Containers** | No | 2 | Unlimited |

*Also available: Hyper-V Server 2016 — free standalone hypervisor (no Windows workloads, hypervisor only)*

**Headline features introduced in 2016:**
- Nano Server (minimal footprint deployment — later downgraded to container base OS only in 2019)
- Windows Containers and Hyper-V Containers (first native Docker support)
- Shielded Virtual Machines (guarded fabric, Host Guardian Service)
- Storage Spaces Direct (software-defined HCI storage, Datacenter only)
- Storage Replica (synchronous/asynchronous block replication)
- Nested Virtualization
- Network Controller and SDN stack (Datacenter only)
- Rolling Cluster OS Upgrade
- PowerShell 5.1 built-in
- Credential Guard, Device Guard (VBS-based credential isolation)
- Just Enough Administration (JEA) — constrained PowerShell remoting
- ReFS v2 (integrity streams, block cloning)

#### Windows Server 2019

| Feature | Essentials | Standard | Datacenter |
|---|:---:|:---:|:---:|
| **Licensing model** | Per-server (25 users/50 devices) | Per-core + CAL | Per-core + CAL |
| **Max RAM** | 64 GB | 24 TB | 24 TB |
| **Hyper-V VM rights** | None | 2 VMs | Unlimited VMs |
| **Storage Spaces Direct** | No | No | Yes |
| **Shielded VMs** | No | No | Yes |
| **Storage Replica** | No | Limited | Unlimited |
| **SDN stack** | No | No | Yes |
| **Storage Migration Service** | Yes | Yes | Yes |
| **System Insights** | Yes | Yes | Yes |
| **Windows Admin Center** | Yes | Yes | Yes |

*Also available: Hyper-V Server 2019 — free standalone hypervisor (last free Hyper-V Server release)*

**Headline features introduced in 2019:**
- Windows Admin Center (WAC) — browser-based server management replacing Server Manager
- System Insights — predictive analytics with ML
- Storage Migration Service — migrate files/shares/identity from legacy servers (back to WS2003)
- Storage Replica brought to Standard edition (restricted: 2 TB, 1 partnership)
- Kubernetes support (beta Windows node support)
- HCI improvements (S2D persistent memory support, dedup on ReFS, 4 PB cluster volumes, cluster sets)
- Hybrid Azure integration (Azure Network Adapter, Azure Backup, Azure File Sync in WAC)
- Windows Defender Advanced Threat Protection (ATP) — endpoint detection and response
- OpenSSH built-in (client and server)
- Linux containers on Windows Server (LCOW)
- Shielded VMs extended to Linux guests
- Encrypted SDN Networks — encrypt traffic between VMs on same subnet
- Precision Time Protocol (PTP) and Leap Second support

#### Windows Server 2022

| Feature | Essentials | Standard | Datacenter | Datacenter: Azure Edition |
|---|:---:|:---:|:---:|:---:|
| **Licensing model** | Per-server (25 users/50 devices) | Per-core + CAL | Per-core + CAL | Per-core + CAL (Azure only) |
| **Max RAM** | 128 GB | 48 TB | 48 TB | 48 TB |
| **Max CPU sockets** | 1 (10 core limit) | 64 | 64 | 64 |
| **Hyper-V VM rights** | 1 VM | 2 VMs | Unlimited VMs | Unlimited VMs |
| **Storage Spaces Direct** | No | No | Yes | Yes |
| **Shielded VMs / HGS** | No | No | Yes | Yes |
| **SDN stack** | No | No | Yes | Yes |
| **SMB over QUIC** | No | No | No | Yes |
| **Hotpatch** | No | No | No | Yes |
| **Azure Extended Networking** | No | No | No | Yes |

*Note: Essentials still available but limited (1 socket, 10 cores, 128 GB RAM, 1 VM). Datacenter: Azure Edition runs only on Azure VMs or Azure Stack HCI — not on bare metal.*

**Headline features introduced in 2022:**
- Secured-core server (hardware root of trust, firmware protection)
- TLS 1.3 enabled by default
- SMB compression (in-transit LZ4/PATTERN_V1)
- SMB over QUIC (Datacenter: Azure Edition only at launch)
- Nested virtualization on AMD processors
- Azure Arc and hybrid management improvements
- Hotpatching (Datacenter: Azure Edition — rebootless security updates)
- Storage Spaces Direct improvements (thin provisioning, ReFS file-level snapshots)
- Windows containers with HostProcess containers and gMSA improvements
- DNS over HTTPS (DoH) client support
- Task Scheduler improvements
- Azure Automanage Machine Configuration

#### Windows Server 2025

| Feature | Essentials | Standard | Datacenter | Datacenter: Azure Edition |
|---|:---:|:---:|:---:|:---:|
| **Licensing model** | Per-server (OEM only) | Per-core + CAL | Per-core + CAL | Per-core + CAL (Azure only) |
| **Max RAM** | 128 GB | 48 TB (4-level) / 4 PB (5-level paging) | 48 TB / 4 PB | 48 TB / 4 PB |
| **Max CPU sockets** | 1 (10 core limit) | 64 | 64 | 64 |
| **Max logical processors** | 10 | 2,048 | 2,048 | 2,048 |
| **Max vCPUs per VM** | N/A | 2,048 | 2,048 | 2,048 |
| **Max RAM per VM** | N/A | 240 TB | 240 TB | 240 TB |
| **Hyper-V VM rights** | 1 VM | 2 VMs | Unlimited VMs | Unlimited VMs |
| **Storage Spaces Direct** | No | No | Yes | Yes |
| **SDN stack** | No | No | Yes | Yes |
| **SMB over QUIC** | No | Yes (new!) | Yes | Yes |
| **Hotpatch (via Azure Arc)** | No | Yes (new!, subscription) | Yes (subscription) | Yes |
| **NVMe/TCP** | No | No | Yes | Yes |
| **GPU-P (GPU Partitioning)** | No | Yes | Yes | Yes |

*Note: Essentials is OEM-only in 2025 (not via Volume Licensing or retail). 25 users/50 devices limit. Effectively a dead-end SKU — no unique roles.*

**Headline features introduced in 2025:**
- **Native NVMe stack** — drops legacy SCSI emulation; up to 60% more storage IOPs vs 2022 on same hardware
- Hotpatch available on Standard and Datacenter via Azure Arc (subscription required)
- SMB over QUIC on Standard and Datacenter (previously Azure Edition only)
- SMB signing required by default
- DTrace for Windows (system tracing, ported from illumos)
- Delegated Managed Service Accounts (dMSA) — successor to gMSA
- NVMe over TCP (NVMe/TCP) for remote block storage (Datacenter only)
- Bluetooth and Wi-Fi support (for edge/IoT scenarios)
- GPU Partitioning (GPU-P) for Hyper-V VMs with live migration and failover support
- Active Directory improvements (32K page size, Forest/Domain Functional Level 10, LDAP TLS enforcement)
- Credential Guard enabled by default on qualifying hardware
- NTLM v1 blocked by default (deprecation path for NTLM v2)
- Block cloning on NTFS
- 4 PB RAM support with 5-level paging (Intel Ice Lake+)
- 2,048 logical processor support (host and per-VM)
- Post-quantum cryptography (PQC) algorithm support
- Improved Windows Containers with containerd integration
- Winget (Windows Package Manager) available in Server Core
- OpenSSH included by default (no longer optional feature)
- 64-bit only — no 32-bit support

### Windows Server — Directory Structure

```
agents/os/windows-server/
├── SKILL.md                              # Technology agent — all versions, core expertise
├── references/
│   ├── architecture.md                   # NT kernel, HAL, registry, services, boot, WMI/CIM
│   ├── best-practices.md                 # Hardening (CIS/STIG), GPO, patching, Server Core, WAC
│   ├── diagnostics.md                    # Event logs, Performance Monitor, WinRM, PowerShell diag
│   └── editions.md                       # Edition comparison matrices, licensing, feature gates
├── scripts/                              # Core diagnostic PowerShell scripts (all-version)
│   ├── 01-server-health.ps1              # Uptime, roles, features, OS build, hotfixes
│   ├── 02-performance-baseline.ps1       # CPU, memory, disk, network counters (Get-Counter)
│   ├── 03-event-log-analysis.ps1         # Critical/error events, patterns, log sizes
│   ├── 04-storage-health.ps1             # Disk, volume, RAID, NTFS/ReFS, space usage
│   ├── 05-network-diagnostics.ps1        # NIC config, DNS, firewall rules, connectivity
│   ├── 06-security-audit.ps1             # Local policy, users/groups, services, open ports, certs
│   ├── 07-windows-update.ps1             # Patch compliance, pending updates, WSUS status
│   ├── 08-backup-status.ps1              # Windows Server Backup, shadow copies, system state
│   ├── 09-service-health.ps1             # Critical services, auto-start failures, recovery config
│   └── 10-registry-audit.ps1             # Key security settings, known-good baselines
│
├── 2016/
│   ├── SKILL.md                          # Version-specific: Nano Server, containers, Shielded VMs
│   └── scripts/
│       ├── 11-container-health.ps1       # Docker/Windows containers on 2016
│       └── 12-credential-guard.ps1       # Device Guard / Credential Guard diagnostics
│
├── 2019/
│   ├── SKILL.md                          # Version-specific: WAC, System Insights, HCI, hybrid
│   └── scripts/
│       ├── 11-container-health.ps1       # Updated container diagnostics
│       ├── 12-system-insights.ps1        # System Insights ML predictions
│       └── 13-storage-migration.ps1      # Storage Migration Service status
│
├── 2022/
│   ├── SKILL.md                          # Version-specific: Secured-core, SMB compression, TLS 1.3
│   └── scripts/
│       ├── 11-container-health.ps1       # HostProcess containers, gMSA
│       ├── 12-secured-core.ps1           # Secured-core server validation
│       ├── 13-smb-health.ps1             # SMB compression, QUIC (Azure Ed), signing
│       └── 14-hotpatch-status.ps1        # Hotpatch enrollment and compliance (Azure Ed)
│
├── 2025/
│   ├── SKILL.md                          # Version-specific: DTrace, dMSA, NVMe/TCP, GPU-P
│   └── scripts/
│       ├── 11-container-health.ps1       # containerd integration, updated diagnostics
│       ├── 12-secured-core.ps1           # Updated secured-core + Credential Guard default
│       ├── 13-smb-health.ps1             # SMB QUIC (all editions), signing enforcement
│       ├── 14-hotpatch-status.ps1        # Hotpatch (all editions)
│       ├── 15-dtrace-setup.ps1           # DTrace availability and tracing
│       ├── 16-nvme-tcp.ps1               # NVMe/TCP remote storage diagnostics
│       └── 17-dmsa-health.ps1            # Delegated Managed Service Account status
│
├── failover-clustering/                  # Feature sub-agent (deep-dive)
│   ├── SKILL.md                          # WSFC comprehensive agent
│   ├── references/
│   │   ├── architecture.md               # Quorum models, heartbeat, cluster network, CSV
│   │   ├── best-practices.md             # CAU, node drain, anti-affinity, workload placement
│   │   └── diagnostics.md               # Cluster logs, validation tests, witness health
│   └── scripts/
│       ├── 01-cluster-health.ps1         # Node status, quorum state, cluster events
│       ├── 02-cluster-network.ps1        # Cluster network config, heartbeat, live migration nets
│       ├── 03-csv-health.ps1             # Cluster Shared Volumes, ownership, redirected I/O
│       ├── 04-resource-groups.ps1        # Resource group status, dependencies, failover history
│       ├── 05-quorum-witness.ps1         # Witness type, disk/cloud/file share health
│       ├── 06-cau-status.ps1             # Cluster-Aware Updating runs, compliance
│       ├── 07-cluster-validation.ps1     # Run/report cluster validation tests
│       └── 08-ag-cluster-health.ps1      # Always On AG integration with WSFC
│
└── hyper-v/                              # Feature sub-agent (deep-dive)
    ├── SKILL.md                          # Hyper-V comprehensive agent
    ├── references/
    │   ├── architecture.md               # Type-1 hypervisor, partitions, VMBus, enlightenments
    │   ├── best-practices.md             # VM sizing, NUMA, dynamic memory, checkpoints, networking
    │   └── diagnostics.md               # VM health, replication, perf counters, integration services
    └── scripts/
        ├── 01-hyperv-host-health.ps1     # Host config, NUMA topology, overcommit ratios
        ├── 02-vm-inventory.ps1           # All VMs: state, config version, generation, resources
        ├── 03-vm-performance.ps1         # CPU, memory, disk, network per VM
        ├── 04-virtual-switch.ps1         # vSwitch config, SET teaming, VLAN, bandwidth
        ├── 05-storage-health.ps1         # VHD/VHDX health, disk I/O, passthrough, shared VHDX
        ├── 06-replication-health.ps1     # Hyper-V Replica status, RPO, failover readiness
        ├── 07-live-migration.ps1         # Live migration config, history, performance
        ├── 08-checkpoint-audit.ps1       # Snapshot inventory, age, disk space impact
        ├── 09-integration-services.ps1   # Integration services version, status per VM
        └── 10-nested-virt.ps1            # Nested virtualization config and validation

```

### Windows Server — Edition Planning Notes

1. **Essentials is effectively a dead-end SKU** — No unique roles since 2019, OEM-only in 2025. Not recommended for new deployments. Agent should cover minimally with migration guidance.
2. **The single biggest Standard vs. Datacenter gate is VM density** — If you run more than 2 Windows Server VMs per host, Datacenter is nearly always cheaper due to unlimited VM rights.
3. **Storage Spaces Direct is a hard Datacenter requirement** — No workaround. If building HCI with local storage, Datacenter is required.
4. **Shielded VMs require the full stack** — HGS (Datacenter host), vTPM, and policy attestation. Standard hosts cannot run Shielded VMs.
5. **Azure Edition is not an on-prem SKU** — Runs only on Azure VMs or Azure Stack HCI. Features it introduced (Hotpatch, SMB/QUIC) are migrating to standard editions over time.
6. **NVMe in 2025 is a significant storage inflection point** — Native NVMe stack (dropping SCSI emulation) affects performance sizing vs 2022 on identical hardware.

### Windows Server — Research & Writer Teams

**Wave 1: Core + Architecture (runs first)**

| # | Research Agent (Sonnet 4.6) | Focus Area | Output |
|---|---|---|---|
| R1 | WS-Architecture | NT kernel, HAL, boot process, registry, services, WMI/CIM, Server Core vs Desktop Experience, Nano Server | `references/architecture.md` research |
| R2 | WS-Best-Practices | CIS/STIG hardening, GPO baselines, patching (WSUS/SCCM/WU), Windows Admin Center, monitoring | `references/best-practices.md` research |
| R3 | WS-Diagnostics | Event Viewer, Performance Monitor, Resource Monitor, Get-Counter, WinRM, PowerShell remoting, Reliability Monitor | `references/diagnostics.md` research |
| R4 | WS-Editions | All edition matrices (2016-2025), licensing models, feature gates, hardware limits, deprecated editions | `references/editions.md` research |

**Wave 2: Version-Specific (after Wave 1 provides context)**

| # | Research Agent (Sonnet 4.6) | Focus Area | Output |
|---|---|---|---|
| R5 | WS-2016 | Nano Server, Windows Containers, Shielded VMs, S2D intro, Credential Guard, PowerShell 5.1, rolling cluster upgrade | `2016/SKILL.md` research |
| R6 | WS-2019 | WAC, System Insights, Storage Migration, HCI, Kubernetes, hybrid Azure, OpenSSH, Linux containers | `2019/SKILL.md` research |
| R7 | WS-2022 | Secured-core, TLS 1.3, SMB compression, SMB/QUIC, nested virt AMD, hotpatch, DNS-over-HTTPS, HostProcess containers | `2022/SKILL.md` research |
| R8 | WS-2025 | DTrace, dMSA, NVMe/TCP, Bluetooth/Wi-Fi, GPU-P, AD 32K page, block cloning NTFS, Credential Guard default, containerd | `2025/SKILL.md` research |

**Wave 3: Feature Deep-Dives (parallel with Wave 2)**

| # | Research Agent (Sonnet 4.6) | Focus Area | Output |
|---|---|---|---|
| R9 | WSFC-Research | Quorum models (node majority, disk witness, cloud witness, file share), heartbeat/network config, CSV, resource groups, affinity/anti-affinity, CAU, rolling upgrades, cluster sets, stretch clusters | `failover-clustering/` research |
| R10 | HyperV-Research | Type-1 hypervisor architecture, parent/child partitions, VMBus, enlightenments, Gen1 vs Gen2 VMs, dynamic memory, NUMA-aware placement, virtual networking (vSwitch, SET), storage (VHD/VHDX, shared VHDX, Storage QoS), live migration, Hyper-V Replica, checkpoints (standard vs production), DDA, GPU-P, nested virtualization | `hyper-v/` research |

**Opus 4.6 Writer Agents (finalize after research completes):**

| # | Writer Agent (Opus 4.6) | Consumes Research From | Produces |
|---|---|---|---|
| W1 | WS-Core-Writer | R1, R2, R3, R4 | Main `SKILL.md`, all `references/*.md`, core `scripts/*.ps1` |
| W2 | WS-Version-Writer | R5, R6, R7, R8 | `2016/SKILL.md` through `2025/SKILL.md`, version `scripts/*.ps1` |
| W3 | WSFC-Writer | R9 | `failover-clustering/SKILL.md`, references, scripts |
| W4 | HyperV-Writer | R10 | `hyper-v/SKILL.md`, references, scripts |

---

## 2. Windows Client (Desktop)

### Editions — Windows 10 (Enterprise/LTSC only — Home/Pro EOL Oct 2025)

*As of April 2026, only Enterprise, Education, and LTSC editions remain under support. Home and Pro 22H2 reached end of support October 2025.*

| Feature | Enterprise | Enterprise LTSC 2021 | Enterprise LTSC IoT | Education |
|---|:---:|:---:|:---:|:---:|
| **BitLocker** | Yes | Yes | Yes | Yes |
| **Group Policy** | Yes | Yes | Yes | Yes |
| **Hyper-V** | Yes | Yes | Yes | Yes |
| **Remote Desktop (host)** | Yes | Yes | Yes | Yes |
| **Windows Sandbox** | Yes | Yes | Yes | Yes |
| **Credential Guard** | Yes | Yes | Yes | Yes |
| **Application Guard** | Yes | Yes | Yes | Yes |
| **AppLocker** | Yes | Yes | Yes | Yes |
| **DirectAccess** | Yes | Yes | Yes | Yes |
| **BranchCache** | Yes | Yes | Yes | Yes |
| **Max RAM** | 6 TB | 6 TB | 6 TB | 6 TB |
| **Update control** | Full (WSUS/SCCM/WUfB) | Full | Full | Full |
| **Feature updates** | Annual | None (fixed feature set) | None | Annual |

**Still-supported versions (as of April 2026):**
- 22H2 Enterprise/Education — EOL Oct 2027
- 21H2 Enterprise LTSC — EOL Jan 2027
- 21H2 IoT Enterprise LTSC — EOL Jan 2032
- ESU (Extended Security Updates) available until Oct 2026 for remaining Pro/Enterprise

### Editions — Windows 11

| Feature | Home | Pro | Pro for Workstations | Enterprise | Education | SE |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| **BitLocker** | Device Encryption | Full | Full | Full | Full | Limited |
| **Group Policy** | No | Yes | Yes | Yes | Yes | Limited |
| **Hyper-V** | No | Yes | Yes | Yes | Yes | No |
| **Remote Desktop (host)** | No | Yes | Yes | Yes | Yes | No |
| **Windows Sandbox** | No | Yes | Yes | Yes | Yes | No |
| **Dev Drive (ReFS)** | No | Yes | Yes | Yes | Yes | No |
| **Copilot+ features** | Yes | Yes | Yes | Yes | Yes | Yes |
| **Windows Recall** | Copilot+ HW | Copilot+ HW | Copilot+ HW | Copilot+ HW | Copilot+ HW | No |
| **Credential Guard** | No | No | No | Yes | Yes | No |
| **App Control for Business** | No | No | No | Yes | Yes | No |
| **Max RAM** | 128 GB | 2 TB | 6 TB | 6 TB | 6 TB | 128 GB |

**Hardware requirements (all editions):** TPM 2.0, Secure Boot, UEFI, 4 GB RAM, 64 GB storage, 1 GHz 2-core 64-bit CPU

**Supported versions (as of April 2026):**
- 23H2 — Home/Pro reached EOL Nov 2025; **Enterprise/Education only** until Nov 2026
- 24H2 — All editions; Home/Pro until Oct 2026, Enterprise/Education until Oct 2027
- 25H2 — All editions; Home/Pro until Oct 2027, Enterprise/Education until Oct 2028
- 26H1 — New-device scoped (not offered as in-place upgrade); Home/Pro until Mar 2028, Enterprise/Education until Mar 2029
- Enterprise LTSC 2024 (build 26100 = 24H2) — Mainstream until Oct 2029
- IoT Enterprise LTSC 2024 — Extended until Oct 2034

**Key features unique to Windows 11 (vs Windows 10):**
- Snap Layouts / Snap Groups
- Virtual Desktops improvements
- Widgets
- Android app support (discontinued 2025) → replaced by cross-device features
- DirectStorage
- Auto HDR
- WSL2 GUI app support (WSLg)
- Dev Drive (ReFS-based developer volume)
- Passkeys support
- Windows Copilot / Copilot+ PC features
- Phone Link integration
- Windows Studio Effects (NPU-powered)

### Windows Client — Directory Structure

```
agents/os/windows-client/
├── SKILL.md                              # Technology agent — Win 10 + 11, core expertise
├── references/
│   ├── architecture.md                   # Desktop NT kernel, UWP/Win32, WinUI, driver model
│   ├── best-practices.md                 # Desktop hardening, Intune/GPO, update management
│   ├── diagnostics.md                    # Reliability Monitor, Event Viewer, SFC/DISM, WinDbg
│   └── editions.md                       # Edition comparison matrices, upgrade paths
├── scripts/
│   ├── 01-system-info.ps1               # OS build, edition, hardware, TPM, Secure Boot
│   ├── 02-performance-health.ps1         # CPU, RAM, disk, startup impact, resource usage
│   ├── 03-update-compliance.ps1          # Windows Update status, pending, history, deferral
│   ├── 04-security-posture.ps1           # Defender status, firewall, BitLocker, credential guard
│   ├── 05-network-diagnostics.ps1        # Wi-Fi, Ethernet, DNS, VPN, proxy config
│   ├── 06-driver-health.ps1             # Driver inventory, unsigned, outdated, problem devices
│   ├── 07-app-inventory.ps1              # Installed apps (Win32 + Store + winget), startup items
│   └── 08-disk-cleanup.ps1              # Temp files, WinSxS, delivery optimization, storage sense
│
├── 10/
│   ├── SKILL.md                          # Windows 10 Enterprise/LTSC (Home/Pro EOL Oct 2025)
│   └── scripts/
│       ├── 09-esu-status.ps1             # ESU enrollment, remaining coverage
│       └── 10-upgrade-readiness.ps1      # Windows 11 hardware/app compatibility assessment
│
├── 11/
│   ├── SKILL.md                          # Windows 11 specifics (23H2/24H2/25H2/26H1 + LTSC 2024)
│   └── scripts/
│       ├── 09-hw-compatibility.ps1       # TPM 2.0, Secure Boot, CPU compatibility check
│       ├── 10-dev-drive.ps1              # Dev Drive (ReFS) setup and health
│       ├── 11-copilot-features.ps1       # NPU detection, Copilot+ readiness, Studio Effects
│       └── 12-hotpatch-status.ps1        # Enterprise 24H2+ hotpatch (rebootless security updates)
│
└── wsl/                                  # Feature sub-agent
    ├── SKILL.md                          # Windows Subsystem for Linux (WSL1 + WSL2)
    ├── references/
    │   ├── architecture.md               # WSL1 syscall translation vs WSL2 VM, filesystem, networking
    │   └── best-practices.md             # Distro management, GPU passthrough, memory limits, .wslconfig
    └── scripts/
        ├── 01-wsl-health.ps1             # WSL version, distros, status, kernel version
        └── 02-wsl-network.ps1            # WSL networking mode (NAT vs mirrored), DNS, proxy
```

### Windows Client — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area | Output |
|---|---|---|---|
| R1 | WinClient-Editions | All editions (Home→Enterprise→LTSC→SE), feature gates, hardware limits, upgrade paths | `references/editions.md` research |
| R2 | WinClient-Core | Desktop architecture differences from Server, UWP/Win32 app model, WinUI, driver model, Intune/GPO | Core references research |
| R3 | Win10-Version | LTSC vs SAC channels, final supported builds, EOL timeline, unique 10 features | `10/SKILL.md` research |
| R4 | Win11-Version | 23H2/24H2 features, hardware requirements, Dev Drive, Copilot+, Snap Layouts, new UX | `11/SKILL.md` research |
| R5 | WSL-Research | WSL1 vs WSL2 architecture, GPU passthrough, WSLg, .wslconfig, networking modes, systemd | `wsl/` research |

| # | Writer Agent (Opus 4.6) | Consumes | Produces |
|---|---|---|---|
| W1 | WinClient-Writer | R1, R2, R3, R4 | All SKILL.md files, references, scripts |
| W2 | WSL-Writer | R5 | `wsl/SKILL.md`, references, scripts |

---

## 3. Red Hat Enterprise Linux (RHEL)

### Editions / Subscription Tiers

| Aspect | Developer (free) | Self-Support | Standard | Premium |
|---|:---:|:---:|:---:|:---:|
| **Cost** | Free (1 system) | Low | Medium | High |
| **Updates & errata** | Yes | Yes | Yes | Yes |
| **Support** | Community only | Self-service KB | Business hours | 24x7 + 1hr critical |
| **Smart Management** | No | No | Add-on | Add-on |
| **Extended Life Cycle** | No | No | Add-on | Add-on |
| **Satellite** | No | No | Add-on | Add-on |

**Variants:** Server, Workstation, High Availability Add-On, Resilient Storage Add-On, Smart Management

### Versions

#### RHEL 8 (supported — 10yr lifecycle, full support ends May 2024, maintenance until May 2029)
- **Kernel:** 4.18
- **Default Python:** 3.6 (streams: 3.8, 3.9, 3.11, 3.12)
- **Init:** systemd 239
- **Package manager:** dnf (yum as alias)
- **Container runtime:** Podman 4.x (from module streams)
- **Key features:** Application Streams, System Roles (Ansible), Cockpit web console, Stratis storage, nftables default, RHEL Insights built-in
- **Notable:** Last RHEL built from traditional Fedora → RHEL pipeline

#### RHEL 9 (supported — full support until May 2027, maintenance until May 2032)
- **Kernel:** 5.14
- **Default Python:** 3.9 (streams: 3.11, 3.12)
- **Init:** systemd 252
- **Key new features vs RHEL 8:**
  - SELinux: performance improvements, new policy modules
  - Podman 4.x with systemd integration (quadlet)
  - Keylime (remote attestation)
  - WireGuard VPN in kernel
  - Image Builder improvements (blueprints for cloud/edge)
  - RHEL for Edge (ostree-based immutable deployments)
  - Dropped: iptables (nftables only), Python 2, legacy BIOS limited

#### RHEL 10 (current — released May 2025, codename Coughlan)
- **Kernel:** 6.12
- **Default Python:** 3.12
- **Init:** systemd 256+
- **Key new features vs RHEL 9:**
  - **Image Mode (bootc)** — flagship: deploy RHEL as immutable bootable OCI container image to bare metal/VM/cloud; managed via container registries; soft reboot for near-zero-downtime updates
  - **x86-64-v3 baseline** — drops v2; requires Intel Haswell (2013) or newer
  - **Post-Quantum Cryptography (PQC)** — FIPS-compliant OpenSSL/OpenSSH with PQC support
  - **RHEL Lightspeed** — AI-powered natural language Linux admin assistant (CLI and Cockpit)
  - **DNS over HTTPS (DoH) and DNS over TLS (DoT)** — encrypted DNS by default
  - Confidential computing support (SEV-SNP, TDX)
  - **No more Modularity/Module Streams** — DNF modularity explicitly dropped; AppStreams continue as traditional RPM packages
  - **VNC → RDP** — graphical remote access switches to RDP protocol
  - **NetworkManager required** — legacy network-scripts removed entirely
  - RISC-V Developer Preview
  - WSL support (Windows Subsystem for Linux images available)
  - Dropped: 32-bit packages, SysV init scripts, legacy drivers

### RHEL — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **SELinux** | Yes | Complex policy system, extensive troubleshooting, mode management, custom modules |
| **Podman / Containers** | Yes | Rootless containers, pods, systemd integration (quadlet), Buildah, Skopeo ecosystem |
| **Cockpit** | No | Web console — covered in best practices |
| **Stratis Storage** | No | Covered in architecture reference |
| **RHEL for Edge / Image Builder** | No | Covered in version agent |
| **Satellite / Smart Management** | No | Separate product, cross-reference only |

### RHEL — Directory Structure

```
agents/os/rhel/
├── SKILL.md                              # Technology agent — all versions
├── references/
│   ├── architecture.md                   # RHEL kernel, systemd, dnf, subscription model
│   ├── best-practices.md                 # CIS/STIG hardening, firewalld, tuned, Cockpit
│   ├── diagnostics.md                    # journalctl, sosreport, crash utility, performance
│   └── editions.md                       # Subscription tiers, variants, add-ons
├── scripts/
│   ├── 01-system-health.sh              # Uptime, kernel, release, subscription status
│   ├── 02-performance-baseline.sh        # CPU, memory, disk, network (sar, vmstat, iostat)
│   ├── 03-journal-analysis.sh           # journalctl critical/error patterns, boot analysis
│   ├── 04-storage-health.sh             # LVM, Stratis, XFS/ext4, RAID, disk SMART
│   ├── 05-network-diagnostics.sh        # NetworkManager, nmcli, firewalld, DNS, routing
│   ├── 06-security-audit.sh             # SELinux status, open ports, users, sudo, SSH config
│   ├── 07-package-audit.sh              # Installed packages, pending updates, module streams
│   ├── 08-subscription-status.sh        # Subscription validity, repos, entitlements
│   └── 09-service-health.sh             # Failed units, enabled services, timer units
│
├── 8/
│   ├── SKILL.md                          # Version-specific: app streams, migration from 7
│   └── scripts/
│       └── 10-appstream-status.sh        # Application stream module status
│
├── 9/
│   ├── SKILL.md                          # Version-specific: keylime, WireGuard, edge
│   └── scripts/
│       ├── 10-keylime-status.sh          # Remote attestation health
│       └── 11-edge-image.sh              # RHEL for Edge / ostree status
│
├── 10/
│   ├── SKILL.md                          # Version-specific: bootc, confidential computing
│   └── scripts/
│       ├── 10-bootc-status.sh            # Bootable container status
│       └── 11-confidential-compute.sh    # SEV-SNP / TDX capability check
│
├── selinux/                              # Feature sub-agent (deep-dive)
│   ├── SKILL.md                          # SELinux comprehensive agent
│   ├── references/
│   │   ├── architecture.md               # MAC framework, type enforcement, MLS/MCS
│   │   ├── best-practices.md             # Policy management, booleans, custom modules
│   │   └── diagnostics.md               # audit2why, sealert, AVCs, troubleshooting workflow
│   └── scripts/
│       ├── 01-selinux-status.sh          # Mode, policy, booleans, denials count
│       ├── 02-avc-analysis.sh            # Recent AVC denials, audit2why, audit2allow
│       ├── 03-context-audit.sh           # File contexts, process domains, port labels
│       └── 04-policy-modules.sh          # Custom modules, boolean settings
│
└── podman/                               # Feature sub-agent (deep-dive)
    ├── SKILL.md                          # Podman/Buildah/Skopeo comprehensive agent
    ├── references/
    │   ├── architecture.md               # Daemonless, rootless, OCI, pod model vs Docker
    │   ├── best-practices.md             # Quadlet units, registries, storage, networking
    │   └── diagnostics.md               # Container debugging, logging, resource limits
    └── scripts/
        ├── 01-podman-health.sh           # Podman version, storage, registries config
        ├── 02-container-inventory.sh     # Running/stopped containers, pods, images
        ├── 03-rootless-audit.sh          # User namespaces, subuid/subgid, cgroup delegation
        └── 04-quadlet-status.sh          # Systemd-managed container units
```

### RHEL — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | RHEL-Architecture | Kernel, systemd, dnf, subscription model, Application Streams |
| R2 | RHEL-Security | CIS/STIG hardening, firewalld, tuned profiles, crypto policies |
| R3 | RHEL-8 | Version-specific features, migration from 7, app streams |
| R4 | RHEL-9 | Keylime, WireGuard, edge, nftables, Podman quadlet |
| R5 | RHEL-10 | Bootc, confidential computing, Podman 5, CentOS Stream model |
| R6 | SELinux-Research | MAC architecture, policy management, troubleshooting, custom modules |
| R7 | Podman-Research | Daemonless containers, rootless, quadlet, Buildah, Skopeo |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | RHEL-Core-Writer | Main SKILL.md, references, core scripts |
| W2 | RHEL-Version-Writer | 8/, 9/, 10/ SKILL.md files + version scripts |
| W3 | SELinux-Writer | selinux/ full sub-agent |
| W4 | Podman-Writer | podman/ full sub-agent |

---

## 4. Ubuntu (Desktop + Server LTS)

### Editions / Variants

| Variant | Desktop | Server | Cloud | Core (IoT) |
|---|:---:|:---:|:---:|:---:|
| **GUI** | GNOME | None (headless) | None | None |
| **Installer** | Ubiquity/Subiquity | Subiquity/autoinstall | Cloud-init | snap-based |
| **Package format** | deb + snap | deb + snap | deb + snap | snap only |
| **Target** | Workstation/laptop | Datacenter/VM | AWS/Azure/GCP | IoT/edge |

**Ubuntu Pro (paid/free for 5 machines):**
- Extended Security Maintenance (ESM) — 10yr total coverage
- Kernel Livepatch — rebootless kernel security updates
- FIPS 140-2/140-3 certified modules
- CIS hardening profiles
- Compliance tooling (USG)

### Versions

#### Ubuntu 20.04 LTS (Focal Fossa) — Standard support ended Apr 2025, ESM until Apr 2030
- **Kernel:** 5.4 (HWE: 5.15)
- **Init:** systemd 245
- **Python:** 3.8
- **Key features:** ZFS on root (experimental), WireGuard in kernel, improved snap integration, GNOME 3.36
- *Note: Past standard support window. Requires Ubuntu Pro (free for 5 machines) for ESM security updates. Agent focuses on migration to 22.04/24.04.*

#### Ubuntu 22.04 LTS (Jammy Jellyfish) — supported until Apr 2027 (ESM: Apr 2032)
- **Kernel:** 5.15 (HWE: 6.5)
- **Init:** systemd 249
- **Python:** 3.10
- **Key new features:** GNOME 42, improved Active Directory integration, Netplan everywhere, real-time kernel (Ubuntu Pro), nftables default, improved snap desktop experience

#### Ubuntu 24.04 LTS (Noble Numbat) — supported until Apr 2029 (ESM: Apr 2034)
- **Kernel:** 6.8
- **Init:** systemd 255
- **Python:** 3.12
- **Key new features:** Performance-optimized kernel, improved TPM-backed FDE, App Armor 4, Netplan improvements, PPA improvements, deb822 sources format, frame pointers enabled by default (profiling)

#### Ubuntu 26.04 LTS — Resolute Raccoon (current — released Apr 2026)
- **Kernel:** 7.0
- **Init:** systemd 259
- **Python:** 3.13
- **Key new features:**
  - **Kernel 7.0** — Intel Nova Lake + AMD Zen 6 support, extensible scheduling, crash dumps enabled by default
  - **GNOME 50** — Wayland-only sessions for desktop; XWayland for legacy X11 apps
  - **Dracut** replaces initramfs-tools as default initial ramdisk generator
  - **sudo-rs** — Rust-based sudo replacement (original renamed to `sudo.ws`)
  - **APT 3.1** — improved dependency solver, OpenSSL for TLS/hashing
  - **Mandatory cgroup v2** — cgroup v1 support removed entirely
  - **TPM-backed full-disk encryption** — passphrase management via TPM, integrated installer support
  - **Chrony** replaces systemd-timesyncd as default time daemon
  - **OpenSSH 10.2p1** — post-quantum key exchange
  - AMD ROCm + NVIDIA CUDA native out-of-box GPU compute support
  - PostgreSQL 18, MySQL 8.4 LTS, HAProxy 3.2 LTS
  - GCC 15.2, LLVM 21, Rust 1.93, Go 1.25, OpenJDK 25, .NET 10

### Ubuntu — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **Snap Packages** | No | Covered in architecture/best-practices references |
| **Netplan** | No | Covered in networking section of references |
| **LXD / Incus** | Yes | System containers, VM management, clustering — complex topic |
| **AppArmor** | Yes | MAC framework parallel to SELinux, profiles, debugging |
| **cloud-init** | No | Covered in cloud deployment section |

### Ubuntu — Directory Structure

```
agents/os/ubuntu/
├── SKILL.md                              # Technology agent — all versions (Desktop + Server)
├── references/
│   ├── architecture.md                   # Debian base, dpkg/apt, snap, Netplan, cloud-init
│   ├── best-practices.md                 # Hardening (CIS/USG), unattended-upgrades, Landscape, Pro
│   ├── diagnostics.md                    # journalctl, apport, crash reports, performance (perf, bpftrace)
│   └── editions.md                       # Desktop vs Server vs Cloud vs Core, Pro vs free
├── scripts/
│   ├── 01-system-health.sh              # Release, kernel, uptime, Pro status, ESM
│   ├── 02-performance-baseline.sh        # CPU, memory, disk, network metrics
│   ├── 03-journal-analysis.sh           # systemd journal analysis, boot time, failed units
│   ├── 04-storage-health.sh             # LVM, ZFS (if used), ext4, disk SMART
│   ├── 05-network-diagnostics.sh        # Netplan config, NetworkManager, UFW, DNS
│   ├── 06-security-audit.sh             # AppArmor status, users, SSH, open ports, unattended-upgrades
│   ├── 07-package-audit.sh              # apt + snap packages, pending upgrades, held packages
│   ├── 08-livepatch-status.sh           # Kernel livepatch status (Pro)
│   └── 09-service-health.sh             # Failed units, enabled services, timers
│
├── 20.04/
│   ├── SKILL.md                          # Version-specific: ZFS root, migration to 22.04
│   └── scripts/
│       └── 10-eol-readiness.sh           # ESM status, upgrade readiness check
│
├── 22.04/
│   ├── SKILL.md                          # Version-specific: AD integration, real-time kernel
│   └── scripts/
│       └── 10-ad-integration.sh          # SSSD/AD join status
│
├── 24.04/
│   ├── SKILL.md                          # Version-specific: TPM FDE, AppArmor 4, performance kernel
│   └── scripts/
│       ├── 10-tpm-fde-status.sh          # TPM-backed full disk encryption
│       └── 11-frame-pointers.sh          # Frame pointer profiling readiness
│
├── 26.04/
│   ├── SKILL.md                          # Version-specific: latest release features
│   └── scripts/
│
└── apparmor/                             # Feature sub-agent (deep-dive)
    ├── SKILL.md                          # AppArmor comprehensive agent
    ├── references/
    │   ├── architecture.md               # LSM framework, profile modes, abstractions
    │   ├── best-practices.md             # Profile creation, aa-genprof, aa-logprof, stacking
    │   └── diagnostics.md               # aa-status, dmesg denials, debugging workflow
    └── scripts/
        ├── 01-apparmor-status.sh         # Profile inventory, enforce vs complain counts
        ├── 02-denial-analysis.sh         # Recent denials, profile recommendations
        └── 03-profile-audit.sh           # Profile quality, unnecessary permissions
```

### Ubuntu — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Ubuntu-Architecture | Debian base, apt/dpkg, snap, Netplan, cloud-init, Subiquity |
| R2 | Ubuntu-20.04 | ZFS root, final features, migration paths |
| R3 | Ubuntu-22.04 | AD integration, real-time kernel, Netplan improvements |
| R4 | Ubuntu-24.04 | TPM FDE, AppArmor 4, performance kernel, frame pointers |
| R5 | Ubuntu-26.04 | Latest release features, what's new |
| R6 | AppArmor-Research | LSM framework, profiles, abstractions, debugging |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Ubuntu-Core-Writer | Main SKILL.md, references, core scripts |
| W2 | Ubuntu-Version-Writer | 20.04/ through 26.04/ agents + scripts |
| W3 | AppArmor-Writer | apparmor/ full sub-agent |

---

## 5. Debian

### Characteristics

Debian has no commercial editions or subscription tiers. Differentiation is by **release branch**:
- **Stable** — production (current: 13 Trixie)
- **Oldstable** — previous stable (current: 12 Bookworm)
- **LTS** — community extended support (current: 11 Bullseye)
- **Testing** — next stable in development
- **Unstable (Sid)** — rolling development

### Versions

#### Debian 11 Bullseye (LTS — community support until Jun 2026, NEAR EOL)
- **Kernel:** 5.10
- **Init:** systemd 247
- **Key features:** driverless printing/scanning, cgroupsv2, Linux 5.10 LTS kernel, Fcitx 5
- *Note: Only ~2 months of LTS support remaining. Agent will focus on migration to 12/13.*

#### Debian 12 Bookworm (oldstable — security until Jun 2028)
- **Kernel:** 6.1
- **Init:** systemd 252
- **Key new features vs 11:** Non-free firmware in installer, UEFI Secure Boot, apt 2.6, merged /usr by default, Pipewire default, improved installer

#### Debian 13 Trixie (current stable — released Aug 2025)
- **Kernel:** 6.12 LTS
- **Init:** systemd 256
- **Key new features vs 12:**
  - **RISC-V 64-bit (riscv64)** — first official release architecture support
  - **APT 3.0** — zstd compression, parallel downloads, improved dependency solver
  - **64-bit time_t ABI transition** — full 32-bit time_t removal (Y2038-safe)
  - **HTTP Boot support** — UEFI HTTP Boot for network installation
  - GNOME 47, KDE Plasma 6.0 (Wayland-first)
  - Podman 5.x, Python 3.12, GCC 14, LibreOffice 25.2+
  - zstd compression for package transport (replaces xz)
  - Landlock LSM experimental support
  - 69,830 packages total; 14,100 new

### Debian — Directory Structure

```
agents/os/debian/
├── SKILL.md                              # Technology agent — Debian philosophy, packaging, governance
├── references/
│   ├── architecture.md                   # dpkg/apt, release process, security team, backports
│   ├── best-practices.md                 # Hardening, unattended-upgrades, backports strategy
│   └── diagnostics.md                    # journalctl, reportbug, dmesg, performance tools
├── scripts/
│   ├── 01-system-health.sh              # Release, kernel, uptime, sources, security repo
│   ├── 02-performance-baseline.sh
│   ├── 03-journal-analysis.sh
│   ├── 04-storage-health.sh
│   ├── 05-network-diagnostics.sh
│   ├── 06-security-audit.sh
│   ├── 07-package-audit.sh              # apt, held packages, backports, security updates
│   └── 08-service-health.sh
│
├── 11/
│   └── SKILL.md                          # Bullseye LTS specifics
├── 12/
│   └── SKILL.md                          # Bookworm specifics
└── 13/
    └── SKILL.md                          # Trixie specifics
```

*No feature sub-agents — Debian's philosophy is upstream tools, not custom Debian-specific stacks. AppArmor is shared with Ubuntu agent via cross-reference.*

### Debian — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | Debian-Core | Debian philosophy, packaging, release process, security team |
| R2 | Debian-Versions | 11/12/13 feature differences, migration, kernel versions |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | Debian-Writer | All SKILL.md files, references, scripts |

---

## 6. Rocky Linux / AlmaLinux

### Characteristics

Rocky Linux and AlmaLinux are RHEL-compatible rebuilds. They share the same RPM packages, kernel versions, and ABI compatibility. Combined into a single agent with a shared core and callouts for distro-specific differences.

**Key differences between Rocky and Alma:**

| Aspect | Rocky Linux | AlmaLinux |
|---|---|---|
| **Founded by** | Gregory Kurtzer (CentOS co-founder) | CloudLinux Inc |
| **Build system** | Peridot (custom) | AlmaLinux Build System |
| **Compatibility goal** | 1:1 RHEL binary compatible | ABI compatible (may diverge slightly) |
| **Secure Boot** | RHEL shim | Own shim (Alma-signed) |
| **Extras** | Rocky-specific SIGs | ELevate (cross-distro upgrade tool) |
| **Governance** | Rocky Enterprise Software Foundation (RESF) | AlmaLinux OS Foundation |

### Versions

Mirrors RHEL 8, 9, 10 with identical kernel and package versions. Version agents focus on:
- Migration from CentOS (especially CentOS 8 → Rocky/Alma 8)
- Distro-specific tooling differences
- Community SIG (Special Interest Group) packages
- Differences from upstream RHEL

### Rocky/Alma — Directory Structure

```
agents/os/rocky-alma/
├── SKILL.md                              # Technology agent — RHEL-compatible ecosystem
├── references/
│   ├── architecture.md                   # RHEL rebuild process, compatibility guarantees
│   ├── best-practices.md                 # CentOS migration, repo management, SIGs
│   └── diagnostics.md                    # Shared with RHEL (cross-reference)
├── scripts/
│   ├── 01-system-health.sh              # Distro detection, release, kernel, repos
│   ├── 02-migration-check.sh            # CentOS → Rocky/Alma migration status
│   ├── 03-repo-health.sh               # Repository config, GPG keys, enabled repos
│   └── 04-compatibility-audit.sh        # RHEL ABI compatibility check
│
├── 8/
│   └── SKILL.md                          # Version 8: CentOS 8 migration focus
├── 9/
│   └── SKILL.md                          # Version 9: current features
└── 10/
    └── SKILL.md                          # Version 10: latest release
```

*No feature sub-agents — core features identical to RHEL. Cross-reference RHEL SELinux and Podman agents.*

### Rocky/Alma — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | RockyAlma-Core | Rebuild process, differences from RHEL, CentOS migration, SIGs |
| R2 | RockyAlma-Versions | 8/9/10 specifics, ELevate tool, compatibility notes |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | RockyAlma-Writer | All SKILL.md files, references, scripts |

---

## 7. SUSE Linux Enterprise (SLES/SLED)

### Products and Modules

**Base products:**
- **SLES** — SUSE Linux Enterprise Server
- **SLED** — SUSE Linux Enterprise Desktop

**Extension/Module system (modular architecture):**

| Module/Extension | Included | Description |
|---|:---:|---|
| Basesystem | Yes | Core OS, YaST, systemd |
| Server Applications | Yes (SLES) | Apache, PostgreSQL, DHCP, DNS, etc. |
| Desktop Applications | Yes (SLED) | GNOME, LibreOffice, multimedia |
| Development Tools | Free | Compilers, debuggers, IDEs |
| Containers | Free | Podman, Buildah, container tools |
| Python 3 | Free | Python 3 module streams |
| SUSE Package Hub | Free | Community packages (openSUSE Backports) |
| **High Availability Extension** | **Paid** | Pacemaker, Corosync, DRBD, SBD, HAWK |
| **Live Patching** | **Paid** | Rebootless kernel updates (kGraft) |
| **SUSE Manager** | **Paid** | Fleet management, patching, compliance |
| **SAP Applications** | **Paid** | SAP HANA/S4HANA optimized profiles |
| **Confidential Computing** | **Paid** | AMD SEV, Intel TDX support |

### Versions

#### SLES 15 SP5 (supported)
- **Kernel:** 5.14.21
- **Key features:** Podman 4.3.1 (Netavark), KVM vCPU limit 768, NVMe-oF TCP boot, Python 3.11, 4096-bit RSA signing key, TLS 1.0/1.1 deprecated, IBM z16 support, ARM64 64K page kernel flavor
- New Systems Management Module (Salt, Ansible with faster update cadence)
- Full Installation Medium allows offline install without registration

#### SLES 15 SP6 (current)
- **Kernel:** 6.4 (significant jump from 5.14)
- **systemd:** 254 (cgroup v2 unified default)
- **Key new features vs SP5:**
  - **OpenSSL 3.1.4** (from 1.1.1) — major cryptographic upgrade
  - **OpenSSH 9.6p1** — RSA keys under 2048 bits rejected
  - **LUKS2 fully supported** in YaST Partitioner (was tech preview)
  - **NFS over TLS** — encrypted storage traffic
  - **Confidential Computing module** — Intel TDX (tech preview)
  - **KubeVirt L3 support**
  - FRRouting (frr) replaces deprecated Quagga for dynamic routing
  - BIND 9.18 with DoT/DoH support
  - PostgreSQL 16 with full L3 support
  - Xen 4.18, QEMU 8.2 (modular libvirt daemon default), libvirt 10.0
  - HPC no longer separate product — now a module within SLES
  - `zypper search-packages` — search across all SLE modules
  - **Deprecated (removal in SP7):** PHP 7.4, IBM Java, OpenLDAP (→ 389 DS), Ceph client

### SLES — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **YaST** | No | Covered in architecture/best-practices |
| **Btrfs + Snapper** | Yes | Default filesystem with snapshots/rollback — unique to SLES in enterprise |
| **HA Extension (Pacemaker/Corosync)** | Yes | Complex clustering — parallel to WSFC |
| **SUSE Manager** | No | Separate product, cross-reference only |
| **SAP tuning** | No | Covered in best-practices |

### SLES — Directory Structure

```
agents/os/sles/
├── SKILL.md                              # Technology agent — SLES philosophy, modules
├── references/
│   ├── architecture.md                   # Module system, Btrfs default, YaST, Wicked, transactional
│   ├── best-practices.md                 # SAP tuning, hardening, SUSEConnect, maintenance
│   ├── diagnostics.md                    # supportconfig, journalctl, YaST logs, crash
│   └── editions.md                       # SLES vs SLED, modules, extensions, pricing
├── scripts/
│   ├── 01-system-health.sh              # Release, kernel, registered modules, uptime
│   ├── 02-performance-baseline.sh
│   ├── 03-journal-analysis.sh
│   ├── 04-btrfs-health.sh              # Btrfs filesystem, snapshots, balance, scrub
│   ├── 05-network-diagnostics.sh        # Wicked/NetworkManager, firewalld, DNS
│   ├── 06-security-audit.sh
│   ├── 07-package-audit.sh              # zypper, modules, patches, patterns
│   ├── 08-registration-status.sh        # SUSEConnect, module registration, repos
│   └── 09-supportconfig.sh             # Generate/analyze supportconfig bundle
│
├── 15-sp5/
│   └── SKILL.md                          # SP5-specific features
├── 15-sp6/
│   └── SKILL.md                          # SP6-specific features
│
├── btrfs-snapper/                        # Feature sub-agent (deep-dive)
│   ├── SKILL.md                          # Btrfs + Snapper snapshots/rollback agent
│   ├── references/
│   │   ├── architecture.md               # Btrfs CoW, subvolumes, snapshots, RAID levels
│   │   ├── best-practices.md             # Snapshot policies, cleanup, quotas, backup integration
│   │   └── diagnostics.md               # btrfs check, scrub, balance, device stats
│   └── scripts/
│       ├── 01-btrfs-status.sh            # Filesystem info, device stats, allocation
│       ├── 02-snapshot-inventory.sh      # Snapper snapshots, ages, space usage
│       ├── 03-rollback-test.sh           # Rollback readiness, boot snapshot
│       └── 04-maintenance.sh             # Balance, scrub, quota check
│
└── ha-extension/                         # Feature sub-agent (deep-dive)
    ├── SKILL.md                          # Pacemaker/Corosync HA cluster agent
    ├── references/
    │   ├── architecture.md               # Corosync ring, Pacemaker CRM, resources, constraints
    │   ├── best-practices.md             # SBD fencing, STONITH, resource agents, maintenance mode
    │   └── diagnostics.md               # crm_mon, corosync-cfgtool, HAWK, pcs commands
    └── scripts/
        ├── 01-cluster-status.sh          # crm_mon, node status, quorum
        ├── 02-resource-health.sh         # Resource status, failover history, colocation
        ├── 03-fencing-audit.sh           # STONITH/SBD configuration, test fence
        ├── 04-corosync-health.sh         # Ring status, token timeouts, membership
        └── 05-hawk-status.sh             # HAWK web console availability
```

### SLES — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | SLES-Architecture | Module system, YaST, Btrfs default, Wicked, transactional updates |
| R2 | SLES-Versions | SP5 vs SP6 differences, kernel changes, new features |
| R3 | Btrfs-Snapper-Research | CoW filesystem, subvolumes, snapshots, rollback, quotas, maintenance |
| R4 | HA-Extension-Research | Pacemaker/Corosync, SBD fencing, HAWK, resource agents |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | SLES-Core-Writer | Main SKILL.md, references, scripts, version agents |
| W2 | Btrfs-Writer | btrfs-snapper/ full sub-agent |
| W3 | HA-Writer | ha-extension/ full sub-agent |

---

## 8. macOS

### Editions

macOS has a **single consumer edition** — no Home/Pro/Enterprise split. Feature availability depends on:
- **Hardware generation:** Apple Silicon (M-series) vs Intel (Rosetta 2 compatibility layer)
- **Apple Intelligence features:** Require Apple Silicon (M1+) with Neural Engine — Intel Macs excluded
- **Virtualization Framework:** Apple Silicon only for running macOS/ARM VMs
- **macOS Server:** Discontinued (Server.app removed in macOS 12+)

*Note: Apple switched to year-based versioning at WWDC 2025 — "macOS 26 Tahoe" not "macOS 16".*

### Versions

#### macOS 14 Sonoma (security updates only)
- **Kernel:** XNU (Darwin 23.x)
- **Key features:** Desktop widgets (interactive, iPhone widgets via Continuity), Game Mode, Presenter Overlay (Neural Engine), Safari profiles, web apps in Dock
- **Enterprise:** Declarative Device Management (DDM) expanded to macOS, FileVault at Setup Assistant, Platform SSO enhancements (Okta, Entra ID), managed Apple IDs (Continuity, Keychain, Wallet)
- **Developer:** Xcode 15, Swift 5.9 (macros), SwiftData, SwiftUI keyframes, visionOS SDK
- **Hardware:** Dropped all 2017 Intel Macs (Kaby Lake); minimum Intel 8th-gen (Coffee Lake) or M1+

#### macOS 15 Sequoia (security updates)
- **Kernel:** XNU (Darwin 24.x)
- **Key features:** iPhone Mirroring, native window tiling, Passwords app (standalone), Apple Intelligence (staged from 15.1+: Writing Tools, notification summaries, Genmoji, Image Playground, enhanced Siri, ChatGPT integration)
- **Enterprise:** Apple Intelligence MDM controls, iPhone Mirroring MDM control, Platform SSO (FileVaultPolicy, LoginPolicy, UnlockPolicy), Safari extension MDM management, DDM-based software updates
- **Developer:** Xcode 16, Swift 6.0 (compile-time concurrency safety), Swift Testing framework, on-device AI code completion
- **Hardware:** Dropped 2018-2019 MacBook Air; Apple Intelligence requires M1+ (Intel excluded from AI features)

#### macOS 26 Tahoe (current — year-based versioning)
- **Kernel:** XNU (Darwin 25.x)
- **Key features:** Liquid Glass design system (translucent UI redesign), Phone app on Mac (full calls via Continuity), Live Activities in menu bar, Spotlight overhaul (actions, cross-device search), live translation in Messages, FaceTime live captions, enhanced Apple Intelligence
- **Enterprise:** **Native MDM migration** (move between MDM vendors without wipe), DDM app deployment (required/optional modes), legacy MDM software update mechanisms deprecated (DDM-only path), Platform SSO simplified setup at ADE, authenticated guest mode with NFC, FileVault unlock over SSH, executable/script secure deployment via MDM
- **Developer:** Xcode 26, Swift 6.2, **Foundation Models framework** (on-device Apple Intelligence model via Swift API), Xcode AI integration (ChatGPT, Claude, any Chat Completions API), compilation caching, bounds safety for C/C++, **Containerization framework** (open-source Linux containers on Apple Silicon)
- **Hardware:** **Last version supporting Intel Macs** (only 4 models: Mac Pro 2019, MacBook Pro 16" 2019, MacBook Pro 13" 2020 4-port, iMac 2020). macOS 27+ will be Apple Silicon only. Intel Macs get no Apple Intelligence features.

### macOS — Key Feature Deep-Dives

| Feature | Warrants Sub-Agent? | Rationale |
|---|:---:|---|
| **MDM / Apple Business Manager** | Yes | Complex deployment pipeline, DDM protocol, profiles, restrictions, ADE, native MDM migration (Tahoe) |
| **Platform SSO / Identity** | Yes | PSSO config with Okta/Entra ID, authentication policies, NFC/Tap-to-Login, ADE integration |
| **Apple Intelligence (IT mgmt)** | No | Covered in version agents + MDM sub-agent (restriction payloads) |
| **Virtualization / Containers** | No | Covered in architecture reference (Virtualization.framework, Containerization framework) |
| **FileVault** | No | Covered in security section of best-practices |
| **Developer Toolchain** | Yes | Xcode, Swift, CLI tools, notarization pipeline, Foundation Models — separate concern |
| **Security Hardening** | No | Covered in best-practices reference (SIP, Gatekeeper, XProtect, CIS benchmarks) |

### macOS — Directory Structure

```
agents/os/macos/
├── SKILL.md                              # Technology agent — all versions
├── references/
│   ├── architecture.md                   # XNU kernel, launchd, frameworks, Apple Silicon vs Intel, SIP/SSV, APFS
│   ├── best-practices.md                 # Hardening (CIS), Homebrew, Time Machine (AFP→SMB migration), FileVault, updates
│   ├── diagnostics.md                    # Console.app, unified log (log show), sysdiagnose, spindump, fs_usage, DTrace
│   └── hardware.md                       # Apple Silicon vs Intel feature matrix, chip capabilities, Rosetta 2 status
├── scripts/
│   ├── 01-system-health.sh              # sw_vers, hardware info, SIP status, uptime, chip type
│   ├── 02-performance-baseline.sh        # CPU, memory, disk, thermal (powermetrics)
│   ├── 03-log-analysis.sh              # Unified logging (log show), crash reports, diagnostic reports
│   ├── 04-storage-health.sh             # APFS volumes, disk utility, Time Machine, SMART
│   ├── 05-network-diagnostics.sh        # networksetup, scutil, DNS, Wi-Fi, VPN
│   ├── 06-security-audit.sh             # FileVault, Gatekeeper, SIP, firewall, XProtect version
│   ├── 07-profile-audit.sh             # MDM profiles, restrictions, certificates
│   ├── 08-app-inventory.sh              # Applications, Homebrew (path-aware), mas (Mac App Store CLI)
│   └── 09-launch-agents.sh             # LaunchAgents, LaunchDaemons, login items
│
├── 14/
│   └── SKILL.md                          # Sonoma: DDM expansion, widgets, Safari profiles
├── 15/
│   └── SKILL.md                          # Sequoia: Apple Intelligence, iPhone Mirroring, PSSO improvements
├── 26/
│   └── SKILL.md                          # Tahoe (year-based versioning): Liquid Glass, MDM migration, Foundation Models
│
├── mdm-deployment/                       # Feature sub-agent (deep-dive)
│   ├── SKILL.md                          # MDM, ABM, DDM protocol, ADE, profile management
│   ├── references/
│   │   ├── architecture.md               # Legacy MDM vs DDM protocol, ABM, ADE workflow, supervised mode
│   │   ├── best-practices.md             # Zero-touch deployment, profiles, restrictions, MDM migration (Tahoe)
│   │   └── diagnostics.md               # Profile install/verify, MDM enrollment debug, Recovery Lock
│   └── scripts/
│       ├── 01-mdm-enrollment.sh          # MDM enrollment status, server URL, certificates
│       ├── 02-profile-inventory.sh       # Installed profiles, payloads, restrictions
│       ├── 03-certificate-audit.sh       # Certificate trust, expiry, MDM identity
│       └── 04-ddm-status.sh             # DDM declarations, status reports
│
├── platform-sso/                         # Feature sub-agent (deep-dive)
│   ├── SKILL.md                          # Platform SSO with Okta/Entra ID
│   ├── references/
│   │   ├── architecture.md               # PSSO protocol, IdP federation, token management
│   │   └── best-practices.md             # Setup (ADE simplified in Tahoe), policies, grace periods, NFC
│   └── scripts/
│       ├── 01-psso-status.sh             # PSSO registration, IdP connection, token validity
│       └── 02-auth-policy-audit.sh       # FileVault/Login/Unlock policy configuration
│
└── developer-toolchain/                  # Feature sub-agent (deep-dive)
    ├── SKILL.md                          # Xcode, Swift, CLI tools, notarization, Foundation Models
    ├── references/
    │   ├── xcode-versions.md             # Xcode 15→16→26 changelog, SDK requirements
    │   ├── swift-migration.md            # Swift 5.9→6.0→6.2, concurrency model migration
    │   └── signing-notarization.md       # Code signing, notarization pipeline, stapling
    └── scripts/
        ├── 01-xcode-health.sh            # Xcode version, CLT version, SDK paths
        ├── 02-signing-audit.sh           # Developer ID, provisioning profiles, entitlements
        └── 03-homebrew-health.sh         # Homebrew path (/opt/homebrew vs /usr/local), outdated, doctor
```

### macOS — Research & Writer Teams

| # | Research Agent (Sonnet 4.6) | Focus Area |
|---|---|---|
| R1 | macOS-Architecture | XNU kernel, launchd, frameworks, SIP/SSV, APFS, Apple Silicon vs Intel, Rosetta 2 |
| R2 | macOS-14 | Sonoma: DDM expansion, widgets, Safari profiles, managed Apple IDs |
| R3 | macOS-15 | Sequoia: Apple Intelligence, iPhone Mirroring, PSSO policies, Swift 6 |
| R4 | macOS-26 | Tahoe: Liquid Glass, native MDM migration, Foundation Models, Containerization, last Intel |
| R5 | MDM-Research | MDM/DDM protocol evolution, ABM, ADE, profiles, MDM migration, Recovery Lock |
| R6 | PSSO-Research | Platform SSO with Okta/Entra ID, authentication policies, NFC, ADE setup |
| R7 | DevToolchain-Research | Xcode lifecycle, Swift version migration, notarization pipeline, Foundation Models API |

| # | Writer Agent (Opus 4.6) | Produces |
|---|---|---|
| W1 | macOS-Core-Writer | Main SKILL.md, references, scripts, version agents |
| W2 | MDM-Writer | mdm-deployment/ full sub-agent |
| W3 | PSSO-Writer | platform-sso/ full sub-agent |
| W4 | DevToolchain-Writer | developer-toolchain/ full sub-agent |

---

## Support Lifecycle Quick Reference (as of April 2026)

| Technology | Version | Support Status | EOL Date |
|---|---|---|---|
| Windows Server | 2016 | Extended Support | Jan 2027 |
| Windows Server | 2019 | Extended Support | Jan 2029 |
| Windows Server | 2022 | Mainstream → Extended | Oct 2026 (MS) → Oct 2031 (Ext) |
| Windows Server | 2025 | Mainstream | Oct 2029 (MS) → Oct 2034 (Ext) |
| Windows 10 | Enterprise 22H2 | ESU | Oct 2027 (Ent/Edu) |
| Windows 10 | LTSC 2021 | Fixed Lifecycle | Jan 2027 |
| Windows 11 | 23H2 Ent/Edu | Supported | Nov 2026 |
| Windows 11 | 24H2 | Supported | Oct 2026 (HP) / Oct 2027 (EE) |
| Windows 11 | 25H2 | Supported | Oct 2027 (HP) / Oct 2028 (EE) |
| Windows 11 | LTSC 2024 | Mainstream | Oct 2029 |
| RHEL | 8 | Maintenance | May 2029 |
| RHEL | 9 | Full Support | May 2027 (Full) → May 2032 (Maint) |
| RHEL | 10 | Full Support | ~2035 |
| Ubuntu | 20.04 | ESM only (Pro) | Apr 2030 (ESM) |
| Ubuntu | 22.04 | Supported | Apr 2027 (Std) → Apr 2032 (Pro) |
| Ubuntu | 24.04 | Supported | May 2029 (Std) → Apr 2034 (Pro) |
| Ubuntu | 26.04 | Current | Apr 2031 (Std) → Apr 2036 (Pro) |
| Debian | 11 Bullseye | LTS (near EOL) | Jun 2026 |
| Debian | 12 Bookworm | Oldstable | Jun 2028 |
| Debian | 13 Trixie | Current Stable | ~2030 |
| Rocky/Alma | 8 | Security Support | May 2029 |
| Rocky/Alma | 9 | Active Support | May 2027 → May 2032 |
| Rocky/Alma | 10 | Current | ~May 2035 |
| SLES | 15 SP5 | Supported (6mo after SP6) | ~Mid 2025 + LTSS |
| SLES | 15 SP6 | Current | ~2027 + LTSS to ~2030 |
| macOS | 14 Sonoma | Security updates | Until ~Sep 2026 |
| macOS | 15 Sequoia | Security updates | Until ~Sep 2027 |
| macOS | 26 Tahoe | Current | Until ~Sep 2028 |

*HP = Home/Pro, EE = Enterprise/Education, MS = Mainstream, Ext = Extended, Maint = Maintenance*

---

## Execution Strategy

### Phased OS-by-OS Approach

Each OS follows the same production pipeline:

```
Phase 1: Spawn research agents (Sonnet 4.6) in parallel
    ↓
Phase 2: Research agents complete → Opus 4.6 writer agents consume research
    ↓
Phase 3: Writers produce SKILL.md files, references, and scripts
    ↓
Phase 4: Review and iterate
```

### Recommended Execution Order

| Order | Technology | Est. Research Agents | Est. Writer Agents | Rationale |
|---|---|:---:|:---:|---|
| 1 | **Windows Server** | 10 | 4 | Most complex, sets pattern for feature sub-agents |
| 2 | **Windows Client** | 5 | 2 | Shares paradigm references with Server |
| 3 | **RHEL** | 7 | 4 | Most complex Linux distro, sets pattern |
| 4 | **Ubuntu** | 6 | 3 | Shares Debian base concepts |
| 5 | **Debian** | 2 | 1 | Lighter scope, Ubuntu covers shared concepts |
| 6 | **Rocky/Alma** | 2 | 1 | RHEL-compatible, lightest scope |
| 7 | **SLES** | 4 | 3 | Unique features (Btrfs, HA Extension) |
| 8 | **macOS** | 5 | 2 | Different paradigm, standalone |

**After all technologies:** Create the OS domain-level agent (`agents/os/SKILL.md` + `references/`)

### Total Inventory

| Component | Count |
|---|---|
| **Technologies** | 8 |
| **Version agents** | 25 (4 WS + 2 WC + 3 RHEL + 4 Ubuntu + 3 Debian + 3 Rocky + 2 SLES + 3 macOS + 1 Win10 LTSC) |
| **Feature sub-agents** | 11 (WSFC, Hyper-V, WSL, SELinux, Podman, AppArmor, Btrfs/Snapper, HA Extension, MDM, Platform SSO, Dev Toolchain) |
| **Reference files** | ~60 |
| **PowerShell scripts** | ~60 (Windows Server + Client) |
| **Bash scripts** | ~70 (Linux distros) |
| **Shell scripts (zsh)** | ~18 (macOS) |
| **Research agents needed** | ~46 (Sonnet 4.6) |
| **Writer agents needed** | ~23 (Opus 4.6) |

### Cross-References (avoid duplication)

| Topic | Primary Agent | Cross-Referenced From |
|---|---|---|
| Active Directory | `agents/identity/active-directory/` (Section 3) | Windows Server, Windows Client |
| DNS Server | `agents/dns/windows-dns/` (Section 5) | Windows Server |
| Hyper-V (full virtualization) | `agents/os/windows-server/hyper-v/` | `agents/virtualization/` (Section 6) |
| Podman | `agents/os/rhel/podman/` | Ubuntu, Rocky/Alma, SLES, Debian |
| AppArmor | `agents/os/ubuntu/apparmor/` | Debian, SLES |
| SELinux | `agents/os/rhel/selinux/` | Rocky/Alma |
| Pacemaker/Corosync | `agents/os/sles/ha-extension/` | RHEL (HA Add-on) |
| Containers (Docker/containerd) | `agents/containers/` (Section 7) | Windows Server, all Linux, macOS (Containerization framework) |
| MDM (cross-platform) | `agents/os/macos/mdm-deployment/` | Intune/SCCM in Windows agents |
| Platform SSO / Identity | `agents/os/macos/platform-sso/` | Okta/Entra ID in identity domain |

---

## Notes

- Scripts are **read-only diagnostics** (safe for production) following the SQL Server pattern
- All PowerShell scripts use `#Requires -Version 5.1` minimum, with 7.x features noted
- All Bash scripts use `#!/usr/bin/env bash` with `set -euo pipefail`
- Version agents document only NEW features introduced in that version
- Feature sub-agents are reserved for topics requiring 500+ lines of dedicated expertise
- Edition/licensing information is maintained in `references/editions.md` per technology
- Paradigm references at the domain level explain ecosystem philosophy (Windows vs Linux vs macOS thinking)
