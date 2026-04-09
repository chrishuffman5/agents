# Windows Server 2022 — Version-Specific Research

**Scope:** Features NEW or CHANGED in Windows Server 2022 only. Cross-version content lives in references/.
**Support:** Mainstream support ends October 14, 2026. Extended support ends October 14, 2031.
**Build:** 10.0.20348 (released August 18, 2021, GA)
**Editions:** Standard, Datacenter, Datacenter: Azure Edition

---

## 1. Secured-Core Server

### Overview

Secured-Core Server is Microsoft's hardware-rooted security certification program, first formally introduced as a shipping feature in Windows Server 2022. It brings together firmware protection, Virtualization Based Security (VBS), and hardware-backed integrity verification into a unified compliance posture. It requires certified hardware from OEM partners.

### Requirements

- TPM 2.0 (Trusted Platform Module)
- UEFI Secure Boot enabled
- CPU with support for Dynamic Root of Trust for Measurement (DRTM) — Intel TXT or AMD SKINIT
- Hardware that passes Microsoft's Secured-Core Server certification

### Components

**System Guard Secure Launch (DRTM)**
Uses CPU-level Dynamic Root of Trust (DRTM) to measure the OS loader before hand-off. Ensures the hypervisor launches from a known-good state even if BIOS/UEFI firmware is compromised. This is distinct from SRTM (Static Root of Trust, which is standard Secure Boot measuring firmware at power-on).

**Virtualization Based Security (VBS)**
Uses Hyper-V to create an isolated memory region (Virtual Secure Mode / VSM). Hypervisor-enforced Code Integrity (HVCI) runs inside VSM and validates all kernel-mode code before execution.

**Hypervisor-Protected Code Integrity (HVCI)**
Also called "Memory Integrity". Runs in VSM; prevents unsigned or tampered kernel drivers from loading. In Windows Server 2022, HVCI can be enforced by policy — it was optional in earlier versions.

**Firmware Protection**
System Management Mode (SMM) protection via Windows UEFI CA revocation and SMM isolation. Prevents firmware-level rootkits from persisting across reboots.

**Secure Boot (UEFI)**
Prevents unauthorized operating systems or bootloaders from loading. Required as a baseline for Secured-Core.

### Verification Commands

```powershell
# Check if Virtualization Based Security is running
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object VirtualizationBasedSecurityStatus,
                  SecurityServicesRunning,
                  SecurityServicesConfigured,
                  CodeIntegrityPolicyEnforcementStatus

# VirtualizationBasedSecurityStatus: 0=Off, 1=Configured, 2=Running
# SecurityServicesRunning: 1=Credential Guard, 2=HVCI, 4=System Guard Secure Launch
# SecurityServicesConfigured: same bitmask — configured but possibly not yet running

# Check Secure Boot state
Confirm-SecureBootUEFI   # Returns $true if Secure Boot is enabled

# Check TPM status and version
Get-Tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, ManufacturerId

# Get TPM version (must be 2.0 for Secured-Core)
Get-CimInstance -Namespace root\cimv2\Security\MicrosoftTpm -ClassName Win32_Tpm |
    Select-Object SpecVersion, IsActivated_InitialValue, IsEnabled_InitialValue

# Check HVCI specifically (via registry — policy setting)
$hvciKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
if (Test-Path $hvciKey) {
    Get-ItemProperty -Path $hvciKey | Select-Object Enabled, WasEnabledBy
}

# System Guard Secure Launch status
$sgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard'
if (Test-Path $sgKey) {
    Get-ItemProperty -Path $sgKey | Select-Object Enabled
}

# Check DRTM (Secure Launch) from msinfo32 alternative — DeviceGuard status
(Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard).SecurityServicesRunning
# Bit 4 (value 4) = System Guard Secure Launch running
```

### Enable / Configure

```powershell
# Enable VBS via Group Policy or registry
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' `
    -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord

# Enable HVCI (requires reboot)
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' `
    -Name 'Enabled' -Value 1 -Type DWord

# Enable via Windows Security app or DGREADINESS tool
# C:\Windows\System32\DGReadiness.ps1 (built-in readiness check tool)
```

### Pitfalls

- Secured-Core requires OEM-certified hardware. Not all hardware that supports TPM + Secure Boot qualifies.
- HVCI may block legitimate unsigned drivers (common with older hardware drivers). Test in audit mode first.
- DRTM requires both CPU support AND BIOS/firmware that implements it. Enable in BIOS/UEFI settings before Windows can use it.
- VBS has a small performance overhead on workloads that make frequent kernel transitions (~5% in typical workloads per Microsoft benchmarks).
- Server Core installation is recommended for Secured-Core to minimize attack surface.

---

## 2. TLS 1.3 Enabled by Default

### Overview

Windows Server 2022 is the first Windows Server version where **TLS 1.3 is enabled by default** for all Schannel-based connections (IIS, WinRM, RDP, LDAP over TLS, etc.). Additionally, **TLS 1.0 and TLS 1.1 are disabled by default** — a major breaking change for environments with legacy clients.

### Default State in 2022

| Protocol  | Default State in 2022 | Default State in 2019 |
|-----------|----------------------|----------------------|
| TLS 1.3   | Enabled              | Disabled             |
| TLS 1.2   | Enabled              | Enabled              |
| TLS 1.1   | Disabled             | Enabled              |
| TLS 1.0   | Disabled             | Enabled              |
| SSL 3.0   | Disabled             | Disabled             |

### TLS 1.3 Cipher Suites (2022 defaults)

TLS 1.3 has its own fixed cipher suite list (separate from TLS 1.2):
- TLS_AES_256_GCM_SHA384
- TLS_AES_128_GCM_SHA256
- TLS_CHACHA20_POLY1305_SHA256 (added via Windows update, not in initial GA)

TLS 1.3 cipher suites are not configurable via the classic Schannel cipher suite registry path — they are hardcoded in the TLS 1.3 specification. TLS 1.3 also removes RSA key exchange and requires forward secrecy.

### Registry Management

```powershell
# Check current TLS protocol states
$protocols = @('TLS 1.0', 'TLS 1.1', 'TLS 1.2', 'TLS 1.3')
foreach ($proto in $protocols) {
    $serverKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Server"
    $clientKey = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$proto\Client"

    $serverEnabled = if (Test-Path $serverKey) {
        (Get-ItemProperty -Path $serverKey -ErrorAction SilentlyContinue).Enabled
    } else { 'Not set (default)' }

    $clientEnabled = if (Test-Path $clientKey) {
        (Get-ItemProperty -Path $clientKey -ErrorAction SilentlyContinue).Enabled
    } else { 'Not set (default)' }

    [PSCustomObject]@{
        Protocol      = $proto
        ServerEnabled = $serverEnabled
        ClientEnabled = $clientEnabled
    }
}

# Re-enable TLS 1.0 (legacy compatibility — NOT recommended for new deployments)
$tls10Server = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
New-Item -Path $tls10Server -Force | Out-Null
Set-ItemProperty -Path $tls10Server -Name 'Enabled' -Value 1 -Type DWord
Set-ItemProperty -Path $tls10Server -Name 'DisabledByDefault' -Value 0 -Type DWord

# Re-enable TLS 1.1 (legacy compatibility)
$tls11Server = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
New-Item -Path $tls11Server -Force | Out-Null
Set-ItemProperty -Path $tls11Server -Name 'Enabled' -Value 1 -Type DWord
Set-ItemProperty -Path $tls11Server -Name 'DisabledByDefault' -Value 0 -Type DWord

# View TLS 1.2 cipher suites (still configurable)
Get-TlsCipherSuite | Where-Object { $_.Name -like '*_SHA256' -or $_.Name -like '*_SHA384' } |
    Select-Object Name, Exchange, Cipher, Hash
```

### Cipher Suite Ordering

```powershell
# View current cipher suite priority order
Get-TlsCipherSuite | Select-Object Name, Exchange, Cipher, Hash, CipherLength

# Disable a specific weak cipher suite
Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_CBC_SHA'

