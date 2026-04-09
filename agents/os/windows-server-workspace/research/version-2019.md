# Windows Server 2019 — Version-Specific Research

**Support Status:** Extended Support until January 9, 2029
**Baseline:** Windows Server 2016; this file covers only NEW or CHANGED features in 2019
**Consumed by:** Opus writer agent producing the version-specific agent file

---

## 1. Windows Admin Center (WAC)

### Overview
WAC is a browser-based, locally deployed management tool introduced as the modern replacement for Server Manager and MMC snap-ins. It requires no cloud connectivity and runs on the admin's machine or a dedicated gateway server.

### Deployment Modes
- **Desktop mode** — Install on a Windows 10/11 admin workstation; manages local and remote servers. Port 6516 (default).
- **Gateway mode** — Install on a dedicated Windows Server; all admins connect through the gateway URL. Recommended for production. Port 443 (HTTPS).

### Gateway Installation (PowerShell)
```powershell
# Download installer (run on the gateway server)
$url = 'https://aka.ms/WACDownload'
$dest = "$env:TEMP\WindowsAdminCenter.msi"
Invoke-WebRequest -Uri $url -OutFile $dest

# Silent install — gateway mode on port 443
msiexec /i $dest /qn /L*v "$env:TEMP\wac-install.log" SME_PORT=443 SSL_CERTIFICATE_OPTION=generate

# Verify service
Get-Service -Name ServerManagementGateway
```

### Certificate Configuration
```powershell
# Bind an existing certificate to WAC (gateway mode)
# Get thumbprint of your cert
$thumb = (Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like '*wac.contoso.com*').Thumbprint

# Re-run installer binding the cert
msiexec /i $dest /qn SME_PORT=443 SME_THUMBPRINT=$thumb SSL_CERTIFICATE_OPTION=installed
```

### Connecting to Server Core Instances
Server Core has no GUI — WAC is the primary management surface.
```powershell
# On the Server Core target — ensure WinRM is enabled
winrm quickconfig -quiet
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'wac-gateway.contoso.com' -Force

# On the gateway — add the Server Core machine
# Done through WAC UI: Add > Add Server Connection > enter hostname/IP
# Credential delegation requires CredSSP or Kerberos constrained delegation configured on gateway
```

### Key Considerations
- WAC extensions (e.g., Dell OpenManage, HPE, Azure hybrid) install per-gateway; manage via Settings > Extensions.
- HCI (Hyper-Converged Infrastructure) management (Storage Spaces Direct clusters) requires the "Hyper-Converged Cluster" connection type.
- WAC does not replace RSAT — RSAT tools remain necessary for some AD/DNS/DHCP workflows.
- Role-based access control (RBAC) in gateway mode uses Windows groups mapped to gateway roles.

### Pitfalls
- Mixed authentication environments: if CredSSP is not configured, double-hop authentication fails silently (tools load but show empty data).
- Self-signed certificate generated at install is untrusted by default browsers; replace with a CA-signed cert for shared gateway use.
- WAC port 443 conflicts with IIS if both are installed on the same server.

---

## 2. System Insights

### Overview
System Insights is a new Windows Server 2019 feature providing built-in predictive analytics using locally trained ML models. It forecasts resource consumption based on historical performance data collected by the system, surfacing predictions without requiring cloud connectivity or external ML infrastructure.

### Built-in Capabilities (Four Default)
| Capability | What it predicts | Data source |
|---|---|---|
| CPU capacity forecasting | Future CPU utilization trends | Performance counters |
| Networking capacity forecasting | Future inbound/outbound traffic | Performance counters |
| Total storage consumption forecasting | Aggregate storage usage growth | Performance counters |
| Volume consumption forecasting | Per-volume usage growth | Performance counters |

### Installation and Enablement
```powershell
# Install the feature (includes management cmdlets)
Install-WindowsFeature -Name System-Insights -IncludeManagementTools

# Verify installed capabilities
Get-InsightsCapability
```

### Core Management Cmdlets
```powershell
# List all capabilities with status
Get-InsightsCapability

# Run a specific capability on demand
Invoke-InsightsCapability -Name 'CPU capacity forecasting'

# Get prediction results for a capability
Get-InsightsCapabilityResult -Name 'CPU capacity forecasting'

# View historical data behind predictions
Get-InsightsCapabilitySchedule -Name 'Volume consumption forecasting'

# Update prediction schedule (default is weekly)
Set-InsightsCapabilitySchedule -Name 'CPU capacity forecasting' -Daily

# Add a remediation action (runs when prediction threshold met)
Add-InsightsCapabilityAction -Name 'CPU capacity forecasting' `
    -Type Script -ScriptPath 'C:\Scripts\scale-cpu-alert.ps1'
```

### Custom Capabilities
Developers can author custom ML capabilities using the System Insights SDK (NuGet: Microsoft.SystemInsights.Capability). Custom capabilities register via PowerShell and appear alongside built-in ones in WAC.

### WAC Integration
System Insights has a dedicated WAC extension. Predictions display with traffic-light status (OK / Warning / Critical) and trend charts. Remediation actions can be configured through the UI.

### Key Considerations
- Predictions require at least 30 days of historical data for accurate forecasting.
- The feature has no network dependency — all model training and inference runs locally.
- Each capability stores its own time-series data; removing and re-adding a capability resets its history.

### Pitfalls
- Fresh installs show "Insufficient data" status for 30 days — do not treat this as a failure.
- Remediation scripts run as SYSTEM; scope permissions carefully.
- On VMs with dynamic resource allocation, forecasts may skew high due to burst patterns from the host.

---

## 3. Storage Migration Service (SMS)

### Overview
SMS is a new role in Windows Server 2019 that automates migration of file servers — including files, shares, NTFS permissions, and server identity — from legacy systems (Windows Server 2003 and later, Samba/Linux) to newer targets. It eliminates manual robocopy + share recreation workflows.

### Three Migration Phases
1. **Inventory** — Catalogs shares, files, permissions, and local user accounts on the source.
2. **Transfer** — Copies data incrementally to the target server (multiple passes; final pass before cutover).
3. **Cutover** — Transfers the source server's identity (computer name, IP addresses, SPNs) to the target; source is renamed; DNS updates propagate.

### Installation
```powershell
# On the orchestrator server (runs the SMS service; can be same as target)
Install-WindowsFeature -Name SMS -IncludeManagementTools

