# Windows Server 2016 — Version-Specific Research

**Support status:** Extended Support ends January 2027. Nearing end-of-life; plan migrations to 2019 or 2022.
**Version number:** 10.0.14393 (same kernel as Windows 10 Anniversary Update)
**This document covers only features NEW or significantly changed in Windows Server 2016.**

---

## 1. Nano Server

Nano Server was Windows Server 2016's most radical deployment option: a minimal-footprint, headless OS with no local logon, no 32-bit support, and roughly 400 MB disk footprint vs 4+ GB for Core.

### Architecture
- No GUI, no WoW64, no MSI installer support
- Management: PowerShell remoting, WMI over WSMAN, Emergency Management Console only
- Deployed via VHD/VHDX image built with `New-NanoServerImage` cmdlet
- Supported roles: Hyper-V, DNS Server, IIS (via IIS package), Failover Clustering, WSFC node
- Did NOT support: Active Directory DS, Group Policy client (full), many traditional Windows roles

### Image Creation (2016 approach)
```powershell
# Mount the WS2016 ISO, then:
Import-Module D:\NanoServer\NanoServerImageGenerator\NanoServerImageGenerator.psm1

New-NanoServerImage `
    -MediaPath D:\ `
    -BasePath C:\NanoBase `
    -TargetPath C:\NanoServer\NanoVM.vhdx `
    -DeploymentType Guest `
    -Edition Datacenter `
    -ComputerName NANO01 `
    -Packages Microsoft-NanoServer-IIS-Package, `
               Microsoft-NanoServer-DNS-Package `
    -DomainName corp.contoso.com `
    -EnableRemoteManagementPort
```

### Key Considerations
- Image built OFFLINE using NanoServerImageGenerator; no in-place package install post-deployment
- Manage via `Enter-PSSession -ComputerName NANO01` or Nano Server Recovery Console
- Event logs accessible remotely via `Get-WinEvent -ComputerName NANO01`
- **Important:** In Windows Server 2019, Nano Server was demoted to a container base image ONLY. It no longer functions as a host OS. Any 2016 Nano deployments must be migrated before 2019+ adoption.

### Common Pitfalls
- Applications requiring 32-bit DLLs, MSI, or .NET Framework 3.5 will not run on Nano
- WMI namespace availability is reduced; test all management scripts against Nano explicitly
- Domain join via `djoin.exe /provision` offline blob; OOBE domain join not supported

---

## 2. Windows Containers (First Native Container Support)

Windows Server 2016 introduced native container support, the first Windows Server version to do so. Docker Engine for Windows is installed as a Windows feature.

### Container Isolation Modes
| Mode | Kernel | Use Case |
|---|---|---|
| Windows Server Containers | Shared host kernel | High-density, trusted workloads |
| Hyper-V Containers | Dedicated lightweight VM kernel | Tenant isolation, untrusted code |

Hyper-V Containers use a minimal VM ("utility VM") per container for kernel isolation. The container image is identical; only the `--isolation=hyperv` flag differs.

### Installation
```powershell
# Install Docker and Containers feature
Install-WindowsFeature -Name Containers -Restart

# Install Docker Engine (2016 method via OneGet/PackageManagement)
Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider
Restart-Computer -Force

# Post-restart verification
docker version
docker info
```

### Base Images (2016 era)
- `microsoft/windowsservercore` — Full Win32 compatibility, ~5 GB compressed
- `microsoft/nanoserver` — Minimal, ~400 MB, PowerShell-only

```powershell
# Pull base images
docker pull microsoft/windowsservercore:ltsc2016
docker pull microsoft/nanoserver:sac2016

# Run a Windows Server Core container
docker run -it microsoft/windowsservercore cmd

# Run with Hyper-V isolation
docker run -it --isolation=hyperv microsoft/windowsservercore cmd
```

### Networking Modes
- `nat` — Default; NAT'd network, containers get private IPs
- `transparent` — Container connects directly to physical network
- `overlay` — Docker Swarm multi-host networking (requires Swarm)
- `l2bridge` / `l2tunnel` — For integration with HNV/SDN stack

### Key Considerations
- Container host and container image OS versions must match for Windows Server Containers (kernel share); Hyper-V isolation relaxes this
- Docker Swarm supported for orchestration in 2016; Kubernetes on Windows matured later (2019+)
- Persistent storage via volume mounts: `docker run -v C:\data:C:\app\data ...`
- Windows containers cannot run Linux images and vice versa on a single host without Linux subsystem

### Common Pitfalls
- `winrm` and some WMI providers not available inside containers by default
- Container image layer caching on Windows is slower than Linux; large base images increase pull times significantly
- Running containers as Local System (default) is a security concern in multi-tenant environments; use user namespaces carefully

---

## 3. Shielded VMs and Host Guardian Service (HGS)

Shielded VMs protect Hyper-V guest VMs from compromised fabric admins. The VHDX is BitLocker-encrypted and can only start on attested, healthy hosts. **Datacenter edition only.**

### Guarded Fabric Architecture
```
Tenant VM (Shielded) -- VHDX encrypted with BitLocker
    |
    v
HGS (Host Guardian Service) -- Issues Key Protector
    |
    v
Guarded Host (Hyper-V) -- Must pass attestation before receiving VM keys
```

### Attestation Modes
| Mode | Description | Security Level |
|---|---|---|
| TPM-trusted attestation | Uses TPM 2.0 chip + Secure Boot + measured boot | Highest |
| Admin-trusted attestation | Host must be member of specific AD security group | Medium (deprecated path) |
| Host Key attestation | Asymmetric key pair per host | Medium (added update) |

