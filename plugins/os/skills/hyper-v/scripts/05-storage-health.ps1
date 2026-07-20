<#
.SYNOPSIS
    Windows Server Hyper-V - Virtual Disk Health Audit
.DESCRIPTION
    Enumerates all virtual hard disks attached to VMs. Reports VHD type,
    size, fragmentation, sector alignment, Storage QoS policy, and identifies
    shared VHDX files. Flags issues such as high fragmentation, legacy VHD
    format, unaligned disks, and deep checkpoint chains.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Virtual Disk Health Inventory
        2. Issues Summary
        3. Checkpoint Chain Depth Analysis
        4. Storage QoS Active Flows
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ── 1. Virtual Disk Health Inventory ──────────────────────────────────────────
Write-Host "=== Virtual Disk Health Inventory ===" -ForegroundColor Cyan

$diskReport = Get-VM | ForEach-Object {
    $vm = $_
    foreach ($drive in (Get-VMHardDiskDrive -VMName $vm.Name)) {
        if (-not $drive.Path) { continue }
        $vhd = Get-VHD -Path $drive.Path -ErrorAction SilentlyContinue
        if (-not $vhd) { continue }

        $issues = @()
        if ($vhd.FragmentationPercentage -gt 20) {
            $issues += "HIGH_FRAG($($vhd.FragmentationPercentage)%)" }
        if ($vhd.Alignment -eq 0)     { $issues += "UNALIGNED" }
        if ($drive.Path -match '\.vhd$') { $issues += "LEGACY_VHD" }
        if ($vhd.VhdType -eq 'Differencing') { $issues += "DIFFERENCING_CHAIN" }

        [PSCustomObject]@{
            VM             = $vm.Name
            Controller     = "$($drive.ControllerType)[$($drive.ControllerNumber),$($drive.ControllerLocation)]"
            Path           = $drive.Path
            Format         = if ($drive.Path -match '\.vhds$') {"VHD Set"}
                             elseif ($drive.Path -match '\.vhdx$') {"VHDX"}
                             else {"VHD"}
            VHDType        = $vhd.VhdType
            Allocated_GB   = [math]::Round($vhd.FileSize / 1GB, 2)
            MaxSize_GB     = [math]::Round($vhd.Size / 1GB, 2)
            Fragmentation  = "$($vhd.FragmentationPercentage)%"
            Alignment      = $vhd.Alignment
            MinIOPS        = $drive.MinimumIOPS
            MaxIOPS        = $drive.MaximumIOPS
            Issues         = ($issues -join ", ")
        }
    }
}

$diskReport | Format-Table VM, Format, VHDType, Allocated_GB, MaxSize_GB,
    Fragmentation, MinIOPS, MaxIOPS, Issues -AutoSize

# ── 2. Issues Summary ────────────────────────────────────────────────────────
Write-Host "`n=== Issues Summary ===" -ForegroundColor Yellow
$issueDisks = $diskReport | Where-Object { $_.Issues -ne "" }
if ($issueDisks) {
    $issueDisks | Select-Object VM, Path, Issues | Format-Table -AutoSize
} else {
    Write-Host "No issues detected." -ForegroundColor Green
}

# ── 3. Checkpoint Chain Depth Analysis ───────────────────────────────────────
Write-Host "`n=== Checkpoint Chain Depth ===" -ForegroundColor Cyan
Get-VM | ForEach-Object {
    $vm    = $_
    $snaps = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    if ($snaps.Count -gt 0) {
        [PSCustomObject]@{
            VM         = $vm.Name
            Snapshots  = $snaps.Count
            OldestSnap = ($snaps | Sort-Object CreationTime | Select-Object -First 1).CreationTime
            Warning    = if ($snaps.Count -gt 3) {"DEEP CHAIN"} else {"OK"}
        }
    }
} | Format-Table -AutoSize

# ── 4. Storage QoS Active Flows ──────────────────────────────────────────────
Write-Host "`n=== Storage QoS Active Flows ===" -ForegroundColor Cyan
try {
    Get-StorageQosFlow -ErrorAction Stop |
        Select-Object InitiatorName, FilePath, Status, IOPS, Bandwidth,
            MinimumIops, MaximumIops | Format-Table -AutoSize
} catch {
    Write-Host "Storage QoS not available (requires SOFS or S2D)." -ForegroundColor Gray
}