# On the source server (must be reachable; SMS installs proxy automatically via WMI)
# Or manually pre-install proxy on source if WMI is blocked:
Install-WindowsFeature -Name SMS-Proxy

# Verify SMS service
Get-Service -Name SMS
```

### PowerShell Workflow
```powershell
# Import the module
Import-Module StorageMigrationService

# Create a new migration job
New-SmsJob -Name 'FileServer-Migration-2024' -Description 'DC01 to FS2019'

# Add source to the job
Add-SmsSourceServer -JobName 'FileServer-Migration-2024' -SourceComputerName 'OldServer'

# Run inventory phase
Start-SmsInventory -JobName 'FileServer-Migration-2024'

# Check inventory status
Get-SmsJob -Name 'FileServer-Migration-2024' | Select-Object State, InventoryStatus

# Start transfer phase
Start-SmsTransfer -JobName 'FileServer-Migration-2024' `
    -SourceComputerName 'OldServer' `
    -DestinationComputerName 'NewServer2019'

# Monitor transfer progress
Get-SmsTransferProgress -JobName 'FileServer-Migration-2024'

# Execute cutover (transfers identity)
Start-SmsCutover -JobName 'FileServer-Migration-2024' `
    -SourceComputerName 'OldServer' `
    -DestinationComputerName 'NewServer2019'
```

### Identity Transfer Details
During cutover SMS transfers:
- Computer name (source is renamed to a temporary name)
- IP addresses (if configured)
- Service Principal Names (SPNs) — critical for Kerberos authentication
- DNS registrations

### WAC Integration
SMS has a first-class WAC extension. The UI walks through all three phases with progress bars, error detail, and per-share transfer statistics. Recommended for most migrations; PowerShell is useful for scripting/automation.

### Key Considerations
- Source can be Windows Server 2003 SP2 or later, and Samba 2.x+ on Linux/NAS.
- Orchestrator requires Windows Server 2019; target must be 2019 or later.
- SMS requires SMB 2.0 or later between orchestrator and source.
- Local users and groups on the source can optionally be migrated to the target.

### Pitfalls
- Firewall rules: SMS requires File and Printer Sharing (SMB-In), WMI, and SMS-specific ports (TCP 28940) open between orchestrator, source, and target.
- Cutover is not instantaneous — plan a maintenance window; clients will experience brief disconnection.
- If source runs Server 2003, you must configure the SMS proxy manually (WMI is often restricted on 2003).
- Identity transfer does not move GPOs or AD computer object settings; those require separate handling.

---

## 4. Storage Spaces Direct (S2D) Improvements

### Persistent Memory (PMEM / Storage Class Memory)
Windows Server 2019 adds native support for NVDIMM and Intel Optane DC Persistent Memory modules.

```powershell
# Enumerate PMEM devices
Get-PhysicalDisk | Where-Object BusType -eq SCM

# Initialize PMEM for use as cache tier in S2D
# (Done at S2D enablement; PMEM auto-detected as cache by default)
Enable-ClusterStorageSpacesDirect -CacheDeviceModel 'NVDimm'

# Use PMEM as capacity (filesystem DAX mode — requires ReFS block cloning disabled)
# Provision namespace first
Get-PmemDisk
New-PmemDisk -PhysicalDeviceIds (Get-PmemPhysicalDevice).DeviceId
```

### Deduplication on ReFS Volumes
2019 is the first version to support block-level deduplication on ReFS within S2D. Dedup on ReFS runs in real-time (not scheduled jobs like NTFS dedup).

```powershell
# Enable dedup on an S2D ReFS volume
Enable-DedupVolume -Volume 'D:\' -UsageType HyperV

# Check dedup savings
Get-DedupStatus -Volume 'D:\'

# Dedup is real-time on ReFS — no manual job scheduling needed
# NTFS dedup jobs still apply to NTFS volumes
```

### Maximum Volume Size
S2D maximum volume size increased to 4 PB per volume (from 64 TB in 2016).

### Performance History (Get-ClusterPerformanceHistory)
New cmdlet providing 50+ series of historical performance metrics stored directly in S2D.

```powershell
# Get CPU history for cluster nodes
Get-ClusterPerformanceHistory -ClusterNode (Get-ClusterNode) -TimeFrame LastWeek

# Get IOPS history for a virtual disk
Get-ClusterPerformanceHistory -VirtualDisk (Get-VirtualDisk 'DataVol') -TimeFrame LastDay

# Get volume throughput history
Get-ClusterPerformanceHistory -Volume (Get-Volume | Where-Object FileSystem -eq ReFS) `
    -TimeFrame LastHour
```

### Cluster Sets
Cluster Sets enable grouping multiple S2D clusters into a single management namespace, enabling cross-cluster live migration and fault domain spanning.

```powershell
# Create a cluster set (run on the management cluster)
New-ClusterSet -Name 'HCI-SuperSet' -NamespaceRoot 'SOFS-Namespace' `
    -StaticAddress '10.0.0.100'

# Add member clusters to the set
Add-ClusterSetMember -ClusterSetName 'HCI-SuperSet' -ClusterName 'Cluster01'
Add-ClusterSetMember -ClusterSetName 'HCI-SuperSet' -ClusterName 'Cluster02'

