# Windows Server 2025 — Version-Specific Research

**Release:** November 2024  
**Support:** Mainstream until October 2029 | Extended until October 2034  
**Scope:** Features NEW or significantly changed in Windows Server 2025 only. Cross-version fundamentals live in references/.

---

## 1. Native NVMe Stack

### Description

Windows Server 2025 replaces the legacy SCSI emulation translation layer (Storport + SCSI miniport) with a direct NVMe I/O path. Previously, NVMe devices still communicated through a compatibility shim that translated NVMe commands through SCSI abstractions, adding latency and limiting queue depth exposure. The new native stack speaks NVMe directly.

**Performance impact:** Up to 60% more IOPS on identical hardware versus Windows Server 2022. Queue depth of 65,535 per namespace (up from 254 in the legacy stack). Latency reduction of 20-40% for small random I/O (4K-8K block sizes typical for databases and VMs).

### NVMe/TCP (Datacenter Edition Only)

NVMe/TCP extends the NVMe protocol over standard TCP/IP networks for remote block storage. This is distinct from iSCSI — NVMe/TCP preserves the NVMe command set end-to-end, avoiding SCSI translation even for network-attached storage.

- Requires 25 GbE or faster network (100 GbE recommended for production)
- Initiator (client) and target (storage) both run on Windows Server 2025 Datacenter or compatible NVMe/TCP storage arrays
- Replaces or supplements iSCSI for flash-based storage pools

### Configuration and Management

```powershell
# Verify NVMe devices are using native stack (not StorNVMe with SCSI emulation)
Get-PhysicalDisk | Where-Object BusType -eq 'NVMe' |
    Select-Object FriendlyName, BusType, HealthStatus, OperationalStatus,
                  @{N='QueueDepth'; E={ ($_ | Get-StorageReliabilityCounter).ReadLatencyMax }}

# Check NVMe namespace details
Get-Disk | Where-Object BusType -eq 'NVMe' |
    Select-Object Number, FriendlyName, Size, PartitionStyle, HealthStatus

# NVMe/TCP initiator (Datacenter) — connect to remote NVMe target
# Load the NVMe/TCP initiator module
Import-Module StorageSpaces

# Discover NVMe/TCP targets
Connect-NvmeTcpTarget -TargetPortalAddress '192.168.10.100' -TargetPortalPortNumber 4420

# List connected NVMe/TCP sessions
Get-NvmeTcpConnection

# Disconnect
Disconnect-NvmeTcpTarget -SessionId <id>
```

### Impact on Ecosystem

- **Backup agents:** Agents using VSS + Storport SCSI path still work, but agents that hook directly into storage stack drivers may need updates. Verify vendor support before upgrading.
- **Monitoring tools:** Disk performance counters (PhysicalDisk, NVMe-specific) remain valid. SMART data is accessible through updated WMI/CIM classes.
- **Storage drivers:** Third-party NVMe driver vendors must certify for the 2025 stack. Inbox storenvm.sys is the Microsoft-supplied driver.
- **Boot devices:** NVMe boot is fully supported. UEFI required (no legacy BIOS with NVMe boot in 2025).

### Pitfalls

- Older NVMe firmware with bugs in namespace management may expose issues previously hidden by the SCSI translation layer. Run firmware updates before deploying on 2025.
- Mixed NVMe + SATA arrays in Storage Spaces Direct: each bus type performs differently. Do not mix in the same storage tier.
- NVMe/TCP requires dedicated storage network VLANs; do not share with management traffic.

---

## 2. Hotpatch — Expanded to All Editions

### Description

Hotpatch allows security patches to be applied to running processes without a reboot by patching in-memory code. In Windows Server 2022, this required Azure Edition running on Azure virtual machines. Windows Server 2025 extends Hotpatch to Standard and Datacenter editions, both on-premises and in the cloud, via Azure Arc enrollment with a Hotpatch subscription.

### How Hotpatch Works

- **Baseline months (quarterly):** Full cumulative update, requires reboot. Typically January, April, July, October.
- **Hotpatch months (monthly, between baselines):** Security-only patches applied to running process memory. No reboot required for these months.
- **Net result:** Approximately 8 reboots/year instead of 12 with traditional patching.

### Enrollment Requirements

1. Server must run Windows Server 2025 (Standard or Datacenter)
2. Azure Arc agent installed and server enrolled in Azure Arc
3. Hotpatch subscription assigned (part of Azure Arc-enabled servers Extended Security Updates or standalone Hotpatch subscription)
4. Virtual Machine Guest State Protection (VMGS) or TPM 2.0 recommended for attestation

```powershell
# Install Azure Arc agent (download from aka.ms/AzureConnectedMachineAgent)
# Run the enrollment script generated from Azure Portal > Azure Arc > Add server

# Verify Arc enrollment status
azcmagent show

# Check Hotpatch enrollment and eligibility
Get-HotpatchStatus  # Requires Windows Server 2025 + Arc enrollment

# View available hotpatches
Get-WindowsUpdate -MicrosoftUpdate | Where-Object { $_.Title -like '*Hotpatch*' }

# Install hotpatch (no reboot)
Install-WindowsUpdate -KBArticleID 'KB5XXXXXXX' -AcceptAll

# Check if current patch is hotpatch or baseline
$os = Get-WmiObject Win32_OperatingSystem
$os.BuildNumber  # Track build vs baseline

# View hotpatch compliance state via Azure Arc
# In Azure Portal: Azure Arc > Servers > [server] > Updates > Hotpatch status
```

### PowerShell Arc Commands

```powershell
# Check Arc agent version (must be 1.41+ for hotpatch support)
azcmagent version

# Show hotpatch configuration
azcmagent config list

# Force hotpatch assessment
azcmagent check

# View extension status (MDE, monitoring, patch extensions)
azcmagent extension list
```

### Pitfalls

- Hotpatch is not available for Domain Controllers running certain roles that prevent in-memory patching (DNS server, DHCP). Verify role compatibility list in MS documentation.
- SQL Server running on a hotpatched host is not itself hotpatched — the OS patch applies to Windows processes. SQL Server requires its own patching cadence.
- If a baseline month patch fails (reboot required), subsequent hotpatches cannot apply until the baseline is successfully installed.
- Container hosts using process-isolated containers: the container shares the host kernel, so hotpatch applies to containers automatically. Hyper-V isolated containers are unaffected by host hotpatch.

---

## 3. SMB over QUIC — All Editions

### Description

SMB over QUIC allows clients to access SMB file shares over UDP port 443 using the QUIC transport (TLS 1.3-based), eliminating the need for VPN for secure remote file access. In Windows Server 2022 this was Azure Edition only. Windows Server 2025 brings it to Standard and Datacenter.

