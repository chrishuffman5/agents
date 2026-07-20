<#
.SYNOPSIS
    Windows Server Hyper-V - Live Migration Configuration Audit
.DESCRIPTION
    Reports live migration host configuration, concurrent migration limits,
    authentication method, performance options, network binding for migration
    traffic, RDMA adapter availability, processor compatibility mode status,
    and recent migration events from the event log.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Host-Level Migration Settings
        2. Migration Network Bindings
        3. RDMA-Capable Adapters
        4. Running VMs (Migration Candidates)
        5. Processor Compatibility Mode Status
        6. Recent Live Migration Events
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Live Migration Configuration ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME`n"

# ── 1. Host-Level Migration Settings ─────────────────────────────────────────
$vmHost = Get-VMHost
[PSCustomObject]@{
    MigrationEnabled        = $vmHost.VirtualMachineMigrationEnabled
    MaxConcurrentMigrations = $vmHost.MaximumVirtualMachineMigrations
    MaxStorageMigrations    = $vmHost.MaximumStorageMigrations
    AuthenticationType      = $vmHost.VirtualMachineMigrationAuthenticationType
    PerformanceOption       = $vmHost.VirtualMachineMigrationPerformanceOption
    UseAnyNetwork           = $vmHost.UseAnyNetworkForMigration
} | Format-List

# ── 2. Migration Network Bindings ────────────────────────────────────────────
Write-Host "=== Migration Network Bindings ===" -ForegroundColor Cyan
try {
    Get-VMMigrationNetwork -ComputerName $env:COMPUTERNAME -ErrorAction Stop |
        Select-Object Subnet, Priority | Format-Table -AutoSize
} catch {
    Write-Host "No specific migration networks configured (using any network)." -ForegroundColor Gray
}

# ── 3. RDMA-Capable Adapters ─────────────────────────────────────────────────
Write-Host "`n=== RDMA-Capable Adapters ===" -ForegroundColor Cyan
try {
    $rdma = Get-NetAdapterRdma -ErrorAction Stop | Where-Object Enabled -eq $true
    if ($rdma) {
        $rdma | Select-Object Name, InterfaceDescription, Enabled,
            MaxQueuePairCount | Format-Table -AutoSize
    } else {
        Write-Host "No RDMA-enabled adapters found." -ForegroundColor Gray
    }
} catch {
    Write-Host "RDMA adapter query not available." -ForegroundColor Gray
}

# ── 4. Running VMs (Migration Candidates) ────────────────────────────────────
Write-Host "`n=== Running VMs (Migration Candidates) ===" -ForegroundColor Cyan
Get-VM | Where-Object State -eq 'Running' |
    Select-Object Name, State,
        @{n="CPU%";e={$_.CPUUsage}},
        @{n="Mem_GB";e={[math]::Round($_.MemoryAssigned/1GB, 1)}},
        @{n="Disks";e={@(Get-VMHardDiskDrive -VMName $_.Name).Count}} |
    Format-Table -AutoSize

# ── 5. Processor Compatibility Mode ──────────────────────────────────────────
Write-Host "`n=== Processor Compatibility Mode ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $proc = Get-VMProcessor -VMName $_.Name
    [PSCustomObject]@{
        VM                   = $_.Name
        CompatibilityEnabled = $proc.CompatibilityForMigrationEnabled
        OlderOSCompat        = $proc.CompatibilityForOlderOperatingSystemsEnabled
    }
} | Format-Table -AutoSize

# ── 6. Recent Migration Events ───────────────────────────────────────────────
Write-Host "`n=== Recent Live Migration Events (last 24 hours) ===" -ForegroundColor Cyan
$cutoff = (Get-Date).AddHours(-24)
try {
    $events = Get-WinEvent -LogName "Microsoft-Windows-Hyper-V-Migration-Admin" `
        -MaxEvents 50 -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -gt $cutoff }
    if ($events) {
        $events | Select-Object TimeCreated, LevelDisplayName, Id,
            @{n="Message";e={$_.Message.Substring(0,
                [Math]::Min(120, $_.Message.Length))}} |
            Format-Table -AutoSize -Wrap
    } else {
        Write-Host "No migration events in the last 24 hours." -ForegroundColor Green
    }
} catch {
    Write-Host "Migration event log not available." -ForegroundColor Gray
}