# View cluster set members
Get-ClusterSetMember -ClusterSetName 'HCI-SuperSet'
```

### Pitfalls
- PMEM in AppDirect mode (DAX) bypasses the Windows cache manager; not all applications support this correctly.
- ReFS dedup on S2D requires the S2D volume to be online and the cluster functional; dedup pauses during node failures.
- Cluster Sets require all member clusters to run Windows Server 2019 or later.
- Performance history data is stored in S2D itself; a complete cluster failure means history loss.

---

## 5. Storage Replica on Standard Edition

### Overview
Storage Replica (SR) was Datacenter-only in Windows Server 2016. Windows Server 2019 Standard edition gains SR support with the following restrictions.

### Standard Edition Restrictions (vs. Datacenter)
| Feature | Standard 2019 | Datacenter 2019 |
|---|---|---|
| Partnerships per server | 1 | Unlimited |
| Resource groups per partnership | 1 | Unlimited |
| Max replicated volume size | 2 TB | Unlimited |
| Asynchronous replication | Yes | Yes |
| Synchronous replication | Yes | Yes |
| Log volume required | Yes | Yes |

### Configuration
```powershell
# Install Storage Replica on both servers
Install-WindowsFeature -Name Storage-Replica -IncludeManagementTools -Restart

# Test prerequisites before configuring
Test-SRTopology -SourceComputerName 'SRV-Source' `
    -SourceVolumeName 'D:' -SourceLogVolumeName 'E:' `
    -DestinationComputerName 'SRV-Dest' `
    -DestinationVolumeName 'D:' -DestinationLogVolumeName 'E:' `
    -DurationInMinutes 30 -ResultPath 'C:\SR-Test'

# Create replication partnership (synchronous)
New-SRPartnership -SourceComputerName 'SRV-Source' `
    -SourceRGName 'SourceRG' -SourceVolumeName 'D:' -SourceLogVolumeName 'E:' `
    -DestinationComputerName 'SRV-Dest' `
    -DestinationRGName 'DestRG' -DestinationVolumeName 'D:' -DestinationLogVolumeName 'E:' `
    -ReplicationMode Synchronous

# Check replication status
(Get-SRGroup).Replicas | Select-Object NumOfBytesRemaining, ReplicationStatus, LastInSyncTime

# Monitor replication health
Get-SRPartnership | Get-SRGroup
```

### Key Considerations
- The destination volume is mounted read-only and inaccessible during replication — this is by design.
- Log volume should be dedicated (no other data), sized at minimum 8 GB, same or faster speed as data volume.
- Synchronous mode requires round-trip latency under 5 ms for acceptable performance.
- Standard edition's 2 TB limit applies per replicated volume, not total.

### Pitfalls
- Attempting a second partnership on Standard edition fails with an explicit error — license enforcement is in the feature, not just documentation.
- Log volume on spinning disk causes severe performance degradation; always use SSD/NVMe for the log.
- Initial sync of large volumes over WAN can take days; plan bandwidth and schedule accordingly.

---

## 6. Kubernetes and Windows Container Networking

### Windows Node Support
Windows Server 2019 ships with the first production-ready support for Windows nodes in Kubernetes clusters. Windows containers running on Windows Server 2019 nodes can be scheduled by a Kubernetes control plane (Linux-based).

```powershell
# Install container and Kubernetes prerequisites
Install-WindowsFeature -Name Containers -Restart

# Pull Windows Server Core base image
docker pull mcr.microsoft.com/windows/servercore:ltsc2019

# Kubernetes kubelet/kubeproxy installation (via script)
# Official: https://kubernetes.io/docs/setup/production-environment/windows/
$KubeVersion = 'v1.18.0'
curl.exe -Lo "C:\k\kubelet.exe" "https://dl.k8s.io/$KubeVersion/bin/windows/amd64/kubelet.exe"
curl.exe -Lo "C:\k\kubeproxy.exe" "https://dl.k8s.io/$KubeVersion/bin/windows/amd64/kube-proxy.exe"
```

### Host Networking Service (HNS) Improvements
HNS is the Windows networking subsystem underpinning container networking. 2019 improvements include:
- L2Bridge and L2Tunnel modes for Kubernetes pod networking
- DSR (Direct Server Return) for load balancing
- Improved VXLAN support for overlay networks

```powershell
# Inspect HNS networks (replaces older HNSNetwork.psm1 approach)
Get-HNSNetwork
Get-HNSEndpoint

# Create an l2bridge network for Kubernetes
New-HNSNetwork -Type L2Bridge -AddressPrefix '10.244.0.0/24' -Gateway '10.244.0.1' -Name 'CBRNetwork'
```

### Limitations in 2019
- Windows nodes cannot host the Kubernetes control plane (Linux-only).
- Named pipes for container communication are not supported in Kubernetes pods.
- Host process containers (run in host network namespace) require Windows Server 2022.
- HostPath volumes are supported but with Windows path syntax requirements.

---

## 7. Linux Containers on Windows (LCOW)

### Overview
LCOW allows running Linux containers side-by-side with Windows containers on the same Windows Server 2019 Docker host, without requiring a Linux VM or WSL. Uses a minimal Moby LinuxKit VM per container group.

### Architecture
Each Linux container group runs inside a lightweight LinuxKit VM (Hyper-V isolation). The Moby project provides the `lcow` runtime shim. This is distinct from WSL2-based Docker Desktop (which came later and is not available on Server).

### Configuration
```powershell
# Install Hyper-V and Containers roles
Install-WindowsFeature -Name Hyper-V, Containers -IncludeManagementTools -Restart

# Enable experimental features in Docker daemon (required for LCOW in 2019 era)
# Edit C:\ProgramData\docker\config\daemon.json:
@'
{
  "experimental": true
}
'@ | Set-Content 'C:\ProgramData\docker\config\daemon.json'

Restart-Service docker

# Run a Linux container on Windows Server 2019
docker run --platform linux alpine echo "Linux on Windows"

