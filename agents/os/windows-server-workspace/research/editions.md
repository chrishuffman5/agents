# Windows Server Editions, Licensing, and Feature Gates: 2016–2025

**Research gathered:** April 8, 2026
**Sources:** Microsoft Learn official documentation (editions-comparison, locks-limits, upgrade-conversion-options, azure-edition, install-upgrade-migrate), Microsoft licensing pages

---

## 1. Available Editions by Version

### Edition Roster

| Edition | 2016 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| Essentials | Yes | Yes | Yes (OEM only) | Yes (OEM only) |
| Standard | Yes | Yes | Yes | Yes |
| Datacenter | Yes | Yes | Yes | Yes |
| Datacenter: Azure Edition | No | No | Yes | Yes |
| Hyper-V Server (free, standalone) | Yes | Yes | **No** (discontinued) | **No** (discontinued) |

**Key notes:**
- **Hyper-V Server** (free standalone hypervisor) existed for 2016 and 2019 only. Microsoft did not release a Hyper-V Server 2022 or 2025. Users needing a free hypervisor are directed to Azure Stack HCI.
- **Essentials 2022 and 2025** are OEM-only; not available through volume licensing channels.
- **Datacenter: Azure Edition** introduced in 2022; runs on Azure or Azure Stack HCI only — not for on-premises bare metal.

---

## 2. Edition-Locked Features Matrix

### Critical Differentiators (Datacenter-Only Unless Noted)

| Feature | 2016 Std | 2016 DC | 2019 Std | 2019 DC | 2022 Std | 2022 DC | 2022 DC:AE | 2025 Std | 2025 DC | 2025 DC:AE |
|---|---|---|---|---|---|---|---|---|---|---|
| **Hyper-V VM rights** | 2 VMs | Unlimited | 2 VMs | Unlimited | 2 VMs | Unlimited | Unlimited | 2 VMs | Unlimited | Unlimited |
| **Storage Spaces Direct** | No | Yes | No | Yes | No | Yes | Yes | No | Yes | Yes |
| **Host Guardian Hyper-V Support** | No | Yes | No | Yes | No | Yes | Yes | No | Yes | Yes |
| **Host Guardian Service (HGS)** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Storage Replica** | No | Yes | Limited¹ | Yes | Limited¹ | Yes | Yes | Limited¹ | Yes | Yes |
| **Network Controller (SDN)** | No | Yes | No | Yes | No | Yes | Yes | No | Yes | Yes |
| **Software Load Balancer** | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **SMB over QUIC** | No | No | No | No | No | No | **Yes** | Yes | Yes | Yes |
| **Hotpatch** | No | No | No | No | No | No | **Yes** | Arc²  | Arc² | **Yes** (built-in) |
| **GPU Partitioning** | No | No | No | No | No | No | No | Yes³ | Yes | Yes³ |
| **Azure Extended Networking** | No | No | No | No | No | No | Yes | No | No | Yes |
| **AVMA (VM Activation)** | Guest-only | Yes | Guest-only | Yes | Guest-only | Yes | Yes | Guest-only | Yes | Yes |
| **Containers (Windows Server)** | Yes | Yes | Yes | Yes | Yes | Yes | No | Yes | Yes | No |
| **NVMe/NVMe-oF initiator** | No | No | No | No | No | No | No | Yes (all editions) | Yes | Yes |

**Notes:**
1. Storage Replica on Standard: limited to 1 partnership, 1 resource group, single volume max 2 TB. This restriction applies identically across 2019, 2022, and 2025 Standard. Datacenter has no limit.
2. Hotpatch on 2025 Standard/Datacenter (non-Azure Edition) requires Azure Arc enrollment and a paid subscription ($1.50 USD per CPU core/month, GA July 2025).
3. GPU Partitioning on Standard is for standalone servers only; live migration between nodes for planned downtime is supported, but clustering for unplanned downtime requires Datacenter edition.

### SMB over QUIC — Version and Edition Availability

| Version | Standard | Datacenter | Datacenter: Azure Edition |
|---|---|---|---|
| 2016 | No | No | N/A |
| 2019 | No | No | N/A |
| 2022 | No | No | **Yes** (Azure Edition exclusive) |
| 2025 | **Yes** | **Yes** | **Yes** |

SMB over QUIC was an Azure Edition exclusive in 2022 (functions as an "SMB VPN" using TLS 1.3, IETF QUIC/HTTP3 protocol). In 2025 it became available in all editions.

### Hotpatch — Version and Edition Availability

