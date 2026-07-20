<#
.SYNOPSIS
    Windows Server Hyper-V - Host Health Assessment
.DESCRIPTION
    Collects host-level Hyper-V configuration including NUMA topology,
    logical processor allocation, memory and vCPU overcommit ratios,
    virtual switch configuration, and role feature installation status.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Host Information
        2. NUMA Topology
        3. Memory Overcommit Analysis
        4. vCPU Overcommit Ratio
        5. Hyper-V Role and Features
        6. SCVMM Agent Status
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 70)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 70)" -ForegroundColor Cyan
}

# ── 1. Host Information ──────────────────────────────────────────────────────
Write-Section "Host Information"
$cs     = Get-CimInstance Win32_ComputerSystem
$os     = Get-CimInstance Win32_OperatingSystem
$vmHost = Get-VMHost

[PSCustomObject]@{
    Hostname         = $env:COMPUTERNAME
    OS               = $os.Caption
    Build            = $os.BuildNumber
    TotalRAM_GB      = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    LogicalCPUs      = $cs.NumberOfLogicalProcessors
    Sockets          = $cs.NumberOfProcessors
    HyperVEnabled    = (Get-WindowsFeature Hyper-V -ErrorAction SilentlyContinue).Installed
    ServerCore       = ($os.Caption -notmatch 'Desktop Experience')
    MigrationAuth    = $vmHost.VirtualMachineMigrationAuthenticationType
    MigrationEnabled = $vmHost.VirtualMachineMigrationEnabled
    MaxLiveMig       = $vmHost.MaximumVirtualMachineMigrations
    MaxStorMig       = $vmHost.MaximumStorageMigrations
} | Format-List

# ── 2. NUMA Topology ─────────────────────────────────────────────────────────
Write-Section "NUMA Topology"
Get-VMHostNumaNode | Select-Object NodeId,
    @{n="MemTotal_GB";e={[math]::Round($_.MemoryTotal / 1GB, 1)}},
    @{n="MemAvail_GB";e={[math]::Round($_.MemoryAvailable / 1GB, 1)}},
    ProcessorsAvailable | Format-Table -AutoSize

Write-Host "NUMA Spanning Enabled: $((Get-VMHost).NumaSpanningEnabled)" -ForegroundColor Yellow

# ── 3. Memory Overcommit Analysis ────────────────────────────────────────────
Write-Section "Memory Overcommit Analysis"
$allVMs        = Get-VM
$totalHostRAM  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$assigned_GB   = [math]::Round(($allVMs | Measure-Object MemoryAssigned -Sum).Sum / 1GB, 2)
$maxConfig_GB  = [math]::Round(($allVMs | ForEach-Object {
    (Get-VMMemory -VMName $_.Name).Maximum } | Measure-Object -Sum).Sum / 1GB, 2)

[PSCustomObject]@{
    HostTotalRAM_GB       = $totalHostRAM
    TotalVMsRunning       = ($allVMs | Where-Object State -eq 'Running').Count
    TotalVMsAll           = $allVMs.Count
    CurrentAssigned_GB    = $assigned_GB
    MaxConfigured_GB      = $maxConfig_GB
    AssignedOvercommitPct = [math]::Round(($assigned_GB / $totalHostRAM) * 100, 1)
    MaxOvercommitPct      = [math]::Round(($maxConfig_GB / $totalHostRAM) * 100, 1)
} | Format-List

# ── 4. vCPU Overcommit Ratio ─────────────────────────────────────────────────
Write-Section "vCPU Overcommit Ratio"
$totalVCPUs = ($allVMs | Where-Object State -eq 'Running' |
    ForEach-Object { (Get-VMProcessor -VMName $_.Name).Count } |
    Measure-Object -Sum).Sum
$physLPs = $cs.NumberOfLogicalProcessors

[PSCustomObject]@{
    PhysicalLogicalProcessors = $physLPs
    TotalRunningvCPUs         = $totalVCPUs
    OvercommitRatio           = "$([math]::Round($totalVCPUs / [math]::Max($physLPs,1), 2)):1"
    Recommendation            = if ($totalVCPUs / [math]::Max($physLPs,1) -gt 4) {
        "WARNING: >4:1 ratio"} else {"OK"}
} | Format-List

# ── 5. Hyper-V Role and Features ─────────────────────────────────────────────
Write-Section "Hyper-V Role and Features"
$features = @('Hyper-V', 'Hyper-V-Tools', 'Hyper-V-PowerShell',
    'RSAT-Clustering', 'Failover-Clustering', 'FS-SMB1')
foreach ($feat in $features) {
    $f = Get-WindowsFeature $feat -ErrorAction SilentlyContinue
    if ($f) {
        [PSCustomObject]@{Feature=$f.Name; DisplayName=$f.DisplayName; Installed=$f.Installed}
    }
} | Format-Table -AutoSize

# ── 6. SCVMM Agent Status ────────────────────────────────────────────────────
Write-Section "SCVMM Agent Status"
$scvmmAgent = Get-Service -Name vmmagent -ErrorAction SilentlyContinue
if ($scvmmAgent) {
    $scvmmAgent | Select-Object Name, Status, StartType | Format-Table -AutoSize
} else {
    Write-Host "SCVMM agent not installed (standalone Hyper-V host)." -ForegroundColor Gray
}

Write-Host "`nHost health assessment complete." -ForegroundColor Green