# Run mixed workloads simultaneously
docker run -d --platform linux nginx        # Linux container
docker run -d mcr.microsoft.com/windows/servercore:ltsc2019 ping -t localhost  # Windows container
```

### Limitations
- Requires Hyper-V role (not available on Hyper-V Server bare metal without Hyper-V management role).
- Performance overhead of LinuxKit VM; not appropriate for high-throughput Linux workloads.
- LCOW was superseded by WSL2-backed Docker on Windows 10/11; on Server 2019 it remains the only option.
- GPU passthrough to Linux containers not supported in this model.

---

## 8. Shielded VMs for Linux Guests

### Overview
Shielded VMs (using the Host Guardian Service) were Windows-only in Server 2016. Server 2019 extends shielded VM protection to Linux guest operating systems.

### Supported Linux Guests
- Ubuntu 16.04 and 18.04
- Red Hat Enterprise Linux 7.x
- SUSE Linux Enterprise Server 12 SP3+

### Requirements
- Linux Integration Services (LIS) built into kernel (4.4+ for Ubuntu; shipped with RHEL 7.4+).
- UEFI Secure Boot enabled in VM firmware (Generation 2 VM required).
- VM must use SCSI controller (not IDE).

### Configuration
```powershell
# Create a shielded Linux VM from template disk
# First, prepare the template disk using RHEL/Ubuntu with Secure Boot
# Then shield it:

New-ShieldingDataFile -ShieldingDataFilePath 'C:\Shielding\linux-shielding.pdk' `
    -AdminPasswordHash (ConvertTo-SecureString 'P@ssw0rd' -AsPlainText -Force | Get-PasswordHash) `
    -Policy Shielded `
    -SpecializationDataFilePath 'C:\Shielding\linux-unattend.xml'

# On the guarded host — provision the shielded Linux VM
New-VM -Name 'ShieldedLinux01' -Generation 2 -MemoryStartupBytes 2GB
Set-VMFirmware -VMName 'ShieldedLinux01' -EnableSecureBoot On -SecureBootTemplate 'MicrosoftUEFICertificateAuthority'
```

### Key Considerations
- HGS (Host Guardian Service) infrastructure must be in place; same HGS used for Windows shielded VMs.
- Linux shielding uses the same attestation model (TPM or Admin-trusted) as Windows.
- The shielding data file (.pdk) contains SSH keys or passwords for post-deployment access.

---

## 9. Windows Defender Advanced Threat Protection (ATP)

### Overview
Windows Defender ATP (now Microsoft Defender for Endpoint) EDR capabilities extend to Windows Server 2019 natively, included without a separate agent install requirement. Provides behavioral detection, threat intelligence, and investigation tools.

### Key Capabilities on Server 2019
- Endpoint Detection and Response (EDR) kernel sensor
- Attack Surface Reduction (ASR) rules
- Network protection (block connections to malicious domains)
- Controlled folder access (ransomware protection)
- Integration with Microsoft Security Center portal

### Configuration via PowerShell
```powershell
# Check Defender status
Get-MpComputerStatus | Select-Object AMRunningMode, RealTimeProtectionEnabled, `
    BehaviorMonitorEnabled, IoavProtectionEnabled

# Enable Attack Surface Reduction rules (example: block Office macros spawning child processes)
Add-MpPreference -AttackSurfaceReductionRules_Ids 'd4f940ab-401b-4efc-aadc-ad5f3c50688a' `
    -AttackSurfaceReductionRules_Actions Enabled

# Enable controlled folder access
Set-MpPreference -EnableControlledFolderAccess Enabled

# Enable network protection
Set-MpPreference -EnableNetworkProtection Enabled

# Onboard to Microsoft Defender for Endpoint (requires workspace key from portal)
# Download onboarding script from portal and run:
# WindowsDefenderATPOnboardingScript.cmd

# Verify onboarding status
Get-MpComputerStatus | Select-Object DeviceControlPoliciesLastUpdated, AMProductVersion
```

### Key Considerations
- EDR on Server 2019 requires onboarding to Microsoft Defender for Endpoint portal (license: MDE for Servers or M365 Defender).
- Server 2019 uses the MMA (Microsoft Monitoring Agent) OR the new unified agent depending on onboarding method.
- ASR rules in Audit mode generate events without blocking — use Audit first in production.

### Pitfalls
- Controlled folder access blocks legitimate apps not in the allowed list — requires application allow-listing before enabling.
- Network protection requires Windows Defender Antivirus to be the primary AV; conflicts with third-party AV.

---

## 10. Encrypted Networks (SDN)

### Overview
Software-Defined Networking in Windows Server 2019 Datacenter gains the ability to encrypt east-west VM-to-VM traffic on the same virtual subnet without modifying applications. Uses certificates and DTLS encryption at the HNV (Hyper-V Network Virtualization) layer.

### Requirements
- Datacenter edition only
- Network Controller (SDN stack) deployed
- Certificates provisioned on each Hyper-V host

### Configuration
```powershell
# Enable encryption on a virtual network subnet (via SDN REST API / NC cmdlets)
# Requires SDN Network Controller and the NetworkControllerHyperv PS module

# Mark a virtual subnet as encryption-required
$vnet = Get-NetworkControllerVirtualNetwork -ConnectionUri $ncUri -ResourceId 'TenantVNet'
$subnet = $vnet.Properties.Subnets | Where-Object ResourceId -eq 'WebTier'
$subnet.Properties.EncryptionCredential = @{
    ResourceRef = "/credentials/EncryptionCert"
}
New-NetworkControllerVirtualNetwork -ConnectionUri $ncUri -ResourceId 'TenantVNet' `
    -Properties $vnet.Properties