### HGS Setup (Datacenter only)
```powershell
# On dedicated HGS server:
Install-WindowsFeature -Name HostGuardianServiceRole -IncludeManagementTools

# Initialize HGS (new AD forest recommended)
Install-HgsServer -HgsDomainName 'bastion.local' -SafeModeAdministratorPassword (Read-Host -AsSecureString)

# Configure attestation mode
Initialize-HgsAttestation -TpmTrustedAttestation

# Configure key protection
Initialize-HgsKeyProtection -NoCertificateRequests
```

### VM Shielding Process
```powershell
# On guarded host: create shielding data file (PDK)
# Owner certificate required (from HGS or self-signed for lab)

# Convert existing VM to shielded (requires Gen2 VM + UEFI + Secure Boot)
# 1. Prepare shielding data file with owner cert, RDP cert, unattend.xml
# 2. New-ShieldedVM or provision via SCVMM/WAC

# Check shielded VM state
Get-VM -Name ShieldedVM01 | Select-Object Name, State, Generation
(Get-VM -Name ShieldedVM01).SecurityProfile
```

### Key Considerations
- Requires Generation 2 VMs with UEFI Secure Boot enabled
- BitLocker encrypts the VHDX; keys released by HGS only after successful attestation
- Shielded VMs block console access via VMConnect (by design)
- HGS should run on dedicated, separate hardware from Hyper-V hosts
- TPM attestation requires TPM 2.0 on all guarded hosts

### Common Pitfalls
- Admin-trusted attestation is considered weak; Microsoft deprecated it post-2016
- HGS AD forest isolation is critical — compromise of HGS = compromise of all shielded VMs
- vTPM state is stored in VHDX; losing the key protector = permanent data loss

---

## 4. Storage Spaces Direct (S2D)

S2D enables software-defined, hyperconverged storage using local disks across cluster nodes. No shared SAS required. **Datacenter edition only; minimum 4 nodes for production.**

### Architecture Stack
```
Applications / Hyper-V VMs
        |
Cluster Shared Volumes (CSV)
        |
Virtual Disks (Storage Spaces)
        |
Storage Pool (S2D Pool)
        |
Physical Disks (NVMe / SSD / HDD per node)
```

### Cache and Capacity Tiers
- NVMe or SSD disks auto-assigned as **cache** tier (write-back cache by default)
- HDD disks auto-assigned as **capacity** tier
- All-flash: fastest NVMe = cache, slower SSD = capacity
- Cache is per-server, not shared

### Enable S2D
```powershell
# Prerequisites: clean disks, no existing pools, Hyper-V + Failover Clustering installed
# Run on all nodes first:
Install-WindowsFeature -Name Hyper-V, Failover-Clustering, Data-Center-Bridging `
    -IncludeManagementTools -Restart

# Create the cluster first (run from one node or management machine):
New-Cluster -Name S2DCluster -Node Node1,Node2,Node3,Node4 -NoStorage

# Enable S2D on the cluster:
Enable-ClusterStorageSpacesDirect -CimSession S2DCluster

# Check pool was created:
Get-StoragePool -CimSession S2DCluster | Where StoragePoolFriendlyName -like 'S2D*'
```

### Create Volumes
```powershell
# Two-way mirror (2 node minimum, survives 1 failure):
New-Volume -StoragePoolFriendlyName 'S2D on S2DCluster' `
           -FriendlyName VM-Vol-01 `
           -FileSystem CSVFS_ReFS `
           -ResiliencySettingName Mirror `
           -Size 2TB

# Three-way mirror (3+ nodes, survives 2 failures):
New-Volume -StoragePoolFriendlyName 'S2D on S2DCluster' `
           -FriendlyName VM-Vol-Mirror3 `
           -FileSystem CSVFS_ReFS `
           -ResiliencySettingName Mirror `
           -PhysicalDiskRedundancy 2 `
           -Size 4TB

# Parity (5+ nodes recommended, better capacity efficiency):
New-Volume -StoragePoolFriendlyName 'S2D on S2DCluster' `
           -FriendlyName VM-Vol-Parity `
           -FileSystem CSVFS_ReFS `
           -ResiliencySettingName Parity `
           -Size 8TB
```

### Fault Domain Awareness
```powershell
# S2D is fault-domain aware (rack, chassis, server)
# Verify fault domains:
Get-StorageFaultDomain -CimSession S2DCluster

# Check health:
Get-StorageSubSystem -CimSession S2DCluster | Get-StorageHealthReport
Get-PhysicalDisk -CimSession S2DCluster | Select FriendlyName, Size, MediaType, HealthStatus, Usage
```

### Key Considerations
- ReFS is the recommended file system for S2D volumes (CSVFS_ReFS); provides integrity streams and faster repair
- Cache device ratio: 1 cache device per 3-4 capacity devices is a common starting point
- S2D uses SMB Direct (RDMA) if NICs support it; configure Data Center Bridging (DCB) for lossless fabric
- **Minimum 4 nodes** for production parity volumes; 2-node mirror supported for ROBO scenarios

### Common Pitfalls
- Mixed disk types within cache tier or capacity tier cause unpredictable performance
- Do not add non-S2D storage pools to the same cluster
- Firmware consistency across all drives in the pool is critical
- ReFS on S2D does not support deduplication in Server 2016 (dedup on ReFS added later)

