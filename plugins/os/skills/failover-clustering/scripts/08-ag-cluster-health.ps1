<#
.SYNOPSIS
    Windows Server Failover Clustering - AG Cluster Health Check
.DESCRIPTION
    Inspects SQL Server Availability Group cluster resources, replica sync
    status, AG health state, listener configuration, and failover readiness
    for AGs hosted on Windows Server Failover Clustering.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering and SQL Server AG
    Safety  : Read-only. No modifications to cluster or SQL configuration.
    Sections:
        1. AG Cluster Resources
        2. AG Resource Groups
        3. AG Resource Parameters
        4. AG Listener Network Resources
        5. SQL Deep Inspection (optional, requires SqlServer module)
        6. Failover Readiness Summary
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName      = ".",
    [switch]$IncludeSQLDetail
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

# ── 1. AG Cluster Resources ──────────────────────────────────────────────────
Write-Section "AG CLUSTER RESOURCES"
$allResources = Get-ClusterResource -Cluster $ClusterName
$agResources  = $allResources | Where-Object ResourceType -eq 'SQL Server Availability Group'
$sqlResources = $allResources | Where-Object ResourceType -eq 'SQL Server'

if (-not $agResources) {
    Write-Host "No SQL Server Availability Group resources found." -ForegroundColor Yellow
    if ($sqlResources) {
        Write-Host "`nSQL Server FCI resources:" -ForegroundColor Yellow
        $sqlResources | Select-Object Name, State, OwnerGroup, OwnerNode | Format-Table -AutoSize
    }
    exit 0
}

Write-Host "Found $($agResources.Count) AG resource(s):" -ForegroundColor Green
$agResources | Select-Object Name, State, OwnerGroup, OwnerNode,
    @{N='RestartAction';E={$_.RestartAction}} | Format-Table -AutoSize

# ── 2. AG Resource Groups ────────────────────────────────────────────────────
Write-Section "AG RESOURCE GROUPS"
$agGroups = foreach ($ag in $agResources) {
    Get-ClusterGroup -Cluster $ClusterName -Name $ag.OwnerGroup -ErrorAction SilentlyContinue
}

$agGroups | Select-Object Name, State, OwnerNode,
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod(hrs)';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={
        switch ($_.AutoFailbackType) { 0{'Prevent'}; 1{'Allow'}; 2{'Windowed'} }
    }} | Format-Table -AutoSize

# ── 3. AG Resource Parameters ────────────────────────────────────────────────
Write-Section "AG RESOURCE PARAMETERS"
foreach ($ag in $agResources) {
    Write-Host "`nAG: $($ag.Name) [Group: $($ag.OwnerGroup)]" -ForegroundColor White
    $params = $ag | Get-ClusterParameter -ErrorAction SilentlyContinue
    if ($params) {
        $params | Select-Object Name, Value | Format-Table -AutoSize
    }

    $possibleOwners = (Get-ClusterOwnerNode -Resource $ag.Name -Cluster $ClusterName).OwnerNodes
    Write-Host "  Possible Owners: $($possibleOwners -join ', ')"
}

# ── 4. AG Listener Network Resources ────────────────────────────────────────
Write-Section "AG LISTENER NETWORK RESOURCES"
$ipResources = $allResources | Where-Object ResourceType -in @('IP Address','SQL IP Address')
$listenerIPs = $ipResources | Where-Object {
    $group = $_.OwnerGroup
    $agGroups | Where-Object Name -eq $group
}

if ($listenerIPs) {
    foreach ($ip in $listenerIPs) {
        $params = $ip | Get-ClusterParameter -ErrorAction SilentlyContinue
        $addr   = ($params | Where-Object Name -eq 'Address').Value
        $mask   = ($params | Where-Object Name -eq 'SubnetMask').Value
        $net    = ($params | Where-Object Name -eq 'Network').Value
        Write-Host "  $($ip.Name): $addr/$mask on '$net' [$($ip.State)] Group: $($ip.OwnerGroup)"
    }
} else {
    Write-Host "No AG listener IP resources found." -ForegroundColor Gray
}

# ── 5. SQL Deep Inspection ───────────────────────────────────────────────────
Write-Section "SQL DEEP INSPECTION"
if ($IncludeSQLDetail) {
    if (-not (Get-Module -Name SqlServer -ListAvailable)) {
        Write-Warning "SqlServer module not installed. Install with: Install-Module SqlServer"
    } else {
        Import-Module SqlServer -ErrorAction SilentlyContinue
        foreach ($node in (Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up')) {
            Write-Host "`n[Node: $($node.Name)]" -ForegroundColor White
            try {
                $agQuery = @"
SELECT ag.name AS AGName, ar.replica_server_name AS Replica,
       ar.availability_mode_desc AS Mode, ar.failover_mode_desc AS Failover,
       ars.role_desc AS Role, ars.synchronization_health_desc AS SyncHealth
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
ORDER BY ag.name, ar.replica_server_name
"@
                $results = Invoke-Sqlcmd -ServerInstance $node.Name `
                    -Query $agQuery -TrustServerCertificate -ErrorAction Stop
                if ($results) {
                    $results | Format-Table AGName, Replica, Role, Mode, SyncHealth -AutoSize

                    $unhealthy = $results | Where-Object { $_.SyncHealth -ne 'HEALTHY' }
                    if ($unhealthy) {
                        Write-Host "  [WARNING] Unhealthy replicas:" -ForegroundColor Red
                        $unhealthy | Select-Object AGName, Replica, SyncHealth | Format-Table -AutoSize
                    }
                }
            } catch {
                Write-Host "  [SQL connection failed: $_]" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "Skipped. Use -IncludeSQLDetail for AG replica/database sync status." -ForegroundColor Gray
}

# ── 6. Failover Readiness Summary ────────────────────────────────────────────
Write-Section "FAILOVER READINESS SUMMARY"
foreach ($ag in $agResources) {
    $group = Get-ClusterGroup -Cluster $ClusterName -Name $ag.OwnerGroup -ErrorAction SilentlyContinue
    $ready = $ag.State -eq 'Online' -and $group.State -eq 'Online'
    $preferredOwners = (Get-ClusterOwnerNode -Group $ag.OwnerGroup -Cluster $ClusterName).OwnerNodes

    Write-Host "`nAG: $($ag.Name)" -ForegroundColor White
    Write-Host "  Resource State:   $($ag.State)" -ForegroundColor $(
        if ($ag.State -eq 'Online') {'Green'} else {'Red'})
    Write-Host "  Group State:      $($group.State)" -ForegroundColor $(
        if ($group.State -eq 'Online') {'Green'} else {'Red'})
    Write-Host "  Current Owner:    $($ag.OwnerNode)"
    Write-Host "  Preferred Owners: $($preferredOwners -join ' > ')"
    Write-Host "  Failover-Ready:   $ready" -ForegroundColor $(
        if ($ready) {'Green'} else {'Red'})

    $possibleOwners = (Get-ClusterOwnerNode -Resource $ag.Name -Cluster $ClusterName).OwnerNodes
    $otherOwners = $possibleOwners | Where-Object { $_ -ne $ag.OwnerNode }
    if ($otherOwners) {
        Write-Host "  Failover Targets: $($otherOwners -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "  [WARNING] No failover targets (only one possible owner)" -ForegroundColor Red
    }
}
