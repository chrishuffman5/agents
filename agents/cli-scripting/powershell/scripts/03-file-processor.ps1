#!/usr/bin/env pwsh
# ============================================================================
# PowerShell - CSV/JSON File Processor
#
# Purpose : Import CSV or JSON files, filter, transform, and export to
#           multiple formats. Supports calculated properties and batching.
# Version : 1.0.0
# Targets : PowerShell 7.0+
# Safety  : Read-only on input files. Creates new output files.
#
# Examples:
#   .\03-file-processor.ps1 -InputFile data.csv -Filter "Department -eq 'Engineering'" -Format JSON
#   .\03-file-processor.ps1 -InputFile data.json -Select Name,Email,Score -SortBy Score -Descending
# ============================================================================
#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory, HelpMessage='Path to input CSV or JSON file')]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$InputFile,

    [string]$Filter,

    [string[]]$Select,

    [string]$SortBy,
    [switch]$Descending,

    [int]$Limit,

    [ValidateSet('CSV','JSON','Table','Both')]
    [string]$Format = 'Table',

    [string]$OutputPath = '.',

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Import ───────────────────────────────────────────────────────────────────
Write-Verbose "Reading: $InputFile"
$ext = [System.IO.Path]::GetExtension($InputFile).ToLower()

$data = switch ($ext) {
    '.csv'  { Import-Csv $InputFile }
    '.tsv'  { Import-Csv $InputFile -Delimiter "`t" }
    '.json' { Get-Content $InputFile -Raw | ConvertFrom-Json }
    default { Import-Csv $InputFile }
}

$total = @($data).Count
Write-Verbose "Loaded $total records"

# ── Filter ───────────────────────────────────────────────────────────────────
if ($Filter) {
    Write-Verbose "Applying filter: $Filter"
    $sb = [scriptblock]::Create("`$_ | Where-Object { `$_.$Filter }")
    try {
        $data = $data | Where-Object ([scriptblock]::Create($Filter))
    } catch {
        # Fallback: simple field=value parsing
        if ($Filter -match '^(\w+)\s*([-]eq|[-]ne|[-]gt|[-]lt|[-]ge|[-]le|[-]like|[-]match)\s*(.+)$') {
            $field = $Matches[1]; $op = $Matches[2]; $val = $Matches[3].Trim("'`"")
            $data = $data | Where-Object {
                $fval = $_.$field
                switch ($op) {
                    '-eq'    { $fval -eq $val }
                    '-ne'    { $fval -ne $val }
                    '-gt'    { [double]$fval -gt [double]$val }
                    '-lt'    { [double]$fval -lt [double]$val }
                    '-ge'    { [double]$fval -ge [double]$val }
                    '-le'    { [double]$fval -le [double]$val }
                    '-like'  { $fval -like $val }
                    '-match' { $fval -match $val }
                }
            }
        } else {
            Write-Error "Cannot parse filter: $Filter. Use format: 'Property -eq Value'"
        }
    }
    Write-Verbose "After filter: $(@($data).Count) records (removed $($total - @($data).Count))"
}

# ── Select ───────────────────────────────────────────────────────────────────
if ($Select -and $Select.Count -gt 0) {
    Write-Verbose "Selecting fields: $($Select -join ', ')"
    $data = $data | Select-Object $Select
}

# ── Sort ─────────────────────────────────────────────────────────────────────
if ($SortBy) {
    Write-Verbose "Sorting by: $SortBy $(if ($Descending) { '(desc)' } else { '(asc)' })"
    $data = $data | Sort-Object $SortBy -Descending:$Descending
}

# ── Limit ────────────────────────────────────────────────────────────────────
if ($Limit -gt 0) {
    $data = $data | Select-Object -First $Limit
    Write-Verbose "Limited to $Limit records"
}

$outputCount = @($data).Count
Write-Verbose "Final output: $outputCount records"

# ── Dry run ──────────────────────────────────────────────────────────────────
if ($DryRun) {
    Write-Host "Dry run: $outputCount records would be written as $Format"
    if ($outputCount -gt 0) {
        Write-Host "Sample:"
        $data | Select-Object -First 3 | Format-Table -AutoSize | Out-String | Write-Host
    }
    return
}

# ── Output ───────────────────────────────────────────────────────────────────
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile) + '_processed'

if ($Format -in 'CSV','Both') {
    $csvPath = Join-Path $OutputPath "$baseName.csv"
    if ($PSCmdlet.ShouldProcess($csvPath, 'Write CSV')) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $data | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "CSV saved: $csvPath ($outputCount records)"
    }
}

if ($Format -in 'JSON','Both') {
    $jsonPath = Join-Path $OutputPath "$baseName.json"
    if ($PSCmdlet.ShouldProcess($jsonPath, 'Write JSON')) {
        if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
        $data | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        Write-Host "JSON saved: $jsonPath ($outputCount records)"
    }
}

if ($Format -eq 'Table') {
    $data | Format-Table -AutoSize
}
