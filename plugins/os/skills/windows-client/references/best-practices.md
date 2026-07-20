# Windows Client Best Practices Reference

---

## Desktop Hardening

### CIS Benchmark for Windows Desktop (Level 1 Highlights)

| Setting | CIS L1 Value | Path |
|---|---|---|
| Interactive logon: Don't display last user name | Enabled | Security Options |
| Require CTRL+ALT+DEL | Enabled | Security Options |
| UAC: Behavior for admins | Prompt for consent on secure desktop | Security Options |
| UAC: Virtualize file/registry writes | Enabled | Security Options |
| Windows Firewall: All profiles | On, inbound block | Firewall settings |
| AutoPlay: Disable for all drives | Enabled | Computer Config |
| Bluetooth: Block discovery | Enabled | Computer Config |

### Microsoft Security Baselines (SCT)

Download from Microsoft Security Compliance Toolkit; apply with LGPO.exe:

```powershell
# Apply Windows 11 security baseline
LGPO.exe /g ".\Windows 11 v23H2 Security Baseline\GPOs"

# Verify with Policy Analyzer
PolicyAnalyzer.exe /l ".\Baselines\Win11-v23H2.PolicyRules"
```

### Attack Surface Reduction (ASR) Rules

ASR rules are Defender-based rules that block specific behaviors associated with malware:

```powershell
# Enable key ASR rules via Intune or PowerShell
Set-MpPreference -AttackSurfaceReductionRules_Ids @(
    'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550',  # Block executable content from email
    'D4F940AB-401B-4EFC-AADC-AD5F3C50688A',  # Block Office child processes
    '3B576869-A4EC-4529-8536-B80A7769E899',  # Block Office from creating executable content
    '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84',  # Block Office from injecting into processes
    'D3E037E1-3EB8-44C8-A917-57927947596D',  # Block JS/VBS from launching downloaded content
    '5BEB7EFE-FD9A-4556-801D-275E5FFC04CC',  # Block execution of obfuscated scripts
    '92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B',  # Block Win32 API calls from Office macros
    '01443614-CD74-433A-B99E-2ECDC07BFCA5'   # Block untrusted/unsigned process from USB
) -AttackSurfaceReductionRules_Actions @(1,1,1,1,1,1,1,1)  # 1=Block, 2=Audit
```

### Exploit Protection

```powershell
# View current exploit protection settings
Get-ProcessMitigation -System
Get-ProcessMitigation -Name explorer.exe

# Enable CFG (Control Flow Guard) system-wide
Set-ProcessMitigation -System -Enable CFG

# Export/import for GPO distribution
Get-ProcessMitigation -RegistryConfigFilePath C:\EP_Config.xml
Set-ProcessMitigation -PolicyFilePath C:\EP_Config.xml
```

### Controlled Folder Access

```powershell
# Enable (protects Documents, Desktop, Pictures from ransomware-like writes)
Set-MpPreference -EnableControlledFolderAccess Enabled

# Add protected folders
Add-MpPreference -ControlledFolderAccessProtectedFolders 'D:\FinancialData'

# Allow specific apps to write to protected folders
Add-MpPreference -ControlledFolderAccessAllowedApplications 'C:\Program Files\Backup\backup.exe'
```

### SMBv1 Removal

SMBv1 must be disabled on all desktops -- it is the attack vector for EternalBlue/WannaCry:

```powershell
# Disable SMBv1
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart

# Verify
Get-SmbServerConfiguration | Select-Object EnableSMB1Protocol
```

---

## Intune / MDM Management

### Enrollment Methods

| Method | Scenario | Join Type |
|---|---|---|
| Windows Autopilot | New device OOB provisioning | Entra ID join or Hybrid join |
| Bulk enrollment (provisioning package) | Kiosk / shared device | Entra ID join |
| Auto-enrollment via Group Policy | Existing AD-joined -> co-management | Hybrid Entra ID join |
| BYOD (user-initiated) | Personal devices | Workplace registration |
| Entra ID join at OOBE | Cloud-first organizations | Entra ID join |