---

## 5. Storage Replica

Storage Replica provides kernel-level, block-level replication — synchronous or asynchronous. **Datacenter edition only in 2016** (Standard got limited SR in 2019).

### Replication Modes
| Mode | Description | RPO |
|---|---|---|
| Synchronous | Write acknowledged only after both sites confirm | RPO = 0 |
| Asynchronous | Write acknowledged at source, async replication | RPO > 0 (latency-dependent) |

### Topology Options
- **Server-to-server:** Two standalone servers, dedicated log and data volumes
- **Cluster-to-cluster:** Two WSFC clusters, site-to-site DR
- **Stretch cluster:** Single cluster spanning two sites (automatic failover)

### Setup (Server-to-Server)
```powershell
# Install on both servers:
Install-WindowsFeature -Name Storage-Replica -IncludeManagementTools -Restart

# Test prerequisites (run from management station):
Test-SRTopology -SourceComputerName SRV-A `
                -SourceVolumeName E: `
                -SourceLogVolumeName F: `
                -DestinationComputerName SRV-B `
                -DestinationVolumeName E: `
                -DestinationLogVolumeName F: `
                -DurationInMinutes 30 `
                -ResultPath C:\SRTest

# Create replication partnership:
New-SRPartnership -SourceComputerName SRV-A `
                  -SourceRGName SRV-A-RG `
                  -SourceVolumeName E: `
                  -SourceLogVolumeName F: `
                  -DestinationComputerName SRV-B `
                  -DestinationRGName SRV-B-RG `
                  -DestinationVolumeName E: `
                  -DestinationLogVolumeName F: `
                  -LogSizeMinimum 8GB `
                  -ReplicationMode Synchronous
```

### Monitoring
```powershell
# Check replication group status:
Get-SRGroup -ComputerName SRV-A
Get-SRGroup -ComputerName SRV-B

# Check partnership:
Get-SRPartnership -ComputerName SRV-A

# Detailed replication statistics:
(Get-SRGroup -ComputerName SRV-B -Name SRV-B-RG).Replicas | 
    Select-Object NumOfBytesRemaining, ReplicationStatus, LastInSyncTime
```

### Key Considerations
- Destination volume is inaccessible (raw) during replication — this is by design
- Log volume should be on fast storage (SSD/NVMe); under-sized logs cause replication lag
- Synchronous mode adds write latency equal to round-trip network time; suitable for <5ms RTT links
- SR does not replicate permissions, VSS snapshots, or DFS namespace configurations

### Common Pitfalls
- Forgetting to size the log volume adequately (minimum 8 GB; larger for high-write workloads)
- Attempting to access the destination volume — SR keeps it locked
- Using SR with volumes that also host page files or other OS files
- Not running `Test-SRTopology` before production setup

---

## 6. Nested Virtualization

Nested Virtualization allows running Hyper-V inside a Hyper-V VM. Introduced in Windows Server 2016 (requires Hyper-V host also running 2016+).

### Requirements
- Host: Windows Server 2016 or Windows 10 Anniversary Update
- Guest VM: Generation 1 or 2, must be powered off before enabling
- Guest OS: Windows Server 2016 / Windows 10 Anniversary Update
- Processor: Intel VT-x/EPT required; AMD not supported in 2016 (AMD support added 2019+)
- Minimum 4 GB RAM for nested Hyper-V guest (8 GB recommended)

### Configuration
```powershell
# On Hyper-V host (VM must be OFF):
Set-VMProcessor -VMName NestedVM -ExposeVirtualizationExtensions $true

# Enable MAC spoofing (required for nested VM networking):
Set-VMNetworkAdapter -VMName NestedVM -MacAddressSpoofing On

# Optional: configure dynamic memory (disable for Hyper-V-in-VM):
Set-VMMemory -VMName NestedVM -DynamicMemoryEnabled $false -StartupBytes 8GB

# Inside the nested VM — install Hyper-V:
Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
```

### Use Cases
- Development/test: run Hyper-V labs inside Azure IaaS VMs or on dev workstations
- Container hosts: Windows containers with Hyper-V isolation require Hyper-V; running container hosts inside VMs requires nested virt
- Training environments: full lab stacks in single host

### Common Pitfalls
- Performance overhead is significant; not for production workloads
- Dynamic memory conflicts with Hyper-V role inside guest (Hyper-V requires static memory)
- Snapshots of a VM running nested Hyper-V are not supported in a consistent state

---

## 7. Network Controller and SDN

Software Defined Networking in Server 2016 provides a centralized management plane for virtual networks. **Datacenter edition only.**

### SDN Stack Components
| Component | Role |
|---|---|
| Network Controller | REST API management plane; programs all SDN components |
| Software Load Balancer (SLB) | Layer 4 load balancing with NAT, VIP, DSR |
| RAS Multitenant Gateway | S2S VPN, GRE tunneling, BGP routing for tenants |
| Hyper-V Network Virtualization (HNV) | Encapsulation (VXLAN/NVGRE) for virtual network isolation |

### Deployment
SDN in 2016 is deployed via SDN Express scripts or SCVMM. Manual deployment is complex; Microsoft provides SDN Express PowerShell scripts.

```powershell
# SDN Express deployment (from GitHub SDNExpress):
# https://github.com/microsoft/SDN
# Edit SDNExpress\scripts\SDNExpressModule.psm1 config file then:
.\SDNExpress\scripts\SDNExpress.ps1 -ConfigurationDataFile .\MyConfig.psd1 -Verbose

# After deployment — query Network Controller:
$uri = "https://nc.contoso.com"
Get-NetworkControllerVirtualNetwork -ConnectionUri $uri
Get-NetworkControllerLoadBalancer -ConnectionUri $uri
```

