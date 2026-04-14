<#
.SYNOPSIS
    Windows Server Hyper-V - Complete VM Inventory
.DESCRIPTION
    Enumerates all VMs on the local Hyper-V host with full configuration
    detail: generation, configuration version, vCPU, memory (static/dynamic),
    disk layout, network adapters, checkpoint presence, and replication status.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. VM Inventory Collection
        2. Summary Table
        3. Detailed Report
        4. Statistics Summary
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$allVMs = Get-VM
Write-Host "Inventorying $($allVMs.Count) VMs on $env:COMPUTERNAME..." -ForegroundColor Cyan

# ── 1. Collect Inventory ─────────────────────────────────────────────────────
$inventory = foreach ($vm in $allVMs) {
    $processor   = Get-VMProcessor -VMName $vm.Name
    $memory      = Get-VMMemory -VMName $vm.Name
    $nics        = Get-VMNetworkAdapter -VMName $vm.Name
    $disks       = Get-VMHardDiskDrive -VMName $vm.Name
    $checkpoints = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    $replication = Get-VMReplication -VMName $vm.Name -ErrorAction SilentlyContinue

    $diskSummary = $disks | ForEach-Object {
        $vhd = if ($_.Path) { Get-VHD -Path $_.Path -ErrorAction SilentlyContinue } else { $null }
        "$($_.ControllerType)[$($_.ControllerNumber),$($_.ControllerLocation)] " +
        "$(if($vhd){"$([math]::Round($vhd.Size/1GB,0))GB/$($vhd.VhdType)"} else {'<passthrough>'})"
    }

    $nicSummary = $nics | ForEach-Object {
        $vlan = Get-VMNetworkAdapterVlan -VMNetworkAdapter $_ -ErrorAction SilentlyContinue
        "$($_.Name):$($_.SwitchName)" +
        "$(if($vlan.OperationMode -eq 'Access'){":VLAN$($vlan.AccessVlanId)"})"
    }

    [PSCustomObject]@{
        Name           = $vm.Name
        State          = $vm.State
        Generation     = $vm.Generation
        ConfigVersion  = $vm.Version
        vCPUs          = $processor.Count
        MemType        = if ($memory.DynamicMemoryEnabled) { "Dynamic" } else { "Static" }
        StartupMem_GB  = [math]::Round($memory.Startup / 1GB, 2)
        MinMem_GB      = [math]::Round($memory.Minimum / 1GB, 2)
        MaxMem_GB      = [math]::Round($memory.Maximum / 1GB, 2)
        AssignedMem_GB = [math]::Round($vm.MemoryAssigned / 1GB, 2)
        Uptime         = $vm.Uptime
        CheckpointType = $vm.CheckpointType
        Checkpoints    = if ($checkpoints) { $checkpoints.Count } else { 0 }
        Disks          = ($diskSummary -join "; ")
        NICs           = ($nicSummary -join "; ")
        ReplState      = if ($replication) { $replication.State } else { "None" }
        ReplHealth     = if ($replication) { $replication.Health } else { "N/A" }
        ISVersion      = $vm.IntegrationServicesVersion
    }
}

# ── 2. Summary Table ─────────────────────────────────────────────────────────
$inventory | Format-Table Name, State, Generation, ConfigVersion, vCPUs,
    MemType, AssignedMem_GB, Checkpoints, ReplState -AutoSize

# ── 3. Detailed Report ───────────────────────────────────────────────────────
Write-Host "`nDetailed Report:" -ForegroundColor Cyan
$inventory | Format-List

# ── 4. Statistics Summary ────────────────────────────────────────────────────
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total VMs:       $($inventory.Count)"
Write-Host "Running:         $(($inventory | Where-Object State -eq 'Running').Count)"
Write-Host "Gen1:            $(($inventory | Where-Object Generation -eq 1).Count)"
Write-Host "Gen2:            $(($inventory | Where-Object Generation -eq 2).Count)"
Write-Host "Dynamic Memory:  $(($inventory | Where-Object MemType -eq 'Dynamic').Count)"
Write-Host "With Checkpoints:$(($inventory | Where-Object Checkpoints -gt 0).Count)"
Write-Host "Replicated:      $(($inventory | Where-Object ReplState -ne 'None').Count)"