### Autopilot Flow

```
OEM ships device with pre-registered Hardware ID
  -> Device powers on, connects to internet
  -> Windows OOBE contacts Autopilot service
  -> Profile applied: skip pages, apply ESP (Enrollment Status Page)
  -> User authenticates with Entra ID
  -> Device enrolls in Intune automatically
  -> Intune pushes compliance policies, configuration profiles, apps
  -> ESP shows progress; user lands on desktop when complete
```

### Compliance Policies

Compliance policies define the minimum security bar; non-compliant devices get Conditional Access blocked:
- Require BitLocker: OS drive encrypted
- Require Secure Boot: Secure Boot state = Enabled
- Minimum OS version: e.g., 10.0.19045 (Win10 22H2)
- Defender real-time protection: On
- Firewall: On

### Configuration Profiles

Replace GPO for cloud-managed devices. Key profile types:
- **Settings Catalog:** Granular CSP-backed settings (mirrors GPO settings)
- **Security Baselines:** Pre-built baseline profiles aligned with Microsoft recommendations
- **Endpoint Security:** Defender AV, firewall, ASR, Disk Encryption (BitLocker) from one blade
- **Administrative Templates:** ADMX-based settings (same as GPO ADMX)
- **Custom OMA-URI:** Direct CSP paths for settings not yet surfaced in UI

### Co-Management with SCCM

When both Intune and SCCM are active, workloads are split:
- Compliance policies
- Resource access (Wi-Fi, VPN, cert profiles)
- Endpoint Protection (Defender)
- Device configuration
- Windows Update policies
- Office 365 client apps
- Client apps (Win32 via Intune vs SCCM)

---

## Update Management

### Windows Update for Business (WUfB)

WUfB is a policy-based approach using Windows Update service directly (no on-premises WSUS required):

| Update Type | Typical Deferral Range | Notes |
|---|---|---|
| Quality Update (monthly CU) | 0-30 days | Security + non-security fixes |
| Feature Update (annual) | 0-365 days | Major OS version upgrade |
| Driver updates | 0-30 days | Optional via WUfB |
| Microsoft product updates | Via WUfB setting | Office, .NET, etc. |

### Intune Update Rings

Intune Update Rings map directly to WUfB registry policies:
- **Ring 0 (Pilot):** Quality defer 0d, Feature defer 0d -- ~5% of fleet
- **Ring 1 (Early):** Quality defer 7d, Feature defer 30d -- ~15% of fleet
- **Ring 2 (Broad):** Quality defer 14d, Feature defer 90d -- remaining fleet
- **Pause updates:** Temporarily halt for up to 35 days when a bad update ships

### Delivery Optimization

DO reduces WAN bandwidth by enabling peer-to-peer download:

```powershell
# Check DO mode
Get-DeliveryOptimizationStatus | Select-Object DownloadMode, DownloadModeSrc
# Mode 0=Off, 1=LAN, 2=Group, 3=Internet, 99=Bypass, 100=Simple

# Monthly statistics
Get-DeliveryOptimizationPerfSnapThisMonth
```

### Feature Update Targeting

```powershell
# Pin to specific Windows 11 version
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
    -Name 'TargetReleaseVersion' -Value 1
Set-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' `
    -Name 'TargetReleaseVersionInfo' -Value '24H2'
```

---

## BitLocker Deployment

### Enabling BitLocker -- Requirements and Methods

| Method | TPM | PIN | Scenario |
|---|---|---|---|
| TPM-only (Device Encryption) | Required | None | Consumer, simplified |
| TPM + PIN | Required | Yes (6+ digit) | Enterprise recommended |
| TPM + Network Unlock | Required | Network-based | Domain-joined, always unlocked on corp |
| Password-only | Not required | Password | USB/removable (BitLocker To Go) |

```powershell
# Enable with TPM+PIN
$pin = ConvertTo-SecureString "123456" -AsPlainText -Force
Enable-BitLocker -MountPoint C: -EncryptionMethod XtsAes256 -TPMandPINProtector -Pin $pin