| Version | Standard | Datacenter | Datacenter: Azure Edition |
|---|---|---|---|
| 2016 | No | No | N/A |
| 2019 | No | No | N/A |
| 2022 | No | No | **Yes** (Azure, no reboot) |
| 2025 | Yes (Arc + subscription) | Yes (Arc + subscription) | **Yes** (built-in, no Arc needed) |

Hotpatch on 2025 Standard/Datacenter: requires Azure Arc enrollment + $1.50/core/month subscription. Azure Edition on Azure: included at no extra cost, no Arc required.

---

## 3. Hardware Limits Per Edition Per Version

### Windows Server 2016

| Limit | Standard | Datacenter |
|---|---|---|
| Max 64-bit CPU sockets | 64 | 64 |
| Max logical processors | Unlimited (no OS cap) | Unlimited |
| Max RAM | 24 TB | 24 TB |
| Max VMs per license | 2 | Unlimited |
| Max SMB connections | 16,777,216 | 16,777,216 |
| Max RDS connections | 65,535 | 65,535 |

### Windows Server 2019

| Limit | Standard | Datacenter |
|---|---|---|
| Max 64-bit CPU sockets | 64 | 64 |
| Max logical processors | Unlimited | Unlimited |
| Max RAM | 24 TB | 24 TB |
| Max VMs per license | 2 | Unlimited |
| Max SMB connections | 16,777,216 | 16,777,216 |
| Max RDS connections | 65,535 | 65,535 |

### Windows Server 2022

| Limit | Standard | Datacenter | Datacenter: Azure Edition |
|---|---|---|---|
| Max 64-bit CPU sockets | 64 | 64 | 64 |
| Max logical processors | Unlimited | Unlimited | **1,024** |
| Max RAM | 4 PB (5-level paging) / 256 TB (4-level paging) | 4 PB / 256 TB | 240 TB (Gen2 VM) / 1 TB (Gen1) |
| Max VMs per license | 2 | Unlimited | Unlimited |
| Storage Replica | 1 partnership, 1 RG, 2 TB | Unlimited | Unlimited |

### Windows Server 2025

| Limit | Standard | Datacenter | Datacenter: Azure Edition |
|---|---|---|---|
| Max 64-bit CPU sockets | 64 | 64 | 64 |
| Max logical processors | Unlimited | Unlimited | **2,048** |
| Max RAM | 4 PB (5-level paging) / 256 TB (4-level paging) | 4 PB / 256 TB | 240 TB (Gen2 VM) / 1 TB (Gen1) |
| Max VMs per license | 2 | Unlimited | Unlimited |
| Hyper-V isolated containers | 2 | Unlimited | Unlimited |
| Storage Replica | 1 partnership, 1 RG, 2 TB | Unlimited | Unlimited |

**Significant jumps:**
- **2016/2019 → 2022/2025**: RAM ceiling jumped from 24 TB to 256 TB–4 PB (due to 5-level paging support)
- **Azure Edition 2022 → 2025**: LP cap increased from 1,024 to 2,048 logical processors
- **2025 Standard/Datacenter**: Same RAM ceiling as 2022 (both support 5-level paging environments)

### Windows Server Essentials (All Versions)

| Limit | Value |
|---|---|
| Max CPU sockets | 1 |
| Max CPU cores | 10 |
| Max users | 25 |
| Max devices | 50 |
| Max VMs | 1 |
| CALs required | No |
| Licensing model | Per-server flat fee (not per-core) |

---

## 4. Licensing Model

### Per-Core Licensing (Standard and Datacenter)

Applies from Windows Server 2016 onward. Key rules:

| Rule | Detail |
|---|---|
| Unit of sale | 2-core packs or 16-core packs |
| Minimum per socket | 8 core licenses |
| Minimum per server | 16 core licenses total |
| Coverage requirement | All physical cores on all sockets must be licensed |
| Standard VM rights | 2 virtual machines (OSEs) per license |
| Datacenter VM rights | Unlimited VMs when all physical cores licensed |
| Additional Standard VMs | Purchase additional Standard licenses to cover more VMs |

**Standard licensing for VMs:** If you need more than 2 VMs on a Standard host, you purchase additional Standard licenses equal to the number of 2-VM increments needed. Each additional full server license of Standard covers 2 more VMs.

### CAL Requirements