# Enable and prioritize a specific cipher suite
Enable-TlsCipherSuite -Name 'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384' -Position 0
```

### Impact on Legacy Clients

- SQL Server Management Studio versions before 18.x may fail to connect
- Older Java clients using Java < 8u261 do not support TLS 1.2+
- LDAP clients that do not support TLS 1.2+ will fail LDAPS connections
- Applications hard-coded to negotiate TLS 1.0 or 1.1 will fail

### Pitfalls

- Merely having the registry key absent does NOT always mean default enabled — test with `Test-NetConnection` or Wireshark to verify.
- TLS 1.3 requires the client AND server to both support it; falls back to 1.2 automatically.
- IIS will prefer TLS 1.3 over 1.2 when both endpoints support it.
- .NET Framework applications use Schannel by default on Windows — they benefit automatically. .NET Core / .NET 5+ applications may have their own TLS settings.

---

## 3. SMB Improvements

### SMB Compression

New in Windows Server 2022. Compresses SMB data in-transit, reducing bandwidth usage. Useful for WAN links or high-latency networks. Compression happens at the SMB layer — does NOT require data to be uncompressed at rest.

**Supported algorithms:**
- LZ4 (default, fastest)
- PATTERN_V1 (for pattern-heavy data, e.g., sparse files with repeated zeros)
- ZSTD (added via later update, better ratio than LZ4)
- Xpress (older, lower compression)

```powershell
# Enable SMB compression on server
Set-SmbServerConfiguration -EnableSmbCompression $true -Confirm:$false

# Enable SMB compression on client (when connecting to servers)
Set-SmbClientConfiguration -EnableSmbCompression $true -Confirm:$false

# Check server SMB compression setting
Get-SmbServerConfiguration | Select-Object EnableSmbCompression

# Check per-connection compression status (active sessions)
Get-SmbSession | Select-Object ClientComputerName, ClientUserName, *compress*

# Set preferred compression algorithm (server side)
Set-SmbServerConfiguration -SmbCompressionAlgorithm 'LZ4' -Confirm:$false
# Values: 'LZNT1', 'Xpress', 'XpressHuffman', 'LZ4', 'Zstd'
```

**Compression bypass for already-compressed data:**
SMB in 2022 detects whether data is already compressed (encrypted files, ZIP archives, JPEG) and skips compression to save CPU cycles.

### AES-256-GCM / CCM Encryption

Windows Server 2022 adds AES-256-GCM and AES-256-CCM for SMB encryption, up from the AES-128 modes in Server 2019. AES-256 provides stronger encryption at the cost of slightly more CPU.

```powershell
# Set SMB encryption cipher suite preference (server)
Set-SmbServerConfiguration -EncryptionCiphers 'AES_256_GCM,AES_128_GCM' -Confirm:$false

# Require encryption for all connections (not just specific shares)
Set-SmbServerConfiguration -EncryptData $true -Confirm:$false

# Require encryption on a specific share
Set-SmbShare -Name 'SecureShare' -EncryptData $true

# Check current encryption settings
Get-SmbServerConfiguration | Select-Object EncryptData, EncryptionCiphers, RejectUnencryptedAccess
```

### SMB Signing Changes

Windows Server 2022 (and Windows 11) makes SMB signing required by default for all connections from Windows clients. This is a security improvement to prevent relay attacks.

```powershell
# Check signing configuration
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature, EnableSecuritySignature

# Enable required signing (already default in 2022)
Set-SmbServerConfiguration -RequireSecuritySignature $true -Confirm:$false
```

### SMB over QUIC (Azure Edition Only in 2022)

SMB over QUIC tunnels SMB traffic over QUIC (UDP port 443) instead of TCP port 445, providing:
- Firewall-friendly traversal (port 443)
- Built-in TLS 1.3 encryption for all traffic
- Resilience to network path changes (connection migration)
- Eliminates the need for VPN for remote file access scenarios

**Availability in 2022:** Azure Edition ONLY. Standard and Datacenter editions do NOT support SMB over QUIC. SMB over QUIC was added to Standard/Datacenter in Windows Server 2025.

```powershell
# Azure Edition only: Enable SMB over QUIC
# Requires a TLS certificate on the server

# Check if SMB over QUIC is available
Get-WindowsFeature -Name FS-SMB-Quic  # Not available on Standard/Datacenter

# On Azure Edition:
Get-SmbServerConfiguration | Select-Object *quic*

# Set up SMB over QUIC mapping (Azure Edition)
New-SmbServerCertificateMapping -Name 'QuicCert' -Thumbprint '<cert-thumbprint>' `
    -StoreName 'My' -Subject 'fileserver.contoso.com'
```

### SMB Direct (RDMA) Compression

Windows Server 2022 adds compression support for SMB Direct (RDMA) connections, combining the bandwidth efficiency of compression with the low-latency of RDMA networking (iWARP, RoCE, InfiniBand).

### Pitfalls

- SMB compression can increase CPU usage significantly on servers processing many simultaneous connections. Monitor CPU before enabling globally.
- AES-256 encryption modes require both client and server on Windows Server 2022 / Windows 11 or later. Older clients fall back to AES-128.
- Required SMB signing (the 2022 default) increases CPU overhead slightly. For very high-throughput SMB workloads, measure before/after.
- SMB over QUIC requires valid TLS certificates — self-signed is supported but adds management overhead.

---

## 4. Hotpatch (Azure Edition Only in 2022)

### Overview

Hotpatch allows security updates to be applied to running processes in memory without requiring a server reboot. The patch is injected into the running process's code pages. This is different from traditional patching which replaces files on disk and requires reboot to load new code.

**Availability in 2022:** Azure Edition ONLY, running on Azure VMs or Azure Stack HCI. Requires Azure Arc enrollment.

### How Hotpatch Works

1. A baseline cumulative update is installed (requires reboot) — typically quarterly.
2. Between baselines, Hotpatch-eligible security updates are released monthly.
3. Hotpatch updates are applied by the Azure Update Manager or Windows Update — they patch in-memory code pages of running processes.
4. No restart required for hotpatch updates. The server maintains 100% uptime during these months.
5. Hotpatch updates are a subset of the full cumulative update — they address the highest-priority CVEs.

**Typical annual reboot schedule with Hotpatch:**
- January: Baseline CU (reboot required)
- February: Hotpatch (no reboot)
- March: Hotpatch (no reboot)
- April: Baseline CU (reboot required)
- May: Hotpatch (no reboot)
- ...and so on quarterly.

### Requirements

- Windows Server 2022 Datacenter: Azure Edition
- Running on Azure VM or Azure Stack HCI
- Azure Arc agent installed and enrolled
- Azure Update Manager subscription

### Azure Arc Enrollment

```powershell
# Install Azure Arc agent (azcmagent)
# Download from: https://aka.ms/AzureConnectedMachineAgent

# Connect to Azure Arc (run on the server)
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect `
    --subscription-id '<subscription-id>' `
    --resource-group '<resource-group>' `
    --tenant-id '<tenant-id>' `
    --location '<azure-region>'

# Verify Arc connection status
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' show

# Check Arc agent service
Get-Service -Name 'himds' | Select-Object Name, Status, StartType

# Check hotpatch enrollment status via registry
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\Installed' `
    -ErrorAction SilentlyContinue
```

### Monitoring Hotpatch Compliance

```powershell
# Check pending Windows Updates (including hotpatch status)
$updateSession = New-Object -ComObject Microsoft.Update.Session
$searcher = $updateSession.CreateUpdateSearcher()
$results = $searcher.Search('IsInstalled=0 and Type=''Software''')
$results.Updates | Select-Object Title, IsDownloaded, IsMandatory

# Check installed hotpatch updates (they have specific KB identifiers)
Get-HotFix | Where-Object { $_.Description -eq 'Hotfix' } |
    Sort-Object InstalledOn -Descending | Select-Object -First 10

# Check Windows Update history for hotpatch entries
$updateSession = New-Object -ComObject Microsoft.Update.Session
$searcher = $updateSession.CreateUpdateSearcher()
$histCount = $searcher.GetTotalHistoryCount()
$history = $searcher.QueryHistory(0, [Math]::Min($histCount, 50))
$history | Where-Object { $_.Title -like '*Hotpatch*' -or $_.Title -like '*hotpatch*' } |
    Select-Object Title, Date, ResultCode

# Hotpatch-related registry indicators
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
    Select-Object CurrentBuild, CurrentBuildNumber, UBR, DisplayVersion