# Traffic between VMs on the encrypted subnet is automatically DTLS-encrypted
# VMs require no application changes
```

### Key Considerations
- Encryption applies to traffic leaving the VM's vNIC; intra-VM traffic is not encrypted.
- Certificate rotation must be planned — expired certs cause traffic drops between VMs.
- Only available with full SDN stack (Network Controller, SLB/MUX); not available in standalone Hyper-V.

---

## 11. OpenSSH Built-in

### Overview
OpenSSH client and server are available as Windows Optional Features in Server 2019 (previously required manual installation from GitHub releases). This enables native SSH access to Windows servers without third-party tools.

### Installation
```powershell
# Install OpenSSH client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Install OpenSSH server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Start and set to automatic
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Confirm firewall rule was created by installer
Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' | Select-Object Name, Enabled, Direction
```

### sshd Configuration
The configuration file is at `C:\ProgramData\ssh\sshd_config`.
```powershell
# Key sshd_config settings for Windows Server
# Default shell — set to PowerShell
Add-Content 'C:\ProgramData\ssh\sshd_config' 'Match All'
Add-Content 'C:\ProgramData\ssh\sshd_config' '    DefaultShell C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

# Or set default shell via registry
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
    -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' `
    -PropertyType String -Force
```

### Key-Based Authentication
```powershell
# Generate key pair on client
ssh-keygen -t ed25519 -C "admin@contoso.com"

# Copy public key to server
# For standard users: %USERPROFILE%\.ssh\authorized_keys
# For administrators: C:\ProgramData\ssh\administrators_authorized_keys

# Set correct ACL on administrators_authorized_keys (SYSTEM and Administrators only)
$acl = Get-Acl 'C:\ProgramData\ssh\administrators_authorized_keys'
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule('SYSTEM','FullControl','Allow')
$acl.AddAccessRule($rule)
$rule2 = New-Object System.Security.AccessControl.FileSystemAccessRule('Administrators','FullControl','Allow')
$acl.AddAccessRule($rule2)
Set-Acl 'C:\ProgramData\ssh\administrators_authorized_keys' $acl

# Restart sshd after changes
Restart-Service sshd
```

### Pitfalls
- The `administrators_authorized_keys` file has strict ACL requirements; wrong permissions silently disable key auth for admin accounts.
- Default shell is `cmd.exe` unless explicitly changed; most users expect PowerShell.
- SSH subsystem for SFTP is enabled by default (`Subsystem sftp sftp-server.exe` in sshd_config) — disable if not needed.

---

## 12. Precision Time Protocol (PTP) and Leap Second Support

### Overview
Windows Server 2019 adds support for Precision Time Protocol (PTP / IEEE 1588-2008), enabling sub-millisecond time accuracy — critical for financial, industrial, and telecom workloads. Also adds Leap Second awareness.

### PTP Configuration
```powershell
# Check Windows Time service (W32tm) status
w32tm /query /status
w32tm /query /configuration

# Enable PTP hardware timestamping (requires PTP-capable NIC)
# PTP is exposed through the Windows Time provider architecture
# Third-party PTP providers (e.g., Meinberg, Spectralink) install as W32tm providers

# Configure W32tm for high accuracy (stratum 1 source)
w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /reliable:YES /update
Restart-Service w32tm

# Verify time accuracy
w32tm /stripchart /computer:time.windows.com /samples:5 /dataonly
```

### Leap Second Support
2019 natively handles leap second insertion without system clock jumps. The system receives leap second notification from the time source and handles it correctly for applications using GetSystemTime APIs.

```powershell
# Check leap second support status
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config' | Select-Object LeapSecondCorrection
```

### Key Considerations
- PTP accuracy below 1 ms requires PTP-aware NIC hardware; software-only PTP achieves 1-10 ms.
- Hyper-V VMs time sync: 2019 VMs on 2019 Hyper-V hosts can participate in PTP if the host is accurate.
- Leap second support requires no special configuration — it is automatic when announced by the time source.

---

## 13. HTTP/2 in IIS 10.0

### Overview
IIS 10.0 on Windows Server 2019 enables HTTP/2 by default for all HTTPS sites. HTTP/2 provides multiplexing, header compression (HPACK), and server push — reducing latency for web workloads.

### Behavior
```powershell
# Verify HTTP/2 is enabled (it is by default for HTTPS)
# Check via netsh
netsh http show global

# HTTP/2 requires TLS 1.2 minimum; ensure cipher suites support it
Get-TlsCipherSuite | Where-Object Name -like '*GCM*' | Select-Object Name

# Disable HTTP/2 if needed (per-application pool or global)
# Global disable via registry:
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters' `
    -Name 'EnableHttp2Cleartext' -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\HTTP\Parameters' `
    -Name 'EnableHttp2Tls' -Value 0 -PropertyType DWORD -Force
Restart-Service W3SVC

# Test HTTP/2 negotiation (curl shows HTTP/2)
curl -I --http2 https://localhost/
```

### Key Considerations
- HTTP/2 requires HTTPS; HTTP/1.1 is used for plain HTTP connections.
- Server Push (H2 push) requires explicit application code to send Link headers.
- Load balancers in front of IIS must support HTTP/2 pass-through or terminate and re-establish.

---

## 14. Diagnostic Scripts

---

### Script: 11-container-health.ps1

```powershell
<#
.SYNOPSIS
    Windows Server 2019 - Container Health and Runtime Diagnostics
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region ── Section 1: Docker Engine Status ──────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 1 — Docker Engine Status"
Write-Host $sep

$dockerSvc = Get-Service -Name docker -ErrorAction SilentlyContinue
if (-not $dockerSvc) {
    Write-Warning "Docker service not found. Install Docker via Install-WindowsFeature Containers."
} else {
    [PSCustomObject]@{
        ServiceName  = $dockerSvc.Name
        Status       = $dockerSvc.Status
        StartType    = $dockerSvc.StartType
    } | Format-List

    if ($dockerSvc.Status -eq 'Running') {
        # Docker version info
        docker version --format '{{json .}}' 2>$null | ConvertFrom-Json |
            Select-Object @{N='ClientVersion';E={$_.Client.Version}},
                          @{N='ServerVersion';E={$_.Server.Components[0].Details.ApiVersion}},
                          @{N='OS/Arch';E={$_.Server.Os + '/' + $_.Server.Arch}} |
            Format-List
    }
}
#endregion