### Key Considerations
- Network Controller requires 3+ nodes for HA (odd number for Raft quorum)
- HNV uses VXLAN or NVGRE encapsulation; switch must pass encapsulated frames (jumbo frames recommended)
- SDN Express requires WinRM, CredSSP, and specific network topology pre-configured

### Common Pitfalls
- SDN is operationally complex; underestimating deployment effort is common
- Mixing non-SDN and SDN VMs on the same host requires careful NIC teaming and vSwitch configuration
- Network Controller certificates must be trusted by all hosts; certificate issues are a top failure point

---

## 8. Credential Guard and Device Guard

Virtualization-Based Security (VBS) features protect credentials and code integrity. Both use Hyper-V to isolate security-sensitive processes.

### Credential Guard
Moves LSASS credential storage into a VBS-isolated process (LSAIso). NTLM hashes and Kerberos tickets are never exposed in the normal OS context.

**Hardware requirements:**
- UEFI Secure Boot enabled
- Virtualization extensions (VT-x/AMD-V) + SLAT
- TPM 1.2 or 2.0 (recommended, not always required)
- 64-bit OS

```powershell
# Enable via GPO (preferred for domain) or registry:
# GPO path: Computer Configuration > Admin Templates > System > Device Guard
# "Turn On Virtualization Based Security" = Enabled
# "Credential Guard Configuration" = Enabled with UEFI lock

# Check status via CIM (Device Guard WMI class):
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object VirtualizationBasedSecurityStatus,
                  SecurityServicesConfigured,
                  SecurityServicesRunning,
                  AvailableSecurityProperties

# SecurityServicesRunning values:
# 1 = Credential Guard running
# 2 = HVCI (Hypervisor Code Integrity) running
```

### Device Guard / HVCI (Hypervisor-Protected Code Integrity)
Enforces kernel code integrity via hypervisor; prevents loading of unsigned or untrusted kernel code.

```powershell
# Create Code Integrity Policy (Windows Defender Application Control in later versions):
# Scan a reference machine:
New-CIPolicy -Level Publisher -FilePath C:\CI\BasePolicy.xml -UserPEs 3> C:\CI\CIAudit.log

# Convert to binary:
ConvertFrom-CIPolicy -XmlFilePath C:\CI\BasePolicy.xml -BinaryFilePath C:\CI\SIPolicy.p7b

# Deploy (copy to system folder):
Copy-Item C:\CI\SIPolicy.p7b C:\Windows\System32\CodeIntegrity\SIPolicy.p7b

# Enable HVCI via GPO or registry:
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' `
    -Name 'EnableVirtualizationBasedSecurity' -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' `
    -Name 'HypervisorEnforcedCodeIntegrity' -Value 1 -Type DWord
```

### Key Considerations
- Credential Guard blocks pass-the-hash and pass-the-ticket attacks effectively
- HVCI can break unsigned drivers; test extensively before enterprise rollout
- Enabling with UEFI lock requires physical access to disable — plan for hardware recovery
- Credential Guard incompatible with unconstrained Kerberos delegation (use resource-based constrained delegation instead)

### Common Pitfalls
- Third-party AV and security drivers frequently fail HVCI validation; verify compatibility
- VMs cannot run Credential Guard if the host does not support nested virtualization
- Enabling UEFI lock without testing recovery process is a common cause of unbootable servers

---

## 9. Just Enough Administration (JEA)

JEA provides constrained PowerShell remoting endpoints where users can perform specific administrative tasks without full administrator rights.

### Components
- **Session Configuration (.pssc):** Defines the PowerShell session — transcript path, visible cmdlets, run-as account
- **Role Capability (.psrc):** Defines what a role can do — visible cmdlets, parameters, scripts, external commands

### Setup
```powershell
# Create role capability file:
New-Item -ItemType Directory -Path 'C:\Program Files\WindowsPowerShell\Modules\JEADns\RoleCapabilities'
New-PSRoleCapabilityFile -Path 'C:\Program Files\WindowsPowerShell\Modules\JEADns\RoleCapabilities\DnsAdmin.psrc'

# Edit DnsAdmin.psrc — specify visible cmdlets:
# VisibleCmdlets = @{ Name='Restart-Service'; Parameters=@{ Name='Name'; ValidateSet='DNS' } },
#                   'Get-DnsServerResourceRecord', 'Add-DnsServerResourceRecord'

# Create session configuration:
New-PSSessionConfigurationFile -Path C:\JEA\DnsAdmins.pssc `
    -SessionType RestrictedRemoteServer `
    -TranscriptDirectory 'C:\Transcripts\JEA' `
    -RunAsVirtualAccount `
    -RoleDefinitions @{ 'CONTOSO\DnsAdmins' = @{ RoleCapabilities = 'DnsAdmin' } }

# Register endpoint:
Register-PSSessionConfiguration -Name 'JEA_DNS' -Path C:\JEA\DnsAdmins.pssc -Force

# Connect as a non-admin user:
Enter-PSSession -ComputerName DNS01 -ConfigurationName JEA_DNS

