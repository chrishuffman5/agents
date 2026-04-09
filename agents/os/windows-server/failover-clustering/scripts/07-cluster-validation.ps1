<#
.SYNOPSIS
    Windows Server Failover Clustering - Cluster Validation Wrapper
.DESCRIPTION
    Executes Test-Cluster with configurable test categories, saves the HTML
    report, and parses results to surface warnings and failures. Safe to
    run on live clusters when using non-destructive test categories.
.NOTES
    Version : 1.0.0
    Targets : Windows Server 2016+ with Failover Clustering role installed
    Safety  : Read-only when using -SkipStorageTests. Storage tests may
              briefly interrupt I/O on production clusters.
    Sections:
        1. Parameter Resolution
        2. Validation Execution
        3. Results Summary
        4. Common Issues Reference
#>

#Requires -Module FailoverClusters

param(
    [string[]]$Nodes,
    [string]$ClusterName      = ".",
    [string]$ReportPath       = "C:\ClusterValidation",
    [switch]$SkipStorageTests,
    [switch]$NetworkOnly,
    [switch]$SystemConfigOnly
)

function Write-Section {
    param([string]$Title)
    Write-Host "`n$('=' * 60)" -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host "$('=' * 60)" -ForegroundColor Cyan
}

# Ensure output directory exists
if (-not (Test-Path $ReportPath)) {
    New-Item -Path $ReportPath -ItemType Directory -Force | Out-Null
}

$reportFile = Join-Path $ReportPath ("ClusterValidation_{0:yyyyMMdd_HHmmss}" -f (Get-Date))

# ── 1. Determine Nodes ───────────────────────────────────────────────────────
if (-not $Nodes) {
    try {
        $Nodes = (Get-ClusterNode -Cluster $ClusterName -ErrorAction Stop).Name
    } catch {
        Write-Error "Could not get cluster nodes and no -Nodes parameter specified: $_"
        exit 1
    }
}

Write-Section "CLUSTER VALIDATION"
Write-Host "Nodes to validate: $($Nodes -join ', ')" -ForegroundColor Yellow
Write-Host "Report output:     $reportFile.htm"

# ── 2. Build Test Scope ──────────────────────────────────────────────────────
$includeTests = @()
if ($NetworkOnly) {
    $includeTests = @('Network')
    Write-Host "Test scope: Network only" -ForegroundColor Yellow
} elseif ($SystemConfigOnly) {
    $includeTests = @('System Configuration')
    Write-Host "Test scope: System Configuration only" -ForegroundColor Yellow
} elseif ($SkipStorageTests) {
    $includeTests = @('Network', 'System Configuration', 'Inventory', 'Hyper-V Configuration')
    Write-Host "Test scope: All except Storage (safe for live clusters)" -ForegroundColor Yellow
} else {
    Write-Host "Test scope: Full validation (includes Storage)" -ForegroundColor Red
    Write-Host "  Storage tests may briefly interrupt I/O. Use -SkipStorageTests for live clusters." -ForegroundColor Yellow
}

Write-Host "`nStarting validation at $(Get-Date)..." -ForegroundColor Cyan

$testParams = @{
    Node       = $Nodes
    ReportName = $reportFile
    Verbose    = $true
}
if ($includeTests.Count -gt 0) {
    $testParams['Include'] = $includeTests
}

try {
    $result = Test-Cluster @testParams 2>&1
    Write-Host "Validation completed at $(Get-Date)." -ForegroundColor Green
} catch {
    Write-Error "Test-Cluster failed: $_"
}

# ── 3. Results Summary ───────────────────────────────────────────────────────
Write-Section "VALIDATION RESULTS SUMMARY"
$htmlReport = "$reportFile.htm"

if (Test-Path $htmlReport) {
    Write-Host "HTML Report: $htmlReport" -ForegroundColor Green

    $reportContent = Get-Content $htmlReport -Raw -ErrorAction SilentlyContinue
    if ($reportContent) {
        $warnings  = ([regex]::Matches($reportContent, 'class="warn"')).Count
        $failures  = ([regex]::Matches($reportContent, 'class="fail"')).Count
        $successes = ([regex]::Matches($reportContent, 'class="pass"')).Count

        Write-Host "`nResult Counts:"
        Write-Host "  Passed:   $successes" -ForegroundColor Green
        Write-Host "  Warnings: $warnings" -ForegroundColor $(
            if ($warnings -gt 0) {'Yellow'} else {'Green'})
        Write-Host "  Failed:   $failures" -ForegroundColor $(
            if ($failures -gt 0) {'Red'} else {'Green'})

        if ($failures -gt 0) {
            Write-Host "`n[ALERT] Validation failures detected. Review $htmlReport." -ForegroundColor Red
        } elseif ($warnings -gt 0) {
            Write-Host "`n[WARNING] Validation warnings present. Review $htmlReport." -ForegroundColor Yellow
        } else {
            Write-Host "`nAll validation tests passed." -ForegroundColor Green
        }
    }
} else {
    Write-Warning "Report file not found at: $htmlReport"
}

# ── 4. Common Issues Reference ───────────────────────────────────────────────
Write-Section "COMMON VALIDATION ISSUES"
Write-Host @"
FAILURE: "Could not validate disk"     -- Check SAN zoning, iSCSI, MPIO config
FAILURE: "Node cannot be reached"      -- Check firewall, DNS, WMI access
WARNING: "NIC driver version mismatch" -- Update NIC drivers to same version
WARNING: "Hotfix level mismatch"       -- Apply pending Windows Updates via CAU
FAILURE: "SCSI-3 reservations failed"  -- Update storage firmware or use S2D
WARNING: "Binding order not optimal"   -- Move cluster NIC to top of binding order
"@ -ForegroundColor Gray