#region ── Section 2: Running Containers ────────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 2 — Running Containers"
Write-Host $sep

try {
    $containers = docker ps --format '{{json .}}' 2>$null |
        ForEach-Object { $_ | ConvertFrom-Json }

    if ($containers) {
        $containers | Select-Object ID, Image, Status, Names, Ports | Format-Table -AutoSize
        Write-Host "Total running: $($containers.Count)"
    } else {
        Write-Host "No containers currently running."
    }
} catch {
    Write-Warning "Could not enumerate containers: $_"
}
#endregion

#region ── Section 3: Container Images ──────────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 3 — Local Container Images"
Write-Host $sep

try {
    docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}' 2>$null
} catch {
    Write-Warning "Could not list images: $_"
}
#endregion

#region ── Section 4: Windows Container Network (HNS) ───────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 4 — Host Networking Service (HNS) Networks"
Write-Host $sep

try {
    $hnsNetworks = Get-HNSNetwork -ErrorAction Stop
    $hnsNetworks | Select-Object Name, Type, AddressPrefix, Id | Format-Table -AutoSize
} catch {
    Write-Warning "HNS module not available or HNS not running: $_"
}
#endregion

#region ── Section 5: LCOW (Linux Containers on Windows) Check ──────────────
Write-Host "`n$sep"
Write-Host " SECTION 5 — LCOW Availability Check"
Write-Host $sep

$daemonConfig = 'C:\ProgramData\docker\config\daemon.json'
if (Test-Path $daemonConfig) {
    $config = Get-Content $daemonConfig -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        ExperimentalEnabled = if ($config.experimental) { $config.experimental } else { $false }
        DaemonConfigPath    = $daemonConfig
    } | Format-List
} else {
    Write-Host "daemon.json not found — LCOW experimental mode likely not configured."
}

$hyperVSvc = Get-Service -Name vmms -ErrorAction SilentlyContinue
[PSCustomObject]@{
    HyperVServicePresent = ($null -ne $hyperVSvc)
    HyperVServiceStatus  = if ($hyperVSvc) { $hyperVSvc.Status } else { 'N/A' }
} | Format-List
#endregion

#region ── Section 6: Kubernetes Node Components ────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 6 — Kubernetes Node Components (if present)"
Write-Host $sep

$k8sComponents = @('kubelet', 'kube-proxy', 'containerd', 'flannel')
foreach ($component in $k8sComponents) {
    $svc = Get-Service -Name $component -ErrorAction SilentlyContinue
    $exe = Get-Command "$component.exe" -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Component = $component
        Service   = if ($svc) { $svc.Status } else { 'Not installed' }
        Executable= if ($exe) { $exe.Source } else { 'Not found in PATH' }
    }
} | Format-Table -AutoSize
#endregion

#region ── Section 7: Container Storage and Disk Usage ──────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 7 — Docker Disk Usage"
Write-Host $sep

try {
    docker system df 2>$null
} catch {
    Write-Warning "Could not retrieve docker disk usage: $_"
}
#endregion

#region ── Section 8: Recent Container Events ───────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 8 — Recent Docker Events (last 50 from Windows Event Log)"
Write-Host $sep

Get-WinEvent -LogName 'Microsoft-Windows-Containers-CCG/Admin' -MaxEvents 10 -ErrorAction SilentlyContinue |
    Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-List

# Also check Application log for docker entries
Get-WinEvent -LogName Application -MaxEvents 100 -ErrorAction SilentlyContinue |
    Where-Object ProviderName -like '*docker*' |
    Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
    Format-List
#endregion
```

---

### Script: 12-system-insights.ps1

```powershell
<#
.SYNOPSIS
    Windows Server 2019 - System Insights Capability Status and Predictions
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region ── Section 1: Feature Installation Check ────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 1 — System Insights Feature Status"
Write-Host $sep

$feature = Get-WindowsFeature -Name System-Insights -ErrorAction SilentlyContinue
if (-not $feature) {
    Write-Warning "System-Insights feature not found. Run: Install-WindowsFeature -Name System-Insights -IncludeManagementTools"
    exit 1
}

[PSCustomObject]@{
    FeatureName    = $feature.Name
    DisplayName    = $feature.DisplayName
    InstallState   = $feature.InstallState
    SubFeatures    = ($feature.SubFeatures -join ', ')
} | Format-List
#endregion

#region ── Section 2: All Capabilities Overview ─────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 2 — Installed Capabilities"
Write-Host $sep

try {
    $capabilities = Get-InsightsCapability -ErrorAction Stop
    $capabilities | Select-Object Name, Enabled, Description | Format-Table -AutoSize -Wrap
    Write-Host "Total capabilities: $($capabilities.Count)"
} catch {
    Write-Warning "Cannot retrieve capabilities — is System-Insights installed? Error: $_"
    exit 1
}
#endregion

#region ── Section 3: Capability Results (Latest Predictions) ───────────────
Write-Host "`n$sep"
Write-Host " SECTION 3 — Latest Prediction Results per Capability"
Write-Host $sep

foreach ($cap in $capabilities) {
    Write-Host "`n-- $($cap.Name) --"
    try {
        $result = Get-InsightsCapabilityResult -Name $cap.Name -ErrorAction Stop
        if ($result) {
            [PSCustomObject]@{
                Status        = $result.Status
                Description   = $result.Description
                Timestamp     = $result.Timestamp
                Data          = ($result.Data | ConvertTo-Json -Compress -ErrorAction SilentlyContinue)
            } | Format-List
        } else {
            Write-Host "   No results yet (requires 30+ days of data for initial prediction)."
        }
    } catch {
        Write-Warning "   Could not retrieve result: $_"
    }
}
#endregion

#region ── Section 4: Prediction Schedules ──────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 4 — Prediction Schedules"
Write-Host $sep

