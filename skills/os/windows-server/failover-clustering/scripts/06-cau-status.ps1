<#
.SYNOPSIS
    Windows Server Failover Clustering - CAU Status and Compliance
.DESCRIPTION
    Reports Cluster-Aware Updating role configuration, last run results,
    per-node update compliance, and scans for available updates. Use for
    verifying patch compliance across cluster nodes.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. CAU Cluster Role Configuration
        2. Current CAU Run Status
        3. Recent CAU Run History
        4. Per-Node Update Compliance
        5. CAU Scan (Available Updates)
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName     = ".",
    [int]$ReportHistoryCount = 5
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
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

# ── 1. CAU Cluster Role ──────────────────────────────────────────────────────
Write-Section "CAU CLUSTER ROLE"
try {
    $cauRole = Get-CauClusterRole -ClusterName $cluster.Name -ErrorAction Stop
    Write-Host "CAU Role Status: Configured" -ForegroundColor Green
    $cauRole | Select-Object ClusterName,
        @{N='Plugins';E={$_.CauPluginName -join ', '}},
        @{N='Schedule';E={"$($_.DaysOfWeek) every $($_.IntervalWeeks) week(s)"}},
        StartTime, MaxFailedNodes, MaxRetriesPerNode,
        RequireAllNodesConnected, EnableFirewallRules | Format-List
} catch {
    Write-Host "CAU Cluster Role: Not configured (self-updating mode not enabled)" -ForegroundColor Yellow
    Write-Host "To enable: Add-CauClusterRole -ClusterName $($cluster.Name) -DaysOfWeek Saturday -StartTime '02:00' -Force"
}

# ── 2. Current CAU Run Status ─────────────────────────────────────────────────
Write-Section "CURRENT CAU RUN STATUS"
try {
    $currentRun = Get-CauRun -ClusterName $cluster.Name -ErrorAction Stop
    if ($currentRun) {
        Write-Host "CAU Run IN PROGRESS:" -ForegroundColor Yellow
        $currentRun | Select-Object ClusterName, RunStartTime,
            CurrentOrMostRecentNode, NumberOfNodeJobs,
            NumberOfCompleted, NumberOfFailed | Format-List
    } else {
        Write-Host "No CAU run currently in progress." -ForegroundColor Green
    }
} catch {
    Write-Host "No active CAU run (or CAU module not available)." -ForegroundColor Gray
}

# ── 3. Recent CAU Run History ────────────────────────────────────────────────
Write-Section "RECENT CAU RUN HISTORY (Last $ReportHistoryCount)"
try {
    $reports = Get-CauReport -ClusterName $cluster.Name -ErrorAction Stop |
        Sort-Object RunStartTime -Descending |
        Select-Object -First $ReportHistoryCount

    if ($reports) {
        $reports | Select-Object RunStartTime, RunEndTime,
            @{N='Duration';E={
                if ($_.RunEndTime) {
                    "$([math]::Round(($_.RunEndTime - $_.RunStartTime).TotalMinutes, 1)) min"
                } else { 'In Progress' }
            }},
            @{N='Result';E={$_.RunResult}},
            @{N='UpdatesInstalled';E={
                ($_.NodeResults.UpdatesInstalled | Measure-Object -Sum).Sum
            }},
            @{N='NodesFailed';E={
                ($_.NodeResults | Where-Object UpdateInstallResult -eq 'Failed').Count
            }} | Format-Table -AutoSize

        $latest = $reports | Select-Object -First 1
        Write-Host "Most Recent Run - Per-Node Details:" -ForegroundColor Yellow
        if ($latest.NodeResults) {
            $latest.NodeResults | Select-Object NodeName, UpdateInstallResult,
                UpdatesDownloaded, UpdatesInstalled,
                @{N='Rebooted';E={$_.NodeRebootRequired}} | Format-Table -AutoSize
        }
    } else {
        Write-Host "No CAU run history found." -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Could not retrieve CAU history: $_"
}

# ── 4. Per-Node Update Compliance ────────────────────────────────────────────
Write-Section "PER-NODE UPDATE COMPLIANCE"
$upNodes = Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up'
foreach ($node in $upNodes) {
    Write-Host "`n[$($node.Name)]" -ForegroundColor White
    try {
        $session = New-CimSession -ComputerName $node.Name -ErrorAction Stop
        $osInfo  = Get-CimInstance Win32_OperatingSystem -CimSession $session
        Write-Host "  OS:          $($osInfo.Caption) Build $($osInfo.BuildNumber)"
        Write-Host "  Last Reboot: $($osInfo.LastBootUpTime)"
        Remove-CimSession $session
    } catch {
        Write-Host "  [Could not connect via CIM: $_]" -ForegroundColor Red
    }
}

# ── 5. CAU Scan ──────────────────────────────────────────────────────────────
Write-Section "CAU SCAN (AVAILABLE UPDATES)"
Write-Host "Scanning for available updates (this may take several minutes)..." -ForegroundColor Yellow
try {
    $scanResult = Invoke-CauScan -ClusterName $cluster.Name `
        -CauPluginName Microsoft.WindowsUpdatePlugin -ErrorAction Stop
    if ($scanResult) {
        $scanResult | Group-Object NodeName | ForEach-Object {
            Write-Host "`n[$($_.Name)] - $($_.Count) update(s) available:" -ForegroundColor Yellow
            $_.Group | Select-Object Title, KBArticleIDs | Format-Table -AutoSize
        }
    } else {
        Write-Host "All nodes are up to date." -ForegroundColor Green
    }
} catch {
    Write-Warning "CAU scan skipped or failed: $_"
}