# Test what's available:
Get-Command  # Shows only permitted commands
```

### Key Considerations
- JEA sessions run as a virtual account (temporary local admin) or a Group Managed Service Account
- All commands are logged via transcripts; review regularly for audit compliance
- WinRM must be enabled; JEA endpoints are WS-Management endpoints
- Constrained language mode prevents script-based bypass attempts

### Common Pitfalls
- Forgetting to set transcript directory leads to no audit trail
- Role capability files must be in a `RoleCapabilities` subfolder of a valid PS module directory
- Providing too-broad `VisibleCmdlets` negates the purpose of JEA

---

## 10. Rolling Cluster OS Upgrade

Allows upgrading a WSFC cluster from Windows Server 2012 R2 to 2016 with zero downtime. Nodes run in mixed-OS mode temporarily.

### Process
```powershell
# 1. Drain and evict one node at a time:
Suspend-ClusterNode -Name NODE01 -Drain
Remove-ClusterNode -Name NODE01  # Remove from cluster

# 2. Reinstall node with Windows Server 2016, rejoin cluster:
Add-ClusterNode -Name NODE01  # After OS reinstall

# 3. Repeat for all nodes. During upgrade, cluster runs in 2012 R2 functional level.
# Verify mixed-mode cluster level:
Get-Cluster | Select-Object ClusterFunctionalLevel
# Returns 8 (2012 R2 level) during upgrade

# 4. After ALL nodes upgraded:
Update-ClusterFunctionalLevel  # Upgrades to level 9 (2016)
# WARNING: This is irreversible — cannot downgrade after running this
```

### Key Considerations
- Cluster Functional Level remains at 2012 R2 (level 8) until `Update-ClusterFunctionalLevel` is run
- New 2016-only features (S2D, Storage Replica CSVs) not available until functional level update
- CSV ownership migrates to upgraded nodes automatically
- Hyper-V VMs continue running during node eviction (live migration)

### Common Pitfalls
- Running `Update-ClusterFunctionalLevel` before all nodes are upgraded breaks the cluster
- Some cluster-aware applications may not tolerate mixed-OS mode — validate with vendor
- Backup cluster database before starting (`Backup-ClusterDatabase`)

---

## 11. PowerShell 5.1

PowerShell 5.1 is the final version of Windows PowerShell (distinct from PowerShell 7.x / PowerShell Core). It ships in-box with Windows Server 2016.

### Key Features vs 5.0
- **PowerShell Classes:** Define custom types with `class` keyword; inheritance supported
- **DSC Improvements:** Local Configuration Manager (LCM) v2, partial configurations, pull server improvements
- **Script Debugging:** Improved step-through debugging in VS Code and ISE
- **Package Management:** PowerShellGet, Install-Module, PSGallery integration
- **OneGet / PackageManagement:** Unified package management API
- **Constrained Language Mode:** Enhanced security for JEA and Device Guard
- **New cmdlets:** `Get-TimeZone`, `Set-TimeZone`, `ConvertFrom-String`, `Format-Hex`
- **Archive cmdlets:** `Compress-Archive`, `Expand-Archive` built-in

### Version Check
```powershell
$PSVersionTable.PSVersion  # Should return 5.1.x on Server 2016
# Major: 5, Minor: 1, Build: 14393.x
```

### Key Considerations
- PowerShell 5.1 requires .NET Framework 4.5+; Server 2016 ships with 4.6.x
- WMF (Windows Management Framework) 5.1 cannot be downgraded once installed
- Side-by-side with PowerShell 7.x is supported; `pwsh.exe` vs `powershell.exe`
- **EOL note:** No new features will be added to PowerShell 5.1; critical security fixes only

---

## 12. ReFS v2

Resilient File System version 2 shipped with Server 2016 with significant improvements over v1 (Server 2012).

### New Capabilities in v2
| Feature | Description |
|---|---|
| Block cloning | Copy-on-write file copies in O(1); used by Hyper-V checkpoints and S2D |
| Sparse VDL (Valid Data Length) | Initialize large files instantly; no zeroing required |
| Integrity streams | Per-file/stream checksumming with auto-correction via Storage Spaces |
| Metadata integrity | All metadata checksummed; auto-repair with mirrored Storage Spaces |

### When to Use ReFS vs NTFS (2016)
| Scenario | Recommendation |
|---|---|
| Hyper-V VHDXs on S2D | ReFS — block cloning accelerates checkpoint merge |
| General file server shares | NTFS — better quota, EFS, dedup support |
| Boot/system volumes | NTFS only — ReFS not bootable |
| Archival/backup repos | ReFS — integrity streams catch silent corruption |
| Deduplication workloads | NTFS — ReFS dedup not available in 2016 |

### Creating ReFS Volumes
```powershell
# Format new volume as ReFS:
Format-Volume -DriveLetter D -FileSystem ReFS -NewFileSystemLabel "HyperV-Data" -Confirm:$false

# Check ReFS version:
Get-Volume -DriveLetter D | Select-Object FileSystem, FileSystemLabel, Size

# ReFS integrity streams per file (if on Storage Spaces):
Get-Item D:\VHDX\MyVM.vhdx | Get-FileIntegrity
Set-FileIntegrity D:\VHDX\MyVM.vhdx -Enable $true
```

### Key Considerations
- Block cloning dramatically speeds Hyper-V checkpoint operations (seconds vs minutes for large VHDXs)
- ReFS does not support 8.3 filename generation, EFS encryption, or disk quotas
- `fsutil` and `defrag` behavior differs on ReFS; defragmentation not applicable
- Integrity stream repair requires redundancy (mirror or parity); single-disk ReFS detects but cannot repair

### Common Pitfalls
- Creating ReFS on a non-Storage-Spaces single disk provides integrity detection but no repair
- Applications that use extended attributes (some backup products) may have ReFS compatibility issues
- ReFS `chkdsk` is not supported the same way as NTFS; `Repair-Volume` is the equivalent

---

## Diagnostic Scripts

### Script 11: Container Health Diagnostics

```powershell
<#
.SYNOPSIS
    Windows Server 2016 - Windows Container and Docker Diagnostics
