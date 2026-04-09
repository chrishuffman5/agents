# Windows Client Editions Reference

---

## Windows 10 Editions -- Supported as of April 2026

Home and Pro 22H2 reached end of life October 14, 2025. Only the following editions remain in support:

| Edition | Build / Version | End of Life |
|---|---|---|
| Enterprise 22H2 | 19045 | October 14, 2027 |
| Enterprise LTSC 2021 | 19044 (21H2) | January 12, 2027 |
| Enterprise LTSC 2019 | 17763 (1809) | January 9, 2029 |
| IoT Enterprise LTSC 2021 | 19044 (21H2) | January 13, 2032 |
| Education 22H2 | 19045 | October 14, 2027 |

### Extended Security Updates (ESU)

Microsoft offers paid ESU coverage for Windows 10 after mainstream EOL:
- **Coverage start:** October 15, 2025 (day after Home/Pro EOL)
- **Duration:** Up to 3 years of additional security patches (years 1, 2, 3 priced separately)
- **Year 1 pricing:** ~$61/device commercial, ~$30/device education; price doubles each year
- **Coverage scope:** Critical and Important security patches only; no features, no hardware support
- **Not covered:** LTSC editions (they carry their own extended timelines)
- **Azure benefit:** ESU included at no extra cost for Windows 10 VMs in Azure / Windows 365

### Enterprise vs LTSC Feature Matrix

| Feature | Enterprise 22H2 | LTSC 2021 | LTSC 2019 |
|---|---|---|---|
| Microsoft Store (consumer apps) | Yes | No | No |
| Edge (Chromium) | Yes | Added via update | Not included |
| Annual feature updates | Yes | No | No |
| WSL 2 | Yes | Yes | WSL 1 only |
| BitLocker | Yes | Yes | Yes |
| Credential Guard | Yes | Yes | Yes |
| WDAC / Device Guard | Yes | Yes | Yes |
| AppLocker | Yes | Yes | Yes |
| Windows Sandbox | Yes | Yes | No |
| Servicing channel | General Availability | Long-Term Servicing | Long-Term Servicing |

---

## Windows 11 Editions

### Edition Overview

| Edition | Target Audience | Notes |
|---|---|---|
| Home | Consumer / OEM | Requires Microsoft Account; no domain join |
| Pro | SMB / Power User | Domain join, Hyper-V, BitLocker, WUfB |
| Pro for Workstations | High-end workstation | SMB Direct, NVDIMM-N, ReFS, 4-socket, 6 TB RAM |
| Enterprise | Large organization | Full policy control, Credential Guard, PDE, LTSC available |
| Education | K-12 / Higher Ed | Enterprise-equivalent, licensed through EES/OVS-ES |
| Enterprise LTSC 2024 | Stable/regulated env | Based on 24H2 (build 26100); no annual feature updates |
| IoT Enterprise LTSC 2024 | Embedded / IoT | Based on 24H2; 10-year support lifecycle |

### Supported Version Lifecycle (as of April 2026)

| Version | Build | Home/Pro EOL | Ent/Edu EOL |
|---|---|---|---|
| 23H2 | 22631 | N/A (EOL for Home/Pro) | November 10, 2026 |
| 24H2 | 26100 | October 13, 2026 | October 12, 2027 |
| 25H2 | TBD | October 2027 (est.) | October 2028 (est.) |
| LTSC 2024 | 26100 | Mainstream Oct 2029 | Extended Oct 2034 (IoT) |

**Support model:**
- Home and Pro: 24 months per feature version
- Enterprise and Education: 36 months per feature version
- LTSC: 5 years mainstream + 5 years extended (Enterprise); 10 years total (IoT)

---

## Security Features by Edition

| Feature | Home | Pro | Pro WS | Enterprise | Education |
|---|---|---|---|---|---|
| Device Encryption (BitLocker lite) | Yes | Yes | Yes | Yes | Yes |
| BitLocker (full) | No | Yes | Yes | Yes | Yes |
| Credential Guard | No | No | No | Yes | Yes |
| Personal Data Encryption (PDE) | No | No | No | Yes | Yes |
| AppLocker | No | No | No | Yes | Yes |
| App Control for Business (WDAC) | No | Yes (policy) | Yes (policy) | Yes (full) | Yes (full) |
| Smart App Control | Yes | Yes | Yes | No | No |
| Windows Hello for Business | No | Yes | Yes | Yes | Yes |
| VBS | Yes | Yes | Yes | Yes | Yes |

---

## Management Features by Edition

