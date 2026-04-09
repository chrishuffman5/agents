# Windows Client Editions — Research Reference

**Scope:** Windows 10 and Windows 11 editions, features, hardware requirements, lifecycle, and upgrade paths  
**As of:** April 2026  
**Source basis:** Microsoft documentation, lifecycle fact sheets, feature comparison pages

---

## 1. Windows 10 Editions — Supported as of April 2026

Home and Pro 22H2 reached end of life October 14, 2025. Only the following editions remain in support:

| Edition | Build / Version | End of Life |
|---|---|---|
| Windows 10 Enterprise 22H2 | 19045 | October 14, 2027 |
| Windows 10 Enterprise LTSC 2021 | 19044 (21H2) | January 12, 2027 |
| Windows 10 Enterprise LTSC 2019 | 17763 (1809) | January 9, 2029 |
| Windows 10 IoT Enterprise LTSC 2021 | 19044 (21H2) | January 13, 2032 |
| Windows 10 Education 22H2 | 19045 | October 14, 2027 |

> **Note:** Windows 10 Home 22H2 and Windows 10 Pro 22H2 both reached EOL on October 14, 2025. Organizations on those editions must upgrade to remain supported.

### 1.1 Extended Security Updates (ESU) — Windows 10

Microsoft offers paid ESU coverage for Windows 10 after mainstream EOL:

- **Program:** Windows 10 ESU (follows Windows 7 / Server 2008 model)
- **Coverage start:** October 15, 2025 (day after Home/Pro EOL)
- **Coverage duration:** Up to 3 years of additional security patches (years 1, 2, 3 priced separately)
- **Eligibility:** Home, Pro, Enterprise, and Education editions on 22H2
- **Year 1 pricing (2025–2026):** ~$61/device for commercial, ~$30/device for education; price doubles each year
- **Volume Licensing / Intune:** Enterprise ESU available per-device via Microsoft 365 Business Premium, Microsoft 365 E3/E5, or standalone SKU
- **What is covered:** Critical and Important security patches only; no new features, no new hardware support
- **What is NOT covered:** LTSC editions (they carry their own extended timelines)
- **Windows 365 / Azure Virtual Desktop:** ESU included at no extra cost for Windows 10 VMs running in Azure

---

## 2. Windows 10 Enterprise vs. LTSC Feature Matrix

LTSC (Long-Term Servicing Channel) trades feature velocity for stability. Key differences:

| Feature | Enterprise 22H2 | Enterprise LTSC 2021 | Enterprise LTSC 2019 |
|---|---|---|---|
| Microsoft Store (consumer apps) | Yes | No | No |
| Microsoft Edge (Chromium) | Yes (built-in) | Added via update | Not included |
| Cortana | Yes (limited) | No | No |
| Annual feature updates (22H2 style) | Yes | No | No |
| Timeline / Activity History | Yes | No | No |
| Windows Subsystem for Linux (WSL) | Yes | Yes (WSL 2) | Yes (WSL 1) |
| BitLocker Drive Encryption | Yes | Yes | Yes |
| Group Policy management | Yes | Yes | Yes |
| Hyper-V (client) | Yes | Yes | Yes |
| Remote Desktop (RDP host) | Yes | Yes | Yes |
| AppLocker | Yes | Yes | Yes |
| Credential Guard | Yes | Yes | Yes |
| Device Guard / WDAC | Yes | Yes | Yes |
| BranchCache | Yes | Yes | Yes |
| DirectAccess | Yes | Yes | Yes |
| Always On VPN (device tunnel) | Yes | Yes | Yes |
| Windows Defender Application Guard | Yes | Yes | Yes |
| Microsoft Endpoint DLP | Yes | Requires add-on | Requires add-on |
| Windows Update for Business | Yes | Yes (limited rings) | Yes (limited rings) |
| .NET 3.5 on-demand | Yes | Yes | Yes |
| Servicing channel | General Availability | Long-Term Servicing | Long-Term Servicing |
| Upgrade to next Windows 10 version | Yes (annual) | No (locked version) | No (locked version) |

---

## 3. Windows 11 Editions — All Supported Versions as of April 2026

### 3.1 Edition Overview

