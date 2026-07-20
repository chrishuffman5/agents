<#
.SYNOPSIS
    Windows Server Failover Clustering - Network Health Analysis
.DESCRIPTION
    Reports cluster networks, network interfaces per node, heartbeat
    configuration, live migration network assignment, and cross-subnet
    settings. Identifies network role misconfigurations and failed interfaces.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. Cluster Heartbeat Settings
        2. Cluster Networks
        3. Cluster Network Interfaces (Per Node)
        4. Network Role Analysis
        5. Live Migration Network Configuration
        6. IP Resource Network Assignments
#>

#Requires -Module FailoverClusters

param(
    [string]$ClusterName = "."
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

$roleNames = @{
    0 = 'None'
    1 = 'Cluster Only (Heartbeat)'
    2 = 'Client Access Only'
    3 = 'All (Cluster + Client)'
}

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

# ── 1. Heartbeat Settings ────────────────────────────────────────────────────
Write-Section "CLUSTER HEARTBEAT SETTINGS"
$cluster | Select-Object Name,
    SameSubnetDelay, SameSubnetThreshold,
    CrossSubnetDelay, CrossSubnetThreshold,
    RouteHistoryLength | Format-List

# ── 2. Cluster Networks ──────────────────────────────────────────────────────
Write-Section "CLUSTER NETWORKS"
$networks = Get-ClusterNetwork -Cluster $ClusterName
$networks | Select-Object Name, State,
    @{N='Role';E={"$($_.Role) - $($roleNames[[int]$_.Role])"}},
    @{N='Metric';E={$_.Metric}}, Address, AddressMask |
    Sort-Object Metric | Format-Table -AutoSize

$downNetworks = $networks | Where-Object { $_.State -ne 'Up' }
if ($downNetworks) {
    Write-Host "`n[WARNING] Networks in non-Up state:" -ForegroundColor Red
    $downNetworks | Select-Object Name, State, Role | Format-Table -AutoSize
}

# ── 3. Network Interfaces (Per Node) ─────────────────────────────────────────
Write-Section "CLUSTER NETWORK INTERFACES (Per Node)"
$interfaces = Get-ClusterNetworkInterface -Cluster $ClusterName
$interfaces | Select-Object Node, Name, Network, State,
    @{N='IPv4Address';E={$_.IPv4Addresses}},
    Adapter |
    Sort-Object Node, Network | Format-Table -AutoSize

$failedIf = $interfaces | Where-Object { $_.State -ne 'Up' }
if ($failedIf) {
    Write-Host "`n[ALERT] Network Interfaces Not Up:" -ForegroundColor Red
    $failedIf | Select-Object Node, Name, Network, State | Format-Table -AutoSize
}

# ── 4. Network Role Analysis ─────────────────────────────────────────────────
Write-Section "NETWORK ROLE ANALYSIS"
$heartbeatNets = $networks | Where-Object { $_.Role -in @(1, 3) }
$clientNets    = $networks | Where-Object { $_.Role -in @(2, 3) }
$unusedNets    = $networks | Where-Object { $_.Role -eq 0 }

Write-Host "Heartbeat-capable networks: $($heartbeatNets.Count)" -ForegroundColor Yellow
$heartbeatNets | Select-Object Name,
    @{N='Role';E={$roleNames[[int]$_.Role]}}, Metric | Format-Table -AutoSize

Write-Host "Client-access networks: $($clientNets.Count)" -ForegroundColor Yellow
$clientNets | Select-Object Name,
    @{N='Role';E={$roleNames[[int]$_.Role]}}, Metric | Format-Table -AutoSize

if ($unusedNets) {
    Write-Host "Unused networks (Role=None): $($unusedNets.Count)" -ForegroundColor Gray
    $unusedNets | Select-Object Name, Metric | Format-Table -AutoSize
}

# ── 5. Live Migration Network Configuration ──────────────────────────────────
Write-Section "LIVE MIGRATION NETWORK CONFIGURATION"
foreach ($node in (Get-ClusterNode -Cluster $ClusterName | Where-Object State -eq 'Up')) {
    try {
        $vmHost = Get-VMHost -ComputerName $node.Name -ErrorAction Stop
        Write-Host "`n[$($node.Name)]" -ForegroundColor Green
        $vmHost | Select-Object VirtualMachineMigrationEnabled,
            UseAnyNetworkForMigration, MaximumVirtualMachineMigrations,
            MaximumStorageMigrations, VirtualMachineMigrationAuthenticationType |
            Format-List
    } catch {
        Write-Host "  [Hyper-V not available on $($node.Name)]" -ForegroundColor Gray
    }
}

# ── 6. IP Resource Network Assignments ────────────────────────────────────────
Write-Section "IP RESOURCE NETWORK ASSIGNMENTS"
$ipResources = Get-ClusterResource -Cluster $ClusterName |
    Where-Object ResourceType -eq 'IP Address'

foreach ($ip in $ipResources) {
    $props = $ip | Get-ClusterParameter -ErrorAction SilentlyContinue
    $addr  = ($props | Where-Object Name -eq 'Address').Value
    $mask  = ($props | Where-Object Name -eq 'SubnetMask').Value
    $net   = ($props | Where-Object Name -eq 'Network').Value
    Write-Host "$($ip.Name): $addr / $mask on '$net' [Group: $($ip.OwnerGroup)]"
}