QUIC provides: built-in encryption, multiplexed streams, connection migration (client IP changes don't drop the connection), and reduced connection establishment latency vs TCP+TLS.

### Server-Side Configuration

```powershell
# Prerequisite: Valid TLS certificate bound to the server's public FQDN
# Certificate must be issued by a CA trusted by clients
# Self-signed works for testing but not production

# Install the SMB server certificate mapping
New-SmbServerCertificateMapping `
    -Name 'ExternalFileServer' `
    -Thumbprint 'A1B2C3D4...' `
    -StoreName 'My' `
    -Subject 'fileserver.contoso.com' `
    -DisplayName 'External SMB over QUIC'

# Enable SMB over QUIC on the server
Set-SmbServerConfiguration -EnableSMBQUIC $true

# Verify the mapping
Get-SmbServerCertificateMapping

# List active SMB over QUIC connections
Get-SmbConnection | Where-Object { $_.Dialect -ge '3.1.1' }

# View QUIC-specific statistics
Get-SmbServerNetworkInterface | Where-Object { $_.TransportType -eq 'QUIC' }

# Remove a certificate mapping
Remove-SmbServerCertificateMapping -Name 'ExternalFileServer'
```

### Firewall Configuration

```powershell
# Allow SMB over QUIC inbound (UDP 443) — server side
New-NetFirewallRule `
    -DisplayName 'SMB over QUIC Inbound' `
    -Direction Inbound `
    -Protocol UDP `
    -LocalPort 443 `
    -Action Allow `
    -Profile Domain,Private,Public

# Note: Do NOT open TCP 445 (traditional SMB) on internet-facing interfaces
# SMB over QUIC (UDP 443) replaces direct SMB exposure
```

### Client Requirements

- Windows 11 22H2 or later (client-side QUIC transport)
- Windows Server 2025 (server-to-server over QUIC)
- Windows 10 22H2 with KB update for QUIC support (limited)

```powershell
# Client: Connect to SMB over QUIC server
# Standard UNC path — transport negotiated automatically
net use Z: \\fileserver.contoso.com\share /user:domain\user

# Force QUIC transport explicitly
New-SmbMapping -LocalPath Z: -RemotePath \\fileserver.contoso.com\share -TransportType QUIC

# Verify transport type on client
Get-SmbConnection | Select-Object ServerName, ShareName, Dialect, Redirected
```

### Certificate Requirements

- Subject Alternative Name (SAN) must match the FQDN clients use to connect
- Certificate must be in the Local Machine > Personal store on the server
- CA trust chain must be valid on all clients (use internal CA for domain-joined, public CA for internet-facing)
- Certificate renewal: SMB over QUIC picks up renewed cert automatically if same thumbprint approach is replaced with subject-based mapping

### Use Cases

- Remote workers accessing file shares without VPN (replace DirectAccess/VPN + DFS)
- Branch office file access where UDP 443 is the only allowed outbound port
- Secure file share exposure in perimeter DMZ for partner access

### Pitfalls

- UDP 443 is also used by HTTPS/QUIC (HTTP/3). Ensure no port conflict with web servers on the same IP.
- Older clients (Win10 pre-22H2) fall back to TCP 445 if QUIC fails — ensure firewall allows the appropriate fallback path or explicitly block TCP 445.
- SMB over QUIC does not support NetBIOS name resolution. Requires DNS or explicit FQDN.
- Connection multiplexing means a single UDP flow carries many SMB streams — one firewall UDP timeout drops all streams. Tune UDP idle timeout on perimeter firewalls to 300+ seconds.

---

## 4. DTrace for Windows

### Description

DTrace (Dynamic Tracing) is a system tracing framework originating from Solaris/illumos, now ported to Windows Server 2025. It provides dynamic instrumentation of kernel and user-space without requiring pre-instrumented code, unlike ETW which requires providers to be registered. DTrace is particularly powerful for ad-hoc, one-liner diagnostics.

### Installation

```powershell
# Install DTrace (optional feature in Windows Server 2025)
Enable-WindowsOptionalFeature -FeatureName 'Microsoft-Windows-Subsystem-DTrace' -Online

# Or via DISM
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-DTrace

# Verify installation
dtrace -version

# Location of dtrace binary
Get-Command dtrace
# C:\Windows\System32\dtrace.exe
```

### Key Probe Types

| Probe Provider | Description |
|---|---|
| `syscall` | System calls (entry/return) |
| `fbt` | Function Boundary Tracing — kernel function entry/return |
| `pid` | User-space process instrumentation |
| `profile` | Timer-based sampling (wall clock or CPU) |
| `io` | Block I/O events |

### Common One-Liners

```dtrace
# Count system calls by name (10-second sample)
dtrace -n 'syscall:::entry { @[probefunc] = count(); }' -c "sleep 10"

# Trace all file opens with process name
dtrace -n 'syscall::NtCreateFile:entry { printf("%s opened %S\n", execname, (wchar_t *)arg2); }'

# CPU profiling — sample every 1ms, show who's on CPU
dtrace -n 'profile-1000hz /arg0/ { @[ufunc(arg0)] = count(); }'

# I/O latency histogram by disk
dtrace -n 'io:::start { ts[arg0] = timestamp; }
           io:::done  { @[args[1]->dev_statname] = quantize(timestamp - ts[arg0]); delete ts[arg0]; }'

# Trace process executions (what's spawning child processes)
dtrace -n 'proc:::exec-success { printf("%s -> %s\n", ppid, args[0]->pr_fname); }'

# Function call frequency in a specific process (pid 1234)
dtrace -n 'fbt::Nt*:entry /pid == 1234/ { @[probefunc] = count(); }'

# Syscall latency > 1ms
dtrace -n 'syscall:::entry { self->ts = timestamp; }
           syscall:::return /self->ts && (timestamp - self->ts) > 1000000/
           { printf("SLOW: %s %dms\n", probefunc, (timestamp - self->ts)/1000000); self->ts = 0; }'
```

### DTrace vs ETW/xperf

| Feature | DTrace | ETW/xperf/WPA |
|---|---|---|
| Instrumentation | Dynamic (no pre-registration) | Requires registered ETW providers |
| Kernel probing | Arbitrary kernel functions (fbt) | Only ETW provider events |
| Aggregation | Built-in (count, quantize, sum) | Post-processing in WPA |
| Learning curve | New syntax (D language) | Familiar but deep |
| Script complexity | One-liners to complex scripts | Complex XML manifests for custom providers |
| Production use | Caution: dynamic patching overhead | Lower overhead for long-running |
| Best for | Ad-hoc investigation, latency forensics | Long-running collection, UI analysis |

### Pitfalls

- DTrace requires `SeSystemProfilePrivilege` and `SeDebugPrivilege` — run as Administrator.
- `fbt` probes on very hot functions (e.g., memory allocation) can create significant overhead. Scope with `/condition/` predicates.
- DTrace is not available in Windows Server Core without enabling the optional feature; the feature itself does not require a GUI.
- D scripts use C-like syntax with important differences — whitespace in predicates matters, and Windows string printing uses `%S` for wide chars.
- Unlike Solaris DTrace, Windows DTrace does not support `ustack()` for user-mode stack traces without additional symbol configuration.

---

## 5. Delegated Managed Service Accounts (dMSA)

### Description

Delegated Managed Service Accounts (dMSA) are the successor to Group Managed Service Accounts (gMSA). Like gMSA, dMSA automatically manages password rotation and allows multiple servers to retrieve the password. The key improvements are: explicit delegation control (which security principals can use the account), streamlined migration from existing standard service accounts, and better integration with zero-trust service identity models.

**Domain Functional Level requirement:** Domain Functional Level 10 (Windows Server 2025) is required to create dMSA objects. All domain controllers in the domain must run Windows Server 2025.

### Key Differences from gMSA

| Feature | gMSA | dMSA |
|---|---|---|
| DFL requirement | Windows Server 2012 (DFL 6) | Windows Server 2025 (DFL 10) |
| Password retrieval | Principals in PrincipalsAllowedToRetrieveManagedPassword | Delegated via Entra ID / AD delegation model |
| Migration path | Manual creation and reconfiguration | Migration cmdlets from existing standard accounts |
| Audit | Standard | Enhanced with delegation audit trail |
| Cloud integration | Limited | Native Entra ID integration |

### Configuration

```powershell
# Prerequisite: Domain must be at DFL 10 (all DCs on WS2025)
# Check DFL
(Get-ADDomain).DomainMode  # Must be 'Windows2025Domain'

# Create a new dMSA
New-ADServiceAccount `
    -Name 'svc-webapp' `
    -DNSHostName 'svc-webapp.contoso.com' `
    -DelegatedManagedServiceAccount `
    -PrincipalsAllowedToRetrieveManagedPassword 'WebServers$' `
    -Path 'OU=ServiceAccounts,DC=contoso,DC=com'

# Grant the account permissions to run on specific computers
Add-ADComputerServiceAccount -Identity 'WEBSERVER01' -ServiceAccount 'svc-webapp'

# Install the dMSA on a member server (run on each server that will use it)
Install-ADServiceAccount -Identity 'svc-webapp'

# Test that the account can be retrieved
Test-ADServiceAccount -Identity 'svc-webapp'

# Migrate from an existing standard service account to dMSA
# Step 1: Create dMSA with migration link
New-ADServiceAccount `
    -Name 'svc-webapp-new' `
    -DelegatedManagedServiceAccount `
    -MigratedFromServiceAccount 'svc-webapp-old' `
    -DNSHostName 'svc-webapp.contoso.com'

# Step 2: After testing, complete migration (removes old account link)
Complete-ADServiceAccountMigration -Identity 'svc-webapp-new'

# View all dMSA objects
Get-ADServiceAccount -Filter { DelegatedManagedServiceAccount -eq $true } |
    Select-Object Name, DNSHostName, Enabled, PrincipalsAllowedToRetrieveManagedPassword
```

### Pitfalls

- DFL 10 is a one-way upgrade. Ensure all DCs are on Windows Server 2025 before raising the DFL, as you cannot roll back.
- dMSA password retrieval still follows the LAPS-like 30-day rotation cycle by default. Applications that cache service account credentials aggressively may fail mid-rotation.
- Migration cmdlet (`MigratedFromServiceAccount`) creates a dependency link — if you delete the old account before `Complete-ADServiceAccountMigration`, the migration fails.
- Unlike gMSA, dMSA has tighter Entra ID sync requirements. If using Azure AD Connect / Entra Connect Sync, ensure the sync scope includes Service Accounts OU.

---

## 6. Active Directory Improvements

### 6.1 32 KB Database Page Size

The AD DS database (NTDS.DIT) historically used 8 KB database pages (inherited from Jet/ESE). Windows Server 2025 upgrades to 32 KB pages when all domain controllers in the domain run Windows Server 2025.

**Impact:**
- Larger attribute values fit within a single page (avoids overflow chains)
- Dramatically improved scalability for large AD databases (100M+ objects)
- Replication efficiency improves — fewer page reads for large multi-valued attributes
- The upgrade happens automatically when the last pre-2025 DC is removed and DFL is raised

```powershell
# Check current AD database page size
# (Requires DSA diagnostics - no direct PowerShell cmdlet as of release)
# Check ESE database version via eseutil
eseutil /mh C:\Windows\NTDS\ntds.dit | Select-String 'Page Size'

# Monitor AD database size and performance
Get-Counter '\NTDS\DRA Pending Replication Synchronizations'
Get-Counter '\NTDS\DS Threads in Use'
Get-Counter '\Database\Database Cache Size'
```

### 6.2 Forest and Domain Functional Level 10

Raising to DFL/FFL 10 enables all Windows Server 2025 AD features:

```powershell
# Check current functional levels
(Get-ADForest).ForestMode    # Must show Windows2025Forest for FFL 10
(Get-ADDomain).DomainMode    # Must show Windows2025Domain for DFL 10

# Raise Domain Functional Level to 10
Set-ADDomainMode -Identity contoso.com -DomainMode Windows2025Domain

# Raise Forest Functional Level to 10 (after all domains are at DFL 10)
Set-ADForestMode -Identity contoso.com -ForestMode Windows2025Forest

# Verify KDC is capable of FFL 10 features
Get-ADDomainController -Filter * | Select-Object Name, OperatingSystem, IsGlobalCatalog
```

### 6.3 LDAP Channel Binding and Signing Enforcement

Windows Server 2025 enforces LDAP channel binding and LDAP signing by default. Applications connecting with plain LDAP (unsigned, no channel binding) will fail.

```powershell
# Check LDAP signing policy (registry)
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' `
    -Name 'LDAPServerIntegrity'
# 0 = None, 1 = Negotiate signing, 2 = Require signing (default in 2025)

# Check LDAP channel binding policy
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' `
    -Name 'LdapEnforceChannelBinding'
# 0 = Never, 1 = When Supported, 2 = Always (default in 2025)

# Audit LDAP binding events before enforcement
# Event ID 2889: Unsigned LDAP bind attempt
# Event ID 3039: LDAP channel binding validation failure
Get-WinEvent -LogName 'Directory Service' |
    Where-Object { $_.Id -in @(2889, 3039) } |
    Select-Object TimeCreated, Id, Message -First 50
```

### 6.4 Kerberos FAST (Flexible Authentication Secure Tunneling)

FAST armors Kerberos AS-REQ messages in a secure tunnel, preventing pre-authentication brute force and AS-REQ harvesting attacks.

```powershell
# Enable FAST via Group Policy
# Computer Configuration > Windows Settings > Security Settings >
# Account Policies > Kerberos Policy > Require Kerberos armoring: Enabled

# Check if FAST is negotiated (look for FAST-related OIDs in KDC logs)
Get-WinEvent -LogName Security |
    Where-Object { $_.Id -eq 4768 } |  # Kerberos authentication ticket requested
    Select-Object -First 20

# Test FAST armor availability
klist  # Shows current Kerberos tickets; armor ticket shows in ticket flags
```

### 6.5 Faster AD Replication

Compressed replication for low-bandwidth links is improved. New delta compression algorithm reduces bandwidth for large multi-valued attribute replication by up to 40%.

```powershell
# Monitor replication health
repadmin /showrepl
repadmin /replsummary

# Check replication latency
repadmin /showutdvec DCNAME dc=contoso,dc=com

# Force replication
repadmin /syncall /AdeP

# Replication traffic stats
Get-Counter '\NTDS\DRA Inbound Bytes Total\sec'
Get-Counter '\NTDS\DRA Outbound Bytes Total\sec'
```

---

## 7. GPU Partitioning (GPU-P) for Hyper-V

### Description

GPU Partitioning (GPU-P) allows a single physical GPU to be shared across multiple Hyper-V virtual machines simultaneously. Each VM gets a dedicated partition of GPU compute, memory, and encode/decode engines. This is distinct from RemoteFX (deprecated) and DDA (which dedicates an entire GPU to one VM).

**Target workload:** AI/ML inference, GPU-accelerated rendering, graphics-intensive apps where per-VM dedicated GPU is cost-prohibitive.

### Supported Scenarios

- Live Migration with GPU-P VMs (unique to 2025 — not supported in 2022)
- Failover Clustering with GPU-P VMs
- Automatic partition rebalancing on host GPU driver updates

### Configuration

```powershell
# Verify the GPU supports partitioning
Get-VMHostPartitionableGpu

# Output includes: Name, ValidPartitionCounts, TotalVRAM, etc.

# Set the number of partitions on the host GPU
Set-VMHostPartitionableGpu -Name 'GPU0' -PartitionCount 4

# Assign a GPU partition to a VM
Add-VMGpuPartitionAdapter -VMName 'AIInferenceVM'

# Configure specific partition resource limits
Set-VMGpuPartitionAdapter -VMName 'AIInferenceVM' `
    -MinPartitionVRAM 0 `
    -MaxPartitionVRAM 1000000000 `
    -OptimalPartitionVRAM 500000000 `
    -MinPartitionCompute 0 `
    -MaxPartitionCompute 1000 `
    -OptimalPartitionCompute 500

# List GPU adapters assigned to a VM
Get-VMGpuPartitionAdapter -VMName 'AIInferenceVM'

# Remove GPU partition from a VM
Remove-VMGpuPartitionAdapter -VMName 'AIInferenceVM'

# Copy GPU drivers into VM (required for guest driver installation)
# The host GPU drivers must be copied to the guest so the guest can use the partition
$vm = 'AIInferenceVM'
Copy-VMFile -VMName $vm -SourcePath 'C:\GPU_Drivers' -DestinationPath 'C:\Temp\GPU_Drivers' -FileSource Host
```

### Supported GPU Requirements

- GPU must support SR-IOV (Single Root I/O Virtualization) for true hardware partitioning
- Microsoft approved vendor list includes: NVIDIA A-series (A2, A10, A16, A30, A100), AMD Instinct MI-series
- Consumer/gaming GPUs (RTX, Radeon RX) are generally NOT supported for GPU-P
- Host must have IOMMU enabled in BIOS/UEFI

### Live Migration with GPU-P

```powershell
# Migrate a GPU-P VM (requires identical GPU on destination host)
Move-VM -Name 'AIInferenceVM' `
    -DestinationHost 'HV02' `
    -DestinationStoragePath 'C:\VMs'

# Both hosts must have same GPU model and compatible driver versions
# Check GPU compatibility before migration
Get-VMHostPartitionableGpu -ComputerName 'HV02'
```

### Pitfalls

- GPU driver versions must be identical (or compatible) on source and destination hosts for live migration.
- GPU-P does not provide hard isolation between VMs for security-sensitive workloads. For complete isolation, use DDA (one GPU per VM).
- VRAM over-subscription is allowed but degrades performance when total requested VRAM exceeds physical VRAM.
- Hyper-V checkpoint (saved state) is not supported for VMs with GPU-P adapters.

---

## 8. Security Defaults in Windows Server 2025

### 8.1 Credential Guard — Enabled by Default

Credential Guard uses Virtualization-Based Security (VBS) to isolate NTLM hashes and Kerberos Ticket Granting Tickets in a separate, hypervisor-protected memory region (VSM), preventing credential extraction by pass-the-hash/pass-the-ticket attacks.

**Windows Server 2025:** Enabled by default on qualifying hardware (UEFI, Secure Boot, IOMMU, TPM 2.0).

```powershell
# Check Credential Guard status
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object SecurityServicesRunning, SecurityServicesConfigured,
                  VirtualizationBasedSecurityStatus

# SecurityServicesRunning: 1 = Credential Guard, 2 = HVCI
# Status: 2 = Running

# Disable Credential Guard if incompatible (e.g., certain virtualization or NLA scenarios)
# Via registry (requires reboot):
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
    -Name 'LsaCfgFlags' -Value 0  # 0=disabled, 1=enabled with UEFI lock, 2=enabled without UEFI lock
```

### 8.2 NTLM v1 Blocked by Default

NTLM v1 is completely blocked in Windows Server 2025. NTLM v2 remains but with enhanced audit controls and a documented deprecation path toward Kerberos-only.

```powershell
# Verify NTLM v1 block status
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' `
    -Name 'LmCompatibilityLevel'
# 5 = Send NTLMv2 only, reject LM & NTLM (default in 2025)

# Audit NTLM v2 usage to identify applications before full NTLM block
# Enable NTLM audit
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' `
    -Name 'AuditNTLMInDomain' -Value 7  # 7 = all NTLM

# View NTLM audit events
Get-WinEvent -LogName 'Microsoft-Windows-NTLM/Operational' |
    Select-Object TimeCreated, Id, Message -First 50
# Event 8004: NTLM auth denied
# Event 8001: NTLM auth accepted

# Restrict NTLM to specific servers (whitelist approach during migration)
$ntlmAllowed = @('LEGACYSERVER01', 'LEGACYSERVER02')
$ntlmAllowed | ForEach-Object {
    # Add to NTLM exception list via Group Policy or registry
    # HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths
}
```

### 8.3 SMB Signing Required by Default

SMB signing prevents man-in-the-middle attacks by signing every SMB packet. Windows Server 2025 requires signing for all SMB connections by default (both client and server).

```powershell
# Check SMB signing configuration on server
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature, EnableSecuritySignature

# Check SMB signing on the client side
Get-SmbClientConfiguration | Select-Object RequireSecuritySignature, EnableSecuritySignature

# If legacy clients cannot sign, temporarily allow unsigned (NOT recommended for production)
Set-SmbServerConfiguration -RequireSecuritySignature $false -Force

# Audit unsigned SMB connections before enforcement
Get-WinEvent -LogName 'Microsoft-Windows-SMBServer/Operational' |
    Where-Object { $_.Id -eq 551 } |  # Unsigned client attempt
    Select-Object TimeCreated, Message -First 20
```

### 8.4 Post-Quantum Cryptography (PQC) in TLS

Windows Server 2025 adds support for ML-KEM (Module Lattice Key Encapsulation Mechanism) — NIST FIPS 203 — as a key exchange algorithm in TLS 1.3. This provides quantum-resistant key exchange while maintaining classical algorithm support.

```powershell
# Verify PQC cipher suite availability
Get-TlsCipherSuite | Where-Object { $_.Name -like '*MLKEM*' -or $_.Name -like '*Kyber*' }

# Check TLS configuration
Get-TlsCipherSuite | Select-Object Name, Certificate, Hash, Exchange, Cipher |
    Where-Object { $_.Exchange -like '*KEM*' }

# The PQC algorithms are negotiated automatically when both client and server support them
# No configuration required to enable — they are in the priority list by default
```

---

## 9. Bluetooth and Wi-Fi Support

### Description

Windows Server 2025 is the first Windows Server release to officially support Bluetooth and Wi-Fi networking. This is targeted at edge computing, IoT gateways, and scenarios where wired network infrastructure is unavailable or impractical.

### Use Cases

- Industrial IoT gateways running Windows Server 2025 on edge hardware
- Retail environments with Wi-Fi-connected POS terminals managed by a server
- Temporary deployment scenarios (disaster recovery sites, pop-up facilities)
- Bluetooth for peripheral management in server room / edge appliance scenarios

### Limitations

- No wireless support for Failover Clustering heartbeat networks (still requires wired)
- Wi-Fi cannot be used as primary management interface for Azure Arc enrollment (wired required for enrollment, Wi-Fi usable after)
- Bluetooth is not supported for any server roles (AD, DNS, DHCP, etc.) as a primary network interface
- Driver support is hardware-specific — not all Wi-Fi adapters are supported; check Windows Catalog

```powershell
# Check Wi-Fi adapter availability
Get-NetAdapter | Where-Object { $_.PhysicalMediaType -like '*802.11*' }

# Connect to Wi-Fi network on Server 2025
netsh wlan connect name='CorpWifi' ssid='Corp-SSID' interface='Wi-Fi'

# Or via PowerShell
Add-VpnConnection  # (Wi-Fi profiles use netsh wlan / Set-WiFiProfile module)

# View available wireless networks
netsh wlan show networks mode=bssid

# Manage Bluetooth
# Install Bluetooth feature if not present
Add-WindowsCapability -Online -Name 'Bluetooth.Generic~~~~0.0.1.0'

# Check Bluetooth device status
Get-PnpDevice | Where-Object { $_.Class -eq 'Bluetooth' }
```

---

## 10. Hardware Scale Improvements

### 10.1 4 PB RAM with 5-Level Paging

Intel's 5-level paging (LA57) extends the linear address space from 128 TB (4-level) to 128 PB. Windows Server 2025 leverages this on supporting Intel processors (Ice Lake Xeon and later, Sapphire Rapids, Emerald Rapids) to support up to 4 PB physical RAM per host.

- Requires Intel Xeon Ice Lake (3rd Gen) or later, or AMD EPYC Genoa+
- BIOS/UEFI must support 5-level paging (check vendor documentation)
- Hyper-V VMs can be assigned up to 240 TB RAM (per-VM maximum)

```powershell
# Check physical memory installed
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1TB
# Returns installed RAM in TB

# Check if 5-level paging is active
# (No direct PowerShell — check via CPUID or system information)
(Get-CimInstance Win32_Processor).Addressablewidth  # Should show 57 for 5-level paging systems

# View memory configuration
Get-CimInstance Win32_PhysicalMemory |
    Select-Object BankLabel, Capacity, Speed, Manufacturer |
    Sort-Object BankLabel
```

### 10.2 2,048 Logical Processor Support

Windows Server 2025 supports up to 2,048 logical processors (up from 512 in Windows Server 2022 for the host, and up to 320 for Hyper-V guests). This matches the largest available AMD EPYC and Intel Xeon multi-socket configurations.

- Per-VM: up to 2,048 vCPUs (practical limit depends on guest OS)
- NUMA topology is preserved in the scheduler for NUMA-optimized workloads

```powershell
# View logical processor count
(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors

# View NUMA topology
Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Processor |
    Select-Object DeviceID, Name, NumberOfCores, NumberOfLogicalProcessors

# Hyper-V: Configure VM vCPU count (up to 2048)
Set-VMProcessor -VMName 'LargeVM' -Count 128

# Check NUMA node affinity for a VM
Get-VMNumaNode -VMName 'LargeVM'
```

---

## 11. Container Improvements

### Description

Windows Server 2025 ships containerd as the default and recommended container runtime, replacing Docker (moby) as the primary supported runtime. The Docker CLI is still available but the runtime layer is containerd.

### containerd Integration

```powershell
# Install containerd (recommended for Windows Server 2025)
# Via WinGet (new in Server 2025 — see section 12)
winget install --id Microsoft.ContainerD -e --source winget

# Start and configure containerd service
Start-Service containerd
Set-Service -Name containerd -StartupType Automatic

# Verify containerd is running
containerd --version
ctr version

# Pull a Windows container image using containerd
ctr image pull mcr.microsoft.com/windows/servercore:ltsc2025

# List images
ctr images ls

# Run a container with containerd
ctr run --rm mcr.microsoft.com/windows/servercore:ltsc2025 test cmd /c dir

# Use crictl for Kubernetes-compatible operations
crictl version
crictl images
crictl ps
```

### Updated Container Base Images

Windows Server 2025 introduces new base image tags:

- `mcr.microsoft.com/windows/servercore:ltsc2025` — Full Server Core with .NET and WinSxS
- `mcr.microsoft.com/windows/nanoserver:ltsc2025` — Minimal footprint for microservices
- `mcr.microsoft.com/windows/server:ltsc2025` — Full desktop experience layer

```powershell
# Pull updated 2025 base images
$images = @(
    'mcr.microsoft.com/windows/servercore:ltsc2025',
    'mcr.microsoft.com/windows/nanoserver:ltsc2025',
    'mcr.microsoft.com/windows/server:ltsc2025'
)
$images | ForEach-Object { ctr image pull $_ }

# Verify image compatibility with host OS version
$hostBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Output "Host build: $hostBuild"
# ltsc2025 images require host build 26100+
```

### Kubernetes Windows Node Improvements

- Improved HostProcess container support (runs with host networking and local admin)
- IPv6 dual-stack support for Windows pods
- Graceful node shutdown support

```powershell
# Configure containerd for Kubernetes (kubeadm join scenario)
# config.toml at C:\Program Files\containerd\config.toml

# Verify Kubernetes node components
kubectl get nodes -o wide  # Shows OS image = Windows Server 2025

# Check Windows node status
kubectl get pods -n kube-system | Where-Object { $_ -match 'windows' }
```

### Pitfalls

- Process-isolated containers on Windows Server 2025 host can only run container images with matching or older OS version. ltsc2022 containers run on ltsc2025 hosts but not vice versa.
- Hyper-V isolated containers avoid OS version mismatch but require Hyper-V role enabled, which conflicts with nested virtualization in some scenarios.
- Docker Desktop for Windows is NOT the same as containerd — if you use Docker Desktop in development, switch to containerd in production to avoid behavior differences.

---

## 12. Other Notable Changes

### 12.1 Winget (Windows Package Manager) in Server Core

Winget is now available in Windows Server 2025, including Server Core installation. This enables package management without a GUI and consistent tooling with client Windows environments.

```powershell
# Verify winget is available
winget --version

# Search for packages
winget search 'Notepad++'
winget search 'Microsoft.PowerShell'

# Install packages
winget install --id Microsoft.PowerShell -e --source winget
winget install --id Git.Git -e --source winget

# Update all installed packages
winget upgrade --all

# Export installed packages (for reproducible environments)
winget export -o C:\Temp\installed-packages.json

# Import packages on a new server
winget import -i C:\Temp\installed-packages.json
```

### 12.2 OpenSSH Included by Default

OpenSSH Server and Client are now installed by default (no longer optional features) in Windows Server 2025.

```powershell
# Verify OpenSSH status (should be present by default)
Get-Service -Name sshd
Get-WindowsCapability -Online | Where-Object { $_.Name -like 'OpenSSH*' }

# Start and enable SSH server
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Configure default SSH shell to PowerShell
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' `
    -Name DefaultShell `
    -Value 'C:\Program Files\PowerShell\7\pwsh.exe' `
    -PropertyType String -Force

# Verify SSH connectivity
ssh -o StrictHostKeyChecking=no user@localhost 'Get-Date'
```

### 12.3 64-bit Only

Windows Server 2025 drops 32-bit (x86) kernel and user-mode application support in the server product. 64-bit application mode is the only option. This affects:

- Legacy 32-bit line-of-business applications — must be updated or run in VMs
- 32-bit COM components embedded in server roles — audit with SysWow64 presence
- Installers that drop 32-bit DLLs into System32

```powershell
# Audit 32-bit processes (should be empty in a pure 64-bit environment)
Get-Process | Where-Object { $_.Handle -ne 0 } |
    ForEach-Object {
        try { [IntPtr]$ptr = [IntPtr]::Zero
              [bool]$is32 = $false
              [Win32.Kernel32]::IsWow64Process($_.Handle, [ref]$is32) | Out-Null
              if ($is32) { $_ | Select-Object Id, Name, Path }
        } catch {}
    }
```

### 12.4 Block Cloning on NTFS

Block cloning allows the file system to perform copy-on-write (CoW) operations at the block level, enabling near-instant file copies without physically duplicating data on disk until a write occurs. Primarily beneficial for VHD/VHDX operations, backup workloads, and deduplication-heavy environments.

```powershell
# Block cloning is automatic for supported operations (VHD creation, VHDX differencing disks)
# No explicit configuration required

# Monitor block cloning activity via Storage QoS / Storage performance counters
Get-Counter '\NTFS\Block Clone Failures'
Get-Counter '\NTFS\Block Clone Requests'

# Verify NTFS volume version supports block cloning
fsutil fsinfo ntfsinfo C:
# Look for 'NTFS Volume Serial Number' and version info
```

---

## 13. PowerShell Diagnostic Scripts

### Script 11: Container Health (containerd Integration)

```powershell
<#
.SYNOPSIS
    Windows Server 2025 container health check for containerd integration.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+
    Safety   : Read-only. No modifications to container state or configuration.
    Sections :
        1. containerd Service Status
        2. Container Runtime Version
        3. Running Containers
        4. Container Images
        5. Container Image OS Version Compatibility
        6. Kubernetes Node Status (if applicable)
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "`n=== Windows Server 2025 Container Health ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: containerd Service Status
Write-Host "--- Section 1: containerd Service Status ---" -ForegroundColor Yellow
$svc = Get-Service -Name containerd -ErrorAction SilentlyContinue
if ($svc) {
    [PSCustomObject]@{
        Service        = $svc.Name
        Status         = $svc.Status
        StartType      = $svc.StartType
        Assessment     = if ($svc.Status -eq 'Running') { 'OK' } else { 'WARNING: containerd not running' }
    } | Format-List
} else {
    Write-Warning 'containerd service not found. Install containerd for Windows Server 2025 container support.'
}

# Also check Docker (legacy) if present
$docker = Get-Service -Name docker -ErrorAction SilentlyContinue
if ($docker) {
    Write-Warning "Legacy Docker service detected. Windows Server 2025 recommends containerd as primary runtime."
    [PSCustomObject]@{
        DockerService = $docker.Name
        DockerStatus  = $docker.Status
        Note          = 'Migrate workloads to containerd runtime'
    } | Format-List
}
#endregion

#region Section 2: Container Runtime Version
Write-Host "--- Section 2: Container Runtime Version ---" -ForegroundColor Yellow
try {
    $ctrdVersion = & containerd --version 2>&1
    $hostOS = Get-CimInstance Win32_OperatingSystem
    [PSCustomObject]@{
        ContainerdVersion = $ctrdVersion
        HostOSCaption     = $hostOS.Caption
        HostBuildNumber   = $hostOS.BuildNumber
        HostVersion       = $hostOS.Version
        MinBuildFor2025   = '26100'
        BuildCompatible   = if ([int]$hostOS.BuildNumber -ge 26100) { 'Yes' } else { 'No - Update required' }
    } | Format-List
} catch {
    Write-Warning "containerd binary not accessible: $_"
}
#endregion

#region Section 3: Running Containers
Write-Host "--- Section 3: Running Containers ---" -ForegroundColor Yellow
try {
    $runningContainers = & ctr containers list 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Running containers:`n$runningContainers"
    } else {
        Write-Warning "Could not list containers (ensure containerd is running)"
    }
} catch {
    Write-Warning "ctr not accessible: $_"
}
#endregion

#region Section 4: Container Images
Write-Host "--- Section 4: Container Images ---" -ForegroundColor Yellow
try {
    $images = & ctr images list 2>&1
    Write-Host "Available images:`n$images"
} catch {
    Write-Warning "Cannot list container images: $_"
}
#endregion

#region Section 5: Container Image OS Compatibility
Write-Host "--- Section 5: Container Image OS Compatibility ---" -ForegroundColor Yellow
$hostBuild = (Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Host "Host OS Build: $hostBuild"
Write-Host "Process-isolated containers require matching container image OS version."
Write-Host "ltsc2025 images (build 26100+): Compatible with WS2025 host"
Write-Host "ltsc2022 images (build 20348):  Compatible (older images run on newer hosts)"
Write-Host "ltsc2019 images (build 17763):  Compatible (older images run on newer hosts)"
Write-Host "Hyper-V isolation bypasses OS version requirements for all above."
#endregion

#region Section 6: Kubernetes Node Check
Write-Host "--- Section 6: Kubernetes Node Status (if applicable) ---" -ForegroundColor Yellow
$kubelet = Get-Service -Name kubelet -ErrorAction SilentlyContinue
if ($kubelet) {
    [PSCustomObject]@{
        KubeletStatus    = $kubelet.Status
        KubeletStartType = $kubelet.StartType
        Assessment       = if ($kubelet.Status -eq 'Running') { 'OK' } else { 'WARNING' }
    } | Format-List
    try {
        $kubectl = & kubectl version --client 2>&1
        Write-Host "kubectl: $kubectl"
    } catch {
        Write-Host "kubectl not available or not in PATH"
    }
} else {
    Write-Host "Kubelet service not present - standalone container host (not Kubernetes node)"
}
#endregion
```

### Script 12: Secured-Core and Credential Guard Validation

```powershell
<#
.SYNOPSIS
    Windows Server 2025 Secured-Core and Credential Guard default validation.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+
    Safety   : Read-only. No modifications to security configuration.
    Sections :
        1. Virtualization-Based Security (VBS) Status
        2. Credential Guard Status (default ON in 2025)
        3. HVCI (Hypervisor-Protected Code Integrity)
        4. Secure Boot Status
        5. TPM Status
        6. Secured-Core Feature Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 Secured-Core & Credential Guard ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: Virtualization-Based Security
Write-Host "--- Section 1: Virtualization-Based Security (VBS) ---" -ForegroundColor Yellow
$devGuard = Get-CimInstance -ClassName Win32_DeviceGuard `
    -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
if ($devGuard) {
    $vbsStatus = switch ($devGuard.VirtualizationBasedSecurityStatus) {
        0 { 'Not Enabled' }
        1 { 'Enabled but Not Running' }
        2 { 'Running' }
        default { "Unknown ($($devGuard.VirtualizationBasedSecurityStatus))" }
    }
    [PSCustomObject]@{
        VBSStatus                    = $vbsStatus
        SecurityServicesConfigured   = $devGuard.SecurityServicesConfigured -join ', '
        SecurityServicesRunning      = $devGuard.SecurityServicesRunning -join ', '
        AvailableSecurityProperties  = $devGuard.AvailableSecurityProperties -join ', '
        RequiredSecurityProperties   = $devGuard.RequiredSecurityProperties -join ', '
    } | Format-List
} else {
    Write-Warning "Win32_DeviceGuard WMI class not accessible."
}
#endregion

#region Section 2: Credential Guard
Write-Host "--- Section 2: Credential Guard (Default ON in WS2025) ---" -ForegroundColor Yellow
$cgRunning = $devGuard.SecurityServicesRunning -contains 1
$cgConfigured = $devGuard.SecurityServicesConfigured -contains 1
$cgLsaFlag = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name LsaCfgFlags -ErrorAction SilentlyContinue).LsaCfgFlags

[PSCustomObject]@{
    CredentialGuardConfigured = $cgConfigured
    CredentialGuardRunning    = $cgRunning
    LsaCfgFlags               = $cgLsaFlag
    LsaFlagMeaning            = switch ($cgLsaFlag) {
        0 { 'Disabled' }
        1 { 'Enabled with UEFI lock' }
        2 { 'Enabled without UEFI lock' }
        default { 'Not set (OS default applies)' }
    }
    WS2025DefaultExpectation  = 'Running on qualifying hardware (UEFI+SecureBoot+TPM2+IOMMU)'
    Assessment                = if ($cgRunning) { 'OK - Credential Guard active' }
                                elseif ($cgConfigured) { 'WARN - Configured but not running' }
                                else { 'INFO - Not running (check hardware requirements)' }
} | Format-List
#endregion

#region Section 3: HVCI
Write-Host "--- Section 3: HVCI (Hypervisor-Protected Code Integrity) ---" -ForegroundColor Yellow
$hvciRunning = $devGuard.SecurityServicesRunning -contains 2
$hvciConfigured = $devGuard.SecurityServicesConfigured -contains 2
$hvciFlag = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' `
    -Name HypervisorEnforcedCodeIntegrity -ErrorAction SilentlyContinue).HypervisorEnforcedCodeIntegrity

[PSCustomObject]@{
    HVCIConfigured   = $hvciConfigured
    HVCIRunning      = $hvciRunning
    RegistryFlag     = $hvciFlag
    Assessment       = if ($hvciRunning) { 'OK - HVCI active' } else { 'INFO - HVCI not running' }
} | Format-List
#endregion

#region Section 4: Secure Boot
Write-Host "--- Section 4: Secure Boot Status ---" -ForegroundColor Yellow
$secureBootEnabled = $false
try {
    $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
} catch {
    # Not UEFI or not accessible
}
[PSCustomObject]@{
    SecureBootEnabled = $secureBootEnabled
    Assessment        = if ($secureBootEnabled) { 'OK' } else { 'WARNING - Secure Boot required for Credential Guard default' }
} | Format-List
#endregion

#region Section 5: TPM Status
Write-Host "--- Section 5: TPM Status ---" -ForegroundColor Yellow
$tpm = Get-Tpm -ErrorAction SilentlyContinue
if ($tpm) {
    [PSCustomObject]@{
        TpmPresent        = $tpm.TpmPresent
        TpmReady          = $tpm.TpmReady
        TpmEnabled        = $tpm.TpmEnabled
        TpmActivated      = $tpm.TpmActivated
        ManagedAuthLevel  = $tpm.ManagedAuthLevel
        Assessment        = if ($tpm.TpmPresent -and $tpm.TpmReady) { 'OK - TPM 2.0 ready' } else { 'WARNING - TPM not ready' }
    } | Format-List
} else {
    Write-Warning "TPM not accessible or not present."
}
#endregion

#region Section 6: Secured-Core Summary
Write-Host "--- Section 6: Secured-Core Feature Summary ---" -ForegroundColor Yellow
$summary = [PSCustomObject]@{
    SecureBoot       = $secureBootEnabled
    TPMReady         = ($tpm.TpmPresent -and $tpm.TpmReady)
    VBSRunning       = ($devGuard.VirtualizationBasedSecurityStatus -eq 2)
    CredentialGuard  = $cgRunning
    HVCIRunning      = $hvciRunning
    OverallAssessment = 'See individual sections above'
}
$allGreen = $summary.SecureBoot -and $summary.TPMReady -and $summary.VBSRunning -and $summary.CredentialGuard
$summary.OverallAssessment = if ($allGreen) {
    'SECURED-CORE COMPLIANT'
} else {
    'PARTIAL - Review failing components above'
}
$summary | Format-List
#endregion
```

### Script 13: SMB Health (QUIC, Signing, Encryption)

```powershell
<#
.SYNOPSIS
    Windows Server 2025 SMB health — SMB over QUIC, signing enforcement, encryption.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+
    Safety   : Read-only. No modifications to SMB configuration.
    Sections :
        1. SMB Server Configuration (WS2025 security defaults)
        2. SMB over QUIC Status and Certificate Mappings
        3. Active SMB Connections
        4. SMB Signing Enforcement
        5. SMB Encryption Status
        6. SMB over QUIC Firewall Rules
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 SMB Health ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: SMB Server Configuration
Write-Host "--- Section 1: SMB Server Configuration ---" -ForegroundColor Yellow
$smbServer = Get-SmbServerConfiguration
[PSCustomObject]@{
    SMBQUICEnabled           = $smbServer.EnableSMBQUIC
    RequireSecuritySignature = $smbServer.RequireSecuritySignature
    EnableSecuritySignature  = $smbServer.EnableSecuritySignature
    EncryptData              = $smbServer.EncryptData
    SMB1Enabled              = $smbServer.EnableSMB1Protocol
    SMB2Enabled              = $smbServer.EnableSMB2Protocol
    MaxDialect               = $smbServer.MaxSmbVersionSelected
    WS2025SigningExpectation = 'RequireSecuritySignature should be True (default in WS2025)'
    WS2025SMB1Expectation    = 'EnableSMB1Protocol should be False (disabled by default)'
} | Format-List
#endregion

#region Section 2: SMB over QUIC
Write-Host "--- Section 2: SMB over QUIC Certificate Mappings ---" -ForegroundColor Yellow
$quicMappings = Get-SmbServerCertificateMapping -ErrorAction SilentlyContinue
if ($quicMappings) {
    $quicMappings | Select-Object Name, Subject, Thumbprint, StoreName, DisplayName |
        Format-Table -AutoSize

    # Check certificate validity
    foreach ($mapping in $quicMappings) {
        $cert = Get-ChildItem -Path "Cert:\LocalMachine\$($mapping.StoreName)" |
            Where-Object { $_.Thumbprint -eq $mapping.Thumbprint } |
            Select-Object -First 1
        if ($cert) {
            [PSCustomObject]@{
                MappingName     = $mapping.Name
                CertSubject     = $cert.Subject
                CertExpiry      = $cert.NotAfter
                DaysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
                CertValid       = $cert.NotAfter -gt (Get-Date)
                Assessment      = if ($cert.NotAfter -gt (Get-Date).AddDays(30)) { 'OK' }
                                  elseif ($cert.NotAfter -gt (Get-Date)) { 'WARNING - Expires within 30 days' }
                                  else { 'CRITICAL - Certificate expired' }
            } | Format-List
        } else {
            Write-Warning "Certificate for mapping '$($mapping.Name)' not found in store '$($mapping.StoreName)'"
        }
    }
} else {
    Write-Host "No SMB over QUIC certificate mappings configured."
    Write-Host "To enable: New-SmbServerCertificateMapping -Name 'ExternalSMB' -Thumbprint '<thumbprint>' -StoreName 'My' -Subject 'server.fqdn.com'"
}
#endregion

#region Section 3: Active SMB Connections
Write-Host "--- Section 3: Active SMB Connections ---" -ForegroundColor Yellow
$connections = Get-SmbConnection
if ($connections) {
    $connections | Group-Object Dialect | Select-Object Name, Count | Format-Table
    Write-Host "`nConnection detail (top 20):"
    $connections | Select-Object -First 20 ServerName, ShareName, Dialect, Encrypted, Signed |
        Format-Table -AutoSize
} else {
    Write-Host "No active SMB connections."
}
#endregion

#region Section 4: SMB Signing Enforcement
Write-Host "--- Section 4: SMB Signing Enforcement ---" -ForegroundColor Yellow
$smbClient = Get-SmbClientConfiguration
[PSCustomObject]@{
    ServerRequiresSigning   = $smbServer.RequireSecuritySignature
    ServerEnablesSigning    = $smbServer.EnableSecuritySignature
    ClientRequiresSigning   = $smbClient.RequireSecuritySignature
    ClientEnablesSigning    = $smbClient.EnableSecuritySignature
    Assessment              = if ($smbServer.RequireSecuritySignature) {
        'OK - Server requires signing (WS2025 default)'
    } else {
        'WARNING - Server does not require signing; consider enabling for security'
    }
} | Format-List

# Audit unsigned connections (Event 551)
$unsignedEvents = Get-WinEvent -LogName 'Microsoft-Windows-SMBServer/Operational' `
    -MaxEvents 10 -ErrorAction SilentlyContinue |
    Where-Object { $_.Id -eq 551 }
if ($unsignedEvents) {
    Write-Warning "Unsigned SMB connection attempts detected (Event 551):"
    $unsignedEvents | Select-Object TimeCreated, Message | Format-Table -Wrap
}
#endregion

#region Section 5: SMB Encryption
Write-Host "--- Section 5: SMB Encryption Status ---" -ForegroundColor Yellow
$shares = Get-SmbShare | Where-Object { $_.Name -notlike '*$' -or $_.Name -eq 'IPC$' }
$shares | Select-Object Name, EncryptData, Path | Format-Table -AutoSize

$encStats = Get-SmbServerNetworkInterface -ErrorAction SilentlyContinue
if ($encStats) {
    $encStats | Select-Object InterfaceIndex, IpAddress, FriendlyName, LinkSpeed | Format-Table -AutoSize
}
#endregion

#region Section 6: SMB over QUIC Firewall Rules
Write-Host "--- Section 6: SMB over QUIC Firewall Rules (UDP 443) ---" -ForegroundColor Yellow
$quicRules = Get-NetFirewallRule | Where-Object { $_.DisplayName -like '*QUIC*' -or $_.DisplayName -like '*SMB*' }
if ($quicRules) {
    $quicRules | Get-NetFirewallPortFilter | ForEach-Object {
        $rule = $quicRules | Where-Object { $_.InstanceID -eq $_.InstanceID }
        [PSCustomObject]@{
            RuleDisplayName = $_.OwningRule
            Protocol        = $_.Protocol
            LocalPort       = $_.LocalPort
        }
    }
    $quicRules | Select-Object DisplayName, Enabled, Direction, Action | Format-Table
} else {
    Write-Host "No SMB/QUIC-specific firewall rules found."
    Write-Host "For SMB over QUIC: ensure UDP 443 inbound is allowed."
}
#endregion
```

### Script 14: Hotpatch Status

```powershell
<#
.SYNOPSIS
    Windows Server 2025 Hotpatch status, Azure Arc enrollment, and compliance.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+ (Hotpatch available on all editions via Azure Arc)
    Safety   : Read-only. No modifications to patch configuration.
    Sections :
        1. OS Version and Hotpatch Eligibility
        2. Azure Arc Agent Status
        3. Current Patch Status
        4. Hotpatch vs Baseline Classification
        5. Pending Updates
        6. Reboot Status
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 Hotpatch Status ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: OS Version and Hotpatch Eligibility
Write-Host "--- Section 1: OS Version and Hotpatch Eligibility ---" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$isWS2025 = $os.BuildNumber -ge 26100
[PSCustomObject]@{
    Caption              = $os.Caption
    Version              = $os.Version
    BuildNumber          = $os.BuildNumber
    ServicePackMajorVer  = $os.ServicePackMajorVersion
    Is_WS2025            = $isWS2025
    HotpatchEligible     = $isWS2025
    HotpatchRequirement  = 'Windows Server 2025 + Azure Arc enrollment + Hotpatch subscription'
    AssessmentNote       = if ($isWS2025) {
        'OS eligible. Check Arc enrollment in Section 2.'
    } else {
        'NOT ELIGIBLE - Hotpatch requires Windows Server 2025+'
    }
} | Format-List
#endregion

#region Section 2: Azure Arc Agent Status
Write-Host "--- Section 2: Azure Arc Agent Status ---" -ForegroundColor Yellow
$arcSvc = Get-Service -Name himds -ErrorAction SilentlyContinue  # Hybrid Instance Metadata Service
$arcAgent = Get-Command azcmagent -ErrorAction SilentlyContinue

if ($arcSvc) {
    [PSCustomObject]@{
        HIMDSService    = $arcSvc.Status
        StartType       = $arcSvc.StartType
        Assessment      = if ($arcSvc.Status -eq 'Running') { 'OK - Arc agent running' }
                          else { 'WARNING - Arc HIMDS not running; hotpatch unavailable' }
    } | Format-List
} else {
    Write-Warning "Azure Arc agent (himds) not installed. Hotpatch requires Azure Arc enrollment."
    Write-Host "Install from: https://aka.ms/AzureConnectedMachineAgent"
}

if ($arcAgent) {
    try {
        $arcStatus = & azcmagent show 2>&1
        Write-Host "`nAzure Arc connection status:`n$arcStatus"
    } catch {
        Write-Warning "Cannot query azcmagent: $_"
    }
}
#endregion

#region Section 3: Current Patch Status
Write-Host "--- Section 3: Current Installed Updates ---" -ForegroundColor Yellow
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 |
    Select-Object HotFixID, Description, InstalledOn, InstalledBy |
    Format-Table -AutoSize

# Last update install time
$lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
if ($lastUpdate) {
    $daysSince = ((Get-Date) - [datetime]$lastUpdate.InstalledOn).Days
    [PSCustomObject]@{
        LastUpdateID      = $lastUpdate.HotFixID
        LastUpdateDate    = $lastUpdate.InstalledOn
        DaysSinceUpdate   = $daysSince
        Assessment        = if ($daysSince -le 45) { 'OK - Recent update applied' }
                            elseif ($daysSince -le 90) { 'WARNING - Update may be stale' }
                            else { 'CRITICAL - No update in 90+ days' }
    } | Format-List
}
#endregion

#region Section 4: Hotpatch vs Baseline Classification
Write-Host "--- Section 4: Update Type Identification ---" -ForegroundColor Yellow
Write-Host "Hotpatch months: in-memory only, no reboot required"
Write-Host "Baseline months: full cumulative update, reboot required (typically Jan/Apr/Jul/Oct)"
Write-Host ""
Write-Host "To identify if current patch is hotpatch:"
Write-Host "  - Hotpatch: applied without reboot, process memory patched"
Write-Host "  - Baseline: requires system reboot, updates all components"
Write-Host ""

# Check Windows Update history for hotpatch indicators
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $historyCount = $searcher.GetTotalHistoryCount()
    if ($historyCount -gt 0) {
        $history = $searcher.QueryHistory(0, [Math]::Min($historyCount, 20))
        $history | ForEach-Object {
            [PSCustomObject]@{
                Date        = $_.Date
                Title       = $_.Title
                ResultCode  = $_.ResultCode
                IsHotpatch  = $_.Title -like '*Hotpatch*'
            }
        } | Format-Table -AutoSize
    }
} catch {
    Write-Host "Windows Update COM object not accessible: $_"
}
#endregion

#region Section 5: Pending Updates
Write-Host "--- Section 5: Pending Updates ---" -ForegroundColor Yellow
try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $result = $searcher.Search('IsInstalled=0 and Type=''Software''')
    if ($result.Updates.Count -eq 0) {
        Write-Host "No pending updates found."
    } else {
        Write-Host "$($result.Updates.Count) pending update(s):"
        $result.Updates | ForEach-Object {
            [PSCustomObject]@{
                Title            = $_.Title
                RequiresReboot   = $_.InstallationBehavior.RebootBehavior -ne 0
                IsHotpatch       = $_.Title -like '*Hotpatch*'
            }
        } | Format-Table -AutoSize
    }
} catch {
    Write-Host "Cannot query Windows Update: $_"
}
#endregion

#region Section 6: Reboot Status
Write-Host "--- Section 6: Reboot Status ---" -ForegroundColor Yellow
$rebootPending = $false
$rebootReasons = @()

if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
    $rebootPending = $true; $rebootReasons += 'Component Based Servicing'
}
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    $rebootPending = $true; $rebootReasons += 'Windows Update'
}
if (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) {
    $rebootPending = $true; $rebootReasons += 'Pending File Operations'
}

[PSCustomObject]@{
    RebootPending   = $rebootPending
    Reasons         = if ($rebootReasons) { $rebootReasons -join ', ' } else { 'None' }
    LastBootTime    = $os.LastBootUpTime
    UptimeDays      = ((Get-Date) - $os.LastBootUpTime).Days
    Assessment      = if ($rebootPending) { 'REBOOT REQUIRED' } else { 'OK - No pending reboot' }
} | Format-List
#endregion
```

### Script 15: DTrace Setup and Validation

```powershell
<#
.SYNOPSIS
    Windows Server 2025 DTrace availability check and basic tracing validation.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+
    Safety   : Read-only. Runs brief non-destructive DTrace probes only.
    Sections :
        1. DTrace Installation Check
        2. DTrace Version and Binary Location
        3. Required Privileges Check
        4. Basic Probe Availability
        5. Sample One-Liner Validation
        6. Common DTrace Use Cases Reference
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 DTrace Setup & Validation ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: DTrace Installation Check
Write-Host "--- Section 1: DTrace Installation Check ---" -ForegroundColor Yellow
$dtraceBin = Get-Command dtrace -ErrorAction SilentlyContinue
$dtraceFeature = Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-DTrace' `
    -ErrorAction SilentlyContinue

[PSCustomObject]@{
    DTraceBinaryFound   = ($null -ne $dtraceBin)
    BinaryPath          = if ($dtraceBin) { $dtraceBin.Source } else { 'Not found' }
    OptionalFeature     = if ($dtraceFeature) { $dtraceFeature.State } else { 'Not found' }
    InstallCommand      = 'Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-DTrace -Online'
    Assessment          = if ($dtraceBin -and $dtraceFeature.State -eq 'Enabled') {
        'OK - DTrace installed and enabled'
    } elseif ($dtraceBin) {
        'PARTIAL - Binary found but feature state unclear'
    } else {
        'NOT INSTALLED - Run install command above'
    }
} | Format-List
#endregion

#region Section 2: DTrace Version
Write-Host "--- Section 2: DTrace Version ---" -ForegroundColor Yellow
if ($dtraceBin) {
    try {
        $version = & dtrace -version 2>&1
        Write-Host "DTrace version: $version"
    } catch {
        Write-Warning "Cannot get DTrace version: $_"
    }
} else {
    Write-Host "DTrace not installed. Skipping version check."
}
#endregion

#region Section 3: Required Privileges
Write-Host "--- Section 3: Required Privileges ---" -ForegroundColor Yellow
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]$identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Check for SeSystemProfilePrivilege and SeDebugPrivilege
$privs = whoami /priv 2>&1 | Select-String -Pattern 'SeSystemProfilePrivilege|SeDebugPrivilege'

[PSCustomObject]@{
    RunningAsAdmin         = $isAdmin
    PrivilegesFound        = if ($privs) { $privs -join '; ' } else { 'Not detected (may still be present)' }
    SeSystemProfilePriv    = ($privs | Where-Object { $_ -match 'SeSystemProfilePrivilege' }) -ne $null
    SeDebugPriv            = ($privs | Where-Object { $_ -match 'SeDebugPrivilege' }) -ne $null
    Assessment             = if ($isAdmin) { 'OK - Running as Administrator (DTrace should have required privileges)' }
                             else { 'ERROR - DTrace requires Administrator privileges' }
} | Format-List
#endregion

#region Section 4: Basic Probe Availability
Write-Host "--- Section 4: Basic Probe Availability ---" -ForegroundColor Yellow
if ($dtraceBin) {
    Write-Host "Testing DTrace probe providers..."
    Write-Host "Key probe types in Windows DTrace:"
    @(
        [PSCustomObject]@{ Provider='syscall'; Description='System call entry/return (e.g., NtCreateFile)'; Example="dtrace -n 'syscall:::entry { @[probefunc] = count(); }'" }
        [PSCustomObject]@{ Provider='fbt'; Description='Function Boundary Tracing - kernel function entry/return'; Example="dtrace -n 'fbt::*:entry { @[probefunc] = count(); }'" }
        [PSCustomObject]@{ Provider='pid'; Description='User-space process instrumentation'; Example="dtrace -n 'pid1234:::entry { trace(probefunc); }'" }
        [PSCustomObject]@{ Provider='profile'; Description='Timer-based sampling (wall clock or CPU)'; Example="dtrace -n 'profile-1000hz { @[execname] = count(); }'" }
        [PSCustomObject]@{ Provider='io'; Description='Block I/O events'; Example="dtrace -n 'io:::start { @[args[1]->dev_statname] = count(); }'" }
        [PSCustomObject]@{ Provider='proc'; Description='Process lifecycle (exec, exit, fork)'; Example="dtrace -n 'proc:::exec-success { trace(args[0]->pr_fname); }'" }
    ) | Format-Table -AutoSize -Wrap
}
#endregion

#region Section 5: Sample One-Liner Test
Write-Host "--- Section 5: Diagnostic One-Liner Reference ---" -ForegroundColor Yellow
Write-Host "The following one-liners are safe to run for diagnostics:"
Write-Host ""
Write-Host '# Count system calls by executable (1-second window):'
Write-Host "  dtrace -n 'syscall:::entry { @[execname] = count(); }' -c ""ping -n 1 localhost"""
Write-Host ""
Write-Host '# Trace file creates with process name:'
Write-Host "  dtrace -n 'syscall::NtCreateFile:entry { printf(""%s"", execname); }'"
Write-Host ""
Write-Host '# CPU hot-spots (1-second profile):'
Write-Host "  dtrace -n 'profile-1000hz /arg0/ { @[func(arg0)] = count(); }' -c ""sleep 1"""
Write-Host ""
Write-Host '# I/O operations by device:'
Write-Host "  dtrace -n 'io:::start { @[args[1]->dev_statname] = count(); }'"
Write-Host ""

if ($dtraceBin) {
    Write-Host "Running a brief 2-second syscall count test..."
    try {
        $result = & dtrace -n "syscall:::entry { @[execname] = count(); }" -c "ping -n 1 127.0.0.1" 2>&1
        if ($result) {
            Write-Host "DTrace test output:"
            Write-Host $result
            Write-Host "DTrace is operational." -ForegroundColor Green
        }
    } catch {
        Write-Warning "DTrace test execution failed: $_"
    }
}
#endregion

#region Section 6: Common Use Cases
Write-Host "--- Section 6: Common DTrace Use Cases for Windows Server 2025 ---" -ForegroundColor Yellow
@(
    [PSCustomObject]@{
        UseCase    = 'Process spawn tracking'
        Probe      = "proc:::exec-success"
        Purpose    = 'Identify unexpected process launches (security/audit)'
    }
    [PSCustomObject]@{
        UseCase    = 'Slow syscall detection'
        Probe      = "syscall:::entry/return with timestamp delta"
        Purpose    = 'Find system calls taking >1ms'
    }
    [PSCustomObject]@{
        UseCase    = 'NVMe I/O latency'
        Probe      = "io:::start/done with quantize()"
        Purpose    = 'Validate WS2025 native NVMe stack performance'
    }
    [PSCustomObject]@{
        UseCase    = 'CPU flame graph data'
        Probe      = "profile-1000hz sampling"
        Purpose    = 'Identify hot functions for optimization'
    }
) | Format-Table -AutoSize -Wrap
#endregion
```

### Script 16: NVMe/TCP Diagnostics

```powershell
<#
.SYNOPSIS
    Windows Server 2025 NVMe/TCP remote storage diagnostics and NVMe stack validation.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+ (NVMe/TCP requires Datacenter edition)
    Safety   : Read-only. No modifications to storage or network configuration.
    Sections :
        1. NVMe Device Enumeration (Native Stack)
        2. NVMe Stack Validation (vs Legacy SCSI Emulation)
        3. NVMe Performance Counters
        4. NVMe/TCP Feature Availability (Datacenter)
        5. NVMe/TCP Connections
        6. Storage Health Summary
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 NVMe Stack & NVMe/TCP Diagnostics ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

#region Section 1: NVMe Device Enumeration
Write-Host "--- Section 1: NVMe Device Enumeration ---" -ForegroundColor Yellow
$nvmeDisks = Get-PhysicalDisk | Where-Object { $_.BusType -eq 'NVMe' }
if ($nvmeDisks) {
    $nvmeDisks | Select-Object FriendlyName, BusType, HealthStatus, OperationalStatus,
        @{N='Size_GB'; E={ [math]::Round($_.Size / 1GB, 1) }},
        @{N='MediaType'; E={ $_.MediaType }} |
        Format-Table -AutoSize
    Write-Host "Total NVMe devices: $($nvmeDisks.Count)"
} else {
    Write-Host "No local NVMe devices detected."
}

# Check all physical disks by bus type
Write-Host "`nAll storage by bus type:"
Get-PhysicalDisk | Group-Object BusType |
    Select-Object Name, Count | Format-Table -AutoSize
#endregion

#region Section 2: NVMe Stack Validation
Write-Host "--- Section 2: NVMe Stack Validation ---" -ForegroundColor Yellow
# Check storenvm.sys version (Microsoft's native NVMe driver)
$nvmeDriver = Get-SystemDriver -Name storenvm -ErrorAction SilentlyContinue
if (-not $nvmeDriver) {
    # Alternative method
    $driverFile = Get-Item 'C:\Windows\System32\drivers\stornvme.sys' -ErrorAction SilentlyContinue
    if ($driverFile) {
        $nvmeDriver = [PSCustomObject]@{
            Name        = 'stornvme'
            Description = 'Standard NVMe Storage Controller'
            Version     = $driverFile.VersionInfo.FileVersion
            LastWrite   = $driverFile.LastWriteTime
        }
    }
}

if ($nvmeDriver) {
    [PSCustomObject]@{
        DriverName     = 'stornvme.sys'
        Version        = (Get-Item 'C:\Windows\System32\drivers\stornvme.sys').VersionInfo.FileVersion
        WS2025Native   = 'stornvme.sys is the native NVMe driver (replaces SCSI emulation path)'
        Assessment     = 'OK - Using native NVMe stack'
    } | Format-List
} else {
    Write-Warning "stornvme.sys not found. Investigating alternative NVMe drivers..."
    Get-PnpDevice | Where-Object { $_.Class -eq 'DiskDrive' -and $_.FriendlyName -like '*NVMe*' } |
        Select-Object InstanceId, FriendlyName, Status | Format-Table
}

# Verify no SCSI emulation wrappers for NVMe
$scsiNvme = Get-PnpDevice |
    Where-Object { $_.FriendlyName -like '*NVMe*' -and $_.Class -eq 'SCSIAdapter' }
if ($scsiNvme) {
    Write-Warning "NVMe devices found with SCSI adapter class — may indicate legacy emulation:"
    $scsiNvme | Select-Object InstanceId, FriendlyName, Status | Format-Table
} else {
    Write-Host "No SCSI-emulated NVMe devices detected (expected in WS2025 native stack)"
}
#endregion

#region Section 3: NVMe Performance Counters
Write-Host "--- Section 3: NVMe Performance Counters (5-second sample) ---" -ForegroundColor Yellow
try {
    $sample1 = Get-Counter '\PhysicalDisk(*)\Disk Reads/sec', '\PhysicalDisk(*)\Disk Writes/sec',
        '\PhysicalDisk(*)\Avg. Disk sec/Read', '\PhysicalDisk(*)\Avg. Disk sec/Write' -ErrorAction Stop
    Start-Sleep -Seconds 2
    $sample2 = Get-Counter '\PhysicalDisk(*)\Disk Reads/sec', '\PhysicalDisk(*)\Disk Writes/sec',
        '\PhysicalDisk(*)\Avg. Disk sec/Read', '\PhysicalDisk(*)\Avg. Disk sec/Write' -ErrorAction Stop

    $sample2.CounterSamples |
        Where-Object { $_.InstanceName -ne '_total' } |
        Select-Object `
            @{N='Disk'; E={ $_.InstanceName }},
            @{N='Counter'; E={ $_.Path -replace '.*\\PhysicalDisk\([^)]+\)\\','' }},
            @{N='Value'; E={ [math]::Round($_.CookedValue, 4) }} |
        Sort-Object Disk, Counter |
        Format-Table -AutoSize
} catch {
    Write-Warning "Could not collect PhysicalDisk counters: $_"
}
#endregion

#region Section 4: NVMe/TCP Feature Availability
Write-Host "--- Section 4: NVMe/TCP Feature Availability (Datacenter Edition) ---" -ForegroundColor Yellow
$os = Get-CimInstance Win32_OperatingSystem
$isDatacenter = $os.Caption -like '*Datacenter*'

[PSCustomObject]@{
    Edition              = $os.Caption
    NVMeTCPAvailable     = $isDatacenter
    Assessment           = if ($isDatacenter) {
        'OK - Datacenter edition supports NVMe/TCP initiator'
    } else {
        'INFO - NVMe/TCP initiator requires Datacenter edition'
    }
    Note = 'NVMe/TCP target role may be provided by storage arrays or WS2025 Datacenter hosts'
} | Format-List

# Check for NVMe/TCP cmdlets availability
$nvmeTcpCmds = Get-Command -Name '*NvmeTcp*' -ErrorAction SilentlyContinue
if ($nvmeTcpCmds) {
    Write-Host "Available NVMe/TCP cmdlets:"
    $nvmeTcpCmds | Select-Object Name, ModuleName | Format-Table
} else {
    Write-Host "No NVMe/TCP cmdlets found in current session."
    Write-Host "Try: Import-Module StorageSpaces ; Get-Command *NvmeTcp*"
}
#endregion

#region Section 5: NVMe/TCP Connections
Write-Host "--- Section 5: NVMe/TCP Active Connections ---" -ForegroundColor Yellow
if ($isDatacenter) {
    try {
        Import-Module StorageSpaces -ErrorAction Stop
        $nvmeTcpConns = Get-NvmeTcpConnection -ErrorAction SilentlyContinue
        if ($nvmeTcpConns) {
            $nvmeTcpConns | Format-Table -AutoSize
        } else {
            Write-Host "No active NVMe/TCP connections."
            Write-Host "To connect: Connect-NvmeTcpTarget -TargetPortalAddress <IP> -TargetPortalPortNumber 4420"
        }
    } catch {
        Write-Host "StorageSpaces module or NVMe/TCP cmdlets not available: $_"
    }
} else {
    Write-Host "NVMe/TCP requires Datacenter edition. Skipping connection check."
}
#endregion

#region Section 6: Storage Health Summary
Write-Host "--- Section 6: Storage Health Summary ---" -ForegroundColor Yellow
Get-PhysicalDisk |
    Select-Object FriendlyName, BusType, HealthStatus, OperationalStatus,
        @{N='Size_GB'; E={ [math]::Round($_.Size/1GB,1) }} |
    Sort-Object BusType, FriendlyName |
    Format-Table -AutoSize

$unhealthyDisks = Get-PhysicalDisk | Where-Object { $_.HealthStatus -ne 'Healthy' }
if ($unhealthyDisks) {
    Write-Warning "Unhealthy disks detected:"
    $unhealthyDisks | Select-Object FriendlyName, HealthStatus, OperationalStatus | Format-Table
} else {
    Write-Host "All disks healthy." -ForegroundColor Green
}
#endregion
```

### Script 17: Delegated Managed Service Account (dMSA) Health

```powershell
<#
.SYNOPSIS
    Windows Server 2025 Delegated Managed Service Account (dMSA) status and migration readiness.
.NOTES
    Version  : 2025.1.0
    Targets  : Windows Server 2025+ with Active Directory (DFL 10 for full dMSA)
    Safety   : Read-only. No modifications to AD objects or service configurations.
    Sections :
        1. Domain Functional Level Check (DFL 10 required for dMSA)
        2. Existing Managed Service Accounts (gMSA inventory)
        3. dMSA Objects
        4. dMSA Migration Readiness
        5. Service Account Usage on Local Machine
        6. dMSA Best Practice Checks
#>
#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "`n=== Windows Server 2025 dMSA Health & Migration Readiness ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)`n"

# Check if ActiveDirectory module is available
$adModule = Get-Module -Name ActiveDirectory -ListAvailable
if (-not $adModule) {
    Write-Warning "ActiveDirectory module not available. Install RSAT-AD-PowerShell feature."
    Write-Host "Install command: Add-WindowsFeature RSAT-AD-PowerShell"
    Write-Host "Some sections will be skipped."
}

#region Section 1: Domain Functional Level
Write-Host "--- Section 1: Domain Functional Level (DFL 10 required for dMSA) ---" -ForegroundColor Yellow
if ($adModule) {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = Get-ADDomain -ErrorAction Stop
        $forest = Get-ADForest -ErrorAction Stop
        [PSCustomObject]@{
            DomainName        = $domain.DNSRoot
            DomainMode        = $domain.DomainMode
            DomainModeNum     = [int]$domain.DomainMode
            ForestMode        = $forest.ForestMode
            DFL10_Required    = 'Windows2025Domain (value 10)'
            dMSA_Supported    = ($domain.DomainMode -ge 'Windows2025Domain')
            Assessment        = if ($domain.DomainMode -ge 'Windows2025Domain') {
                'OK - DFL 10 met; dMSA creation supported'
            } elseif ($domain.DomainMode -ge 'Windows2016Domain') {
                "INFO - DFL is $($domain.DomainMode); raise to Windows2025Domain for dMSA creation"
            } else {
                "WARNING - DFL $($domain.DomainMode) is too low; dMSA requires DFL 10 (Windows2025Domain)"
            }
        } | Format-List

        Write-Host "Domain Controllers:"
        Get-ADDomainController -Filter * |
            Select-Object Name, OperatingSystem, OperatingSystemVersion, IsGlobalCatalog, Site |
            Format-Table -AutoSize
    } catch {
        Write-Warning "Cannot query AD domain: $_"
    }
} else {
    Write-Host "ActiveDirectory module not available. Skipping DFL check."
}
#endregion

#region Section 2: Existing gMSA Inventory
Write-Host "--- Section 2: Existing gMSA Inventory (migration candidates) ---" -ForegroundColor Yellow
if ($adModule) {
    try {
        $gmsas = Get-ADServiceAccount -Filter { ObjectClass -eq 'msDS-GroupManagedServiceAccount' } `
            -Properties Name, DNSHostName, Enabled, PrincipalsAllowedToRetrieveManagedPassword,
                        Created, Modified, Description -ErrorAction Stop

        if ($gmsas) {
            Write-Host "Found $($gmsas.Count) gMSA object(s):"
            $gmsas | Select-Object Name, DNSHostName, Enabled, Created, Modified |
                Format-Table -AutoSize

            Write-Host "`ngMSA details (migration candidates):"
            foreach ($gmsa in $gmsas) {
                [PSCustomObject]@{
                    Name                    = $gmsa.Name
                    DNSHostName             = $gmsa.DNSHostName
                    Enabled                 = $gmsa.Enabled
                    Created                 = $gmsa.Created
                    Modified                = $gmsa.Modified
                    Description             = $gmsa.Description
                    MigrationCandidate      = 'Yes - can migrate to dMSA with New-ADServiceAccount -MigratedFromServiceAccount'
                } | Format-List
            }
        } else {
            Write-Host "No gMSA objects found in this domain."
        }
    } catch {
        Write-Warning "Cannot query gMSA objects: $_"
    }
} else {
    Write-Host "Skipping (ActiveDirectory module not available)"
}
#endregion