| Edition | Target Audience | Notes |
|---|---|---|
| Home | Consumer / OEM | Requires Microsoft Account; no domain join |
| Pro | SMB / Power User | Domain join, Hyper-V, BitLocker, WUfB |
| Pro for Workstations | High-end workstation | SMB Direct, NVDIMM-N, ReFS, 4-socket, 6 TB RAM |
| Enterprise | Large organization | Full policy control, Credential Guard, PDE, LTSC available |
| Education | K-12 / Higher Ed | Enterprise-equivalent, licensed through EES/OVS-ES |
| SE (Special Edition) | Cloud-managed K-12 | Discontinued after 24H2; final supported version only |
| Enterprise LTSC 2024 | Stable/regulated env | Based on 24H2 (build 26100); no annual feature updates |
| IoT Enterprise LTSC 2024 | Embedded / IoT | Based on 24H2; 10-year support lifecycle |

### 3.2 Supported Version Lifecycle (as of April 2026)

| Version | Build | Editions | Home/Pro EOL | Ent/Edu EOL |
|---|---|---|---|---|
| 23H2 | 22631 | Enterprise, Education only | N/A (already EOL for Home/Pro) | November 10, 2026 |
| 24H2 | 26100 | All editions | October 13, 2026 | October 12, 2027 |
| 25H2 | TBD | All editions | October 2027 (est.) | October 2028 (est.) |
| 26H1 | TBD | New-device scoped | Not available as in-place upgrade | TBD |
| LTSC 2024 | 26100 | Enterprise LTSC, IoT Enterprise LTSC | Mainstream Oct 2029 | Extended Oct 2034 (IoT) |

**Support model:**
- Home and Pro: 24 months per feature version
- Enterprise and Education: 36 months per feature version
- LTSC: 5 years mainstream + 5 years extended (Enterprise); 10 years total (IoT)

> **26H1 note:** Windows 11 26H1 is scoped to new device shipments and is not available as an in-place upgrade from 24H2 or 25H2 for existing devices. This follows Microsoft's updated cadence model announced in 2025.

---

## 4. Windows 11 Feature Matrix by Edition

### 4.1 Security Features

| Feature | Home | Pro | Pro WS | Enterprise | Education |
|---|---|---|---|---|---|
| Device Encryption (BitLocker lite) | Yes | Yes | Yes | Yes | Yes |
| BitLocker Drive Encryption (full) | No | Yes | Yes | Yes | Yes |
| BitLocker To Go | No | Yes | Yes | Yes | Yes |
| Credential Guard | No | No | No | Yes | Yes |
| Windows Defender Credential Guard (Hyper-V based) | No | No | No | Yes | Yes |
| Personal Data Encryption (PDE) | No | No | No | Yes | Yes |
| Windows Defender Application Guard (MDAG) | No | No | No | Yes | Yes |
| AppLocker | No | No | No | Yes | Yes |
| App Control for Business (WDAC) | No (can deploy policy) | Yes (policy) | Yes (policy) | Yes (full) | Yes (full) |
| Smart App Control | Yes | Yes | Yes | No (policy-managed) | No (policy-managed) |
| Windows Hello (PIN / biometric) | Yes | Yes | Yes | Yes | Yes |
| Windows Hello for Business | No | Yes | Yes | Yes | Yes |
| Microsoft Pluton (hardware-dependent) | Yes | Yes | Yes | Yes | Yes |
| Virtualization-Based Security (VBS) | Yes | Yes | Yes | Yes | Yes |
| Secure Boot enforcement | Yes | Yes | Yes | Yes | Yes |

### 4.2 Management and Deployment Features

| Feature | Home | Pro | Pro WS | Enterprise | Education |
|---|---|---|---|---|---|
| Active Directory domain join | No | Yes | Yes | Yes | Yes |
| Azure AD / Entra ID join | Limited | Yes | Yes | Yes | Yes |
| Group Policy (Local) | No | Yes | Yes | Yes | Yes |
| Group Policy (Domain) | No | Yes | Yes | Yes | Yes |
| Enterprise-only Group Policy settings | No | No | No | Yes | Yes |
| Windows Update for Business | No | Yes | Yes | Yes | Yes |
| Assigned Access (kiosk mode) | No | Yes | Yes | Yes | Yes |
| Provisioning packages (PPKG) | No | Yes | Yes | Yes | Yes |
| Microsoft Intune co-management | Limited | Yes | Yes | Yes | Yes |
| Windows Autopilot | No | Yes | Yes | Yes | Yes |
| Mobile Device Management (MDM) | Limited | Yes | Yes | Yes | Yes |