# Add recovery key and back up to AD
Add-BitLockerKeyProtector -MountPoint C: -RecoveryPasswordProtector
$keyID = (Get-BitLockerVolume C:).KeyProtector |
    Where-Object KeyProtectorType -eq RecoveryPassword
Backup-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $keyID.KeyProtectorId

# Back up to Entra ID (Intune-managed)
BackupToAAD-BitLockerKeyProtector -MountPoint C: -KeyProtectorId $keyID.KeyProtectorId
```

### Device Encryption (Simplified BitLocker)

Consumer-grade automatic encryption on InstantGo/Modern Standby devices:
- Enabled automatically on Entra ID join or Microsoft account sign-in
- Uses XTS-AES 128-bit; recovery key backed to Microsoft account or Entra ID
- Check: `manage-bde -status C:`
- No PIN required; transparent to user

### BitLocker GPO/Intune Policies

Key settings path: `Computer Config\Admin Templates\Windows Components\BitLocker Drive Encryption`
- Require additional authentication at startup
- Encryption method: XTS-AES 256 recommended
- Recovery key backup: Required for AD or Entra ID
- Startup PIN length: Minimum 6 digits

---

## Application Management

### winget Operations

```powershell
# Install (silent, no prompts)
winget install --id Microsoft.VisualStudioCode --silent `
    --accept-package-agreements --accept-source-agreements

# Upgrade all installed packages
winget upgrade --all --silent --include-unknown

# Export installed app list
winget export -o apps.json

# Import / restore from list
winget import -i apps.json --accept-package-agreements

# Configure with DSC YAML
winget configure --file .\dev-machine.dsc.yaml
```

### MSIX Deployment via PowerShell

```powershell
# Add MSIX package
Add-AppxPackage -Path .\App.msix

# Provision for all users (requires admin)
Add-AppxProvisionedPackage -Online -PackagePath .\App.msix -SkipLicense

# Remove Store app for all users
Get-AppxPackage -Name Microsoft.ZuneMusic -AllUsers | Remove-AppxPackage -AllUsers
```

### Application Compatibility

- **Program Compatibility Assistant (PCA):** Monitors app crashes and offers compatibility mode
- **Compatibility modes:** Windows 7/8/8.1, reduced color, 640x480, DPI scaling
- **Registry:** `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers`
- **Compatibility Administrator (ACT):** Create shims for legacy apps; deploy via GPO with `sdbinst.exe`

### AppLocker vs App Control for Business (WDAC)

| Aspect | AppLocker | App Control for Business (WDAC) |
|---|---|---|
| Licensing | Enterprise / Education | Available on Pro+; full authoring Enterprise |
| Policy engine | Kernel rule enforcement via SRP | Hypervisor-Protected Code Integrity (HVCI) |
| Scope | User-mode applications | Kernel + user-mode (drivers + apps) |
| Recommended path | Legacy; still supported | Microsoft's strategic direction |

Microsoft recommends migrating from AppLocker to App Control for Business as the long-term strategy.

---

## Group Policy vs Intune

| Capability | Group Policy (ADMX) | Intune (MDM/Settings Catalog) |
|---|---|---|
| Scope | Domain-joined devices | Entra ID-joined / hybrid-joined |
| Delivery | GPO, SYSVOL replication | HTTPS push from Microsoft Graph |
| LTSC support | Full | Full (Intune supports LTSC) |
| Conflict resolution | OU hierarchy / WMI filter | Assignment groups / filters |
| Reporting | RSOP, GPRESULT | Intune compliance reports |
| Offline enforcement | Yes (cached GPO) | Delayed (requires connectivity) |
