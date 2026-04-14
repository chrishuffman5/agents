<#
.SYNOPSIS
    Windows Server Failover Clustering - Quorum and Witness Health
.DESCRIPTION
    Reports quorum model, witness type and accessibility, node vote weights,
    dynamic quorum state, and calculates current quorum margin to determine
    how many additional node failures the cluster can survive.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only. No modifications to cluster configuration.
    Sections:
        1. Quorum Configuration
        2. Witness Details
        3. Node Vote Status
        4. Quorum Math
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

try {
    $cluster = Get-Cluster -Name $ClusterName -ErrorAction Stop
    $nodes   = Get-ClusterNode -Cluster $ClusterName
} catch {
    Write-Error "Cannot connect to cluster '$ClusterName': $_"
    exit 1
}

# ── 1. Quorum Configuration ──────────────────────────────────────────────────
Write-Section "QUORUM CONFIGURATION"
$quorum = Get-ClusterQuorum -Cluster $ClusterName
$quorum | Select-Object Cluster, QuorumResource, QuorumType | Format-List

Write-Host "Dynamic Quorum Enabled: $($cluster.DynamicQuorum)" -ForegroundColor $(
    if ($cluster.DynamicQuorum -eq 1) {'Green'} else {'Yellow'})

# ── 2. Witness Details ────────────────────────────────────────────────────────
Write-Section "WITNESS DETAILS"
switch ($quorum.QuorumType) {
    'NodeMajority' {
        Write-Host "Quorum Type: Node Majority (no witness)" -ForegroundColor Cyan
        Write-Host "Relies entirely on node votes."
        if ($nodes.Count % 2 -eq 0) {
            Write-Host "[WARNING] Even node count ($($nodes.Count)) with no witness - add a witness." -ForegroundColor Yellow
        }
    }
    'NodeAndDiskMajority' {
        Write-Host "Quorum Type: Node and Disk Majority" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName `
            -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            Write-Host "Witness Disk Resource: $($witnessRes.Name)"
            Write-Host "Witness Disk State:    $($witnessRes.State)" -ForegroundColor $(
                if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})
            Write-Host "Witness Disk Owner:    $($witnessRes.OwnerNode)"
        } else {
            Write-Host "[ERROR] Witness disk resource not found." -ForegroundColor Red
        }
    }
    'NodeAndFileShareMajority' {
        Write-Host "Quorum Type: Node and File Share Majority" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName `
            -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            $params    = $witnessRes | Get-ClusterParameter -ErrorAction SilentlyContinue
            $sharePath = ($params | Where-Object Name -eq 'SharePath').Value
            Write-Host "Witness Share Path:    $sharePath"

            if ($sharePath) {
                $accessible = Test-Path $sharePath -ErrorAction SilentlyContinue
                Write-Host "Share Accessible:      $accessible" -ForegroundColor $(
                    if ($accessible) {'Green'} else {'Red'})
            }
            Write-Host "Witness Resource State: $($witnessRes.State)" -ForegroundColor $(
                if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})
        }
    }
    'Majority' {
        Write-Host "Quorum Type: Majority (may include Cloud Witness)" -ForegroundColor Cyan
        $witnessRes = Get-ClusterResource -Cluster $ClusterName `
            -Name $quorum.QuorumResource -ErrorAction SilentlyContinue
        if ($witnessRes) {
            Write-Host "Witness Resource: $($witnessRes.Name) [$($witnessRes.ResourceType)]"
            Write-Host "Witness State:    $($witnessRes.State)" -ForegroundColor $(
                if ($witnessRes.State -eq 'Online') {'Green'} else {'Red'})

            if ($witnessRes.ResourceType -eq 'Cloud Witness') {
                $params      = $witnessRes | Get-ClusterParameter
                $accountName = ($params | Where-Object Name -eq 'AccountName').Value
                $endpoint    = ($params | Where-Object Name -eq 'EndpointInfo').Value
                Write-Host "Azure Storage Account: $accountName"
                Write-Host "Endpoint:              $endpoint"
            }
        }
    }
}

# ── 3. Node Vote Status ──────────────────────────────────────────────────────
Write-Section "NODE VOTE STATUS"
$voteData = foreach ($node in $nodes) {
    [PSCustomObject]@{
        NodeName      = $node.Name
        State         = $node.State
        NodeWeight    = $node.NodeWeight
        DynamicWeight = $node.DynamicWeight
        Vote          = if ($node.DynamicWeight -eq 1) { 'Voting' } else { 'NOT Voting' }
    }
}
$voteData | Format-Table -AutoSize

# ── 4. Quorum Math ───────────────────────────────────────────────────────────
Write-Section "QUORUM MATH"
$activeVotes  = ($voteData | Where-Object { $_.DynamicWeight -eq 1 }).Count
$witnessVote  = if ($quorum.QuorumType -ne 'NodeMajority') { 1 } else { 0 }
$totalVotes   = $activeVotes + $witnessVote
$quorumNeeded = [math]::Floor($totalVotes / 2) + 1
$margin       = $activeVotes + $witnessVote - $quorumNeeded

Write-Host "Active Node Votes:     $activeVotes"
Write-Host "Witness Vote:          $witnessVote"
Write-Host "Total Possible Votes:  $totalVotes"
Write-Host "Votes Needed (quorum): $quorumNeeded"
Write-Host "Current Quorum Margin: $margin vote(s) above threshold" -ForegroundColor $(
    if ($margin -le 1) {'Yellow'} else {'Green'})

$canSurvive = ($activeVotes + $witnessVote - 1) -ge $quorumNeeded
Write-Host "Can survive 1 node failure: $canSurvive" -ForegroundColor $(
    if ($canSurvive) {'Green'} else {'Red'})
