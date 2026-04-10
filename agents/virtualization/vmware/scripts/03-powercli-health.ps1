# ==============================================================================
# PowerCLI Cluster Health Check
# ==============================================================================
# Connects to vCenter and checks cluster health: HA status, DRS status,
# alarm summary, host connection state, VM tools status, snapshot age,
# datastore capacity, and vSAN health (if applicable).
#
# Prerequisites: VMware.PowerCLI module installed
#
# Usage:
#   .\03-powercli-health.ps1 -VCenterServer "vcenter.corp.local"
#   .\03-powercli-health.ps1 -VCenterServer "vcenter.corp.local" -ClusterName "Production"
# ==============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VCenterServer,

    [Parameter(Mandatory = $false)]
    [string]$ClusterName
)

# --- Connect to vCenter ---
Write-Host "Connecting to vCenter: $VCenterServer" -ForegroundColor Cyan
try {
    Connect-VIServer -Server $VCenterServer -ErrorAction Stop | Out-Null
    Write-Host "Connected successfully.`n" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to vCenter: $_"
    exit 1
}

$divider = "=" * 72
$warnings = @()

# Get clusters
if ($ClusterName) {
    $clusters = Get-Cluster -Name $ClusterName -ErrorAction Stop
} else {
    $clusters = Get-Cluster
}

