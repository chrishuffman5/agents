#!/usr/bin/env pwsh
# ============================================================================
# PowerShell - Log Analyzer
#
# Purpose : Parse log files using regex, extract structured entries,
#           generate summaries by level, time window, and pattern frequency.
# Version : 1.0.0
# Targets : PowerShell 7.0+
# Safety  : Read-only. Analyzes logs without modification.
#
# Examples:
#   .\04-log-analyzer.ps1 -LogFile app.log
#   .\04-log-analyzer.ps1 -LogFile app.log -Since 2 -Level ERROR -TopN 20
#   .\04-log-analyzer.ps1 -LogFile app.log -Format JSON -OutputPath C:\Reports
# ============================================================================
#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage='Path to log file')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$LogFile,

    [double]$Since,

    [ValidateSet('DEBUG','INFO','WARN','ERROR','FATAL')]
    [string]$Level,

    [int]$TopN = 10,

    [ValidateSet('Console','JSON','Both')]
    [string]$Format = 'Console',

    [string]$OutputPath = '.',

    [string]$Pattern = '^(?<timestamp>\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2})\s+(?<level>DEBUG|INFO|WARN|ERROR|FATAL)\s+(?:\[(?<source>[^\]]+)\]\s+)?(?<message>.+)$'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Verbose "Analyzing: $LogFile"

# ── Parse log entries ────────────────────────────────────────────────────────
$rawLines = Get-Content $LogFile
Write-Verbose "Total lines: $($rawLines.Count)"

$entries = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($line in $rawLines) {
    if ($line -match $Pattern) {
        $ts = try { [datetime]$Matches['timestamp'] } catch { [datetime]::MinValue }
        $entries.Add([PSCustomObject]@{
            Timestamp = $ts
            Level     = $Matches['level']
            Source    = $Matches['source'] ?? ''
            Message   = $Matches['message']
            Raw       = $line
        })
    }
}

Write-Verbose "Parsed entries: $($entries.Count) of $($rawLines.Count) lines"

# ── Filter by time window ────────────────────────────────────────────────────
if ($Since -gt 0) {
    $cutoff = (Get-Date).AddHours(-$Since)
    $before = $entries.Count
    $entries = [System.Collections.Generic.List[PSCustomObject]]($entries | Where-Object { $_.Timestamp -ge $cutoff })
    Write-Verbose "Time filter (last ${Since}h): $($entries.Count) entries (removed $($before - $entries.Count))"
}

# ── Filter by level ──────────────────────────────────────────────────────────
if ($Level) {
    $entries = [System.Collections.Generic.List[PSCustomObject]]($entries | Where-Object { $_.Level -eq $Level })
    Write-Verbose "Level filter ($Level): $($entries.Count) entries"
}

# ── Analysis ─────────────────────────────────────────────────────────────────
$analysis = [ordered]@{
    File           = $LogFile
    TotalLines     = $rawLines.Count
    ParsedEntries  = $entries.Count
    TimeRange      = if ($entries.Count -gt 0) {
        "$($entries[0].Timestamp) to $(($entries | Select-Object -Last 1).Timestamp)"
    } else { 'N/A' }
}

# Level summary
$levelSummary = $entries | Group-Object Level | Select-Object @{N='Level';E={$_.Name}}, Count | Sort-Object Count -Descending
$analysis['LevelSummary'] = $levelSummary

# Top error messages (normalized)
$topErrors = $entries | Where-Object { $_.Level -eq 'ERROR' } |
    ForEach-Object { $_.Message -replace '\d{4,}','<NUM>' -replace '[0-9a-f]{8,}','<HEX>' } |
    Group-Object | Sort-Object Count -Descending | Select-Object -First $TopN |
    Select-Object @{N='Count';E={$_.Count}}, @{N='Message';E={$_.Name}}
$analysis['TopErrors'] = $topErrors

# Top warnings
$topWarnings = $entries | Where-Object { $_.Level -eq 'WARN' } |
    ForEach-Object { $_.Message -replace '\d{4,}','<NUM>' } |
    Group-Object | Sort-Object Count -Descending | Select-Object -First $TopN |
    Select-Object @{N='Count';E={$_.Count}}, @{N='Message';E={$_.Name}}
$analysis['TopWarnings'] = $topWarnings

# Errors by hour
$errorsByHour = $entries | Where-Object { $_.Level -eq 'ERROR' } |
    Group-Object { $_.Timestamp.ToString('yyyy-MM-dd HH:00') } |
    Sort-Object Name |
    Select-Object @{N='Hour';E={$_.Name}}, Count
$analysis['ErrorsByHour'] = $errorsByHour

# Top sources
$topSources = $entries | Where-Object { $_.Source } |
    Group-Object Source | Sort-Object Count -Descending | Select-Object -First $TopN |
    Select-Object @{N='Source';E={$_.Name}}, Count
$analysis['TopSources'] = $topSources

# ── Output ───────────────────────────────────────────────────────────────────
function Show-ConsoleReport {
    $SEP = '=' * 60
    Write-Host "`n$SEP" -ForegroundColor Cyan
    Write-Host "  LOG ANALYSIS REPORT" -ForegroundColor Cyan
    Write-Host $SEP -ForegroundColor Cyan
    Write-Host "  File    : $($analysis['File'])"
    Write-Host "  Lines   : $($analysis['TotalLines'])"
    Write-Host "  Parsed  : $($analysis['ParsedEntries'])"
    Write-Host "  Range   : $($analysis['TimeRange'])"
    if ($Since) { Write-Host "  Window  : Last ${Since} hours" }
    if ($Level) { Write-Host "  Filter  : $Level only" }

    Write-Host "`n--- Level Summary ---"
    $levelSummary | ForEach-Object {
        $color = switch ($_.Level) { 'ERROR' {'Red'} 'FATAL' {'Red'} 'WARN' {'Yellow'} default {'White'} }
        Write-Host "  $($_.Level.PadRight(8)) $($_.Count)" -ForegroundColor $color
    }

    if ($topErrors.Count -gt 0) {
        Write-Host "`n--- Top Errors (Top $TopN) ---"
        $topErrors | ForEach-Object { Write-Host "  $($_.Count.ToString().PadLeft(5))  $($_.Message.Substring(0, [math]::Min($_.Message.Length, 80)))" -ForegroundColor Red }
    }

    if ($topWarnings.Count -gt 0) {
        Write-Host "`n--- Top Warnings (Top $TopN) ---"
        $topWarnings | ForEach-Object { Write-Host "  $($_.Count.ToString().PadLeft(5))  $($_.Message.Substring(0, [math]::Min($_.Message.Length, 80)))" -ForegroundColor Yellow }
    }

    if ($errorsByHour.Count -gt 0) {
        Write-Host "`n--- Errors by Hour ---"
        $errorsByHour | ForEach-Object { Write-Host "  $($_.Hour)  $($_.Count)" }
    }

    Write-Host "`n$SEP" -ForegroundColor Cyan
}

if ($Format -in 'Console','Both') { Show-ConsoleReport }

if ($Format -in 'JSON','Both') {
    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
    $jsonPath = Join-Path $OutputPath 'log-analysis.json'
    $analysis | ConvertTo-Json -Depth 5 | Set-Content $jsonPath -Encoding UTF8
    Write-Host "JSON report saved: $jsonPath"
}
