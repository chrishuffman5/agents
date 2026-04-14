<#
.SYNOPSIS
    Windows Server Failover Clustering - Resource Groups and Dependencies
.DESCRIPTION
    Analyzes resource group configuration including dependency trees,
    preferred and possible owners, failover policy settings, restart
    policies, and surfaces common misconfigurations.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. Resource Group Status
        2. Preferred and Possible Owners
        3. Resource Dependency Chains
        4. Resource Restart Policies
        5. Configuration Issue Detection
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = ".",
    [string]$GroupFilter  = "*"
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    $nodes   = Get-ClusterNode -Cluster $ClusterName
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

$groups    = Get-ClusterGroup -Cluster $ClusterName | Where-Object Name -like $GroupFilter
$resources = Get-ClusterResource -Cluster $ClusterName

# ── 1. Resource Group Status ──────────────────────────────────────────────────
Write-Section "RESOURCE GROUP STATUS"
$groups | Select-Object Name, State, OwnerNode, Priority,
    @{N='FailoverThreshold';E={$_.FailoverThreshold}},
    @{N='FailoverPeriod(hrs)';E={$_.FailoverPeriod}},
    @{N='AutoFailback';E={
        switch ($_.AutoFailbackType) {
            0 { 'Prevent' }
            1 { 'Allow' }
            2 { 'Allow with Window' }
        }
    }} | Sort-Object State, Name | Format-Table -AutoSize

# ── 2. Preferred and Possible Owners ─────────────────────────────────────────
Write-Section "PREFERRED AND POSSIBLE OWNERS"
foreach ($group in $groups) {
    $preferred = (Get-ClusterOwnerNode -Group $group.Name -Cluster $ClusterName).OwnerNodes
    $groupRes  = $resources | Where-Object OwnerGroup -eq $group.Name

    Write-Host "`nGroup: $($group.Name) [$($group.State) on $($group.OwnerNode)]" -ForegroundColor White

    if ($preferred) {
        Write-Host "  Preferred Owners: $($preferred -join ' > ')" -ForegroundColor Yellow
    } else {
        Write-Host "  Preferred Owners: Any (none specified)" -ForegroundColor Gray
    }

    Write-Host "  Resources in group: $($groupRes.Count)"
    foreach ($res in $groupRes) {
        $possibleOwners = (Get-ClusterOwnerNode -Resource $res.Name -Cluster $ClusterName).OwnerNodes
        $ownerInfo = if ($possibleOwners.Count -eq $nodes.Count -or $possibleOwners.Count -eq 0) {
            "All nodes"
        } else {
            $possibleOwners -join ', '
        }
        Write-Host "    [$($res.State.ToString().PadRight(15))] $($res.Name) ($($res.ResourceType)) - Possible: $ownerInfo"
    }
}

# ── 3. Resource Dependency Chains ────────────────────────────────────────────
Write-Section "RESOURCE DEPENDENCY CHAINS"
foreach ($group in $groups) {
    $groupRes = $resources | Where-Object OwnerGroup -eq $group.Name
    Write-Host "`nGroup: $($group.Name)" -ForegroundColor White

    foreach ($res in $groupRes) {
        try {
            $deps = Get-ClusterResourceDependency -Resource $res.Name `
                -Cluster $ClusterName -ErrorAction SilentlyContinue
            if ($deps -and $deps.DependencyExpression) {
                Write-Host "  $($res.Name) depends on: $($deps.DependencyExpression)" -ForegroundColor Yellow
            }
        } catch { }
    }
}

# ── 4. Resource Restart Policies ─────────────────────────────────────────────
Write-Section "RESOURCE RESTART POLICIES"
foreach ($group in ($groups | Sort-Object Name)) {
    $groupRes = $resources | Where-Object OwnerGroup -eq $group.Name
    Write-Host "`nGroup: $($group.Name)" -ForegroundColor White

    foreach ($res in $groupRes) {
        try {
            $restartAction = switch ($res.RestartAction) {
                0 { 'Do Not Restart' }
                1 { 'Restart (no failover)' }
                2 { 'Restart then Failover' }
                default { $res.RestartAction }
            }
            Write-Host ("  {0,-40} Action={1}, Threshold={2}, Period={3}ms" -f `
                $res.Name, $restartAction, $res.RestartThreshold, $res.RestartPeriod)
        } catch {
            Write-Host "  $($res.Name) - policy unavailable"
        }
    }
}

# ── 5. Configuration Issue Detection ─────────────────────────────────────────
Write-Section "CONFIGURATION ISSUES"
$issues = @()

foreach ($group in $groups) {
    $preferred = (Get-ClusterOwnerNode -Group $group.Name -Cluster $ClusterName).OwnerNodes

    # Group not on preferred owner
    if ($preferred -and $preferred.Count -gt 0 -and $group.State -eq 'Online') {
        if ($group.OwnerNode -ne $preferred[0]) {
            $issues += "Group '$($group.Name)' on '$($group.OwnerNode)' but preferred is '$($preferred[0])'"
        }
    }

    # Group in failed state
    if ($group.State -eq 'Failed') {
        $issues += "Group '$($group.Name)' is in FAILED state"
    }

    # No preferred owners configured
    if ($preferred.Count -eq 0 -and $group.Name -notmatch 'Available Storage|Cluster Group') {
        $issues += "Group '$($group.Name)' has no preferred owner configured"
    }
}

if ($issues) {
    Write-Host "Issues Found:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
} else {
    Write-Host "No configuration issues detected." -ForegroundColor Green
}