foreach ($cap in $capabilities) {
    try {
        $schedule = Get-InsightsCapabilitySchedule -Name $cap.Name -ErrorAction Stop
        [PSCustomObject]@{
            Capability   = $cap.Name
            ScheduleType = $schedule.Type
            DayOfWeek    = $schedule.DayOfWeek
            Time         = $schedule.Time
        }
    } catch {
        [PSCustomObject]@{
            Capability   = $cap.Name
            ScheduleType = 'Error retrieving schedule'
            DayOfWeek    = 'N/A'
            Time         = 'N/A'
        }
    }
} | Format-Table -AutoSize
#endregion

#region ── Section 5: Remediation Actions ───────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 5 — Configured Remediation Actions"
Write-Host $sep

foreach ($cap in $capabilities) {
    try {
        $actions = Get-InsightsCapabilityAction -Name $cap.Name -ErrorAction Stop
        if ($actions) {
            Write-Host "`n-- $($cap.Name) --"
            $actions | Select-Object Type, ScriptPath, Enabled | Format-Table -AutoSize
        }
    } catch {
        # No actions configured is normal — silently skip
    }
}

$hasActions = $capabilities | ForEach-Object {
    Get-InsightsCapabilityAction -Name $_.Name -ErrorAction SilentlyContinue
} | Where-Object { $_ }

if (-not $hasActions) {
    Write-Host "No remediation actions configured on any capability."
}
#endregion

#region ── Section 6: On-Demand Invocation Status ───────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 6 — Last Manual Invocation Times"
Write-Host $sep

# System Insights logs invocations to the event log
$logName = 'Microsoft-Windows-SystemInsights/Operational'
try {
    $events = Get-WinEvent -LogName $logName -MaxEvents 50 -ErrorAction Stop |
        Where-Object Id -in @(1, 2, 3, 100, 101)

    if ($events) {
        $events | Select-Object TimeCreated, Id, LevelDisplayName, Message |
            Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No System Insights events found in operational log."
    }
} catch {
    Write-Warning "Cannot read System Insights event log: $_"
}
#endregion

#region ── Section 7: Data Collection Health ────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 7 — Performance Counter Data Collection"
Write-Host $sep

# System Insights relies on Performance Logs & Alerts (pla) service
$plaSvc = Get-Service -Name pla -ErrorAction SilentlyContinue
[PSCustomObject]@{
    ServiceName  = 'Performance Logs & Alerts (pla)'
    Status       = if ($plaSvc) { $plaSvc.Status } else { 'Not found' }
    StartType    = if ($plaSvc) { $plaSvc.StartType } else { 'N/A' }
} | Format-List

# Check that System Insights data collectors exist
$collectors = Get-WmiObject -Namespace root\cimv2 -Class Win32_PerfRawData_PerfOS_System -ErrorAction SilentlyContinue
Write-Host "Performance data accessible: $(if ($collectors) { 'Yes' } else { 'No — check PLA service' })"
#endregion
```

---

### Script: 13-storage-migration.ps1

```powershell
<#
.SYNOPSIS
    Windows Server 2019 - Storage Migration Service Job Status and Progress
.NOTES
    Version : 2019.1.0
    Targets : Windows Server 2019+
    Safety  : Read-only. No modifications to system configuration.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$sep = '=' * 70

#region ── Section 1: SMS Feature and Service Status ────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 1 — Storage Migration Service Feature Status"
Write-Host $sep

$feature = Get-WindowsFeature -Name SMS -ErrorAction SilentlyContinue
[PSCustomObject]@{
    FeatureName  = 'SMS (Orchestrator)'
    InstallState = if ($feature) { $feature.InstallState } else { 'Not found' }
} | Format-List

$proxyFeature = Get-WindowsFeature -Name SMS-Proxy -ErrorAction SilentlyContinue
[PSCustomObject]@{
    FeatureName  = 'SMS-Proxy'
    InstallState = if ($proxyFeature) { $proxyFeature.InstallState } else { 'Not found' }
} | Format-List

$smsSvc = Get-Service -Name SMS -ErrorAction SilentlyContinue
[PSCustomObject]@{
    ServiceName = 'SMS Service'
    Status      = if ($smsSvc) { $smsSvc.Status } else { 'Not found' }
    StartType   = if ($smsSvc) { $smsSvc.StartType } else { 'N/A' }
} | Format-List
#endregion

#region ── Section 2: All Migration Jobs ────────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 2 — All Migration Jobs"
Write-Host $sep

try {
    Import-Module StorageMigrationService -ErrorAction Stop

    $jobs = Get-SmsJob -ErrorAction Stop
    if ($jobs) {
        $jobs | Select-Object Name, State, Description,
            @{N='CreatedTime';E={$_.CreatedTime}},
            @{N='ModifiedTime';E={$_.ModifiedTime}} |
            Format-Table -AutoSize
        Write-Host "Total jobs: $($jobs.Count)"
    } else {
        Write-Host "No migration jobs found."
    }
} catch [System.IO.FileNotFoundException] {
    Write-Warning "StorageMigrationService module not found. Install: Install-WindowsFeature -Name SMS -IncludeManagementTools"
    exit 1
} catch {
    Write-Warning "Error retrieving SMS jobs: $_"
    exit 1
}
#endregion

#region ── Section 3: Per-Job Detailed Status ───────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 3 — Job Detail and Phase Status"
Write-Host $sep