### 4.3 Networking and Remote Access

| Feature | Home | Pro | Pro WS | Enterprise | Education |
|---|---|---|---|---|---|
| Remote Desktop (RDP host — incoming) | No | Yes | Yes | Yes | Yes |
| Remote Desktop client (outgoing) | Yes | Yes | Yes | Yes | Yes |
| DirectAccess | No | No | No | Yes | Yes |
| Always On VPN (device tunnel) | No | No | No | Yes | Yes |
| Always On VPN (user tunnel) | No | Yes | Yes | Yes | Yes |
| BranchCache | No | No | No | Yes | Yes |
| SMB Direct (RDMA) | No | No | Yes | No* | No* |
| Wi-Fi Direct | Yes | Yes | Yes | Yes | Yes |

> *SMB Direct is available on Pro for Workstations specifically due to workstation-class hardware certification requirements.

### 4.4 Virtualization and Developer Features

| Feature | Home | Pro | Pro WS | Enterprise | Education |
|---|---|---|---|---|---|
| Hyper-V | No | Yes | Yes | Yes | Yes |
| Windows Sandbox | No | Yes | Yes | Yes | Yes |
| WSL / WSL 2 | Yes | Yes | Yes | Yes | Yes |
| Dev Drive (ReFS-backed) | No | Yes | Yes | Yes | Yes |
| ReFS (full volume creation) | No | No | Yes | No* | No* |
| NVDIMM-N support | No | No | Yes | No | No |
| Sandbox isolated environment | No | Yes | Yes | Yes | Yes |

> *ReFS volume creation outside of Dev Drive is exclusive to Pro for Workstations. Enterprise can read/write ReFS volumes but cannot create them without the Workstations license.

### 4.5 Hardware Limits by Edition

| Limit | Home | Pro | Pro for Workstations | Enterprise | Education |
|---|---|---|---|---|---|
| Maximum RAM | 128 GB | 2 TB | 6 TB | 6 TB | 2 TB |
| Maximum CPU sockets | 1 | 2 | 4 | 2 | 2 |
| Maximum logical processors | 256 | 256 | 512 | 256 | 256 |
| SMB Direct / RDMA | No | No | Yes | No | No |
| NVDIMM-N (persistent memory) | No | No | Yes | No | No |

---

## 5. Windows 11 Hardware Requirements

### 5.1 Minimum Requirements (All Editions)

| Component | Requirement |
|---|---|
| Processor | 1 GHz, 2+ cores, 64-bit; on approved CPU list |
| RAM | 4 GB |
| Storage | 64 GB |
| Firmware | UEFI with Secure Boot enabled |
| TPM | TPM 2.0 (required, not optional) |
| Graphics | DirectX 12 compatible; WDDM 2.0 driver |
| Display | 720p, 9" diagonal, 8 bits per color channel |
| Internet | Required for Home setup; Microsoft Account mandatory for Home |

### 5.2 Approved CPU Baseline

| Manufacturer | Minimum Generation |
|---|---|
| Intel | 8th generation (Coffee Lake) and newer |
| AMD | Zen 2 architecture (Ryzen 3000 series) and newer |
| Qualcomm | Snapdragon 7c and newer (ARM64) |

> **Exception:** Intel Core X-series (Skylake-X), Intel Xeon W-series (Skylake-W), and AMD Threadripper 1000/2000 series are excluded from the supported CPU list despite being newer than the minimums above. Check the Microsoft approved CPU list for per-SKU confirmation.

### 5.3 Feature-Specific Hardware Requirements

| Feature | Additional Hardware Required |
|---|---|
| Windows Hello Face | IR camera (infrared) |
| Windows Hello Fingerprint | Fingerprint reader |
| Windows Hello for Business (FIDO2) | Certified security key or compatible biometric |
| DirectStorage | NVMe SSD + DirectX 12 Ultimate with Shader Model 6.0 |
| Snap Layouts 3-column | 1920px+ horizontal resolution |
| Auto HDR | HDR-capable display |
| TPM-based attestation (for Credential Guard) | TPM 2.0 (firmware or discrete) |
| Microsoft Pluton security processor | Pluton-enabled CPU (AMD Ryzen 6000+, Qualcomm Snapdragon, newer Intel) |
| Wi-Fi 6E features | Wi-Fi 6E certified adapter |

---

## 6. Edition Feature Deep Dives

### 6.1 BitLocker vs. Device Encryption