#region Section 3: dMSA Objects
Write-Host "--- Section 3: Delegated MSA (dMSA) Objects ---" -ForegroundColor Yellow
if ($adModule) {
    try {
        # dMSA objects are of objectClass msDS-DelegatedManagedServiceAccount (new in DFL 10)
        $dmsas = Get-ADServiceAccount -Filter { ObjectClass -eq 'msDS-DelegatedManagedServiceAccount' } `
            -Properties Name, DNSHostName, Enabled, Created, Modified, Description `
            -ErrorAction Stop

        if ($dmsas) {
            Write-Host "Found $($dmsas.Count) dMSA object(s):"
            $dmsas | Select-Object Name, DNSHostName, Enabled, Created, Modified |
                Format-Table -AutoSize
        } else {
            Write-Host "No dMSA objects found. dMSA requires DFL 10 (Windows Server 2025 domain)."
            Write-Host "Create command: New-ADServiceAccount -Name 'svc-name' -DelegatedManagedServiceAccount -DNSHostName 'svc.domain.com'"
        }
    } catch {
        # Likely because the schema class doesn't exist yet (DFL < 10)
        Write-Host "dMSA class not available in AD schema. Requires Windows Server 2025 DFL."
    }
} else {
    Write-Host "Skipping (ActiveDirectory module not available)"
}
#endregion

