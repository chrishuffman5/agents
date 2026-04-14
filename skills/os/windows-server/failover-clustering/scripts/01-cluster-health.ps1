<#
.SYNOPSIS
    Windows Server Failover Clustering - Cluster Health Overview
.DESCRIPTION
    Retrieves cluster node status, resource group health, individual resource
    states, and recent cluster events. Designed for rapid health assessment
    of Windows Server Failover Clusters.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. Cluster Overview
        2. Cluster Nodes
        3. Cluster Groups (Roles)
        4. Cluster Resources
        5. Recent Cluster Events
        6. Health Summary
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [int]$EventLookbackMinutes = 60
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
    Write-Error "Failed to connect to cluster '$ClusterName': $_"
    exit 1
}

# ── 1. Cluster Overview ──────────────────────────────────────────────────────
Write-Section "CLUSTER OVERVIEW"
$cluster | Select-Object `
    Name, Domain,
    @{N='QuorumType';E={$_.QuorumType}},
    @{N='QuorumResource';E={$_.QuorumResourceName}},
    @{N='FunctionalLevel';E={$_.ClusterFunctionalLevel}},
    SharedVolumesRoot, BlockCacheSize, DynamicQuorum,
    SameSubnetDelay, SameSubnetThreshold,
    CrossSubnetDelay, CrossSubnetThreshold | Format-List

# ── 2. Cluster Nodes ─────────────────────────────────────────────────────────
Write-Section "CLUSTER NODES"
$nodes = Get-ClusterNode -Cluster $ClusterName
$nodes | Select-Object `
    Name, State,
    @{N='NodeWeight';E={$_.NodeWeight}},
    @{N='DynamicWeight';E={$_.DynamicWeight}},
    @{N='StatusInfo';E={$_.StatusInformation}},
    DrainStatus,
    @{N='Groups';E={(Get-ClusterGroup -Cluster $ClusterName |
        Where-Object OwnerNode -eq $_.Name).Count}} | Format-Table -AutoSize

$downNodes = $nodes | Where-Object { $_.State -ne 'Up' }
if ($downNodes) {
    Write-Host "`n[WARNING] Unhealthy Nodes:" -ForegroundColor Red
    $downNodes | Select-Object Name, State, StatusInformation | Format-Table -AutoSize
}

# ── 3. Cluster Groups (Roles) ────────────────────────────────────────────────
Write-Section "CLUSTER GROUPS (ROLES)"
$groups = Get-ClusterGroup -Cluster $ClusterName
$groups | Select-Object `
    Name, State, OwnerNode,
    @{N='Priority';E={$_.Priority}},
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={$_.AutoFailbackType}} |
    Sort-Object State, Name | Format-Table -AutoSize

$failedGroups = $groups | Where-Object { $_.State -notin @('Online','Partially Online') }
if ($failedGroups) {
    Write-Host "`n[ALERT] Groups Not Fully Online:" -ForegroundColor Red
    $failedGroups | Select-Object Name, State, OwnerNode | Format-Table -AutoSize
}

# ── 4. Cluster Resources ─────────────────────────────────────────────────────
Write-Section "CLUSTER RESOURCES"
$resources = Get-ClusterResource -Cluster $ClusterName
$resources | Select-Object `
    Name, State, ResourceType, OwnerGroup,
    @{N='OwnerNode';E={$_.OwnerNode}} |
    Sort-Object State, ResourceType, Name | Format-Table -AutoSize

$failedResources = $resources | Where-Object { $_.State -eq 'Failed' }
if ($failedResources) {
    Write-Host "`n[ALERT] Failed Resources:" -ForegroundColor Red
    $failedResources | Select-Object Name, ResourceType, OwnerGroup, OwnerNode |
        Format-Table -AutoSize
}

# ── 5. Recent Cluster Events ─────────────────────────────────────────────────
Write-Section "RECENT CLUSTER EVENTS (Last $EventLookbackMinutes Minutes)"
$since = (Get-Date).AddMinutes(-$EventLookbackMinutes)
try {
    $events = Get-WinEvent -LogName 'Microsoft-Windows-FailoverClustering/Operational' `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.Level -le 3 } |
        Select-Object TimeCreated, Id, LevelDisplayName, Message |
        Sort-Object TimeCreated -Descending

    if ($events) {
        Write-Host "Top 5 Recent Error/Warning Events:" -ForegroundColor Yellow
        $events | Select-Object -First 5 | Format-List TimeCreated, Id, LevelDisplayName, Message
    } else {
        Write-Host "No errors or warnings in the last $EventLookbackMinutes minutes." -ForegroundColor Green
    }
} catch {
    Write-Warning "Could not retrieve cluster events: $_"
}

# ── 6. Health Summary ────────────────────────────────────────────────────────
Write-Section "HEALTH SUMMARY"
$totalNodes   = $nodes.Count
$onlineNodes  = ($nodes | Where-Object State -eq 'Up').Count
$totalGroups  = $groups.Count
$onlineGroups = ($groups | Where-Object State -eq 'Online').Count
$totalRes     = $resources.Count
$onlineRes    = ($resources | Where-Object State -eq 'Online').Count

Write-Host "Nodes:     $onlineNodes/$totalNodes online" -ForegroundColor $(
    if ($onlineNodes -eq $totalNodes) {'Green'} else {'Red'})
Write-Host "Groups:    $onlineGroups/$totalGroups online" -ForegroundColor $(
    if ($onlineGroups -eq $totalGroups) {'Green'} else {'Yellow'})
Write-Host "Resources: $onlineRes/$totalRes online" -ForegroundColor $(
    if ($onlineRes -eq $totalRes) {'Green'} else {'Yellow'})