.DESCRIPTION
    Collects comprehensive diagnostics for Docker Engine and Windows Containers
    on Windows Server 2016. Covers Docker service status, container inventory,
    image inventory, network configuration, and resource utilization.
    Suitable for both Windows Server Containers and Hyper-V Containers.
.NOTES
    Version : 2016.1.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
#>

#Requires -RunAsAdministrator

$Separator = '=' * 60

#region --- Docker Service Status ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  DOCKER SERVICE STATUS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$dockerSvc = Get-Service -Name docker -ErrorAction SilentlyContinue
if ($null -eq $dockerSvc) {
    Write-Warning "Docker service not found. Is Docker installed?"
} else {
    $dockerSvc | Select-Object Name, Status, StartType | Format-Table -AutoSize

    if ($dockerSvc.Status -eq 'Running') {
        Write-Host "Docker version info:" -ForegroundColor Yellow
        & docker version 2>&1
    }
}
#endregion

#region --- Windows Containers Feature ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  WINDOWS FEATURES" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$features = @('Containers','Hyper-V','Hyper-V-Tools','Hyper-V-PowerShell')
foreach ($f in $features) {
    $feat = Get-WindowsFeature -Name $f -ErrorAction SilentlyContinue
    if ($feat) {
        [PSCustomObject]@{
            Feature      = $f
            DisplayName  = $feat.DisplayName
            InstallState = $feat.InstallState
        }
    }
} | Format-Table -AutoSize
#endregion

#region --- Docker Info ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  DOCKER ENGINE INFO" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    & docker info 2>&1
} else {
    Write-Warning "Docker not running — skipping docker info."
}
#endregion

#region --- Running Containers ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  RUNNING CONTAINERS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    $running = & docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}\t{{.Ports}}" 2>&1
    Write-Host $running

    Write-Host "`nAll containers (including stopped):" -ForegroundColor Yellow
    & docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}" 2>&1
} else {
    Write-Warning "Docker not running — skipping container inventory."
}
#endregion

#region --- Container Resource Usage ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  CONTAINER RESOURCE USAGE (running containers)" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    # --no-stream returns a single snapshot (non-blocking)
    & docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>&1
} else {
    Write-Warning "Docker not running — skipping resource stats."
}
#endregion

#region --- Image Inventory ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  CONTAINER IMAGE INVENTORY" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    & docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}\t{{.CreatedSince}}" 2>&1

    Write-Host "`nDangling images (untagged):" -ForegroundColor Yellow
    & docker images -f dangling=true 2>&1
} else {
    Write-Warning "Docker not running — skipping image inventory."
}
#endregion

#region --- Docker Networks ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  DOCKER NETWORK CONFIGURATION" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    & docker network ls 2>&1

    Write-Host "`nNAT network details:" -ForegroundColor Yellow
    & docker network inspect nat 2>&1 | Select-Object -First 40
} else {
    Write-Warning "Docker not running — skipping network info."
}
#endregion

#region --- Docker Volumes ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  DOCKER VOLUMES" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

if ($dockerSvc -and $dockerSvc.Status -eq 'Running') {
    & docker volume ls 2>&1
} else {
    Write-Warning "Docker not running — skipping volume info."
}
#endregion

#region --- Docker Daemon Logs (recent) ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  DOCKER EVENT LOG (last 20 events from Windows Event Log)" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$dockerEvents = Get-WinEvent -LogName 'Microsoft-Windows-Docker' -MaxEvents 20 -ErrorAction SilentlyContinue
if ($dockerEvents) {
    $dockerEvents | Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-Table -AutoSize -Wrap
} else {
    # Fallback: check application log for docker entries
    Get-WinEvent -LogName Application -MaxEvents 200 -ErrorAction SilentlyContinue |
        Where-Object { $_.ProviderName -match 'docker' } |
        Select-Object -First 10 TimeCreated, Id, LevelDisplayName, Message |
        Format-Table -AutoSize -Wrap
}
#endregion

Write-Host "`n$Separator" -ForegroundColor Green
Write-Host "  Container diagnostics complete" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Green
```

---

### Script 12: Credential Guard and VBS Status Check

```powershell
<#
.SYNOPSIS
    Windows Server 2016 - VBS, Credential Guard, and Device Guard Status
.DESCRIPTION
    Checks the status of Virtualization-Based Security (VBS), Credential Guard,
    and Device Guard (HVCI) on Windows Server 2016. Reports hardware requirements,
    current configuration state, and running security services.
    Equivalent to the Device Guard section in msinfo32.exe but scriptable.
.NOTES
    Version : 2016.1.0
    Targets : Windows Server 2016+
    Safety  : Read-only. No modifications to system configuration.
#>

#Requires -RunAsAdministrator

$Separator = '=' * 60