- **Device Encryption** (Home and all editions as fallback): Requires Modern Standby (InstantGo) or HSTI-compliant hardware. Encrypts the OS drive automatically when signed in with a Microsoft Account; key backed up to Microsoft Account. No management UI beyond on/off toggle.
- **BitLocker Drive Encryption** (Pro and above): Full pre-boot authentication, recovery key management via AD/AAD/file/USB, PIN/TPM/USB key protectors, XTS-AES 128/256 cipher selection, encrypt-used-space-only option, manage-bde CLI, Group Policy control.
- **BitLocker To Go** (Pro and above): BitLocker for removable drives (USB, SD card). Includes read-only compatibility mode for older Windows versions.

### 6.2 AppLocker vs. App Control for Business (WDAC)

| Aspect | AppLocker | App Control for Business (WDAC) |
|---|---|---|
| Licensing | Enterprise / Education | Available on Pro+; full policy authoring Enterprise |
| Policy engine | Kernel rule enforcement via SRP | Hypervisor-Protected Code Integrity (HVCI) |
| Scope | User-mode applications | Kernel + user-mode (drivers + apps) |
| Management | Group Policy / PowerShell | Group Policy, Intune, MEM, PowerShell |
| Recommended path | Legacy; still supported | Microsoft's strategic control plane going forward |
| Audit mode | Yes | Yes |
| Supplemental policies | No | Yes (Enterprise) |

> Microsoft recommends migrating from AppLocker to App Control for Business (formerly WDAC) as the long-term application control strategy. AppLocker remains supported but receives no new feature investment.

### 6.3 Credential Guard and Personal Data Encryption

- **Credential Guard:** Uses VBS (Virtualization-Based Security) to isolate NTLM hashes and Kerberos tickets from the main OS process. Requires Enterprise or Education. Prevents Pass-the-Hash and Pass-the-Ticket attacks. Enabled by default on eligible Enterprise hardware since Windows 11 22H2.
- **Personal Data Encryption (PDE):** Windows 11 Enterprise only. Encrypts individual files per-user using DPAPI-NG backed by Windows Hello for Business credentials. Provides file-level encryption beyond BitLocker's volume-level protection. Files are inaccessible when user is signed out, even to admin.

### 6.4 DirectAccess vs. Always On VPN

| Aspect | DirectAccess | Always On VPN |
|---|---|---|
| Windows requirement | Enterprise / Education | Enterprise (device tunnel); Pro+ (user tunnel) |
| Protocol | IPv6 over IPsec (ISATAP/Teredo/IP-HTTPS) | IKEv2, SSTP, L2TP, OpenVPN (via profile) |
| Infrastructure | Requires Windows Server DA role + PKI | Requires NPS/RADIUS + PKI + VPN gateway |
| Modern management | Limited (no Intune native support) | Full Intune / MEM support via VPN profiles |
| Status | Legacy; no new investment | Microsoft's recommended replacement for DA |
| Platform support | Windows only | Windows, with similar concepts on other platforms |

---

## 7. Upgrade Paths

### 7.1 Windows 10 to Windows 11

- **Free upgrade availability:** Available for Windows 10 Home, Pro, Enterprise, and Education on compatible hardware via Windows Update, the PC Health Check app, or ISO media.
- **Hardware gate:** TPM 2.0, Secure Boot, and approved CPU are strictly enforced during upgrade. Devices not meeting requirements do not receive the upgrade offer.
- **Edition mapping:** Home upgrades to Home; Pro upgrades to Pro; Enterprise upgrades to Enterprise; Education upgrades to Education.
- **LTSC note:** Windows 10 Enterprise LTSC 2019 / 2021 does not have an upgrade path to Windows 11 LTSC 2024 via Windows Update. A clean install or in-place upgrade using LTSC 2024 media is required.

### 7.2 Windows 11 Edition Upgrades

| From | To | Method |
|---|---|---|
| Home | Pro | Purchase Pro upgrade key in Settings > System > Activation; or retail box key |
| Pro | Enterprise | Volume License agreement + KMS/MAK key, or Azure AD-joined + M365 E3/E5 subscription |
| Pro | Education | Requires enrollment in education licensing program |
| Enterprise | Enterprise LTSC | Clean install only; no in-place edition channel switch via Settings |
| Any GA channel | LTSC | Clean install required; LTSC is a separate channel, not an edition key swap |