#region Section 4: dMSA Migration Readiness
Write-Host "--- Section 4: dMSA Migration Readiness Assessment ---" -ForegroundColor Yellow
if ($adModule) {
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        $dfl = $domain.DomainMode
        $allDCsWS2025 = (Get-ADDomainController -Filter *).OperatingSystem |
            ForEach-Object { $_ -like '*2025*' } |
            Where-Object { $_ -eq $false }
        $allOnWS2025 = ($allDCsWS2025.Count -eq 0)

        @(
            [PSCustomObject]@{
                Requirement     = 'Domain Functional Level 10'
                Met             = ($dfl -ge 'Windows2025Domain')
                CurrentValue    = $dfl
                Action          = if ($dfl -ge 'Windows2025Domain') { 'None' }
                                  else { 'Raise DFL: Set-ADDomainMode -Identity domain -DomainMode Windows2025Domain' }
            }
            [PSCustomObject]@{
                Requirement     = 'All DCs on Windows Server 2025'
                Met             = $allOnWS2025
                CurrentValue    = if ($allOnWS2025) { 'All WS2025' } else { 'Mixed OS versions' }
                Action          = if ($allOnWS2025) { 'None' }
                                  else { 'Upgrade all DCs to Windows Server 2025 before raising DFL' }
            }
            [PSCustomObject]@{
                Requirement     = 'RSAT-AD-PowerShell available'
                Met             = ($null -ne $adModule)
                CurrentValue    = if ($adModule) { $adModule.Version } else { 'Not installed' }
                Action          = if ($adModule) { 'None' } else { 'Add-WindowsFeature RSAT-AD-PowerShell' }
            }
        ) | Format-Table -AutoSize -Wrap
    } catch {
        Write-Warning "Cannot assess migration readiness: $_"
    }
} else {
    Write-Host "Skipping (ActiveDirectory module not available)"
}
#endregion