```

### Subscription and Cost

- Hotpatch is included with Windows Server 2022 Datacenter: Azure Edition license when running on Azure.
- On Azure Stack HCI, requires Azure Arc-enabled servers and may require Azure Update Manager license.

### Pitfalls

- Hotpatch does NOT cover all security updates — only a subset. Full baseline CUs (with reboots) are still required quarterly.
- Hotpatch does not patch the kernel itself for certain vulnerability classes; kernel-level patches still require reboots.
- If a hotpatch fails to apply (validation error), the system falls back to standard patching at the next patch cycle.
- Baseline months (quarterly) still require maintenance windows for reboots.
- Non-security updates (feature updates, driver updates) are not hotpatched.

---

## 5. Datacenter: Azure Edition

### Overview

Windows Server 2022 introduced a new edition tier: **Datacenter: Azure Edition**. This is the first time Microsoft released a Windows Server edition that is exclusively cloud-native.

### Where It Runs

- Azure Virtual Machines (specific VM SKUs)
- Azure Stack HCI

**Does NOT run on:**
- Physical on-premises servers
- VMware, Hyper-V on-premises (non-HCI), or other hypervisors

### Unique Features vs Datacenter

| Feature | Datacenter: Azure Edition | Standard / Datacenter |
|---------|--------------------------|----------------------|
| Hotpatch | Yes | No |
| SMB over QUIC | Yes | No (added in 2025) |
| Azure Extended Networking | Yes | No |
| Faster feature cadence | Yes (via Windows Update) | No |

### Azure Extended Networking

Allows Azure VMs to retain their on-premises IP addresses after migration to Azure, without re-subnetting. Uses a stretched VxLAN-like overlay.

### Licensing

- Priced identically to Datacenter edition
- License is Azure-only; cannot be transferred to on-premises
- Available in Azure Marketplace or included in Azure Hybrid Benefit calculations

### Pitfalls

- Cannot use Azure Edition license for on-premises disaster recovery VMs — a separate Standard or Datacenter license is required.
- Features unique to Azure Edition (Hotpatch, SMB/QUIC) will not be in Standard/Datacenter until Windows Server 2025.
- Azure Edition does not change Hyper-V guest licensing rights — Standard still covers 2 VMs, Datacenter covers unlimited.

---

## 6. Nested Virtualization on AMD

### Overview

Windows Server 2022 is the **first Windows Server version to support nested virtualization on AMD processors**. Previously (2019 and earlier), nested virtualization (running Hyper-V inside a Hyper-V VM) was Intel-only.

AMD nested virtualization support requires:
- AMD EPYC (Naples, Rome, Milan, or later) or Ryzen Pro with AMD-V + RVI (NPT)
- Host running Windows Server 2022 (or Windows 11)
- Hyper-V role installed on host

### Configuration

```powershell
# Enable nested virtualization for a specific VM (run on Hyper-V HOST)
Set-VMProcessor -VMName 'NestedVM' -ExposeVirtualizationExtensions $true

# Verify the VM supports nested virt
Get-VMProcessor -VMName 'NestedVM' | Select-Object ExposeVirtualizationExtensions

# Inside the nested VM, verify Hyper-V can be installed
# (Run inside the nested VM after enabling)
Get-WindowsFeature -Name Hyper-V

# Enable MAC address spoofing (required for nested VM networking)
Set-VMNetworkAdapter -VMName 'NestedVM' -MacAddressSpoofing On
```

### Use Cases

- Development and testing environments running Hyper-V or WSL inside VMs
- Azure Stack HCI validation labs
- Container hosts (Docker Desktop, kind) running inside VMs
- Training environments

### Pitfalls

- AMD nested virtualization performance is lower than bare-metal (additional virtualization layers add latency).
- Not all AMD CPUs support nested virtualization — verify CPUID flags: `SVM`, `NPT`, `RVI`.
- Live migration between Intel and AMD hosts with nested virtualization enabled is not supported.
- Nested VMs cannot use GPU pass-through or SR-IOV.

---

## 7. DNS over HTTPS (DoH)

### Overview

Windows Server 2022 includes client-side **DNS over HTTPS (DoH)** support in the Windows DNS client (dnscache service). DoH encrypts DNS queries using HTTPS to prevent eavesdropping and DNS spoofing.

**Important distinction:** This is CLIENT-side DoH (the server making DNS lookups). The Windows Server 2022 DNS Server role does NOT natively act as a DoH resolver/forwarder — it forwards traditionally.

### Configuration

```powershell
# Check current DoH server configurations
Get-DnsClientDohServerAddress

# Add a DoH server (e.g., Cloudflare)
Add-DnsClientDohServerAddress -ServerAddress '1.1.1.1' `
    -DohTemplate 'https://cloudflare-dns.com/dns-query' `
    -AllowFallbackToUdp $true -AutoUpgrade $true

# Add Google DoH
Add-DnsClientDohServerAddress -ServerAddress '8.8.8.8' `
    -DohTemplate 'https://dns.google/dns-query' `
    -AllowFallbackToUdp $true -AutoUpgrade $true

# Remove a DoH server
Remove-DnsClientDohServerAddress -ServerAddress '1.1.1.1'

# Check DNS client settings
Get-DnsClient | Select-Object InterfaceAlias, ConnectionSpecificSuffix, UseSuffixWhenRegistering
```

### Registry Configuration

```powershell
# DoH policy per adapter (alternative to cmdlets)
# HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\{adapter-guid}\DohInterfaceSettings

# Check effective DoH configuration
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' `
    -Name 'EnableAutoDoh' -ErrorAction SilentlyContinue
```

### Group Policy

DoH can be configured via Group Policy:
- Path: `Computer Configuration > Administrative Templates > Network > DNS Client`
- Policy: "Configure DNS over HTTPS (DoH) name resolution"
- Options: Off, Allow (fallback to UDP), Require (DoH only, fail if unavailable)

### Server-Side Considerations

- The Windows DNS Server role does not support acting as a DoH forwarder in 2022 (added in Server 2025).
- Use DNS over TLS or a proxy (Unbound, Nginx, Pi-hole) if DoH server-side forwarding is needed.
- Corporate environments using internal DNS servers: DoH bypass for internal zones is configurable via NRPT (Name Resolution Policy Table).

### Pitfalls

- DoH will bypass local DNS interceptors (firewalls, proxies) that inspect port 53. Plan security policies accordingly.
- AllowFallbackToUdp should be set based on security requirements — disabled if DNS privacy is critical.
- Not all DNS providers listed in Windows are supported on Server — test each template URL.

---

## 8. Azure Arc Integration

### Overview

Windows Server 2022 ships with improved first-party support for **Azure Arc for Servers**, allowing on-premises Windows Server machines to be managed through the Azure portal. This is not exclusive to 2022, but 2022 is the first version where Arc is a recommended default management layer.

### Capabilities via Azure Arc

- **Azure Policy** — enforce compliance policies on on-premises servers
- **Azure Monitor** — collect metrics and logs via Azure Monitor Agent (AMA)
- **Microsoft Defender for Servers** — threat protection for on-premises
- **Azure Update Manager** — unified update management across on-prem and cloud
- **Azure Automation** — runbooks for on-premises automation
- **Azure Key Vault extension** — certificate distribution to on-prem servers
- **Inventory and change tracking** via Azure Resource Graph

### Agent Installation

```powershell
# Download and install Azure Connected Machine Agent
# Method 1: Via script generated from Azure portal
# Method 2: Manual

$agentUrl = 'https://aka.ms/AzureConnectedMachineAgent'
$installerPath = "$env:TEMP\AzureConnectedMachineAgent.msi"
Invoke-WebRequest -Uri $agentUrl -OutFile $installerPath
Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /qn" -Wait

# Connect to Azure Arc
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' connect `
    --subscription-id '<subscription-id>' `
    --resource-group '<resource-group>' `
    --tenant-id '<tenant-id>' `
    --location 'eastus'

# Check agent status
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' show

# Check Arc agent services
Get-Service -Name 'himds', 'ExtensionService', 'GCArcService' |
    Select-Object Name, Status, StartType
```

### Verification