#region --- Hardware Virtualization Prerequisites ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  HARDWARE VIRTUALIZATION PREREQUISITES" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
[PSCustomObject]@{
    ProcessorName              = $cpu.Name
    VirtualizationFirmwareEnabled = $cpu.VirtualizationFirmwareEnabled
    SecondLevelAddressTranslation = $cpu.SecondLevelAddressTranslationExtensions
    VMMonitorModeExtensions    = $cpu.VMMonitorModeExtensions
} | Format-List

# Secure Boot status
$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
Write-Host "Secure Boot Enabled: $($secureBoot)" -ForegroundColor $(if ($secureBoot) {'Green'} else {'Yellow'})

# TPM status
$tpm = Get-CimInstance -Namespace root\CIMv2\Security\MicrosoftTpm -ClassName Win32_Tpm -ErrorAction SilentlyContinue
if ($tpm) {
    [PSCustomObject]@{
        TPM_IsEnabled      = $tpm.IsEnabled_InitialValue
        TPM_IsActivated    = $tpm.IsActivated_InitialValue
        TPM_IsOwned        = $tpm.IsOwned_InitialValue
        TPM_SpecVersion    = $tpm.SpecVersion
    } | Format-List
} else {
    Write-Warning "TPM not detected or WMI namespace unavailable."
}
#endregion

#region --- VBS and Device Guard Status (Win32_DeviceGuard) ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  VBS / DEVICE GUARD STATUS (Win32_DeviceGuard)" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$dg = Get-CimInstance -ClassName Win32_DeviceGuard `
          -Namespace root\Microsoft\Windows\DeviceGuard `
          -ErrorAction SilentlyContinue

if ($null -eq $dg) {
    Write-Warning "Win32_DeviceGuard WMI class not available. Requires Server 2016 with KB updates."
} else {
    # Decode VirtualizationBasedSecurityStatus
    $vbsStatusMap = @{
        0 = 'Not enabled'
        1 = 'Enabled but not running'
        2 = 'Running'
    }

    # Decode SecurityServicesConfigured / SecurityServicesRunning bitmask
    $serviceMap = @{
        0 = 'None'
        1 = 'Credential Guard'
        2 = 'HVCI (Hypervisor Code Integrity)'
    }

    function Decode-ServiceFlags($flags) {
        $result = @()
        if ($flags -band 1) { $result += 'Credential Guard' }
        if ($flags -band 2) { $result += 'HVCI' }
        if ($result.Count -eq 0) { $result += 'None' }
        return $result -join ', '
    }

    # Decode AvailableSecurityProperties bitmask
    function Decode-SecurityProps($props) {
        $propMap = @{
            1 = 'BaseVirtualization'
            2 = 'SecureBoot'
            3 = 'DMAProtection'
            4 = 'SecureMemoryOverwrite'
            5 = 'NXProtection'
            6 = 'SMMMitigations'
            7 = 'MBEC/TridentTSME'
        }
        ($props | ForEach-Object { $propMap[$_] }) -join ', '
    }

    [PSCustomObject]@{
        VBS_Status                   = $vbsStatusMap[$dg.VirtualizationBasedSecurityStatus]
        SecurityServicesConfigured   = Decode-ServiceFlags($dg.SecurityServicesConfigured)
        SecurityServicesRunning      = Decode-ServiceFlags($dg.SecurityServicesRunning)
        AvailableSecurityProperties  = Decode-SecurityProps($dg.AvailableSecurityProperties)
        RequiredSecurityProperties   = Decode-SecurityProps($dg.RequiredSecurityProperties)
        CodeIntegrityPolicyEnforcement = $dg.CodeIntegrityPolicyEnforcementStatus
    } | Format-List

    # Color-coded summary
    $cgRunning = ($dg.SecurityServicesRunning -band 1) -eq 1
    $hvciRunning = ($dg.SecurityServicesRunning -band 2) -eq 2

    Write-Host "--- SUMMARY ---" -ForegroundColor Yellow
    Write-Host "VBS Running:        " -NoNewline
    if ($dg.VirtualizationBasedSecurityStatus -eq 2) {
        Write-Host "YES" -ForegroundColor Green
    } else {
        Write-Host "NO ($($vbsStatusMap[$dg.VirtualizationBasedSecurityStatus]))" -ForegroundColor Red
    }

    Write-Host "Credential Guard:   " -NoNewline
    if ($cgRunning) {
        Write-Host "RUNNING" -ForegroundColor Green
    } else {
        Write-Host "NOT RUNNING" -ForegroundColor Red
    }

    Write-Host "HVCI:               " -NoNewline
    if ($hvciRunning) {
        Write-Host "RUNNING" -ForegroundColor Green
    } else {
        Write-Host "NOT RUNNING" -ForegroundColor Yellow
    }
}
#endregion

#region --- Registry-Based VBS Configuration ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  REGISTRY CONFIGURATION (DeviceGuard)" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$dgRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
if (Test-Path $dgRegPath) {
    $dgReg = Get-ItemProperty -Path $dgRegPath -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        EnableVirtualizationBasedSecurity = $dgReg.EnableVirtualizationBasedSecurity
        RequirePlatformSecurityFeatures   = $dgReg.RequirePlatformSecurityFeatures
        HypervisorEnforcedCodeIntegrity   = $dgReg.HypervisorEnforcedCodeIntegrity
        Locked                            = $dgReg.Locked
    } | Format-List
} else {
    Write-Warning "DeviceGuard registry key not found — VBS not configured via registry."
}

# LSA protection (RunAsPPL) - related credential protection
$lsaPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$lsaReg = Get-ItemProperty -Path $lsaPath -ErrorAction SilentlyContinue
Write-Host "LSA RunAsPPL (Protected Process Light): $($lsaReg.RunAsPPL)" -ForegroundColor Yellow
Write-Host "  (1 = enabled, provides additional LSASS protection even without Credential Guard)"
#endregion

#region --- LSASS Process Protection ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  LSASS PROCESS PROTECTION" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$lsass = Get-CimInstance -ClassName Win32_Process -Filter "Name='lsass.exe'" -ErrorAction SilentlyContinue
if ($lsass) {
    $lsass | Select-Object ProcessId, Name, HandleCount, WorkingSetSize, VirtualSize |
        Format-Table -AutoSize
}

# Check if LSAIso (Credential Guard isolated process) is running
$lsaIso = Get-Process -Name LsaIso -ErrorAction SilentlyContinue
if ($lsaIso) {
    Write-Host "LsaIso.exe (Credential Guard isolated LSA): RUNNING (PID $($lsaIso.Id))" -ForegroundColor Green
} else {
    Write-Host "LsaIso.exe: NOT RUNNING (Credential Guard not active)" -ForegroundColor Yellow
}
#endregion

#region --- Secure Boot and UEFI Details ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  UEFI / SECURE BOOT DETAILS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

# BIOS/UEFI info
$bios = Get-CimInstance -ClassName Win32_Bios
[PSCustomObject]@{
    BIOSVersion       = $bios.BIOSVersion -join '; '
    SMBIOSVersion     = "$($bios.SMBIOSMajorVersion).$($bios.SMBIOSMinorVersion)"
    Manufacturer      = $bios.Manufacturer
    ReleaseDate       = $bios.ReleaseDate
} | Format-List

# Boot configuration
$bootEnv = Get-CimInstance -ClassName Win32_ComputerSystem
Write-Host "Firmware Type (BIOS=0 / UEFI check below): "
$firmwarePath = 'HKLM:\System\CurrentControlSet\Control'
$fwReg = Get-ItemProperty -Path $firmwarePath -Name SystemStartOptions -ErrorAction SilentlyContinue
Write-Host "  SystemStartOptions: $($fwReg.SystemStartOptions)"

# Check UEFI via WMI (available Server 2016+)
try {
    $uefi = Get-ItemProperty 'HKLM:\System\CurrentControlSet\Control\SecureBoot\State' -ErrorAction Stop
    Write-Host "SecureBoot State UEFISecureBootEnabled: $($uefi.UEFISecureBootEnabled)" -ForegroundColor Green
} catch {
    Write-Host "SecureBoot registry state not found (legacy BIOS or key absent)" -ForegroundColor Yellow
}
#endregion

#region --- Code Integrity Policy Status ---
Write-Host "`n$Separator" -ForegroundColor Cyan
Write-Host "  CODE INTEGRITY / WDAC POLICY STATUS" -ForegroundColor Cyan
Write-Host $Separator -ForegroundColor Cyan

