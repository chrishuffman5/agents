<#
.SYNOPSIS
    Windows Server Failover Clustering - CSV Health Monitor
.DESCRIPTION
    Reports Cluster Shared Volume status, coordinator node ownership,
    redirected I/O state, free space analysis, and ownership distribution.
    Flags volumes with low free space or active redirected I/O.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. CSV Volume Status
        2. Redirected I/O Summary
        3. Free Space Analysis
        4. Ownership Distribution
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [int]$FreeSpaceWarningPct  = 20,
    [int]$FreeSpaceCriticalPct = 10
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster: $_"
    exit 1
}

# ── 1. CSV Volume Status ─────────────────────────────────────────────────────
Write-Section "CSV VOLUME STATUS"
$csvs = Get-ClusterSharedVolume -Cluster $ClusterName

if (-not $csvs) {
    Write-Host "No Cluster Shared Volumes found on '$($cluster.Name)'." -ForegroundColor Yellow
    exit 0
}

foreach ($csv in $csvs) {
    $stateColor = switch ($csv.State) {
        'Online'      { 'Green' }
        'Partial'     { 'Yellow' }
        'Unavailable' { 'Red' }
        default       { 'Yellow' }
    }

    Write-Host "`n--- $($csv.Name) ---" -ForegroundColor White

    foreach ($volInfo in $csv.SharedVolumeInfo) {
        $totalGB = [math]::Round($volInfo.Partition.Size / 1GB, 2)
        $freeGB  = [math]::Round($volInfo.Partition.FreeSpace / 1GB, 2)
        $freePct = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

        $spaceColor = if ($freePct -le $FreeSpaceCriticalPct) { 'Red' }
                      elseif ($freePct -le $FreeSpaceWarningPct) { 'Yellow' }
                      else { 'Green' }

        Write-Host "  State:          " -NoNewline; Write-Host $csv.State -ForegroundColor $stateColor
        Write-Host "  Owner Node:     $($csv.OwnerNode)"
        Write-Host "  Mount Point:    $($volInfo.FriendlyVolumeName)"
        Write-Host "  Total Size:     $totalGB GB"
        Write-Host "  Free Space:     " -NoNewline
        Write-Host "$freeGB GB ($freePct%)" -ForegroundColor $spaceColor

        $redirected = $volInfo.RedirectedIOReason -ne 0
        Write-Host "  Redirected I/O: " -NoNewline
        if ($redirected) {
            Write-Host "YES - $($volInfo.RedirectedIOReason)" -ForegroundColor Red
        } else {
            Write-Host "No (Direct I/O)" -ForegroundColor Green
        }

        Write-Host "  Fault State:    $($volInfo.FaultState)"
        Write-Host "  Backup Mode:    $($volInfo.BackupState)"
    }
}

# ── 2. Redirected I/O Summary ────────────────────────────────────────────────
Write-Section "CSV REDIRECTED I/O SUMMARY"
$redirectedCSVs = $csvs | Where-Object {
    $_.SharedVolumeInfo | Where-Object { $_.RedirectedIOReason -ne 0 }
}

if ($redirectedCSVs) {
    Write-Host "[WARNING] CSVs with Redirected I/O:" -ForegroundColor Red
    foreach ($csv in $redirectedCSVs) {
        foreach ($volInfo in $csv.SharedVolumeInfo) {
            if ($volInfo.RedirectedIOReason -ne 0) {
                Write-Host "  $($csv.Name) - Reason: $($volInfo.RedirectedIOReason)" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "`nRedirected I/O Reason Codes:"
    Write-Host "  2  = NoDiskConnectivity      4  = FileSystemNotMounted"
    Write-Host "  8  = InMaintenance           16  = VolumeTooBig"
    Write-Host "  32 = BitLockerInitializing   64  = DiskTimeout"
} else {
    Write-Host "All CSVs operating in Direct I/O mode." -ForegroundColor Green
}

# ── 3. Free Space Analysis ───────────────────────────────────────────────────
Write-Section "CSV FREE SPACE ANALYSIS"
$spaceIssues = @()
foreach ($csv in $csvs) {
    foreach ($volInfo in $csv.SharedVolumeInfo) {
        $totalGB = [math]::Round($volInfo.Partition.Size / 1GB, 2)
        $freeGB  = [math]::Round($volInfo.Partition.FreeSpace / 1GB, 2)
        $freePct = if ($totalGB -gt 0) { [math]::Round(($freeGB / $totalGB) * 100, 1) } else { 0 }

        if ($freePct -le $FreeSpaceWarningPct) {
            $spaceIssues += [PSCustomObject]@{
                CSV       = $csv.Name
                TotalGB   = $totalGB
                FreeGB    = $freeGB
                FreePct   = $freePct
                Severity  = if ($freePct -le $FreeSpaceCriticalPct) { 'CRITICAL' } else { 'WARNING' }
            }
        }
    }
}

if ($spaceIssues) {
    Write-Host "[ALERT] CSVs with low free space:" -ForegroundColor Red
    $spaceIssues | Sort-Object FreePct | Format-Table -AutoSize
} else {
    Write-Host "All CSVs have adequate free space (>$FreeSpaceWarningPct%)." -ForegroundColor Green
}

# ── 4. Ownership Distribution ────────────────────────────────────────────────
Write-Section "CSV OWNERSHIP DISTRIBUTION"
$csvs | Group-Object OwnerNode |
    Select-Object Count, @{N='OwnerNode';E={$_.Name}} |
    Sort-Object Count -Descending | Format-Table -AutoSize