| CAL Type | Required For | Who Needs It |
|---|---|---|
| Windows Server CAL (User) | Accessing Standard or Datacenter services | Each unique user |
| Windows Server CAL (Device) | Accessing Standard or Datacenter services | Each device (better when multiple users share few devices) |
| No CAL | Essentials edition | N/A — built into server license |
| No CAL | Datacenter: Azure Edition | Activated and billed through Azure |
| RDS CAL | Remote Desktop Services specifically | Separate from base CAL; required even for PAYG |

**Rule of thumb:** User CAL = fewer users, many devices. Device CAL = fewer devices, many users.

### Essentials Licensing

- Per-server flat fee, not per-core
- No CAL purchase required
- Enforced limits: 25 users, 50 devices, 1 socket, 10 cores
- Available OEM-only for 2022 and 2025
- Cannot be combined (no stacking of Essentials licenses)

### Azure Edition Licensing

- Not available through traditional volume licensing
- Consumed through Azure Marketplace or Azure Stack HCI
- Available to: Software Assurance customers, Windows Server subscription customers, Azure cloud customers
- No traditional product key; activated by Azure infrastructure
- Cannot be installed on on-premises bare metal
- Virtual-only (OSE); no associated virtualization rights (VMs must be licensed separately)

### Windows Server 2025 Pay-As-You-Go (PAYG)

New in 2025; requires Azure Arc enrollment:

| Detail | Value |
|---|---|
| Pricing | ~$33.58/core/month (~$0.046/core/hour) |
| Minimum cores | None |
| CAL requirement | Server CALs waived; RDS CALs still required |
| Upgrade rights | Included (upgrade to future versions at no extra cost) |
| Requirement | Azure Arc + Azure subscription (Contributor or higher) |
| Use case | Organizations needing flexible/temporary VM capacity without upfront license purchase |

### Volume Licensing Channels

| Channel | Description |
|---|---|
| Enterprise Agreement (EA) | 3-year commitment; best pricing for large orgs; Software Assurance included |
| Microsoft Products & Services Agreement (MPSA) | Flexible purchasing without term commitment |
| Cloud Solution Provider (CSP) | Monthly billing; for cloud-delivered services |
| OEM | Pre-installed on hardware; non-transferable; only channel for Essentials 2022/2025 |
| Retail | Box product; transferable one time |

---

## 5. Edition Migration and Upgrade Paths

### In-Place Version Upgrade Matrix

| From \ To | 2016 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| 2016 | — | Yes | Yes | Yes |
| 2019 | No | — | Yes | Yes |
| 2022 | No | No | — | Yes |
| 2025 | No | No | No | — (repair only) |

**Version hop rules:**
- **2025 target (nonclustered):** Can upgrade from up to 4 versions back (2012 R2 and later → 2025)
- **2022 and earlier target (nonclustered):** Max 2 versions at a time
- **Cluster OS Rolling Upgrade:** Only 1 version at a time; no skipping

### Edition Conversion (Same Version)

| Conversion | Supported | Method |
|---|---|---|
| Standard → Datacenter | **Yes** | DISM /Set-Edition or in-place upgrade with Datacenter key |
| Datacenter → Standard | **No** | Requires clean install |
| Evaluation → Standard | Yes | DISM /Set-Edition + retail key |
| Evaluation → Datacenter | Yes | DISM /Set-Edition + Datacenter key (if evaluation is Standard) |
| Evaluation Datacenter → Standard | **No** | Requires clean install |
| Datacenter → Azure Edition | Yes (during version upgrade) | Specify Azure Edition key during setup |
| Retail ↔ Volume ↔ OEM (same edition) | Yes | slmgr.vbs /ipk |

**Edition conversion is one-way upward.** You cannot convert Datacenter back to Standard without a reinstall. Azure Edition, once installed, cannot be switched back without reinstalling the OS.

### DISM Commands for Edition Operations

```cmd
# Check current edition
DISM /online /Get-CurrentEdition

# List valid upgrade targets
DISM /online /Get-TargetEditions

# Save license terms
DISM /online /Set-Edition:<TargetEdition> /GetEula:C:\license.rtf

# Convert Standard to Datacenter (requires reboot)
DISM /online /Set-Edition:ServerDatacenter /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula

# Switch license type (retail/VL/OEM, same edition)
slmgr.vbs /ipk <product key>
```

**Edition name tokens used in DISM:**
- `ServerStandard` — Standard Core
- `ServerStandardEval` — Standard Evaluation
- `ServerDatacenter` — Datacenter Core
- `ServerDatacenterEval` — Datacenter Evaluation

### Version Upgrade Edition Rules