#region Section 5: Service Account Usage on Local Machine
Write-Host "--- Section 5: Service Account Usage on Local Machine ---" -ForegroundColor Yellow
$services = Get-CimInstance Win32_Service |
    Where-Object { $_.StartName -notlike 'LocalSystem' -and
                   $_.StartName -notlike 'NT AUTHORITY*' -and
                   $_.StartName -notlike 'NT SERVICE*' -and
                   $_.StartName -ne $null }

if ($services) {
    Write-Host "Services running under non-built-in accounts (managed service account candidates):"
    $services | Select-Object Name, DisplayName, StartName, State, StartMode |
        Format-Table -AutoSize

    # Flag any running as standard domain users (not MSAs)
    $domainUserSvcs = $services | Where-Object { $_.StartName -notlike '*$*' }
    if ($domainUserSvcs) {
        Write-Warning "Services using standard domain user accounts (should use gMSA or dMSA):"
        $domainUserSvcs | Select-Object Name, StartName | Format-Table
    }

    # Flag gMSA accounts (end in $)
    $msaSvcs = $services | Where-Object { $_.StartName -like '*$' }
    if ($msaSvcs) {
        Write-Host "Services using MSA/gMSA accounts ($ suffix — dMSA migration candidates):"
        $msaSvcs | Select-Object Name, StartName | Format-Table
    }
} else {
    Write-Host "No services running under non-built-in accounts on this machine."
}
#endregion

