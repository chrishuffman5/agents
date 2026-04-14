<#
.SYNOPSIS
    Windows Server Hyper-V - Checkpoint Inventory and Age Audit
.DESCRIPTION
    Enumerates all VM checkpoints (snapshots) across all VMs. Reports
    checkpoint type, creation time, age in days, and estimates disk space
    consumed by differencing VHDX files. Flags stale checkpoints that
    may impact performance.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Checkpoint Inventory
        2. Stale Checkpoints (>7 days)
        3. Checkpoint Disk Space Impact per VM
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Checkpoint Audit ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

# ── 1. Checkpoint Inventory ──────────────────────────────────────────────────
$allCheckpoints = Get-VM | ForEach-Object {
    $vm   = $_
    $snaps = Get-VMSnapshot -VMName $vm.Name -ErrorAction SilentlyContinue
    foreach ($snap in $snaps) {
        $avhdxSize_GB = 0
        $avhdxCount   = 0
        $vmDir = Split-Path -Parent (Get-VMHardDiskDrive -VMName $vm.Name |
            Where-Object Path -ne $null | Select-Object -First 1 -ExpandProperty Path) `
            -ErrorAction SilentlyContinue

        if ($vmDir) {
            $avhdxFiles   = Get-ChildItem -Path $vmDir -Filter "*.avhdx" -ErrorAction SilentlyContinue
            $avhdxCount   = if ($avhdxFiles) { $avhdxFiles.Count } else { 0 }
            $avhdxSize_GB = [math]::Round(
                ($avhdxFiles | Measure-Object Length -Sum).Sum / 1GB, 2)
        }

        $ageDays = [math]::Round(((Get-Date) - $snap.CreationTime).TotalDays, 1)

        [PSCustomObject]@{
            VM           = $vm.Name
            SnapshotName = $snap.Name
            Type         = $snap.SnapshotType
            CreationTime = $snap.CreationTime.ToString('yyyy-MM-dd HH:mm')
            AgeDays      = $ageDays
            Parent       = $snap.ParentSnapshotName
            avhdx_Count  = $avhdxCount
            avhdx_GB     = $avhdxSize_GB
            AgeWarning   = if ($ageDays -gt 30) {"STALE >30d"}
                           elseif ($ageDays -gt 7) {"OLD >7d"}
                           else {"OK"}
        }
    }
}

if (-not $allCheckpoints) {
    Write-Host "No checkpoints found on any VM." -ForegroundColor Green
    exit 0
}

$allCheckpoints | Format-Table VM, SnapshotName, Type, CreationTime,
    AgeDays, avhdx_GB, AgeWarning -AutoSize

# ── 2. Stale Checkpoints ─────────────────────────────────────────────────────
Write-Host "`n=== Checkpoints Older Than 7 Days ===" -ForegroundColor Yellow
$stale = $allCheckpoints | Where-Object AgeDays -gt 7 | Sort-Object AgeDays -Descending
if ($stale) {
    $stale | Select-Object VM, SnapshotName, AgeDays, avhdx_GB, AgeWarning |
        Format-Table -AutoSize
} else {
    Write-Host "None found." -ForegroundColor Green
}

# ── 3. Disk Space Impact per VM ──────────────────────────────────────────────
Write-Host "`n=== Checkpoint Disk Space Impact per VM ===" -ForegroundColor Cyan
$allCheckpoints | Group-Object VM | ForEach-Object {
    [PSCustomObject]@{
        VM              = $_.Name
        TotalCheckpoints = $_.Count
        TotalavhdxGB    = ($_.Group | Measure-Object avhdx_GB -Maximum).Maximum
        OldestDays      = ($_.Group | Measure-Object AgeDays -Maximum).Maximum
    }
} | Sort-Object OldestDays -Descending | Format-Table -AutoSize
