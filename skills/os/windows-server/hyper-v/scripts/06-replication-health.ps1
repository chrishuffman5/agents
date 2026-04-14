<#
.SYNOPSIS
    Windows Server Hyper-V - Replication Health Report
.DESCRIPTION
    Audits all replicated VMs on the local host. Reports replication state,
    health, last successful replication time, RPO compliance, and pending
    replication lag. Suitable for daily DR readiness checks.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Hyper-V role installed
    Safety  : Read-only. No modifications to system configuration.
    Sections:
        1. Replication Status Overview
        2. Critical / Warning Items
        3. Detailed Replication Statistics
        4. Replica Server Configuration
#>

#Requires -Modules Hyper-V
#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Host "=== Hyper-V Replication Health Report ===" -ForegroundColor Cyan
Write-Host "Host: $env:COMPUTERNAME  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"

$replVMs = Get-VMReplication -ErrorAction SilentlyContinue

if (-not $replVMs) {
    Write-Host "No replication relationships found on this host." -ForegroundColor Yellow
    exit 0
}

# ── 1. Replication Status Overview ────────────────────────────────────────────
$report = $replVMs | ForEach-Object {
    $r = $_
    $lag = $null
    $rpoViolation = $false

    if ($r.LastReplicationTime) {
        $lag = (Get-Date) - $r.LastReplicationTime
        $rpoViolation = ($lag.TotalSeconds -gt ($r.ReplicationFrequency * 2))
    }

    $stats = Measure-VMReplication -VMName $r.VMName -ErrorAction SilentlyContinue

    [PSCustomObject]@{
        VMName          = $r.VMName
        Mode            = $r.Mode
        State           = $r.State
        Health          = $r.Health
        ReplicaServer   = $r.ReplicaServerName
        FrequencySec    = $r.ReplicationFrequency
        LastReplication = if ($r.LastReplicationTime) {
            $r.LastReplicationTime.ToString('yyyy-MM-dd HH:mm:ss')} else {"Never"}
        LagMinutes      = if ($lag) {[math]::Round($lag.TotalMinutes, 1)} else {"N/A"}
        RPO_Violation   = $rpoViolation
        RecoveryPoints  = $r.RecoveryHistory
        Compression     = $r.CompressionEnabled
        AvgLatency_ms   = if ($stats) {$stats.AverageReplicationLatency} else {"N/A"}
        PendingSize_MB  = if ($stats) {
            [math]::Round($stats.PendingReplicationSize / 1MB, 1)} else {"N/A"}
    }
}

$report | Format-Table VMName, Mode, State, Health, LagMinutes,
    RPO_Violation, RecoveryPoints -AutoSize

# ── 2. Critical / Warning Items ──────────────────────────────────────────────
Write-Host "`n=== Critical / Warning Items ===" -ForegroundColor Yellow
$critical = $report | Where-Object {
    $_.Health -ne 'Normal' -or $_.RPO_Violation -eq $true -or
    $_.State -notin 'Replicating','Enabled'
}

if ($critical) {
    $critical | Format-Table VMName, Mode, State, Health, LagMinutes, RPO_Violation -AutoSize
} else {
    Write-Host "All replication relationships are healthy." -ForegroundColor Green
}

# ── 3. Detailed Statistics ────────────────────────────────────────────────────
Write-Host "`n=== Detailed Replication Statistics ===" -ForegroundColor Cyan
$report | Format-List VMName, Mode, State, Health, FrequencySec,
    LastReplication, LagMinutes, AvgLatency_ms, PendingSize_MB,
    RecoveryPoints, Compression

# ── 4. Replica Server Configuration ──────────────────────────────────────────
Write-Host "`n=== Replica Server Configuration ===" -ForegroundColor Cyan
$replicaConfig = Get-VMReplicationServer -ErrorAction SilentlyContinue
if ($replicaConfig -and $replicaConfig.ReplicationEnabled) {
    $replicaConfig | Select-Object ReplicationEnabled, AllowedAuthenticationType,
        KerberosAuthorizationPort, CertificateAuthorizationPort,
        MonitoringInterval, MonitoringStartTime | Format-List
} else {
    Write-Host "This host is not configured as a replica server." -ForegroundColor Gray
}
