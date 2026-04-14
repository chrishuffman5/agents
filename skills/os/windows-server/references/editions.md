# Windows Server Editions, Licensing, and Feature Gates

## Edition Roster

| Edition | 2016 | 2019 | 2022 | 2025 |
|---|---|---|---|---|
| Essentials | Yes | Yes | OEM only | OEM only |
| Standard | Yes | Yes | Yes | Yes |
| Datacenter | Yes | Yes | Yes | Yes |
| Datacenter: Azure Edition | No | No | Yes | Yes |
| Hyper-V Server (free) | Yes | Yes | Discontinued | Discontinued |

- **Hyper-V Server** (free standalone hypervisor): 2016 and 2019 only. Users needing a free hypervisor are directed to Azure Stack HCI.
- **Essentials 2022/2025**: OEM-only; not available through volume licensing.
- **Datacenter: Azure Edition**: Azure or Azure Stack HCI only -- not for on-premises bare metal.

---

## Edition-Locked Features

| Feature | Standard | Datacenter | DC: Azure Edition |
|---|---|---|---|
| Hyper-V VM rights | 2 VMs | Unlimited | Unlimited |
| Storage Spaces Direct | No | Yes | Yes |
| Host Guardian Hyper-V Support | No | Yes | Yes |
| Storage Replica | Limited (1 partnership, 2 TB) | Unlimited | Unlimited |
| Network Controller (SDN) | No | Yes | Yes |
| SMB over QUIC (2022) | No | No | Yes |
| SMB over QUIC (2025) | Yes | Yes | Yes |
| Hotpatch (2022) | No | No | Yes |
| Hotpatch (2025) | Arc + subscription | Arc + subscription | Built-in |
| GPU Partitioning (2025) | Standalone only | Full (clustered) | Full |

### SMB over QUIC Availability

- 2022: Azure Edition exclusive
- 2025: All editions (Standard, Datacenter, Azure Edition)

### Hotpatch Availability

- 2022: Azure Edition only (on Azure)
- 2025 Standard/Datacenter: Requires Azure Arc + $1.50/core/month subscription
- 2025 Azure Edition: Built-in, no Arc needed

---

## Hardware Limits

### 2016 / 2019

| Limit | Standard | Datacenter |
|---|---|---|
| Max CPU sockets | 64 | 64 |
| Max logical processors | Unlimited | Unlimited |
| Max RAM | 24 TB | 24 TB |
| Max VMs per license | 2 | Unlimited |

### 2022 / 2025

| Limit | Standard | Datacenter | DC: Azure Edition |
|---|---|---|---|
| Max CPU sockets | 64 | 64 | 64 |
| Max logical processors | Unlimited | Unlimited | 1,024 (2022) / 2,048 (2025) |
| Max RAM | 4 PB (5-level) / 256 TB (4-level) | 4 PB / 256 TB | 240 TB (Gen2 VM) |
| Max VMs per license | 2 | Unlimited | Unlimited |

### Essentials (All Versions)

| Limit | Value |
|---|---|
| Max CPU sockets | 1 |
| Max CPU cores | 10 |
| Max users | 25 |
| Max devices | 50 |
| Max VMs | 1 |
| CALs required | No |

---

## Licensing Model

### Per-Core Licensing (Standard and Datacenter)

| Rule | Detail |
|---|---|
| Unit of sale | 2-core packs or 16-core packs |
| Minimum per socket | 8 core licenses |
| Minimum per server | 16 core licenses total |
| Standard VM rights | 2 VMs per license |
| Datacenter VM rights | Unlimited VMs |

Standard edition: purchase additional licenses for more VMs (each full license = 2 more VMs). Datacenter break-even: ~6-8 VMs (Datacenter costs ~3-4x Standard).

### CAL Requirements

| CAL Type | Required For |
|---|---|
| Windows Server CAL (User/Device) | Standard or Datacenter access |
| RDS CAL | Remote Desktop Services (separate from base CAL) |
| No CAL | Essentials edition |
| No CAL | Azure Edition (billed through Azure) |

### PAYG Licensing (2025)

New in 2025: ~$33.58/core/month via Azure Arc. CALs waived (RDS CALs still required). Requires Azure Arc + Azure subscription.

---

## Upgrade Paths

### In-Place Version Upgrade

| From | To 2019 | To 2022 | To 2025 |
|---|---|---|---|
| 2016 | Yes | Yes | Yes |
| 2019 | -- | Yes | Yes |
| 2022 | -- | -- | Yes |

- 2025 target: up to 4 versions back (2012 R2+)
- Cluster OS Rolling Upgrade: 1 version at a time only

### Edition Conversion

| Conversion | Supported | Method |
|---|---|---|
| Standard -> Datacenter | Yes | `DISM /Set-Edition` or in-place upgrade |
| Datacenter -> Standard | No | Requires clean install |
| Evaluation -> Retail | Yes | `DISM /Set-Edition` + product key |

Edition conversion is one-way upward. Azure Edition cannot be switched back without reinstall.

```powershell
# Check current edition
DISM /online /Get-CurrentEdition

# List valid upgrade targets
DISM /online /Get-TargetEditions

# Convert Standard to Datacenter
DISM /online /Set-Edition:ServerDatacenter /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula
```

---

## Decision Framework

### Standard vs Datacenter

| Scenario | Recommended | Reason |
|---|---|---|
| Physical server, few or no VMs | Standard | 2 VM rights sufficient |
| Dense virtualization (3+ VMs) | Datacenter | Unlimited VMs; breaks even ~7-8 VMs |
| Storage Spaces Direct | Datacenter | S2D is Datacenter-only |
| Shielded VMs / Guarded Fabric | Datacenter | Host Guardian Hyper-V is Datacenter-only |
| SDN with Network Controller | Datacenter | Network Controller is Datacenter-only |
| Storage Replica, unrestricted | Datacenter | Standard limited to 1 partnership, 2 TB |
| Dev/test or small workload | Standard | Lower cost, full feature set minus above |

### Edition Detection

```powershell
# Method 1: CIM
(Get-CimInstance Win32_OperatingSystem).Caption

# Method 2: Registry
(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID

# Method 3: SKU number
$os = Get-CimInstance Win32_OperatingSystem
$os.OperatingSystemSKU
# 7=Standard(full), 8=Datacenter(full), 12=Datacenter(core), 13=Standard(core), 98=Essentials

# Method 4: DISM
DISM /online /Get-CurrentEdition
```