$ciPolicyPath = 'C:\Windows\System32\CodeIntegrity'
if (Test-Path $ciPolicyPath) {
    $ciFiles = Get-ChildItem -Path $ciPolicyPath -ErrorAction SilentlyContinue |
               Select-Object Name, Length, LastWriteTime
    if ($ciFiles) {
        Write-Host "Code Integrity policy files:" -ForegroundColor Yellow
        $ciFiles | Format-Table -AutoSize
    } else {
        Write-Host "No Code Integrity policy files deployed." -ForegroundColor Yellow
    }
}

# Check CI audit log
$ciEventLog = Get-WinEvent -LogName 'Microsoft-Windows-CodeIntegrity/Operational' `
    -MaxEvents 20 -ErrorAction SilentlyContinue
if ($ciEventLog) {
    Write-Host "`nRecent Code Integrity events:" -ForegroundColor Yellow
    $ciEventLog | Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Format-Table -AutoSize -Wrap
} else {
    Write-Host "No Code Integrity operational events found." -ForegroundColor Yellow
}
#endregion

Write-Host "`n$Separator" -ForegroundColor Green
Write-Host "  VBS/Credential Guard diagnostics complete" -ForegroundColor Green
Write-Host $Separator -ForegroundColor Green
```

---

## Quick Reference: Edition Feature Matrix

| Feature | Standard | Datacenter |
|---|---|---|
| Nano Server | Yes | Yes |
| Windows Containers | Yes | Yes |
| Hyper-V Containers | Yes | Yes |
| Nested Virtualization | Yes | Yes |
| Credential Guard / Device Guard | Yes | Yes |
| JEA | Yes | Yes |
| PowerShell 5.1 | Yes | Yes |
| ReFS v2 | Yes | Yes |
| Rolling Cluster OS Upgrade | Yes | Yes |
| Storage Replica | No | Yes |
| Storage Spaces Direct | No | Yes |
| Shielded VMs / HGS | No | Yes |
| Network Controller / SDN | No | Yes |

---

## Key End-of-Life Considerations

- **Extended Support ends January 14, 2027** — security patches only; no new features
- Nano Server as a host OS: deprecated in 2019; customers still on 2016 Nano must plan migration
- Admin-trusted attestation for HGS: deprecated; migrate to TPM or host key attestation
- PowerShell 5.1: no new features; evaluate migration path to PowerShell 7.x for new automation
- Storage Replica in Standard edition: not available until 2019; Datacenter-only on 2016
- Windows containers on 2016: image compatibility with newer container runtime versions may require `--isolation=hyperv` flag when mixing OS versions