- By default, edition is preserved during version upgrade (Standard → Standard, DC → DC)
- Upgrade can optionally change Standard → Datacenter or Datacenter → Azure Edition at the same time
- Cannot downgrade edition during version upgrade

### Essentials Migration Path

Essentials has no direct in-place upgrade path to Standard/Datacenter. Migration requires:
1. Deploy new Standard/Datacenter server
2. Migrate roles (AD DS, file shares, DHCP, etc.) using Windows Server Migration Tools
3. Decommission old Essentials server

Alternatively, use `slmgr.vbs /ipk <Standard key>` to convert an Essentials installation to Standard (converts license type, not edition architecture).

---

## 6. Decision Framework

### Standard vs. Datacenter

| Scenario | Recommended Edition | Reason |
|---|---|---|
| Physical server, few or no VMs | Standard | 2 VM rights sufficient; cost effective |
| Dense virtualization host (3+ VMs) | Datacenter | Unlimited VMs; per-license cost breaks even ~7–8 VMs |
| Storage Spaces Direct (S2D) | **Datacenter required** | S2D is Datacenter-only across all versions |
| Shielded VMs / Guarded Fabric host | **Datacenter required** | Host Guardian Hyper-V Support is Datacenter-only |
| SDN with Network Controller | **Datacenter required** | Network Controller role is Datacenter-only |
| Storage Replica, unrestricted | **Datacenter required** | Standard limited to 1 partnership, 2 TB |
| Storage Replica, simple 2-node DR | Standard may suffice | If single volume under 2 TB |
| Hyper-V cluster for HA (unplanned) | **Datacenter required** | Standard GPU partitioning clustering not supported |
| Dev/test or small workload server | Standard | Lower cost; full feature set minus above |

**Break-even math for Standard vs. Datacenter:** A Datacenter license costs roughly 3–4× a Standard license. Since each Standard license gives 2 VMs, at ~6–8 VMs the cumulative Standard license cost exceeds one Datacenter license. Run Datacenter for any host expected to run more than ~6–8 VMs.

### When Azure Edition Makes Sense

| Scenario | Azure Edition Appropriate? |
|---|---|
| Running VMs in Azure (IaaS) | **Yes** — default for Azure WS VMs |
| Running VMs on Azure Stack HCI | **Yes** — supported and licensed through HCI |
| On-premises bare metal server | **No** — not supported; virtual-only |
| Need Hotpatch without extra subscription | **Yes** — built-in on Azure |
| Need SMB over QUIC on 2022 | **Yes** — was exclusive to Azure Edition |
| Need Windows Server containers | **No** — containers not supported in Azure Edition |
| Need KMS activation | **No** — Azure Edition activated by Azure only |
| Need to migrate away from Azure later | **No** — cannot convert back; requires OS reinstall |

### When Essentials Makes Sense

**Use Essentials when:**
- Small business with ≤25 users and ≤50 devices
- Single-socket hardware (up to 10 cores)
- Want to avoid CAL procurement complexity
- Budget-constrained, buying via OEM channel

**Do not use Essentials when:**
- More than 25 users or 50 devices
- Multi-socket hardware
- Need any Datacenter features (S2D, Shielded VMs, SDN)
- Need more than 1 VM
- Need volume licensing (EA, MPSA, CSP) — Essentials is OEM-only for 2022/2025
- Expect to scale beyond small business in 2–3 years (migration is manual, not in-place upgrade)

---

## 7. PowerShell Commands for Edition Detection

### Detect Current Edition

```powershell
# Method 1: Get-ComputerInfo (most complete)
Get-ComputerInfo -Property OsName, WindowsEditionId, OsProductType, OsVersion

# Method 2: WMI/CIM
(Get-CimInstance Win32_OperatingSystem).Caption

# Method 3: Registry
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName

# Method 4: DISM (reliable for SKU-level data)
# Run from elevated command prompt or Start-Process
DISM /online /Get-CurrentEdition
```

### Detect Available Upgrade Targets

```cmd
# List editions this installation can be converted to
DISM /online /Get-TargetEditions
```

```powershell
# Get full Windows edition info via PowerShell
Get-WindowsEdition -Online
```

### Check License/Activation Status

```cmd
# View full license details (edition, channel, activation status, evaluation expiry)
slmgr.vbs /dlv

# Check evaluation status (look for "EVAL" in output)
DISM /online /Get-CurrentEdition
```

### Detect Edition Programmatically