```powershell
# Verify Arc connectivity
& 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe' check

# Check heartbeat (last time agent reported to Azure)
Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Azure Connected Machine Agent' `
    -ErrorAction SilentlyContinue
```

### Pitfalls

- Azure Arc agent requires outbound HTTPS (port 443) to Azure endpoints. Proxy configuration is often needed in enterprise environments.
- Arc-enrolled servers count against Azure subscription limits — plan resource group organization.
- Azure Monitor Agent (AMA) replaces the older Log Analytics Agent (MMA) — do not install both.

---

## 9. Storage Improvements

### Storage Bus Cache for Standalone Servers

In Windows Server 2019 and earlier, Storage Bus Cache (using NVMe/SSD as a cache tier for HDD) was only available with Storage Spaces Direct (S2D) clusters. Windows Server 2022 enables Storage Bus Cache for **standalone servers** (non-clustered).

```powershell
# Enable Storage Bus Cache on standalone server (non-S2D)
Enable-StorageBusCache

# Check Storage Bus Cache status
Get-StorageBusCache

# View cache bindings (which SSDs cache which HDDs)
Get-StorageBusCacheStore

# Configure cache mode per storage pool
# Write-back vs Write-through
Set-StorageBusCache -OperationalMode WriteThrough  # or WriteBack
```

### ReFS Improvements

**File-Level Snapshots (ReFS Block Cloning extended)**
ReFS in 2022 improves block cloning for backup applications — instant file snapshots without copying data.

**Deduplication on ReFS (preview/experimental in 2022)**
Data Deduplication can be enabled on ReFS volumes (was NTFS-only in prior versions). This is primarily targeted at VDI/virtual machine workloads.

```powershell
# Enable deduplication on ReFS volume (2022 only, requires Data Dedup feature)
Enable-DedupVolume -Volume 'D:\' -UsageType HyperV
# Note: 'HyperV' type is optimized for VHD/VHDX workloads on ReFS

# Check dedup status on ReFS
Get-DedupVolume -Volume 'D:\'
Get-DedupStatus -Volume 'D:\'
```

**Nested Resiliency (ReFS on Storage Spaces)**
Mirror-accelerated parity improvements for faster rebuild times and better random write performance.

### Adjustable Storage Repair Speed

Storage Spaces repair (resync after disk failure) speed is now configurable without registry hacks.

```powershell
# Set repair speed (0=slowest, 100=fastest)
# Higher speed = faster recovery but more I/O impact on workloads
Set-StoragePool -FriendlyName 'Pool1' -RepairPolicy Sequential
# Or for faster repair:
Set-StoragePool -FriendlyName 'Pool1' -RepairPolicy Parallel

# Check current repair policy
Get-StoragePool -FriendlyName 'Pool1' | Select-Object FriendlyName, RepairPolicy

# Monitor active repair jobs
Get-StorageJob | Select-Object Name, OperationType, PercentComplete, EstimatedCompletionTime
```

### Pitfalls

- Storage Bus Cache for standalone requires SSD and HDD in the same server (NVMe recommended for cache tier).
- ReFS deduplication in 2022 is not fully supported for all workload types — verify with Microsoft support for production use.
- Adjusting repair speed to max during business hours can significantly impact I/O performance.

---

## 10. Windows Containers Improvements

### HostProcess Containers

New container type in Windows Server 2022. HostProcess containers run directly on the **host's** network namespace and can access host storage and devices. This is similar to Linux privileged containers.

**Use cases:**
- Node-level configuration tasks in Kubernetes
- Device driver installation across cluster nodes
- DaemonSet equivalents for Windows nodes (monitoring agents, log collectors)
- Cluster setup and bootstrap automation

**Key differences from standard containers:**
- Shares host network namespace (no container-specific IP)
- Can access host file system at `$env:CONTAINER_SANDBOX_MOUNT_POINT`
- Can run as local or domain service accounts
- Requires specific security context in Kubernetes pod spec

```powershell
# Verify HostProcess container support (Windows Server 2022+)
Get-WindowsFeature -Name Containers

# Check containerd version (must support HostProcess)
containerd --version

# HostProcess container example (Docker):
# docker run --isolation=process --network=host mcr.microsoft.com/windows/servercore:ltsc2022 cmd.exe

# In Kubernetes YAML (requires containerd 1.6+):
# securityContext:
#   windowsOptions:
#     hostProcess: true
#     runAsUserName: "NT AUTHORITY\\SYSTEM"
```

### gMSA Improvements for Containers

Group Managed Service Accounts (gMSA) allow containers to authenticate to Active Directory without embedding credentials. Windows Server 2022 adds:

- **gMSA without domain join** — the container HOST does not need to be domain-joined (uses a portable credential spec and a "helper" service account)
- Improved gMSA spec file handling

```powershell
# Check gMSA plugin for containers
Get-Module -ListAvailable -Name CredentialSpec

# Create a credential spec file for a container
New-CredentialSpec -AccountName 'ContainerApp$' -Path 'C:\ProgramData\Docker\CredentialSpecs\app.json'

# List credential specs
Get-CredentialSpec

# For non-domain-joined host scenario:
# Requires CCGPLUGIN (Credential Guard Plugin) registration
# and a standard user account with "allowed to retrieve password" permission
```

### Smaller Container Base Images

Windows Server 2022 introduced optimized container base images:
- `mcr.microsoft.com/windows/servercore:ltsc2022` — ~2.3GB (reduced from ltsc2019)
- `mcr.microsoft.com/windows/nanoserver:ltsc2022` — ~98MB
- `mcr.microsoft.com/windows/server:ltsc2022` — full Windows Server 2022

```powershell
# Pull the 2022-specific container images
docker pull mcr.microsoft.com/windows/servercore:ltsc2022
docker pull mcr.microsoft.com/windows/nanoserver:ltsc2022