### 7.3 In-Place Upgrade vs. Clean Install

| Scenario | Recommended Method |
|---|---|
| Win10 Home/Pro → Win11 (same edition) | In-place via Windows Update or Media Creation Tool |
| Win10 Enterprise → Win11 Enterprise | In-place via ISO with volume license key |
| Any edition → LTSC | Clean install from LTSC media; in-place upgrade not supported from GA channel |
| Major hardware change (new motherboard) | Clean install preferred; in-place may cause activation issues |
| Troubleshooting persistent issues | Clean install |
| Preserving applications and data | In-place upgrade (keep files and apps option) |

### 7.4 LTSC-Specific Considerations

- LTSC licenses are purchased separately from GA channel licenses; they are not included in most standard Enterprise agreements without explicit LTSC entitlement.
- LTSC does not receive new Microsoft Store apps, new versions of Edge (until patched separately), or annual Windows feature updates.
- LTSC 2024 (build 26100) shares its codebase with Windows 11 24H2 but ships as a distinct channel.
- Organizations choosing LTSC for stability should plan a migration every 5 years when a new LTSC version ships.
- IoT Enterprise LTSC 2024 extends support to October 2034, making it suitable for embedded and kiosk deployments with 10-year hardware lock-in.

---

## 8. PowerShell and Command-Line Edition Detection

### 8.1 PowerShell Commands

```powershell
# Full OS name, version, and edition ID
Get-ComputerInfo | Select-Object OsName, OsVersion, WindowsEditionId, OsBuildNumber

# Quick edition check via registry
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID

# Full registry properties for current version
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
    Select-Object ProductName, EditionID, ReleaseId, DisplayVersion, CurrentBuild, UBR

# Check if Enterprise features are licensed
(Get-WmiObject -Class SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND LicenseStatus=1").Name
```

### 8.2 DISM Commands

```cmd
:: Current edition
DISM /Online /Get-CurrentEdition

:: All editions this installation can upgrade to (requires valid target key)
DISM /Online /Get-TargetEditions

:: Upgrade edition in-place (example: Pro to Enterprise)
DISM /Online /Set-Edition:ServerEnterprise /ProductKey:XXXXX-XXXXX-XXXXX-XXXXX-XXXXX /AcceptEula
```

### 8.3 Legacy Command-Line Detection

```cmd
:: OS name and version from systeminfo
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"

:: Quick WMI check
wmic os get Caption, Version, BuildNumber, OSArchitecture

:: Check TPM status (relevant for Win11 compliance)
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, ManagedAuthLevel
```

### 8.4 Common EditionID Values

| EditionID Value | Edition |
|---|---|
| `Core` | Windows 10/11 Home |
| `CoreSingleLanguage` | Windows 10/11 Home Single Language |
| `Professional` | Windows 10/11 Pro |
| `ProfessionalWorkstation` | Windows 11 Pro for Workstations |
| `Enterprise` | Windows 10/11 Enterprise |
| `Education` | Windows 10/11 Education |
| `EnterpriseS` | Windows 10/11 Enterprise LTSC |
| `IoTEnterpriseSK` | Windows 10/11 IoT Enterprise LTSC |

---

## 9. Quick Reference Summary

### Windows 10 Support Status (April 2026)

- Home 22H2: **EOL** (October 2025)
- Pro 22H2: **EOL** (October 2025)
- Enterprise 22H2: **Supported** until October 2027
- Enterprise LTSC 2021: **Supported** until January 2027
- Enterprise LTSC 2019: **Supported** until January 2029
- IoT Enterprise LTSC 2021: **Supported** until January 2032
- ESU available for Home/Pro/Enterprise 22H2 at additional cost

### Windows 11 Key Decision Points

| If you need... | Choose... |
|---|---|
| Maximum compatibility and feature access | Enterprise 24H2 or 25H2 |
| 5-year stable baseline, no feature churn | Enterprise LTSC 2024 |
| 10-year embedded / kiosk deployment | IoT Enterprise LTSC 2024 |
| Workstation with >2 TB RAM or 4-socket CPU | Pro for Workstations or Enterprise |
| Education with enterprise security | Education (equivalent to Enterprise) |
| Consumer device, no corporate management | Home or Pro |
| Remote Desktop hosting on non-Enterprise | Pro (minimum) |
| Credential Guard or PDE | Enterprise or Education |
| AppLocker / WDAC full policy authoring | Enterprise or Education |