if ($jobs) {
    foreach ($job in $jobs) {
        Write-Host "`n========== Job: $($job.Name) =========="
        Write-Host "  State       : $($job.State)"
        Write-Host "  Description : $($job.Description)"

        # Inventory phase status
        Write-Host "`n  [Inventory Phase]"
        try {
            $inv = Get-SmsSourceServer -JobName $job.Name -ErrorAction Stop
            $inv | Select-Object ComputerName, InventoryStatus, ShareCount, FileCount,
                @{N='TotalSizeGB';E={[math]::Round($_.TotalBytes/1GB,2)}} |
                Format-Table -AutoSize
        } catch {
            Write-Warning "  Could not retrieve inventory data: $_"
        }

        # Transfer phase status
        Write-Host "`n  [Transfer Phase]"
        try {
            $progress = Get-SmsTransferProgress -JobName $job.Name -ErrorAction Stop
            if ($progress) {
                $progress | Select-Object SourceComputerName, DestinationComputerName,
                    State, PercentComplete,
                    @{N='TransferredGB';E={[math]::Round($_.BytesTransferred/1GB,2)}},
                    @{N='TotalGB';E={[math]::Round($_.TotalBytes/1GB,2)}},
                    @{N='RemainingGB';E={[math]::Round($_.BytesRemaining/1GB,2)}},
                    StartTime, EstimatedCompletionTime |
                    Format-List
            } else {
                Write-Host "  No transfer data (transfer phase not started or complete)."
            }
        } catch {
            Write-Warning "  Could not retrieve transfer progress: $_"
        }
    }
}
#endregion

#region ── Section 4: Per-Job Share Transfer Detail ─────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 4 — Share-Level Transfer Detail"
Write-Host $sep

if ($jobs) {
    foreach ($job in $jobs) {
        Write-Host "`n-- Job: $($job.Name) --"
        try {
            $shares = Get-SmsShare -JobName $job.Name -ErrorAction Stop
            if ($shares) {
                $shares | Select-Object ShareName, SourcePath, DestinationPath,
                    TransferStatus,
                    @{N='TransferredGB';E={[math]::Round($_.BytesTransferred/1GB,2)}},
                    @{N='TotalGB';E={[math]::Round($_.TotalBytes/1GB,2)}},
                    ErrorMessage |
                    Format-Table -AutoSize
            } else {
                Write-Host "  No share data available."
            }
        } catch {
            Write-Warning "  Could not retrieve share detail: $_"
        }
    }
}
#endregion

#region ── Section 5: Cutover History ───────────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 5 — Cutover Status"
Write-Host $sep

if ($jobs) {
    foreach ($job in $jobs) {
        Write-Host "`n-- Job: $($job.Name) --"
        try {
            $cutover = Get-SmsCutoverStatus -JobName $job.Name -ErrorAction Stop
            if ($cutover) {
                $cutover | Select-Object SourceComputerName, DestinationComputerName,
                    CutoverStatus, StartTime, EndTime,
                    IdentityTransferred, SPNTransferred, IPAddressTransferred |
                    Format-List
            } else {
                Write-Host "  Cutover not initiated for this job."
            }
        } catch {
            # Get-SmsCutoverStatus may not exist on all patch levels
            Write-Host "  Cutover status cmdlet not available on this build."
        }
    }
}
#endregion

#region ── Section 6: SMS Event Log ─────────────────────────────────────────
Write-Host "`n$sep"
Write-Host " SECTION 6 — Storage Migration Service Events (Last 25)"
Write-Host $sep

$smsLogName = 'Microsoft-Windows-StorageMigrationService/Admin'
try {
    $events = Get-WinEvent -LogName $smsLogName -MaxEvents 25 -ErrorAction Stop
    $events | Select-Object TimeCreated, Id, LevelDisplayName,
        @{N='Message';E={$_.Message.Substring(0,[Math]::Min(120,$_.Message.Length))}} |
        Format-Table -AutoSize -Wrap
} catch {
    # Try operational log as fallback
    try {
        $events = Get-WinEvent -LogName 'Microsoft-Windows-StorageMigrationService/Operational' `
            -MaxEvents 25 -ErrorAction Stop
        $events | Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize -Wrap
    } catch {
        Write-Warning "Could not read SMS event logs: $_"
    }
}
#endregion

#region ── Section 7: Firewall and Connectivity Prerequisites ───────────────
Write-Host "`n$sep"
Write-Host " SECTION 7 — SMS Firewall Rules"
Write-Host $sep

$smsRules = Get-NetFirewallRule -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like '*Storage Migration*' -or $_.DisplayName -like '*SMS*' }

if ($smsRules) {
    $smsRules | Select-Object DisplayName, Enabled, Direction, Action | Format-Table -AutoSize
} else {
    Write-Warning "No SMS-specific firewall rules found. Verify TCP 28940 and SMB (445) are open."
}

# Check WMI availability (needed for proxy push to source)
$wmiSvc = Get-Service -Name Winmgmt -ErrorAction SilentlyContinue
[PSCustomObject]@{
    WMIService     = 'Windows Management Instrumentation'
    Status         = if ($wmiSvc) { $wmiSvc.Status } else { 'Not found' }
} | Format-List
#endregion
```

---

## 15. Summary Reference

| Feature | Edition | Key Cmdlet / Tool |
|---|---|---|
| Windows Admin Center | All | `msiexec` install; WAC UI |
| System Insights | All | `Get-InsightsCapability`, `Invoke-InsightsCapability` |
| Storage Migration Service | All | `New-SmsJob`, `Start-SmsTransfer` |
| S2D + PMEM | Datacenter | `Get-PmemDisk`, `Enable-ClusterStorageSpacesDirect` |
| S2D Dedup on ReFS | Datacenter | `Enable-DedupVolume` |
| Storage Replica (Standard) | Standard + Datacenter | `New-SRPartnership` |
| Kubernetes Windows Nodes | All (Containers role) | `kubelet`, HNS cmdlets |
| LCOW | All + Hyper-V role | `docker run --platform linux` |
| Shielded VMs (Linux) | Datacenter | `New-ShieldingDataFile` |
| Windows Defender ATP | All | `Set-MpPreference`, portal onboarding |
| Encrypted Networks (SDN) | Datacenter | Network Controller REST API |
| OpenSSH Built-in | All | `Add-WindowsCapability` |
| PTP / Leap Second | All | `w32tm` |
| HTTP/2 (IIS) | All | Default-on; netsh http |