# Check image sizes
docker images mcr.microsoft.com/windows/*
```

### Pitfalls

- HostProcess containers require containerd (not Docker Engine) as the container runtime in Kubernetes.
- HostProcess containers running as SYSTEM have full host access — treat them with the same security rigor as host processes.
- gMSA without domain join requires Windows Server 2022 Host + 2019+ domain controllers running gMSA support.
- Container images are version-locked: ltsc2022 images only run on 2022 hosts (Windows container OS version matching requirement).

---

## 11. Hyper-V Improvements

### vTPM for Linux Guests

Windows Server 2022 adds virtual TPM (vTPM) support for Linux virtual machines running under Hyper-V. Previously vTPM was Windows-only.

**Supported Linux distros with vTPM:**
- Ubuntu 20.04+
- RHEL 8+
- SLES 15 SP3+
- Debian 11+

```powershell
# Enable vTPM for a Linux VM (run on Hyper-V host)
# VM must use Generation 2 and have Secure Boot configured for Linux
Set-VMFirmware -VMName 'UbuntuVM' -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
Enable-VMTPM -VMName 'UbuntuVM'

# Verify vTPM is enabled
Get-VMSecurity -VMName 'UbuntuVM' | Select-Object TpmEnabled, KsdEnabled

# Inside the Linux VM, verify TPM:
# tpm2_getcap properties-fixed
# ls /dev/tpm*
```

### Processor Compatibility Mode for Live Migration

Windows Server 2022 improves the processor compatibility mode for live migration, allowing migration between a wider range of CPU generations (e.g., Intel Haswell to Cascade Lake) without exposing guest VMs to CPU generation mismatches.

```powershell
# Enable processor compatibility mode for live migration
Set-VMProcessor -VMName 'MyVM' -CompatibilityForMigrationEnabled $true

# Verify setting
Get-VMProcessor -VMName 'MyVM' | Select-Object CompatibilityForMigrationEnabled

# Check VM generation (Gen 2 required for vTPM)
Get-VM -Name 'MyVM' | Select-Object Name, Generation
```

### Pitfalls

- vTPM for Linux requires Generation 2 VMs only. Linux VMs created as Generation 1 cannot use vTPM.
- Processor compatibility mode reduces exposed CPU features to the lowest common denominator — AVX/AVX-512 workloads may lose instructions.
- Live migration with mixed CPU generations requires all hosts in the cluster to run 2022+ with updated firmware.

---

## 12. HTTPS for WinRM (Secure Remote Management)

### Overview

Windows Server 2022 defaults WinRM to require HTTPS for remote management sessions when configured via Server Manager or remote management tools. This is a posture change from 2019 where HTTP was the default.

```powershell
# Check current WinRM listeners
Get-WSManInstance -ResourceURI 'winrm/config/listener' -SelectorSet @{Transport='HTTPS'; Address='*'} `
    -ErrorAction SilentlyContinue

# List all WinRM listeners
Get-ChildItem -Path 'WSMan:\localhost\Listener'

# Create HTTPS WinRM listener with a certificate
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*$env:COMPUTERNAME*" } |
    Select-Object -First 1

New-WSManInstance -ResourceURI 'winrm/config/Listener' `
    -SelectorSet @{Address='*'; Transport='HTTPS'} `
    -ValueSet @{Hostname=$env:COMPUTERNAME; CertificateThumbprint=$cert.Thumbprint}

# Test HTTPS WinRM connectivity from remote machine
Test-WSMan -ComputerName 'Server2022' -UseSSL

# Connect via HTTPS WinRM
Enter-PSSession -ComputerName 'Server2022' -UseSSL -Credential (Get-Credential)
```

### Pitfalls

- HTTPS WinRM requires a valid server certificate with the server's FQDN in Subject or SAN.
- Self-signed certificates work but require `-SkipCACheck` and `-SkipCNCheck` on client connections — acceptable for internal use, not production.
- Firewall must allow TCP 5986 (HTTPS WinRM). The default HTTP port 5985 should be blocked.

---

## 13. PowerShell Diagnostic Scripts

### Script 11: Container Health (HostProcess, gMSA, Base Images)

```powershell
<#
.SYNOPSIS
    Windows Server 2022 Container Health - HostProcess, gMSA, and image diagnostics.

.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022 (build 20348+)
    Safety  : Read-only. No modifications to data or configuration.

    Sections:
      1. Container Feature and Runtime Status
      2. HostProcess Container Support Check
      3. gMSA Credential Spec Inventory
      4. Running Container Summary
      5. Container Image Inventory (2022 images)
      6. containerd Configuration Check
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host '=== Windows Server 2022 Container Health ===' -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ''

# Section 1: Container Feature and Runtime Status
Write-Host '--- Section 1: Container Feature & Runtime ---' -ForegroundColor Yellow

$containerFeature = Get-WindowsFeature -Name Containers
[PSCustomObject]@{
    Feature       = $containerFeature.Name
    DisplayName   = $containerFeature.DisplayName
    InstallState  = $containerFeature.InstallState
} | Format-List

# Check container runtime services
$runtimes = @('docker', 'containerd', 'com.docker.service')
foreach ($svc in $runtimes) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        [PSCustomObject]@{
            Runtime = $svc
            Status  = $s.Status
            StartType = $s.StartType
        }
    }
} | Format-Table -AutoSize

# Section 2: HostProcess Container Support Check
Write-Host '--- Section 2: HostProcess Container Support ---' -ForegroundColor Yellow

$build = [System.Environment]::OSVersion.Version.Build
$hostProcessSupported = $build -ge 20348
Write-Host "OS Build: $build"
Write-Host "HostProcess Containers Supported: $hostProcessSupported"

# Check containerd version for HostProcess support (requires 1.6+)
try {
    $ctrdVersion = & containerd --version 2>&1
    Write-Host "containerd: $ctrdVersion"
} catch {
    Write-Host 'containerd: Not found or not in PATH' -ForegroundColor Gray
}

Write-Host ''

# Section 3: gMSA Credential Spec Inventory
Write-Host '--- Section 3: gMSA Credential Specs ---' -ForegroundColor Yellow

$credSpecPaths = @(
    'C:\ProgramData\Docker\CredentialSpecs',
    'C:\ProgramData\containerd\cri-conf.d'
)

foreach ($path in $credSpecPaths) {
    if (Test-Path $path) {
        $specs = Get-ChildItem -Path $path -Filter '*.json' -ErrorAction SilentlyContinue
        if ($specs) {
            Write-Host "Credential specs in ${path}:"
            $specs | Select-Object Name, LastWriteTime, @{N='SizeKB';E={[Math]::Round($_.Length/1KB,1)}} |
                Format-Table -AutoSize
        } else {
            Write-Host "No credential specs found in $path"
        }
    }
}

# Check CCGPLUGIN for non-domain-joined gMSA
$ccgService = Get-Service -Name 'CCGService' -ErrorAction SilentlyContinue
Write-Host "CCGService (non-domain-join gMSA): $(if ($ccgService) { $ccgService.Status } else { 'Not installed' })"
Write-Host ''

# Section 4: Running Container Summary
Write-Host '--- Section 4: Running Containers ---' -ForegroundColor Yellow

try {
    $containers = & docker ps --format '{{json .}}' 2>&1 | ForEach-Object { $_ | ConvertFrom-Json }
    if ($containers) {
        $containers | Select-Object Names, Image, Status, Ports | Format-Table -AutoSize
    } else {
        Write-Host 'No running containers (docker)'
    }
} catch {
    Write-Host 'docker: Not available or not running' -ForegroundColor Gray
}

try {
    $ctrdContainers = & ctr containers list 2>&1
    Write-Host "containerd containers:`n$ctrdContainers"
} catch {
    Write-Host 'ctr: Not available' -ForegroundColor Gray
}
Write-Host ''

# Section 5: Container Image Inventory
Write-Host '--- Section 5: Container Images (2022-specific) ---' -ForegroundColor Yellow

try {
    $images = & docker images --format '{{json .}}' 2>&1 | ForEach-Object { $_ | ConvertFrom-Json }
    $images2022 = $images | Where-Object { $_.Tag -like '*ltsc2022*' -or $_.Tag -like '*2022*' }
    if ($images2022) {
        $images2022 | Select-Object Repository, Tag, Size, CreatedSince | Format-Table -AutoSize
    } else {
        Write-Host 'No ltsc2022 images found locally'
    }
} catch {
    Write-Host 'docker: Not available for image listing' -ForegroundColor Gray
}
Write-Host ''

# Section 6: containerd Configuration
Write-Host '--- Section 6: containerd Configuration ---' -ForegroundColor Yellow

$containerdConfig = 'C:\Program Files\containerd\config.toml'
if (Test-Path $containerdConfig) {
    Write-Host "containerd config found: $containerdConfig"
    # Show relevant settings without printing full config
    $configContent = Get-Content $containerdConfig -Raw
    $hostProcessLine = if ($configContent -match 'hostprocess|HostProcess') { 'Configured' } else { 'Not explicitly configured (may use defaults)' }
    Write-Host "HostProcess config: $hostProcessLine"
} else {
    Write-Host 'containerd config.toml not found at default path'
}

Write-Host ''
Write-Host '=== Container Health Check Complete ===' -ForegroundColor Cyan
```

---

### Script 12: Secured-Core Server Validation

```powershell
<#
.SYNOPSIS
    Windows Server 2022 Secured-Core validation — VBS, HVCI, Secure Boot, TPM, firmware protection.

.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022 (build 20348+)
    Safety  : Read-only. No modifications to data or configuration.

    Sections:
      1. Secure Boot Status
      2. TPM Status and Version
      3. Virtualization Based Security (VBS)
      4. Hypervisor-Protected Code Integrity (HVCI)
      5. System Guard / Secure Launch (DRTM)
      6. Credential Guard
      7. Overall Secured-Core Assessment
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host '=== Windows Server 2022 Secured-Core Validation ===' -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ''

$assessment = @{}

# Section 1: Secure Boot
Write-Host '--- Section 1: Secure Boot ---' -ForegroundColor Yellow
try {
    $secureBoot = Confirm-SecureBootUEFI
    $assessment['SecureBoot'] = $secureBoot
    Write-Host "Secure Boot Enabled: $secureBoot" -ForegroundColor $(if ($secureBoot) { 'Green' } else { 'Red' })
} catch {
    Write-Host 'Secure Boot: Cannot determine (not UEFI or access denied)' -ForegroundColor Yellow
    $assessment['SecureBoot'] = $false
}
Write-Host ''

# Section 2: TPM Status
Write-Host '--- Section 2: TPM Status ---' -ForegroundColor Yellow
$tpm = Get-Tpm
[PSCustomObject]@{
    TpmPresent   = $tpm.TpmPresent
    TpmEnabled   = $tpm.TpmEnabled
    TpmActivated = $tpm.TpmActivated
    TpmReady     = $tpm.TpmReady
} | Format-List

$tpmCim = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName 'Win32_Tpm' -ErrorAction SilentlyContinue
if ($tpmCim) {
    $specVersion = $tpmCim.SpecVersion
    $isTPM20 = $specVersion -like '2.*'
    Write-Host "TPM Spec Version: $specVersion" -ForegroundColor $(if ($isTPM20) { 'Green' } else { 'Red' })
    $assessment['TPM20'] = $isTPM20
} else {
    Write-Host 'TPM WMI class not accessible' -ForegroundColor Yellow
    $assessment['TPM20'] = $false
}
Write-Host ''

# Section 3: VBS Status
Write-Host '--- Section 3: Virtualization Based Security (VBS) ---' -ForegroundColor Yellow
$dg = Get-CimInstance -ClassName 'Win32_DeviceGuard' -Namespace 'root\Microsoft\Windows\DeviceGuard' -ErrorAction SilentlyContinue
if ($dg) {
    $vbsStatus = switch ($dg.VirtualizationBasedSecurityStatus) {
        0 { 'Not enabled' }
        1 { 'Enabled but not running' }
        2 { 'Running' }
        default { "Unknown ($($dg.VirtualizationBasedSecurityStatus))" }
    }
    $vbsRunning = $dg.VirtualizationBasedSecurityStatus -eq 2
    $assessment['VBSRunning'] = $vbsRunning

    Write-Host "VBS Status: $vbsStatus" -ForegroundColor $(if ($vbsRunning) { 'Green' } else { 'Red' })
    Write-Host "Services Running (bitmask): $($dg.SecurityServicesRunning)"
    Write-Host "Services Configured (bitmask): $($dg.SecurityServicesConfigured)"

    # Decode bitmask
    $running = $dg.SecurityServicesRunning
    Write-Host "  Credential Guard running: $(($running -band 1) -ne 0)"
    Write-Host "  HVCI running: $(($running -band 2) -ne 0)"
    Write-Host "  System Guard Secure Launch running: $(($running -band 4) -ne 0)"
} else {
    Write-Host 'DeviceGuard WMI class not accessible' -ForegroundColor Yellow
    $assessment['VBSRunning'] = $false
}
Write-Host ''

# Section 4: HVCI (Memory Integrity)
Write-Host '--- Section 4: HVCI (Hypervisor-Protected Code Integrity) ---' -ForegroundColor Yellow
$hvciKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
if (Test-Path $hvciKey) {
    $hvciProps = Get-ItemProperty -Path $hvciKey
    $hvciEnabled = $hvciProps.Enabled -eq 1
    $assessment['HVCIEnabled'] = $hvciEnabled
    Write-Host "HVCI Policy Enabled: $hvciEnabled" -ForegroundColor $(if ($hvciEnabled) { 'Green' } else { 'Red' })
    if ($hvciProps.PSObject.Properties['WasEnabledBy']) {
        Write-Host "Enabled By: $($hvciProps.WasEnabledBy)"
    }
} else {
    Write-Host 'HVCI registry key not found (may not be configured)' -ForegroundColor Yellow
    $assessment['HVCIEnabled'] = $false
}
Write-Host ''

# Section 5: System Guard / Secure Launch (DRTM)
Write-Host '--- Section 5: System Guard Secure Launch (DRTM) ---' -ForegroundColor Yellow
$sgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\SystemGuard'
if (Test-Path $sgKey) {
    $sgProps = Get-ItemProperty -Path $sgKey
    $sgEnabled = $sgProps.Enabled -eq 1
    $assessment['SecureLaunch'] = $sgEnabled
    Write-Host "System Guard Secure Launch: $sgEnabled" -ForegroundColor $(if ($sgEnabled) { 'Green' } else { 'Yellow' })
} else {
    Write-Host 'System Guard key not found (DRTM may not be supported on this hardware)' -ForegroundColor Yellow
    $assessment['SecureLaunch'] = $false
}

# Also check via DeviceGuard WMI bitmask (bit 4 = Secure Launch)
if ($dg -and ($dg.SecurityServicesRunning -band 4)) {
    Write-Host 'System Guard Secure Launch: RUNNING (via WMI)' -ForegroundColor Green
    $assessment['SecureLaunch'] = $true
}
Write-Host ''

# Section 6: Credential Guard
Write-Host '--- Section 6: Credential Guard ---' -ForegroundColor Yellow
$cgKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
if (Test-Path $cgKey) {
    $cgProps = Get-ItemProperty -Path $cgKey -ErrorAction SilentlyContinue
    $cgConfigured = $cgProps.EnableVirtualizationBasedSecurity -eq 1
    Write-Host "VBS Configured for Credential Guard: $cgConfigured"
}
if ($dg) {
    $cgRunning = ($dg.SecurityServicesRunning -band 1) -ne 0
    Write-Host "Credential Guard Running: $cgRunning" -ForegroundColor $(if ($cgRunning) { 'Green' } else { 'Yellow' })
}
Write-Host ''

# Section 7: Overall Assessment
Write-Host '--- Section 7: Secured-Core Assessment ---' -ForegroundColor Yellow
$checks = @{
    'Secure Boot'               = $assessment['SecureBoot']
    'TPM 2.0'                   = $assessment['TPM20']
    'VBS Running'               = $assessment['VBSRunning']
    'HVCI Enabled'              = $assessment['HVCIEnabled']
    'System Guard Secure Launch'= $assessment['SecureLaunch']
}

$passed = 0
foreach ($check in $checks.GetEnumerator()) {
    $status = if ($check.Value) { 'PASS'; $passed++ } else { 'FAIL' }
    $color = if ($check.Value) { 'Green' } else { 'Red' }
    Write-Host "[$status] $($check.Key)" -ForegroundColor $color
}

Write-Host ''
$securedCoreQualified = $passed -ge 4  # Secure Boot + TPM + VBS + HVCI minimum
$qualColor = if ($securedCoreQualified) { 'Green' } else { 'Red' }
Write-Host "Secured-Core Qualification: $(if ($securedCoreQualified) { 'QUALIFIED' } else { 'NOT QUALIFIED' }) ($passed/5 checks passed)" -ForegroundColor $qualColor
Write-Host ''
Write-Host '=== Secured-Core Validation Complete ===' -ForegroundColor Cyan
```

---

### Script 13: SMB Health (Compression, QUIC, Signing, Encryption)

```powershell
<#
.SYNOPSIS
    Windows Server 2022 SMB health — compression, signing, encryption, QUIC (Azure Ed).

.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022 (build 20348+)
    Safety  : Read-only. No modifications to data or configuration.

    Sections:
      1. SMB Server Configuration
      2. SMB Compression Status
      3. SMB Encryption Settings
      4. SMB Signing Status
      5. SMB over QUIC (Azure Edition check)
      6. Active SMB Sessions
      7. SMB Share Security Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host '=== Windows Server 2022 SMB Health ===' -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ''

# Section 1: SMB Server Configuration
Write-Host '--- Section 1: SMB Server Configuration ---' -ForegroundColor Yellow
$smbServer = Get-SmbServerConfiguration
[PSCustomObject]@{
    SMB1Enabled              = $smbServer.EnableSMB1Protocol
    SMB2Enabled              = $smbServer.EnableSMB2Protocol
    MaxDialect               = if ($smbServer.PSObject.Properties['ServerHidden']) { 'SMB 3.1.1 (2022 default)' } else { 'N/A' }
    OplocksEnabled           = $smbServer.EnableOplocks
    MultiChannelEnabled      = $smbServer.EnableMultiChannel
    AutoDisconnectTimeout    = $smbServer.AutoDisconnectTimeout
} | Format-List

Write-Host "SMB1 Enabled: $($smbServer.EnableSMB1Protocol)" -ForegroundColor $(if (-not $smbServer.EnableSMB1Protocol) { 'Green' } else { 'Red' })
Write-Host ''

# Section 2: SMB Compression
Write-Host '--- Section 2: SMB Compression (2022 Feature) ---' -ForegroundColor Yellow
$compressionEnabled = $smbServer.EnableSmbCompression
Write-Host "Server Compression Enabled: $compressionEnabled"

$clientConfig = Get-SmbClientConfiguration
Write-Host "Client Compression Enabled: $($clientConfig.EnableSmbCompression)"

if ($smbServer.PSObject.Properties['SmbCompressionAlgorithm']) {
    Write-Host "Compression Algorithm: $($smbServer.SmbCompressionAlgorithm)"
}

# Check compression on active sessions
$sessions = Get-SmbSession -ErrorAction SilentlyContinue
if ($sessions) {
    $sessionsWithComp = $sessions | Where-Object { $_.PSObject.Properties['CompressionEnabled'] }
    if ($sessionsWithComp) {
        Write-Host 'Active sessions with compression:'
        $sessionsWithComp | Select-Object ClientComputerName, ClientUserName, CompressionEnabled |
            Format-Table -AutoSize
    } else {
        Write-Host "Active sessions: $($sessions.Count) (compression property not exposed on this build)"
    }
} else {
    Write-Host 'No active SMB sessions'
}
Write-Host ''

# Section 3: SMB Encryption
Write-Host '--- Section 3: SMB Encryption ---' -ForegroundColor Yellow
$encryptData = $smbServer.EncryptData
Write-Host "Global Encryption Required: $encryptData" -ForegroundColor $(if ($encryptData) { 'Green' } else { 'Yellow' })

if ($smbServer.PSObject.Properties['EncryptionCiphers']) {
    Write-Host "Encryption Ciphers: $($smbServer.EncryptionCiphers)"
}

if ($smbServer.PSObject.Properties['RejectUnencryptedAccess']) {
    Write-Host "Reject Unencrypted Access: $($smbServer.RejectUnencryptedAccess)"
}

# Per-share encryption
$shares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'IPC$' }
if ($shares) {
    Write-Host ''
    Write-Host 'Per-share encryption status:'
    $shares | Select-Object Name, Path, EncryptData, FolderEnumerationMode |
        Format-Table -AutoSize
}
Write-Host ''

# Section 4: SMB Signing
Write-Host '--- Section 4: SMB Signing ---' -ForegroundColor Yellow
$signingRequired = $smbServer.RequireSecuritySignature
$signingEnabled = $smbServer.EnableSecuritySignature

Write-Host "Signing Required (server): $signingRequired" -ForegroundColor $(if ($signingRequired) { 'Green' } else { 'Yellow' })
Write-Host "Signing Enabled (server): $signingEnabled"
Write-Host "Client Signing Required: $($clientConfig.RequireSecuritySignature)"
Write-Host "Client Signing Enabled: $($clientConfig.EnableSecuritySignature)"
Write-Host ''

# Section 5: SMB over QUIC (Azure Edition)
Write-Host '--- Section 5: SMB over QUIC (Azure Edition) ---' -ForegroundColor Yellow
$edition = (Get-WmiObject -Class Win32_OperatingSystem).Caption
$isAzureEdition = $edition -like '*Azure*'
Write-Host "Edition: $edition"
Write-Host "Azure Edition: $isAzureEdition"

if ($isAzureEdition) {
    $quicCerts = Get-SmbServerCertificateMapping -ErrorAction SilentlyContinue
    if ($quicCerts) {
        Write-Host 'SMB over QUIC Certificate Mappings:'
        $quicCerts | Select-Object Name, Subject, Thumbprint | Format-Table -AutoSize
    } else {
        Write-Host 'No SMB over QUIC certificate mappings configured'
    }

    $quicConfig = Get-SmbServerConfiguration | Select-Object *quic* -ErrorAction SilentlyContinue
    if ($quicConfig) {
        $quicConfig | Format-List
    }
} else {
    Write-Host 'SMB over QUIC: Not available (requires Datacenter: Azure Edition)' -ForegroundColor Yellow
}
Write-Host ''

# Section 6: Active SMB Sessions
Write-Host '--- Section 6: Active SMB Sessions ---' -ForegroundColor Yellow
$sessions = Get-SmbSession -ErrorAction SilentlyContinue
if ($sessions) {
    Write-Host "Total active sessions: $($sessions.Count)"
    $sessions | Select-Object ClientComputerName, ClientUserName, NumOpens, Dialect, TransportName |
        Sort-Object ClientComputerName | Format-Table -AutoSize
} else {
    Write-Host 'No active SMB sessions'
}
Write-Host ''

# Section 7: SMB Share Security Summary
Write-Host '--- Section 7: SMB Share Security Summary ---' -ForegroundColor Yellow
$publicShares = $shares | Where-Object { $_.FolderEnumerationMode -eq 'Unrestricted' }
if ($publicShares) {
    Write-Host "Shares with unrestricted folder enumeration: $($publicShares.Count)" -ForegroundColor Yellow
    $publicShares | Select-Object Name, Path | Format-Table -AutoSize
} else {
    Write-Host 'No shares with unrestricted folder enumeration' -ForegroundColor Green
}

$unencryptedShares = $shares | Where-Object { -not $_.EncryptData -and -not $smbServer.EncryptData }
Write-Host "Shares without encryption (and global encryption off): $($unencryptedShares.Count)"

Write-Host ''
Write-Host '=== SMB Health Check Complete ===' -ForegroundColor Cyan
```

---

### Script 14: Hotpatch Status (Azure Edition)

```powershell
<#
.SYNOPSIS
    Windows Server 2022 Hotpatch enrollment, compliance, and update history (Azure Edition).

.NOTES
    Version : 2022.1.0
    Targets : Windows Server 2022 Datacenter: Azure Edition (build 20348+)
    Safety  : Read-only. No modifications to data or configuration.

    Sections:
      1. Edition and Hotpatch Eligibility Check
      2. Azure Arc Agent Status
      3. Windows Update Configuration
      4. Installed Hotpatch Updates
      5. Pending Updates
      6. Update History (last 30 days)
      7. Hotpatch Compliance Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host '=== Windows Server 2022 Hotpatch Status ===' -ForegroundColor Cyan
Write-Host "Server: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ''

# Section 1: Edition and Eligibility
Write-Host '--- Section 1: Edition and Hotpatch Eligibility ---' -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$edition = $os.Caption
$build = $os.BuildNumber
$version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
$ubr = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR

Write-Host "Edition: $edition"
Write-Host "Build: $build.$ubr"
Write-Host "Display Version: $version"

$isAzureEdition = $edition -like '*Azure*'
$isWS2022 = $build -ge 20348
$isEligible = $isAzureEdition -and $isWS2022

Write-Host "Azure Edition: $isAzureEdition" -ForegroundColor $(if ($isAzureEdition) { 'Green' } else { 'Yellow' })
Write-Host "Hotpatch Eligible: $isEligible" -ForegroundColor $(if ($isEligible) { 'Green' } else { 'Red' })

if (-not $isAzureEdition) {
    Write-Host ''
    Write-Host 'NOTE: Hotpatch requires Datacenter: Azure Edition. This edition does not support Hotpatch.' -ForegroundColor Yellow
    Write-Host 'Showing standard Windows Update status instead.' -ForegroundColor Yellow
}
Write-Host ''

# Section 2: Azure Arc Agent Status
Write-Host '--- Section 2: Azure Arc Agent Status ---' -ForegroundColor Yellow
$arcAgentPath = 'C:\Program Files\AzureConnectedMachineAgent\azcmagent.exe'
$arcInstalled = Test-Path $arcAgentPath

Write-Host "Arc Agent Installed: $arcInstalled" -ForegroundColor $(if ($arcInstalled) { 'Green' } else { 'Red' })

if ($arcInstalled) {
    try {
        $arcStatus = & $arcAgentPath show 2>&1 | Select-Object -First 20
        Write-Host 'Arc Agent Status:'
        $arcStatus | ForEach-Object { Write-Host "  $_" }
    } catch {
        Write-Host 'Could not query Arc agent status' -ForegroundColor Yellow
    }
}

# Check Arc services
$arcServices = @('himds', 'ExtensionService', 'GCArcService')
foreach ($svc in $arcServices) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        $color = if ($s.Status -eq 'Running') { 'Green' } else { 'Red' }
        Write-Host "Service [$($s.Name)]: $($s.Status)" -ForegroundColor $color
    } else {
        Write-Host "Service [$svc]: Not installed" -ForegroundColor Yellow
    }
}
Write-Host ''

# Section 3: Windows Update Configuration
Write-Host '--- Section 3: Windows Update Configuration ---' -ForegroundColor Yellow
$wuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
if (Test-Path $wuKey) {
    $wuPolicy = Get-ItemProperty -Path $wuKey -ErrorAction SilentlyContinue
    $auKey = "$wuKey\AU"
    $auPolicy = Get-ItemProperty -Path $auKey -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        WUServer              = $wuPolicy.WUServer
        TargetGroup           = $wuPolicy.TargetGroup
        AutoUpdateBehavior    = $auPolicy.AUOptions
        ScheduledInstallDay   = $auPolicy.ScheduledInstallDay
        ScheduledInstallTime  = $auPolicy.ScheduledInstallTime
    } | Format-List
} else {
    Write-Host 'No Windows Update group policy configured (using defaults)'
}

# Windows Update service status
$wuService = Get-Service -Name 'wuauserv' -ErrorAction SilentlyContinue
if ($wuService) {
    Write-Host "Windows Update Service: $($wuService.Status)"
}
Write-Host ''

# Section 4: Installed Hotpatch Updates
Write-Host '--- Section 4: Installed Hotpatch / Security Updates ---' -ForegroundColor Yellow
$installedUpdates = Get-HotFix | Sort-Object InstalledOn -Descending
$recentUpdates = $installedUpdates | Where-Object {
    $_.InstalledOn -ge (Get-Date).AddDays(-90)
}

if ($recentUpdates) {
    Write-Host "Updates installed in the last 90 days: $($recentUpdates.Count)"
    $recentUpdates | Select-Object HotFixID, Description, InstalledOn, InstalledBy |
        Format-Table -AutoSize
} else {
    Write-Host 'No updates found in the last 90 days via Get-HotFix'
}

# Look for hotpatch-specific updates via COM API
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $searcher = $updateSession.CreateUpdateSearcher()
    $histCount = $searcher.GetTotalHistoryCount()
    if ($histCount -gt 0) {
        $history = $searcher.QueryHistory(0, [Math]::Min($histCount, 100))
        $hotpatchHistory = $history | Where-Object {
            $_.Title -like '*Hotpatch*' -or $_.Categories | Where-Object { $_.Name -like '*Hotpatch*' }
        }
        if ($hotpatchHistory) {
            Write-Host ''
            Write-Host 'Hotpatch update history entries:'
            $hotpatchHistory | Select-Object Title, Date, ResultCode | Format-Table -AutoSize
        } else {
            Write-Host '(No hotpatch-labeled entries found in Windows Update history)'
        }
    }
} catch {
    Write-Host 'Windows Update COM API not accessible' -ForegroundColor Yellow
}
Write-Host ''

# Section 5: Pending Updates
Write-Host '--- Section 5: Pending Updates ---' -ForegroundColor Yellow
try {
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $searcher = $updateSession.CreateUpdateSearcher()
    Write-Host 'Searching for pending updates (this may take a moment)...'
    $pendingResults = $searcher.Search('IsInstalled=0 and Type=''Software'' and IsHidden=0')
    if ($pendingResults.Updates.Count -gt 0) {
        Write-Host "Pending updates: $($pendingResults.Updates.Count)" -ForegroundColor Yellow
        $pendingResults.Updates | ForEach-Object {
            [PSCustomObject]@{
                Title        = $_.Title
                IsDownloaded = $_.IsDownloaded
                IsMandatory  = $_.IsMandatory
                KBArticle    = ($_.KBArticleIDs -join ', ')
            }
        } | Format-Table -AutoSize
    } else {
        Write-Host 'No pending updates found' -ForegroundColor Green
    }
} catch {
    Write-Host 'Could not search for pending updates' -ForegroundColor Yellow
}
Write-Host ''

# Section 6: Update History (last 30 days)
Write-Host '--- Section 6: Update History (last 30 days) ---' -ForegroundColor Yellow
try {
    $cutoff = (Get-Date).AddDays(-30)
    $recentHistory = $history | Where-Object { $_.Date -ge $cutoff }
    if ($recentHistory) {
        $recentHistory | Select-Object Title, Date,
            @{N='Result';E={ switch($_.ResultCode){ 1{'InProgress'} 2{'Succeeded'} 3{'Succeeded w/Errors'} 4{'Failed'} 5{'Aborted'} default{$_} }}} |
            Format-Table -AutoSize -Wrap
    } else {
        Write-Host 'No update history in the last 30 days'
    }
} catch {
    Write-Host 'Update history not accessible' -ForegroundColor Yellow
}
Write-Host ''

# Section 7: Compliance Summary
Write-Host '--- Section 7: Hotpatch Compliance Summary ---' -ForegroundColor Yellow
$lastReboot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$daysSinceReboot = [Math]::Round(((Get-Date) - $lastReboot).TotalDays, 1)

Write-Host "Last Reboot: $($lastReboot.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Days Since Reboot: $daysSinceReboot" -ForegroundColor $(if ($daysSinceReboot -gt 90) { 'Yellow' } else { 'Green' })

$pendingReboot = $false
$rebootKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
)
foreach ($key in $rebootKeys) {
    if (Test-Path $key) { $pendingReboot = $true }
}
Write-Host "Reboot Pending: $pendingReboot" -ForegroundColor $(if ($pendingReboot) { 'Yellow' } else { 'Green' })

Write-Host ''
$arcRunning = (Get-Service -Name 'himds' -ErrorAction SilentlyContinue)?.Status -eq 'Running'
$compliance = @{
    'Azure Edition'   = $isAzureEdition
    'Arc Enrolled'    = $arcInstalled -and $arcRunning
    'No Pending Reboot (unexpected)' = -not $pendingReboot
    'Updated recently (<90 days)' = ($recentUpdates.Count -gt 0)
}
foreach ($item in $compliance.GetEnumerator()) {
    $status = if ($item.Value) { 'OK' } else { 'REVIEW' }
    $color = if ($item.Value) { 'Green' } else { 'Yellow' }
    Write-Host "[$status] $($item.Key)" -ForegroundColor $color
}

Write-Host ''
Write-Host '=== Hotpatch Status Check Complete ===' -ForegroundColor Cyan
```

---

## Version Boundaries

**This research covers Windows Server 2022 ONLY.** Feature cross-references:

- TLS 1.3 exists in 2019 but was NOT enabled by default — the default-on behavior is 2022-specific.
- SMB over QUIC (for Standard/Datacenter) was added in Windows Server 2025, not 2022.
- Hotpatch on Standard/Datacenter (non-Azure) is a Windows Server 2025 feature.
- Nested AMD virtualization was backported to some 2019 builds but is first-class in 2022.
- HostProcess containers require Windows Server 2022+ (not supported on 2019).
- DoH client support exists in Windows 10 21H1+ and Server 2022+ — server-side DoH resolver support is 2025+.
- Storage Bus Cache for standalone servers is new in 2022 (previously S2D clusters only).
- Secured-Core Server branding and enforcement (with certified hardware requirement) is formalized in 2022.
- vTPM for Linux guests under Hyper-V is new in 2022.

---

## Key Considerations for the Writer Agent

1. **Edition stratification is critical** — Many 2022 features are Azure Edition-only (Hotpatch, SMB/QUIC). The writer must clearly separate these from features available in all editions.

2. **TLS 1.0/1.1 disabled by default** is the single most operationally disruptive change for organizations upgrading from 2016/2019. It should be prominently flagged.

3. **Secured-Core requires certified hardware** — It cannot be fully enabled on arbitrary hardware. The writer should distinguish what can be enabled via software vs. what requires OEM certification.

4. **Script numbering starts at 11** — Scripts 01-10 are assumed to be cross-version scripts in references/. These 4 scripts (11-14) are version-specific additions.

5. **SMB compression default is OFF** — It must be explicitly enabled. Do not imply it is on by default.

6. **Hotpatch ≠ zero reboots** — Baseline months (quarterly) still require reboots. The writer should clarify this to avoid customer confusion.