foreach ($cluster in $clusters) {
    Write-Host "$divider" -ForegroundColor Yellow
    Write-Host "CLUSTER: $($cluster.Name)" -ForegroundColor Yellow
    Write-Host "$divider" -ForegroundColor Yellow

    # --- HA Status ---
    Write-Host "`n[1] HIGH AVAILABILITY (HA)" -ForegroundColor Cyan
    $haConfig = $cluster.ExtensionData.Configuration.DasConfig
    Write-Host "  HA Enabled:              $($cluster.HAEnabled)"
    Write-Host "  Admission Control:       $($cluster.HAAdmissionControlEnabled)"
    Write-Host "  Host Monitoring:         $($haConfig.HostMonitoring)"
    Write-Host "  VM Monitoring:           $($haConfig.VmMonitoring)"
    Write-Host "  Failover Level:          $($haConfig.FailoverLevel)"

    if (-not $cluster.HAEnabled) {
        $warnings += "[WARN] Cluster '$($cluster.Name)': HA is DISABLED"
    }
    if (-not $cluster.HAAdmissionControlEnabled) {
        $warnings += "[WARN] Cluster '$($cluster.Name)': Admission Control is DISABLED"
    }

    # --- DRS Status ---
    Write-Host "`n[2] DISTRIBUTED RESOURCE SCHEDULER (DRS)" -ForegroundColor Cyan
    Write-Host "  DRS Enabled:             $($cluster.DrsEnabled)"
    Write-Host "  Automation Level:        $($cluster.DrsAutomationLevel)"

    if ($cluster.DrsEnabled) {
        $drsRecs = Get-DrsRecommendation -Cluster $cluster -ErrorAction SilentlyContinue
        $drsCount = if ($drsRecs) { $drsRecs.Count } else { 0 }
        Write-Host "  Pending Recommendations: $drsCount"
        if ($drsCount -gt 0) {
            $warnings += "[INFO] Cluster '$($cluster.Name)': $drsCount pending DRS recommendations"
        }

        # DRS Rules
        $rules = Get-DrsRule -Cluster $cluster -ErrorAction SilentlyContinue
        if ($rules) {
            Write-Host "  DRS Rules:"
            foreach ($rule in $rules) {
                $ruleType = if ($rule.KeepTogether) { "Affinity" } else { "Anti-Affinity" }
                Write-Host "    - $($rule.Name) ($ruleType, Enabled=$($rule.Enabled))"
            }
        }
    }

    # --- Host Health ---
    Write-Host "`n[3] HOST HEALTH" -ForegroundColor Cyan
    $clusterHosts = Get-VMHost -Location $cluster
    foreach ($vmhost in $clusterHosts) {
        $cpuPct = [math]::Round(($vmhost.CpuUsageMhz / $vmhost.CpuTotalMhz) * 100, 1)
        $memPct = [math]::Round(($vmhost.MemoryUsageGB / $vmhost.MemoryTotalGB) * 100, 1)
        $vmCount = ($vmhost | Get-VM).Count

        $status = "OK"
        if ($vmhost.ConnectionState -ne "Connected") {
            $status = "PROBLEM"
            $warnings += "[CRIT] Host '$($vmhost.Name)': State is $($vmhost.ConnectionState)"
        }
        if ($cpuPct -gt 90) {
            $warnings += "[WARN] Host '$($vmhost.Name)': CPU at ${cpuPct}%"
        }
        if ($memPct -gt 90) {
            $warnings += "[WARN] Host '$($vmhost.Name)': Memory at ${memPct}%"
        }

        Write-Host "  $($vmhost.Name)"
        Write-Host "    State: $($vmhost.ConnectionState)  CPU: ${cpuPct}%  Memory: ${memPct}%  VMs: $vmCount"
    }

    # --- VMware Tools Status ---
    Write-Host "`n[4] VMWARE TOOLS STATUS" -ForegroundColor Cyan
    $clusterVMs = Get-VM -Location $cluster | Where-Object { $_.PowerState -eq "PoweredOn" }
    $toolsOutdated = $clusterVMs | Where-Object {
        $_.ExtensionData.Guest.ToolsVersionStatus -notin @("guestToolsCurrent", "guestToolsUnmanaged")
    }
    $toolsNotRunning = $clusterVMs | Where-Object {
        $_.ExtensionData.Guest.ToolsRunningStatus -ne "guestToolsRunning"
    }

    Write-Host "  Powered-On VMs:          $($clusterVMs.Count)"
    Write-Host "  Tools Outdated/Missing:  $($toolsOutdated.Count)"
    Write-Host "  Tools Not Running:       $($toolsNotRunning.Count)"

    if ($toolsOutdated.Count -gt 0) {
        $warnings += "[WARN] Cluster '$($cluster.Name)': $($toolsOutdated.Count) VMs with outdated/missing Tools"
        Write-Host "  Outdated VMs:"
        $toolsOutdated | Select-Object Name,
            @{N="ToolsStatus"; E={$_.ExtensionData.Guest.ToolsVersionStatus}} |
            ForEach-Object { Write-Host "    - $($_.Name): $($_.ToolsStatus)" }
    }

    # --- Snapshot Health ---
    Write-Host "`n[5] SNAPSHOT HEALTH" -ForegroundColor Cyan
    $allVMs = Get-VM -Location $cluster
    $snapshots = $allVMs | Get-Snapshot -ErrorAction SilentlyContinue
    $oldSnaps = $snapshots | Where-Object { $_.Created -lt (Get-Date).AddDays(-3) }

    Write-Host "  Total Snapshots:         $($snapshots.Count)"
    Write-Host "  Snapshots > 3 days old:  $($oldSnaps.Count)"

    if ($oldSnaps.Count -gt 0) {
        $warnings += "[WARN] Cluster '$($cluster.Name)': $($oldSnaps.Count) snapshots older than 3 days"
        $oldSnaps | Select-Object VM, Name, Created,
            @{N="AgeDays"; E={[math]::Round(((Get-Date) - $_.Created).TotalDays, 1)}},
            @{N="SizeGB"; E={[math]::Round($_.SizeGB, 2)}} |
            Sort-Object AgeDays -Descending |
            ForEach-Object { Write-Host "    - $($_.VM): $($_.Name) ($($_.AgeDays) days, $($_.SizeGB) GB)" }
    }

    # --- Datastore Health ---
    Write-Host "`n[6] DATASTORE HEALTH" -ForegroundColor Cyan
    $datastores = Get-Datastore -VMHost ($clusterHosts) | Sort-Object -Unique -Property Name
    foreach ($ds in $datastores) {
        $usedPct = [math]::Round((1 - ($ds.FreeSpaceGB / $ds.CapacityGB)) * 100, 1)
        $freeGB = [math]::Round($ds.FreeSpaceGB, 1)

        $marker = ""
        if ($usedPct -gt 90) {
            $marker = " [CRITICAL]"
            $warnings += "[CRIT] Datastore '$($ds.Name)': ${usedPct}% used ($freeGB GB free)"
        } elseif ($usedPct -gt 80) {
            $marker = " [WARNING]"
            $warnings += "[WARN] Datastore '$($ds.Name)': ${usedPct}% used ($freeGB GB free)"
        }

        Write-Host "  $($ds.Name): ${usedPct}% used, $freeGB GB free${marker}"
    }

    # --- vSAN Health (if applicable) ---
    if ($cluster.VsanEnabled) {
        Write-Host "`n[7] vSAN HEALTH" -ForegroundColor Cyan
        Write-Host "  vSAN Enabled: True"
        try {
            $vsanConfig = Get-VsanClusterConfiguration -Cluster $cluster -ErrorAction Stop
            Write-Host "  Space Efficiency:  $($vsanConfig.SpaceEfficiencyEnabled)"
            Write-Host "  Encryption:        $($vsanConfig.EncryptionEnabled)"
            Write-Host "  Stretched Cluster: $($vsanConfig.StretchedClusterEnabled)"
        } catch {
            Write-Host "  (Could not retrieve vSAN configuration details)"
        }
    }

    # --- Active Alarms ---
    Write-Host "`n[8] ACTIVE ALARMS" -ForegroundColor Cyan
    $alarms = $cluster.ExtensionData.TriggeredAlarmState
    if ($alarms -and $alarms.Count -gt 0) {
        Write-Host "  Active alarms: $($alarms.Count)"
        $warnings += "[WARN] Cluster '$($cluster.Name)': $($alarms.Count) active alarms"
        foreach ($alarm in $alarms) {
            $alarmDef = Get-View $alarm.Alarm -Property Info.Name -ErrorAction SilentlyContinue
            $entity = Get-View $alarm.Entity -Property Name -ErrorAction SilentlyContinue
            $alarmName = if ($alarmDef) { $alarmDef.Info.Name } else { "Unknown" }
            $entityName = if ($entity) { $entity.Name } else { "Unknown" }
            Write-Host "    - $alarmName on $entityName ($($alarm.OverallStatus))"
        }
    } else {
        Write-Host "  No active alarms." -ForegroundColor Green
    }
}

# --- Health Summary ---
Write-Host "`n$divider" -ForegroundColor Yellow
Write-Host "HEALTH CHECK SUMMARY" -ForegroundColor Yellow
Write-Host $divider -ForegroundColor Yellow

if ($warnings.Count -eq 0) {
    Write-Host "All checks passed. No warnings or critical issues." -ForegroundColor Green
} else {
    $critCount = ($warnings | Where-Object { $_ -match "^\[CRIT\]" }).Count
    $warnCount = ($warnings | Where-Object { $_ -match "^\[WARN\]" }).Count
    $infoCount = ($warnings | Where-Object { $_ -match "^\[INFO\]" }).Count

    Write-Host "Critical: $critCount  Warnings: $warnCount  Info: $infoCount`n"
    foreach ($w in $warnings) {
        $color = if ($w -match "^\[CRIT\]") { "Red" } elseif ($w -match "^\[WARN\]") { "Yellow" } else { "Cyan" }
        Write-Host "  $w" -ForegroundColor $color
    }
}

Write-Host "`nReport complete: $(Get-Date)" -ForegroundColor Cyan

# Disconnect
Disconnect-VIServer -Server * -Confirm:$false