| Feature | Home | Pro | Enterprise | Education |
|---|---|---|---|---|
| AD domain join | No | Yes | Yes | Yes |
| Entra ID join | Limited | Yes | Yes | Yes |
| Group Policy | No | Yes | Yes | Yes |
| Windows Update for Business | No | Yes | Yes | Yes |
| Assigned Access (kiosk) | No | Yes | Yes | Yes |
| Windows Autopilot | No | Yes | Yes | Yes |
| MDM (Intune) | Limited | Yes | Yes | Yes |

---

## Networking Features by Edition

| Feature | Home | Pro | Pro WS | Enterprise |
|---|---|---|---|---|
| RDP host (incoming) | No | Yes | Yes | Yes |
| DirectAccess | No | No | No | Yes |
| Always On VPN (device tunnel) | No | No | No | Yes |
| Always On VPN (user tunnel) | No | Yes | Yes | Yes |
| BranchCache | No | No | No | Yes |
| SMB Direct (RDMA) | No | No | Yes | No |

---

## Virtualization Features by Edition

| Feature | Home | Pro | Pro WS | Enterprise |
|---|---|---|---|---|
| Hyper-V | No | Yes | Yes | Yes |
| Windows Sandbox | No | Yes | Yes | Yes |
| WSL / WSL 2 | Yes | Yes | Yes | Yes |
| Dev Drive (ReFS-backed) | No | Yes | Yes | Yes |

---

## Hardware Limits by Edition

| Limit | Home | Pro | Pro for Workstations | Enterprise |
|---|---|---|---|---|
| Maximum RAM | 128 GB | 2 TB | 6 TB | 6 TB |
| Maximum CPU sockets | 1 | 2 | 4 | 2 |
| Maximum logical processors | 256 | 256 | 512 | 256 |

---

## Windows 11 Hardware Requirements

| Component | Requirement |
|---|---|
| Processor | 1 GHz, 2+ cores, 64-bit; on approved CPU list |
| RAM | 4 GB |
| Storage | 64 GB |
| Firmware | UEFI with Secure Boot enabled |
| TPM | TPM 2.0 (required) |
| Graphics | DirectX 12 compatible; WDDM 2.0 driver |
| Display | 720p, 9" diagonal |

### Approved CPU Baseline

| Manufacturer | Minimum Generation |
|---|---|
| Intel | 8th generation (Coffee Lake) and newer |
| AMD | Zen 2 (Ryzen 3000 series) and newer |
| Qualcomm | Snapdragon 7c and newer (ARM64) |

---

## Upgrade Paths

### Windows 10 to Windows 11

- Free upgrade on compatible hardware via Windows Update or ISO media
- Hardware gate: TPM 2.0, Secure Boot, and approved CPU strictly enforced
- Edition mapping: Home->Home, Pro->Pro, Enterprise->Enterprise, Education->Education
- LTSC: No upgrade path via Windows Update; clean install or in-place with LTSC 2024 media required

### Windows 11 Edition Upgrades

| From | To | Method |
|---|---|---|
| Home | Pro | Purchase Pro upgrade key in Settings > Activation |
| Pro | Enterprise | Volume License + KMS/MAK, or Entra ID + M365 E3/E5 |
| Any GA | LTSC | Clean install required; separate channel |

### LTSC Considerations

- LTSC licenses purchased separately from GA channel; not included in most standard Enterprise agreements
- Does not receive new Store apps, new Edge versions, or annual feature updates
- LTSC 2024 (build 26100) shares codebase with Windows 11 24H2
- IoT Enterprise LTSC 2024 extends support to October 2034 (10-year lifecycle)

---

## Edition Detection

```powershell
# Full OS info
Get-ComputerInfo | Select-Object OsName, OsVersion, WindowsEditionId, OsBuildNumber

# Quick edition check
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID

# Common EditionID values:
#   Core                    = Home
#   Professional            = Pro
#   ProfessionalWorkstation = Pro for Workstations
#   Enterprise              = Enterprise
#   Education               = Education
#   EnterpriseS             = Enterprise LTSC
```

---

## Key Decision Points

| If you need... | Choose... |
|---|---|
| Maximum compatibility and features | Enterprise 24H2 or 25H2 |
| 5-year stable baseline | Enterprise LTSC 2024 |
| 10-year embedded / kiosk | IoT Enterprise LTSC 2024 |
| Workstation >2 TB RAM or 4-socket | Pro for Workstations |
| Credential Guard or PDE | Enterprise or Education |
| AppLocker / WDAC full authoring | Enterprise or Education |
| Consumer, no corporate management | Home or Pro |
| RDP hosting on non-Enterprise | Pro (minimum) |