```powershell
# Returns SKU number; useful for scripted decisions
$os = Get-CimInstance Win32_OperatingSystem
$os.OperatingSystemSKU

# Common SKU values:
# 7  = Standard (full)
# 8  = Datacenter (full)
# 12 = Datacenter (core)
# 13 = Standard (core)
# 14 = Enterprise (core)
# 98 = Windows Server Essentials

# Check if running in Azure (Azure Edition indicator)
$os.Caption -match "Azure"
```

### Check Hotpatch Status (2025)

```powershell
# Check if hotpatching is enabled
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 10

# Via Azure Arc policy — check from Azure portal or:
# az connectedmachine show --name <machine> --resource-group <rg>
```

### Quick Edition Decision Script

```powershell
$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

Write-Host "Edition: $edition"
Write-Host "Build: $version"

switch ($edition) {
    "ServerStandard"    { Write-Host "Standard — 2 VM rights, limited SR" }
    "ServerDatacenter"  { Write-Host "Datacenter — unlimited VMs, S2D, SDN, full SR" }
    "ServerDatacenterAzure" { Write-Host "Azure Edition — Azure/HCI only, Hotpatch built-in" }
    "ServerEssentials"  { Write-Host "Essentials — 25 users / 50 devices max" }
    default             { Write-Host "Unknown or evaluation edition" }
}
```

---

## 8. Quick Reference: Feature Gate Summary

| Feature | Introduced | Editions | Notes |
|---|---|---|---|
| Storage Spaces Direct | 2016 | DC, DC:AE | Never in Standard |
| Storage Replica (any) | 2016 DC / 2019 Std | Std (limited), DC | Std limit: 1 partnership, 2 TB |
| Shielded VMs / Host Guardian Hyper-V | 2016 | DC, DC:AE | Host Guardian Service role available on all |
| Network Controller (SDN) | 2016 | DC, DC:AE | SLB available on all editions |
| Datacenter: Azure Edition | 2022 | DC:AE only | Azure/HCI only, virtual-only OSE |
| SMB over QUIC | 2022 (Azure Edition) / 2025 (all) | 2022: DC:AE only; 2025: all | TLS 1.3, QUIC transport |
| Hotpatch | 2022 (Azure Edition) / 2025 (all) | 2022: DC:AE; 2025: Std/DC + Arc subscription | $1.50/core/month for non-AE |
| GPU Partitioning | 2025 | Std (standalone), DC (clustered) | Live migrate VMs with GPU partitions |
| NVMe native I/O | 2025 | All | Registry/GPO opt-in; replaces SCSI emulation |
| NVMe-oF initiator (TCP) | 2025 | All | RDMA support planned future update |
| Pay-As-You-Go licensing | 2025 | Std, DC | Arc required; ~$33.58/core/month |
| Hotpatch subscription (Arc) | 2025 GA | Std, DC (non-Azure) | $1.50/core/month; GA July 2025 |
| 4 PB RAM support | 2022 | Std, DC | Requires hardware 5-level paging |
| Azure Extended Networking | 2022 | DC:AE | Stretch on-prem subnets into Azure |

---

## Sources

- [Comparison of Windows Server editions — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/editions-comparison)
- [Locks and limits in Windows Server — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/locks-limits)
- [What is Azure Edition for Windows Server? — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/azure-edition)
- [Convert Windows Server editions and license types — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/upgrade-conversion-options)
- [Plan Your Windows Server Upgrade Path — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/upgrade-overview)
- [Hardware limits for Windows Server Essentials — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/essentials/get-started/hardware-limits)
- [Windows Server 2025 Licensing & Pricing — Microsoft](https://www.microsoft.com/en-us/windows-server/pricing)
- [Enable Hotpatch for Azure Arc-enabled servers — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/enable-hotpatch-azure-arc-enabled-servers)
- [GPU Partitioning in Windows Server 2025 Hyper-V — Microsoft Community Hub](https://techcommunity.microsoft.com/blog/itopstalkblog/gpu-partitioning-in-windows-server-2025-hyper-v/4429593)
- [Hotpatching for Azure Arc-Connected Servers: GA and Subscription Details](https://techcommunity.microsoft.com/blog/windowsservernewsandbestpractices/hotpatching-for-azure-arc%E2%80%93connected-servers-general-availability-and-subscriptio/4433915)
- [No Hyper-V Server 2022 Free — Petri](https://petri.com/microsoft-says-there-will-be-no-hyper-v-server-2022-free-edition/)
- [Configure Windows Server Pay-as-you-go with Azure Arc — Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/get-started/windows-server-pay-as-you-go)