#region Section 6: dMSA Best Practice Checks
Write-Host "--- Section 6: dMSA Best Practice Summary ---" -ForegroundColor Yellow
@(
    [PSCustomObject]@{
        Practice    = 'Use dMSA over standard accounts for services'
        Reason      = 'Auto-rotating passwords, no manual credential management'
        Reference   = 'New-ADServiceAccount -DelegatedManagedServiceAccount'
    }
    [PSCustomObject]@{
        Practice    = 'Specify PrincipalsAllowedToRetrieveManagedPassword'
        Reason      = 'Limit which computers/groups can use the dMSA'
        Reference   = 'New-ADServiceAccount ... -PrincipalsAllowedToRetrieveManagedPassword'
    }
    [PSCustomObject]@{
        Practice    = 'Run Test-ADServiceAccount before deploying'
        Reason      = 'Validate dMSA can be installed on target server'
        Reference   = 'Test-ADServiceAccount -Identity svc-name'
    }
    [PSCustomObject]@{
        Practice    = 'Use Complete-ADServiceAccountMigration when done migrating'
        Reason      = 'Removes the link to old account and cleans up'
        Reference   = 'Complete-ADServiceAccountMigration -Identity svc-name-new'
    }
    [PSCustomObject]@{
        Practice    = 'Audit dMSA usage via AD auditing'
        Reason      = 'dMSA access is auditable with enhanced audit trail vs gMSA'
        Reference   = 'Enable object access auditing in Default Domain Controllers Policy'
    }
) | Format-Table -AutoSize -Wrap
#endregion
```

---

## Version Boundary Notes

Features present in Windows Server 2022 that are NOT Windows Server 2025 exclusive:
- Storage Spaces Direct (S2D) — 2016+
- Hyper-V basic features, ReFS, SMB 3.x — pre-2025
- Windows Admin Center — works with 2019+
- Failover Clustering — long-standing feature

Features REMOVED or DEPRECATED in Windows Server 2025:
- 32-bit kernel and 32-bit process mode (completely gone)
- RemoteFX vGPU (deprecated since 2022, removed in 2025)
- NTLM v1 (blocked by default, supported only with explicit configuration)
- Stretch Database for SQL Server (deprecated — note: SQL Server feature, not Windows Server)

## Key Reference Sources

- Windows Server 2025 What's New: https://learn.microsoft.com/en-us/windows-server/get-started/whats-new-windows-server-2025
- Hotpatch for Windows Server 2025: https://learn.microsoft.com/en-us/azure/update-manager/hotpatch-on-premises
- SMB over QUIC: https://learn.microsoft.com/en-us/windows-server/storage/file-server/smb-over-quic
- DTrace for Windows: https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/dtrace
- dMSA: https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/delegated-managed-service-accounts
- NVMe/TCP: https://learn.microsoft.com/en-us/windows-server/storage/nvme/nvme-tcp
- GPU Partitioning: https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/deploy/gpu-partitioning
